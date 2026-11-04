"""Physical blade adapter: real Lua, mocked Unreal/UEVR boundary only."""
import unittest
from pathlib import Path
from lupa.lua54 import LuaRuntime
import test_chainsword_preview as preview

ROOT = Path(__file__).resolve().parents[1]


class PhysicalChainswordTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute("package.path=" + repr(str(ROOT / 'src/lua/?.lua').replace('\\', '/') + ';') + "..package.path")
        self.lua.execute(FIXTURE)
        self.lua.execute("contact=require('boltgun_chainsword_contact').new(uevr)")

    def run_lua(self, code):
        self.lua.execute(code)

    def value(self, code):
        return self.lua.eval(code)

    def frame(self, dt=.02, capture=True):
        self.lua.globals().ctx.dt = dt
        self.run_lua("contact:step(pawn,blade,true,ctx.dt,1)")
        if capture:
            self.run_lua("contact:capture(pawn,blade,true,1,1)")

    def arm(self):
        for _ in range(3):
            self.frame()

    def test_real_hit_uses_original_damage_and_restores_all_weapon_bytes(self):
        self.arm()
        self.assertEqual(self.value('ctx.damage'), 1)
        self.assertEqual(self.value('sword.CuttingDamage'), 40)
        self.assertTrue(self.value('sword.ChainswordCuttingTarget==nil'))
        self.assertEqual(self.value('sword.ChainswordHit:read_byte(7)'), 73)
        self.assertTrue(self.value('ctx.real_hits[ctx.applied_hit]'))
        self.assertEqual(self.value('ctx.applied_damage'), 10)

    def test_stationary_contact_repeats_only_after_cooldown(self):
        self.arm()
        for _ in range(20):
            self.frame()
        self.assertEqual(self.value('ctx.damage'), 1)
        for _ in range(6):
            self.frame()
        self.assertEqual(self.value('ctx.damage'), 2)

    def test_missing_enemy_wall_dead_or_nonblocking_never_damage(self):
        for change in ('ctx.hit=false', 'ctx.wall=true', 'ctx.dead=true', 'ctx.blocking=false',
                       'ctx.occluded=true'):
            with self.subTest(change=change):
                self.setUp()
                self.run_lua(change)
                self.arm()
                self.assertEqual(self.value('ctx.damage'), 0)

    def test_gates_invalidate_previous_pose_and_preserve_cooldown(self):
        changes = [('paused', True), ('loaded', False), ('hmd', False), ('controllers', False),
                   ('runtime', False), ('menu', True), ('held', False), ('aim', False),
                   ('pose_valid', False), ('sword_ready', False), ('busy', True), ('player_dead', True)]
        for field, value in changes:
            with self.subTest(field=field):
                self.setUp()
                self.arm()
                self.lua.globals().ctx[field] = value
                self.frame()
                self.lua.globals().ctx[field] = not value
                self.frame()
                self.frame()
                self.assertEqual(self.value('ctx.damage'), 1)

    def test_no_fresh_stereo_capture_or_wrong_eye_does_not_trace(self):
        for _ in range(5):
            self.frame(capture=False)
            self.run_lua('contact:capture(pawn,blade,true,1,2)')
        self.assertEqual(self.value('ctx.traces'), 0)

    def test_hitch_teleport_and_nonfinite_pose_drop_contacts(self):
        self.frame()
        self.run_lua('ctx.x=500')
        self.frame()
        self.frame()
        self.assertEqual(self.value('ctx.damage'), 0)
        self.frame(.5)
        self.run_lua('ctx.x=0/0')
        self.frame()
        self.frame()
        self.assertEqual(self.value('ctx.damage'), 0)

    def test_original_damage_error_restores_state_and_stops_retrying(self):
        self.run_lua('ctx.damage_error=true')
        self.arm()
        self.assertEqual(self.value('ctx.damage'), 1)
        self.assertEqual(self.value('sword.CuttingDamage'), 40)
        self.assertTrue(self.value('sword.ChainswordCuttingTarget==nil'))
        self.assertEqual(self.value('sword.ChainswordHit:read_byte(7)'), 73)
        for _ in range(30):
            self.frame()
        self.assertEqual(self.value('ctx.damage'), 1)
        self.assertTrue(self.value('contact.stopped'))

    def test_missing_reflection_contract_fails_before_damage(self):
        self.run_lua("ctx.missing='ChainswordHit'")
        self.arm()
        self.assertEqual(self.value('ctx.damage'), 0)

    def test_scale_change_requires_two_new_matching_poses(self):
        self.frame()
        self.frame()
        self.run_lua('ctx.scale=.5;contact:capture(pawn,blade,true,.5,1)')
        self.run_lua('contact:step(pawn,blade,true,.02,.5)')
        self.assertEqual(self.value('ctx.traces'), 0)

    def test_recreated_blade_preserves_same_weapon_cooldown(self):
        self.arm()
        self.run_lua("blade.name='ProceduralMeshComponent Test.Rebuilt';contact:reset_pose()")
        for _ in range(3):
            self.frame()
        self.assertEqual(self.value('ctx.damage'), 1)

    def test_hidden_or_foreign_blade_cannot_damage(self):
        for change in ('blade.bVisible=false', 'blade.bHiddenInGame=true',
                       'blade.outer=enemy'):
            with self.subTest(change=change):
                self.setUp()
                self.run_lua(change)
                self.arm()
                self.assertEqual(self.value('ctx.damage'), 0)

    def test_dense_contacts_exhaust_actual_trace_budget_before_any_damage(self):
        self.run_lua('''
            ctx.enemies={}
            for i=1,15 do
                local e=obj('Enemy '..i);e.is_a=enemy.is_a;e.IsDead=enemy.IsDead
                ctx.enemies[i]=e
            end
        ''')
        self.arm()
        self.assertLessEqual(self.value('ctx.traces'), 512)
        self.assertEqual(self.value('ctx.damage'), 0)

    def test_each_restore_is_attempted_when_a_setter_fails(self):
        self.run_lua('''
            ctx.restores={}
            local setter=sword.set_property
            function sword:set_property(k,v)
                if ctx.damage>0 then
                    ctx.restores[k]=true
                    if k=='CuttingDamage' then error('restore rejected') end
                end
                setter(self,k,v)
            end
        ''')
        self.arm()
        self.assertTrue(self.value('contact.stopped'))
        self.assertTrue(self.value('ctx.restores.ChainswordHit and ctx.restores.ChainswordCuttingTarget'))
        self.assertTrue(self.value('sword.ChainswordCuttingTarget==nil'))
        self.assertEqual(self.value('sword.ChainswordHit:read_byte(7)'), 73)


