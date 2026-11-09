"""
Retargets Quaternius UAL (CC0) clips from the Godot GLB onto Roblox R15 poses.

For each R15 part we take the matching UAL bone's world rotation delta from a rest
pose equivalent to R15's (arms hanging straight down), convert glTF (facing +Z) to
Roblox (facing -Z) by a 180 degree turn about Y, and write each part's Pose rotation as
delta(parent)^-1 * delta(part) (R15 joint frames are axis-aligned at rest). The hips
also carry a translation (scaled to the survivor's hip height).

Usage: python -I ual_retarget.py <glb> <out.json> <clip> [<clip> ...]
"""
import json
import struct
import sys

import numpy as np

FPS = 15

PARTS = {
    "LowerTorso": ("DEF-hips", None),
    "UpperTorso": ("DEF-spine.003", "LowerTorso"),
    "Head": ("DEF-head", "UpperTorso"),
    "RightUpperArm": ("DEF-upper_arm.R", "UpperTorso"),
    "RightLowerArm": ("DEF-forearm.R", "RightUpperArm"),
    "RightHand": ("DEF-hand.R", "RightLowerArm"),
    "LeftUpperArm": ("DEF-upper_arm.L", "UpperTorso"),
    "LeftLowerArm": ("DEF-forearm.L", "LeftUpperArm"),
    "LeftHand": ("DEF-hand.L", "LeftLowerArm"),
    "RightUpperLeg": ("DEF-thigh.R", "LowerTorso"),
    "RightLowerLeg": ("DEF-shin.R", "RightUpperLeg"),
    "RightFoot": ("DEF-foot.R", "RightLowerLeg"),
    "LeftUpperLeg": ("DEF-thigh.L", "LowerTorso"),
    "LeftLowerLeg": ("DEF-shin.L", "LeftUpperLeg"),
    "LeftFoot": ("DEF-foot.L", "LeftLowerLeg"),
}
# Bones whose rest direction is straightened to hang down like R15's limbs.
STRAIGHTEN = {
    "DEF-upper_arm.R": ("DEF-upper_arm.R", "DEF-forearm.R"),
    "DEF-forearm.R": ("DEF-upper_arm.R", "DEF-forearm.R"),
    "DEF-hand.R": ("DEF-upper_arm.R", "DEF-forearm.R"),
    "DEF-upper_arm.L": ("DEF-upper_arm.L", "DEF-forearm.L"),
    "DEF-forearm.L": ("DEF-upper_arm.L", "DEF-forearm.L"),
    "DEF-hand.L": ("DEF-upper_arm.L", "DEF-forearm.L"),
    "DEF-thigh.R": ("DEF-thigh.R", "DEF-shin.R"),
    "DEF-shin.R": ("DEF-thigh.R", "DEF-shin.R"),
    "DEF-thigh.L": ("DEF-thigh.L", "DEF-shin.L"),
    "DEF-shin.L": ("DEF-thigh.L", "DEF-shin.L"),
}
SURVIVOR_HIP = 2.9
ARM_OUT_DEG = 33  # studs from the ground to the R15 survivor's LowerTorso centre (approx.)


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    ])


def qinv(q):
    return np.array([-q[0], -q[1], -q[2], q[3]])


def qrot(q, v):
    p = np.array([v[0], v[1], v[2], 0.0])
    return qmul(qmul(q, p), qinv(q))[:3]


def qnorm(q):
    return q / np.linalg.norm(q)


def slerp(a, b, t):
    d = float(np.dot(a, b))
    if d < 0:
        b, d = -b, -d
    if d > 0.9995:
        return qnorm(a + (b - a) * t)
    th = np.arccos(d)
    return (np.sin((1 - t) * th) * a + np.sin(t * th) * b) / np.sin(th)


def between(u, v):
    """Shortest rotation taking direction u to direction v."""
    u = u / np.linalg.norm(u)
    v = v / np.linalg.norm(v)
    c = np.cross(u, v)
    d = float(np.dot(u, v))
    if d < -0.9999:
        axis = np.cross(u, [1, 0, 0])
        if np.linalg.norm(axis) < 1e-6:
            axis = np.cross(u, [0, 0, 1])
        axis /= np.linalg.norm(axis)
        return np.array([axis[0], axis[1], axis[2], 0.0])
    return qnorm(np.array([c[0], c[1], c[2], 1 + d]))


def load(path):
    b = open(path, "rb").read()
    clen = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + clen])
    off = 20 + clen
    blen = struct.unpack("<I", b[off:off + 4])[0]
    bin_ = b[off + 8:off + 8 + blen]

    def accessor(i):
        a = j["accessors"][i]
        bv = j["bufferViews"][a["bufferView"]]
        n = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[a["type"]]
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        assert a["componentType"] == 5126
        arr = np.frombuffer(bin_, dtype="<f4", count=a["count"] * n, offset=start)
        return arr.reshape(a["count"], n) if n > 1 else arr

    return j, accessor


