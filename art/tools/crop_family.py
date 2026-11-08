import numpy as np
from PIL import Image
from scipy import ndimage
sheets = {
    'nature': (3, 2, ['dead_tree', 'bare_branches', 'rock_cluster', 'reed_stubble', 'grass_clump', 'twig_shrub']),
    'camp': (3, 3, ['campfire', 'storage_crate', 'recycler', 'spring_basin', 'lantern_post', 'standing_torch', 'barrels', 'supply_sacks', 'rain_collector']),
}
for name, (cols, rows, names) in sheets.items():
    im = Image.open(f'families/{name}_sheet_v1.png').convert('RGB')
    a = np.asarray(im).astype(int)
    bg = np.median(np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3)]), axis=0)
    diff = np.abs(a - bg).max(axis=2)
    mask = ndimage.binary_dilation(diff > 14, iterations=6)
    labels, n = ndimage.label(mask)
    W, H = im.size
    boxes = ndimage.find_objects(labels)
    sizes = ndimage.sum(mask, labels, range(1, n + 1))
    owner = {}
    for i, sl in enumerate(boxes):
        if sizes[i] < 400:
            continue
        cy = (sl[0].start + sl[0].stop) / 2
        cx = (sl[1].start + sl[1].stop) / 2
        cell = int(cy // (H / rows)) * cols + int(cx // (W / cols))
        owner.setdefault(cell, []).append(sl)
    for idx, asset in enumerate(names):
        sls = owner.get(idx, [])
        y0 = min(s[0].start for s in sls); y1 = max(s[0].stop for s in sls)
        x0 = min(s[1].start for s in sls); x1 = max(s[1].stop for s in sls)
        # keep only this cell's components: blank everything else
        keep = np.zeros_like(mask)
        for s in sls:
            lab = labels[s]
            ids = set(np.unique(lab)) - {0}
            for k in ids:
                keep[s] |= lab == k
        crop = a.copy()
        crop[~keep] = bg
        crop = Image.fromarray(crop.astype('uint8')).crop((x0, y0, x1, y1))
        side = int(max(x1 - x0, y1 - y0) * 1.12)
        out = Image.new('RGB', (side, side), tuple(int(v) for v in bg))
        out.paste(crop, ((side - (x1 - x0)) // 2, (side - (y1 - y0)) // 2))
        out.resize((1024, 1024), Image.LANCZOS).save(f'crops/{asset}.png')
        print(asset, (x0, y0, x1, y1), len(sls), 'parts')
