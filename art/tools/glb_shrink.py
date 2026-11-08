"""Rewrite a GLB with every texture downsized to MAX px (Roblox caps SurfaceAppearance maps at 1024)."""
import io, json, struct, sys
from PIL import Image

MAX = 1024

def shrink(src, dst):
    f = open(src, 'rb').read()
    jl = struct.unpack('<I', f[12:16])[0]
    j = json.loads(f[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack('<I', f[off:off + 4])[0]
    binary = f[off + 8: off + 8 + bl]
    image_views = {im['bufferView']: im for im in j.get('images', [])}
    out = bytearray()
    for i, view in enumerate(j['bufferViews']):
        start = view.get('byteOffset', 0)
        data = binary[start:start + view['byteLength']]
        if i in image_views:
            im = Image.open(io.BytesIO(data))
            im.load()
            if max(im.size) > MAX:
                im = im.resize((MAX, MAX * im.height // im.width), Image.LANCZOS)
            buf = io.BytesIO()
            if image_views[i].get('mimeType') == 'image/png':
                im.save(buf, 'PNG', optimize=True)
            else:
                im.convert('RGB').save(buf, 'JPEG', quality=92)
            data = buf.getvalue()
        while len(out) % 4:
            out.append(0)
        view['byteOffset'] = len(out)
        view['byteLength'] = len(data)
        out += data
    while len(out) % 4:
        out.append(0)
    j['buffers'][0]['byteLength'] = len(out)
    js = json.dumps(j, separators=(',', ':')).encode()
    while len(js) % 4:
        js += b' '
    total = 12 + 8 + len(js) + 8 + len(out)
    with open(dst, 'wb') as w:
        w.write(struct.pack('<III', 0x46546C67, 2, total))
        w.write(struct.pack('<II', len(js), 0x4E4F534A) + js)
        w.write(struct.pack('<II', len(out), 0x004E4942) + bytes(out))

for path in sys.argv[1:]:
    shrink(path, path)
    import os
    print(path, os.path.getsize(path))
