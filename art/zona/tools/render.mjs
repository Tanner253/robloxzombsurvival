// Tiny software renderer for a sanity look at a gun GLB: orthographic panels, textured with baseColor (nearest),
// lambert-shaded. Panels: right (camera +Z), left (camera -Z, mirrored), top (camera +Y), stacked.
// usage: node render.mjs in.glb out.png [width] [views=right,left,top] [xmin:xmax (model units, for close-ups)] [ymin:ymax]
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { getBounds } from '@gltf-transform/functions';
import sharp from 'sharp';

const [, , input, output, wArg, viewArg, xArg, yArg] = process.argv;
const W = +(wArg || 1400);
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(input);
const root = doc.getRoot(), scene = root.listScenes()[0];
const b = getBounds(scene);
const texCache = new Map();
const texOf = async (t) => {
	if (!t) return null;
	if (!texCache.has(t)) {
		const { data, info } = await sharp(Buffer.from(t.getImage())).removeAlpha().raw().toBuffer({ resolveWithObject: true });
		texCache.set(t, { data, w: info.width, h: info.height, c: info.channels });
	}
	return texCache.get(t);
};
const tris = [];
for (const n of root.listNodes()) {
	const mesh = n.getMesh();
	if (!mesh) continue;
	const M = n.getWorldMatrix();
	const pt = (p) => [0, 1, 2].map((r) => M[r] * p[0] + M[4 + r] * p[1] + M[8 + r] * p[2] + M[12 + r]);
	for (const p of mesh.listPrimitives()) {
		const pos = p.getAttribute('POSITION'), uv = p.getAttribute('TEXCOORD_0'), idx = p.getIndices();
		const mat = p.getMaterial();
		const tex = await texOf(mat?.getBaseColorTexture());
		const fac = mat?.getBaseColorFactor() ?? [1, 1, 1, 1];
		const cnt = idx ? idx.getCount() : pos.getCount();
		const v = [], u = [];
		for (let i = 0; i < cnt; i += 3) {
			const ids = [0, 1, 2].map((k) => (idx ? idx.getScalar(i + k) : i + k));
			tris.push({ P: ids.map((j) => pt(pos.getElement(j, v))), UV: uv ? ids.map((j) => uv.getElement(j, u).slice()) : null, tex, fac, mat: mat?.getName() });
		}
	}
}
const [x0, x1] = xArg ? xArg.split(':').map(Number) : [b.min[0], b.max[0]];
const [y0, y1] = yArg ? yArg.split(':').map(Number) : [b.min[1], b.max[1]];
const s = (W - 40) / (x1 - x0);
const panels = (viewArg || 'right,left,top').split(',');
const hOf = (v) => Math.ceil((v === 'top' ? b.max[2] - b.min[2] : y1 - y0) * s) + 40;
const H = panels.reduce((a, v) => a + hOf(v), 0);
const img = Buffer.alloc(W * H * 3, 235);
const zb = new Float32Array(W * H).fill(-Infinity);
// (PICK="x,y;x,y": print the material and UV under those pixels, to place paint rects)
const UVB = new Float32Array(W * H * 2).fill(-1), MB = new Array(W * H);
const L = [0.4, 0.7, 0.6].map((x) => x / Math.hypot(0.4, 0.7, 0.6));
let top0 = 0;
for (const v of panels) {
	const off = top0;
	const view = {
		right: (p) => [20 + (p[0] - x0) * s, off + 20 + (y1 - p[1]) * s, p[2]],
		left: (p) => [20 + (x1 - p[0]) * s, off + 20 + (y1 - p[1]) * s, -p[2]],
		top: (p) => [20 + (p[0] - x0) * s, off + 20 + (p[2] - b.min[2]) * s, p[1]],
	}[v];
	const yLo = off, yHi = off + hOf(v) - 1;
	for (const t of tris) {
		const S = t.P.map(view);
		const e1 = t.P[1].map((x, k) => x - t.P[0][k]), e2 = t.P[2].map((x, k) => x - t.P[0][k]);
		let nrm = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]];
		const nl = Math.hypot(...nrm) || 1;
		nrm = nrm.map((x) => x / nl);
		const shade = 0.3 + 0.7 * Math.abs(nrm[0] * L[0] + nrm[1] * L[1] + nrm[2] * L[2]);
		const minx = Math.max(0, Math.floor(Math.min(S[0][0], S[1][0], S[2][0]))), maxx = Math.min(W - 1, Math.ceil(Math.max(S[0][0], S[1][0], S[2][0])));
		const miny = Math.max(yLo, Math.floor(Math.min(S[0][1], S[1][1], S[2][1]))), maxy = Math.min(yHi, Math.ceil(Math.max(S[0][1], S[1][1], S[2][1])));
		if (minx > maxx || miny > maxy) continue;
		const area = (S[1][0] - S[0][0]) * (S[2][1] - S[0][1]) - (S[2][0] - S[0][0]) * (S[1][1] - S[0][1]);
		if (Math.abs(area) < 1e-9) continue;
		for (let y = miny; y <= maxy; y++) for (let x = minx; x <= maxx; x++) {
			const px = x + 0.5, py = y + 0.5;
			const w0 = ((S[1][0] - px) * (S[2][1] - py) - (S[2][0] - px) * (S[1][1] - py)) / area;
			const w1 = ((S[2][0] - px) * (S[0][1] - py) - (S[0][0] - px) * (S[2][1] - py)) / area;
			const w2 = 1 - w0 - w1;
			if (w0 < 0 || w1 < 0 || w2 < 0) continue;
			const z = w0 * S[0][2] + w1 * S[1][2] + w2 * S[2][2];
			const o = y * W + x;
			if (z <= zb[o]) continue;
			zb[o] = z;
			if (t.UV) { UVB[o * 2] = w0 * t.UV[0][0] + w1 * t.UV[1][0] + w2 * t.UV[2][0]; UVB[o * 2 + 1] = w0 * t.UV[0][1] + w1 * t.UV[1][1] + w2 * t.UV[2][1]; MB[o] = t.mat; }
			let col = t.fac.slice(0, 3).map((c) => Math.pow(c, 1 / 2.2) * 255);
			if (t.tex && t.UV) {
				const uu = w0 * t.UV[0][0] + w1 * t.UV[1][0] + w2 * t.UV[2][0], vv = w0 * t.UV[0][1] + w1 * t.UV[1][1] + w2 * t.UV[2][1];
				const tx = Math.min(t.tex.w - 1, Math.max(0, Math.floor((uu - Math.floor(uu)) * t.tex.w))), ty = Math.min(t.tex.h - 1, Math.max(0, Math.floor((vv - Math.floor(vv)) * t.tex.h)));
				const ti = (ty * t.tex.w + tx) * t.tex.c;
				col = [0, 1, 2].map((k) => t.tex.data[ti + k] * Math.pow(t.fac[k], 1 / 2.2));
			}
			for (let k = 0; k < 3; k++) img[o * 3 + k] = Math.min(255, Math.round(col[k] * shade));
		}
	}
	top0 += hOf(v);
}
for (const pr of (process.env.PICK || '').split(';').filter(Boolean)) { const [x, y] = pr.split(',').map(Number); const o = y * W + x; console.log(`pick ${x},${y}: ${MB[o]} uv ${UVB[o * 2].toFixed(4)},${UVB[o * 2 + 1].toFixed(4)}`); }
await sharp(img, { raw: { width: W, height: H, channels: 3 } }).png().toFile(output);
console.log(`rendered ${output} ${W}x${H}, ${tris.length} tris, panels ${panels.join(',')}`);
