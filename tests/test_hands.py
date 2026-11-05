"""Exercise the actual hand owner with an engine-thread-only Unreal boundary."""
import unittest
from pathlib import Path
import test_bolter_preview as base

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'src/lua/boltgun_hands.lua'


class HandsTests(unittest.TestCase):
    def setUp(self):
        fixture = base.BolterPreviewTests()
        fixture.reload = lambda: None
        fixture.setUp()
        self.lua, self.tick = fixture.lua, fixture.tick
        self.lua.execute(r'''
        ctx.engine_thread=true
        ctx.dead=false;ctx.loaded=true;ctx.paused=false;ctx.game_menu=false
        pawn.get_full_name=function()engine_only();return 'BP_PlayerCharacter_Sternguard_C /Game/Maps/Test.Test.PersistentLevel.BP_PlayerCharacter_Sternguard_C_1' end
        registry[pawn:get_full_name()]=pawn
        pawn.IsDead=function()engine_only();return ctx.dead end
        local pawn_property=pawn.get_property
        pawn.get_property=function(self,k)
          if k=='bPlayerFinishedLevelLoad' then engine_only();return ctx.loaded end
          return pawn_property(self,k)
        end
        controller=object('Controller test',1300,class('Controller'))
        hud=object('HUD test',1301,class('HUD'),controller)
        menu=object('Menu test',1302,class('Widget'),hud)
        controller.get_property=function()engine_only();return hud end
        hud.get_property=function()engine_only();return ctx.game_menu and menu or nil end
        menu.IsInViewport=function()engine_only();return true end
        menu.IsVisible=function()engine_only();return true end
        uevr.api.get_player_controller=function()engine_only();return controller end
        gs_class=class('Class /Script/Engine.GameplayStatics')
        gs=object('Default__GameplayStatics',1303,gs_class)
        gs.IsGamePaused=function()engine_only();return ctx.paused end
        gs_class.get_class_default_object=function()engine_only();return gs end
        proc_class=class('Class /Script/ProceduralMeshComponent.ProceduralMeshComponent')
        local function visual(name,address,cls,owner)
          local part=object(name,address,cls,owner)
          part.get_property=primary.get_property;part.hidden=false;part.visible=true
          return part
        end
        sword=visual('Sword preview',1310,proc_class,pawn)
        gun=visual('Firearm preview',1311,mesh_class,pawn)
        uevr.boltgun_weapon_grips={
          left=function(owner) engine_only();assert(owner==pawn);return sword,2.4,0,0,1 end,
          right=function(owner) engine_only();assert(owner==pawn);return gun,-48,2,24,.5 end}
        math_class=class('Class /Script/Engine.KismetMathLibrary')
        math_library=object('Default__KismetMathLibrary',1312,math_class)
        math_class.get_class_default_object=function()engine_only();return math_library end
        math_library.NegateRotator=function(self,r)
          engine_only();assert(r.Yaw==0 and r.Roll==0)
          return {Pitch=-r.Pitch,Yaw=0,Roll=0}
        end
        math_library.LessLess_VectorRotator=function(self,v,r)
          engine_only();assert(r.Yaw==0 and r.Roll==0)
          local s,c=math.sin(math.rad(r.Pitch)),math.cos(math.rad(r.Pitch))
          return {x=c*v.X+s*v.Z,y=v.Y,z=-s*v.X+c*v.Z}
        end
        material.get_full_name=function()engine_only();return 'MaterialInstanceConstant /Game/Art/Pickups/Powerups/Materials/MI_Pickups_Boltgun.MI_Pickups_Boltgun' end
        texture=object('Texture2D test.palette',1304,class('Class /Script/Engine.Texture2D'))
        texture.Blueprint_GetSizeX=function()engine_only();return ctx.texture_width or 256 end
        texture.Blueprint_GetSizeY=function()engine_only();return ctx.texture_height or 256 end
        rendering_class=class('Class /Script/Engine.KismetRenderingLibrary')
        rendering=object('Default__KismetRenderingLibrary',1305,rendering_class)
        rendering.ImportFileAsTexture2D=function(self,owner,path)
          engine_only();ctx.imports=(ctx.imports or 0)+1;ctx.import_path=path
          return not ctx.fail_texture and texture or nil
        end
        rendering_class.get_class_default_object=function()engine_only();return rendering end
        local find=uevr.api.find_uobject
        uevr.api.find_uobject=function(self,name)
          engine_only()
          if name=='Class /Script/Engine.GameplayStatics' then return gs_class end
          if name=='Class /Script/ProceduralMeshComponent.ProceduralMeshComponent' then return proc_class end
          if name=='Class /Script/Engine.KismetRenderingLibrary' then return rendering_class end
          if name=='Class /Script/Engine.KismetMathLibrary' then
            ctx.math_lookups=(ctx.math_lookups or 0)+1
            return not ctx.no_trim_math and math_class or nil
          end
          return find(self,name)
        end
        uevr.api.add_component_by_class=function(self,owner,cls,deferred)
          engine_only();assert(cls==proc_class and deferred==false)
          local c=new_component(owner);c.sections=0
          c.get_class=function()engine_only();return proc_class end
          c.GetNumSections=function(self)engine_only();return self.sections end
          c.GetAttachParent=function(self)engine_only();return self.parent end
          c.K2_AttachToComponent=function(self,parent,socket,location,rotation,scale,weld)
            engine_only()
            assert(parent.valid and socket.name=='None' and location==0 and rotation==0 and scale==0 and weld==false)
            assert(self.hidden and not self.visible)
            if not ctx.fail_attach then self.parent=parent;return true end
            return false
          end
          c.K2_DetachFromComponent=function(self,location,rotation,scale,modify)
            engine_only();assert(location==0 and rotation==0 and scale==0 and modify==false)
            assert(self.hidden and not self.visible);self.parent=nil
          end
          c.K2_SetRelativeLocationAndRotation=function(self,p,r,sweep,hit,teleport)
            engine_only();assert(not sweep and teleport and self.parent)
            self.location=p;self.rotation=r
          end
          c.CreateDynamicMaterialInstance=function(self,slot,source,name)
            engine_only();assert(slot==0 and source==material)
            local dmi=object('DMI hand',1400+ctx.created,class('DMI'),c)
            dmi.SetTextureParameterValue=function(self,k,value)
              engine_only();assert(k.name=='BC')
              if not ctx.fail_binding and ctx.fail_binding_hand~=ctx.created then self.texture=value end
            end
            dmi.K2_GetTextureParameterValue=function(self,k)engine_only();assert(k.name=='BC');return self.texture end
            c.material=dmi;return dmi
          end
          return c
        end
        uevr.params.functions.dispatch_custom_event=function(name,data)
          engine_only();assert(name=='boltgun.hands.v1')
          local owner,component,hand=data:match('^(%d+)|(%d+)|([01])$')
          assert(owner=='1001' and component and hand)
          table.insert(ctx.events,{name=name,data=data})
          if not ctx.no_plugin then ctx.components[ctx.created].sections=1 end
          files['hands3d.texture_path']=ctx.texture_path or 'E:/Temporary Profile/data/hands3d/hands_color.png'
        end
        secondary.get_short_name=function()engine_only();return 'Secondary Render Plane' end
        secondary.get_property=primary.get_property
        secondary.SetHiddenInGame=primary.SetHiddenInGame
        secondary.SetVisibility=primary.SetVisibility
        registry[secondary:get_full_name()]=secondary
        registry[renderer:get_full_name()]=renderer
        regular=object('MaterialInstanceConstant /Game/Unrelated.Arms',1500,class('MIC'))
        regular.get_class=function()engine_only();return {find_function=function()engine_only();return nil end,find_property=function()engine_only();return {} end} end
        regular.get_property=function()engine_only();return nil end
        primary.GetMaterial=function()engine_only();return ctx.primary_material or regular end
        secondary.GetMaterial=function()engine_only();return ctx.secondary_material or regular end
        function death_material(sequence,frame)
          local stem='MI_Arms_Death'..sequence..'_'..frame
          local m=object('MaterialInstanceConstant /Game/Art/Animations/Player/Deaths/Death'..sequence..'/'..stem..'.'..stem,1550,class('MIC'))
          m.get_class=regular.get_class
          m.get_property=function()engine_only();return nil end;return m
        end
        uevr.params.vr.is_runtime_ready=function()return ctx.runtime~=false end
        uevr.params.vr.is_aim_allowed=function()return ctx.aim~=false end
        ctx.queries=0;ctx.engine_thread=false
        ''')
        self.reload()

    def reload(self):
        self.assertTrue(SOURCE.exists(), 'Hands implementation missing')
        self.lua.execute(SOURCE.read_text(encoding='utf-8'))

    def value(self, expr):
        return self.lua.eval(expr)

    def run_lua(self, code):
        self.lua.execute(code)

    def start(self):
        for _ in range(4):
            self.tick(1)

    def test_load_and_reset_do_not_access_unreal(self):
        self.assertEqual(self.value('ctx.queries'), 0)
        self.start()
        queries = self.value('ctx.queries')
        self.run_lua('reset()')
        self.assertEqual(self.value('ctx.queries'), queries)

    def test_both_real_components_attach_to_their_visible_weapons_without_mc_states(self):
        self.start()
        self.assertEqual(self.value('ctx.created'), 2)
        self.assertTrue(self.value('ctx.components[1].parent==sword and ctx.components[2].parent==gun'))
        self.assertEqual(self.value('ctx.attached'), 0)
        self.assertTrue(self.value('ctx.components[1].visible and ctx.components[2].visible'))
        self.assertFalse(self.value('primary.hidden or secondary.hidden'))
        self.assertEqual(self.value('ctx.components[1].collision'), 0)
        self.assertFalse(self.value('ctx.components[1].shadow'))

    def test_death_hides_hands_and_only_proven_death_arms(self):
        self.start()
        self.run_lua("ctx.dead=true;ctx.primary_material=death_material('01','01')")
        self.tick()
        self.assertFalse(self.value('ctx.components[1].visible or ctx.components[2].visible'))
        self.assertTrue(self.value('primary.hidden'))
        self.assertFalse(self.value('secondary.hidden'))
        self.run_lua('ctx.dead=false;ctx.primary_material=regular')
        self.tick()
        self.assertFalse(self.value('primary.hidden'))
        self.assertTrue(self.value('ctx.components[1].visible'))

    def test_loading_pause_ui_and_tracking_loss_hide_both(self):
        self.start()
        for key in ('loaded', 'hmd', 'controllers', 'runtime', 'aim'):
            with self.subTest(key=key):
                self.run_lua(f'ctx.{key}=false')
                self.tick()
                self.assertFalse(self.value('ctx.components[1].visible or ctx.components[2].visible'))
                self.run_lua(f'ctx.{key}=true')
                self.tick()
        for key in ('paused', 'game_menu', 'menu'):
            with self.subTest(key=key):
                self.run_lua(f'ctx.{key}=true')
                self.tick()
                self.assertFalse(self.value('ctx.components[1].visible or ctx.components[2].visible'))
                self.run_lua(f'ctx.{key}=false')
                self.tick()

    def test_missing_bridge_never_shows_empty_geometry(self):
        self.run_lua('ctx.no_plugin=true')
        self.start()
        self.assertEqual(self.value('ctx.created'), self.value('ctx.destroyed'))
        self.assertFalse(self.value('primary.hidden or secondary.hidden'))

    def test_reload_recovers_exact_owned_pair_and_death_flags(self):
        self.start()
        self.run_lua("ctx.primary_material=death_material('02','09');ctx.dead=true")
        self.tick()
        self.run_lua('reset();ctx.primary_material=regular;ctx.dead=false')
        self.reload()
        self.start()
        self.assertEqual(self.value('ctx.destroyed'), 2)
        self.assertEqual(self.value('ctx.created'), 4)
        self.assertFalse(self.value('primary.hidden'))

    def test_foreign_component_is_not_mutated_or_duplicated(self):
        self.start()
        self.run_lua('ctx.components[1].get_outer=function()engine_only();return renderer end')
        self.tick()
        self.assertEqual(self.value('ctx.created'), 2)
        self.assertTrue(self.value("#files['hands3d.owned']>0"))

    def test_lookalike_death_names_and_unknown_frames_are_untouched(self):
        self.start()
        for sequence, frame in (('00','01'), ('01','08'), ('03','10')):
            self.run_lua(f"ctx.dead=true;ctx.primary_material=death_material('{sequence}','{frame}')")
            self.tick()
            self.assertFalse(self.value('primary.hidden'))
        self.assertFalse(self.value('ctx.components[1].visible'))
        self.run_lua("ctx.primary_material=death_material('03','09')")
        self.tick()
        self.assertTrue(self.value('primary.hidden'))

    def test_all_catalogued_death_frames_are_suppressed(self):
        self.start()
        for sequence, count in ((1, 7), (2, 9), (3, 9)):
            for frame in range(1, count+1):
                self.run_lua(f"ctx.secondary_material=death_material('{sequence:02}','{frame:02}')")
                self.tick()
                self.assertTrue(self.value('secondary.hidden'))
        self.assertFalse(self.value('primary.hidden'))

    def test_dynamic_material_matches_exact_bc_texture(self):
        self.start()
        self.run_lua('''
        dynamic=object('MaterialInstanceDynamic test.death',1600,class('DMI'))
        dynamic.get_property=function()engine_only();return nil end
        dynamic.K2_GetTextureParameterValue=function()
          engine_only()
          return object('Texture2D /Game/Art/Animations/Player/Deaths/Death02/T_Arms_Death02_01_BC.T_Arms_Death02_01_BC',1601,class('Texture2D'))
        end
        ctx.primary_material=dynamic
        ''')
        self.tick()
        self.assertTrue(self.value('primary.hidden'))

    def test_death_comfort_survives_missing_geometry_bridge(self):
        self.run_lua('ctx.no_plugin=true')
        self.start()
        self.run_lua("ctx.primary_material=death_material('01','01');ctx.dead=true")
        self.tick()
        self.assertTrue(self.value('primary.hidden'))
        self.assertEqual(self.value('ctx.created'), self.value('ctx.destroyed'))

    def test_death_renderer_on_previous_pawn_survives_dead_pawn_possession(self):
        self.start()
        self.run_lua('''
        dead_pawn=object('BP_DeadPlayerPawn_C /Game/Maps/Test.Test.PersistentLevel.BP_DeadPlayerPawn_C_1',1603,class('DeadPawn'))
        uevr.api.get_local_pawn=function()engine_only();return dead_pawn end
        ctx.primary_material=death_material('03','01')
        ''')
        self.tick()
        self.assertTrue(self.value('primary.hidden'))
        self.assertEqual(self.value('ctx.destroyed'), 2)
        self.assertEqual(self.value('ctx.created'), 2)

    def test_visibility_restoration_preserves_native_changes(self):
        self.start()
        self.run_lua("ctx.primary_material=death_material('01','01')")
        self.tick()
        self.run_lua('primary.hidden=true;primary.visible=true;ctx.primary_material=regular')
        self.tick()
        self.assertTrue(self.value('primary.hidden and primary.visible'))

    def test_recorded_original_visibility_is_restored(self):
        self.start()
        self.run_lua("primary.hidden=true;primary.visible=true;ctx.primary_material=death_material('01','01')")
        self.tick()
        self.run_lua('ctx.primary_material=regular')
        self.tick()
        self.assertTrue(self.value('primary.hidden and primary.visible'))

    def test_foreign_death_plane_is_not_restored(self):
        self.start()
        self.run_lua("ctx.primary_material=death_material('01','01')")
        self.tick()
        self.run_lua('primary.get_outer=function()engine_only();return pawn end;ctx.primary_material=regular')
        self.tick()
        self.assertTrue(self.value('primary.hidden'))
        self.assertTrue(self.value("#files['hands3d.owned']>0"))

    def test_corrupt_recovery_blocks_duplicate_components(self):
        self.run_lua("files['hands3d.owned']='not a journal'")
        self.start()
        self.assertEqual(self.value('ctx.created'), 0)
        self.assertEqual(self.value("files['hands3d.owned']"), 'not a journal')

    def test_settings_bound_invalid_values_and_apply_both_sides(self):
        self.run_lua("files['hands3d.settings']='scale=99\\nleft_x=3\\nright_y=-4\\nright_pitch=45\\nleft_yaw=nan'")
        self.start()
        self.assertEqual(self.value('ctx.components[1].scale'), 1)
        self.assertEqual(self.value('ctx.components[1].location.Y'), -3)
        self.assertEqual(self.value('ctx.components[1].rotation.Yaw'), 0)
        self.assertEqual(self.value('ctx.components[2].rotation.Pitch'), -45)

    def test_texture_failure_removes_partial_pair(self):
        self.run_lua('ctx.fail_texture=true')
        self.start()
        self.assertEqual(self.value('ctx.created'), self.value('ctx.destroyed'))
        self.assertFalse(self.value('primary.hidden or secondary.hidden'))

    def test_imports_dedicated_color_atlas_once_and_binds_both_hands(self):
        self.run_lua(r"ctx.texture_path='E:\\Temporary Profile\\data\\hands3d\\hands_color.png'")
        self.start()
        self.assertEqual(self.value('ctx.imports'), 1)
        self.assertEqual(self.value('ctx.import_path'), 'E:/Temporary Profile/data/hands3d/hands_color.png')
        self.assertTrue(self.value('ctx.components[1].material.texture==texture and ctx.components[2].material.texture==texture'))

    def test_white_placeholder_and_failed_binding_never_show_hands(self):
        for setup in ('ctx.texture_width=1;ctx.texture_height=1', 'ctx.fail_binding=true'):
            with self.subTest(setup=setup):
                self.setUp()
                self.run_lua(setup)
                self.start()
                self.assertEqual(self.value('ctx.created'), self.value('ctx.destroyed'))
                self.assertFalse(self.value('primary.hidden or secondary.hidden'))

    def test_second_hand_binding_failure_rolls_back_first_hand(self):
        self.run_lua('ctx.fail_binding_hand=2')
        self.start()
        self.assertEqual(self.value('ctx.created'), 2)
        self.assertEqual(self.value('ctx.destroyed'), 2)
        self.assertFalse(self.value('ctx.components[1].visible or ctx.components[2].visible'))
        self.assertFalse(self.value('primary.hidden or secondary.hidden'))

    def test_invalid_texture_type_and_unavailable_dimensions_fail_closed(self):
        for setup in ("texture.get_class=function()engine_only();return class('Class /Script/Engine.TextureCube') end",
                      "ctx.missing_function='Blueprint_GetSizeX'", 'ctx.texture_width=0'):
            with self.subTest(setup=setup):
                self.setUp()
                self.run_lua(setup)
                self.start()
                self.assertEqual(self.value('ctx.created'), self.value('ctx.destroyed'))
                self.assertFalse(self.value('primary.hidden or secondary.hidden'))

    def test_texture_hint_rejects_legacy_and_traversal_paths(self):
        for path in ('E:/Profile/data/hands3d_color.png',
                     'E:/Profile/../data/hands3d/hands_color.png',
                     'data/hands3d/hands_color.png',
                     'E:/Profile/data/hands3d/hands_color.png\n'):
            with self.subTest(path=path):
                self.setUp()
                self.lua.globals().ctx.texture_path = path
                self.start()
                self.assertEqual(self.value('ctx.imports or 0'), 0)
                self.assertEqual(self.value('ctx.created'), self.value('ctx.destroyed'))

    def test_grip_origin_uses_applied_mesh_landmark_and_compensates_for_weapon_scale(self):
        self.run_lua(r"""
        files['bolter3d.settings']='scale=.8\nx=3\ny=-4\nz=5\nyaw=90\ngrip_x=-80\ngrip_z=10'
        files['chainsword3d.settings']='x=-2\ny=6\nz=1\nyaw=180'
        """)
        self.start()
        for hand, location, scale in ((1, (2.4, 0, 0), 1), (2, (-48, 2, 24), 2)):
            for axis, want in zip('XYZ', location):
                self.assertEqual(self.value(f'ctx.components[{hand}].location.{axis}'), want)
            self.assertEqual(self.value(f'ctx.components[{hand}].scale'), scale)

    def test_parent_retirement_hides_hand_then_reuses_it_for_replacement(self):
        self.start()
        self.run_lua('''
        ctx.engine_thread=true;uevr.boltgun_weapon_grips.before_destroy(gun);ctx.engine_thread=false
        gun.valid=false
        ''')
        self.assertFalse(self.value('ctx.components[2].visible or ctx.components[2].parent'))
        self.assertTrue(self.value('ctx.components[1].visible'))
        self.tick()
        self.assertFalse(self.value('ctx.components[2].visible'))
        self.run_lua('''
        gun=object('Replacement',1330,mesh_class,pawn)
        gun.get_property=primary.get_property;gun.hidden=false;gun.visible=true
        uevr.boltgun_weapon_grips.right=function()engine_only();return gun,-55,0,20,.4 end
        ''')
        self.tick()
        self.assertTrue(self.value('ctx.components[2].visible and ctx.components[2].parent==gun'))
        self.assertEqual(self.value('ctx.components[2].location.X'), -55)
        self.assertEqual(self.value('ctx.components[2].scale'), 2.5)
        self.assertEqual(self.value('ctx.created'), 2)

    def test_local_trim_composes_after_weapon_frame_without_moving_grip(self):
        self.run_lua(r"files['hands3d.settings']='right_pitch=90'")
        self.start()
        self.assertEqual(self.value('ctx.components[2].rotation.Pitch'), -90)
        for axis, want in zip('XYZ', (-48, 2, 24)):
            self.assertAlmostEqual(self.value(f'ctx.components[2].location.{axis}'), want)
        self.run_lua(r"files['hands3d.settings']='right_pitch=90\nright_z=4\nscale=1.25'")
        self.tick()
        for axis, want in zip('XYZ', (-48, 2, 16)):
            self.assertAlmostEqual(self.value(f'ctx.components[2].location.{axis}'), want)
        self.assertEqual(self.value('ctx.components[2].scale'), 2.5)

    def test_missing_or_foreign_weapon_hides_only_its_hand(self):
        self.start()
        for change in ('gun.hidden=true',
                       'gun.hidden=false;gun.get_outer=function()engine_only();return renderer end',
                       'gun.get_outer=function()engine_only();return pawn end;uevr.boltgun_weapon_grips.right=nil'):
            self.run_lua(change)
            self.tick()
            self.assertFalse(self.value('ctx.components[2].visible'))
            self.assertTrue(self.value('ctx.components[1].visible'))

    def test_zero_rotation_trim_works_without_kismet_math_helpers(self):
        self.run_lua(r"ctx.no_trim_math=true;files['hands3d.settings']='right_y=3'")
        self.start()
        self.assertEqual(self.value('ctx.math_lookups or 0'), 0)
        self.assertTrue(self.value('ctx.components[1].visible and ctx.components[2].visible'))
        self.assertEqual(self.value('ctx.components[2].location.Z'), 18)

    def test_attach_rejection_keeps_hand_hidden_until_it_can_attach(self):
        self.run_lua('ctx.fail_attach=true')
        self.start()
        self.assertFalse(self.value('ctx.components[1].visible or ctx.components[2].visible'))
        self.run_lua('ctx.fail_attach=false')
        self.tick()
        self.assertTrue(self.value('ctx.components[1].visible and ctx.components[2].visible'))

    def test_legacy_recovery_unregisters_without_destroying_pending_mc_targets(self):
        self.start()
        self.run_lua("reset();files['hands3d.owned']=files['hands3d.owned']:gsub('^v2','v1')")
        self.reload()
        self.start()
        self.assertEqual(self.value('ctx.removed'), 2)
        self.assertEqual(self.value('ctx.destroyed'), 0)
        self.assertFalse(self.value('ctx.components[1].visible or ctx.components[2].visible'))
        self.assertTrue(self.value('ctx.components[3].visible and ctx.components[4].visible'))


if __name__ == '__main__':
    unittest.main()
