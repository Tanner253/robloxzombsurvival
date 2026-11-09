"""Crops a family sheet (grid of separate subjects on a flat grey or transparent background)
into one square PNG per subject, padded, for 3D conversion or icons.

usage: python crop_sheet.py <sheet.png> <cols> <rows> <outdir> <name1,name2,...> [--alpha]
Subjects are found as connected components and assigned to the grid cell holding their centre.
With --alpha the output keeps transparency (icons); otherwise the background stays flat grey.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sheet, cols, rows, outdir, names = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], sys.argv[5].split(",")
alpha = "--alpha" in sys.argv
im = Image.open(sheet).convert("RGBA")
a = np.asarray(im).astype(int)
W, H = im.size
if alpha:
    mask = a[:, :, 3] > 24
    bg = np.array([0, 0, 0])
else:
    rgb = a[:, :, :3]
    bg = np.median(np.concatenate([rgb[:8].reshape(-1, 3), rgb[-8:].reshape(-1, 3), rgb[:, :8].reshape(-1, 3), rgb[:, -8:].reshape(-1, 3)]), axis=0)
    mask = np.abs(rgb - bg).max(axis=2) > 16
mask = ndimage.binary_dilation(mask, iterations=4)
labels, n = ndimage.label(mask)
boxes = ndimage.find_objects(labels)
sizes = ndimage.sum(mask, labels, range(1, n + 1))
owner = {}
for i, sl in enumerate(boxes):
    if sizes[i] < 600:
        continue
    cy = (sl[0].start + sl[0].stop) / 2
    cx = (sl[1].start + sl[1].stop) / 2
    cell = min(int(cy // (H / rows)), rows - 1) * cols + min(int(cx // (W / cols)), cols - 1)
    owner.setdefault(cell, []).append(i + 1)
os.makedirs(outdir, exist_ok=True)
for idx, name in enumerate(names):
    ids = owner.get(idx, [])
    if not ids:
        print("missing", name)
        continue
    keep = np.isin(labels, ids)
    ys, xs = np.nonzero(keep)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    out = a.copy()
    if alpha:
        out[~keep, 3] = 0
    else:
        out[~keep, :3] = bg
        out[:, :, 3] = 255
    crop = Image.fromarray(out.astype("uint8"), "RGBA").crop((x0, y0, x1, y1))
    side = int(max(x1 - x0, y1 - y0) * 1.12)
    fill = (0, 0, 0, 0) if alpha else tuple(int(v) for v in bg) + (255,)
    canvas = Image.new("RGBA", (side, side), fill)
    canvas.paste(crop, ((side - (x1 - x0)) // 2, (side - (y1 - y0)) // 2))
    if not alpha:
        canvas = canvas.convert("RGB")
    canvas.save(os.path.join(outdir, name + ".png"))
    print(name, canvas.size)
