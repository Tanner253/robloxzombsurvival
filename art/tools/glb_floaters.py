"""Conform-pass gate (ART_DIRECTION 10a): flag floating islands and hovering cards in GLBs.

Splits each mesh into connected components (positions welded) and flags:
  - FLOAT: a component that touches neither the ground plane (the model's lowest point)
    nor any other component: no vertex of it within EPS of another component's surface
    (its triangles, not only its vertices: a bolt head resting on a wide plank face is
    far from that face's few vertices but touches the face), and
  - CARD:  a near-flat component (thinnest extent under CARD_RATIO of its widest) whose
    underside sits above the ground by more than EPS while resting on other geometry
    only along an edge: a decal-like sheet hovering over the model (e.g. a leaf mat or a
    lichen patch modelled as a separate sheet).

Usage:  python glb_floaters.py [--fix | --settle] file.glb [...]
  Exit code 1 when anything is flagged (0 flags is the gate).
  --fix settles small floaters onto the ground (a stick resting a hair above it, gap
  under 5% of the height) and deletes the rest, writing the file in place.
  --settle plants every floating piece on the ground whatever its gap: for a group of
  free-standing objects in one mesh (a sofa and armchairs) where each piece is whole and
  only hovers. Cards are still deleted.
EPS is 1% of the model's height; components under 0.2% of the triangles are ignored
for CARD (scan noise) but never for FLOAT.
"""
import json
import struct
import sys

import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from scipy.spatial import cKDTree

CARD_RATIO = 0.06
TINY = 0.002


def load(path):
    f = bytearray(open(path, 'rb').read())
    jl = struct.unpack('<I', f[12:16])[0]
    j = json.loads(f[20:20 + jl])
    return f, j, jl, 20 + jl + 8


def accessor(f, j, bstart, index):
    a = j['accessors'][index]
    v = j['bufferViews'][a['bufferView']]
    start = bstart + v.get('byteOffset', 0) + a.get('byteOffset', 0)
    n = {'SCALAR': 1, 'VEC3': 3}[a['type']]
    dt = {5123: np.uint16, 5125: np.uint32, 5126: np.float32}[a['componentType']]
    data = np.frombuffer(bytes(f), dt, a['count'] * n, start)
    return (data.reshape(-1, 3) if n == 3 else data), start, dt


def components(pos, idx):
    span = np.ptp(pos, axis=0).max()
    key = np.round(pos / (span * 1e-4)).astype(np.int64)
    _, weld = np.unique(key, axis=0, return_inverse=True)
    weld = weld.ravel()
    t = weld[idx]
    n = weld.max() + 1
    rows = np.concatenate([t[:, 0], t[:, 1], t[:, 2]])
    cols = np.concatenate([t[:, 1], t[:, 2], t[:, 0]])
    _, lab = connected_components(coo_matrix((np.ones(len(rows)), (rows, cols)), shape=(n, n)), directed=False)
    return lab[t[:, 0]]


def surface_contact(pts, tris, eps):
    """True when any point lies within eps of any triangle (tris: (T, 3, 3))."""
    if len(tris) == 0 or len(pts) == 0:
        return False
    a, b, c = tris[:, 0], tris[:, 1], tris[:, 2]
    n = np.cross(b - a, c - a)
    area = np.linalg.norm(n, axis=1)
    keep = area > 1e-12
    a, b, c, n = a[keep], b[keep], c[keep], n[keep] / area[keep, None]
    for start in range(0, len(pts), 64):
        p = pts[start:start + 64][:, None, :]  # (P, 1, 3)
        d = np.einsum('ptk,tk->pt', p - a[None], n)  # signed plane distance (P, T)
        near = np.abs(d) <= eps
        if not near.any():
            continue
        q = p - d[..., None] * n[None]  # projection onto each plane
        # barycentric inside test with an eps margin on the edges
        v0, v1 = (b - a)[None], (c - a)[None]
        v2 = q - a[None]
        d00 = np.einsum('ptk,ptk->pt', v0.repeat(len(p), 0), v0.repeat(len(p), 0))
        d01 = np.einsum('ptk,ptk->pt', v0.repeat(len(p), 0), v1.repeat(len(p), 0))
        d11 = np.einsum('ptk,ptk->pt', v1.repeat(len(p), 0), v1.repeat(len(p), 0))
        d20 = np.einsum('ptk,ptk->pt', v2, v0.repeat(len(p), 0))
        d21 = np.einsum('ptk,ptk->pt', v2, v1.repeat(len(p), 0))
        den = d00 * d11 - d01 * d01
        den = np.where(np.abs(den) < 1e-18, 1e-18, den)
        v = (d11 * d20 - d01 * d21) / den
        w = (d00 * d21 - d01 * d20) / den
        u = 1 - v - w
        span = np.sqrt(np.maximum(d00, d11))
        tol = -eps / np.maximum(span, 1e-9)
        inside = (u >= tol) & (v >= tol) & (w >= tol)
        if np.any(near & inside):
            return True
    return False


