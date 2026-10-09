"""Offline checks for the uninstalled, read-only native weapon diagnostic."""
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
from lupa.lua54 import LuaRuntime


class NativeProbeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
        ctx={queries=0,logs={},fail=false,asset_loaded=true,pawn_valid=true,
             weapon_valid=true,handler_valid=true,property_exists=true}
        local function cls(name,super)
          return {get_full_name=function() return name end,
                  get_super_struct=function() return super end,
                  find_property=function() return ctx.property_exists and {} or nil end}
        end
        base=cls('BlueprintGeneratedClass /Game/Blueprints/Weapons/Boltgun/BP_Boltgun.BP_Boltgun_C')
        weapon={get_class=function() return ctx.weapon_class or base end}
        handler={get_class=function() return cls('Class /Script/Boltgun.BGWeaponHandler') end,
          get_property=function(self,key)
            assert(key=='EquippedWeapon','Forbidden property: '..key)
            if ctx.fail then error('engine read failed') end
            return weapon
          end}
        pawn={get_class=function() return cls('PlayerClass') end,
          get_property=function(self,key)
            assert(key=='WeaponHandlerComponent','Forbidden property: '..key)
            return handler
          end}
        tick=function() end; reset=function() end
        uevr={params={functions={log_info=function(s) table.insert(ctx.logs,s) end},
          sdk={callbacks={on_pre_engine_tick=function(f) tick=f end,
                          on_script_reset=function(f) reset=f end}}},
          api={get_local_pawn=function(self,index)
            ctx.queries=ctx.queries+1; assert(index==0); return pawn end,
            find_uobject=function(self,name)
              ctx.queries=ctx.queries+1
              return ctx.asset_loaded and {} or nil
            end},types={UObjectHook={exists=function(obj)
              if obj==pawn then return ctx.pawn_valid end
              if obj==handler then return ctx.handler_valid end
              if obj==weapon then return ctx.weapon_valid end
              return obj~=nil
            end}}}
        ''')
        source = ROOT / "tools/probes/native_probe.template.lua"
        text = source.read_text(encoding="utf-8") if source.exists() else ""
        literal = '''{['BlueprintGeneratedClass /Game/Blueprints/Weapons/Boltgun/BP_Boltgun.BP_Boltgun_C']={
          weapon_type='Boltgun',mesh_object='StaticMesh bolter',material_object='MaterialInstanceConstant bolter'}}'''
        self.lua.execute(text.replace("local assets = __ASSET_CATALOG__", "local assets = " + literal))

    def step(self, seconds=1):
        self.lua.globals().tick(None, seconds)

    def messages(self):
        return list(self.lua.globals().ctx.logs.values())

    def test_no_engine_access_during_script_load(self):
        self.assertEqual(self.lua.globals().ctx.queries, 0)

    def test_identifies_equipped_weapon_and_loaded_geometry(self):
        self.step()
        self.assertTrue(any('Boltgun' in s and 'mesh=true' in s and 'material=true' in s for s in self.messages()))

    def test_handles_unloaded_assets_and_notices_when_they_load(self):
        self.lua.globals().ctx.asset_loaded = False
        self.step()
        self.assertTrue(any('mesh=false' in s for s in self.messages()))
        self.lua.globals().ctx.asset_loaded = True
        self.step()
        self.assertTrue(any('mesh=true' in s for s in self.messages()))

    def test_ignores_dead_pawn_handler_and_weapon(self):
        for field in ('pawn_valid', 'handler_valid', 'weapon_valid'):
            self.lua.globals().ctx[field] = False
            self.step()
            self.assertFalse(any('mesh=' in s for s in self.messages()))
            self.lua.globals().ctx[field] = True

    def test_no_get_property_when_reflection_field_is_missing(self):
        self.lua.globals().ctx.property_exists = False
        self.lua.globals().ctx.fail = True
        self.step()
        self.assertFalse(any('error' in s.lower() for s in self.messages()))

    def test_machine_spirit_variant_uses_verified_parent_class(self):
        self.lua.execute("ctx.weapon_class={get_full_name=function() return 'Variant' end,get_super_struct=function() return base end}")
        self.step()
        self.assertTrue(any('mesh=true' in s for s in self.messages()))

    def test_stops_after_native_api_error(self):
        self.lua.globals().ctx.fail = True
        self.step()
        before = self.lua.globals().ctx.queries
        self.step()
        self.assertEqual(self.lua.globals().ctx.queries, before)
        self.assertTrue(any('disabled' in s.lower() for s in self.messages()))

    def test_reset_stops_further_engine_access(self):
        self.step()
        self.lua.globals().reset()
        before = self.lua.globals().ctx.queries
        self.step()
        self.assertEqual(self.lua.globals().ctx.queries, before)

    def test_throttles_queries_and_does_not_repeat_log(self):
        self.step()
        before = self.lua.globals().ctx.queries
        logs = len(self.messages())
        self.step(.1)
        self.assertEqual(self.lua.globals().ctx.queries, before)
        self.step(1)
        self.assertEqual(len(self.messages()), logs)


if __name__ == "__main__":
    unittest.main()
