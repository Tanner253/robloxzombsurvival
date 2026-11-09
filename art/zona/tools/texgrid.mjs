// Export each baseColor texture of a GLB as PNG with a UV grid (every 0.1, labelled) for finding stamped text.
// usage: node texgrid.mjs in.glb outPrefix [size=1024] [u0:u1:v0:v1 crop, then grid every 0.02]
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import sharp from 'sharp';

const [, , input, prefix, sArg, cropArg] = process.argv;
const S = +(sArg || 1024);
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(input);
const seen = new Set();
for (const m of doc.getRoot().listMaterials()) {
	const t = m.getBaseColorTexture();
	if (!t || seen.has(t)) continue;
	seen.add(t);
	let [u0, u1, v0, v1] = cropArg ? cropArg.split(':').map(Number) : [0, 1, 0, 1];
	const meta = await sharp(Buffer.from(t.getImage())).metadata();
	const img = sharp(Buffer.from(t.getImage())).extract({ left: Math.round(u0 * meta.width), top: Math.round(v0 * meta.height), width: Math.round((u1 - u0) * meta.width), height: Math.round((v1 - v0) * meta.height) }).resize(S, S, { fit: 'fill' });
	const step = cropArg ? 0.02 : 0.1;
	let svg = `<svg width="${S}" height="${S}" xmlns="http://www.w3.org/2000/svg">`;
	for (let g = Math.ceil(u0 / step) * step; g <= u1 + 1e-9; g += step) { const x = ((g - u0) / (u1 - u0)) * S; svg += `<line x1="${x}" y1="0" x2="${x}" y2="${S}" stroke="#ff00ff" stroke-width="1" opacity="0.6"/><text x="${x + 2}" y="12" font-size="11" fill="#ff00ff">${g.toFixed(2)}</text>`; }
	for (let g = Math.ceil(v0 / step) * step; g <= v1 + 1e-9; g += step) { const y = ((g - v0) / (v1 - v0)) * S; svg += `<line x1="0" y1="${y}" x2="${S}" y2="${y}" stroke="#00ffff" stroke-width="1" opacity="0.6"/><text x="2" y="${y - 2}" font-size="11" fill="#00ffff">${g.toFixed(2)}</text>`; }
	svg += '</svg>';
	const out = `${prefix}_${m.getName().replace(/[^\w]/g, '_')}.png`;
	await img.composite([{ input: Buffer.from(svg) }]).png().toFile(out);
	console.log(out, `${meta.width}x${meta.height}`);
}
