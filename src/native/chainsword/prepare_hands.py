"""Adapt the pinned CC0 Grab3D gauntlet to a fixed VR weapon grip.

python src/native/chainsword/prepare_hands.py path/to/gauntlet.glb
Requires Pillow for the color texture. No game assets are input or output.
"""
import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import struct

from prepare import accessor, encode_mesh

SOURCE_SHA256 = '4234274A6A7B2C62EB42C384DAB8439E2381A82D5132FDFE64CF3C2041313D51'


def pose(p, n):
    x, y, z = p
    nx, ny, nz = n
    # Close the fingers toward the palm. A cylindrical map rotates the normals
    # with the surface and preserves the source's separate armor plates.
    base = .185 if x < -.046 else .215
    radius = .040 if x < -.046 else .045
    if y > base:
        angle = (y-base)/radius
        sn, cs = math.sin(angle), math.cos(angle)
        y, z = base+(radius+z)*sn, -radius+(radius+z)*cs
        ny, nz = ny*cs+nz*sn, -ny*sn+nz*cs
    # UE centimeters. The curl's cylinder center is (source y=.215,z=-.045).
    # Rotate the right hand -90 degrees around its forward X axis: the grip
    # opening runs along weapon Z, thumb up and dorsal armor to the outside.
    # Native Y mirroring produces the matching left-hand +90-degree pose.
    # Swapping source X/Y mirrors the basis, so reverse triangle winding.
    return ((y-.215)*85, (z+.045)*85, -x*85), (ny, nz, -nx)


def recolor(pixel, cuff=False):
    r, g, b = pixel[:3]
    light = (r+g+b)/(3*185)
    if b > r*.96 and b > g*.95:  # steel plates -> cobalt-blue armor
        return tuple(min(255, round(c*light)) for c in (24, 66, 153))
    if r > b*1.5 and g > b*1.35 and g > r*.68:  # brass trim
        return (r, g, b)
    if cuff:
        return tuple(min(255, round(c*light)) for c in (28, 68, 153))
    # Leather -> dark charcoal glove, retain the baked folds.
    return tuple(max(0, min(255, round(c*light))) for c in (25, 29, 37))


def main():
    from PIL import Image, ImageDraw
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    raw = args.source.read_bytes()
    if hashlib.sha256(raw).hexdigest().upper() != SOURCE_SHA256:
        raise ValueError('Source differs from the reviewed CC0 gauntlet')
    if raw[:4] != b'glTF':
        raise ValueError('Expected binary glTF')
    length = struct.unpack_from('<I', raw, 12)[0]
    data, binary = json.loads(raw[20:20+length]), raw[28+length:]
    primitive = data['meshes'][0]['primitives'][0]
    positions = accessor(data, binary, primitive['attributes']['POSITION'])
    normals = accessor(data, binary, primitive['attributes']['NORMAL'])
    posed = [pose(p, n) for p, n in zip(positions, normals)]
    uv = accessor(data, binary, primitive['attributes']['TEXCOORD_0'])
    ids = [i[0] for i in accessor(data, binary, primitive['indices'])]
    front = [k for i in range(0, len(ids), 3) for k in (ids[i], ids[i+2], ids[i+1])]
    # Source is double-sided. Preserve that independently of the cooked shader.
    indices = front+ids
    out = Path(__file__).resolve().parents[3]/'assets/hands'
    out.mkdir(exist_ok=True)
    (out/'right_grip.bgmesh').write_bytes(encode_mesh(
        [p for p, _ in posed], [n for _, n in posed], uv, indices))
    image = data['images'][1]
    view = data['bufferViews'][image['bufferView']]
    start = view.get('byteOffset', 0)
    texture = Image.open(io.BytesIO(binary[start:start+view['byteLength']])).convert('RGB')
    texture = texture.resize((1024, 1024), Image.Resampling.LANCZOS)
    # Repaint the forearm cuff blue while retaining the glove's dark leather.
    cuff = Image.new('1', texture.size)
    draw = ImageDraw.Draw(cuff)
    for i in range(0, len(ids), 3):
        face = ids[i:i+3]
        if sum(positions[k][1] for k in face)/3 < .095:
            draw.polygon([(round(uv[k][0]*1023), round(uv[k][1]*1023)) for k in face], fill=1)
    texture.putdata([recolor(c, bool(mask)) for c, mask in zip(texture.getdata(), cuff.getdata())])
    texture.save(out/'hands_color.png')
    print('Prepared CC0 hands:', len(positions), 'vertices;', len(indices)//3, 'double-sided triangles')


if __name__ == '__main__':
    main()
