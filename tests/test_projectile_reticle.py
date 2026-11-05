"""Production reticle geometry and lifecycle, without a game/VR process."""
import unittest
from pathlib import Path
from lupa.lua54 import LuaRuntime
import test_bolter_preview as preview

SOURCE = Path(__file__).resolve().parents[1] / 'src/lua/boltgun_reticle.lua'


class ReticleGeometryTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.module = self.lua.execute(SOURCE.read_text(encoding='utf-8'))

    def test_ray_uses_sampled_native_rotation_and_origin(self):
        ray = self.module.ray(self.lua.eval('''{Translation={X=10,Y=20,Z=30},
            Rotation={X=0,Y=0,Z=0,W=1}}'''))
        self.assertEqual(ray.origin.x, 10)
        self.assertEqual(ray.finish.x, 10010)
        self.assertEqual(ray.finish.y, 20)

    def test_ray_rejects_invalid_rotation(self):
        self.assertIsNone(self.module.ray(self.lua.eval('''{Translation={X=0,Y=0,Z=0},
            Rotation={X=0,Y=0,Z=0,W=0}}''')))

    def test_marker_hit_and_far_plane(self):
        self.lua.globals().mod = self.module
        self.lua.execute('''ray=mod.ray({Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1}})
            eye={x=0,y=20,z=0}''')
        marker = self.lua.eval('mod.marker(ray,{point={x=100,y=0,z=0},time=.01},eye)')
        self.assertAlmostEqual(marker.position.x, 99.6)
        self.assertEqual(self.lua.eval('mod.marker(ray,{point={x=100,y=0,z=0},time=.01,initial=true},eye)'),
                         (None, 'marker-initial-overlap'))
        self.assertEqual(self.lua.eval('mod.marker(ray,nil,eye).point.x'), 10000)

    def test_marker_rejects_hit_off_ray_or_out_of_range(self):
        self.lua.globals().mod = self.module
        self.lua.execute('''ray=mod.ray({Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1}})
            eye={x=0,y=20,z=0}''')
        for point in ('{x=100,y=400,z=0}', '{x=-100,y=0,z=0}'):
            with self.subTest(point=point):
                self.assertEqual(self.lua.eval(f'mod.marker(ray,{{point={point},time=.01}},eye)'),
                                 (None, 'marker-hit-off-ray'))


class ReticleIntegrationTests(unittest.TestCase):
    """Exercise main-module wiring; lifecycle tests below run the real adapter."""

    def setUp(self):
        fixture = preview.BolterPreviewTests()
        fixture.reload = lambda: None
        fixture.setUp()
        self.lua, self.tick = fixture.lua, fixture.tick
        self.lua.execute('''
        ctx.reticle_loads=0;ctx.reticle_steps=0;ctx.reticle_stops=0
        package.preload.boltgun_reticle=function()
          ctx.reticle_loads=ctx.reticle_loads+1
          if ctx.reticle_missing then error('reticle unavailable') end
          return {new=function(api)
            assert(api==uevr)
            return {step=function(self,owner,equipped,enabled)
              engine_only();ctx.reticle_steps=ctx.reticle_steps+1
              ctx.reticle_owner=owner;ctx.reticle_weapon=equipped;ctx.reticle_enabled=enabled
            end,stop=function()ctx.reticle_stops=ctx.reticle_stops+1 end}
          end}
        end
        uevr.params.sdk.callbacks.on_post_engine_tick=function(f)post_tick=f end
        ''')

    def load(self):
        self.lua.execute((SOURCE.parent / 'boltgun_bolter3d.lua').read_text(encoding='utf-8'))

    def post_tick(self):
        self.lua.globals().ctx.engine_thread = True
        try:
            self.lua.execute('post_tick()')
        finally:
            self.lua.globals().ctx.engine_thread = False

    def value(self, code):
        return self.lua.eval(code)

    def test_owner_and_equipped_weapon_are_forwarded_only_on_post_engine_tick(self):
        self.load()
        self.assertEqual(self.value('ctx.queries'), 0)
        self.assertEqual(self.value('ctx.reticle_loads'), 1)
        self.post_tick()
        self.assertFalse(self.value('ctx.reticle_enabled'))
        self.tick()
        self.assertEqual(self.value('ctx.reticle_steps'), 1)
        self.post_tick()
        self.assertTrue(self.value('ctx.reticle_enabled'))
        self.assertTrue(self.value('ctx.reticle_owner==pawn and ctx.reticle_weapon==weapon'))

    def test_missing_callback_skips_the_optional_dependency(self):
        self.lua.execute('uevr.params.sdk.callbacks.on_post_engine_tick=nil')
        self.load()
        self.tick()
        self.assertEqual(self.value('ctx.reticle_loads'), 0)
        self.assertEqual(self.value('ctx.created'), 1)

    def test_require_failure_keeps_the_original_hud_path_and_weapon_preview(self):
        self.lua.execute('ctx.reticle_missing=true')
        self.load()
        self.assertIn('World reticle unavailable; retaining original HUD reticle',
                      self.value('ctx.logs[#ctx.logs]'))
        self.tick()
        self.assertEqual(self.value('ctx.created'), 1)
        self.assertEqual(self.value('ctx.reticle_steps'), 0)
        self.assertIsNone(self.value('post_tick'))

    def test_no_published_muzzle_or_owned_mesh_never_enables_reticle(self):
        for change in ('ctx.fail_event=true', 'ctx.mesh_loaded=false;ctx.mesh_load_allowed=false',
                       "files['bolter3d.settings']='muzzle_enabled=0'", "files['bolter3d.mode']='off'"):
            with self.subTest(change=change):
                self.setUp()
                self.lua.execute(change)
                self.load()
                self.tick()
                self.post_tick()
                self.assertFalse(self.value('ctx.reticle_enabled'))

    def test_main_reset_stops_reticle_without_uobject_access(self):
        self.load()
        self.tick()
        before = self.value('ctx.queries')
        self.lua.execute('reset()')
        self.assertEqual(self.value('ctx.queries'), before)
        self.assertEqual(self.value('ctx.reticle_stops'), 1)
        self.post_tick()
        self.assertFalse(self.value('ctx.reticle_enabled'))


class ReticleLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(FIXTURE)
        self.lua.globals().mod = self.lua.execute(SOURCE.read_text(encoding='utf-8'))
        self.run_lua('reticle=mod.new(uevr)')

    def run_lua(self, code):
        self.lua.execute(code)

    def value(self, code):
        return self.lua.eval(code)

    def frame(self, enabled=True):
        self.lua.globals().enabled = enabled
        self.run_lua('reticle:step(pawn,weapon,enabled)')

    def assert_hidden(self):
        self.assertFalse(self.value('part.bVisible'))
        self.assertTrue(self.value('part.bHiddenInGame'))
        self.assertAlmostEqual(self.value('image.opacity'), .375)

    def test_real_trace_uses_native_sample_and_places_camera_facing_marker(self):
        self.frame()
        self.assertFalse(self.value('reticle.stopped'), self.value('ctx.log'))
        self.assertEqual(self.value('ctx.traces'), 1)
        self.assertEqual(self.value('ctx.breaks'), 1)
        for field, expected in (('start.X', 10), ('start.Y', 20), ('start.Z', 30),
                                ('finish.X', 10), ('finish.Y', 10020), ('finish.Z', 30),
                                ('location.X', 10), ('location.Y', 119.6), ('location.Z', 30),
                                ('rotation.Pitch', 0), ('rotation.Yaw', -90),
                                ('rotation.Roll', 0), ('scale.X', .002334375),
                                ('scale.Y', .002334375), ('scale.Z', .002334375)):
            with self.subTest(field=field):
                self.assertAlmostEqual(self.value('ctx.' + field), expected)
        self.assertTrue(self.value('part.bVisible and not part.bHiddenInGame'))
        self.assertEqual(self.value('image.opacity'), 0)
        self.assertEqual(self.value('other_image.opacity'), .8)
        self.assertTrue(self.value('ctx.collision==0 and ctx.overlaps==false and ctx.mobility==2'))
        self.assertTrue(self.value('ctx.shadow==false and ctx.owner_no_see==false and ctx.only_owner==false'))

    def test_trace_miss_places_far_plane_instead_of_reusing_previous_hit(self):
        self.frame()
        self.run_lua('ctx.hit=false')
        self.frame()
        self.assertEqual(self.value('ctx.traces'), 2)
        self.assertEqual(self.value('ctx.breaks'), 1)
        self.assertAlmostEqual(self.value('ctx.location.Y'), 10019.6)
        self.assertTrue(self.value('part.bVisible and not reticle.stopped'))

    def test_valid_near_muzzle_hit_stays_on_current_firing_ray(self):
        self.run_lua('ctx.eye.X=-40;ctx.hit_y=.2;ctx.time=.00002')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'placed', self.value('ctx.log'))
        self.assertAlmostEqual(self.value('ctx.location.X'), 10)
        self.assertAlmostEqual(self.value('ctx.location.Y'), 20.1)
        self.assertEqual(self.value('reticle.near_placed'), 1)
        self.assertEqual(self.value('image.opacity'), 0)

    def test_exact_muzzle_contact_without_overlap_stays_at_muzzle(self):
        self.run_lua('ctx.eye.X=-40;ctx.hit_y=0;ctx.time=0')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'placed', self.value('ctx.log'))
        self.assertAlmostEqual(self.value('ctx.location.Y'), 20)
        self.assertEqual(self.value('image.opacity'), 0)

    def test_initial_overlap_hides_both_glyphs_until_next_clear_hit(self):
        self.frame()
        self.run_lua('ctx.initial=true')
        self.frame()
        self.assertFalse(self.value('part.bVisible'))
        self.assertTrue(self.value('part.bHiddenInGame'))
        self.assertEqual(self.value('image.opacity'), 0)
        self.assertEqual(self.value('reticle.status'), 'marker-initial-overlap')
        self.assertEqual(self.value('reticle.placed'), 1)
        self.run_lua('ctx.initial=false;ctx.hit_y=200;ctx.time=.02')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'placed')
        self.assertAlmostEqual(self.value('ctx.location.Y'), 219.6)

    def test_status_retains_geometry_and_overlap_after_pause(self):
        self.run_lua('ctx.initial=true')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'marker-initial-overlap')
        self.assertEqual(self.value('reticle.geometry_rejected'), 1)
        self.assertEqual(self.value('image.opacity'), 0)
        self.run_lua('reticle.ticks=120;ctx.paused=true')
        self.frame()
        self.assert_hidden()
        status = self.value('ctx.status_file')
        self.assertIn('stage=paused-or-menu\n', status)
        self.assertIn('geometry_rejected=1\n', status)
        self.assertIn('last_geometry_rejection=marker-initial-overlap\n', status)
        self.assertIn('initial_overlaps=1\n', status)

    def test_sampling_failure_restores_hud_after_confirmed_overlap(self):
        for failure, stage in (('ctx.ack=false', 'native-ack-missing'),
                               ("ctx.fail='LineTraceSingle'", 'api-error')):
            with self.subTest(failure=failure):
                self.setUp()
                self.run_lua('ctx.initial=true')
                self.frame()
                self.assertEqual(self.value('image.opacity'), 0)
                self.run_lua(failure)
                self.frame()
                self.assert_hidden()
                self.assertEqual(self.value('reticle.status'), stage)

    def test_silent_world_setter_failure_hides_marker_and_restores_hud(self):
        for field in ('noop_location', 'noop_rotation', 'noop_scale'):
            with self.subTest(field=field):
                self.setUp()
                self.frame()
                self.lua.globals().ctx[field] = True
                self.frame()
                self.assert_hidden()
                self.assertFalse(self.value('reticle.stopped'))
                self.assertEqual(self.value('ctx.traces'), 2)
                self.lua.globals().ctx[field] = False
                self.frame()
                self.assertTrue(self.value('part.bVisible'))
                self.assertEqual(self.value('image.opacity'), 0)

    def test_rejected_native_ack_cannot_reuse_previous_visible_sample(self):
        self.frame()
        self.run_lua('ctx.ack=false')
        self.frame()
        self.assert_hidden()
        self.assertEqual(self.value('ctx.traces'), 1)
        self.assertEqual(self.value('ctx.placements'), 1)
        self.assertFalse(self.value('reticle.stopped'))
        self.run_lua('ctx.ack=true;ctx.sample.Translation.Y=70')
        self.frame()
        self.assertEqual(self.value('ctx.traces'), 2)
        self.assertAlmostEqual(self.value('ctx.start.Y'), 70)
        self.assertAlmostEqual(self.value('ctx.location.Y'), 169.6)

    def test_world_widget_uses_original_brush_alpha_and_no_palette(self):
        self.frame()
        self.assertFalse(self.value('reticle.stopped'), self.value('ctx.log'))
        self.assertTrue(self.value('part.class==widgetclass and part.widget~=cross'))
        self.assertTrue(self.value('world_image.Brush.ResourceObject==glyph'))
        self.assertAlmostEqual(self.value('world_image.ColorAndOpacity.A'), .65)
        self.assertAlmostEqual(self.value('world_image.opacity'), .375)
        self.assertEqual(self.value('part.space'), 0)
        self.assertEqual(self.value('part.BlendMode'), 2)
        self.assertEqual(self.value('part.background.A'), 0)
        self.assertGreaterEqual(self.value('part.size.X'), 128)
        self.assertEqual(self.value('part.pivot.X'), .5)
        self.assertFalse(self.value('part.focusable'))
        self.assertTrue(self.value('part.material==alpha_material'))
        self.assertEqual(self.value('reticle.material'), 'original-hud-brush-alpha')
        self.assertEqual(self.value('ctx.imports'), 0)
        self.assertEqual(self.value('ctx.mesh_requests'), 0)
        self.assertEqual(self.value('world_image.Brush.ImageSize.X'), 32)

    def test_live_weapon_brush_and_settings_refresh_without_recreating_component(self):
        self.frame()
        self.run_lua('image.Brush=dlc_brush;image.ColorAndOpacity={R=.2,G=.4,B=.8,A=.5};'
                     'image.RenderTransform.Scale={X=1.5,Y=1.5}')
        self.frame()
        self.assertTrue(self.value('world_image.Brush.ResourceObject==dlc_glyph'))
        self.assertEqual(self.value('world_image.Brush.ImageSize.X'), 64)
        self.assertAlmostEqual(self.value('world_image.ColorAndOpacity.B'), .8)
        self.assertAlmostEqual(self.value('world_image.RenderTransform.Scale.X'), 1.5)
        self.assertEqual(self.value('world_image.opacity'), .375)
        self.assertEqual(self.value('ctx.created'), 1)
        self.assertEqual(self.value('ctx.widget_creates'), 1)
        self.assertEqual(self.value('ctx.material_creates'), 1)
        self.assertGreaterEqual(self.value('part.size.X'), 192)

    def test_widget_dynamic_material_is_not_recreated_each_tick(self):
        self.run_lua('ctx.get_material_returns_instance=true')
        self.frame()
        self.assertFalse(self.value('reticle.stopped'), self.value('ctx.log'))
        self.frame()
        self.assertFalse(self.value('reticle.stopped'), self.value('ctx.log'))
        self.assertEqual(self.value('ctx.material_creates'), 1)

    def test_missing_or_empty_original_brush_restores_hud_and_can_resume(self):
        for change in ('image.Brush=nil', 'image.Brush.ResourceObject=nil',
                       'glyph.valid=false', 'image.Brush.ImageSize.X=0',
                       'image.Brush.ImageSize.Y=0/0'):
            with self.subTest(change=change):
                self.setUp()
                self.frame()
                self.run_lua(change)
                self.frame()
                self.assert_hidden()
                self.assertFalse(self.value('reticle.stopped'), self.value('ctx.log'))
                self.run_lua('glyph.valid=true;image.Brush=dlc_brush')
                self.frame()
                self.assertTrue(self.value('part.bVisible'))

    def test_unverified_or_depth_disabled_alpha_material_never_replaces_hud(self):
        for change in (
            'alpha_material.valid=false', 'alpha_material.name=pickup.name',
            'alpha_material.Parent=nil', 'alpha_parent.name=unlit.name',
            'alpha_parent.MaterialDomain=1', 'alpha_parent.ShadingModels.ShadingModelField=3',
            'alpha_parent.bDisableDepthTest=true', 'alpha_material.BasePropertyOverrides=nil',
            'overrides.BlendMode=0', 'overrides.bOverride_BlendMode=false;alpha_parent.BlendMode=0',
            'overrides.bOverride_ShadingModel=true;overrides.ShadingModel=1',
            'overrides.bOverride_BlendMode=nil', 'overrides.TwoSided=false',
        ):
            with self.subTest(change=change):
                self.setUp()
                self.run_lua(change)
                self.frame()
                self.assertFalse(self.value('part.bVisible'))
                self.assertEqual(self.value('image.opacity'), .375)
                self.assertEqual(self.value('ctx.traces'), 0)
                self.assertEqual(self.value('reticle.acks'), 0)
                self.assertEqual(self.value('reticle.status'), 'widget-alpha-unavailable')
                self.assertFalse(self.value('reticle.stopped'))

    def test_material_override_applies_only_when_enabled(self):
        self.run_lua('alpha_parent.BlendMode=0;overrides.ShadingModel=1')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'placed', self.value('ctx.log'))

    def test_material_loss_restores_hud_after_successful_placement(self):
        self.frame()
        self.run_lua('alpha_parent.bDisableDepthTest=true')
        self.frame()
        self.assert_hidden()
        self.assertEqual(self.value('reticle.status'), 'widget-alpha-unavailable')
        self.assertEqual(self.value('ctx.traces'), 1)

    def test_widget_setters_are_checked_before_hud_suppression(self):
        for change in ('ctx.reject_widget=true', 'ctx.reject_brush=true',
                       'ctx.reject_material=true', 'ctx.reject_draw_size=true'):
            with self.subTest(change=change):
                self.setUp()
                self.run_lua(change)
                self.frame()
                self.assert_hidden()
                self.assertTrue(self.value('reticle.stopped'))
                self.assertEqual(self.value('ctx.destroyed'), 1)

    def test_hud_remains_until_render_target_and_native_glyph_redraw_complete(self):
        self.run_lua('ctx.auto_render=false;ctx.render_ready=false')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'glyph-render-pending')
        self.assertTrue(self.value('not part.bHiddenInGame and part.bVisible and part.offscreen'))
        self.assertEqual(self.value('image.opacity'), .375)
        self.assertEqual(self.value('ctx.traces'), 0)
        self.run_lua('ctx.render_ready=true;visibility_changes=part.visibility_changes')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'glyph-render-pending')
        self.assertEqual(self.value('image.opacity'), .375)
        self.assertEqual(self.value('part.visibility_changes'), self.value('visibility_changes'))
        self.run_lua('draw_widget()')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'placed')
        self.assertEqual(self.value('image.opacity'), 0)
        self.assertEqual(self.value('ctx.traces'), 1)

    def test_changed_native_glyph_keeps_hud_until_its_new_frame_is_drawn(self):
        self.frame()
        self.run_lua('ctx.auto_render=false;image.Brush=dlc_brush')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'glyph-render-pending')
        self.assertTrue(self.value('not part.bHiddenInGame and part.bVisible'))
        self.assertEqual(self.value('image.opacity'), .375)
        self.run_lua('draw_widget()')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'placed')
        self.assertEqual(self.value('image.opacity'), 0)
        self.assertTrue(self.value('world_image.Brush.ResourceObject==dlc_glyph'))

    def test_proxy_redraw_does_not_invalidate_unchanged_glyph_on_same_target(self):
        self.frame()
        self.run_lua('ctx.auto_render=false;part.bRedrawRequested=true')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'placed')
        self.assertEqual(self.value('image.opacity'), 0)
        self.run_lua("target=obj('TextureRenderTarget2D Test.RecreatedGlyph','new_target')")
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'glyph-render-pending')
        self.assertEqual(self.value('image.opacity'), .375)
        self.assertEqual(self.value('reticle.acks'), 2)

    def test_wrong_render_target_binding_cannot_hide_original_hud(self):
        self.run_lua('ctx.wrong_slate=true')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'glyph-render-pending')
        self.assertTrue(self.value('part.transform.Scale3D.X==0'))
        self.assertEqual(self.value('image.opacity'), .375)
        self.assertEqual(self.value('ctx.traces'), 0)

    def test_warmup_scale_failure_keeps_component_hidden_and_can_retry(self):
        self.run_lua('ctx.auto_render=false;ctx.noop_scale=true')
        self.frame()
        self.assert_hidden()
        self.assertEqual(self.value('reticle.status'), 'warmup-scale-readback')
        self.assertEqual(self.value('reticle.acks'), 0)
        self.run_lua('ctx.noop_scale=false')
        self.frame()
        self.run_lua('draw_widget()')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'placed')

    def test_warmup_rejects_collision_before_enabling_visibility(self):
        self.run_lua('ctx.auto_render=false;ctx.reject_collision=true')
        self.frame()
        self.assert_hidden()
        self.assertEqual(self.value('reticle.status'), 'warmup-collision-enabled')
        self.assertEqual(self.value('reticle.acks'), 0)

    def test_slate_binding_on_wrong_mid_parent_cannot_hide_original_hud(self):
        self.run_lua('ctx.wrong_mid_parent=true;ctx.get_material_returns_instance=true')
        self.frame()
        self.assert_hidden()
        self.assertEqual(self.value('reticle.status'), 'widget-alpha-unavailable')
        self.assertEqual(self.value('reticle.acks'), 0)
        self.assertEqual(self.value('ctx.traces'), 0)

    def test_missing_redraw_reflection_keeps_original_hud(self):
        self.run_lua("ctx.missing_property='bRedrawRequested'")
        self.frame()
        self.assert_hidden()
        self.assertEqual(self.value('reticle.status'), 'glyph-redraw-unavailable')
        self.assertEqual(self.value('reticle.acks'), 0)

    def test_reset_during_widget_warmup_releases_owned_widget(self):
        self.run_lua('ctx.render_ready=false')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'glyph-render-pending')
        self.assertTrue(self.value('part.widget~=nil and part.widget~=cross'))
        self.run_lua('oldpart=part;reticle:stop();reticle=mod.new(uevr)')
        self.frame(False)
        self.assertTrue(self.value('not oldpart.valid and oldpart.widget==nil'))
        self.assertEqual(self.value('ctx.destroyed'), 1)
        self.assertEqual(self.value('ctx.journal'), '')
        self.assertEqual(self.value('image.opacity'), .375)
        self.assertEqual(self.value('reticle.acks'), 0)

    def test_native_visibility_changes_never_leave_world_marker_visible(self):
        for target in ('image','cross','root'):
            with self.subTest(target=target):
                self.setUp()
                self.frame()
                self.run_lua(target+'.Visibility=2')
                self.frame()
                self.assert_hidden()
                self.run_lua(target+'.Visibility=0')
                self.frame()
                self.assertTrue(self.value('part.bVisible and not part.bHiddenInGame'))

    def test_recovery_removes_previous_procedural_marker_without_creating_one(self):
        self.frame()
        self.run_lua('part.class=partclass;reticle:stop();reticle=mod.new(uevr)')
        self.frame(False)
        self.assertFalse(self.value('reticle.stopped'),self.value('ctx.log'))
        self.assertEqual(self.value('ctx.journal'),'')
        self.assertEqual(self.value('ctx.destroyed'),1)
        self.assertEqual(self.value('image.opacity'),.375)

    def test_status_identifies_silent_rejection_and_survives_without_log_spam(self):
        self.run_lua('ctx.ack=false')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'native-ack-missing')
        self.assertIn('stage=native-ack-missing', self.value('ctx.status_file'))
        self.run_lua('for i=1,600 do reticle:step(pawn,weapon,true) end')
        self.assertLessEqual(self.value('ctx.status_writes'), 6)
        self.assertLessEqual(self.value('#ctx.logs'), 3)
        self.assertEqual(self.value('ctx.traces'), 0)
        self.run_lua('ctx.ack=true')
        self.frame()
        self.assertEqual(self.value('reticle.status'), 'placed')
        self.assertTrue(self.value('part.bVisible'))

    def test_status_distinguishes_gates_sample_placement_and_facing(self):
        for change, stage in (
                ('enabled=false', 'integration-disabled'),
                ('ctx.runtime=false', 'runtime-not-ready'),
                ('handler.outer=foreign', 'weapon-owner-gate'),
                ('ctx.paused=true', 'paused-or-menu'),
                ('ctx.sample.Rotation.W=0', 'native-ray-invalid'),
                ('camera.valid=false', 'camera-unavailable'),
                ('ctx.noop_location=true', 'placement-readback'),
                ('ctx.noop_rotation=true', 'facing-readback')):
            with self.subTest(stage=stage):
                self.setUp()
                self.frame()
                self.run_lua('enabled=true;' + change)
                self.run_lua('reticle:step(pawn,weapon,enabled)')
                self.assertEqual(self.value('reticle.status'), stage)
                self.assert_hidden()

    def test_diagnostic_file_failure_does_not_disable_marker_or_break_ownership(self):
        self.run_lua('ctx.status_fail=true')
        self.frame()
        self.assertFalse(self.value('reticle.stopped'))
        self.assertTrue(self.value('part.bVisible'))
        self.assertNotEqual(self.value('ctx.journal'), '')

    def test_successive_frames_retain_exact_hud_snapshot_until_disable(self):
        self.frame()
        self.run_lua('journal_after_first=ctx.journal;writes_after_first=ctx.journal_writes')
        self.frame()
        self.assertEqual(self.value('ctx.journal'), self.value('journal_after_first'))
        self.assertEqual(self.value('ctx.journal_writes'), self.value('writes_after_first'))
        self.assertEqual(self.value('#ctx.opacity_writes'), 2)
        self.assertEqual(self.value('ctx.opacity_writes[1]'), 0)
        self.assertEqual(self.value('ctx.opacity_writes[2]'), 0)
        self.frame(False)
        self.assert_hidden()
        self.assertEqual(self.value('ctx.opacity_writes[3]'), .375)
        self.assertEqual(self.value('ctx.destroyed'), 0)
        self.frame()
        self.frame(False)
        self.assert_hidden()
        self.assertEqual(self.value('ctx.created'), 1)

    def test_disable_does_not_overwrite_an_external_hud_opacity_change(self):
        self.frame()
        self.run_lua('image.opacity=.625')
        self.frame(False)
        self.assertEqual(self.value('image.opacity'), .625)
        self.assertEqual(self.value('#ctx.opacity_writes'), 1)

    def test_stop_touches_no_uobjects_and_next_instance_recovers_journal(self):
        self.frame()
        self.run_lua('oldpart=part;before_stop=ctx.touches;oldjournal=ctx.journal;'
                     'ctx.forbid=true;reticle:stop();reticle:step(pawn,weapon,true)')
        self.assertEqual(self.value('ctx.touches'), self.value('before_stop'))
        self.assertEqual(self.value('ctx.journal'), self.value('oldjournal'))
        self.assertEqual(self.value('image.opacity'), 0)
        self.run_lua('ctx.forbid=false;reticle=mod.new(uevr)')
        self.frame(False)
        self.assertFalse(self.value('oldpart.valid'))
        self.assertEqual(self.value('image.opacity'), .375)
        self.assertEqual(self.value('ctx.destroyed'), 1)
        self.assertEqual(self.value('ctx.journal'), '')
        self.frame()
        self.assertEqual(self.value('ctx.created'), 2)
        self.assertTrue(self.value('part~=oldpart and part.bVisible'))
        self.assertEqual(self.value('image.opacity'), 0)

    def test_runtime_and_owner_gates_hide_restore_and_can_resume(self):
        changes = (
            ('ctx.runtime=false', 'ctx.runtime=true'),
            ('ctx.hmd=false', 'ctx.hmd=true'),
            ('ctx.controllers=false', 'ctx.controllers=true'),
            ('ctx.aim=false', 'ctx.aim=true'),
            ('ctx.menu=true', 'ctx.menu=false'),
            ('ctx.paused=true', 'ctx.paused=false'),
            ('menu.valid=true', 'menu.valid=false'),
            ('pawn.bPlayerFinishedLevelLoad=false', 'pawn.bPlayerFinishedLevelLoad=true'),
            ('ctx.dead=true', 'ctx.dead=false'),
            ('ctx.foreign_local=true', 'ctx.foreign_local=false'),
            ('handler.outer=foreign', 'handler.outer=pawn'),
            ('handler.EquippedWeapon=foreign', 'handler.EquippedWeapon=weapon'),
            ('weapon.outer=foreign', 'weapon.outer=pawn'),
            ('camera.valid=false', 'camera.valid=true'),
        )
        for reject, resume in changes:
            with self.subTest(reject=reject):
                self.setUp()
                self.frame()
                self.run_lua(reject)
                self.frame()
                self.assert_hidden()
                self.assertEqual(self.value('ctx.traces'), 1)
                self.assertFalse(self.value('reticle.stopped'))
                self.run_lua(resume)
                self.frame()
                self.assertTrue(self.value('part.bVisible'))
                self.assertEqual(self.value('ctx.traces'), 2)

    def test_foreign_or_similarly_named_hud_widgets_are_never_suppressed(self):
        for change in ('hud.PlayerOwner=foreign', "hud.name='OtherHUD Test.HUD'",
                       "root.name='OtherWidget Test.Root'", "cross.name='OtherCrosshair Test.Cross'",
                       "image.name='Image Test.Other.WidgetTree.Crosshair'", 'image.class=generic'):
            with self.subTest(change=change):
                self.setUp()
                self.run_lua(change)
                self.frame()
                self.assertFalse(self.value('reticle.stopped'), self.value('ctx.log'))
                self.assertFalse(self.value('part and part.bVisible or false'))
                self.assertEqual(self.value('image.opacity'), .375)
                self.assertEqual(self.value('#ctx.opacity_writes'), 0)

    def test_malformed_samples_and_hits_hide_without_reusing_old_destination(self):
        for change in ('ctx.sample.Rotation.W=0', 'ctx.sample.Translation.X=0/0',
                       'ctx.sample.Rotation=nil', 'ctx.time=-1',
                       'ctx.time=0/0', 'ctx.off_ray=true', 'ctx.bad_point=true',
                       'ctx.eye.X=0/0'):
            with self.subTest(change=change):
                self.setUp()
                self.frame()
                self.run_lua(change)
                self.frame()
                self.assert_hidden()
                self.assertEqual(self.value('ctx.placements'), 1)
                self.assertFalse(self.value('reticle.stopped'))

    def test_api_failures_cleanup_report_and_stop_retrying(self):
        changes = ("ctx.fail='dispatch_ray'", "ctx.fail='K2_GetComponentToWorld'",
                   "ctx.fail='LineTraceSingle'", "ctx.fail='BreakHitResult'",
                   "ctx.fail='GetCameraLocation'", "ctx.fail='K2_SetWorldLocation'",
                   'ctx.trace_result=42', 'ctx.missing_hit=true', 'ctx.blocking=false',
                   'ctx.missing_point=true', 'ctx.reject_opacity=true;image.opacity=.375')
        for change in changes:
            with self.subTest(change=change):
                self.setUp()
                self.frame()
                self.run_lua(change)
                self.frame()
                self.assert_hidden()
                self.assertTrue(self.value('reticle.stopped'))
                self.assertIn('[Boltgun reticle] Disabled:', self.value('ctx.log'))
                self.assertEqual(self.value('ctx.destroyed'), 1)
                self.assertEqual(self.value('ctx.journal'), '')
                self.run_lua('before_retry=ctx.touches')
                self.frame()
                self.assertEqual(self.value('ctx.touches'), self.value('before_retry'))

    def test_changed_owned_identity_is_not_moved_or_destroyed(self):
        for change in ("pawn.address='reused'", "part.name='ProceduralMeshComponent Test.Reused'",
                       "part.address='reused'", 'part.outer=foreign'):
            with self.subTest(change=change):
                self.setUp()
                self.frame()
                self.run_lua(change)
                self.frame()
                self.assertTrue(self.value('reticle.stopped'))
                self.assertEqual(self.value('ctx.traces'), 1)
                self.assertEqual(self.value('ctx.placements'), 1)
                self.assertEqual(self.value('ctx.destroyed'), 0)
                self.assertNotEqual(self.value('ctx.journal'), '')

    def test_malformed_recovery_journal_never_creates_or_destroys_components(self):
        for journal in ('garbage', 'v1\nengine\nowner',
                        'v1\nengine\npawn\nPawn Test.Player\npart\nProceduralMeshComponent Test.Part\n'
                        'image\nImage Test.Cross.WidgetTree.Crosshair\nnan'):
            with self.subTest(journal=journal):
                self.setUp()
                self.lua.globals().ctx.journal = journal
                self.frame()
                self.assertTrue(self.value('reticle.stopped'))
                self.assertEqual(self.value('ctx.created'), 0)
                self.assertEqual(self.value('ctx.destroyed'), 0)
                self.assertEqual(self.value('ctx.traces'), 0)

    def test_recovery_refuses_reused_component_address(self):
        self.frame()
        self.run_lua("reticle:stop();part.address='reused';reticle=mod.new(uevr)")
        self.frame(False)
        self.assertTrue(self.value('reticle.stopped'))
        self.assertEqual(self.value('ctx.destroyed'), 0)
        self.assertNotEqual(self.value('ctx.journal'), '')

    def test_destroyed_component_can_remain_in_uobject_array_until_gc(self):
        self.frame()
        self.run_lua('''part.K2_DestroyComponent=function(self,owner)
            touch('K2_DestroyComponent');assert(owner==pawn)
            assert(not self.bVisible and self.bHiddenInGame)
            self.unregistered=true;ctx.destroyed=ctx.destroyed+1
        end
        reticle:stop();reticle=mod.new(uevr)''')
        self.frame(False)
        self.assertFalse(self.value('reticle.stopped'), self.value('ctx.log'))
        self.assertTrue(self.value('part.valid and part.unregistered'))
        self.assertEqual(self.value('ctx.journal'), '')