class ChainswordIntegrationTests(unittest.TestCase):
    """Run the visual owner, contact pipeline and damage adapter together."""

    def setUp(self):
        fixture = preview.ChainswordTests()
        fixture.reload = lambda: None
        fixture.setUp()
        self.lua, self.tick = fixture.lua, fixture.tick
        self.lua.execute("package.path=" + repr(str(ROOT / 'src/lua/?.lua').replace('\\', '/') + ';') + "..package.path")
        # Reuse the external collision boundary without replacing any production module.
        self.lua.execute("collision=setmetatable({}, {__index=_G})")
        self.lua.globals().collision_fixture = FIXTURE
        self.lua.execute("assert(load(collision_fixture,'collision','t',collision))()")
        self.lua.execute(INTEGRATION_FIXTURE)
        self.lua.execute((ROOT / 'src/lua/boltgun_chainsword.lua').read_text(encoding='utf-8'))

    def value(self, code):
        return self.lua.eval(code)

    def stereo(self, eye=1):
        # Stereo has no authenticated thread identity. Forbid all UObject access.
        self.lua.execute(f"if stereo then stereo(nil,{eye},100,nil,nil,false) end")

    def end_tick(self):
        self.lua.globals().ctx.engine_thread = True
        try:
            self.lua.execute('if post_tick then post_tick() end')
        finally:
            self.lua.globals().ctx.engine_thread = False

    def frame(self, capture=True, eye=1, dt=.02):
        self.tick(dt)
        if capture:
            self.stereo(eye)
        self.end_tick()

    def start(self):
        for _ in range(3):
            self.frame(capture=False, dt=1)

    def test_load_registers_capture_without_unreal_access(self):
        self.assertEqual(self.value('ctx.queries'), 0)
        self.assertTrue(self.value('type(stereo)=="function"'))

    def test_stereo_only_marks_then_post_engine_tick_captures_owned_pose(self):
        self.start()
        self.tick(.02)
        before = self.value('ctx.queries')
        self.stereo()
        self.assertEqual(self.value('ctx.queries'), before)
        self.assertEqual(self.value('ctx.capture_reads or 0'), 0)
        self.end_tick()
        self.assertGreater(self.value('ctx.capture_reads or 0'), 0)
        self.assertEqual(self.value('ctx.traces'), 0)

    def test_owned_display_pose_reaches_real_damage_only_on_engine_tick(self):
        self.start()
        self.lua.execute('ctx.x=12')
        self.stereo()  # Outside the engine callback interval: no UObject reads.
        self.assertEqual(self.value('ctx.capture_reads or 0'), 0)
        self.frame()
        self.assertEqual(self.value('ctx.damage'), 0)
        self.frame()
        self.assertEqual(self.value('ctx.damage'), 0)
        self.frame()
        self.assertEqual(self.value('ctx.damage'), 1)
        self.assertEqual(self.value('ctx.first_trace_x'), 17)
        self.assertTrue(self.value('ctx.captured_component==ctx.components[1]'))
        self.assertEqual(self.value('collision.sword.CuttingDamage'), 40)
        self.assertEqual(self.value('collision.sword.ChainswordHit:read_byte(7)'), 73)

    def test_missing_stereo_or_second_eye_never_queries(self):
        self.start()
        for _ in range(4):
            self.frame(capture=False)
            self.frame(eye=2)
        self.assertEqual(self.value('ctx.traces'), 0)

    def test_late_stereo_marker_does_not_authorize_next_frame_capture(self):
        self.start()
        self.frame(capture=False)
        self.stereo()
        self.frame(capture=False)
        self.assertEqual(self.value('ctx.capture_reads or 0'), 0)

    def test_hidden_component_rebuild_keeps_weapon_cooldown(self):
        self.start()
        for _ in range(3):
            self.frame()
        self.assertEqual(self.value('ctx.damage'), 1)
        self.lua.execute('ctx.menu=true')
        self.frame()
        self.lua.execute('ctx.menu=false')
        # Creation retry is deliberately throttled; permit it without advancing
        # the contact clock by using invalid (>100ms) gameplay deltas.
        self.frame(dt=1)
        for _ in range(3):
            self.frame()
        self.assertEqual(self.value('ctx.created'), 2)
        self.assertEqual(self.value('ctx.damage'), 1)

    def test_ui_off_and_hidden_codex_discard_pending_capture(self):
        for change in ("ctx.menu=true", "files['chainsword3d.mode']='off'",
                       "sprite_mat.get_full_name=function()return 'MaterialInstanceConstant /Game/Art/Animations/Player/Codex/Reading/Book' end"):
            with self.subTest(change=change):
                self.setUp()
                self.start()
                self.frame()
                self.frame()
                self.lua.execute(change)
                self.frame(dt=.02 if 'mode' not in change else .3)
                self.assertEqual(self.value('ctx.damage'), 0)

    def test_settings_change_discards_pose_before_calibration_moves_blade(self):
        self.start()
        self.frame(capture=False, dt=.1)
        self.frame(dt=.1)
        self.frame(dt=.02)
        self.lua.execute("files['chainsword3d.settings']='x=20'")
        self.frame(dt=.04)  # Cross the 250ms settings refresh with a valid delta.
        self.assertEqual(self.value('ctx.traces'), 0)
        self.frame()
        self.assertEqual(self.value('ctx.traces'), 0)
        self.frame()
        self.assertEqual(self.value('ctx.damage'), 1)

    def test_reset_stops_capture_and_damage_without_unreal_calls(self):
        self.start()
        self.frame()
        before = self.value('ctx.queries')
        self.lua.globals().reset()
        self.assertEqual(self.value('ctx.queries'), before)
        for _ in range(4):
            self.frame()
        self.assertEqual(self.value('ctx.queries'), before)
        self.assertEqual(self.value('ctx.damage'), 0)


