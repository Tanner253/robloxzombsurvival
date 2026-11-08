"""Conform step: lay a lying-down asset flat (a pile of branches, a log, a rug).

Tripo sometimes rebuilds a top-down concept tilted. This turns the mesh so its
thinnest principal axis points up (+Y), keeps the longest axis along Z, puts the
lowest point on y = 0 and writes positions and normals back in place.

Usage:  python glb_layflat.py file.glb [...]
Only for assets that lie on the ground; standing things keep their authored up.
"""
import json
import struct
import sys

import numpy as np


def run(path):
    f = bytearray(open(path, 'rb').read())
    jl = struct.unpack('<I', f[12:16])[0]
    j = json.loads(f[20:20 + jl])
    bstart = 20 + jl + 8
    prim = j['meshes'][0]['primitives'][0]

    def view(name):
        a = j['accessors'][prim['attributes'][name]]
        v = j['bufferViews'][a['bufferView']]
        start = bstart + v.get('byteOffset', 0) + a.get('byteOffset', 0)
        arr = np.frombuffer(bytes(f), np.float32, a['count'] * 3, start).reshape(-1, 3).astype(float)
        return a, start, arr

    pa, pstart, pos = view('POSITION')
    centre = pos.mean(axis=0)
    _, vecs = np.linalg.eigh(np.cov((pos - centre).T))
    up, mid, long = vecs[:, 0], vecs[:, 1], vecs[:, 2]  # ascending variance
    if np.dot(up, [0, 1, 0]) < 0:
        up = -up
    x = np.cross(up, long)
    rot = np.stack([x, up, long])  # rows: new X, Y, Z in old coordinates
    if np.linalg.det(rot) < 0:
        rot[0] = -rot[0]
    new = (pos - centre) @ rot.T
    new[:, 1] -= new[:, 1].min()
    f[pstart:pstart + new.size * 4] = new.astype(np.float32).tobytes()
    pa['min'] = new.min(axis=0).tolist()
    pa['max'] = new.max(axis=0).tolist()
    if 'NORMAL' in prim['attributes']:
        _, nstart, nrm = view('NORMAL')
        out = nrm @ rot.T
        f[nstart:nstart + out.size * 4] = out.astype(np.float32).tobytes()
    # Rewrite the container: the JSON chunk may grow; the BIN chunk is copied as is
    # (bufferView offsets are relative to it).
    binary = bytes(f[20 + jl:])
    js = json.dumps(j, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    total = 12 + 8 + len(js) + len(binary)
    out_bytes = struct.pack('<III', 0x46546C67, 2, total) + struct.pack('<II', len(js), 0x4E4F534A) + js + binary
    open(path, 'wb').write(out_bytes)
    size = np.ptp(new, axis=0)
    print(f'{path}: laid flat, size {np.round(size / size.max(), 3)}')


for p in sys.argv[1:]:
    run(p)
