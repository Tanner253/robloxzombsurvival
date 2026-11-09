"""
Offline preview of the survivor's melee, tool and action moves (checklist 13.4).

Reads tools/anim/export.luau's JSON (the StarterCharacter rig and every move built by
Domain/MeleeKeys), poses the rig exactly as the client does (each part's rotation q,
relative to its parent in character space, becomes the joint transform J^-1 * q * J;
part = parent * a0 * T * a1^-1), and draws 6-frame sheets: prep, windup, mid-strike,
contact, follow-through and recovery. Row 1 is the game camera (55 degree pitch, 45 degree
yaw, the survivor facing screen right), row 2 the side and row 3 the front. The weapon is
drawn from the grip attachment along the hand mount (Models.held "hand"), and its tip's
path from windup to follow-through is traced.

Usage (from roblox/):
  lune run tools/anim/export.luau <export.json>
  python -P tools/anim/preview.py <export.json> <out_dir> [move ...] [--variant upper]
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

CELL = 300
WEAPON_LENGTH = 2.4
WEAPON_GRIP = 0.14
MOUNT_LOOK = np.array([0.0, 0.35, -1.0]) / np.linalg.norm([0.0, 0.35, -1.0])

PARENTS = {
    "LowerTorso": "HumanoidRootPart",
    "UpperTorso": "LowerTorso",
    "Head": "UpperTorso",
    "RightUpperArm": "UpperTorso",
    "RightLowerArm": "RightUpperArm",
    "RightHand": "RightLowerArm",
    "LeftUpperArm": "UpperTorso",
    "LeftLowerArm": "LeftUpperArm",
    "LeftHand": "LeftLowerArm",
    "RightUpperLeg": "LowerTorso",
    "RightLowerLeg": "RightUpperLeg",
    "RightFoot": "RightLowerLeg",
    "LeftUpperLeg": "LowerTorso",
    "LeftLowerLeg": "LeftUpperLeg",
    "LeftFoot": "LeftLowerLeg",
}
ORDER = list(PARENTS.keys())
COLORS = {
    "Head": (222, 196, 170),
    "UpperTorso": (92, 110, 128),
    "LowerTorso": (70, 76, 84),
    "RightUpperArm": (104, 124, 146),
    "RightLowerArm": (222, 196, 170),
    "RightHand": (222, 196, 170),
    "LeftUpperArm": (84, 100, 118),
    "LeftLowerArm": (190, 166, 144),
    "LeftHand": (190, 166, 144),
    "RightUpperLeg": (66, 70, 60),
    "RightLowerLeg": (66, 70, 60),
    "RightFoot": (48, 40, 34),
    "LeftUpperLeg": (56, 60, 52),
    "LeftLowerLeg": (56, 60, 52),
    "LeftFoot": (40, 34, 28),
}


def cf(c):
    m = np.eye(4)
    m[:3, 3] = c[0:3]
    m[0, :3] = c[3:6]
    m[1, :3] = c[6:9]
    m[2, :3] = c[9:12]
    return m


def rot_only(m):
    r = np.eye(4)
    r[:3, :3] = m[:3, :3]
    return r


def quat_matrix(q):
    x, y, z, w = q
    n = math.sqrt(x * x + y * y + z * z + w * w) or 1.0
    x, y, z, w = x / n, y / n, z / n, w / n
    m = np.eye(4)
    m[:3, :3] = [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]
    return m


def slerp(a, b, t):
    a = np.array(a, dtype=float)
    b = np.array(b, dtype=float)
    d = float(np.dot(a, b))
    if d < 0:
        b, d = -b, -d
    if d > 0.9995:
        r = a + (b - a) * t
        return r / np.linalg.norm(r)
    th = math.acos(min(1.0, d))
    return (math.sin((1 - t) * th) * a + math.sin(t * th) * b) / math.sin(th)


def ease(name, a):
    if name == "linear":
        return a
    if name == "constant":
        return 0.0
    if name == "in":
        return a ** 3
    if name == "out":
        return 1 - (1 - a) ** 3
    return 4 * a ** 3 if a < 0.5 else 1 - (-2 * a + 2) ** 3 / 2  # inOut


class Rig:
    def __init__(self, data):
        self.parts = data["parts"]
        self.joints = {k: (v["parent"], cf(v["c0"]), cf(v["c1"])) for k, v in data["joints"].items()}
        self.grip = cf(data["grip"]) if data.get("grip") else np.eye(4)
        rest = {"HumanoidRootPart": np.eye(4)}
        frames = {}

        def rest_of(name):
            if name in rest:
                return rest[name]
            parent, c0, c1 = self.joints[name]
            pr = rest_of(parent)
            frames[name] = rot_only(pr) @ rot_only(c0)
            rest[name] = frames[name] @ np.linalg.inv(rot_only(c1))
            return rest[name]

        for name in ORDER:
            rest_of(name)
        self.frames = frames

    def pose(self, poses, yaw=0.0):
        root = np.eye(4)
        c, s = math.cos(yaw), math.sin(yaw)
        root[:3, :3] = [[c, 0, s], [0, 1, 0], [-s, 0, c]]
        world = {"HumanoidRootPart": root}

        def solve(name):
            if name in world:
                return world[name]
            parent, c0, c1 = self.joints[name]
            pw = solve(parent)
            j = self.frames[name]
            jinv = np.linalg.inv(j)
            t = np.eye(4)
            v = poses.get(name)
            if v is not None:
                t = jinv @ quat_matrix(v[0:4]) @ j
                if len(v) > 4:
                    t[:3, 3] = (jinv[:3, :3] @ np.array(v[4:7]))
            world[name] = pw @ c0 @ t @ np.linalg.inv(c1)
            return world[name]

        for name in ORDER:
            solve(name)
        return world

    weapon_length = WEAPON_LENGTH
    weapon_grip = WEAPON_GRIP

    def weapon(self, world):
        hand = world["RightHand"]
        grip = (hand @ self.grip)[:3, 3]
        look = hand[:3, :3] @ MOUNT_LOOK
        butt = grip - look * self.weapon_length * self.weapon_grip
        tip = grip + look * self.weapon_length * (1 - self.weapon_grip)
        return butt, grip, tip


def sample(built, t):
    keys = built["keys"]
    if t <= keys[0]["t"]:
        return keys[0]["poses"]
    for a, b in zip(keys, keys[1:]):
        if a["t"] <= t <= b["t"]:
            span = b["t"] - a["t"]
            alpha = ease(a["ease"], (t - a["t"]) / span if span > 0 else 1)
            out = {}
            for part, qa in a["poses"].items():
                qb = b["poses"].get(part, qa)
                q = list(slerp(qa[0:4], qb[0:4], alpha))
                if len(qa) > 4:
                    pb = qb[4:7] if len(qb) > 4 else qa[4:7]
                    q += [qa[4 + i] + (pb[i] - qa[4 + i]) * alpha for i in range(3)]
                out[part] = q
            return out
    return keys[-1]["poses"]


def view_matrix(kind):
    if kind == "game":
        pitch, yaw = math.radians(55), math.radians(45)
        cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(-pitch), math.sin(-pitch)
        ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
        rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
        return ry @ rx  # columns: camera right, up, back
    if kind == "side":  # looking at the survivor's right side
        return np.array([[0, 0, -1], [0, 1, 0], [1, 0, 0]], dtype=float).T
    return np.array([[-1, 0, 0], [0, 1, 0], [0, 0, -1]], dtype=float).T  # front


BOX_FACES = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]


def box_corners(m, size):
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                pts.append((m @ np.array([sx * hx, sy * hy, sz * hz, 1.0]))[:3])
    return pts


def render(rig, world, trail, kind, label, scale=38):
    img = Image.new("RGB", (CELL, CELL), (30, 34, 40))
    draw = ImageDraw.Draw(img)
    cam = view_matrix(kind)
    right, up, back = cam[:, 0], cam[:, 1], cam[:, 2]
    centre = world["HumanoidRootPart"][:3, 3] + np.array([0, -0.3, 0])

    def proj(p):
        d = p - centre
        return (CELL / 2 + float(np.dot(d, right)) * scale, CELL / 2 + 20 - float(np.dot(d, up)) * scale), float(np.dot(d, back))

    ground = centre[1] - 3.3
    gpts = [proj(centre + np.array([x, ground - centre[1], z]))[0] for x, z in ((-3, -3), (3, -3), (3, 3), (-3, 3))]
    draw.polygon(gpts, fill=(44, 50, 44))
    # A Hollow-sized target 3.2 studs ahead, and the facing arrow on the ground.
    root = world["HumanoidRootPart"]
    fwd = -root[:3, 2]
    rgt = root[:3, 0]
    base = centre + np.array([0, ground - centre[1], 0])
    arrow = [proj(base + fwd * 0.6)[0], proj(base + fwd * 2.4)[0]]
    draw.line(arrow, fill=(110, 140, 110), width=3)
    tc = base + fwd * 3.2
    target_pts = []
    for h in (0.0, 5.2):
        for sx, sz in ((-0.8, -0.5), (0.8, -0.5), (0.8, 0.5), (-0.8, 0.5)):
            target_pts.append(proj(tc + rgt * sx + fwd * sz + np.array([0, h, 0]))[0])
    target_edges = [(0, 1), (1, 2), (2, 3), (3, 0), (4, 5), (5, 6), (6, 7), (7, 4), (0, 4), (1, 5), (2, 6), (3, 7)]
    light = np.array([0.3, 0.8, 0.5])
    light /= np.linalg.norm(light)
    faces = []
    for name in ORDER:
        corners = box_corners(world[name], rig.parts[name]["size"])
        for face in BOX_FACES:
            pts3 = [corners[i] for i in face]
            normal = np.cross(pts3[1] - pts3[0], pts3[2] - pts3[0])
            n = np.linalg.norm(normal)
            if n < 1e-9:
                continue
            normal /= n
            centroid = sum(pts3) / 4
            if np.dot(normal, centroid - world[name][:3, 3]) < 0:
                normal = -normal
            if np.dot(normal, back) <= 0:
                continue
            shade = 0.45 + 0.55 * max(0.0, float(np.dot(normal, light)))
            col = tuple(int(c * shade) for c in COLORS[name])
            faces.append((proj(centroid)[1], [proj(p)[0] for p in pts3], col))
    butt, grip, tip = rig.weapon(world)
    faces.sort(key=lambda f: f[0])
    weapon_depth = proj(grip)[1]
    drawn_weapon = False
    for depth, pts, col in faces:
        if not drawn_weapon and depth > weapon_depth:
            draw_weapon(draw, proj, butt, grip, tip, trail)
            drawn_weapon = True
        draw.polygon(pts, fill=col, outline=(20, 22, 26))
    if not drawn_weapon:
        draw_weapon(draw, proj, butt, grip, tip, trail)
    for a, b in target_edges:
        draw.line([target_pts[a], target_pts[b]], fill=(170, 70, 70), width=1)
    draw.text((6, 6), label, fill=(240, 220, 160))
    return img


def draw_weapon(draw, proj, butt, grip, tip, trail):
    if trail:
        pts = [proj(p)[0] for p in trail]
        draw.line(pts, fill=(255, 190, 90), width=2)
    draw.line([proj(butt)[0], proj(grip)[0]], fill=(120, 84, 50), width=5)
    draw.line([proj(grip)[0], proj(tip)[0]], fill=(196, 200, 206), width=6)
    x, y = proj(tip)[0]
    draw.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(255, 120, 60))


# Art.held lengths and grips per class (the longest of each class).
WEAPONS = {
    "blade": (2.3, 0.12), "axe": (2.9, 0.12), "pick": (2.2, 0.16), "blunt": (2.3, 0.14),
    "heavy": (3.4, 0.1), "stab": (3.4, 0.14), "fists": (0.0, 0.0), "gather.chop": (1.7, 0.18),
    "gather.mine": (2.2, 0.16), "gather.pickup": (0.0, 0.0), "use": (0.0, 0.0), "react": (0.0, 0.0),
}


def arm_weapon(rig, move_id):
    for prefix in (move_id, move_id.split(".")[0]):
        if prefix in WEAPONS:
            rig.weapon_length, rig.weapon_grip = WEAPONS[prefix]
            return


def compact(rig, moves, ids, variant, kind, path):
    """One row per move, the six frames of one view, for reviewing many moves at once."""
    global CELL
    keep = CELL
    CELL = 200
    img = Image.new("RGB", (CELL * 6 + 140, CELL * len(ids)), (18, 20, 24))
    draw = ImageDraw.Draw(img)
    for r, move_id in enumerate(ids):
        arm_weapon(rig, move_id)
        move = moves[move_id]
        built, marks = move[variant], move["marks"]
        yaw = math.radians(-45) if kind == "game" else 0.0
        t0, t1 = marks["windup"], marks["follow"]
        trail = [rig.weapon(rig.pose(sample(built, t0 + (t1 - t0) * i / 24), yaw))[2] for i in range(25)]
        draw.text((6, r * CELL + 8), move_id, fill=(255, 255, 255))
        for c, (name, at) in enumerate(FRAMES):
            t = at(marks)
            cell = render(rig, rig.pose(sample(built, t), yaw), trail, kind, f"{name} {t:.2f}", scale=25)
            img.paste(cell, (140 + c * CELL, r * CELL))
    img.save(path)
    CELL = keep
    return path


FRAMES = [
    ("prep", lambda m: m["prep"] if m["prep"] > 0 else m["windup"] * 0.4),
    ("windup", lambda m: m["windup"]),
    ("strike", lambda m: (m["windup"] + m["contact"]) / 2),
    ("contact", lambda m: m["contact"]),
    ("follow", lambda m: m["follow"]),
    ("recover", lambda m: (m["follow"] + m["cycle"]) / 2),
]


def sheet(rig, move_id, move, variant, out_dir):
    arm_weapon(rig, move_id)
    built = move[variant]
    marks = move["marks"]
    yaw = math.radians(-45)  # facing screen right in the game camera
    trail = []
    t0, t1 = marks["windup"], marks["follow"]
    for i in range(25):
        t = t0 + (t1 - t0) * i / 24
        trail.append(rig.weapon(rig.pose(sample(built, t), yaw))[2])
    rows = []
    for kind in ("game", "side", "front"):
        cells = []
        for name, at in FRAMES:
            t = at(marks)
            y = yaw if kind == "game" else 0.0
            world = rig.pose(sample(built, t), y)
            tr = trail if kind == "game" else [rig.weapon(rig.pose(sample(built, t0 + (t1 - t0) * i / 24), 0.0))[2] for i in range(25)]
            cells.append(render(rig, world, tr, kind, f"{name} {t:.2f}s" if kind == "game" else name))
        rows.append(cells)
    img = Image.new("RGB", (CELL * 6, CELL * 3 + 24), (18, 20, 24))
    draw = ImageDraw.Draw(img)
    draw.text((8, 6), f"{move_id} ({variant})  marks {marks}", fill=(255, 255, 255))
    for r, cells in enumerate(rows):
        for c, cell in enumerate(cells):
            img.paste(cell, (c * CELL, 24 + r * CELL))
    path = os.path.join(out_dir, f"{move_id}_{variant}.png")
    img.save(path)
    return path


def measure(data):
    """Prints the arm geometry Domain/MeleeKeys's arm solver hardcodes (torso space, rest)."""
    rig = Rig(data["rig"])
    world = rig.pose({}, 0.0)
    torso = world["UpperTorso"]
    tinv = np.linalg.inv(torso)
    joints = rig.joints

    def pivot(child):
        parent, c0, _ = joints[child]
        return (tinv @ world[parent] @ c0)[:3, 3]

    for side, grip_name in (("Right", "RightGripAttachment"), ("Left", "LeftGripAttachment")):
        shoulder = pivot(f"{side}UpperArm")
        elbow = pivot(f"{side}LowerArm")
        wrist = pivot(f"{side}Hand")
        hand = tinv @ world[f"{side}Hand"]
        grip_cf = rig.grip if side == "Right" else cf(data["rig"].get("leftGrip") or [0, -0.096, -0.065, 1, 0, 0, 0, 1, 0, 0, 0, 1])
        grip = (hand @ grip_cf)[:3, 3]
        look = hand[:3, :3] @ MOUNT_LOOK
        fmt = lambda v: "{ " + ", ".join(f"{x:.4f}" for x in v) + " }"
        print(f"{side}: shoulder={fmt(shoulder)} elbow={fmt(elbow)} wrist={fmt(wrist)} grip={fmt(grip)}")
        print(f"  handRest rows={fmt(hand[0,:3])} {fmt(hand[1,:3])} {fmt(hand[2,:3])} weaponRest={fmt(look)}")


def main():
    args = sys.argv[1:]
    if args and args[0] == "--measure":
        measure(json.load(open(args[1])))
        return
    variant = "full"
    if "--variant" in args:
        i = args.index("--variant")
        variant = args[i + 1]
        del args[i:i + 2]
    data = json.load(open(args[0]))
    out_dir = args[1]
    os.makedirs(out_dir, exist_ok=True)
    rig = Rig(data["rig"])
    if args[2:3] == ["--compact"]:
        kind = args[3]
        ids = args[4:] or sorted(data["moves"].keys())
        print(compact(rig, data["moves"], ids, variant, kind, os.path.join(out_dir, f"compact_{kind}_{variant}_{ids[0]}.png")))
        return
    wanted = args[2:] or sorted(data["moves"].keys())
    for move_id in wanted:
        print(sheet(rig, move_id, data["moves"][move_id], variant, out_dir))


main()
