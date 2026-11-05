import importlib.util
from pathlib import Path
import math
import unittest

ROOT = Path(__file__).resolve().parent


class HandPreparationTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('prepare_hands', ROOT / 'prepare_hands.py')
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)

    def test_fingers_close_over_grip_and_keep_unit_normals(self):
        p, n = self.mod.pose((0.0, .29, 0.0), (0.0, 0.0, 1.0))
        self.assertLess(p[1], 0, 'Fingertips must close behind the grip center')
        self.assertEqual(p[2], 0, 'Grip cylinder must run along the weapon Z axis')
        self.assertLess(math.hypot(p[0], p[1]), 4)
        self.assertLess(p[0], 4, 'No extended fingers projecting past the trigger')
        self.assertAlmostEqual(sum(v*v for v in n), 1.0)
        wrist, _ = self.mod.pose((0.0, .06, 0.0), (0.0, 0.0, 1.0))
        self.assertLess(wrist[0], -10)

    def test_recolor_keeps_dark_glove_and_blue_armor_distinct(self):
        armor = self.mod.recolor((170, 180, 190))
        glove = self.mod.recolor((125, 72, 40))
        trim = self.mod.recolor((190, 151, 60))
        self.assertGreater(armor[2], armor[0]*2)
        self.assertLess(max(glove), 55)
        self.assertGreater(trim[0], trim[2]*2)
        cuff = self.mod.recolor((125, 72, 40), cuff=True)
        self.assertGreater(cuff[2], cuff[0]*3)

    def test_checked_in_asset_has_finite_geometry_and_original_provenance(self):
        import struct
        asset = ROOT.parents[2] / 'assets/hands'
        raw = (asset / 'right_grip.bgmesh').read_bytes()
        magic, version, vertices, indices = struct.unpack_from('<8sIII', raw)
        self.assertEqual((magic, version, vertices), (b'BGCHAIN1', 1, 12776))
        self.assertEqual(indices, 44778*2)
        self.assertEqual(len(raw), 20 + vertices*32 + indices*4)
        for values in struct.iter_unpack('<8f', raw[20:20+vertices*32]):
            self.assertTrue(all(math.isfinite(v) for v in values))
            self.assertAlmostEqual(sum(v*v for v in values[3:6]), 1, places=4)
        credits = (asset / 'CREDITS.txt').read_text()
        self.assertIn('CC0', credits)
        self.assertIn('https://grab3d.com/models/weapons/gauntlet/', credits)


if __name__ == '__main__':
    unittest.main()
