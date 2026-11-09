// Stack PNGs vertically into one sheet.  usage: node sheet.mjs out.png a.png b.png ...
import sharp from 'sharp';
const [, , out, ...ins] = process.argv;
const metas = await Promise.all(ins.map((f) => sharp(f).metadata()));
const W = Math.max(...metas.map((m) => m.width)), H = metas.reduce((a, m) => a + m.height, 0);
let y = 0;
const comp = ins.map((f, i) => { const c = { input: f, top: y, left: 0 }; y += metas[i].height; return c; });
await sharp({ create: { width: W, height: H, channels: 3, background: '#ebebeb' } }).composite(comp).png().toFile(out);
console.log(out, W, H);