FIXTURE = r'''
ctx={damage=0,traces=0,real_hits={},x=0,hmd=true,controllers=true,runtime=true,menu=false,held=true,
 aim=true,pose_valid=true,sword_ready=true,loaded=true,paused=false,hit=true,blocking=true}
function obj(name,outer)
 local o={valid=true,name=name,outer=outer}
 function o:get_full_name() return self.name end
 function o:get_address() return self.name end
 function o:get_outer() return self.outer end
 function o:get_property(k) return self[k] end
 function o:set_property(k,v) assert(k~='CurrentHealth');self[k]=v end
 function o:get_class() return self.class or generic end
 return o
end
generic={valid=true}
function generic:find_property(k)
 if ctx.missing==k then return nil end
 return {get_class=function() return {get_name=function() return 'ObjectProperty' end} end}
end
function generic:find_function(k) return k=='DealCuttingDamage' and function_descriptor({},function()end) or {} end
function function_descriptor(names,call,outputs)
 local fields={}
 for i,n in ipairs(names) do fields[i]={get_fname=function()return{to_string=function()return n end}end,
  get_next=function()return fields[i+1]end} end
 return setmetatable({get_child_properties=function()return fields[1]end,
  find_property=function(_,n)return{is_param=function()return true end,is_return_param=function()return false end,
   is_out_param=function()return outputs and outputs[n] or false end}end}, {__call=call})
end
hitdesc={valid=true,get_properties_size=function()return 16 end,
 get_full_name=function()return 'ScriptStruct /Script/Engine.HitResult' end}
function hit(bytes)
 local h={bBlockingHit=true,bytes=bytes or {}}
 function h:get_struct() return hitdesc end
 function h:read_byte(i) return self.bytes[i] or 0 end
 function h:write_byte(i,v) self.bytes[i]=v end
 return h
end
StructObject={new=function(desc)
 if desc==hitdesc then return hit() end
 return {set_property=function(self,k,v)self[k]=v end}
end}
engine=obj('Engine');pawn=obj('BP_PlayerCharacter_Sternguard_C /Game/Maps/Test.Test.PersistentLevel.BP_PlayerCharacter_Sternguard_C_0')
handler=obj('Handler',pawn);sword=obj('BP_Chainsword_C /Game/Maps/Test.Sword',handler)
blade=obj('ProceduralMeshComponent Test.Blade',pawn);enemy=obj('Enemy');wall=obj('Wall')
blade.bVisible=true;blade.bHiddenInGame=false
enemyclass=obj('Class /Script/Boltgun.BGNonPlayableCharacterBase')
function enemy:is_a(c)return c==enemyclass end
function wall:is_a(c)return false end
function enemy:IsDead()return ctx.dead==true end
function pawn:IsDead()return ctx.player_dead==true end
function pawn:K2_GetActorLocation()return {X=0,Y=0,Z=0}end
function blade:K2_GetComponentToWorld()
 local scale=ctx.scale or 1
 return {Translation={X=ctx.x,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=scale,Y=scale,Z=scale}}
end
function sword:GetOwner()return pawn end
sword.CuttingDamage=40;sword.StrikeDamage=10;sword.ChainswordHit=hit({[7]=73})
function sword:DealCuttingDamage()
 ctx.damage=ctx.damage+1;ctx.applied_damage=self.CuttingDamage;ctx.applied_hit=self.ChainswordHit
 assert(self.ChainswordCuttingTarget==enemy);assert(ctx.real_hits[self.ChainswordHit])
 if ctx.damage_error then error('native damage failed')end
end
local pawn_prop=pawn.get_property
function pawn:get_property(k)
 if k=='bPlayerFinishedLevelLoad' then return ctx.loaded end
 if k=='WeaponHandlerComponent' then return handler end
 return pawn_prop(self,k)
end
function handler:get_property(k)if k=='EquippedMeleeWeapon' and ctx.sword_ready then return sword end end
local sword_prop=sword.get_property
function sword:get_property(k)if k=='ChainswordCuttingTarget' and ctx.busy then return enemy end;return sword_prop(self,k)end
controller=obj('Controller');hud=obj('HUD');controller.MyHUD=hud
gs=obj('GameplayStatics');system=obj('KismetSystemLibrary')
function gs:IsGamePaused()return ctx.paused end
local trace_names={'WorldContextObject','Start','End','Radius','TraceChannel','bTraceComplex','ActorsToIgnore','DrawDebugType','OutHit','bIgnoreSelf','TraceColor','TraceHitColor','DrawTime'}
trace=function_descriptor(trace_names,function(_,self,p,a,b,r,channel,complex,ignore,draw,out,ignoreself)
 ctx.traces=ctx.traces+1
 ctx.first_trace_x=ctx.first_trace_x or a.X
 assert(p==pawn and ignore[1]==pawn and ignore[2]==sword and r>0 and channel==0 and not complex and draw==0 and ignoreself)
 if not ctx.hit then return false end
 local target=ctx.wall and wall or enemy
 if ctx.enemies then target=ctx.enemies[#ignore-1];if not target then return false end end
 if ctx.occluded and a.Z==0 then target=wall end
 for _,o in ipairs(ignore)do if o==target then return false end end
 local h=hit();h.target=target;h.bBlockingHit=ctx.blocking;ctx.real_hits[h]=true;out.result=h;return true
end,{OutHit=true})
local break_names={'Hit','bBlockingHit','bInitialOverlap','Time','Location','ImpactPoint','HitActor','HitComponent'}
breaker=function_descriptor(break_names,function(_,self,h,blocking,initial,time,location,point,actor,component)
 blocking.result=h.bBlockingHit;initial.result=false;time.result=.5
 point.result={X=0,Y=0,Z=40};location.result=point.result;actor.result=h.target
end,{bBlockingHit=true,bInitialOverlap=true,Time=true,Location=true,ImpactPoint=true,HitActor=true,HitComponent=true})
gs.class={valid=true,find_function=function(_,k)if k=='BreakHitResult'then return breaker end;return {}end}
system.class={valid=true,find_function=function(_,k)if k=='SphereTraceSingle'then return trace end end}
local vector=obj('Vector');function vector:as_struct()return self end
local function lib(o)return {valid=true,get_class_default_object=function()return o end}end
uevr={api={get_engine=function()return engine end,get_local_pawn=function()return pawn end,
 get_player_controller=function()return controller end,
 find_uobject=function(_,name)
 if name=='Class /Script/Engine.GameplayStatics'then return lib(gs)end
 if name=='Class /Script/Engine.KismetSystemLibrary'then return lib(system)end
 if name=='Class /Script/Boltgun.BGNonPlayableCharacterBase'then return enemyclass end
 if name=='ScriptStruct /Script/CoreUObject.Vector'then return vector end
 end},types={UObjectHook={exists=function(o)return o and o.valid==true end}},
 params={functions={is_drawing_ui=function()return ctx.menu end,log_info=function()end},vr={
 is_runtime_ready=function()return ctx.runtime end,is_openxr=function()return true end,
 is_hmd_active=function()return ctx.hmd end,is_using_controllers=function()return ctx.controllers end,
 is_aim_allowed=function()return ctx.aim end,get_left_controller_index=function()return 0 end,
 get_left_joystick_source=function()return 0 end,get_action_handle=function()return 123 end,
 is_action_active=function(action,source)assert(action==123 and source==0);return ctx.held end,
 get_transform=function(_,index)assert(index==0);if not ctx.pose_valid then return {[3]={x=0/0,y=0,z=0}}end
 return {[0]={x=1,y=0,z=0},[1]={x=0,y=1,z=0},[2]={x=0,y=0,z=1},[3]={x=.3,y=1,z=-.2}}end}}}
'''

