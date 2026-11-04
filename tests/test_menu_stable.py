"""Offline execution of menu leases against the UEVR/UE API boundary."""
import unittest
from pathlib import Path
from lupa.lua54 import LuaRuntime

SCRIPT = Path(__file__).resolve().parents[1] / 'profile/scripts/boltgun_menu_stable.lua'
ORIGINAL = {'VR_AimMethod': '2', 'UI_FollowView': 'true', 'VR_DecoupledPitchUIAdjust': 'true'}
DESIRED = {'VR_AimMethod': '0', 'UI_FollowView': 'false', 'VR_DecoupledPitchUIAdjust': 'false'}


class StableMenuTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(r'''
            ctx={ready=true,controllers=true,overlay=false,aim=true,aim_writes=0,
                paused=false,logged=0,widget=false,writes=0,captures=0,cursor_writes=0,
                now=0,thread='outside',offthread=0,files={},fs_writes=0,
                settings={VR_AimMethod='2',UI_FollowView='true',VR_DecoupledPitchUIAdjust='true'}}
            local function engine_only()
                if ctx.thread~='engine' then
                    ctx.offthread=ctx.offthread+1;error('UObject access outside engine tick')
                end
            end
            fs={read=function(k) if ctx.fs_read_fault then error('journal read failed') end;return ctx.files[k] or '' end,
                write=function(k,v)
                    if ctx.fs_write_fault then error('journal write failed') end
                    ctx.files[k]=v;ctx.fs_writes=ctx.fs_writes+1
                end}
            os.clock=function() return ctx.now end
            local address=0
            local function object(name,fields)
                address=address+1
                local o={name=name,fields=fields or {},address=address}
                function o:get_full_name() engine_only();return self.name end
                function o:get_address() engine_only();return self.address end
                function o:get_class() engine_only();return {find_property=function(_,k) return self.fields[k]~=nil end} end
                function o:get_property(k)
                    engine_only()
                    if ctx.hud_fault and k=='MyHUD' then error('HUD unavailable') end
                    return self.fields[k]
                end
                function o:set_property(k,v)
                    engine_only()
                    assert(not self.dead,'dead object')
                    if k=='bShowMouseCursor' and v==true then
                        assert((ctx.files['boltgun_menu_cursor.owned'] or ''):find(self.name,1,true),
                            'cursor mutated before ownership journal')
                    end
                    if ctx.cursor_fault then error('cursor unavailable') end
                    self.fields[k]=v;ctx.cursor_writes=ctx.cursor_writes+1
                    if ctx.cursor_after_fault then error('cursor failed after mutation') end
                end
                return o
            end
            ctx.engine=object('GameEngine /Engine/Transient.GameEngine_1')
            ctx.front_pc=object('BGPlayerController /Game/Maps/3DFrontend/MainMenu_InteriorScene.MainMenu_InteriorScene.PersistentLevel.BGPlayerController_1',{bShowMouseCursor=false})
            ctx.pc=ctx.front_pc
            ctx.game_pc=object('BGPlayerController /Game/Maps/Map01.PersistentLevel.BGPlayerController_1',{bShowMouseCursor=false})
            ctx.game_pawn=object('BP_PlayerCharacter_Sternguard_C /Game/Maps/Map01.PersistentLevel.BP_PlayerCharacter_Sternguard_C_1',{bPlayerFinishedLevelLoad=true})
            ctx.menu_widget=object('NativeMenu',{Visibility=0})
            function ctx.menu_widget:IsInViewport()
                if ctx.widget_fault then error('widget no longer owns slate') end
                return ctx.widget
            end
            function ctx.menu_widget:IsVisible() return ctx.widget end
            ctx.game_pc.fields.MyHUD=object('HUD',{CurrentMenu=ctx.menu_widget})
            local statics=object('Engine.GameplayStatics')
            function statics:IsGamePaused(_)
                ctx.pause_reads=(ctx.pause_reads or 0)+1
                if ctx.fail_second_pause_read and ctx.pause_reads>1 then error('stale pause probe') end
                return ctx.paused
            end
            local sc=object('Class Engine.GameplayStatics')
            function sc:get_class_default_object() return statics end
            local lib=object('UMG.WidgetBlueprintLibrary')
            local lc=object('Class UMG.WidgetBlueprintLibrary')
            function lc:get_class_default_object() return lib end
            local names={'PlayerController','InWidgetToFocus','InMouseLockMode','bHideCursorDuringCapture'}
            local fn={}
            function fn:get_child_properties()
                local function field(i)
                    if not names[i] then return nil end
                    return {get_fname=function() return {to_string=function()
                        return ctx.bad_signature and i==3 and 'WrongABI' or names[i]
                    end} end,get_next=function() return field(i+1) end}
                end
                return field(1)
            end
            function fn:find_property(_) return {is_param=function() return true end} end
            setmetatable(fn,{__call=function(_,l,pc,menu,lock,hide)
                assert(l==lib and pc==ctx.pc and lock==0 and hide==false)
                if ctx.capture_fault then error('capture unavailable') end
                ctx.captures=ctx.captures+1;ctx.capture_menu=menu
            end})
            function lc:find_function(n) if n=='SetInputMode_GameAndUIEx' then return fn end end
            uevr={params={vr={
                is_runtime_ready=function() return ctx.ready end,
                is_using_controllers=function() return ctx.controllers end,
                is_aim_allowed=function() return ctx.aim end,
                set_aim_allowed=function(v) ctx.aim=v;ctx.aim_writes=ctx.aim_writes+1 end,
                get_mod_value=function(self,k)
                    assert(self==uevr.params.vr,'instance-bound getter')
                    if ctx.read_fault==k then error('read unavailable') end
                    if ctx.read_fault_once==k then ctx.read_fault_once=nil;error('transient read failure') end
                    return ctx.settings[k] or ''
                end,
                set_mod_value=function(k,v)
                    assert(type(k)=='string' and type(v)=='string')
                    if ctx.setter_fault==k then error('setter unavailable') end
                    ctx.writes=ctx.writes+1
                    if ctx.ignore_write~=k then ctx.settings[k]=v end
                    if ctx.after_write_fault==k then error('error after mutation') end
                end
            },functions={is_drawing_ui=function() return ctx.overlay end,
                log_info=function(message) ctx.logged=ctx.logged+1;ctx.last_log=message end},sdk={callbacks={
                on_pre_engine_tick=function(f) tick=f end,on_script_reset=function(f) reset=f end
            }}},api={get_player_controller=function() engine_only();return ctx.pc end,
                get_engine=function() engine_only();return ctx.engine end,
                get_local_pawn=function() engine_only();return ctx.pawn end,
                find_uobject=function(_,n)
                    engine_only()
                    if n=='Class /Script/Engine.GameplayStatics' then return sc end
                    if n=='Class /Script/UMG.WidgetBlueprintLibrary' and not ctx.no_capture then return lc end
                    for _,o in ipairs({ctx.front_pc,ctx.game_pc}) do
                        if o.name==n and not o.dead then return o end
                    end
                end},types={UObjectHook={exists=function(o) engine_only();return o~=nil and not o.dead end}}}
        ''')
        self.lua.execute(SCRIPT.read_text(encoding='utf-8'))
        self.ctx = self.lua.globals().ctx

    def tick(self):
        self.ctx.thread = 'engine'
        try:
            self.lua.globals().tick()
        finally:
            self.ctx.thread = 'outside'

    def reset(self):
        self.ctx.thread = 'ui'
        try:
            self.lua.globals().reset()
        finally:
            self.ctx.thread = 'outside'

    def game(self):
        self.ctx.pc, self.ctx.pawn = self.ctx.game_pc, self.ctx.game_pawn

    def assert_settings(self, expected):
        self.assertEqual({k: self.ctx.settings[k] for k in DESIRED}, expected)

    def test_stereo_hook_overwrite_does_not_reenable_controller_aim(self):
        self.tick()
        self.assert_settings(DESIRED)
        self.ctx.aim = True  # UObjectHook overwrites the temporary flag.
        self.tick()
        self.assert_settings(DESIRED)
        self.assertEqual(self.ctx.writes, 3)
        self.assertEqual(self.ctx.aim_writes, 0)
        self.game()
        self.tick()
        self.assert_settings(ORIGINAL)

    def test_exact_original_strings_and_disabled_aim_survive_reset(self):
        self.ctx.settings.VR_AimMethod = '0.000000'
        self.ctx.settings.UI_FollowView = 'false'
        self.ctx.aim = False
        self.tick()
        self.reset()
        self.assert_settings(dict(ORIGINAL, VR_AimMethod='0.000000', UI_FollowView='false'))
        self.assertFalse(self.ctx.aim)
        self.tick()
        self.assertEqual(self.ctx.aim_writes, 0)

    def test_cursor_restores_on_controller_transition_and_menu_exit(self):
        self.tick()
        self.assertTrue(self.ctx.front_pc.fields.bShowMouseCursor)
        self.game()
        self.ctx.paused = True
        self.tick()
        self.assertFalse(self.ctx.front_pc.fields.bShowMouseCursor)
        self.assertTrue(self.ctx.game_pc.fields.bShowMouseCursor)
        self.ctx.paused = False
        self.tick()
        self.assertFalse(self.ctx.game_pc.fields.bShowMouseCursor)
        self.assert_settings(ORIGINAL)

    def test_external_cursor_change_is_not_reacquired(self):
        self.tick()
        self.ctx.pc.fields.bShowMouseCursor = False
        self.tick()
        self.tick()
        self.assertFalse(self.ctx.pc.fields.bShowMouseCursor)
        self.assertEqual(self.ctx.cursor_writes, 1)

    def test_framework_overlay_never_changes_game_capture_or_cursor(self):
        self.game()
        self.ctx.overlay = True
        self.tick()
        self.assert_settings(DESIRED)
        self.assertEqual((self.ctx.captures, self.ctx.cursor_writes), (0, 0))
        self.ctx.overlay = False
        self.tick()
        self.assert_settings(ORIGINAL)

    def test_loading_and_visible_native_widget_lease_settings(self):
        self.game()
        self.ctx.game_pawn.fields.bPlayerFinishedLevelLoad = False
        self.tick()
        self.assert_settings(DESIRED)
        self.ctx.game_pawn.fields.bPlayerFinishedLevelLoad = True
        self.tick()
        self.assert_settings(ORIGINAL)
        self.ctx.widget = True
        self.tick()
        self.assert_settings(DESIRED)
        self.ctx.widget = False
        self.tick()
        self.assert_settings(ORIGINAL)

    def test_unknown_and_lost_runtime_release_leases(self):
        for field in ('ready', 'controllers'):
            self.tick()
            self.ctx[field] = False
            self.tick()
            self.assert_settings(ORIGINAL)
            self.assertFalse(self.ctx.pc.fields.bShowMouseCursor)
            self.ctx[field] = True
        self.tick()
        self.ctx.pc = None
        self.tick()
        self.assert_settings(ORIGINAL)

    def test_external_setting_change_yields_until_menu_exit(self):
        self.tick()
        self.ctx.settings.VR_AimMethod = '5'
        self.tick()
        self.tick()
        self.assert_settings(dict(ORIGINAL, VR_AimMethod='5'))
        self.game()
        self.tick()
        self.ctx.paused = True
        self.tick()
        self.assert_settings(DESIRED)
        self.ctx.paused = False
        self.tick()
        self.assert_settings(dict(ORIGINAL, VR_AimMethod='5'))

    def test_failed_apply_rolls_back_and_bounds_errors(self):
        self.ctx.setter_fault = 'VR_DecoupledPitchUIAdjust'
        for _ in range(3):
            self.tick()
            self.assert_settings(ORIGINAL)
        self.assertEqual(self.ctx.logged, 3)
        self.ctx.setter_fault = None
        self.tick()
        self.assert_settings(ORIGINAL)

    def test_error_after_mutation_retains_recovery(self):
        self.ctx.after_write_fault = 'UI_FollowView'
        self.tick()
        self.ctx.after_write_fault = None
        self.game()
        self.tick()
        self.assert_settings(ORIGINAL)

    def test_missing_setting_and_ignored_write_roll_back(self):
        self.ctx.settings.UI_FollowView = ''
        self.tick()
        self.assertEqual(self.ctx.settings.VR_AimMethod, '2')
        self.ctx.settings.UI_FollowView = 'true'
        self.ctx.ignore_write = 'UI_FollowView'
        self.tick()
        self.assert_settings(ORIGINAL)

    def test_restore_retries_after_circuit_breaker(self):
        self.tick()
        self.ctx.setter_fault = 'VR_AimMethod'
        self.game()
        for _ in range(3):
            self.tick()
        self.assertEqual(self.ctx.settings.UI_FollowView, 'true')
        self.ctx.setter_fault = None
        self.tick()
        self.assert_settings(ORIGINAL)

    def test_dead_controller_is_not_written_on_restore(self):
        self.tick()
        self.ctx.front_pc.dead = True
        self.game()
        self.tick()
        self.assert_settings(ORIGINAL)
        self.assertEqual(self.ctx.cursor_writes, 1)

    def test_widget_probe_failure_keeps_pause_detection_available(self):
        self.game()
        self.ctx.widget_fault = True
        self.tick()
        self.assert_settings(ORIGINAL)
        self.ctx.paused = True
        self.tick()
        self.assert_settings(DESIRED)

    def test_capture_identity_and_intro_refresh_are_preserved(self):
        self.tick()
        self.tick()
        self.assertEqual(self.ctx.captures, 1)
        self.game()
        self.ctx.game_pawn.fields.bPlayerFinishedLevelLoad = False
        self.tick()
        self.assertEqual(self.ctx.captures, 2)
        self.ctx.now = .19
        self.tick()
        self.assertEqual(self.ctx.captures, 2)
        self.ctx.now = .21
        self.tick()
        self.assertEqual(self.ctx.captures, 3)

    def test_capture_fault_and_abi_mismatch_do_not_disable_stability(self):
        self.ctx.capture_fault = True
        self.tick()
        self.assert_settings(DESIRED)
        self.assertTrue(self.ctx.pc.fields.bShowMouseCursor)

    def test_capture_abi_mismatch_is_not_called(self):
        self.ctx.bad_signature = True
        self.tick()
        self.assert_settings(DESIRED)
        self.assertEqual(self.ctx.captures, 0)

    def test_missing_cursor_property_keeps_stability(self):
        self.ctx.pc.fields.bShowMouseCursor = None
        self.tick()
        self.assert_settings(DESIRED)
        self.assertEqual(self.ctx.cursor_writes, 0)

    def test_unknown_scene_never_acquires_settings_or_pointer(self):
        self.game()
        self.ctx.game_pawn.name = 'SpectatorPawn /Game/Maps/Map01.PersistentLevel.Pawn_1'
        self.ctx.paused = True
        self.tick()
        self.assert_settings(ORIGINAL)
        self.assertEqual((self.ctx.writes, self.ctx.cursor_writes, self.ctx.captures), (0, 0, 0))

    def test_external_change_to_each_ui_setting_releases_the_group(self):
        for key in ('UI_FollowView', 'VR_DecoupledPitchUIAdjust'):
            with self.subTest(key=key):
                self.setUp()
                self.tick()
                self.ctx.settings[key] = 'true'
                self.tick()
                self.tick()
                self.assert_settings(ORIGINAL)
                self.assertFalse(self.ctx.front_pc.fields.bShowMouseCursor)
                self.assertEqual(self.ctx.writes, 5)

    def test_unreadable_setting_never_partially_acquires(self):
        self.ctx.read_fault = 'VR_DecoupledPitchUIAdjust'
        self.tick()
        self.assert_settings(ORIGINAL)
        self.assertEqual((self.ctx.writes, self.ctx.cursor_writes, self.ctx.captures), (0, 0, 0))

    def test_restore_read_fault_does_not_block_other_settings_or_cursor(self):
        self.tick()
        self.ctx.read_fault = 'VR_AimMethod'
        self.game()
        self.tick()
        self.assertEqual(self.ctx.settings.UI_FollowView, 'true')
        self.assertEqual(self.ctx.settings.VR_DecoupledPitchUIAdjust, 'true')
        self.assertFalse(self.ctx.front_pc.fields.bShowMouseCursor)
        self.ctx.read_fault = None
        self.tick()
        self.assert_settings(ORIGINAL)

    def test_reset_yields_external_changes_and_restores_remaining_owners(self):
        self.tick()
        self.ctx.settings.UI_FollowView = 'true'
        self.ctx.pc.fields.bShowMouseCursor = False
        self.reset()
        self.assert_settings(ORIGINAL)
        self.assertFalse(self.ctx.pc.fields.bShowMouseCursor)
        self.assertEqual(self.ctx.cursor_writes, 1)
        writes = self.ctx.writes
        self.tick()
        self.assertEqual(self.ctx.writes, writes)

    def test_cursor_failure_is_optional_and_not_repeated(self):
        self.ctx.cursor_fault = True
        for _ in range(5):
            self.tick()
            self.assert_settings(DESIRED)
        self.ctx.cursor_fault = None
        self.tick()
        self.assertFalse(self.ctx.pc.fields.bShowMouseCursor)
        self.game()
        self.tick()
        self.assert_settings(ORIGINAL)

    def test_cursor_error_after_mutation_can_still_restore(self):
        self.ctx.cursor_after_fault = True
        self.tick()
        self.assert_settings(DESIRED)
        self.ctx.cursor_after_fault = None
        self.game()
        self.tick()
        self.assertFalse(self.ctx.front_pc.fields.bShowMouseCursor)

    def test_cursor_restore_retries_when_script_is_stopped(self):
        self.tick()
        self.ctx.cursor_fault = True
        self.reset()
        self.assertTrue(self.ctx.pc.fields.bShowMouseCursor)
        self.ctx.cursor_fault = None
        self.tick()
        self.assertFalse(self.ctx.pc.fields.bShowMouseCursor)
        self.assert_settings(ORIGINAL)

    def test_preexisting_visible_cursor_is_left_visible(self):
        self.ctx.pc.fields.bShowMouseCursor = True
        self.tick()
        self.game()
        self.tick()
        self.assertTrue(self.ctx.front_pc.fields.bShowMouseCursor)
        self.assertEqual(self.ctx.cursor_writes, 0)

    def test_framework_overlay_releases_native_cursor_and_reenters_menu(self):
        self.tick()
        self.ctx.overlay = True
        self.tick()
        self.assert_settings(DESIRED)
        self.assertFalse(self.ctx.front_pc.fields.bShowMouseCursor)
        self.assertEqual(self.ctx.captures, 1)
        self.ctx.overlay = False
        self.tick()
        self.assertTrue(self.ctx.front_pc.fields.bShowMouseCursor)
        self.assertEqual(self.ctx.captures, 2)

    def test_capture_refocuses_on_widget_and_visibility_change(self):
        self.game()
        self.ctx.paused = True
        self.tick()
        self.tick()
        self.assertEqual(self.ctx.captures, 1)
        self.assertTrue(self.lua.eval('ctx.capture_menu == ctx.menu_widget'))
        self.ctx.menu_widget.fields.Visibility = 1
        self.tick()
        self.assertEqual(self.ctx.captures, 2)

    def test_missing_input_library_does_not_disable_stability_or_cursor(self):
        self.ctx.no_capture = True
        self.tick()
        self.assert_settings(DESIRED)
        self.assertTrue(self.ctx.pc.fields.bShowMouseCursor)
        self.assertEqual(self.ctx.captures, 0)

    def test_gameplay_does_not_write_aim_flag_or_pointer(self):
        self.game()
        self.tick()
        self.assert_settings(ORIGINAL)
        self.assertEqual((self.ctx.aim_writes, self.ctx.writes, self.ctx.cursor_writes,
                          self.ctx.captures, self.ctx.logged), (0, 0, 0, 0, 0))

    def test_capture_uses_the_confirmed_pause_snapshot(self):
        self.game()
        self.ctx.paused = True
        self.ctx.fail_second_pause_read = True
        self.tick()
        self.assert_settings(DESIRED)
        self.assertEqual((self.ctx.captures, self.ctx.pause_reads), (1, 1))

    def test_pause_change_refocuses_the_same_visible_widget(self):
        self.game()
        self.ctx.widget = True
        self.tick()
        self.ctx.paused = True
        self.tick()
        self.assertEqual(self.ctx.captures, 2)

    def test_reset_on_ui_thread_never_touches_uobjects(self):
        self.tick()
        self.reset()
        self.assertEqual(self.ctx.offthread, 0)
        self.assert_settings(ORIGINAL)
        self.assertTrue(self.ctx.front_pc.fields.bShowMouseCursor)
        self.tick()
        self.assertFalse(self.ctx.front_pc.fields.bShowMouseCursor)

    def test_reload_recovers_cursor_when_old_callback_is_unregistered(self):
        self.tick()
        self.reset()
        self.assertEqual(self.ctx.offthread, 0)
        self.assertTrue(self.ctx.front_pc.fields.bShowMouseCursor)
        self.lua.execute(SCRIPT.read_text(encoding='utf-8'))
        self.game()
        self.tick()
        self.assertFalse(self.ctx.front_pc.fields.bShowMouseCursor)
        self.assertEqual(self.ctx.files['boltgun_menu_cursor.owned'], '')

    def test_reload_in_menu_preserves_the_original_cursor_owner(self):
        self.tick()
        self.reset()
        self.lua.execute(SCRIPT.read_text(encoding='utf-8'))
        self.tick()
        self.assertTrue(self.ctx.front_pc.fields.bShowMouseCursor)
        self.game()
        self.tick()
        self.assertFalse(self.ctx.front_pc.fields.bShowMouseCursor)

    def test_cursor_journal_failure_never_mutates_cursor_or_breaks_settings(self):
        self.ctx.fs_write_fault = True
        self.tick()
        self.assert_settings(DESIRED)
        self.assertFalse(self.ctx.front_pc.fields.bShowMouseCursor)
        self.assertEqual(self.ctx.cursor_writes, 0)

    def test_journal_from_different_engine_never_restores_its_controller(self):
        self.tick()
        self.reset()
        self.ctx.engine.address = 999
        self.lua.execute(SCRIPT.read_text(encoding='utf-8'))
        self.game()
        self.tick()
        self.assertTrue(self.ctx.front_pc.fields.bShowMouseCursor)
        self.assertEqual(self.ctx.cursor_writes, 1)
        self.assertEqual(self.ctx.files['boltgun_menu_cursor.owned'], '')

    def test_replaced_controller_is_not_written_on_reload(self):
        self.tick()
        self.reset()
        self.ctx.front_pc.address = 999
        self.lua.execute(SCRIPT.read_text(encoding='utf-8'))
        self.game()
        self.tick()
        self.assertTrue(self.ctx.front_pc.fields.bShowMouseCursor)
        self.assertEqual(self.ctx.cursor_writes, 1)

    def test_optional_hud_failure_does_not_release_confirmed_pause(self):
        self.game()
        self.ctx.paused = True
        self.ctx.hud_fault = True
        for _ in range(4):
            self.tick()
            self.assert_settings(DESIRED)
        self.ctx.hud_fault = False
        self.tick()
        self.assert_settings(DESIRED)

    def test_cleanup_takeover_observed_after_read_error_is_not_reacquired(self):
        self.tick()
        self.ctx.settings.VR_AimMethod = '5'
        self.ctx.read_fault_once = 'VR_AimMethod'
        self.tick()
        self.tick()
        self.assert_settings(dict(ORIGINAL, VR_AimMethod='5'))
        self.game()
        self.tick()
        self.ctx.paused = True
        self.tick()
        self.assert_settings(DESIRED)

    def test_malformed_journal_disables_cursor_without_breaking_stability(self):
        self.ctx.files['boltgun_menu_cursor.owned'] = 'unrecognized record'
        self.tick()
        self.tick()
        self.assert_settings(DESIRED)
        self.assertEqual(self.ctx.cursor_writes, 0)
        self.assertEqual(self.ctx.files['boltgun_menu_cursor.owned'], 'unrecognized record')
        self.assertEqual(self.ctx.logged, 1)

    def test_missing_engine_defers_journal_recovery(self):
        self.tick()
        self.reset()
        saved_engine = self.ctx.engine
        self.ctx.engine = None
        self.lua.execute(SCRIPT.read_text(encoding='utf-8'))
        self.game()
        self.tick()
        self.assertTrue(self.ctx.front_pc.fields.bShowMouseCursor)
        self.ctx.engine = saved_engine
        self.tick()
        self.assertFalse(self.ctx.front_pc.fields.bShowMouseCursor)

    def test_failed_journal_clear_can_recover_in_another_instance(self):
        self.tick()
        self.reset()
        self.ctx.fs_write_fault = True
        self.tick()
        self.assertFalse(self.ctx.front_pc.fields.bShowMouseCursor)
        self.assertNotEqual(self.ctx.files['boltgun_menu_cursor.owned'], '')
        self.ctx.fs_write_fault = False
        self.lua.execute(SCRIPT.read_text(encoding='utf-8'))
        self.game()
        self.tick()
        self.assertFalse(self.ctx.front_pc.fields.bShowMouseCursor)
        self.assertEqual(self.ctx.files['boltgun_menu_cursor.owned'], '')
        self.assertEqual(self.ctx.cursor_writes, 2)

    def test_script_load_has_no_unreal_or_filesystem_side_effects(self):
        self.assertEqual((self.ctx.offthread, self.ctx.fs_writes, self.ctx.cursor_writes,
                          self.ctx.writes), (0, 0, 0, 0))


if __name__ == '__main__':
    unittest.main()
