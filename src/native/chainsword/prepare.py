"""Prepare Kaiser-E's licensed glTF for the UE4 procedural mesh bridge.

The source's transform stack expresses an absurd ~15 m sword; we deliberately
use the authored local axes and measured grip, then fit total length to 95 cm.
Runtime input is fixed-size little-endian POD, never Unreal serialized assets.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import struct

GRIP = (340.0, 0.0, -5.0)
SCALE = 95.0 / (434.9090881347656 + 165.763671875)

def convert_positions(positions):
    # UE X=blade front, Y=thickness, Z=blade length. Flip handedness.
    return [((z-GRIP[2])*SCALE, -(y-GRIP[1])*SCALE, (GRIP[0]-x)*SCALE)
            for x,y,z in positions]

def encode_mesh(positions, normals, uvs, indices):
    n=len(positions)
    if not 3<=n<=100000 or len(normals)!=n or len(uvs)!=n or not indices or len(indices)%3:
        raise ValueError('Invalid mesh counts')
    if any(i<0 or i>=n for i in indices): raise ValueError('Index outside mesh')
    output=bytearray(struct.pack('<8sIII',b'BGCHAIN1',1,n,len(indices)))
    for p,norm,uv in zip(positions,normals,uvs):
        values=(*p,*norm,*uv)
        if len(values)!=8 or not all(math.isfinite(x) for x in values):
            raise ValueError('Nonfinite or malformed vertex')
        output.extend(struct.pack('<8f',*values))
    output.extend(struct.pack('<'+'i'*len(indices),*indices))
    return bytes(output)

def accessor(data,binary,index):
    a=data['accessors'][index];v=data['bufferViews'][a['bufferView']]
    fmt={5126:'f',5125:'I',5123:'H'}[a['componentType']]
    size={'SCALAR':1,'VEC2':2,'VEC3':3}[a['type']]
    pack=struct.Struct('<'+fmt*size)
    offset=v.get('byteOffset',0)+a.get('byteOffset',0)
    stride=v.get('byteStride',pack.size)
    return [pack.unpack_from(binary,offset+i*stride) for i in range(a['count'])]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('source',type=Path)
    args=parser.parse_args()
    root=Path(__file__).resolve().parent;out=root.parents[2]/'assets/chainsword';out.mkdir(exist_ok=True)
    source=args.source;data=json.loads((source/'scene.gltf').read_text())
    binary=(source/'scene.bin').read_bytes()
    assert len(data['meshes'])==1 and len(data['meshes'][0]['primitives'])==1
    p=data['meshes'][0]['primitives'][0];assert p['mode']==4
    pos=accessor(data,binary,p['attributes']['POSITION'])
    normals=[(z,-y,-x) for x,y,z in accessor(data,binary,p['attributes']['NORMAL'])]
    uv=accessor(data,binary,p['attributes']['TEXCOORD_0'])
    ids=[i[0] for i in accessor(data,binary,p['indices'])]
    # Mirrored basis requires reversing each face winding.
    ids=[j for i in range(0,len(ids),3) for j in (ids[i],ids[i+2],ids[i+1])]
    source_triangles=len(ids)//3
    # glTF declares doubleSided=true; the reused cooked material cannot change
    # its static two-sided shader option. Supply both face windings instead.
    material=data['materials'][p['material']]
    if material.get('doubleSided'):
        ids+= [j for i in range(0,len(ids),3) for j in (ids[i],ids[i+2],ids[i+1])]
    payload=encode_mesh(convert_positions(pos),normals,uv,ids)
    (out/'chainsword.bgmesh').write_bytes(payload)
    from PIL import Image
    with Image.open(source/'textures/Material_96_baseColor.jpeg') as image:
        image.convert('RGB').resize((2048,2048),Image.Resampling.LANCZOS).save(out/'chainsword_color.png')
    # Keep attribution with both project and installed asset.
    (out/'CREDITS.txt').write_text((source/'license.txt').read_text()+'\nMod adaptations: 95 cm length, grip origin, Unreal axes, 2K color texture.\n',encoding='utf-8')
    report={'vertices':len(pos),'source_triangles':source_triangles,'runtime_triangles':len(ids)//3,'length_cm':95,'grip_source':GRIP,
            'source_gltf_sha256':hashlib.sha256((source/'scene.gltf').read_bytes()).hexdigest(),
            'source_bin_sha256':hashlib.sha256(binary).hexdigest(),
            'source_glb_sha256':hashlib.sha256((source/'wh-40k-chainsword.glb').read_bytes()).hexdigest(),
            'note':'Both downloads contain 8014 split vertices and 7814 triangles; no separate chain or rig.',
            'assets':{f.name:hashlib.sha256(f.read_bytes()).hexdigest().upper() for f in out.iterdir()}}
    (root/'prepared.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
