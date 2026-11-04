"""Exercise the real comfort adapter at the reflected UE/Lua boundary."""
import unittest
from pathlib import Path
from lupa.lua54 import LuaRuntime

SOURCE = Path(__file__).resolve().parents[1] / 'src/lua/boltgun_comfort.lua'

FIXTURE = r'''
ctx={thread=false,objects={},journal='',created=0,destroyed=0,menu=false,ready=true,
     enabled=true,dead=false,loaded=true,fail_write=false,health=100}
local serial=100
function guard() assert(ctx.thread,'UObject access outside engine tick') end
function obj(class,name,props,outer)
 serial=serial+1
 local o={class=class,name=name,props=props or {},outer=outer,address=serial,live=true}
 ctx.objects[name]=o
 function o:get_full_name()guard();return self.name end
 function o:get_address()guard();return self.address end
 function o:get_outer()guard();return self.outer end
 function o:get_class()guard();return self.class end
 function o:get_property(k)guard();return self.props[k] end
 function o:set_property(k,v)guard();assert(self.props[k]~=nil,k);self.props[k]=v end
 function o:GetRenderOpacity()guard();return self.opacity or 1 end
 function o:SetRenderOpacity(v)guard();self.opacity=v end
 function o:GetOwningPlayer()guard();return pc end
 function o:IsDead()guard();return ctx.dead end
 function o:IsInViewport()guard();return true end
 function o:IsVisible()guard();return ctx.menu end
 function o:GetHUD()guard();return hud end
 function o:K2_DestroyComponent(owner)guard();assert(owner==pawn);ctx.destroyed=ctx.destroyed+1;self.live=false end
 return o
end
function cls(name,properties)
 local c={name=name,properties=properties or {}}
 function c:get_full_name()guard();return self.name end
 function c:find_property(k)guard();return self.properties[k] and {} or nil end
 function c:find_function(k)guard();return ctx.missing_function~=k and {} or nil end
 function c:get_class_default_object()guard();return self.default end
 ctx.objects[name]=c;c.live=true
 return c
end
imageclass=cls('Class /Script/UMG.Image')
canvasclass=cls('Class /Script/UMG.CanvasPanel')
pawnclass=cls('BlueprintGeneratedClass /Game/Blueprints/Player/BP_PlayerCharacter_Sternguard.BP_PlayerCharacter_Sternguard_C',
 {bPlayerFinishedLevelLoad=true,CurrentHealth=true})
pawn=obj(pawnclass,'BP_PlayerCharacter_Sternguard_C /Game/Maps/Test.Test:PersistentLevel.BP_PlayerCharacter_Sternguard_C_0',
 {bPlayerFinishedLevelLoad=true,CurrentHealth=100})
pc=obj(cls('PC',{MyHUD=true}),'PC pc')
menu=obj(cls('Menu'),'Menu menu')
hud=obj(cls('HUD',{PlayerOwner=true,['Player HUD Widget']=true,CurrentMenu=true,ScreenEffectInterfaceWidget=true}),'Gameplay_HUD_C hud',
 {PlayerOwner=pc,CurrentMenu=menu})
root=obj(cls('Root',{CanvasPanel_Vignette_Low_Health=true,W_PlayerDamageScreenPulse=true}),
 'Gameplay_HUD_UI_C root',{},hud)
blood=obj(canvasclass,'CanvasPanel root.WidgetTree.CanvasPanel_Vignette_Low_Health',{},root)
pulse=obj(cls('Pulse',{AccruedDamage=true}),'W_PlayerDamageScreenPulse_C root.WidgetTree.W_PlayerDamageScreenPulse',
 {AccruedDamage=0},root)
root.props.CanvasPanel_Vignette_Low_Health=blood;root.props.W_PlayerDamageScreenPulse=pulse
hud.props['Player HUD Widget']=root;pc.props.MyHUD=hud
manager=obj(cls('Manager',{W_ScreenEffect_BloodManager=true}),'W_ScreenEffect_Manager_C manager')
blooddata=cls('BlueprintGeneratedClass /Game/Data/UI/BP_UIScreenEffectManager_Blood_Data.BP_UIScreenEffectManager_Blood_Data_C')
splatter=obj(cls('System',{ScreenEffectData=true,ActiveEffects=true}),
 'W_ScreenEffect_System_C manager.WidgetTree.W_ScreenEffect_BloodManager',
 {ScreenEffectData=blooddata,ActiveEffects={}},manager)
manager.props.W_ScreenEffect_BloodManager=splatter;hud.props.ScreenEffectInterfaceWidget=manager
slop=obj(cls('System'),'W_ScreenEffect_System_C manager.WidgetTree.W_ScreenEffect_SlopManager')
engine=obj(cls('Engine'),'Engine engine')
partclass=cls('Class /Script/Engine.PostProcessComponent',
 {bEnabled=true,bUnbound=true,BlendWeight=true,Priority=true})
matclass=cls('Class /Script/Engine.Material',{MaterialDomain=true})
material=obj(matclass,'Material /Game/Materials/PostProcessing/PickUpMaterials/M_PP_PickUp_Flash.M_PP_PickUp_Flash',
 {MaterialDomain=4})
midclass=cls('Class /Script/Engine.MaterialInstanceDynamic')
stringclass=cls('Class /Script/Engine.KismetStringLibrary')
stringclass.default=obj(stringclass,'KismetStringLibrary default')
function stringclass.default:Conv_StringToName(s)guard();return {fname=s} end
local function name(k)assert(type(k)=='table' and k.fname,'Expected reflected FName');return k.fname end
libclass=cls('Class /Script/Engine.KismetMaterialLibrary')
libclass.default=obj(libclass,'KismetMaterialLibrary default')
function libclass.default:CreateDynamicMaterialInstance(world,parent,instance_name,flags)
 guard();assert(world==pawn and parent==material and name(instance_name)=='None')
 if ctx.fail_mid then return nil end
 mid=obj(midclass,'MaterialInstanceDynamic mid'..ctx.created,{},pawn);mid.scalars={};mid.vectors={}
 function mid:SetScalarParameterValue(k,v)guard();self.scalars[name(k)]=v end
 function mid:K2_GetScalarParameterValue(k)guard();return self.scalars[name(k)] end
 function mid:SetVectorParameterValue(k,v)guard();self.vectors[name(k)]=v end
 function mid:K2_GetVectorParameterValue(k)guard();return ctx.fail_color and {R=1,G=1,B=1,A=1} or self.vectors[name(k)] end
 return mid
end
gsclass=cls('Class /Script/Engine.GameplayStatics');gsclass.default=obj(gsclass,'GameplayStatics default')
function gsclass.default:IsGamePaused()guard();return ctx.paused==true end
uevr={api={},types={UObjectHook={exists=function(o)guard();return o~=nil and o.live end}},
 params={vr={is_runtime_ready=function()return ctx.ready end,is_hmd_active=function()return ctx.ready end},
 functions={is_drawing_ui=function()return ctx.drawing==true end,log_info=function(s)ctx.log=s end}}}
function uevr.api:get_engine()guard();return engine end
function uevr.api:find_uobject(n)guard();local o=ctx.objects[n];return o and o.live and o or nil end
function uevr.api:get_local_pawn()guard();return pawn end
function uevr.api:get_player_controller()guard();return pc end
function uevr.api:add_component_by_class(owner,c)
 guard();assert(owner==pawn and c==partclass);ctx.created=ctx.created+1
 part=obj(partclass,'PostProcessComponent pawn.Comfort'..ctx.created,
 {bEnabled=true,bUnbound=false,BlendWeight=1,Priority=0},pawn)
 function part:AddOrUpdateBlendable(m,w)guard();assert(m==mid);self.blend=m;self.weight=w;if ctx.fail_blend then error('blend failed') end end
 return part
end
fs={read=function()return ctx.journal end,write=function(_,s)if not ctx.fail_write then ctx.journal=s end end}
function tick()ctx.thread=true;comfort:step(pawn,ctx.enabled);ctx.thread=false end
'''


class ComfortTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(FIXTURE)
        self.lua.globals().module = self.lua.execute(SOURCE.read_text(encoding='utf-8'))
        self.lua.execute('comfort=module.new(uevr)')

    def run_lua(self, code):
        return self.lua.execute(code)

    def value(self, code):
        return self.lua.eval(code)

    def test_creates_owned_postprocess_and_only_suppresses_exact_effects(self):
        self.run_lua('tick()')
        self.assertEqual(self.value('ctx.created'), 1)
        self.assertEqual(self.value('blood.opacity'), 0)
        self.assertEqual(self.value('pulse.opacity'), 0)
        self.assertEqual(self.value('splatter.opacity'), 0)
        self.assertIsNone(self.value('manager.opacity'))
        self.assertIsNone(self.value('slop.opacity'))
        self.assertIsNone(self.value('root.opacity'))
        self.assertEqual(self.value('mid.scalars.STR'), 0)
        self.assertEqual(self.value('mid.scalars["Distort-X"]'), 0)
        self.assertEqual(self.value('mid.vectors.Color.R'), .35)

    def test_damage_pulse_and_low_health_are_bounded_and_center_not_tinted_globally(self):
        self.run_lua('tick();pawn.props.CurrentHealth=20;pulse.props.AccruedDamage=30;tick()')
        self.assertGreater(self.value('mid.scalars.STR'), 0)
        self.assertLessEqual(self.value('mid.scalars.STR'), .08)
        self.assertEqual(self.value('part.weight'), 1)

    def test_active_blood_splatter_produces_halo_without_health_damage(self):
        self.run_lua('effect=obj(cls("Effect",{IsActive=true}),"W_ScreenEffect_Element_C active",{IsActive=true});'
                     'splatter.props.ActiveEffects={effect};tick()')
        self.assertAlmostEqual(self.value('mid.scalars.STR'), .02)
        self.run_lua('effect.props.IsActive=false;tick()')
        self.assertEqual(self.value('mid.scalars.STR'), 0)

    def test_gates_restore_original_opacity_and_destroy_owned_component(self):
        for gate in ('ctx.enabled=false', 'ctx.menu=true', 'ctx.ready=false',
                     'ctx.paused=true', 'ctx.drawing=true', 'pawn.props.bPlayerFinishedLevelLoad=false'):
            with self.subTest(gate=gate):
                self.setUp()
                self.run_lua('blood.opacity=.7;pulse.opacity=.8;splatter.opacity=.9;tick();'+gate+';tick()')
                self.assertAlmostEqual(self.value('blood.opacity'), .7)
                self.assertAlmostEqual(self.value('pulse.opacity'), .8)
                self.assertAlmostEqual(self.value('splatter.opacity'), .9)
                self.assertEqual(self.value('ctx.destroyed'), 1)
                self.assertEqual(self.value('ctx.journal'), '')

    def test_death_suppresses_only_blood_with_halo_off(self):
        self.run_lua('tick();ctx.dead=true;tick()')
        self.assertEqual(self.value('mid.scalars.STR'), 0)
        self.assertEqual(self.value('blood.opacity'), 0)

    def test_wrong_widget_path_or_missing_function_leaves_hud_untouched(self):
        for change in ('blood.name="CanvasPanel root.WidgetTree.Unrelated"',
                       'splatter.props.ScreenEffectData=cls("OtherData")',
                       'splatter.name="W_ScreenEffect_System_C manager.WidgetTree.W_ScreenEffect_SlopManager"',
                       'ctx.missing_function="AddOrUpdateBlendable"', 'ctx.fail_mid=true', 'ctx.fail_blend=true',
                       'ctx.fail_color=true'):
            with self.subTest(change=change):
                self.setUp()
                self.run_lua(change+';tick()')
                self.assertIsNone(self.value('blood.opacity'))
                self.assertIsNone(self.value('root.opacity'))

    def test_journal_write_failure_prevents_widget_mutation(self):
        self.run_lua('ctx.fail_write=true;tick()')
        self.assertIsNone(self.value('blood.opacity'))
        self.assertTrue(self.value('comfort.stopped'))

    def test_reset_is_pure_lua_and_new_instance_recovers_before_reallocating(self):
        self.run_lua('blood.opacity=.6;tick();comfort:stop()')
        self.assertEqual(self.value('ctx.destroyed'), 0)
        self.run_lua('comfort=module.new(uevr);ctx.enabled=false;tick()')
        self.assertEqual(self.value('ctx.destroyed'), 1)
        self.assertAlmostEqual(self.value('blood.opacity'), .6)
        self.assertEqual(self.value('ctx.created'), 1)

    def test_foreign_opacity_is_preserved_on_cleanup(self):
        self.run_lua('tick();blood.opacity=.4;ctx.enabled=false;tick()')
        self.assertAlmostEqual(self.value('blood.opacity'), .4)

    def test_reused_address_or_name_does_not_claim_another_component(self):
        self.run_lua('tick();comfort:stop();part.address=part.address+1;comfort=module.new(uevr);tick()')
        self.assertTrue(self.value('comfort.stopped'))
        self.assertEqual(self.value('ctx.destroyed'), 0)
        self.assertNotEqual(self.value('ctx.journal'), '')

    def test_invalid_health_fails_without_hiding_hud(self):
        self.run_lua('pawn.props.CurrentHealth=0/0;tick()')
        self.assertIsNone(self.value('blood.opacity'))

    def test_fixed_assetdata_loader_handles_unloaded_postprocess_material(self):
        self.run_lua(r'''
        ctx.objects[material.name]=nil
        descriptor=cls('ScriptStruct /Script/CoreUObject.AssetData',
          {ObjectPath=true,PackageName=true,PackagePath=true,AssetName=true,AssetClass=true})
        function descriptor:as_struct()guard();return self end
        StructObject={new=function(desc)
          guard();assert(desc==descriptor)
          return {set_property=function(self,k,v)guard();self[k]=v.fname end}
        end}
        stringclass=cls('Class /Script/Engine.KismetStringLibrary')
        stringclass.default=obj(stringclass,'KismetStringLibrary default')
        function stringclass.default:Conv_StringToName(s)guard();return {fname=s} end
        registryclass=cls('Class /Script/AssetRegistry.AssetRegistryHelpers')
        registryclass.default=obj(registryclass,'AssetRegistryHelpers default')
        function registryclass.default:IsValid(data)
          guard();assert(data.AssetClass=='Material');return true
        end
        function registryclass.default:GetAsset(data)
          guard();assert(data.ObjectPath==material.name:match('^Material (.+)$'))
          ctx.loaded_asset=data;return material
        end
        tick()
        ''')
        self.assertEqual(self.value('ctx.loaded_asset.AssetName'), 'M_PP_PickUp_Flash')
        self.assertEqual(self.value('ctx.created'), 1)
        self.assertEqual(self.value('splatter.opacity'), 0)

    def test_splatter_identity_is_rechecked_before_restoration(self):
        self.run_lua('tick();comfort:stop();splatter.props.ScreenEffectData=slop;'
                     'comfort=module.new(uevr);tick()')
        self.assertTrue(self.value('comfort.stopped'))
        self.assertEqual(self.value('ctx.destroyed'), 0)
        self.assertNotEqual(self.value('ctx.journal'), '')

    def test_disabled_adapter_never_allocates(self):
        self.run_lua('ctx.enabled=false;tick()')
        self.assertEqual(self.value('ctx.created'), 0)

    def test_corrupt_journal_blocks_all_allocation(self):
        self.run_lua('ctx.journal="broken";tick()')
        self.assertEqual(self.value('ctx.created'), 0)
        self.assertEqual(self.value('ctx.journal'), 'broken')

    def test_other_engine_session_drops_journal_without_mutating_surviving_objects(self):
        self.run_lua('tick();comfort:stop();engine.address=engine.address+1;'
                     'comfort=module.new(uevr);ctx.enabled=false;tick()')
        self.assertEqual(self.value('ctx.destroyed'), 0)
        self.assertEqual(self.value('ctx.journal'), '')

    def test_foreign_component_owner_blocks_recovery(self):
        self.run_lua('tick();comfort:stop();part.outer=pc;comfort=module.new(uevr);tick()')
        self.assertEqual(self.value('ctx.destroyed'), 0)
        self.assertTrue(self.value('comfort.stopped'))
        self.assertNotEqual(self.value('ctx.journal'), '')

    def test_menu_reentry_creates_one_fresh_effect_and_no_component_leak(self):
        self.run_lua('tick();ctx.menu=true;tick();ctx.menu=false;tick();tick()')
        self.assertEqual(self.value('ctx.created'), 2)
        self.assertEqual(self.value('ctx.destroyed'), 1)


if __name__ == '__main__':
    unittest.main()
