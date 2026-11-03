"""Offline UEVR engine-tick checks for the native menu aim guard."""
import unittest
from pathlib import Path

from lupa.lua54 import LuaRuntime


SCRIPT = Path(__file__).resolve().parents[1] / "profile/scripts/boltgun_menu_stable.lua"


class StableMenuTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(r'''
            ctx = {ready=true, controllers=true, overlay=false, aim=true,
                   writes=0, paused=false, load=true, logged=0, widget=false,
                   widget_fault=false}
            local function object(name, fields)
                local o = {name=name,fields=fields or {}}
                function o:get_full_name() return self.name end
                function o:get_class()
                    return {find_property=function(_,field)
                        return self.fields[field]~=nil
                    end}
                end
                function o:get_property(field) return self.fields[field] end
                return o
            end
            local frontend = 'BGPlayerController /Game/Maps/3DFrontend/MainMenu_InteriorScene.MainMenu_InteriorScene.PersistentLevel.BGPlayerController_1'
            local gameplay = 'BP_PlayerCharacter_Sternguard_C /Game/Maps/Map01.PersistentLevel.BP_PlayerCharacter_Sternguard_C_1'
            ctx.pc = object(frontend)
            ctx.pawn = nil
            ctx.game_pc = object('BGPlayerController /Game/Maps/Map01.PersistentLevel.BGPlayerController_1')
            ctx.game_pawn = object(gameplay,{bPlayerFinishedLevelLoad=true})
            ctx.menu_widget = object('NativeMenu')
            function ctx.menu_widget:IsInViewport()
                if ctx.widget_fault then error('widget no longer owns slate') end
                return ctx.widget
            end
            function ctx.menu_widget:IsVisible() return ctx.widget end
            ctx.hud = object('HUD',{CurrentMenu=ctx.menu_widget})
            ctx.game_pc.fields.MyHUD=ctx.hud
            local statics = object('Engine.GameplayStatics')
            function statics:IsGamePaused(_) return ctx.paused end
            uevr={params={vr={
                is_runtime_ready=function() return ctx.ready end,
                is_using_controllers=function() return ctx.controllers end,
                is_aim_allowed=function() return ctx.aim end,
                set_aim_allowed=function(v)
                    if ctx.setter_fault then error('setter unavailable') end
                    ctx.aim=v;ctx.writes=ctx.writes+1
                end
            }, functions={
                is_drawing_ui=function() return ctx.overlay end,
                log_info=function() ctx.logged=ctx.logged+1 end
            },sdk={callbacks={
                on_pre_engine_tick=function(f) tick=f end,
                on_script_reset=function(f) reset=f end
            }}}, api={
                get_player_controller=function() return ctx.pc end,
                get_local_pawn=function() return ctx.pawn end,
                find_uobject=function(_,name)
                    if name=='Class /Script/Engine.GameplayStatics' then
                        return {get_class_default_object=function() return statics end}
                    end
                end
            }, types={UObjectHook={exists=function(o) return o~=nil end}}}
        ''')
        self.lua.execute(SCRIPT.read_text(encoding="utf-8"))
        self.ctx = self.lua.globals().ctx

    def tick(self):
        self.lua.globals().tick()

    def game(self):
        self.ctx.pc = self.ctx.game_pc
        self.ctx.pawn = self.ctx.game_pawn

    def test_frontend_blocks_aim_and_restores_in_game(self):
        self.tick()
        self.assertFalse(self.ctx.aim)
        self.tick()
        self.assertEqual(self.ctx.writes, 1)
        self.game()
        self.tick()
        self.assertTrue(self.ctx.aim)
        self.assertEqual(self.ctx.writes, 2)

    def test_overlay_and_pause_block_and_release(self):
        self.game()
        self.ctx.overlay = True
        self.tick()
        self.assertFalse(self.ctx.aim)
        self.ctx.overlay = False
        self.tick()
        self.assertTrue(self.ctx.aim)
        self.ctx.paused = True
        self.tick()
        self.assertFalse(self.ctx.aim)
        self.ctx.paused = False
        self.tick()
        self.assertTrue(self.ctx.aim)

    def test_loading_and_native_menu_detection(self):
        self.game()
        self.ctx.game_pawn.fields.bPlayerFinishedLevelLoad = False
        self.tick()
        self.assertFalse(self.ctx.aim)
        self.ctx.game_pawn.fields.bPlayerFinishedLevelLoad = True
        self.tick()
        self.assertTrue(self.ctx.aim)
        self.ctx.widget = True
        self.tick()
        self.assertFalse(self.ctx.aim)
        self.ctx.widget = False
        self.tick()
        self.assertTrue(self.ctx.aim)

    def test_unknown_state_and_external_setting_are_preserved(self):
        self.ctx.pc = None
        self.tick()
        self.assertTrue(self.ctx.aim)
        self.assertEqual(self.ctx.writes, 0)
        self.ctx.pc = self.ctx.game_pc
        self.ctx.pawn = self.ctx.game_pawn
        self.ctx.aim = False
        self.ctx.paused = True
        self.tick()
        self.assertFalse(self.ctx.aim)
        self.assertEqual(self.ctx.writes, 0)
        self.ctx.aim = True
        self.tick()
        self.assertEqual(self.ctx.writes, 1)
        self.ctx.aim = True  # Someone else took ownership while the menu was open.
        self.tick()
        self.ctx.paused = False
        self.tick()
        self.assertTrue(self.ctx.aim)
        self.assertEqual(self.ctx.writes, 1)

    def test_reset_restores_owned_state(self):
        self.tick()
        self.assertFalse(self.ctx.aim)
        self.lua.globals().reset()
        self.assertTrue(self.ctx.aim)
        self.tick()
        self.assertTrue(self.ctx.aim)

    def test_unavailable_widget_method_does_not_kill_other_detection(self):
        self.game()
        self.ctx.widget_fault = True
        self.tick()
        self.assertTrue(self.ctx.aim)
        self.ctx.paused = True
        self.tick()
        self.assertFalse(self.ctx.aim)

    def test_invalid_aim_setter_stops_after_three_failures(self):
        self.ctx.setter_fault = True
        for _ in range(3):
            self.tick()
        self.assertTrue(self.ctx.aim)
        self.assertEqual(self.ctx.logged, 3)
        self.ctx.setter_fault = False
        self.tick()
        self.assertEqual(self.ctx.writes, 0)


if __name__ == "__main__":
    unittest.main()