def check(path, fix=False, settle_all=False):
    f, j, jl, bstart = load(path)
    prim = j['meshes'][0]['primitives'][0]
    pos, _, _ = accessor(f, j, bstart, prim['attributes']['POSITION'])
    idx_flat, istart, dt = accessor(f, j, bstart, prim['indices'])
    idx = idx_flat.astype(np.int64).reshape(-1, 3)
    pos = pos.astype(float)
    tri_comp = components(pos, idx)
    ncomp = tri_comp.max() + 1
    ground = pos[:, 1].min()
    height = np.ptp(pos[:, 1])
    eps = max(height * 0.01, 1e-6)
    comp_pts = []
    for c in range(ncomp):
        verts = np.unique(idx[tri_comp == c])
        comp_pts.append(pos[verts])
    trees = [cKDTree(p) for p in comp_pts]
    flags = []
    for c in range(ncomp):
        pts = comp_pts[c]
        if len(pts) == 0:
            continue
        tris = int((tri_comp == c).sum())
        lo, hi = pts.min(axis=0), pts.max(axis=0)
        on_ground = lo[1] <= ground + eps
        touching = 0
        for o in range(ncomp):
            if o == c or len(comp_pts[o]) == 0:
                continue
            olo, ohi = comp_pts[o].min(axis=0), comp_pts[o].max(axis=0)
            if np.any(hi + eps < olo) or np.any(ohi + eps < lo):
                continue
            d, _ = trees[o].query(pts, k=1, distance_upper_bound=eps)
            touching += int(np.isfinite(d).sum())
            if touching == 0:
                # Resting on a face rather than near its vertices: test the triangles.
                otris = pos[idx[tri_comp == o]]
                tlo, thi = otris.min(axis=1), otris.max(axis=1)
                close = np.all(tlo <= hi + eps, axis=1) & np.all(thi >= lo - eps, axis=1)
                if surface_contact(pts, otris[close], eps):
                    touching += 1
        extent = hi - lo
        flat = extent.min() < CARD_RATIO * extent.max()
        if not on_ground and touching == 0:
            flags.append((c, 'FLOAT', tris, lo[1] - ground))
        elif flat and not on_ground and tris > TINY * len(idx) and touching < 0.05 * len(pts):
            flags.append((c, 'CARD', tris, lo[1] - ground))
    name = path.replace('\\', '/').split('/')[-1]
    if not flags:
        print(f'{name:24s} ok      ({ncomp} pieces)')
        return 0
    for c, kind, tris, above in flags:
        print(f'{name:24s} {kind:6s} piece {c}: {tris} triangles, {above:.3f} above ground')
    if fix:
        settle = {c for c, kind, _, above in flags if kind == 'FLOAT' and (settle_all or above < 0.05 * height)}
        bad = {c for c, _, _, _ in flags} - settle
        if settle:
            pa = j['accessors'][prim['attributes']['POSITION']]
            pv = j['bufferViews'][pa['bufferView']]
            pstart = bstart + pv.get('byteOffset', 0) + pa.get('byteOffset', 0)
            moved = pos.copy()
            for c in settle:
                verts = np.unique(idx[tri_comp == c])
                moved[verts, 1] -= moved[verts, 1].min() - ground
            f[pstart:pstart + moved.size * 4] = moved.astype(np.float32).tobytes()
            print(f'{name:24s} settled {len(settle)} pieces onto the ground')
        keep = ~np.isin(tri_comp, list(bad))
        new = idx[keep].astype(dt).tobytes()
        f[istart:istart + len(new)] = new
        j['accessors'][prim['indices']]['count'] = int(keep.sum() * 3)
        js = json.dumps(j, separators=(',', ':')).encode()
        assert len(js) <= jl
        f[20:20 + jl] = js + b' ' * (jl - len(js))
        open(path, 'wb').write(bytes(f))
        if bad:
            print(f'{name:24s} fixed: removed {int((~keep).sum())} triangles')
    return len(flags)


if __name__ == '__main__':
    args = sys.argv[1:]
    settle_all = '--settle' in args
    fix = '--fix' in args or settle_all
    files = [a for a in args if a not in ('--fix', '--settle')]
    total = sum(check(p, fix, settle_all) for p in files)
    sys.exit(1 if total and not fix else 0)
