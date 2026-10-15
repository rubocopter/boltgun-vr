"""Engine/VR-independent lifecycle checks for the experimental bolter component."""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'src/lua/boltgun_bolter3d.lua'
from lupa.lua54 import LuaRuntime


class BolterPreviewTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
        ctx={queries=0,created=0,destroyed=0,attached=0,removed=0,logs={},
             components={},hmd=true,controllers=true,menu=false,engine_thread=false,
             mesh_loaded=true,material_loaded=true,weapon_name='Bolter',addresses=2000,
             load_calls=0,asset_lookups=0,mesh_load_allowed=true,library_available=true,soft_load_calls=0,
             registry_available=true,struct_available=true,events={}}
        files={['bolter3d.mode']='preview'}
        function engine_only()
          assert(ctx.engine_thread,'Unreal access outside engine tick')
          ctx.queries=ctx.queries+1
        end
        function class(name)
          return {valid=true,get_full_name=function() engine_only(); return name end,
            find_property=function(self,key) engine_only(); return ctx.missing_property~=key and {} or nil end,
            find_function=function(self,key)
              engine_only();if key=='GetBarrelTransform' then return nil end
              return ctx.missing_function~=key and {} or nil
            end,
            get_super_struct=function() engine_only(); return nil end}
        end
        mesh_class=class('Class /Script/Engine.StaticMeshComponent')
        bolter_class=class('BlueprintGeneratedClass /Game/Blueprints/Weapons/Boltgun/BP_Boltgun.BP_Boltgun_C')
        other_class=class('OtherWeapon')
        function object(name,address,klass,outer)
          return {valid=true,get_full_name=function() engine_only(); return name end,
            get_address=function() engine_only(); return address end,
            get_class=function() engine_only(); return klass end,
            get_outer=function() engine_only(); return outer end}
        end
        engine=object('Engine test',1000,class('Engine'))
        pawn=object('Pawn test',1001,class('Pawn'))
        handler=object('Handler test',1002,class('Handler'),pawn)
        weapon=object('Weapon test',1003,bolter_class,handler)
        renderer_class=class('BGWeaponRenderComponent')
        renderer=object('Renderer test',1010,renderer_class,pawn)
        primary=object('StaticMeshComponent test.Primary Render Plane',1011,mesh_class,renderer)
        secondary=object('StaticMeshComponent test.Secondary Render Plane',1012,mesh_class,renderer)
        primary.get_short_name=function() engine_only();return 'Primary Render Plane' end
        primary.hidden=false;primary.visible=true
        secondary.hidden=false;secondary.visible=true
        primary.get_property=function(self,key)
          engine_only()
          if key=='bHiddenInGame' then return self.hidden end
          if key=='bVisible' then return self.visible end
          error('Unexpected sprite property')
        end
        primary.SetHiddenInGame=function(self,value,propagate)
          engine_only();assert(propagate==false);self.hidden=value
        end
        primary.SetVisibility=function(self,value,propagate)
          engine_only();assert(propagate==false);self.visible=value
        end
        renderer.get_property=function(self,key)
          engine_only()
          if key=='PrimaryRenderPlane' then if ctx.sprite_missing then return nil end;return primary end
          if key=='SecondaryRenderPlane' then return secondary end
          error('Unexpected renderer property')
        end
        weapon.get_class=function() engine_only(); return ctx.weapon_name=='Bolter' and bolter_class or other_class end
        pawn.get_property=function(self,key)
          engine_only()
          if key=='WeaponHandlerComponent' then return handler end
          if key=='WeaponRenderer' then return renderer end
          error('Unexpected pawn property')
        end
        handler.get_property=function(self,key)
          engine_only(); assert(key=='EquippedWeapon'); return weapon
        end
        mesh=object('Mesh test',1004,class('StaticMesh'))
        material=object('Material test',1005,class('MaterialInstanceConstant'))
        mesh.get_full_name=function() engine_only();return 'StaticMesh /Game/Art/Pickups/Weapons/M_Pickups_Boltgun.M_Pickups_Boltgun' end
        system_class=class('Class /Script/Engine.KismetSystemLibrary')
        system_class.find_function=function(self,key)
          engine_only();if ctx.library_function_missing==key then return nil end
          return {}
        end
        system=object('Default__KismetSystemLibrary',1006,system_class)
        system.MakeSoftObjectPath=function(self,path)
          engine_only();return {path=path}
        end
        system.LoadAsset_Blocking=function(self,soft)
          -- Match the installed UEVR bridge: SoftObjectProperty is not copied.
          engine_only();ctx.soft_load_calls=ctx.soft_load_calls+1
          return nil
        end
        system_class.get_class_default_object=function()
          engine_only();return ctx.library_available and system or nil
        end
        asset_struct=class('ScriptStruct /Script/CoreUObject.AssetData')
        asset_struct.find_property=function(self,key)
          engine_only();if ctx.asset_field_missing==key then return nil end
          return {}
        end
        -- find_uobject only casts UClass automatically. ScriptStructs arrive
        -- as generic UObjects without find_property, exactly as in UEVR.
        asset_descriptor=object('ScriptStruct /Script/CoreUObject.AssetData',1009,class('UScriptStruct'))
        asset_descriptor.as_struct=function()
          engine_only();if ctx.cast_failed then return nil end;return asset_struct
        end
        StructObject={new=function(desc)
          engine_only();assert(desc==asset_struct)
          return {set_property=function(self,key,value) engine_only();self[key]=value end}
        end}
        strings_class=class('Class /Script/Engine.KismetStringLibrary')
        strings_class.find_function=function(self,key)
          engine_only();if ctx.library_function_missing==key then return nil end
          return {}
        end
        strings=object('Default__KismetStringLibrary',1007,strings_class)
        strings.Conv_StringToName=function(self,value) engine_only();return {name=value} end
        strings_class.get_class_default_object=function() engine_only();return strings end
        assets_class=class('Class /Script/AssetRegistry.AssetRegistryHelpers')
        assets_class.find_function=function(self,key)
          engine_only();if ctx.registry_function_missing==key then return nil end
          return {}
        end
        assets=object('Default__AssetRegistryHelpers',1008,assets_class)
        assets_class.get_class_default_object=function()
          engine_only();if ctx.registry_default_missing then return nil end;return assets
        end
        assets.IsValid=function(self,data) engine_only();return not ctx.asset_invalid end
        assets.GetAsset=function(self,data)
          engine_only();ctx.load_calls=ctx.load_calls+1
          assert(data.ObjectPath.name=='/Game/Art/Pickups/Weapons/M_Pickups_Boltgun.M_Pickups_Boltgun')
          assert(data.PackageName.name=='/Game/Art/Pickups/Weapons/M_Pickups_Boltgun')
          assert(data.PackagePath.name=='/Game/Art/Pickups/Weapons')
          assert(data.AssetName.name=='M_Pickups_Boltgun')
          assert(data.AssetClass.name=='StaticMesh')
          if ctx.load_error then error('mock load failure') end
          if ctx.mesh_load_allowed then
            ctx.mesh_loaded=true
            if ctx.unexpected_mesh then return material end
            return mesh
          end
          return nil
        end
        registry={}
        registry['StaticMeshComponent test.Primary Render Plane']=primary
        registry['Pawn test']=pawn
        function new_component(owner)
          engine_only(); ctx.created=ctx.created+1; ctx.addresses=ctx.addresses+1
          local name='StaticMeshComponent test.'..ctx.created
          local c=object(name,ctx.addresses,mesh_class,owner)
          registry[name]=c; table.insert(ctx.components,c)
          c.SetHiddenInGame=function(self,value,propagate) engine_only(); self.hidden=value end
          c.SetVisibility=function(self,value,propagate) engine_only(); self.visible=value end
          c.SetCollisionEnabled=function(self,value) engine_only(); self.collision=value end
          c.SetGenerateOverlapEvents=function(self,value) engine_only(); self.overlaps=value end
          c.SetMobility=function(self,value) engine_only(); self.mobility=value end
          c.SetCastShadow=function(self,value) engine_only(); self.shadow=value end
          c.SetOwnerNoSee=function(self,value) engine_only(); self.owner_no_see=value end
          c.SetOnlyOwnerSee=function(self,value) engine_only(); self.only_owner_see=value end
          c.SetStaticMesh=function(self,value) engine_only(); self.mesh=value; return not ctx.fail_mesh end
          c.SetMaterial=function(self,slot,value) engine_only(); assert(slot==0); self.material=value end
          c.SetRelativeScale3D=function(self,value) engine_only(); self.scale=value.X end
          c.K2_DestroyComponent=function(self,requester)
            engine_only(); assert(requester==owner,'Wrong component owner'); self.valid=false
            ctx.destroyed=ctx.destroyed+1
          end
          return c
        end
        fs={read=function(key) return files[key] or '' end,
          write=function(key,value)
            if ctx.fail_journal and key=='bolter3d.owned' then return end
            files[key]=value
          end}
        UEVR_Vector3f={new=function() return {x=0,y=0,z=0} end}
        UEVR_Quaternionf={new=function() return {x=0,y=0,z=0,w=0} end}
        tick=function() end;reset=function() end
        uevr={api={get_engine=function() engine_only();return engine end,
          get_local_pawn=function() engine_only();return pawn end,
          add_component_by_class=function(self,actor,klass,deferred)
            assert(klass==mesh_class and deferred==false);return new_component(actor)
          end,
          find_uobject=function(self,name)
            engine_only()
            if name=='Class /Script/Engine.StaticMeshComponent' then return mesh_class end
            if name=='Class /Script/Engine.KismetSystemLibrary' then
              return ctx.library_available and system_class or nil
            end
            if name=='Class /Script/Engine.KismetStringLibrary' then
              return ctx.library_available and strings_class or nil
            end
            if name=='Class /Script/AssetRegistry.AssetRegistryHelpers' then
              return ctx.registry_available and assets_class or nil
            end
            if name=='ScriptStruct /Script/CoreUObject.AssetData' then
              return ctx.struct_available and asset_descriptor or nil
            end
             if name:find('StaticMesh /Game/',1,true) then
               ctx.asset_lookups=ctx.asset_lookups+1
               return ctx.mesh_loaded and mesh or nil
             end
            if name:find('MaterialInstanceConstant /Game/',1,true) then return ctx.material_loaded and material or nil end
            return registry[name]
          end},
          types={UObjectHook={exists=function(o) engine_only();return o~=nil and o.valid==true end,
            get_or_add_motion_controller_state=function(c)
              engine_only();assert(c.valid)
              if ctx.fail_hook then return nil end
              ctx.attached=ctx.attached+1
              return {set_hand=function(self,value) engine_only();c.hand=value end,
                set_permanent=function(self,value) engine_only();c.permanent=value end,
                set_location_offset=function(self,value) engine_only();c.offset=value end,
                set_rotation_offset=function(self,value) engine_only();c.rotation=value end}
            end,
            remove_motion_controller_state=function(c) engine_only();ctx.removed=ctx.removed+1 end}},
          params={vr={is_hmd_active=function() return ctx.hmd end,
                      is_using_controllers=function() return ctx.controllers end},
            functions={is_drawing_ui=function() return ctx.menu end,
                       dispatch_custom_event=function(name,data)
                         if data~='off' then engine_only() end
                         if ctx.fail_event then error('event failure') end
                         table.insert(ctx.events,{name=name,data=data})
                       end,
                       log_info=function(s) table.insert(ctx.logs,s) end},
            sdk={callbacks={on_pre_engine_tick=function(f) tick=f end,
                            on_script_reset=function(f) reset=f end}}}}
        ''')
        self.reload()

    def reload(self):
        self.lua.execute(SOURCE.read_text(encoding='utf-8') if SOURCE.exists() else '')

    def tick(self, delta=.1):
        ctx=self.lua.globals().ctx
        ctx.engine_thread=True
        try:
            self.lua.globals().tick(None,delta)
        finally:
            ctx.engine_thread=False

    def component(self):
        return self.lua.globals().ctx.components[1]

    def test_no_engine_calls_at_injection_load(self):
        self.assertEqual(self.lua.globals().ctx.queries,0)

    def test_entire_native_firearm_catalog_creates_and_hides_primary_sprite(self):
        catalog = json.loads((ROOT / 'assets/catalog/original_weapon_catalog.json').read_text())
        self.assertEqual(len(catalog), 10)
        for item in catalog:
            with self.subTest(weapon=item['weapon_type']):
                self.setUp()
                klass = 'BlueprintGeneratedClass ' + item['weapon_classes'][0]
                mesh_name = item['mesh_object']
                self.lua.globals().ctx.mesh_loaded = False
                self.lua.execute(f'''weapon.get_class=function() engine_only();return class({json.dumps(klass)}) end
                    mesh.get_full_name=function() engine_only();return {json.dumps(mesh_name)} end
                    assets.GetAsset=function(self,data)
                      engine_only();ctx.load_calls=ctx.load_calls+1
                      assert(data.ObjectPath.name=={json.dumps(mesh_name.split(' ',1)[1])})
                      assert(data.AssetClass.name=='StaticMesh')
                      ctx.mesh_loaded=true;return mesh
                    end''')
                self.tick()
                ctx = self.lua.globals().ctx
                self.assertEqual(ctx.created, 1)
                self.assertEqual(ctx.load_calls, 1)
                self.assertTrue(self.lua.eval('ctx.components[1].mesh == mesh'))
                self.assertTrue(self.component().visible)
                self.assertTrue(self.lua.globals().primary.hidden)
                self.assertFalse(self.lua.globals().primary.visible)
                self.assertEqual(self.component().hand, 1)
                self.assertTrue(self.component().permanent)
                self.assertTrue(any(e.data != 'off' for e in ctx.events.values()))
                self.tick()
                self.assertEqual(ctx.created, 1)

    def test_weapon_swap_replaces_visual_and_restores_sprite_on_off(self):
        self.tick()
        self.assertEqual(self.lua.globals().ctx.created, 1)
        self.lua.execute('''weapon.get_class=function() engine_only();return class(
          'BlueprintGeneratedClass /Game/Blueprints/Weapons/Shotgun/BP_Shotgun.BP_Shotgun_C') end
          mesh.get_full_name=function() engine_only();return
          'StaticMesh /Game/Art/Pickups/Weapons/M_ShotgunPickup.M_ShotgunPickup' end''')
        self.tick(1.1)
        ctx = self.lua.globals().ctx
        self.assertEqual(ctx.destroyed, 1)
        self.assertEqual(ctx.created, 2)
        self.assertTrue(self.lua.globals().primary.hidden)
        self.assertTrue(ctx.components[2].permanent)
        self.lua.globals().files['bolter3d.mode'] = 'off'
        self.tick(1)
        self.assertEqual(ctx.destroyed, 2)
        self.assertFalse(self.lua.globals().primary.hidden)
        self.assertTrue(self.lua.globals().primary.visible)

    def test_creates_one_visual_only_component_for_bolter(self):
        self.tick()
        ctx=self.lua.globals().ctx
        self.assertEqual(ctx.created,1)
        c=self.component()
        self.assertEqual(c.hand,1)
        self.assertTrue(c.permanent)
        self.assertEqual(c.collision,0)
        self.assertFalse(c.overlaps)
        self.assertFalse(c.shadow)
        self.assertEqual(c.mobility,2)
        self.assertTrue(c.visible)
        self.assertFalse(c.hidden)
        self.assertAlmostEqual(c.scale,.5)

    def test_all_firearms_use_separate_recoil_anchor(self):
        catalog = json.loads((ROOT / 'assets/catalog/original_weapon_catalog.json').read_text())
        for item in catalog:
            with self.subTest(weapon=item['weapon_type']):
                self.setUp()
                self.lua.globals().files['bolter3d.settings'] = 'recoil_enabled=1'
                klass = 'BlueprintGeneratedClass ' + item['weapon_classes'][0]
                mesh_name = item['mesh_object']
                self.lua.execute(f"""weapon.get_class=function() engine_only();return class({json.dumps(klass)}) end
                    mesh.get_full_name=function() engine_only();return {json.dumps(mesh_name)} end
                    assets.GetAsset=function() engine_only();return mesh end""")
                self.tick()
                ctx = self.lua.globals().ctx
                self.assertEqual(ctx.created, 2)
                self.assertTrue(ctx.components[1].visible)
                self.assertFalse(ctx.components[2].visible)
                events = [e.data for e in ctx.events.values() if e.data != 'off']
                parts = events[-1].split('|')
                self.assertEqual(len(parts), 14)
                self.assertNotEqual(parts[2], parts[6])
                self.lua.globals().files['bolter3d.mode'] = 'off'
                self.tick(1)
                self.assertEqual(ctx.destroyed, 2)
                self.assertTrue(self.lua.globals().primary.visible)

    def test_bolter_recoil_uses_hidden_stable_muzzle_reference(self):
        self.lua.globals().files['bolter3d.settings']='recoil_enabled=1'
        self.tick()
        ctx=self.lua.globals().ctx
        self.assertEqual(ctx.created,2)
        visual,anchor=ctx.components[1],ctx.components[2]
        self.assertTrue(visual.visible)
        self.assertFalse(anchor.visible)
        self.assertTrue(anchor.hidden)
        self.assertEqual(anchor.scale,visual.scale)
        self.assertEqual(anchor.offset.y,visual.offset.y)
        self.assertEqual(anchor.rotation.w,visual.rotation.w)
        events=[e.data for e in ctx.events.values() if e.name=='boltgun.muzzle.v1' and e.data!='off']
        self.assertEqual(len(events),1)
        parts=events[0].split('|')
        self.assertEqual(parts[:3],['1001','1003','2002'])
        self.assertEqual(parts[6],'2001')
        self.assertEqual(len(parts),14)
        self.assertEqual(self.lua.globals().files['bolter3d.owned'].split('\n')[0],'v3')

    def test_bolter_recoil_cleans_up_both_components_and_recovers(self):
        self.lua.globals().files['bolter3d.settings']='recoil_enabled=1'
        self.tick()
        ctx=self.lua.globals().ctx
        self.reload()
        self.lua.globals().files['bolter3d.mode']='off'
        self.tick()
        self.assertEqual(ctx.destroyed,2)
        self.assertFalse(self.lua.globals().primary.hidden)
        self.assertEqual(self.lua.globals().files['bolter3d.owned'],'')

    def test_bolter_recoil_recovers_anchor_even_if_visible_component_expired(self):
        self.lua.globals().files['bolter3d.settings']='recoil_enabled=1'
        self.tick()
        ctx=self.lua.globals().ctx
        ctx.components[1].valid=False
        self.reload()
        self.lua.globals().files['bolter3d.mode']='off'
        self.tick()
        self.assertEqual(ctx.destroyed,1)
        self.assertFalse(ctx.components[2].valid)
        self.assertFalse(self.lua.globals().primary.hidden)
        self.assertEqual(self.lua.globals().files['bolter3d.owned'],'')

    def test_does_not_duplicate_component_on_repeated_ticks(self):
        for _ in range(10): self.tick()
        self.assertEqual(self.lua.globals().ctx.created,1)

    def test_recoil_can_be_disabled_without_leaving_anchor_or_hidden_sprite(self):
        self.lua.globals().files['bolter3d.settings']='recoil_enabled=1'
        self.tick()
        self.lua.globals().files['bolter3d.settings']='recoil_enabled=0'
        self.tick(1.1)
        ctx=self.lua.globals().ctx
        self.assertEqual(ctx.destroyed,2)
        self.assertEqual(ctx.created,3)
        self.assertTrue(ctx.components[3].visible)
        parts=[e.data for e in ctx.events.values() if e.data!='off'][-1].split('|')
        self.assertEqual(len(parts),6)
        self.lua.globals().files['bolter3d.mode']='off'
        self.tick(1)
        self.assertEqual(ctx.destroyed,3)
        self.assertTrue(self.lua.globals().primary.visible)

    def test_same_weapon_type_new_instance_replaces_visual_and_muzzle_lease(self):
        self.tick()
        self.lua.execute('''
          replacement=object('Weapon replacement',1050,bolter_class,handler)
          replacement.get_class=function() engine_only();return bolter_class end
          handler.get_property=function(self,key)
            engine_only();assert(key=='EquippedWeapon');return replacement
          end
        ''')
        self.tick(1.1)
        ctx=self.lua.globals().ctx
        self.assertEqual(ctx.created,2)
        self.assertEqual(ctx.destroyed,1)
        self.assertTrue(self.lua.globals().primary.hidden)
        self.assertTrue(ctx.components[2].visible)
        leases=[e.data for e in ctx.events.values() if e.name=='boltgun.muzzle.v1' and e.data!='off']
        self.assertEqual(leases[-1].split('|')[1],'1050')

    def test_identical_weapon_class_resolves_profile_only_once_per_instance(self):
        self.lua.execute('''
          ctx.weapon_class_name_reads=0
          bolter_class.get_full_name=function()
            engine_only();ctx.weapon_class_name_reads=ctx.weapon_class_name_reads+1
            return 'BlueprintGeneratedClass /Game/Blueprints/Weapons/Boltgun/BP_Boltgun.BP_Boltgun_C'
          end
        ''')
        self.tick()
        initial=self.lua.globals().ctx.weapon_class_name_reads
        self.assertGreater(initial,0)
        for _ in range(15): self.tick(.1)
        self.assertEqual(self.lua.globals().ctx.weapon_class_name_reads,initial)

    def test_recoil_partial_anchor_creation_failure_removes_both_components(self):
        self.lua.globals().files['bolter3d.settings']='recoil_enabled=1'
        self.lua.execute('''local original=new_component
          new_component=function(owner)
            local c=original(owner)
            if ctx.created==2 then c.SetStaticMesh=function() error('anchor mesh failure') end end
            return c
          end''')
        self.tick()
        ctx=self.lua.globals().ctx
        self.assertEqual(ctx.destroyed,2)
        self.assertTrue(self.lua.globals().primary.visible)
        self.assertEqual(self.lua.globals().files['bolter3d.owned'],'')
        self.assertFalse(any(e.data!='off' for e in ctx.events.values()))

    def test_recoil_recreates_pair_when_anchor_expires(self):
        self.lua.globals().files['bolter3d.settings']='recoil_enabled=1'
        self.tick()
        self.lua.globals().ctx.components[2].valid=False
        self.tick(1.1)
        ctx=self.lua.globals().ctx
        self.assertEqual(ctx.destroyed,1)
        self.assertEqual(ctx.created,4)
        self.assertTrue(ctx.components[3].visible)
        self.assertFalse(ctx.components[4].visible)

    def test_packaged_defaults_enable_bolter_recoil(self):
        self.lua.globals().files['bolter3d.settings']=(ROOT/'profile/defaults/bolter3d.default.settings').read_text()
        self.tick()
        self.assertEqual(self.lua.globals().ctx.created,2)

    def test_foreign_anchor_is_retained_while_owned_visual_and_sprite_restore(self):
        self.lua.globals().files['bolter3d.settings']='recoil_enabled=1'
        self.tick()
        self.lua.execute('''local foreign=object('Foreign pawn',9999,class('Pawn'))
          ctx.components[2].get_outer=function() engine_only();return foreign end
          ctx.components[2].SetHiddenInGame=function() error('foreign mutation') end
          ctx.components[2].SetRelativeScale3D=function() error('foreign mutation') end''')
        self.lua.globals().files['bolter3d.settings']='recoil_enabled=1\nx=5'
        self.tick(.3)
        ctx=self.lua.globals().ctx
        self.assertTrue(self.lua.globals().primary.visible)
        self.assertFalse(ctx.components[1].valid)
        self.assertTrue(ctx.components[2].valid)
        self.assertNotEqual(self.lua.globals().files['bolter3d.owned'],'')
        self.lua.globals().files['bolter3d.mode']='off'
        self.reload()
        self.tick()
        self.assertTrue(self.lua.globals().primary.visible)

    def test_partial_anchor_initialization_and_rollback_failure_recover_both(self):
        self.lua.globals().files['bolter3d.settings']='recoil_enabled=1'
        self.lua.execute('''local original=new_component
          new_component=function(owner)
            local c=original(owner)
            if ctx.created==1 then
              local destroy=c.K2_DestroyComponent
              local failed=false
              c.K2_DestroyComponent=function(self,requester)
                if not failed then failed=true;error('transient rollback failure') end
                return destroy(self,requester)
              end
            else c.SetStaticMesh=function() error('anchor initialization failed') end end
            return c
          end''')
        self.tick()
        self.lua.globals().files['bolter3d.mode']='off'
        self.reload()
        self.tick()
        ctx=self.lua.globals().ctx
        self.assertEqual(ctx.destroyed,2)
        self.assertFalse(ctx.components[2].valid)
        self.assertTrue(self.lua.globals().primary.visible)
        self.assertEqual(self.lua.globals().files['bolter3d.owned'],'')

    def test_foreign_anchor_journal_survives_expired_original_pawn(self):
        self.lua.globals().files['bolter3d.settings']='recoil_enabled=1'
        self.tick()
        self.lua.execute('''local foreign=object('Foreign pawn',9999,class('Pawn'))
          ctx.components[2].get_outer=function() engine_only();return foreign end
          ctx.components[2].SetHiddenInGame=function() error('foreign mutation') end''')
        self.lua.globals().files['bolter3d.mode']='off'
        self.tick(.3)
        journal=self.lua.globals().files['bolter3d.owned']
        self.lua.globals().pawn.valid=False
        self.lua.globals().files['bolter3d.mode']='preview'
        self.reload()
        self.tick()
        self.assertEqual(self.lua.globals().files['bolter3d.owned'],journal)
        self.assertTrue(self.lua.globals().ctx.components[2].valid)
        self.assertEqual(self.lua.globals().ctx.created,2)

    def test_muzzle_heartbeat_publishes_only_the_owned_mesh_and_equipped_weapon(self):
        self.tick()
        event=self.lua.globals().ctx.events[1]
        self.assertIsNotNone(event,'The active model must publish a muzzle heartbeat')
        self.assertEqual(event.name,'boltgun.muzzle.v1')
        values=event.data.split('|')
        self.assertEqual(values[:3],['1001','1003','2001'])
        self.assertAlmostEqual(float(values[3]),67.81414,places=4)
        self.assertAlmostEqual(float(values[5]),53)

    def test_shotgun_uses_its_barrel_and_independent_calibration(self):
        self.lua.execute('''weapon.get_class=function() engine_only();return class(
          'BlueprintGeneratedClass /Game/Blueprints/Weapons/Shotgun/BP_Shotgun.BP_Shotgun_C') end
          mesh.get_full_name=function() engine_only();return
          'StaticMesh /Game/Art/Pickups/Weapons/M_ShotgunPickup.M_ShotgunPickup' end''')
        self.tick()
        values=self.lua.globals().ctx.events[1].data.split('|')
        self.assertAlmostEqual(float(values[3]),84.109,places=3)
        self.assertAlmostEqual(float(values[5]),54.241,places=3)
        self.lua.globals().files['bolter3d.settings']='shotgun_muzzle_z=56\nmuzzle_z=70'
        self.tick(.3)
        ctx=self.lua.globals().ctx
        values=ctx.events[len(ctx.events)].data.split('|')
        self.assertAlmostEqual(float(values[5]),56)

    def test_each_firearm_can_disable_only_its_muzzle_bridge(self):
        self.lua.execute('''weapon.get_class=function() engine_only();return class(
          'BlueprintGeneratedClass /Game/Blueprints/Weapons/Shotgun/BP_Shotgun.BP_Shotgun_C') end
          mesh.get_full_name=function() engine_only();return
          'StaticMesh /Game/Art/Pickups/Weapons/M_ShotgunPickup.M_ShotgunPickup' end''')
        self.lua.globals().files['bolter3d.settings']='shotgun_muzzle_enabled=0'
        self.tick()
        self.assertTrue(self.component().visible)
        self.assertFalse(self.component().permanent)
        self.assertTrue(all(e.data=='off' for e in self.lua.globals().ctx.events.values()))

    def test_reset_revokes_muzzle_without_unreal_access(self):
        self.tick()
        ctx=self.lua.globals().ctx;before=ctx.queries
        self.lua.globals().reset()
        self.assertGreater(len(ctx.events),0,'Reset must revoke the native lease')
        self.assertEqual(ctx.events[len(ctx.events)].data,'off')
        self.assertEqual(ctx.queries,before)

    def test_cleanup_revokes_before_destroying_owned_mesh(self):
        self.tick()
        self.lua.execute('''ctx.components[1].K2_DestroyComponent=function(self,requester)
          engine_only();assert(ctx.events[#ctx.events].data=='off');self.valid=false
          ctx.destroyed=ctx.destroyed+1
        end''')
        self.lua.globals().ctx.weapon_name='Shotgun';self.tick()
        self.assertEqual(self.lua.globals().ctx.destroyed,1)

    def test_muzzle_can_be_disabled_without_disabling_model(self):
        self.lua.globals().files['bolter3d.settings']='muzzle_enabled=0'
        self.tick()
        self.assertTrue(self.component().visible)
        self.assertFalse(self.component().permanent)
        self.assertTrue(all(e.data=='off' for e in self.lua.globals().ctx.events.values()))

    def test_muzzle_event_failure_keeps_visual_and_native_firing_available(self):
        self.lua.globals().ctx.fail_event=True
        self.tick();self.tick()
        self.assertEqual(self.lua.globals().ctx.created,1)
        self.assertEqual(self.lua.globals().ctx.destroyed,0)
        self.assertTrue(self.component().visible)

    def test_missing_dispatch_api_retains_visual_without_native_attachment_contract(self):
        self.lua.globals().uevr.params.functions.dispatch_custom_event=None
        self.tick()
        self.assertTrue(self.component().visible)
        self.assertFalse(self.component().permanent)

    def test_muzzle_heartbeat_does_not_dispatch_every_frame(self):
        self.tick()
        ctx=self.lua.globals().ctx;before=len(ctx.events)
        self.tick(.01);self.tick(.01)
        self.assertEqual(len(ctx.events),before)
        self.tick(.1)
        self.assertEqual(len(ctx.events),before+1)

    def test_loads_original_mesh_once_when_unavailable(self):
        ctx=self.lua.globals().ctx
        ctx.mesh_loaded=False;ctx.material_loaded=False
        self.tick()
        self.assertEqual(ctx.created,1)
        self.assertEqual(ctx.load_calls,1)
        self.assertIsNone(self.component().material)
        self.tick(1)
        self.assertEqual(ctx.load_calls,1)

    def test_missing_material_uses_native_mesh_default(self):
        self.lua.globals().ctx.material_loaded=False
        self.tick()
        self.assertEqual(self.lua.globals().ctx.created,1)
        self.assertIsNone(self.component().material)

    def test_reloads_previously_loaded_mesh_after_switch_and_collection(self):
        ctx = self.lua.globals().ctx
        ctx.mesh_loaded = False
        self.tick()
        self.assertEqual(ctx.load_calls, 1)
        ctx.weapon_name = 'Other'
        self.tick(1)
        self.assertEqual(ctx.destroyed, 1)
        # Unreal can collect the pickup once the owned component is destroyed.
        ctx.mesh_loaded = False
        ctx.weapon_name = 'Bolter'
        self.tick(1)
        self.assertEqual(ctx.load_calls, 2)
        self.assertEqual(ctx.created, 2)
        self.assertTrue(self.lua.globals().primary.hidden)
        self.assertTrue(ctx.components[2].visible)
        self.tick(1)
        self.assertEqual(ctx.load_calls, 2)

    def test_reloads_collected_mesh_after_uevr_menu(self):
        ctx = self.lua.globals().ctx
        ctx.mesh_loaded = False
        self.tick()
        ctx.menu = True
        self.tick(1)
        self.assertEqual(ctx.destroyed, 1)
        ctx.mesh_loaded = False
        ctx.menu = False
        self.tick(1)
        self.assertEqual(ctx.load_calls, 2)
        self.assertEqual(ctx.created, 2)
        self.assertTrue(self.lua.globals().primary.hidden)

    def test_entire_arsenal_reloads_after_repeated_switches_and_collection(self):
        catalog = json.loads((ROOT / 'assets/catalog/original_weapon_catalog.json').read_text())
        self.lua.execute('''
          weapon.get_class=function() engine_only();return class(ctx.active_class) end
          mesh.get_full_name=function() engine_only();return ctx.active_mesh end
          assets.GetAsset=function(self,data)
            engine_only();ctx.load_calls=ctx.load_calls+1
            assert(data.ObjectPath.name==ctx.active_mesh:match('^StaticMesh (.+)$'))
            assert(data.AssetClass.name=='StaticMesh')
            ctx.mesh_loaded=true;return mesh
          end
        ''')
        ctx = self.lua.globals().ctx
        for index, item in enumerate(catalog * 3, 1):
            with self.subTest(cycle=index, weapon=item['weapon_type']):
                ctx.active_class = 'BlueprintGeneratedClass ' + item['weapon_classes'][0]
                ctx.active_mesh = item['mesh_object']
                ctx.mesh_loaded = False
                self.tick(1)
                self.assertEqual(ctx.load_calls, index)
                self.assertEqual(ctx.created, index)
                self.assertEqual(ctx.destroyed, index - 1)
                self.assertTrue(self.lua.globals().primary.hidden)
                self.assertFalse(self.lua.globals().primary.visible)
                self.assertTrue(ctx.components[index].visible)
                self.tick(.01)
                self.assertEqual(ctx.load_calls, index)

    def test_failed_load_attempt_is_not_repeated_each_second(self):
        ctx=self.lua.globals().ctx
        ctx.mesh_loaded=False;ctx.mesh_load_allowed=False
        for _ in range(4): self.tick(1)
        self.assertEqual(ctx.load_calls,1)
        self.assertEqual(ctx.created,0)
        before=ctx.queries
        ctx.mesh_loaded=True
        self.tick(1)
        self.assertEqual(ctx.created,0)
        self.assertGreater(ctx.queries,before)
        self.assertLessEqual(ctx.queries-before,35,'Failed mesh should only poll equipped weapon')
        self.assertEqual(ctx.load_calls,1)
        self.assertEqual(ctx.asset_lookups,1)

    def test_failed_bolter_load_does_not_prevent_loading_shotgun(self):
        ctx=self.lua.globals().ctx
        ctx.mesh_loaded=False;ctx.mesh_load_allowed=False
        self.tick()
        self.assertEqual(ctx.load_calls,1)
        self.assertEqual(ctx.created,0)
        self.lua.execute('''
          weapon.get_class=function() engine_only();return class(
            'BlueprintGeneratedClass /Game/Blueprints/Weapons/Shotgun/BP_Shotgun.BP_Shotgun_C') end
          mesh.get_full_name=function() engine_only();return
            'StaticMesh /Game/Art/Pickups/Weapons/M_ShotgunPickup.M_ShotgunPickup' end
          assets.GetAsset=function(self,data)
            engine_only();ctx.load_calls=ctx.load_calls+1
            assert(data.ObjectPath.name=='/Game/Art/Pickups/Weapons/M_ShotgunPickup.M_ShotgunPickup')
            ctx.mesh_loaded=true;return mesh
          end
        ''')
        ctx.mesh_load_allowed=True
        self.tick(1.1)
        self.assertEqual(ctx.created,1)
        self.assertTrue(self.component().visible)
        self.assertEqual(ctx.load_calls,2)
        self.assertEqual(ctx.asset_lookups,2)

    def test_failed_weapon_stays_latched_after_using_another_firearm(self):
        ctx=self.lua.globals().ctx
        ctx.mesh_loaded=False;ctx.mesh_load_allowed=False
        self.tick()
        self.assertEqual(ctx.load_calls,1)
        self.assertEqual(ctx.asset_lookups,1)
        self.lua.execute('''
          weapon.get_class=function() engine_only();return class(
            'BlueprintGeneratedClass /Game/Blueprints/Weapons/Shotgun/BP_Shotgun.BP_Shotgun_C') end
          mesh.get_full_name=function() engine_only();return
            'StaticMesh /Game/Art/Pickups/Weapons/M_ShotgunPickup.M_ShotgunPickup' end
        ''')
        ctx.mesh_loaded=True
        self.tick(1.1)
        self.assertEqual(ctx.created,1)
        self.assertTrue(self.lua.globals().primary.hidden)
        self.lua.execute('weapon.get_class=function() engine_only();return bolter_class end')
        self.tick(1.1)
        self.assertEqual(ctx.created,1)
        self.assertEqual(ctx.destroyed,1)
        self.assertFalse(self.lua.globals().primary.hidden)
        self.assertTrue(self.lua.globals().primary.visible)
        self.assertEqual(ctx.load_calls,1)
        self.assertEqual(ctx.asset_lookups,2)
        for _ in range(60): self.tick(.1)
        self.assertEqual(ctx.load_calls,1)
        self.assertEqual(ctx.asset_lookups,2)

    def test_missing_library_requires_explicit_reenable_before_recovery(self):
        ctx=self.lua.globals().ctx
        ctx.mesh_loaded=False;ctx.library_available=False
        self.tick();self.assertEqual(ctx.created,0)
        self.assertEqual(ctx.load_calls,0)
        ctx.mesh_loaded=True
        self.lua.globals().files['bolter3d.mode']='off'
        self.tick(1)
        self.lua.globals().files['bolter3d.mode']='preview'
        self.tick(1)
        self.assertEqual(ctx.created,1)

    def test_missing_kismet_function_skips_forced_load(self):
        ctx=self.lua.globals().ctx
        ctx.mesh_loaded=False;ctx.library_function_missing='Conv_StringToName'
        self.tick()
        self.assertEqual(ctx.created,0)
        self.assertEqual(ctx.load_calls,0)

    def test_loading_exception_suspends_until_explicit_reenable(self):
        ctx=self.lua.globals().ctx
        ctx.mesh_loaded=False;ctx.load_error=True
        self.tick()
        self.assertEqual(ctx.created,0)
        self.assertEqual(ctx.load_calls,1)
        before=ctx.queries
        ctx.mesh_loaded=True
        self.tick(1)
        self.assertGreater(ctx.queries,before)
        self.assertLessEqual(ctx.queries-before,35)
        self.assertEqual(ctx.load_calls,1)
        self.assertEqual(ctx.asset_lookups,1)
        self.assertEqual(ctx.created,0)
        self.lua.globals().files['bolter3d.mode']='off'
        self.tick(1)
        self.lua.globals().files['bolter3d.mode']='preview'
        self.tick(1)
        self.assertEqual(ctx.created,1)

    def test_failed_struct_cast_never_loads_again_and_probes_are_bounded(self):
        ctx=self.lua.globals().ctx
        ctx.mesh_loaded=False;ctx.cast_failed=True
        self.tick()
        before=ctx.queries
        for _ in range(60): self.tick(.1)
        self.assertEqual(ctx.load_calls,0)
        self.assertEqual(ctx.asset_lookups,1)
        self.assertGreater(ctx.queries,before)
        self.assertLessEqual(ctx.queries-before,240,'Poll must be bounded after a failed cast')

    def test_failed_load_only_probes_weapon_at_bounded_intervals(self):
        ctx=self.lua.globals().ctx
        ctx.mesh_loaded=False;ctx.mesh_load_allowed=False
        self.tick()
        before=ctx.queries
        for _ in range(600): self.tick(.01)
        self.assertGreater(ctx.queries,before)
        self.assertLessEqual(ctx.queries-before,240,'Poll must be bounded after a failed load')
        self.assertEqual(ctx.load_calls,1)
        self.assertEqual(ctx.asset_lookups,1)

    def test_registry_load_bypasses_unsupported_soft_parameter(self):
        ctx=self.lua.globals().ctx
        ctx.mesh_loaded=False
        self.tick()
        self.assertEqual(ctx.created,1)
        self.assertEqual(ctx.soft_load_calls,0)

    def test_registry_or_struct_unavailable_never_calls_loader(self):
        for key in ('registry_available','struct_available'):
            with self.subTest(key=key):
                self.setUp()
                ctx=self.lua.globals().ctx
                ctx.mesh_loaded=False;ctx[key]=False
                self.tick()
                self.assertEqual(ctx.created,0)
                self.assertEqual(ctx.load_calls,0)

    def test_asset_fields_validated_before_loading(self):
        ctx=self.lua.globals().ctx
        ctx.mesh_loaded=False;ctx.asset_field_missing='ObjectPath'
        self.tick()
        self.assertEqual(ctx.load_calls,0)
        self.assertEqual(ctx.created,0)

    def test_invalid_asset_data_never_calls_loader(self):
        ctx=self.lua.globals().ctx
        ctx.mesh_loaded=False;ctx.asset_invalid=True
        self.tick()
        self.assertEqual(ctx.load_calls,0)
        self.assertEqual(ctx.created,0)

    def test_registry_function_and_default_validated(self):
        for key,value in (('registry_function_missing','GetAsset'),('registry_default_missing',True)):
            with self.subTest(key=key):
                self.setUp()
                ctx=self.lua.globals().ctx
                ctx.mesh_loaded=False;ctx[key]=value
                self.tick()
                self.assertEqual(ctx.load_calls,0)
                self.assertEqual(ctx.created,0)

    def test_unexpected_loaded_object_is_rejected(self):
        ctx=self.lua.globals().ctx
        ctx.mesh_loaded=False;ctx.unexpected_mesh=True
        self.tick()
        self.assertEqual(ctx.load_calls,1)
        self.assertEqual(ctx.created,0)

    def test_other_weapon_and_menu_never_force_asset_load(self):
        ctx=self.lua.globals().ctx
        ctx.mesh_loaded=False;ctx.weapon_name='Shotgun'
        self.tick()
        self.assertEqual(ctx.load_calls,0)
        ctx.weapon_name='Bolter';ctx.menu=True
        self.tick(1)
        self.assertEqual(ctx.load_calls,0)

    def test_other_weapon_never_creates_bolter(self):
        self.lua.globals().ctx.weapon_name='Shotgun'
        self.tick()
        self.assertEqual(self.lua.globals().ctx.created,0)

    def test_switching_weapon_removes_only_owned_visual(self):
        self.tick()
        self.lua.globals().ctx.weapon_name='Shotgun'
        self.tick()
        self.assertEqual(self.lua.globals().ctx.destroyed,1)
        self.assertEqual(self.lua.globals().ctx.removed,1)
        self.assertTrue(self.lua.globals().pawn.valid)
        self.assertTrue(self.lua.globals().weapon.valid)

    def test_off_mode_is_inert_without_recovery_journal(self):
        self.lua.globals().files['bolter3d.mode']='off'
        self.tick()
        self.assertEqual(self.lua.globals().ctx.queries,0)

    def test_live_disable_destroys_component_in_engine_tick(self):
        self.tick()
        self.lua.globals().files['bolter3d.mode']='off'
        self.tick(1)
        self.assertEqual(self.lua.globals().ctx.destroyed,1)

    def test_menu_hmd_and_controller_loss_remove_visual(self):
        for key,value in (('menu',True),('hmd',False),('controllers',False)):
            self.tick(1)
            before=self.lua.globals().ctx.destroyed
            self.lua.globals().ctx[key]=value
            self.tick()
            self.assertEqual(self.lua.globals().ctx.destroyed,before+1)
            self.lua.globals().ctx[key]=not value

    def test_dead_pawn_is_not_dereferenced(self):
        self.lua.globals().pawn.valid=False
        self.tick()
        self.assertEqual(self.lua.globals().ctx.created,0)

    def test_missing_native_property_or_function_prevents_creation(self):
        self.lua.globals().ctx.missing_property='EquippedWeapon'
        self.tick()
        self.assertEqual(self.lua.globals().ctx.created,0)
        self.lua.globals().ctx.missing_property=None
        self.lua.globals().ctx.missing_function='K2_DestroyComponent'
        self.tick(1)
        self.assertEqual(self.lua.globals().ctx.created,0)

    def test_mesh_assignment_failure_rolls_back(self):
        self.lua.globals().ctx.fail_mesh=True
        self.tick()
        self.assertEqual(self.lua.globals().ctx.created,1)
        self.assertEqual(self.lua.globals().ctx.destroyed,1)
        self.tick(1)
        self.assertEqual(self.lua.globals().ctx.created,1)

    def test_hook_failure_rolls_back(self):
        self.lua.globals().ctx.fail_hook=True
        self.tick()
        self.assertEqual(self.lua.globals().ctx.destroyed,1)

    def test_journal_failure_never_leaves_visible_component(self):
        self.lua.globals().ctx.fail_journal=True
        self.tick()
        self.assertEqual(self.lua.globals().ctx.created,1)
        self.assertEqual(self.lua.globals().ctx.destroyed,1)

    def test_reset_does_no_native_cleanup_until_next_engine_tick(self):
        self.tick()
        before=self.lua.globals().ctx.queries
        self.lua.globals().reset()
        self.assertEqual(self.lua.globals().ctx.queries,before)
        self.assertEqual(self.lua.globals().ctx.destroyed,0)
        self.reload()
        self.lua.globals().files['bolter3d.mode']='off'
        self.tick()
        self.assertEqual(self.lua.globals().ctx.destroyed,1)

    def test_reload_recovers_owned_component_before_creating_another(self):
        self.tick();self.lua.globals().reset();self.reload();self.tick()
        self.assertEqual(self.lua.globals().ctx.destroyed,1)
        self.assertEqual(self.lua.globals().ctx.created,2)

    def test_calibration_updates_existing_component(self):
        self.tick()
        self.lua.globals().files['bolter3d.settings']='scale=0.6\nx=12\ny=-8\nz=9\nyaw=10\npitch=0\nroll=0\n'
        self.tick(1)
        self.assertEqual(self.lua.globals().ctx.created,1)
        self.assertAlmostEqual(self.component().scale,.6)
        self.assertEqual(self.component().offset.x,26.4)
        self.assertAlmostEqual(self.component().offset.y,20.8)
        self.assertEqual(self.component().offset.z,9)

    def test_invalid_calibration_uses_defaults(self):
        self.lua.globals().files['bolter3d.settings']='scale=nan\nx=inf\ny=999999\nz=broken'
        self.tick()
        self.assertEqual(self.lua.globals().ctx.created,1)
        self.assertAlmostEqual(self.component().scale,.5)
        self.assertEqual(self.component().offset.y,24)

    def test_default_grip_point_lands_at_tracked_controller(self):
        self.tick()
        c=self.component()
        # UObjectHook GLM->UE translation: (y,z,-x). Mesh grip is (-48,0,24) cm.
        self.assertAlmostEqual(c.offset.y+c.scale*(-48),0)
        self.assertAlmostEqual(c.offset.z,0)
        self.assertAlmostEqual(-c.offset.x+c.scale*24,0)

    def test_primary_sprite_hidden_only_after_visual_is_ready(self):
        self.tick()
        self.assertTrue(self.lua.globals().primary.hidden)
        self.assertFalse(self.lua.globals().primary.visible)
        self.assertTrue(self.lua.globals().secondary.visible)
        self.assertFalse(self.lua.globals().secondary.hidden)

    def test_sprite_restored_when_switching_to_other_weapon(self):
        self.tick()
        self.lua.globals().ctx.weapon_name='Shotgun'
        self.tick()
        self.assertFalse(self.lua.globals().primary.hidden)
        self.assertTrue(self.lua.globals().primary.visible)

    def test_sprite_never_hidden_when_visibility_or_owner_cannot_be_verified(self):
        for key,value in (('sprite_missing',True),('missing_property','bVisible')):
            with self.subTest(key=key):
                self.setUp();self.lua.globals().ctx[key]=value
                self.tick()
                self.assertEqual(self.lua.globals().ctx.created,0)
                self.assertTrue(self.lua.globals().primary.visible)
                self.assertFalse(self.lua.globals().primary.hidden)

    def test_journal_write_failure_keeps_primary_sprite_available(self):
        self.lua.globals().ctx.fail_journal=True
        self.tick()
        self.assertFalse(self.lua.globals().primary.hidden)
        self.assertTrue(self.lua.globals().primary.visible)

    def test_sprite_restored_even_if_preview_component_was_destroyed_elsewhere(self):
        self.tick();self.lua.globals().reset();self.reload()
        self.component().valid=False
        self.lua.globals().files['bolter3d.mode']='off'
        self.tick()
        self.assertFalse(self.lua.globals().primary.hidden)
        self.assertTrue(self.lua.globals().primary.visible)

    def test_grip_origin_scales_without_drifting_from_controller(self):
        self.lua.globals().files['bolter3d.settings']='scale=0.4'
        self.tick()
        c=self.component()
        self.assertAlmostEqual(c.offset.y+c.scale*(-48),0)
        self.assertAlmostEqual(-c.offset.x+c.scale*24,0)

    def test_barrel_inspection_reports_signature_without_calling_gameplay_function(self):
        self.lua.execute('''
        ctx.barrel_calls=0
        local field={get_fname=function() engine_only();return {to_string=function() return 'Offset' end} end,
          get_next=function() engine_only();return nil end}
        local property={is_param=function() engine_only();return true end,
          is_return_param=function() engine_only();return false end,
          get_class=function() engine_only();return {get_name=function() return 'StructProperty' end} end}
        local fn={get_child_properties=function() engine_only();return field end,
          find_property=function(self,name) engine_only();assert(name=='Offset');return property end}
        local old=renderer_class.find_function
        renderer_class.find_function=function(self,name)
          if name=='GetBarrelTransform' then engine_only();return fn end
          return old(self,name)
        end
        renderer.GetBarrelTransform=function() ctx.barrel_calls=ctx.barrel_calls+1;error('Must not invoke') end
        ''')
        self.tick()
        self.assertEqual(self.lua.globals().ctx.barrel_calls,0)
        self.assertTrue(any('Offset:StructProperty:input' in str(s)
            for s in self.lua.globals().ctx.logs.values()))
        self.assertTrue(self.component().visible)

    def test_optional_barrel_inspection_error_does_not_disable_replacement(self):
        self.lua.execute('''
        local old=renderer_class.find_function
        renderer_class.find_function=function(self,name)
          if name=='GetBarrelTransform' then engine_only();return {get_child_properties=function() error('Unavailable') end} end
          return old(self,name)
        end
        ''')
        self.tick();self.tick()
        self.assertTrue(self.component().visible)
        self.assertTrue(self.lua.globals().primary.hidden)

    def test_sprite_original_flags_preserved_on_disable(self):
        self.lua.globals().primary.hidden=True
        self.lua.globals().primary.visible=False
        self.tick()
        self.lua.globals().files['bolter3d.mode']='off'
        self.tick(1)
        self.assertTrue(self.lua.globals().primary.hidden)
        self.assertFalse(self.lua.globals().primary.visible)

    def test_sprite_remains_visible_if_mesh_or_controller_attachment_fails(self):
        for key in ('fail_mesh','fail_hook'):
            with self.subTest(key=key):
                self.setUp();self.lua.globals().ctx[key]=True
                self.tick()
                self.assertFalse(self.lua.globals().primary.hidden)
                self.assertTrue(self.lua.globals().primary.visible)

    def test_reset_defers_sprite_restoration_until_engine_tick(self):
        self.tick();self.lua.globals().reset()
        self.assertTrue(self.lua.globals().primary.hidden)
        self.reload()
        self.lua.globals().files['bolter3d.mode']='off'
        self.tick()
        self.assertFalse(self.lua.globals().primary.hidden)
        self.assertTrue(self.lua.globals().primary.visible)

    def test_recovery_rejects_different_sprite_identity(self):
        self.tick();self.lua.globals().reset();self.reload()
        self.lua.execute('primary.get_address=function() engine_only();return 99999 end')
        self.tick()
        self.assertEqual(self.lua.globals().ctx.destroyed,0)
        self.assertEqual(self.lua.globals().ctx.created,1)

    def test_legacy_component_journal_recovery_still_supported(self):
        self.tick();self.lua.globals().reset();self.reload()
        # Previous preview never hid a sprite: reconstruct its v1 journal.
        self.lua.execute('local f={};for x in files["bolter3d.owned"]:gmatch("[^\\r\\n]+") do f[#f+1]=x end;f[1]="v1";files["bolter3d.owned"]=table.concat(f,"\\n",1,6);primary.hidden=false;primary.visible=true')
        self.lua.globals().files['bolter3d.mode']='off'
        self.tick()
        self.assertEqual(self.lua.globals().ctx.destroyed,1)

    def test_game_res_showing_sprite_is_suppressed_while_bolter3d_active(self):
        self.tick()
        self.lua.globals().primary.visible=True
        self.lua.globals().primary.hidden=False
        self.tick()
        self.assertTrue(self.lua.globals().primary.hidden)
        self.assertFalse(self.lua.globals().primary.visible)

    def test_missing_assets_are_not_searched_every_frame(self):
        self.lua.globals().ctx.mesh_loaded=False
        self.lua.globals().ctx.mesh_load_allowed=False
        self.lua.execute('ctx.asset_queries=0; old_find=uevr.api.find_uobject; uevr.api.find_uobject=function(self,name) if name:find(" /Game/",1,true) then ctx.asset_queries=ctx.asset_queries+1 end; return old_find(self,name) end')
        self.tick(.01)
        before=self.lua.globals().ctx.asset_queries
        for _ in range(20): self.tick(.01)
        self.assertEqual(self.lua.globals().ctx.asset_queries,before)

    def test_corrupt_journal_blocks_creation_without_touching_objects(self):
        self.lua.globals().files['bolter3d.owned']='invalid'
        self.tick()
        self.assertEqual(self.lua.globals().ctx.created,0)
        self.assertEqual(self.lua.globals().files['bolter3d.owned'],'invalid')

    def test_journal_from_other_engine_does_not_destroy_a_named_object(self):
        self.tick();self.lua.globals().reset();self.reload()
        self.lua.execute('engine.get_address=function() engine_only();return 9000 end')
        self.lua.globals().files['bolter3d.mode']='off'
        self.tick()
        self.assertEqual(self.lua.globals().ctx.destroyed,0)

    def test_journal_address_mismatch_refuses_cleanup_or_duplicate(self):
        self.tick();self.lua.globals().reset();self.reload()
        self.lua.execute('ctx.components[1].get_address=function() engine_only();return 7777 end')
        self.tick()
        self.assertEqual(self.lua.globals().ctx.created,1)
        self.assertEqual(self.lua.globals().ctx.destroyed,0)

    def test_journal_class_mismatch_refuses_cleanup_or_duplicate(self):
        self.tick();self.lua.globals().reset();self.reload()
        self.lua.execute('ctx.components[1].get_class=function() engine_only();return class("OtherClass") end')
        self.tick()
        self.assertEqual(self.lua.globals().ctx.created,1)
        self.assertEqual(self.lua.globals().ctx.destroyed,0)

    def test_expired_owner_hides_and_detaches_without_using_dead_owner(self):
        self.tick()
        self.lua.globals().pawn.valid=False
        self.tick()
        self.assertEqual(self.lua.globals().ctx.destroyed,0)
        self.assertEqual(self.lua.globals().ctx.removed,1)
        self.assertFalse(self.component().visible)

    def test_valid_but_different_owner_is_never_mutated(self):
        self.tick()
        self.lua.execute('other_owner=object("OtherOwner",9999,class("Pawn"));ctx.components[1].get_outer=function() engine_only();return other_owner end')
        self.lua.globals().files['bolter3d.mode']='off'
        self.tick(1)
        self.assertEqual(self.lua.globals().ctx.destroyed,0)
        self.assertTrue(self.component().visible)
        self.assertNotEqual(self.lua.globals().files['bolter3d.owned'],'')

    def test_save_load_reused_component_wrappers_do_not_disable_firearms(self):
        for recoil in (0, 1):
            with self.subTest(recoil=recoil):
                self.setUp()
                self.lua.globals().files['bolter3d.settings']=f'recoil_enabled={recoil}'
                self.tick()
                for generation in range(1, 4):
                    before=self.lua.globals().ctx.created
                    self.lua.execute("""
                      old_pawn=pawn
                      old_pawn.valid=false
                      for _, c in pairs(ctx.components) do
                        if c.valid then
                          c.get_full_name=function() engine_only();return 'Recycled unrelated component' end
                          c.get_outer=function() engine_only();return object('Unrelated actor',9000,class('Actor')) end
                          c.SetHiddenInGame=function() error('recycled component mutation') end
                          c.SetVisibility=function() error('recycled component mutation') end
                          c.K2_DestroyComponent=function() error('recycled component destruction') end
                        end
                      end
                      pawn=object('Pawn loaded_save',ctx.created+3000,class('Pawn'))
                      pawn.get_property=old_pawn.get_property
                      renderer.get_outer=function() engine_only();return pawn end
                      primary.hidden=false;primary.visible=true
                    """)
                    self.tick(1.1)
                    ctx=self.lua.globals().ctx
                    self.assertEqual(ctx.created,before+1+recoil)
                    self.assertFalse(self.lua.globals().primary.visible)
                    self.assertTrue(ctx.components[before+1].visible)
                    self.tick(1.1)
                    self.assertEqual(ctx.created,before+1+recoil)
                    self.assertFalse(any('Disabled after API error' in v for v in ctx.logs.values()))

    def test_save_load_retires_old_ownership_even_if_component_identity_is_unchanged(self):
        self.lua.globals().files['bolter3d.settings']='recoil_enabled=1'
        self.tick()
        journal=self.lua.globals().files['bolter3d.owned']
        self.lua.execute("""
          old_pawn=pawn;old_pawn.valid=false
          local foreign=object('Foreign after travel',9000,class('Actor'))
          for _,c in pairs(ctx.components) do
            c.get_outer=function() engine_only();return foreign end
            c.SetHiddenInGame=function() error('foreign mutation') end
            c.K2_DestroyComponent=function() error('foreign destruction') end
          end
          pawn=object('Pawn new_save',3000,class('Pawn'))
          pawn.get_property=old_pawn.get_property
          renderer.get_outer=function() engine_only();return pawn end
          primary.visible=true;primary.hidden=false
        """)
        self.tick(1.1)
        self.assertEqual(self.lua.globals().ctx.created,4)
        self.assertFalse(self.lua.globals().primary.visible)
        self.assertEqual(self.lua.globals().files['bolter3d.retired'],journal)
        self.assertNotEqual(self.lua.globals().files['bolter3d.owned'],journal)

    def test_teardown_before_new_pawn_is_ready_does_not_permanently_stop_3d(self):
        self.tick()
        self.lua.execute("""
          old_pawn=pawn;old_pawn.valid=false
          local foreign=object('Foreign after travel',9000,class('Actor'))
          ctx.components[1].get_outer=function() engine_only();return foreign end
          ctx.components[1].SetHiddenInGame=function() error('foreign mutation') end
          ctx.components[1].K2_DestroyComponent=function() error('foreign destruction') end
          ctx.menu=true
        """)
        for _ in range(3):
            self.tick(1.1)
        self.assertEqual(self.lua.globals().ctx.created,1)
        self.lua.execute("""
          pawn=object('Pawn new_save',3000,class('Pawn'))
          pawn.get_property=old_pawn.get_property
          renderer.get_outer=function() engine_only();return pawn end
          primary.visible=true;primary.hidden=false
          ctx.menu=false
        """)
        self.tick(1.1)
        self.assertEqual(self.lua.globals().ctx.created,2)
        self.assertFalse(self.lua.globals().primary.visible)

    def test_save_load_waits_for_new_pawn_sprite_initialization(self):
        self.tick()
        self.lua.execute("""
          old_pawn=pawn;old_pawn.valid=false
          ctx.components[1].valid=false
          pawn=object('Pawn initializing_save',3000,class('Pawn'))
          pawn.get_property=old_pawn.get_property
          renderer.get_outer=function() engine_only();return pawn end
          ctx.sprite_missing=true
          primary.visible=true;primary.hidden=false
        """)
        self.tick(1.1)
        self.assertEqual(self.lua.globals().ctx.created,1)
        self.lua.globals().ctx.sprite_missing=False
        self.tick(1.1)
        self.assertEqual(self.lua.globals().ctx.created,2)
        self.assertFalse(self.lua.globals().primary.visible)

    def test_reused_component_with_different_class_is_never_mutated(self):
        self.tick()
        self.lua.execute("""
          ctx.components[1].get_class=function() engine_only();return class('OtherComponent') end
          ctx.components[1].SetHiddenInGame=function() error('unrelated class mutation') end
          ctx.components[1].K2_DestroyComponent=function() error('unrelated class destruction') end
        """)
        self.tick(1.1)
        self.assertEqual(self.lua.globals().ctx.created,2)
        self.assertFalse(self.lua.globals().primary.visible)

    def test_map_travel_renames_old_pawn_and_sprite_without_disabling_3d(self):
        self.tick()
        self.lua.execute("""
          old_pawn=pawn
          old_pawn.get_full_name=function() engine_only();return 'Pawn TRASH_previous_map' end
          primary.get_full_name=function() engine_only();return 'StaticMeshComponent TRASH_previous_map' end
          pawn=object('Pawn new_map',3001,class('Pawn'))
          pawn.get_property=old_pawn.get_property
          renderer.get_outer=function() engine_only();return pawn end
          primary.get_full_name=function() engine_only();return 'StaticMeshComponent new_map.Primary Render Plane' end
          primary.hidden=false;primary.visible=true
          local foreign=object('Expired world component owner',3002,class('Pawn'))
          ctx.components[1].get_outer=function() engine_only();return foreign end
          ctx.components[1].SetHiddenInGame=function() error('old world mutation') end
        """)
        self.tick(1)
        self.assertEqual(self.lua.globals().ctx.created,2)
        self.assertFalse(self.lua.globals().primary.visible)
        self.tick(1)
        self.assertEqual(self.lua.globals().ctx.created,2)
        self.assertTrue(self.component().visible)

    def test_replaced_sprite_is_detected_even_when_old_sprite_is_still_valid(self):
        self.tick()
        self.lua.execute("""
          old_primary=primary
          primary={}
          for k,v in pairs(old_primary) do primary[k]=v end
          primary.get_address=function() engine_only();return 4001 end
          primary.get_full_name=function() engine_only();return 'StaticMeshComponent new_sprite' end
          primary.hidden=false;primary.visible=true
        """)
        self.tick(1)
        self.assertEqual(self.lua.globals().ctx.created,2)
        self.assertFalse(self.lua.globals().primary.visible)
        self.assertTrue(self.lua.globals().primary.valid)

    def test_renderer_replacement_on_same_pawn_recovers_3d(self):
        self.tick()
        self.lua.execute("""
          primary.get_full_name=function() engine_only();return 'StaticMeshComponent replaced.Primary Render Plane' end
          primary.hidden=false;primary.visible=true
        """)
        self.tick(1)
        self.tick(1)
        self.assertEqual(self.lua.globals().ctx.created,2)
        self.assertFalse(self.lua.globals().primary.visible)

    def test_default_rotation_is_a_unit_identity_quaternion(self):
        self.tick()
        q=self.component().rotation
        self.assertAlmostEqual(q.w,1)
        self.assertAlmostEqual(q.x*q.x+q.y*q.y+q.z*q.z,0)


if __name__=='__main__': unittest.main()
