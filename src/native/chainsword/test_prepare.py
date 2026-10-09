import importlib.util
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parent

class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue((ROOT / 'prepare.py').exists(), 'Chainsword converter is missing')
        spec = importlib.util.spec_from_file_location('chainsword_prepare', ROOT / 'prepare.py')
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)

    def test_grip_and_length(self):
        result = self.mod.convert_positions([(340, 0, -5), (-165.763671875, 0, -5),
                                              (434.9090881347656, 0, -5)])
        self.assertEqual(result[0], (0.0, 0.0, 0.0))
        self.assertAlmostEqual(result[1][2] - result[2][2], 95.0, places=4)

    def test_binary_roundtrip_and_invalid_indices(self):
        vertices=[(0.,0.,0.), (1.,0.,0.), (0.,1.,0.)]
        raw=self.mod.encode_mesh(vertices,[(0.,0.,1.)]*3,[(0.,0.)]*3,[0,1,2])
        self.assertEqual(struct.unpack_from('<8sIII',raw), (b'BGCHAIN1',1,3,3))
        self.assertEqual(len(raw),20+3*32+3*4)
        with self.assertRaises(ValueError):
            self.mod.encode_mesh(vertices,[(0.,0.,1.)]*3,[(0.,0.)]*3,[0,1,3])

    def test_nonfinite_geometry_is_rejected(self):
        with self.assertRaises(ValueError):
            self.mod.encode_mesh([(float('nan'),0.,0.)]*3,[(0.,0.,1.)]*3,[(0.,0.)]*3,[0,1,2])

if __name__=='__main__': unittest.main()
