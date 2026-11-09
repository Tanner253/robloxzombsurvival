// Verify a model GLB: per node world bbox (cm), triangles, material textures; and every connected island of
// triangles (joined through shared or coincident corners) checked against the rest of the model: the nearest
// vertex of anything else. Islands more than 2 cm from everything else are flagged FLOATING.
// usage: node verify.mjs file.glb
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { getBounds } from '@gltf-transform/functions';

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(process.argv[2]);
const root = doc.getRoot(), scene = root.listScenes()[0];
const pt = (m, p) => [0, 1, 2].map((r) => m[r] * p[0] + m[4 + r] * p[1] + m[8 + r] * p[2] + m[12 + r]);
const items = [];
const verts = []; // [x, y, z, islandId]
const islands = []; // { node, tris, lo, hi }
let total = 0;
for (const n of root.listNodes()) {
	const mesh = n.getMesh();
	if (!mesh) continue;
	const W = n.getWorldMatrix();
	let tris = 0;
	const mats = new Set();
	const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
	// islands across the node's primitives, by position
	const keyOf = (q) => q.map((x) => Math.round(x * 1e5)).join(',');
	const parent = new Map();
	const find = (x) => { while (parent.get(x) !== x) { parent.set(x, parent.get(parent.get(x))); x = parent.get(x); } return x; };
	const unite = (a, b) => { a = find(a); b = find(b); if (a !== b) parent.set(a, b); };
	const pts = new Map();
	const triKeys = [];
	const v = [];
	for (const p of mesh.listPrimitives()) {
		const pos = p.getAttribute('POSITION'), idx = p.getIndices();
		const keys = [];
		for (let i = 0; i < pos.getCount(); i++) { const q = pt(W, pos.getElement(i, v)); const k = keyOf(q); keys.push(k); if (!parent.has(k)) { parent.set(k, k); pts.set(k, q); } for (let a = 0; a < 3; a++) { lo[a] = Math.min(lo[a], q[a]); hi[a] = Math.max(hi[a], q[a]); } }
		const cnt = idx ? idx.getCount() : pos.getCount();
		for (let t = 0; t < cnt; t += 3) { const k3 = [0, 1, 2].map((j) => keys[idx ? idx.getScalar(t + j) : t + j]); unite(k3[0], k3[1]); unite(k3[0], k3[2]); triKeys.push(k3); }
		tris += cnt / 3;
		const m = p.getMaterial();
		mats.add(`${m?.getName()}[${m?.getBaseColorTexture() ? 'base' : 'NOBASE'}${m?.getNormalTexture() ? '+nrm' : ''}${m?.getMetallicRoughnessTexture() ? '+mr' : ''}${m?.getAlphaMode() !== 'OPAQUE' ? '+' + m?.getAlphaMode() : ''}]`);
		if (p.listSemantics().some((s) => /JOINTS|WEIGHTS/.test(s))) mats.add('HAS_SKIN_ATTRS');
	}
	const idOf = new Map();
	for (const k of parent.keys()) { const r = find(k); if (!idOf.has(r)) { idOf.set(r, islands.length); islands.push({ node: n.getName(), tris: 0, lo: [Infinity, Infinity, Infinity], hi: [-Infinity, -Infinity, -Infinity] }); } }
	for (const k3 of triKeys) {
		const id = idOf.get(find(k3[0]));
		islands[id].tris++;
		// (the surface sampled every 8 mm, so a big decimated triangle still counts as near)
		const [a, b2, c] = k3.map((k) => pts.get(k));
		const n = Math.min(40, Math.ceil(Math.max(Math.hypot(...a.map((x, i) => x - b2[i])), Math.hypot(...a.map((x, i) => x - c[i])), Math.hypot(...b2.map((x, i) => x - c[i]))) / 0.008));
		if (n > 1) for (let i = 0; i <= n; i++) for (let j = 0; i + j <= n; j++) { const w1 = i / n, w2 = j / n, w0 = 1 - w1 - w2; verts.push([0, 1, 2].map((q) => w0 * a[q] + w1 * b2[q] + w2 * c[q]).concat([id])); }
	}
	for (const [k, q] of pts) { const id = idOf.get(find(k)); verts.push([q[0], q[1], q[2], id]); const I = islands[id]; for (let a = 0; a < 3; a++) { I.lo[a] = Math.min(I.lo[a], q[a]); I.hi[a] = Math.max(I.hi[a], q[a]); } }
	total += tris;
	items.push({ name: n.getName(), tris, mats: [...mats].join(' '), lo, hi, islands: idOf.size });
}
const CELL = 0.01;
const grid = new Map();
for (const q of verts) { const k = q.slice(0, 3).map((x) => Math.floor(x / CELL)).join(','); if (!grid.has(k)) grid.set(k, []); grid.get(k).push(q); }
const byIsland = new Map();
for (const q of verts) { if (!byIsland.has(q[3])) byIsland.set(q[3], []); byIsland.get(q[3]).push(q); }
const floating = [];
for (const [id, qs] of byIsland) {
	if (islands.length < 2) break;
	let best = Infinity;
	const R = 2;
	for (const q of qs) {
		const c = q.slice(0, 3).map((x) => Math.floor(x / CELL));
		for (let dx = -R; dx <= R && best > 0.002; dx++) for (let dy = -R; dy <= R; dy++) for (let dz = -R; dz <= R; dz++) {
			const cell = grid.get(`${c[0] + dx},${c[1] + dy},${c[2] + dz}`);
			if (cell) for (const p of cell) if (p[3] !== id) { const d = Math.hypot(p[0] - q[0], p[1] - q[1], p[2] - q[2]); if (d < best) best = d; }
		}
		if (best < 0.002) break;
	}
	if (best > 0.02) floating.push({ ...islands[id], gap: best });
}
const b = getBounds(scene);
const cm = (a) => a.map((x) => (x * 100).toFixed(1)).join(',');
console.log(`overall size (m): ${b.max.map((v, k) => (v - b.min[k]).toFixed(3)).join(' x ')}   total tris ${total}   nodes ${items.length}   islands ${islands.length}`);
for (const it of items) console.log(`  ${it.name.padEnd(14)} ${String(it.tris).padStart(6)} tris ${String(it.islands).padStart(4)} isl  box cm [${cm(it.lo)}]..[${cm(it.hi)}]  ${it.mats}`);
for (const f of floating) console.log(`  FLOATING island in ${f.node}: ${f.tris} tris, box cm [${cm(f.lo)}]..[${cm(f.hi)}], nearest other ${f.gap === Infinity ? '>2' : (f.gap * 100).toFixed(1)} cm`);
if (!floating.length) console.log('  no floating islands (all within 2 cm of the rest)');
console.log('textures:', root.listTextures().map((t) => `${t.getMimeType().split('/')[1]} ${t.getSize()?.join('x')}`).join(', '));
console.log('extensionsUsed:', root.listExtensionsUsed().map((e) => e.extensionName).join(', ') || '-');
