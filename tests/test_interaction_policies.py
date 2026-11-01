"""Offline contracts for proposed contact melee and menu interactions.

These modules are intentionally disconnected from live UEVR callbacks until
an authenticated, focus-aware XR sample producer is available.
"""
import unittest
from pathlib import Path

from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1] / 'src/lua'


def load(name):
    lua = LuaRuntime(unpack_returned_tuples=True)
    return lua, lua.execute((ROOT / name).read_text(encoding='utf-8'))


class TrackingPolicyTests(unittest.TestCase):
    def setUp(self):
        self.lua, module = load('boltgun_tracking_policy.lua')
        self.gate = module.new()

    def sample(self, **changes):
        sample = dict(source='openxr', trusted=True, fresh=True,
                      focused=True, foreground=True, process_nonce='process-A',
                      epoch=2, sequence=1, clock=10.0, owner='owned-blade',
                      hands=dict(left=dict(tracked=True, active=True)))
        sample.update(changes)
        return self.lua.table_from(sample, recursive=True)

    def allow(self, sample, now=10.01):
        return self.gate.allow(self.gate, sample, now, 'owned-blade', 'left')[0]

    def test_requires_second_distinct_recent_sample(self):
        self.assertFalse(self.allow(self.sample()))
        self.assertTrue(self.allow(self.sample(sequence=2, clock=10.02), 10.03))
        self.assertFalse(self.allow(self.sample(sequence=2, clock=10.02), 10.04))

    def test_rejects_untrusted_stale_unfocused_or_foreign_owner(self):
        for field, value in [('trusted', False), ('focused', False),
                             ('foreground', False), ('fresh', False),
                             ('owner', 'foreign'), ('source', 'uevr')]:
            with self.subTest(field=field):
                self.gate.reset(self.gate)
                self.assertFalse(self.allow(self.sample(**{field: value})))
        self.assertFalse(self.allow(self.sample(), 10.10))
        self.gate.reset(self.gate)
        self.assertFalse(self.allow(self.sample(hands=dict(left=dict(tracked=False, active=True)))))

    def test_loss_and_epoch_transition_require_rearming(self):
        self.assertFalse(self.allow(self.sample()))
        self.assertTrue(self.allow(self.sample(sequence=2, clock=10.02), 10.03))
        self.assertFalse(self.allow(self.sample(sequence=3, clock=10.04, focused=False), 10.05))
        self.assertFalse(self.allow(self.sample(sequence=4, clock=10.06), 10.07))
        self.assertTrue(self.allow(self.sample(sequence=5, clock=10.08), 10.09))
        self.assertFalse(self.allow(self.sample(epoch=3, sequence=1, clock=10.10), 10.11))


class MenuPolicyTests(unittest.TestCase):
    def setUp(self):
        self.lua, module = load('boltgun_menu_policy.lua')
        self.policy = module.new()

    def step(self, rt, buttons=64+128, **context):
        c = dict(mode='frontend', source_owned=True, tracking_ok=True,
                 focused=True, foreground=True, dt=.016)
        c.update(context)
        return self.policy.step(self.policy, self.lua.table_from(c), rt, buttons)

    def test_requires_confirmed_frontend_and_release_to_arm(self):
        self.assertEqual(self.step(240).buttons, 192)
        self.assertFalse(self.step(240).accepted)
        self.assertEqual(self.step(0).rt, 0)
        event = self.step(200)
        self.assertTrue(event.accepted)
        self.assertEqual(event.rt, 0)
        self.assertEqual(event.buttons, 192 + 4096)

    def test_never_consumes_foreign_source_or_unverified_gameplay(self):
        self.assertEqual(self.step(210, mode='gameplay').rt, 210)
        self.assertEqual(self.step(210, source_owned=False).rt, 210)
        self.assertEqual(self.step(210, tracking_ok=False).buttons, 192)

    def test_drains_menu_trigger_across_transition_and_focus_loss(self):
        self.step(0)
        self.step(220)
        self.assertEqual(self.step(220, mode='gameplay').rt, 0)
        self.assertEqual(self.step(220, focused=False).rt, 0)
        self.assertEqual(self.step(0, mode='gameplay').rt, 0)
        self.assertEqual(self.step(220, mode='gameplay').rt, 220)


class GeometryTests(unittest.TestCase):
    def setUp(self):
        self.lua, self.ray = load('boltgun_menu_ray.lua')
        self.sweep = self.lua.execute((ROOT / 'boltgun_blade_sweep.lua').read_text(encoding='utf-8'))

    def vec(self, x=0, y=0, z=0):
        return self.lua.table_from(dict(x=x, y=y, z=z))

    def rot(self):
        return self.lua.table_from(dict(x=0, y=0, z=0, w=1))

    def pose(self, x=0, z=0):
        return self.lua.table_from(dict(position=self.vec(x=x, z=z), rotation=self.rot()))

    def test_menu_ray_uses_normalized_quad_and_rejects_behind(self):
        panel = self.lua.table_from(dict(center=self.vec(z=-2), rotation=self.rot(),
                                         width=2, height=1))
        ray = self.lua.table_from(dict(position=self.vec(x=.5, y=.25),
                                       rotation=self.rot(), active=True, tracked=True))
        hit = self.ray.intersect(ray, panel)
        self.assertAlmostEqual(hit.x, .75)
        self.assertAlmostEqual(hit.y, .25)
        panel.center.z = 2
        self.assertIsNone(self.ray.intersect(ray, panel))
        panel.center.z = -2
        ray.tracked = False
        self.assertIsNone(self.ray.intersect(ray, panel))

    def test_sweep_is_bounded_and_rejects_discontinuous_motion(self):
        base, tip = self.vec(z=15), self.vec(z=90)
        segments, reason = self.sweep.generate(self.pose(), self.pose(x=3), base, tip, 3, .02)
        self.assertIsNone(reason)
        self.assertGreater(len(segments), 1)
        self.assertLessEqual(len(segments), 1200)
        rejected, reason = self.sweep.generate(self.pose(), self.pose(x=60), base, tip, 3, .02)
        self.assertIsNone(rejected)
        self.assertEqual(reason, 'discontinuity')
        rejected, reason = self.sweep.generate(self.pose(), self.pose(x=3), base, tip, 3, .0001)
        self.assertIsNone(rejected)
        self.assertEqual(reason, 'discontinuity')


if __name__ == '__main__':
    unittest.main()
