"""Fail-closed decisions for future physical chainsword hit integration."""
import unittest
from pathlib import Path

from lupa.lua54 import LuaRuntime


SOURCE = Path(__file__).resolve().parents[1] / 'src/lua/boltgun_melee_policy.lua'


class MeleePolicyTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        module = self.lua.execute(SOURCE.read_text(encoding='utf-8'))
        self.policy = module.new()

    def step(self, time, *, target=None, **changes):
        frame = dict(now=time, dt=.02, owner='pawn-A', tracked=True, focused=True,
                     foreground=True, held=True, blade_owned=True, ui=False,
                     sweep_valid=True, linear_cm_s=160, angular_deg_s=0)
        frame.update(changes)
        contact = (dict(target='enemy-A', enemy=True, verified=True,
                        blocking=True) if target is True else target)
        if isinstance(contact, dict):
            contact = self.lua.table_from(contact)
        return self.policy.step(self.policy, self.lua.table_from(frame), contact)

    def test_startup_needs_two_moving_frames_and_confirmed_contact(self):
        self.assertIsNone(self.step(1, target=True))
        self.assertIsNone(self.step(1.02))
        hit = self.step(1.04, target=True)
        self.assertEqual(hit.target, 'enemy-A')
        self.assertTrue(hit.impact)
        self.assertIsNone(self.step(1.06, target=True))

    def test_resting_blade_never_cuts_even_with_contact(self):
        for i in range(20):
            self.assertIsNone(self.step(2+i*.02, target=True, linear_cm_s=0, angular_deg_s=0))

    def test_moving_without_l2_does_not_arm_or_buffer_hits(self):
        for i in range(4):
            self.assertIsNone(self.step(3+i*.02, target=True, held=False))
        self.assertIsNone(self.step(3.08, target=True))
        self.assertIsNone(self.step(3.10))
        self.assertIsNotNone(self.step(3.12, target=True))

    def test_loss_of_focus_tracking_owner_or_sweep_resets_motion(self):
        for field, value in [('tracked', False), ('focused', False),
                             ('foreground', False), ('ui', True),
                             ('blade_owned', False), ('sweep_valid', False),
                             ('owner', 'pawn-B')]:
            with self.subTest(field=field):
                self.policy.reset(self.policy)
                self.step(5)
                self.assertIsNone(self.step(5.02, target=True, **{field: value}))
                self.assertIsNone(self.step(5.04, target=True))

    def test_invalid_dt_motion_and_time_regression_fail_closed(self):
        self.step(7)
        for frame in [dict(dt=.0), dict(dt=.5), dict(linear_cm_s=2000),
                      dict(angular_deg_s=3000), dict(now=6.0),
                      dict(linear_cm_s=float('nan'))]:
            self.policy.reset(self.policy)
            self.step(7)
            self.assertIsNone(self.step(7.02, target=True, **frame))
            self.assertIsNone(self.step(7.04, target=True))

    def test_contacts_require_verified_enemy_block_and_identity(self):
        for change in [dict(verified=False), dict(enemy=False),
                       dict(blocking=False), dict(target='pawn-A'),
                       dict(target='')]:
            with self.subTest(change=change):
                self.policy.reset(self.policy)
                self.step(9)
                base = dict(target='enemy-A', enemy=True, verified=True, blocking=True)
                base.update(change)
                self.assertIsNone(self.step(9.02, target=base))

    def test_target_dedup_and_cooldown_per_target(self):
        self.step(11)
        self.assertIsNotNone(self.step(11.02, target=True))
        self.assertIsNone(self.step(11.04, target=True))
        self.assertIsNotNone(self.step(11.06, target=dict(target='enemy-B', enemy=True,
                                                        verified=True, blocking=True)))
        self.assertIsNone(self.step(11.08, target=True))
        self.assertIsNone(self.step(11.40, target=True, linear_cm_s=0, angular_deg_s=0))
        self.assertIsNone(self.step(11.42, target=True))
        self.assertIsNotNone(self.step(11.44, target=True))

    def test_release_and_session_change_clear_prior_targets(self):
        self.step(13)
        self.assertIsNotNone(self.step(13.02, target=True))
        self.assertIsNone(self.step(13.04, target=True, held=False))
        self.assertIsNone(self.step(13.06, target=True))
        self.assertIsNone(self.step(13.08, target=True))  # L2 toggling cannot bypass cooldown.
        self.assertIsNone(self.step(13.44, target=True))
        self.assertIsNotNone(self.step(13.46, target=True))


if __name__ == '__main__':
    unittest.main()