INTEGRATION_FIXTURE = r'''
ctx.engine_thread=true
for k,v in pairs(collision.ctx) do if ctx[k]==nil then ctx[k]=v end end
collision.ctx=ctx;collision.pawn=pawn;collision.handler=handler;collision.engine=engine
pawn.get_full_name=function()engine_only();return 'BP_PlayerCharacter_Sternguard_C /Game/Maps/Test.Test.PersistentLevel.BP_PlayerCharacter_Sternguard_C_0' end
pawn.IsDead=function()engine_only();return ctx.player_dead==true end
pawn.K2_GetActorLocation=function()engine_only();return {X=0,Y=0,Z=0}end
local pawn_prop=pawn.get_property
pawn.get_property=function(self,k)
 if k=='bPlayerFinishedLevelLoad'then engine_only();return ctx.loaded end
 return pawn_prop(self,k)
end
local handler_prop=handler.get_property
handler.get_property=function(self,k)
 if k=='EquippedMeleeWeapon'then engine_only();return ctx.sword_ready and collision.sword or nil end
 return handler_prop(self,k)
end
local find=uevr.api.find_uobject
uevr.api.find_uobject=function(self,name)
 if name=='Class /Script/Engine.GameplayStatics' or name=='Class /Script/Engine.KismetSystemLibrary' or
    name=='Class /Script/Boltgun.BGNonPlayableCharacterBase' or name=='ScriptStruct /Script/CoreUObject.Vector' then
  engine_only();return collision.uevr.api.find_uobject(self,name)
 end
 return find(self,name)
end
uevr.api.get_player_controller=collision.uevr.api.get_player_controller
local create=uevr.api.add_component_by_class
uevr.api.add_component_by_class=function(...)
 local c=create(...)
 c.get_property=function(self,k)
  engine_only();if k=='bVisible'then return self.visible end;if k=='bHiddenInGame'then return self.hidden end
 end
 c.K2_GetComponentToWorld=function(self)
  engine_only();ctx.capture_reads=(ctx.capture_reads or 0)+1;ctx.captured_component=self
  return {Translation={X=ctx.x,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},
          Scale3D={X=self.scale,Y=self.scale,Z=self.scale}}
 end
 return c
end
local make=StructObject.new
local vector=collision.uevr.api:find_uobject('ScriptStruct /Script/CoreUObject.Vector'):as_struct()
StructObject.new=function(desc)
 engine_only();if desc==collision.hitdesc or desc==vector then return collision.StructObject.new(desc) end
 return make(desc)
end
for k,v in pairs(collision.uevr.params.vr) do uevr.params.vr[k]=v end
uevr.params.sdk.callbacks.on_post_calculate_stereo_view_offset=function(f)stereo=f end
uevr.params.sdk.callbacks.on_post_engine_tick=function(f)post_tick=f end
ctx.engine_thread=false;ctx.queries=0
'''

if __name__ == '__main__':
    unittest.main()
