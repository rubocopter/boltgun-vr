"""External sword lifecycle, ownership and conservative sprite suppression."""
import unittest
from pathlib import Path
import test_bolter_preview as base

SOURCE=Path(__file__).resolve().parents[1]/'src/lua/boltgun_chainsword.lua'

class ChainswordTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(SOURCE.exists(),'Chainsword script is missing')
        fixture=base.BolterPreviewTests();fixture.reload=lambda:None;fixture.setUp()
        self.lua=fixture.lua;self.tick=fixture.tick;self.component=fixture.component
        self.lua.execute('''
        ctx.engine_thread=true
        files['chainsword3d.mode']='preview'
        proc_class=class('Class /Script/ProceduralMeshComponent.ProceduralMeshComponent')
        secondary.get_short_name=function() engine_only();return 'Secondary Render Plane' end
        secondary.hidden=false;secondary.visible=true
        secondary.get_property=primary.get_property
        secondary.SetHiddenInGame=primary.SetHiddenInGame;secondary.SetVisibility=primary.SetVisibility
        registry[secondary:get_full_name()]=secondary
        sprite_class=class('MaterialInstanceConstant')
        sprite_class.find_function=function()engine_only();return nil end
        sprite_mat=object('MaterialInstanceConstant /Game/Art/Animations/Weapons/Chainsword/Idle/MI_Chainsword_Idle_01.MI_Chainsword_Idle_01',1200,sprite_class)
        sprite_mat.get_property=function(self,key)engine_only();assert(key=='Parent');return nil end
        secondary.GetMaterial=function() engine_only();return sprite_mat end
        secondary.sprite_scale={x=1,y=2,z=3}
        local secondary_property=secondary.get_property
        secondary.get_property=function(self,key)
          if key=='RelativeScale3D' then engine_only();return self.sprite_scale end
          return secondary_property(self,key)
        end
        secondary.SetRelativeScale3D=function(self,value)
          engine_only();self.sprite_scale={x=value.X,y=value.Y,z=value.Z}
          ctx.book_writes=(ctx.book_writes or 0)+1
        end
        texture=object('Texture2D test.external',1201,class('Texture2D'))
        rendering_class=class('Class /Script/Engine.KismetRenderingLibrary')
        rendering=object('Default__KismetRenderingLibrary',1202,rendering_class)
        rendering.ImportFileAsTexture2D=function(self,pawn,path)
          engine_only();ctx.imports=(ctx.imports or 0)+1
          return not ctx.fail_texture and texture or nil
        end
        rendering_class.get_class_default_object=function()return rendering end
        material.get_full_name=function()engine_only();return 'MaterialInstanceConstant /Game/Art/Pickups/Powerups/Materials/MI_Pickups_Boltgun.MI_Pickups_Boltgun' end
        dmi=object('MaterialInstanceDynamic test.external',1203,class('MaterialInstanceDynamic'))
        dmi.SetTextureParameterValue=function(self,name,value)engine_only();assert(name.name=='BC');self.texture=value end
        dmi.K2_GetTextureParameterValue=function(self,name)engine_only();return self.texture end
        local find=uevr.api.find_uobject
        uevr.api.find_uobject=function(self,name)
          if name=='Class /Script/ProceduralMeshComponent.ProceduralMeshComponent' then
            engine_only();if ctx.no_proc then return nil end;return proc_class
          end
          if name=='Class /Script/Engine.KismetRenderingLibrary' then engine_only();return rendering_class end
          return find(self,name)
        end
        uevr.api.add_component_by_class=function(self,pawn,cls,deferred)
          engine_only();assert(cls==proc_class);local c=new_component(pawn)
          c.get_class=function()engine_only();return proc_class end
          c.sections=0
          c.GetNumSections=function(self)engine_only();return self.sections end
          c.CreateDynamicMaterialInstance=function(self,slot,source,name)
            engine_only();assert(slot==0 and source==material);return dmi
          end
          return c
        end
        uevr.params.functions.dispatch_custom_event=function(name,data)
          engine_only();assert(name=='boltgun.chainsword.v1')
          if not ctx.no_plugin then ctx.components[ctx.created].sections=1 end
        end
        assets.GetAsset=function(self,data)
          engine_only();ctx.load_calls=ctx.load_calls+1
          assert(data.AssetClass.name=='MaterialInstanceConstant')
          assert(data.ObjectPath.name=='/Game/Art/Pickups/Powerups/Materials/MI_Pickups_Boltgun.MI_Pickups_Boltgun')
          return material
        end
        ctx.queries=0;ctx.engine_thread=false
        ''')
        self.reload()

    def reload(self):self.lua.execute(SOURCE.read_text(encoding='utf-8'))
    def eval(self,code):return self.lua.eval(code)
    def start(self):
        for _ in range(3):self.tick(1)

    def test_load_is_inert_until_engine_tick(self):self.assertEqual(self.eval('ctx.queries'),0)
    def test_left_hand_model_hides_only_sword_sprite(self):
        self.start()
        self.assertEqual(self.eval('ctx.created'),1)
        self.assertEqual(self.component().hand,0)
        self.assertTrue(self.component().visible)
        self.assertTrue(self.eval('secondary.hidden'))
        self.assertFalse(self.eval('primary.hidden'))
        self.assertEqual(self.component().collision,0)
        self.assertFalse(self.component().overlaps)
    def test_no_plugin_keeps_sprite_and_stops_repeated_calls(self):
        self.lua.execute('ctx.no_plugin=true');self.start()
        self.assertFalse(self.eval('secondary.hidden'))
        self.assertEqual(self.eval('ctx.destroyed'),1)
        count=self.eval('ctx.queries')
        for _ in range(50):self.tick(.1)
        self.assertEqual(self.eval('ctx.queries'),count)
    def test_texture_failure_retains_sprite(self):
        self.lua.execute('ctx.fail_texture=true');self.start()
        self.assertFalse(self.eval('secondary.hidden'))
        self.assertEqual(self.eval('ctx.destroyed'),1)
    def test_other_secondary_effect_is_preserved(self):
        self.start()
        self.lua.execute("sprite_mat.get_full_name=function()return 'MaterialInstanceConstant /Game/Dash/MI_Hand' end")
        self.tick(.1)
        self.assertFalse(self.eval('secondary.hidden'))
        self.assertTrue(self.eval('secondary.visible'))
        self.assertFalse(self.component().visible)
        self.assertEqual(self.eval('ctx.destroyed'),0)
    def test_off_restores_sprite_and_destroys_visual(self):
        self.start();self.lua.execute("files['chainsword3d.mode']='off'");self.tick(.3)
        self.assertFalse(self.eval('secondary.hidden'))
        self.assertTrue(self.eval('secondary.visible'))
        self.assertEqual(self.eval('ctx.destroyed'),1)
    def test_reset_makes_no_unreal_calls_then_recovers_on_tick(self):
        self.start();count=self.eval('ctx.queries');self.lua.globals().reset()
        self.assertEqual(self.eval('ctx.queries'),count)
        self.reload();self.start()
        self.assertEqual(self.eval('ctx.destroyed'),1)
        self.assertEqual(self.eval('ctx.created'),2)
    def test_inactive_headset_creates_nothing(self):
        self.lua.execute('ctx.hmd=false');self.start()
        self.assertEqual(self.eval('ctx.created'),0)
    def test_journal_failure_keeps_sprite(self):
        self.lua.execute("local write=fs.write;fs.write=function(k,v)if k~='chainsword3d.owned' then write(k,v)end end")
        self.start();self.assertFalse(self.eval('secondary.hidden'))
        self.assertEqual(self.eval('ctx.destroyed'),1)
    def test_bridge_warmup_precedes_creation(self):
        self.tick(1);self.tick(1)
        self.assertEqual(self.eval('ctx.created'),0)
        self.tick(1);self.assertEqual(self.eval('ctx.created'),1)
    def test_unloaded_material_is_loaded_through_registry(self):
        self.lua.execute('ctx.material_loaded=false');self.start()
        self.assertEqual(self.eval('ctx.load_calls'),1)
        self.assertTrue(self.component().visible)
    def test_absent_procedural_class_retains_sprite(self):
        self.lua.execute('ctx.no_proc=true');self.start()
        self.assertEqual(self.eval('ctx.created'),0)
        self.assertFalse(self.eval('secondary.hidden'))
    def test_engine_visibility_for_another_effect_overrides_idle_snapshot(self):
        self.lua.execute('secondary.hidden=true')
        self.start()
        self.lua.execute("sprite_mat.get_full_name=function()return 'MaterialInstanceConstant /Game/Dash/MI_Hand' end; secondary.hidden=false;secondary.visible=true")
        self.tick(.1)
        self.assertFalse(self.eval('secondary.hidden'))
        self.assertTrue(self.eval('secondary.visible'))

    def book(self):
        self.lua.execute("sprite_mat.get_full_name=function()return 'MaterialInstanceConstant /Game/Art/Animations/Player/Codex/Reading/MI_Arms_Idle_Reading_01.MI_Arms_Idle_Reading_01' end")

    def test_book_scales_only_the_codex_without_accumulating(self):
        self.start();self.book();self.tick(.1)
        self.assertAlmostEqual(self.eval('secondary.sprite_scale.x'),.65)
        self.assertAlmostEqual(self.eval('secondary.sprite_scale.y'),1.3)
        self.assertFalse(self.eval('secondary.hidden'))
        for _ in range(20):self.tick(.1)
        self.assertAlmostEqual(self.eval('secondary.sprite_scale.x'),.65)
        self.assertEqual(self.eval('ctx.book_writes'),1)
        self.assertFalse(self.component().visible)

    def test_leaving_book_restores_original_scale_and_sword(self):
        self.start();self.book();self.tick(.1)
        self.lua.execute("sprite_mat.get_full_name=function()return 'MaterialInstanceConstant /Game/Art/Animations/Weapons/Chainsword/Idle/MI_Chainsword_Idle_01.MI_Chainsword_Idle_01' end")
        self.tick(.1)
        self.assertAlmostEqual(self.eval('secondary.sprite_scale.x'),1)
        self.assertTrue(self.component().visible)
        self.assertTrue(self.eval('secondary.hidden'))

    def test_authored_scale_after_book_is_preserved(self):
        self.start();self.book();self.tick(.1)
        self.lua.execute("sprite_mat.get_full_name=function()return 'MaterialInstanceConstant /Game/Dash/MI_Hand' end;secondary.sprite_scale={x=9,y=8,z=7}")
        self.tick(.1)
        self.assertEqual(self.eval('secondary.sprite_scale.x'),9)

    def test_book_off_and_reset_restore_exact_scale(self):
        self.start();self.book();self.tick(.1)
        before=self.eval('ctx.queries');self.lua.globals().reset()
        self.assertEqual(before,self.eval('ctx.queries'))
        self.reload();self.start()
        self.assertAlmostEqual(self.eval('secondary.sprite_scale.x'),.65)
        self.lua.globals().files['chainsword3d.mode']='off';self.tick(.3)
        self.assertAlmostEqual(self.eval('secondary.sprite_scale.x'),1)
        self.assertAlmostEqual(self.eval('secondary.sprite_scale.y'),2)

    def test_no_book_mutation_without_known_material_and_valid_scale(self):
        self.start()
        self.lua.execute("sprite_mat.get_full_name=function()return 'MaterialInstanceConstant /Game/Art/Animations/Player/Other/MI_Arms_Idle_Reading_01' end")
        self.tick(.1)
        self.assertEqual(self.eval('secondary.sprite_scale.x'),1)
        self.book();self.lua.execute('secondary.sprite_scale={x=0/0,y=1,z=1}')
        self.tick(.1)
        self.assertEqual(self.eval('ctx.book_writes or 0'),0)

    def test_book_journal_failure_never_changes_native_scale(self):
        self.start();self.book()
        self.lua.execute("local write=fs.write;fs.write=function(k,v)if k~='chainsword3d.book' then write(k,v)end end")
        self.tick(.1)
        self.assertEqual(self.eval('secondary.sprite_scale.x'),1)

    def test_native_float_precision_does_not_compound_or_block_restoration(self):
        self.lua.execute('''secondary.sprite_scale={x=374,y=187,z=1}
          secondary.SetRelativeScale3D=function(self,value)
            engine_only()
            local function f(v)return string.unpack('f',string.pack('f',v)) end
            self.sprite_scale={x=f(value.X),y=f(value.Y),z=f(value.Z)}
          end''')
        self.start();self.book()
        for _ in range(12):self.tick(.1)
        self.assertAlmostEqual(self.eval('secondary.sprite_scale.x'),374*.65,places=4)
        self.lua.globals().files['chainsword3d.mode']='off';self.tick(.3)
        self.assertEqual(self.eval('secondary.sprite_scale.x'),374)

    def test_reflected_vector_fallback_and_native_resize_during_book(self):
        self.start();self.book()
        self.lua.execute('''local getter=secondary.get_property
          secondary.get_property=function(self,key)
            if key=='RelativeScale3D' then
              return {get_property=function(_,axis)return self.sprite_scale[axis:lower()] end}
            end
            return getter(self,key)
          end''')
        self.tick(.1)
        self.assertAlmostEqual(self.eval('secondary.sprite_scale.x'),.65)
        self.lua.execute('secondary.sprite_scale={x=4,y=5,z=6}')
        self.tick(.1)
        self.assertAlmostEqual(self.eval('secondary.sprite_scale.x'),2.6)
        self.lua.globals().files['chainsword3d.mode']='off';self.tick(.3)
        self.assertEqual(self.eval('secondary.sprite_scale.x'),4)

if __name__=='__main__':unittest.main()
