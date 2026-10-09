import sys
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
from lupa.lua54 import LuaRuntime

class WheelTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
        ctx={active=true,menu=false,snap=true,draws=0,modreads=0,recenters=0,loading=true,
             action_calls_during_load=0,create_pressed=false,aim=2,aim_writes=0,
             left_pos={x=-0.45,y=1.2,z=-0.35},right_pos={x=0.45,y=1.2,z=-0.35}}
        mods={FrameworkConfig_AlwaysShowCursor='false',UI_Framework_MouseEmulation='true',UI_Framework_FollowView='false'}
        files={}
        fs={write=function(path,data) files[path]=data end,
            read=function(path) return files[path] or '' end}
        uevr={params={vr={
          get_mod_value=function(self,key)
            if self~=uevr.params.vr then error('missing VR instance') end
            ctx.modreads=ctx.modreads+1
            if ctx.fail_overlay then error('Overlay API unavailable') end
            return mods[key]
          end,
          set_mod_value=function(key,value) mods[key]=value end,
          save_config=function()
            ctx.saves=(ctx.saves or 0)+1
            if ctx.defer_save then ctx.queued_save=true;return end
            disk={};for key,value in pairs(mods) do disk[key]=value end;disk.snap=ctx.snap
          end,
          is_snap_turn_enabled=function()
            ctx.snap_reads=(ctx.snap_reads or 0)+1
            if ctx.fail_snap then error('Snap getter unavailable') end
            return ctx.snap
          end,
          is_using_controllers=function() return ctx.active end,
          is_hmd_active=function() return ctx.active end,
          get_left_controller_index=function() return 1 end,
          get_right_controller_index=function() return 2 end,
          get_transform=function(self,index)
            if self~=uevr.params.vr then error('missing VR instance') end
            if ctx.fail_pose then error('tracking unavailable') end
            if index==1 then return {[3]=ctx.left_pos} end
            if index==2 then return {[3]=ctx.right_pos} end
            error('unexpected controller')
          end,
          get_aim_method=function() if ctx.fail_aim_read then error('aim read failed') end;return ctx.aim end,
          set_aim_method=function(method)
            if ctx.fail_aim_write then error('aim write failed') end
            ctx.aim=method;ctx.aim_writes=ctx.aim_writes+1
          end,
          get_lowest_xinput_index=function() return 0 end,
          set_snap_turn_enabled=function(v)
            if ctx.fail_set then error('Snap setter unavailable') end
            ctx.snap=v
          end,
          get_joystick_axis=function() error('Forbidden runtime query') end,
          get_action_handle=function(path)
            if ctx.loading then ctx.action_calls_during_load=ctx.action_calls_during_load+1 end
            return path
          end,
          get_left_joystick_source=function()
            if ctx.loading then ctx.action_calls_during_load=ctx.action_calls_during_load+1 end
            return 'left'
          end,
          get_right_joystick_source=function() return 'right' end,
          is_action_active=function(action,source)
            if ctx.loading then ctx.action_calls_during_load=ctx.action_calls_during_load+1 end
            return action=='/actions/default/in/ThumbrestTouchLeft' and source=='left' and ctx.create_pressed
          end,
          is_action_active_any_joystick=function(action)
            return action=='/actions/default/in/ThumbrestTouchLeft' and ctx.create_pressed
          end,
          trigger_haptic_vibration=function(delay,duration,frequency,amplitude,source)
            if ctx.fail_haptic then error('Haptics unavailable') end
            ctx.haptics=(ctx.haptics or 0)+1
            ctx.haptic_duration=duration;ctx.haptic_amplitude=amplitude
            ctx.haptic_source=source
          end,
          recenter_view=function()
            if ctx.loading then ctx.action_calls_during_load=ctx.action_calls_during_load+1 end
            ctx.recenters=ctx.recenters+1
          end
        },functions={is_drawing_ui=function() return ctx.menu end,log_info=function() end},
        sdk={callbacks={on_pre_engine_tick=function(f) tick=f end,
          on_xinput_get_state=function(f) poll=f end,
          on_script_reset=function(f) reset=f end,on_frame=function(f)
            frame=function()
              if ctx.queued_save then
                disk={};for key,value in pairs(mods) do disk[key]=value end;disk.snap=ctx.snap
                ctx.queued_save=false
              end
              f()
            end
          end}}}}
        imgui=setmetatable({calc_text_size=function(t) return {x=#t*7,y=14} end,
          get_display_size=function() return {x=1920,y=1080} end,
          get_window_pos=function() return {x=790,y=390} end,
          begin_window=function() ctx.draws=ctx.draws+1 end},
          {__index=function() return function() end end})
        ''')
        self.lua.execute((ROOT/'profile/scripts/boltgun_sense.lua').read_text())
        self.lua.globals().ctx.loading=False
        self.lua.globals().tick(None, .01)
        self.lua.globals().frame();self.lua.globals().frame()
    def poll(self,b=0,x=0,y=0,user=0):
        p=self.lua.table_from(dict(wButtons=b,sThumbRX=int(x*32767),sThumbRY=int(y*32767),
                                  sThumbLX=1234,sThumbLY=5678,bRightTrigger=255))
        self.lua.globals().poll(None,user,self.lua.table_from(dict(Gamepad=p)))
        return p
    def close_hands(self):
        self.lua.globals().ctx.left_pos.x=.30
    def settle_hands(self):
        for _ in range(6): self.lua.globals().tick(None,.05)
    def test_two_handed_aim_activates_after_proximity_and_restores_on_separation(self):
        ctx=self.lua.globals().ctx
        self.close_hands()
        for _ in range(3): self.lua.globals().tick(None,.05)
        self.assertEqual(ctx.aim,2)
        self.settle_hands()
        self.assertEqual(ctx.aim,4)
        self.assertEqual(ctx.aim_writes,1)
        ctx.left_pos.x=-.45
        self.lua.globals().tick(None,.05)
        self.assertEqual(ctx.aim,2)
        self.assertEqual(ctx.aim_writes,2)
    def test_two_handed_proximity_spike_does_not_activate(self):
        ctx=self.lua.globals().ctx
        self.close_hands()
        self.lua.globals().tick(None,.05)
        ctx.left_pos.x=-.45
        self.lua.globals().tick(None,.05)
        self.assertEqual(ctx.aim,2)
        self.assertEqual(ctx.aim_writes,0)
    def test_two_handed_restores_on_menu_reset_and_wheel(self):
        ctx=self.lua.globals().ctx
        self.close_hands();self.settle_hands()
        self.assertEqual(ctx.aim,4)
        self.poll(128);self.lua.globals().tick(None,.05)
        self.assertEqual(ctx.aim,2)
        self.poll();ctx.menu=True;self.lua.globals().tick(None,.05)
        self.assertEqual(ctx.aim,2)
        ctx.menu=False;self.settle_hands()
        self.assertEqual(ctx.aim,4)
        self.lua.globals().reset()
        self.assertEqual(ctx.aim,2)
    def test_two_handed_requires_original_right_hand_aim(self):
        ctx=self.lua.globals().ctx
        ctx.aim=3
        self.close_hands();self.settle_hands()
        self.assertEqual(ctx.aim,3)
        self.assertEqual(ctx.aim_writes,0)
    def test_two_handed_does_not_overwrite_external_aim_change(self):
        ctx=self.lua.globals().ctx
        self.close_hands();self.settle_hands()
        ctx.aim=1
        self.lua.globals().tick(None,.05)
        ctx.left_pos.x=-.45
        self.lua.globals().reset()
        self.assertEqual(ctx.aim,1)
        self.assertEqual(ctx.aim_writes,1)
    def test_two_handed_tracking_failure_fails_closed(self):
        ctx=self.lua.globals().ctx
        self.close_hands();ctx.fail_pose=True
        self.settle_hands()
        self.assertEqual(ctx.aim,2)
        ctx.fail_pose=False;self.settle_hands()
        self.assertEqual(ctx.aim,4)
        ctx.fail_pose=True;self.lua.globals().tick(None,.05)
        self.assertEqual(ctx.aim,2)
    def test_two_handed_rejects_missing_or_identical_origin_poses(self):
        ctx=self.lua.globals().ctx
        self.close_hands()
        ctx.left_pos.x=0;ctx.left_pos.y=0;ctx.left_pos.z=0
        ctx.right_pos.x=0;ctx.right_pos.y=0;ctx.right_pos.z=0
        self.settle_hands()
        self.assertEqual(ctx.aim,2)
    def test_two_handed_can_be_disabled_via_profile_data(self):
        ctx=self.lua.globals().ctx
        self.lua.globals().files['two_hand.mode']='off\n'
        self.lua.execute((ROOT/'profile/scripts/boltgun_sense.lua').read_text())
        self.close_hands();self.settle_hands()
        self.assertEqual(ctx.aim,2)
    def test_two_handed_restores_when_controllers_disconnect(self):
        ctx=self.lua.globals().ctx
        self.close_hands();self.settle_hands()
        ctx.active=False
        self.lua.globals().tick(None,.05)
        self.assertEqual(ctx.aim,2)
    def test_two_handed_external_right_mode_requires_separation(self):
        ctx=self.lua.globals().ctx
        self.close_hands();self.settle_hands()
        self.assertEqual(ctx.aim,4)
        ctx.aim=2  # An external setting change cancels script ownership.
        self.settle_hands()
        self.assertEqual(ctx.aim,2)
        ctx.left_pos.x=-.45;self.lua.globals().tick(None,.05)
        self.close_hands();self.settle_hands()
        self.assertEqual(ctx.aim,4)
    def test_two_handed_setter_error_does_not_retry_while_near(self):
        ctx=self.lua.globals().ctx
        self.close_hands();ctx.fail_aim_write=True
        self.settle_hands()
        self.assertEqual(ctx.aim,2)
        ctx.fail_aim_write=False;self.settle_hands()
        self.assertEqual(ctx.aim,2)
        ctx.left_pos.x=-.45;self.lua.globals().tick(None,.05)
        self.close_hands();self.settle_hands()
        self.assertEqual(ctx.aim,4)
    def test_two_handed_aim_getter_failure_does_not_override_unknown_mode(self):
        ctx=self.lua.globals().ctx
        self.close_hands();ctx.fail_aim_read=True
        self.settle_hands()
        self.assertEqual(ctx.aim,2)
        ctx.fail_aim_read=False;self.settle_hands()
        self.assertEqual(ctx.aim,4)
    def test_two_handed_hysteresis_prevents_flicker(self):
        ctx=self.lua.globals().ctx
        self.close_hands();self.settle_hands()
        ctx.left_pos.x=.19  # 26 cm: between the enter and exit thresholds.
        self.settle_hands()
        self.assertEqual(ctx.aim,4)
        ctx.left_pos.x=.12  # 33 cm: disengages.
        self.lua.globals().tick(None,.05)
        self.assertEqual(ctx.aim,2)
    def test_four_sectors_commit_on_release(self):
        for x,y,mask in [(0,1,1),(0,-1,2),(-1,0,4),(1,0,8)]:
            self.assertEqual(self.poll(128,x,y).wButtons,0)
            self.assertEqual(self.poll().wButtons,mask)
            self.lua.globals().tick(None,.2)
            self.lua.globals().frame()
            self.assertEqual(self.poll().wButtons,0)
    def test_selection_haptic_is_deferred_and_single(self):
        self.poll(128,1,0);self.poll()
        self.assertIsNone(self.lua.globals().ctx.haptics)
        self.lua.globals().tick(None,.01)
        self.assertEqual(self.lua.globals().ctx.haptics,1)
        self.assertEqual(self.lua.globals().ctx.haptic_source,'right')
        self.assertAlmostEqual(self.lua.globals().ctx.haptic_duration,.025)
        self.assertAlmostEqual(self.lua.globals().ctx.haptic_amplitude,.18)
        self.lua.globals().tick(None,.01)
        self.assertEqual(self.lua.globals().ctx.haptics,1)
    def test_cancel_has_no_haptic(self):
        self.poll(128,1,0);self.poll(128);self.poll()
        self.lua.globals().tick(None,.01)
        self.assertIsNone(self.lua.globals().ctx.haptics)
    def test_haptic_failure_does_not_break_selection(self):
        self.lua.globals().ctx.fail_haptic=True
        self.poll(128,1,0)
        self.assertEqual(self.poll().wButtons,8)
        self.lua.globals().tick(None,.01)
        self.assertTrue(self.lua.globals().ctx.snap)
    def test_center_cancels(self):
        self.poll(128,0,1); self.poll(128)
        self.assertEqual(self.poll().wButtons,0)
    def test_no_snap_getter_at_injection(self):
        self.assertIsNone(self.lua.globals().ctx.snap_reads)
        self.assertEqual(self.lua.globals().ctx.modreads,0)
    def test_menu_opened_in_current_poll_cancels_selection(self):
        self.poll(128,1,0);self.lua.globals().tick(None,.01)
        self.lua.globals().ctx.menu=True
        self.assertEqual(self.poll().wButtons,0)
    def test_no_action_api_calls_at_script_load(self):
        self.assertEqual(self.lua.globals().ctx.action_calls_during_load,0)
    def test_save_while_open_is_repaired_after_release_and_next_load(self):
        self.poll(128);self.lua.globals().tick(None,.01)
        self.lua.globals().uevr.params.vr.save_config()
        self.assertEqual(self.lua.globals().disk.FrameworkConfig_AlwaysShowCursor,'true')
        self.poll();self.lua.globals().tick(None,.01)
        self.assertEqual(self.lua.globals().disk.FrameworkConfig_AlwaysShowCursor,'false')
        self.lua.globals().frame()
        self.poll(128);self.lua.globals().tick(None,.01)
        self.lua.globals().uevr.params.vr.save_config()
        self.lua.execute((ROOT/'profile/scripts/boltgun_sense.lua').read_text())
        self.lua.globals().tick(None,.01)
        self.assertEqual(self.lua.globals().mods.FrameworkConfig_AlwaysShowCursor,'false')
        self.assertTrue(self.lua.globals().ctx.snap)
    def test_reopening_is_blocked_until_deferred_save_executes(self):
        self.lua.globals().ctx.defer_save=True
        self.poll(128);self.lua.globals().tick(None,.01)
        self.poll();self.lua.globals().tick(None,.01)
        self.poll(128);self.lua.globals().tick(None,.01)
        self.assertEqual(self.lua.globals().mods.FrameworkConfig_AlwaysShowCursor,'false')
        self.lua.globals().frame()
        self.assertEqual(self.lua.globals().disk.FrameworkConfig_AlwaysShowCursor,'false')
        self.poll(128);self.lua.globals().tick(None,.01)
        self.assertEqual(self.lua.globals().mods.FrameworkConfig_AlwaysShowCursor,'true')
    def test_reset_reload_preserves_deferred_save_barrier(self):
        self.lua.globals().ctx.defer_save=True
        self.poll(128);self.lua.globals().tick(None,.01)
        self.lua.globals().reset()
        self.lua.execute((ROOT/'profile/scripts/boltgun_sense.lua').read_text())
        self.lua.globals().tick(None,.01)
        self.poll(128);self.lua.globals().tick(None,.01)
        self.assertEqual(self.lua.globals().mods.FrameworkConfig_AlwaysShowCursor,'false')
        self.lua.globals().frame()
        self.assertEqual(self.lua.globals().disk.FrameworkConfig_AlwaysShowCursor,'false')
        self.poll(128);self.lua.globals().tick(None,.01)
        self.assertEqual(self.lua.globals().mods.FrameworkConfig_AlwaysShowCursor,'false')
        self.lua.globals().frame()
        self.poll(128);self.lua.globals().tick(None,.01)
        self.assertEqual(self.lua.globals().mods.FrameworkConfig_AlwaysShowCursor,'true')
    def test_preserves_continuous_turn_setting(self):
        self.lua.globals().ctx.snap=False
        self.poll(128); self.lua.globals().tick(None,.01)
        self.poll(); self.lua.globals().tick(None,.01)
        self.lua.globals().frame()
        self.assertFalse(self.lua.globals().ctx.snap)
    def test_snap_getter_failure_cancels_wheel_without_exception(self):
        self.lua.globals().ctx.fail_snap=True
        self.poll(128); self.lua.globals().tick(None,.01)
        self.lua.globals().frame()
        self.assertEqual(self.lua.globals().ctx.draws,0)
        self.assertEqual(self.poll().wButtons,0)
        self.assertTrue(self.lua.globals().ctx.snap)
    def test_snap_setter_failure_cancels_without_exception(self):
        self.lua.globals().ctx.fail_set=True
        self.poll(128); self.lua.globals().tick(None,.01)
        self.lua.globals().frame()
        self.assertEqual(self.lua.globals().ctx.draws,0)
        self.assertTrue(self.lua.globals().ctx.snap)
    def test_snap_restored_after_release_and_reset(self):
        self.poll(128); self.lua.globals().tick(None,.01)
        self.assertFalse(self.lua.globals().ctx.snap)
        self.poll(); self.lua.globals().tick(None,.01)
        self.assertTrue(self.lua.globals().ctx.snap)
        self.lua.globals().frame()
        self.poll(128); self.lua.globals().tick(None,.01)
        self.lua.globals().reset()
        self.assertTrue(self.lua.globals().ctx.snap)
    def test_native_start_passes_through_and_menu_chord_passes_through(self):
        self.assertEqual(self.poll(16).wButtons,16)
        self.assertEqual(self.poll(64+128).wButtons,64+128)
    def test_wheel_identifies_native_weapon_groups_without_claiming_inventory(self):
        self.lua.execute('ctx.labels={}; imgui.text_colored=function(label) table.insert(ctx.labels,label) end')
        self.poll(128);self.lua.globals().tick(None,.01);self.lua.globals().frame()
        labels=list(self.lua.globals().ctx.labels.values())
        for label in ('BOLTGUN','VENGEANCE','SHOTGUN','MELTAGUN','MULTIMELTA*',
                      'PLASMA','VOLKITE','HEAVY BOLTER','GRAV-GUN','MISIL*'):
            self.assertIn(label,labels)
        self.assertIn('* DLC / SEGUN DISPONIBILIDAD',labels)
        self.assertNotIn('ARRIBA',labels)
    def test_face_button_pause_chord(self):
        self.assertEqual(self.poll(8192+32768).wButtons,16)
        self.assertEqual(self.poll(8192+32768).wButtons,0)
        self.assertEqual(self.poll().wButtons,0)
        self.assertEqual(self.poll(8192+32768).wButtons,16)
    def test_create_recenters_once_per_press(self):
        # OpenXR's left source is zero, exposed as nil by the Lua pointer wrapper.
        self.lua.execute('uevr.params.vr.get_left_joystick_source=function() return nil end')
        self.lua.globals().ctx.create_pressed=True
        self.lua.globals().tick(None,.01)
        self.assertEqual(self.lua.globals().ctx.recenters,1)
        self.lua.globals().tick(None,.01)
        self.assertEqual(self.lua.globals().ctx.recenters,1)
        self.lua.globals().ctx.create_pressed=False
        self.lua.globals().tick(None,.01)
        self.lua.globals().ctx.create_pressed=True
        self.lua.globals().tick(None,.01)
        self.assertEqual(self.lua.globals().ctx.recenters,2)
    def test_trigger_movement_preserved_and_rotation_suppressed(self):
        p=self.poll(128+4096,1,0)
        self.assertEqual((p.sThumbLX,p.sThumbLY,p.bRightTrigger,p.wButtons),(1234,5678,255,4096))
        self.assertEqual((p.sThumbRX,p.sThumbRY),(0,0))
    def test_other_user_and_inactive_untouched(self):
        self.assertEqual(self.poll(128,1,0,user=1).wButtons,128)
        self.lua.globals().ctx.active=False
        self.lua.globals().tick(None,.01)
        self.assertEqual(self.poll(128,1,0).sThumbRX,32767)
    def test_wheel_draws_only_when_open(self):
        self.lua.globals().frame(); self.assertEqual(self.lua.globals().ctx.draws,0)
        self.poll(128); self.lua.globals().frame()
        self.assertEqual(self.lua.globals().ctx.draws,1)
        self.lua.globals().ctx.menu=True; self.lua.globals().tick(None,.01)
        self.lua.globals().frame(); self.assertEqual(self.lua.globals().ctx.draws,1)
    def test_overlay_is_temporary_and_restored_on_reset(self):
        self.poll(128);self.lua.globals().tick(None,.01)
        mods=self.lua.globals().mods
        self.assertEqual(mods.FrameworkConfig_AlwaysShowCursor,'true')
        self.assertEqual(mods.UI_Framework_MouseEmulation,'false')
        self.poll();self.lua.globals().tick(None,.01)
        self.assertEqual(mods.FrameworkConfig_AlwaysShowCursor,'false')
        self.assertEqual(mods.UI_Framework_MouseEmulation,'true')
        self.assertEqual(mods.UI_Framework_FollowView,'false')
        self.lua.globals().frame()
        self.poll(128);self.lua.globals().tick(None,.01);self.lua.globals().reset()
        self.assertEqual(mods.FrameworkConfig_AlwaysShowCursor,'false')
    def test_overlay_failure_cancels_without_changing_game_input(self):
        self.lua.globals().ctx.fail_overlay=True
        self.poll(128);self.lua.globals().tick(None,.01);self.lua.globals().frame()
        self.assertEqual(self.lua.globals().ctx.draws,0)
        self.assertTrue(self.lua.globals().ctx.snap)
        self.assertEqual(self.poll(4096).wButtons,4096)

if __name__=='__main__': unittest.main()