def main():
    glb, out, clips = sys.argv[1], sys.argv[2], sys.argv[3:]
    j, accessor = load(glb)
    nodes = j["nodes"]
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parent[c] = i
    index = {n.get("name"): i for i, n in enumerate(nodes)}
    rest_r = [qnorm(np.array(n.get("rotation", [0, 0, 0, 1]), dtype=float)) for n in nodes]
    rest_t = [np.array(n.get("translation", [0, 0, 0]), dtype=float) for n in nodes]

    def world(i, rots, trans):
        r = np.array([0, 0, 0, 1.0])
        t = np.zeros(3)
        chain = []
        k = i
        while k is not None:
            chain.append(k)
            k = parent.get(k)
        for k in reversed(chain):
            t = t + qrot(r, trans[k])
            r = qnorm(qmul(r, rots[k]))
        return r, t

    # Rest world frames, with limbs straightened to hang down (R15's rest).
    rest_world = {}
    for name, idx in index.items():
        rest_world[name] = world(idx, rest_r, rest_t)
    # The survivor rig's rest limb directions, measured from its rig attachments (Roblox
    # space, facing -Z) and turned into glTF space (facing +Z): (x, y, z) -> (-x, y, -z).
    def g(x, y, z):
        return np.array([-x, y, -z])

    targets = {
        "DEF-upper_arm.R": ("DEF-forearm.R", g(0.156, -0.985, -0.067)),
        "DEF-forearm.R": ("DEF-hand.R", g(0.081, -0.955, -0.285)),
        "DEF-upper_arm.L": ("DEF-forearm.L", g(-0.149, -0.988, -0.052)),
        "DEF-forearm.L": ("DEF-hand.L", g(-0.092, -0.957, -0.274)),
        "DEF-thigh.R": ("DEF-shin.R", g(0.108, -0.994, 0.007)),
        "DEF-shin.R": ("DEF-foot.R", g(0.106, -0.987, 0.120)),
        "DEF-thigh.L": ("DEF-shin.L", g(-0.108, -0.994, 0.007)),
        "DEF-shin.L": ("DEF-foot.L", g(-0.106, -0.987, 0.120)),
    }
    fix = {}
    for bone, (child, target) in targets.items():
        fix[bone] = between(rest_world[child][1] - rest_world[bone][1], target)
    # Hands follow their forearm's correction.
    fix["DEF-hand.R"] = fix["DEF-forearm.R"]
    fix["DEF-hand.L"] = fix["DEF-forearm.L"]
    hip_rest = rest_world["DEF-hips"][1]

    turn = np.array([0, 1, 0, 0.0])  # 180 degrees about Y: glTF +Z forward -> Roblox -Z

    def to_roblox_q(q):
        return qnorm(qmul(qmul(turn, q), qinv(turn)))

    result = {}
    for clip in clips:
        anim = next(a for a in j["animations"] if a["name"] == clip)
        tracks = {}
        length = 0.0
        for ch in anim["channels"]:
            s = anim["samplers"][ch["sampler"]]
            times = accessor(s["input"])
            vals = accessor(s["output"])
            length = max(length, float(times[-1]))
            tracks[(ch["target"]["node"], ch["target"]["path"])] = (times, vals)

        def sample(node, path, t, default):
            tr = tracks.get((node, path))
            if tr is None:
                return default
            times, vals = tr
            if t <= times[0]:
                return np.array(vals[0], dtype=float)
            if t >= times[-1]:
                return np.array(vals[-1], dtype=float)
            k = int(np.searchsorted(times, t)) - 1
            f = (t - times[k]) / (times[k + 1] - times[k])
            if path == "rotation":
                return slerp(np.array(vals[k], dtype=float), np.array(vals[k + 1], dtype=float), f)
            return vals[k] * (1 - f) + vals[k + 1] * f

        keys = []
        frames = max(2, int(round(length * FPS)) + 1)
        for fi in range(frames):
            t = min(length, fi / FPS)
            rots = [qnorm(sample(i, "rotation", t, rest_r[i])) for i in range(len(nodes))]
            trans = [np.array(sample(i, "translation", t, rest_t[i]), dtype=float) for i in range(len(nodes))]
            deltas = {}
            hip_pos = None
            for part, (bone, _) in PARTS.items():
                r, p = world(index[bone], rots, trans)
                rr = rest_world[bone][0]
                if bone in fix:
                    rr = qnorm(qmul(fix[bone], rr))  # the bind pose with this limb hanging down
                deltas[part] = to_roblox_q(qnorm(qmul(r, qinv(rr))))
                if bone == "DEF-hips":
                    hip_pos = p
            poses = {}
            for part, (_, par) in PARTS.items():
                d = deltas[part]
                q = d if par is None else qnorm(qmul(qinv(deltas[par]), d))
                entry = [round(float(x), 4) for x in q]
                if par is None:
                    scale = SURVIVOR_HIP / max(hip_rest[1], 1e-3)
                    off = (hip_pos - hip_rest) * scale
                    entry += [round(float(-off[0]), 3), round(float(off[1]), 3), round(float(-off[2]), 3)]
                poses[part] = entry
            keys.append({"t": round(t, 4), "p": poses})
        result[clip] = {"length": round(length, 4), "keys": keys}
        print(clip, "length", round(length, 3), "keys", len(keys))
    json.dump(result, open(out, "w"), separators=(",", ":"))


main()
