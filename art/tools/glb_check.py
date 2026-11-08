"""Per GLB: vertex/triangle counts, bounding box, and disconnected pieces (floaters) after welding positions."""
import json, struct, sys
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}

def load(path):
    f = open(path, 'rb').read()
    jl = struct.unpack('<I', f[12:16])[0]
    j = json.loads(f[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack('<I', f[off:off + 4])[0]
    b = f[off + 8:off + 8 + bl]
    def acc(i):
        a = j['accessors'][i]; v = j['bufferViews'][a['bufferView']]
        start = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        n = NC[a['type']]
        return np.frombuffer(b, CT[a['componentType']], a['count'] * n, start).reshape(-1, n) if n > 1 else np.frombuffer(b, CT[a['componentType']], a['count'], start)
    return j, acc

for path in sys.argv[1:]:
    j, acc = load(path)
    p = j['meshes'][0]['primitives'][0]
    pos = acc(p['attributes']['POSITION']).astype(float)
    idx = acc(p['indices']).astype(int).reshape(-1, 3)
    key = np.round(pos / (np.ptp(pos, axis=0).max() * 1e-4)).astype(np.int64)
    _, weld = np.unique(key, axis=0, return_inverse=True)
    weld = weld.ravel()
    t = weld[idx]
    rows = np.concatenate([t[:, 0], t[:, 1], t[:, 2]]); cols = np.concatenate([t[:, 1], t[:, 2], t[:, 0]])
    n = weld.max() + 1
    ncomp, lab = connected_components(coo_matrix((np.ones(len(rows)), (rows, cols)), shape=(n, n)), directed=False)
    tri_lab = lab[t[:, 0]]
    counts = np.bincount(tri_lab, minlength=ncomp)
    order = np.argsort(-counts)
    size = np.ptp(pos, axis=0)
    small = [(int(counts[c])) for c in order[1:] if counts[c] > 0]
    print(f"{path.split('/')[-1]:22s} tris={len(idx):6d} size={np.round(size, 3)} pieces={ncomp} main={counts[order[0]]} others={small[:8]}{'...' if len(small) > 8 else ''}")
