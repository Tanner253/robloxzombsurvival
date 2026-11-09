// Per lead-joint vertex counts and stood (default-pose) bounding boxes for the skinned meshes of a glTF.
// usage: node joints.mjs in.gltf "<mesh name substring regex>"
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';

const [, , input, meshRe] = process.argv;
const re = new RegExp(meshRe || '.');
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(input);
const mul = (a, b) => { const o = new Array(16).fill(0); for (let c = 0; c < 4; c++) for (let r = 0; r < 4; r++) for (let k = 0; k < 4; k++) o[c * 4 + r] += a[k * 4 + r] * b[c * 4 + k]; return o; };
const point = (m, p) => [0, 1, 2].map((r) => m[r] * p[0] + m[4 + r] * p[1] + m[8 + r] * p[2] + m[12 + r]);
for (const n of doc.getRoot().listNodes()) {
	if (!n.getSkin() || !re.test(n.getMesh().getName())) continue;
	const skin = n.getSkin(), joints = skin.listJoints(), ibm = skin.getInverseBindMatrices();
	const J = joints.map((j, k) => mul(j.getWorldMatrix(), ibm.getElement(k, [])));
	const stats = new Map();
	for (const prim of n.getMesh().listPrimitives()) {
		const pos = prim.getAttribute('POSITION'), ji = prim.getAttribute('JOINTS_0'), jw = prim.getAttribute('WEIGHTS_0');
		const a = [], w = [], p = [];
		for (let i = 0; i < pos.getCount(); i++) {
			ji.getElement(i, a); jw.getElement(i, w);
			let best = 0; for (let k = 1; k < 4; k++) if (w[k] > w[best]) best = k;
			const name = joints[a[best]].getName();
			const q = point(J[a[best]], pos.getElement(i, p));
			if (!stats.has(name)) stats.set(name, { n: 0, lo: [Infinity, Infinity, Infinity], hi: [-Infinity, -Infinity, -Infinity] });
			const s = stats.get(name); s.n++;
			for (let k = 0; k < 3; k++) { s.lo[k] = Math.min(s.lo[k], q[k]); s.hi[k] = Math.max(s.hi[k], q[k]); }
		}
	}
	console.log(`mesh ${n.getMesh().getName()}`);
	for (const [name, s] of stats) console.log(`  ${name.padEnd(36)} ${String(s.n).padStart(6)}v  lo ${s.lo.map((x) => x.toFixed(3))}  hi ${s.hi.map((x) => x.toFixed(3))}`);
}
