"""Conform step: drop disconnected fragments under 1% of the triangles (floaters) from a GLB, in place."""
import json, struct, sys
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

for path in sys.argv[1:]:
    f = bytearray(open(path, 'rb').read())
    jl = struct.unpack('<I', f[12:16])[0]
    j = json.loads(f[20:20 + jl])
    off = 20 + jl
    bstart = off + 8
    p = j['meshes'][0]['primitives'][0]
    pa = j['accessors'][p['attributes']['POSITION']]; pv = j['bufferViews'][pa['bufferView']]
    pos = np.frombuffer(bytes(f), np.float32, pa['count'] * 3, bstart + pv.get('byteOffset', 0) + pa.get('byteOffset', 0)).reshape(-1, 3)
    ia = j['accessors'][p['indices']]; iv = j['bufferViews'][ia['bufferView']]
    dt = {5123: np.uint16, 5125: np.uint32}[ia['componentType']]
    istart = bstart + iv.get('byteOffset', 0) + ia.get('byteOffset', 0)
    idx = np.frombuffer(bytes(f), dt, ia['count'], istart).reshape(-1, 3)
    key = np.round(pos / (np.ptp(pos, axis=0).max() * 1e-4)).astype(np.int64)
    _, weld = np.unique(key, axis=0, return_inverse=True); weld = weld.ravel()
    t = weld[idx.astype(int)]
    n = weld.max() + 1
    rows = np.concatenate([t[:, 0], t[:, 1], t[:, 2]]); cols = np.concatenate([t[:, 1], t[:, 2], t[:, 0]])
    _, lab = connected_components(coo_matrix((np.ones(len(rows)), (rows, cols)), shape=(n, n)), directed=False)
    tl = lab[t[:, 0]]
    counts = np.bincount(tl)
    keep = counts[tl] >= 0.01 * len(idx)
    new = idx[keep].astype(dt).tobytes()
    f[istart:istart + len(new)] = new
    ia['count'] = int(keep.sum() * 3)
    js = json.dumps(j, separators=(',', ':')).encode()
    # keep the JSON chunk the same length (pad with spaces) so offsets don't move
    assert len(js) <= jl, 'json grew'
    js += b' ' * (jl - len(js))
    f[20:20 + jl] = js
    open(path, 'wb').write(bytes(f))
    print(path, 'removed', int((~keep).sum()), 'triangles')