# Only the Unreal/UEVR/fs boundary is faked. Reflection order deliberately differs
# from the engine's usual order, and the breaker accepts only the actual trace hit.
FIXTURE = r'''
ctx={touches=0,created=0,destroyed=0,traces=0,breaks=0,placements=0,journal='',journal_writes=0,
 status_file='',status_writes=0,logs={},imports=0,palette_path='',mesh_requests=0,widget_creates=0,material_creates=0,auto_render=true,render_ready=true,
 opacity_writes={},runtime=true,hmd=true,controllers=true,aim=true,ack=true,mesh_ack=true,
 hit=true,blocking=true,time=.01,eye={X=10,Y=20,Z=30},
 sample={Translation={X=10,Y=20,Z=30},Rotation={X=0,Y=0,Z=math.sqrt(.5),W=math.sqrt(.5)}}}
function touch(method)
 ctx.touches=ctx.touches+1
 assert(not ctx.forbid,'UObject access during reset: '..method)
 if ctx.fail==method then error('fake API failure: '..method) end
end
objects={}
function obj(name,address,outer)
 local o={name=name,address=address,outer=outer,valid=true,Visibility=0}
 function o:IsVisible()touch('IsVisible');return self.Visibility==0 or self.Visibility==3 or self.Visibility==4 end
 objects[name]=o
 function o:get_full_name()touch('get_full_name');return self.name end
 function o:get_address()touch('get_address');return self.address end
 function o:get_outer()touch('get_outer');return self.outer end
 function o:get_class()touch('get_class');return self.class or generic end
 function o:get_property(k)touch('get_property');return self[k] end
 return o
end
generic=obj('Class Test.Generic','generic')
function generic:find_property(k)touch('find_property');return ctx.missing_property~=k and {} or nil end
engine=obj('Engine Test.Engine','engine');pawn=obj('Pawn Test.Player','pawn');foreign=obj('Foreign Test.Other','foreign')
handler=obj('Handler Test.Handler','handler',pawn);weapon=obj('Weapon Test.Weapon','weapon',pawn)
pawn.WeaponHandlerComponent=handler;pawn.bPlayerFinishedLevelLoad=true;handler.EquippedWeapon=weapon
function pawn:IsDead()touch('IsDead');return ctx.dead==true end
function weapon:GetOwner()touch('GetOwner');return self.outer end
controller=obj('Controller Test.Controller','controller')
camera=obj('Camera Test.Camera','camera');controller.PlayerCameraManager=camera
function camera:GetCameraLocation()touch('GetCameraLocation');return ctx.eye end
hud=obj('Gameplay_HUD_C Test.HUD','hud');hud.PlayerOwner=controller;controller.MyHUD=hud
function controller:GetHUD()touch('GetHUD');return hud end
root=obj('Gameplay_HUD_UI_C Test.Root','root');hud['Player HUD Widget']=root
cross=obj('W_PlayerHUD_Crosshair_C Test.Cross','cross');root.W_PlayerHUD_Crosshair=cross
imageclass=obj('Class /Script/UMG.Image','imageclass');imageclass.find_property=generic.find_property
image=obj('Image Test.Cross.WidgetTree.Crosshair','image');image.class=imageclass;image.opacity=.375
other_image=obj('Image Test.Cross.WidgetTree.Other','other_image');other_image.opacity=.8
cross.Crosshair=image
function image:GetRenderOpacity()touch('GetRenderOpacity');return self.opacity end
function image:SetRenderOpacity(v)
 touch('SetRenderOpacity');ctx.opacity_writes[#ctx.opacity_writes+1]=v
 if not ctx.reject_opacity or v~=0 then self.opacity=v end
end
function copy_struct(v)
 if type(v)~='table' or v.get_address then return v end
 local out={};for k,n in pairs(v)do out[k]=copy_struct(n)end;return out
end
glyph=obj('Texture2D /Game/Test.Crosshairs_Boltgun','glyph')
dlc_glyph=obj('Texture2D /Game/Test.Crosshairs_MultiMelta','dlcglyph')
image.Brush={ResourceObject=glyph,ImageSize={X=32,Y=32},DrawAs=1}
dlc_brush={ResourceObject=dlc_glyph,ImageSize={X=64,Y=64},DrawAs=1}
image.ColorAndOpacity={R=1,G=1,B=1,A=.65}
image.RenderTransform={Translation={X=0,Y=0},Scale={X=1,Y=1},Shear={X=0,Y=0},Angle=0}
image.RenderTransformPivot={X=.5,Y=.5}
widgetclass=obj('Class /Script/UMG.WidgetComponent','widgetclass')
widgetclass.find_property=generic.find_property
crossclass=obj('WidgetBlueprintGeneratedClass /Game/Blueprints/UI/Gameplay_HUD/W_PlayerHUD_Crosshair.W_PlayerHUD_Crosshair_C','crossclass')
cross.class=crossclass
crossclass.find_property=generic.find_property
alpha_material=obj('MaterialInstanceConstant /Engine/EngineMaterials/Widget3DPassThrough_Translucent.Widget3DPassThrough_Translucent','alpha')
alpha_parent=obj('Material /Engine/EngineMaterials/Widget3DPassThrough.Widget3DPassThrough','alpha_parent')
alpha_parent.MaterialDomain=0;alpha_parent.ShadingModels={ShadingModelField=1};alpha_parent.BlendMode=2
alpha_parent.bDisableDepthTest=false
overrides={bOverride_BlendMode=true,BlendMode=2,bOverride_ShadingModel=false,ShadingModel=0,
 bOverride_TwoSided=true,TwoSided=true}
alpha_material.Parent=alpha_parent;alpha_material.BasePropertyOverrides=overrides
factory=obj('Class /Script/UMG.WidgetBlueprintLibrary','factory')
function factory:get_class_default_object()return self end
function factory:Create(owner,cls,pc)
 touch('Create');assert(owner==pawn and cls==crossclass and pc==controller)
 ctx.widget_creates=ctx.widget_creates+1
 local widget=obj('W_PlayerHUD_Crosshair_C Test.WorldCross','worldwidget'..ctx.widget_creates);widget.class=crossclass
 world_image=obj('Image Test.WorldCross.WidgetTree.Crosshair','worldimage');world_image.class=imageclass
 world_image.Brush={};widget.Crosshair=world_image
 function world_image:SetVisibility(v)touch('SetGlyphVisibility');self.Visibility=v end
 function world_image:SetBrush(v)touch('SetBrush');if not ctx.reject_brush then self.Brush=copy_struct(v) end end
 function world_image:SetColorAndOpacity(v)touch('SetColorAndOpacity');self.ColorAndOpacity=copy_struct(v) end
 function world_image:SetRenderOpacity(v)touch('SetWorldOpacity');self.opacity=v end
 function world_image:GetRenderOpacity()return self.opacity end
 function world_image:SetRenderTransform(v)touch('SetRenderTransform');self.RenderTransform=copy_struct(v) end
 function world_image:SetRenderTransformPivot(v)touch('SetRenderTransformPivot');self.RenderTransformPivot=copy_struct(v) end
 return widget
end
menu=obj('Menu Test.Menu','menu');menu.valid=false;hud.CurrentMenu=menu
function menu:IsInViewport()touch('IsInViewport');return true end
function menu:IsVisible()touch('IsVisible');return true end
partclass=obj('Class /Script/ProceduralMeshComponent.ProceduralMeshComponent','partclass')
partclass.find_property=generic.find_property
unlit=obj('Material /Engine/EngineDebugMaterials/VertexColorMaterial.VertexColorMaterial','unlit')
unlit.ShadingModel=0;unlit.MaterialDomain=0;unlit.BlendMode=0
pickup=obj('MaterialInstanceConstant /Game/Art/Pickups/Powerups/Materials/MI_Pickups_Boltgun.MI_Pickups_Boltgun','pickup')
texture=obj('Texture2D Test.WhitePalette','texture')
strings=obj('Class /Script/Engine.KismetStringLibrary','strings')
function strings:find_function(name)return name=='Conv_StringToName' and {} end
function strings:get_class_default_object()return self end
function strings:Conv_StringToName(name)return name end
rendering=obj('Class /Script/Engine.KismetRenderingLibrary','rendering')
function rendering:find_function(name)return name=='ImportFileAsTexture2D' and {} end
function rendering:get_class_default_object()return self end
function rendering:ImportFileAsTexture2D(owner,path)
 touch('ImportFileAsTexture2D');assert(owner==pawn and path==ctx.palette_path)
 ctx.imports=ctx.imports+1;return texture
end
target=obj('TextureRenderTarget2D Test.Glyph','target')
function newpart()
 local o=obj('ProceduralMeshComponent Test.Part','part'..ctx.created,pawn);o.class=partclass
 o.bVisible=false;o.bHiddenInGame=true;o.sections=0;o.TranslucentMaterial=alpha_material;o.BlendMode=1
 o.transform={Scale3D={X=1,Y=1,Z=1}};o.visibility_changes=0
 function o:set_property(k,v)touch('set_property');assert(k=='BlendMode');self[k]=v end
 function o:SetTickWhenOffscreen(v)self.offscreen=v end
 function o:SetWidgetSpace(v)touch('SetWidgetSpace');self.space=v end
 function o:GetWidgetSpace()return self.space end
 function o:SetDrawAtDesiredSize(v)self.desired=v end
 function o:SetDrawSize(v)touch('SetDrawSize');if not ctx.reject_draw_size then self.size=v end end
 function o:GetDrawSize()return self.size or {X=0,Y=0} end
 function o:SetPivot(v)touch('SetPivot');self.pivot=v end
 function o:GetPivot()return self.pivot end
 function o:SetWindowFocusable(v)touch('SetWindowFocusable');self.focusable=v end
 function o:GetWindowFocusable()return self.focusable end
 function o:SetBackgroundColor(v)touch('SetBackgroundColor');self.background=v end
 function o:SetWidget(v)touch('SetWidget');if not ctx.reject_widget then self.widget=v end end
 function o:GetUserWidgetObject()return self.widget end
 function o:RequestRedraw()touch('RequestRedraw');self.bRedrawRequested=not ctx.auto_render end
 function o:GetRenderTarget()
  touch('GetRenderTarget');if not ctx.render_ready then return nil end
  target.SizeX=self.size.X;target.SizeY=self.size.Y;return target
 end
 function o:GetMaterialInstance()touch('GetMaterialInstance');return self.dmi end
 function o:SetHiddenInGame(v,propagate)
  touch('SetHiddenInGame');assert(propagate==false)
  if self.bHiddenInGame~=v then self.visibility_changes=self.visibility_changes+1;self.bHiddenInGame=v end
 end
 function o:SetVisibility(v,propagate)
  touch('SetVisibility');assert(propagate==false)
  if self.bVisible~=v then self.visibility_changes=self.visibility_changes+1;self.bVisible=v end
 end
 function o:SetCollisionEnabled(v)touch('SetCollisionEnabled');ctx.collision=ctx.reject_collision and 2 or v end
 function o:GetCollisionEnabled()touch('GetCollisionEnabled');return ctx.collision end
 function o:SetGenerateOverlapEvents(v)touch('SetGenerateOverlapEvents');ctx.overlaps=v end
 function o:SetMobility(v)touch('SetMobility');ctx.mobility=v end
 function o:SetCastShadow(v)touch('SetCastShadow');ctx.shadow=v end
 function o:SetOwnerNoSee(v)touch('SetOwnerNoSee');ctx.owner_no_see=v end
 function o:SetOnlyOwnerSee(v)touch('SetOnlyOwnerSee');ctx.only_owner=v end
 function o:GetNumSections()touch('GetNumSections');return self.sections end
 function o:GetMaterial(index)touch('GetMaterial');assert(index==0);return ctx.get_material_returns_instance and self.dmi or self.material end
 function o:SetMaterial(index,material)
  touch('SetMaterial');assert(index==0);ctx.material_creates=ctx.material_creates+1
  if not ctx.reject_material then self.material=material end
  self.dmi=obj('MaterialInstanceDynamic Test.Widget','widgetdmi',self)
  self.dmi.Parent=ctx.wrong_mid_parent and pickup or self.material
  function self.dmi:K2_GetTextureParameterValue(key)
   touch('K2_GetTextureParameterValue');assert(key=='SlateUI')
   return not ctx.wrong_slate and ctx.render_ready and target or nil
  end
 end
 function o:CreateDynamicMaterialInstance(index,source,name)
  touch('CreateDynamicMaterialInstance');assert(index==0 and source==pickup and name=='BoltgunReticleWhite')
  local dmi=obj('MaterialInstanceDynamic Test.ReticleWhite','dmi',self)
  function dmi:SetTextureParameterValue(key,value)
   touch('SetTextureParameterValue');assert(key=='BC');if not ctx.reject_texture then self.texture=value end
  end
  function dmi:K2_GetTextureParameterValue(key)touch('K2_GetTextureParameterValue');assert(key=='BC');return self.texture end
  self.material=dmi;return dmi
 end
 function o:K2_GetComponentToWorld()touch('K2_GetComponentToWorld');return self.transform end
 function o:K2_SetWorldLocation(v,sweep,hit,teleport)
  touch('K2_SetWorldLocation');assert(not sweep and type(hit)=='table' and teleport)
  ctx.location=v;ctx.placements=ctx.placements+1
  if not ctx.noop_location then self.transform.Translation={X=v.X,Y=v.Y,Z=v.Z} end
 end
 function o:K2_SetWorldRotation(v,sweep,hit,teleport)
  touch('K2_SetWorldRotation');assert(not sweep and type(hit)=='table' and teleport);ctx.rotation=v
  if not ctx.noop_rotation then
   assert(v.Roll==0)
   local p,y=math.rad(v.Pitch)/2,math.rad(v.Yaw)/2
   self.transform.Rotation={X=math.sin(p)*math.sin(y),Y=-math.sin(p)*math.cos(y),
    Z=math.cos(p)*math.sin(y),W=math.cos(p)*math.cos(y)}
  end
 end
 function o:SetWorldScale3D(v)
  touch('SetWorldScale3D');ctx.scale=v
  if not ctx.noop_scale then self.transform.Scale3D={X=v.X,Y=v.Y,Z=v.Z} end
 end
 function o:K2_DestroyComponent(owner)
  touch('K2_DestroyComponent');assert(owner==pawn and self.outer==pawn)
  assert(not self.bVisible and self.bHiddenInGame);self.widget=nil;self.valid=false;ctx.destroyed=ctx.destroyed+1
 end
 return o
end
function draw_widget()
 assert(part.bVisible and not part.bHiddenInGame and part.offscreen and ctx.render_ready)
 local scale=part.transform.Scale3D
 assert(ctx.collision==0 and scale.X==0 and scale.Y==0 and scale.Z==0)
 part.bRedrawRequested=false
end
function descriptor(names,outputs,call)
 local fields={}
 for i,n in ipairs(names) do
  fields[i]={get_fname=function()return{to_string=function()return n end}end,
   get_next=function()return fields[i+1]end}
 end
 return setmetatable({get_child_properties=function()touch('get_child_properties');return fields[1]end,
  find_property=function(_,n)return {is_param=function()return true end,
   is_return_param=function()return false end,is_out_param=function()return outputs[n]==true end}end},
  {__call=function(_,self,...)
   local args={...};local values={};for i,n in ipairs(names)do values[n]=args[i]end
   return call(self,values)
  end})
end
gs=obj('GameplayStatics Test.Default','gs');system=obj('KismetSystemLibrary Test.Default','system')
function gs:IsGamePaused(pc)touch('IsGamePaused');assert(pc==controller);return ctx.paused==true end
trace=descriptor({'End','WorldContextObject','TraceChannel','Start','ActorsToIgnore','OutHit',
 'TraceColor','bTraceComplex','DrawDebugType','bIgnoreSelf','DrawTime','TraceHitColor'}, {OutHit=true},function(self,v)
 touch('LineTraceSingle');ctx.traces=ctx.traces+1
 assert(self==system and v.WorldContextObject==pawn and v.ActorsToIgnore[1]==pawn and v.ActorsToIgnore[2]==weapon)
 assert(#v.ActorsToIgnore==2 and v.TraceChannel==0 and v.bTraceComplex==false and v.bIgnoreSelf==true)
 assert(v.DrawDebugType==0 and v.DrawTime==0 and v.TraceColor.A==0 and v.TraceHitColor.A==0)
 assert(not part.bVisible and part.bHiddenInGame,'trace exposed unplaced marker')
 ctx.start=v.Start;ctx.finish=v.End
 if ctx.trace_result then return ctx.trace_result end
 if not ctx.hit then return false end
 ctx.real_hit={};if not ctx.missing_hit then v.OutHit.result=ctx.real_hit end;return true
end)
breaker=descriptor({'Time','ImpactPoint','Hit','bInitialOverlap','bBlockingHit','Location','HitActor','HitComponent'},
 {Time=true,ImpactPoint=true,bInitialOverlap=true,bBlockingHit=true,Location=true,HitActor=true,HitComponent=true},function(self,v)
 touch('BreakHitResult');ctx.breaks=ctx.breaks+1;assert(self==gs and v.Hit==ctx.real_hit)
 v.Time.result=ctx.time;v.bInitialOverlap.result=ctx.initial==true;v.bBlockingHit.result=ctx.blocking
 if not ctx.missing_point then
  -- The fixture's sampled quaternion points along +Y. Expected coordinates in
  -- tests are literals, independent of the production ray/marker helpers.
  v.ImpactPoint.result={X=ctx.bad_point and 0/0 or (ctx.off_ray and 50 or ctx.start.X),
   Y=ctx.start.Y+(ctx.hit_y or 100),Z=ctx.start.Z}
 end
end)
gs.class=obj('Class Test.GameplayStatics','gsclass')
function gs.class:find_function(k)touch('find_function');if k=='BreakHitResult' then return breaker end end
system.class=obj('Class Test.KismetSystemLibrary','sysclass')
function system.class:find_function(k)touch('find_function');if k=='LineTraceSingle' then return trace end end
function library(name,o)
 local c=obj('Class /Script/Engine.'..name,name)
 function c:get_class_default_object()touch('get_class_default_object');return o end
end
library('GameplayStatics',gs);library('KismetSystemLibrary',system)
for _,name in ipairs({'Vector','Vector2D','Rotator'}) do
 local d=obj('ScriptStruct /Script/CoreUObject.'..name,name)
 function d:as_struct()touch('as_struct');return self end
end
StructObject={new=function(desc)
 touch('StructObject.new');assert(desc.valid)
 return {set_property=function(self,k,v)self[k]=v end}
end}
fs={read=function(path)
 if path=='hands3d.texture_path' then return ctx.palette_path end
 if path=='bolter3d.reticle.status' then return ctx.status_file end
 assert(path=='bolter3d.reticle.owned');return ctx.journal end,
 write=function(path,text)
 if path=='bolter3d.reticle.status' then
  assert(not ctx.status_fail,'diagnostic disk failure')
  ctx.status_writes=ctx.status_writes+1;ctx.status_file=text;return
 end
 assert(path=='bolter3d.reticle.owned');ctx.journal_writes=ctx.journal_writes+1;ctx.journal=text end}
uevr={api={get_engine=function()touch('get_engine');return engine end,
 get_local_pawn=function(_,index)touch('get_local_pawn');assert(index==0);return ctx.foreign_local and foreign or pawn end,
 get_player_controller=function(_,index)touch('get_player_controller');assert(index==0);return controller end,
 find_uobject=function(_,name)
  touch('find_uobject');if name==unlit.name and not ctx.unlit_available then return nil end
  if name==pickup.name and not ctx.pickup_available then return nil end
  return objects[name] end,
 add_component_by_class=function(_,owner,class,deferred)
  touch('add_component_by_class');assert(owner==pawn and (class==partclass or class==widgetclass) and deferred==false)
  ctx.created=ctx.created+1;part=newpart();part.class=class;return part
 end},types={UObjectHook={exists=function(o)touch('exists');return o and o.valid==true end}},
 params={vr={is_runtime_ready=function()return ctx.runtime end,is_hmd_active=function()return ctx.hmd end,
 is_using_controllers=function()return ctx.controllers end,is_aim_allowed=function()return ctx.aim end},
 functions={is_drawing_ui=function()return ctx.menu==true end,
 log_info=function(msg)ctx.log=msg;ctx.logs[#ctx.logs+1]=msg end,
 dispatch_custom_event=function(event,payload)
  assert(event=='boltgun.reticle.v1')
  local command,p,w,c=payload:match('^([^|]+)|([^|]+)|([^|]+)|([^|]+)$')
  assert(p==pawn.address and w==weapon.address and c==part.address)
  touch('dispatch_'..command)
  assert(part.bHiddenInGame and not part.bVisible,'native request reused stale visible ack')
  if command=='mesh' then ctx.mesh_requests=ctx.mesh_requests+1;if ctx.mesh_ack then part.sections=1 end
  elseif command=='ray' then
   if ctx.ack then
    -- Native sampling moves the component to a fresh transform. World setters
    -- then mutate this copy, never the next frame's native sample fixture.
    part.transform={}
    for key,values in pairs(ctx.sample) do
     local copy={};for k,v in pairs(values)do copy[k]=v end;part.transform[key]=copy
    end
    part.transform.Scale3D=part.transform.Scale3D or {X=1,Y=1,Z=1}
    part.bVisible=true
   end
  else error('unexpected reticle command') end
 end}}}
'''


if __name__ == '__main__':
    unittest.main()
