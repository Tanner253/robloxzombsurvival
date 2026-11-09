// Build a clean "gun alone" GLB from a Zona FPS weapon pack, for Roblox import.
// A port of the gun-alone half of Zona's scripts/weapon-packs.mjs (processWeaponPack), driven by its own
// WEAPON_PACKS config: the skinned gun is stood on its skeleton (joint world x inverse bind, the pose the
// skeleton was bound in), each triangle goes to the piece its first corner's lead joint maps to, pieces
// mapped to null (the spare / reload magazines) are dropped, rigid `parts` are baked in place, and the result
// is straightened (`trim`) into gun space: +X muzzle, +Y up, +Z right, metres, centred on its box.
// Then: bipod legs folded along the barrel, flat-colour materials given a real baseColor texture (so Roblox
// imports a ColorMap), unsupported material extensions removed, textures to JPEG at <= tex px, weld,
// simplify(0.15), prune, dedup.
//
// usage: node build_v2.mjs <gun> <out.glb> [texSize]
import fs from 'node:fs';
import path from 'node:path';
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { prune, weld, dedup, transformMesh, getBounds, textureCompress, simplify, simplifyPrimitive, compactPrimitive } from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';
import sharp from 'sharp';
import { WEAPON_PACKS } from 'file:///C:/Users/perci/source/repos/Zona/scripts/assets.config.mjs';

const SRC = 'C:/Users/perci/source/repos/Zona/assets-src/models';
// our gun name -> Zona pack id, pieces to leave out, bipod legs to fold
const GUNS = {
	ak74m: { pack: 'ak' },
	aks74u: { pack: 'aks74u' },
	mp7a1: { pack: 'mp7a1', drop: ['sight', 'silencer'] },
	scorpion: { pack: 'scorpion' },
	shotgun_set: { pack: 'db12' },
	barrett: {
		pack: 'barrett',
		fold: ['bipodR', 'bipodL'],
		// (v3: the folded carry handle's grip and arm, which hang beside the receiver, and the rear monopod's post
		// and foot, cut as whole islands by the joint that leads them; the handle's hinge mount on top stays)
		cut: (I) => (I.joint === 'M82 Carrying Handle_010' && I.lo[1] < 0.05) || I.joint === 'M82 Stock Adjustment Pin_02',
	},
	benelli_m3: { pack: 'benelli_m3', drop: ['sight', 'silencer'] },
	// batch 3: the marksman rifle (silencer kept), the compact 9A-91 (silencer off), the earlier four rebuilt
	sniper: { pack: 'sniper' },
	'9a91': { pack: 'a91', drop: ['silencer', 'bullet'] },
	ar15: { pack: 'ar15', drop: ['silencer', 'sight', 'foregrip', 'light'], dropNodes: ['Bolt', 'Springs', 'Hammer', 'Firing pin', 'Bolt carrier key', 'Disconnector'] },
	desert_eagle: { pack: 'desert_eagle' },
	pistol_m9: { pack: 'm9' },
	bolt_action_rifle_7_62: { pack: 'mosin9130', drop: ['bullet'] },
	// melee: tip / head along +Y
	knife_animated: { pack: 'knife', tipUp: true },
	pitchfork: { pack: 'pitchfork', tipUp: true },
	baseball_bat: { plain: { dir: 'baseball_bat', file: 'baseball_bat_1k.gltf' } },
	hatchet: { plain: { dir: 'hatchet', file: 'hatchet_1k.gltf' } },
};

const [, , gun, output, texArg] = process.argv;
const G = GUNS[gun];
if (!G) throw new Error(`unknown gun ${gun}; one of ${Object.keys(GUNS).join(', ')}`);
// (`plain`: a still model with no pack settings, every mesh kept as it stands, in its own axes and size)
const cfg = G.plain ? { ...G.plain, scale: 1, forward: [1, 0, 0], up: [0, 1, 0] } : WEAPON_PACKS[G.pack];
if (cfg.level) throw new Error('level not ported');
const TEX = +(texArg || 1024);
const BUDGET = +(process.env.BUDGET || G.budget || 8000);
const drop = new Set(G.drop ?? []);

// ---- 4x4 column-major matrix helpers (as in weapon-packs.mjs)
const mul = (a, b) => {
	const o = new Array(16).fill(0);
	for (let c = 0; c < 4; c++) for (let r = 0; r < 4; r++) for (let k = 0; k < 4; k++) o[c * 4 + r] += a[k * 4 + r] * b[c * 4 + k];
	return o;
};
const move = (x, y, z) => [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, z, 1];
const scaleBy = (s) => [s, 0, 0, 0, 0, s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1];
const point = (m, p) => [0, 1, 2].map((r) => m[r] * p[0] + m[4 + r] * p[1] + m[8 + r] * p[2] + m[12 + r]);
const turn = (m, v) => [0, 1, 2].map((r) => m[r] * v[0] + m[4 + r] * v[1] + m[8 + r] * v[2]);
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const unit = (v) => v.map((x) => x / Math.hypot(...v));

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(path.join(SRC, cfg.dir, cfg.file));
const root = doc.getRoot(), scene = root.listScenes()[0];
const extras = root.getAsset().extras || {};
for (const [end, name] of Object.entries(cfg.rename ?? {})) for (const n of root.listNodes()) if (new RegExp(end).test(n.getName())) n.setName(name);
await doc.transform(prune({ keepLeaves: true, keepAttributes: true }), weld());

// (a rigid gun: every animated node put where the first animation has it on its first frame)
if (!cfg.skinned) {
	const anim = root.listAnimations()[0];
	if (anim) for (const ch of anim.listChannels()) {
		const node = ch.getTargetNode(), out = ch.getSampler()?.getOutput();
		if (!node || !out) continue;
		const v = out.getElement(0, []);
		if (ch.getTargetPath() === 'translation') node.setTranslation(v);
		else if (ch.getTargetPath() === 'rotation') node.setRotation(v);
		else if (ch.getTargetPath() === 'scale') node.setScale(v);
	}
}

/** A skinned shape stood on its skeleton as it is now: positions, normals, tangents, each point's lead joint. */
function standSkin(node, meshScale = 1) {
	const skin = node.getSkin(), joints = skin.listJoints(), ibm = skin.getInverseBindMatrices();
	const J = joints.map((j, k) => mul(j.getWorldMatrix(), ibm.getElement(k, [])));
	return node.getMesh().listPrimitives().map((prim) => {
		const pos = prim.getAttribute('POSITION'), nor = prim.getAttribute('NORMAL'), tan = prim.getAttribute('TANGENT');
		const ji = prim.getAttribute('JOINTS_0'), jw = prim.getAttribute('WEIGHTS_0');
		const n = pos.getCount();
		const P = new Float32Array(n * 3), N = nor ? new Float32Array(n * 3) : null, T = tan ? new Float32Array(n * 4) : null;
		const lead = new Array(n);
		const a = [], b = [], w = [], q = [];
		for (let i = 0; i < n; i++) {
			ji.getElement(i, a);
			jw.getElement(i, w);
			const m = new Array(16).fill(0);
			let best = 0;
			for (let k = 0; k < 4; k++) {
				if (w[k] > w[best]) best = k;
				if (w[k] > 0) for (let e = 0; e < 16; e++) m[e] += J[a[k]][e] * w[k];
			}
			lead[i] = joints[a[best]].getName();
			P.set(point(m, pos.getElement(i, b).map((x) => x * meshScale)), i * 3);
			if (N) {
				const v = turn(m, nor.getElement(i, b)), l = (Math.hypot(...v) || 1) * Math.sign(meshScale);
				N.set(v.map((x) => x / l), i * 3);
			}
			if (T) {
				tan.getElement(i, q);
				const v = turn(m, q), l = (Math.hypot(...v) || 1) * Math.sign(meshScale);
				T.set([v[0] / l, v[1] / l, v[2] / l, q[3]], i * 4);
			}
		}
		return { prim, P, N, T, lead, flip: meshScale < 0 };
	});
}

const partOf = (node) => {
	for (let n = node; n; n = n.getParentNode()) if (n.getName() in (cfg.parts ?? {})) return (G.dropNodes ?? []).includes(n.getName()) ? null : cfg.parts[n.getName()];
	return null;
};
const pieces = [];
const shapes = cfg.skinned ? [].concat(cfg.skinned.mesh) : [];
const stood = cfg.skinned
	? root.listNodes().filter((n) => n.getSkin() && shapes.some((m) => n.getMesh()?.getName().includes(m))).flatMap((n) => standSkin(n, cfg.meshScale ?? 1))
	: null;
if (stood) for (const s of stood) pieces.push({ skin: s, of: s.lead.map((j) => { const p = j in cfg.skinned.joints ? cfg.skinned.joints[j] : cfg.skinned.rest; return p && !drop.has(p) ? p : null; }) });
if (!stood || cfg.parts) {
	for (const n of root.listNodes()) {
		if (!n.getMesh() || n.getSkin()) continue;
		const piece = G.plain ? (n.getName() || 'base').replace(/[^\w]/g, '_') : partOf(n);
		if (piece) pieces.push({ node: n, piece, world: n.getWorldMatrix(), dropped: drop.has(piece) });
	}
}
if (!pieces.length) throw new Error('no pieces found');
// (a dropped rigid piece stays long enough to be measured: `put` lays another piece where it was)
const allPieces = pieces.slice();
for (let i = pieces.length - 1; i >= 0; i--) if (pieces[i].dropped) pieces.splice(i, 1);

// pack-space box of what is kept
const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
const grow = (p) => { for (let k = 0; k < 3; k++) { lo[k] = Math.min(lo[k], p[k]); hi[k] = Math.max(hi[k], p[k]); } };
const eachPoint = (pc, fn) => {
	if (pc.skin) { for (let i = 0; i < pc.of.length; i++) if (pc.of[i]) fn([pc.skin.P[i * 3], pc.skin.P[i * 3 + 1], pc.skin.P[i * 3 + 2]], pc.of[i]); }
	else { const v = []; for (const prim of pc.node.getMesh().listPrimitives()) { const pos = prim.getAttribute('POSITION'); for (let i = 0; i < pos.getCount(); i++) fn(point(pc.world, pos.getElement(i, v)), pc.piece); } }
};
for (const pc of pieces) eachPoint(pc, grow);
const size = hi.map((v, k) => v - lo[k]);
const order = [0, 1, 2].sort((a, b) => size[b] - size[a]);
const f = cfg.forward, u = cfg.up, r = cross(f, u);
const s = cfg.scale ?? cfg.length / size[order[0]];
let B = mul(scaleBy(s), [f[0], u[0], r[0], 0, f[1], u[1], r[1], 0, f[2], u[2], r[2], 0, 0, 0, 0, 1]);
if (cfg.trim) {
	const t = (deg) => Math.tan(((deg ?? 0) * Math.PI) / 180);
	const e1 = unit([1, t(cfg.trim.pitch), t(cfg.trim.yaw)]);
	const b = [0, t(cfg.trim.roll), 1];
	const k = b[0] * e1[0] + b[1] * e1[1] + b[2] * e1[2];
	const e3 = unit(b.map((v, i) => v - k * e1[i]));
	const e2 = cross(e3, e1);
	B = mul([e1[0], e2[0], e3[0], 0, e1[1], e2[1], e3[1], 0, e1[2], e2[2], e3[2], 0, 0, 0, 0, 1], B);
}
// gun-space box (for aloneLength)
const glo = [Infinity, Infinity, Infinity], ghi = [-Infinity, -Infinity, -Infinity];
for (const pc of pieces) eachPoint(pc, (p) => { const q = point(B, p); for (let k = 0; k < 3; k++) { glo[k] = Math.min(glo[k], q[k]); ghi[k] = Math.max(ghi[k], q[k]); } });
const own = cfg.aloneLength ? cfg.aloneLength / Math.max(...[0, 1, 2].map((k) => ghi[k] - glo[k])) : 1;
// (`tipUp`, melee: the gun-space +X (its point) turned to +Y)
const Rz = G.tipUp ? [0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1] : scaleBy(1);
const A = mul(Rz, mul(scaleBy(own), B));
const R = mul(Rz, [B[0] / s, B[1] / s, B[2] / s, 0, B[4] / s, B[5] / s, B[6] / s, 0, B[8] / s, B[9] / s, B[10] / s, 0, 0, 0, 0, 1]);
// `put` (Zona's): a piece drawn lying beside the gun for show (the AR-15's brake) laid where the piece that takes its
// place is (its suppressor): back end on back end, middles together
const shift = new Map();
for (const [piece, onto] of Object.entries(cfg.put ?? {})) {
	const box = (name) => {
		const b = { min: [Infinity, Infinity, Infinity], max: [-Infinity, -Infinity, -Infinity] };
		for (const pc of allPieces) if (!pc.skin && pc.piece === name) eachPoint(pc, (p) => { const q = point(A, p); for (let k = 0; k < 3; k++) { b.min[k] = Math.min(b.min[k], q[k]); b.max[k] = Math.max(b.max[k], q[k]); } });
		return b;
	};
	const a = box(piece), b = box(onto);
	if (!isFinite(a.min[0]) || !isFinite(b.min[0])) throw new Error(`put: ${piece} or ${onto} not found`);
	shift.set(piece, [b.min[0] - a.min[0], (b.min[1] + b.max[1] - a.min[1] - a.max[1]) / 2, (b.min[2] + b.max[2] - a.min[2] - a.max[2]) / 2]);
	console.log(`  put ${piece} where ${onto} was: moved ${shift.get(piece).map((x) => x.toFixed(3))}`);
}

const buffer = root.listBuffers()[0];
const acc = (type, array) => doc.createAccessor().setType(type).setArray(array).setBuffer(buffer);
const made = new Map();
const nodes = [];
const put = (name, mesh) => {
	mesh.setName(name);
	const n = doc.createNode(made.has(name) ? `${name}_${made.get(name)}` : name).setMesh(mesh);
	made.set(name, (made.get(name) ?? 1) + 1);
	nodes.push(n);
	return n;
};
for (const pc of pieces) {
	if (pc.node) {
		// (deep copy: a mesh drawn by more than one node is moved once per node)
		const mesh = doc.createMesh(pc.node.getMesh().getName());
		for (const p0 of pc.node.getMesh().listPrimitives()) {
			const p = p0.clone();
			for (const sem of p.listSemantics()) p.setAttribute(sem, /^(JOINTS|WEIGHTS)_/.test(sem) ? null : p0.getAttribute(sem).clone());
			if (p0.getIndices()) p.setIndices(p0.getIndices().clone());
			mesh.addPrimitive(p);
		}
		const to = mul(A, pc.world);
		transformMesh(mesh, shift.has(pc.piece) ? mul(move(...shift.get(pc.piece)), to) : to);
		put(pc.piece, mesh);
		continue;
	}
	const { prim, P, N, T } = pc.skin;
	const idx = prim.getIndices(), uv = prim.getAttribute('TEXCOORD_0');
	const count = idx ? idx.getCount() : P.length / 3;
	const byPiece = new Map();
	for (let t = 0; t < count; t += 3) {
		const tri = [0, 1, 2].map((k) => (idx ? idx.getScalar(t + k) : t + k));
		if (pc.skin.flip) [tri[1], tri[2]] = [tri[2], tri[1]];
		const piece = pc.of[tri[0]];
		if (!piece) continue;
		if (!byPiece.has(piece)) byPiece.set(piece, { remap: new Map(), order: [], index: [] });
		const b = byPiece.get(piece);
		for (const v of tri) {
			if (!b.remap.has(v)) { b.remap.set(v, b.order.length); b.order.push(v); }
			b.index.push(b.remap.get(v));
		}
	}
	// (islands: connected triangle groups, joined through shared corners and coincident positions; printed with
	// ISLANDS=1, and those G.cut says are dropped)
	if (process.env.ISLANDS || G.cut) for (const [piece, b] of byPiece) {
		const n = b.order.length;
		const parent = Int32Array.from({ length: n }, (_, i) => i);
		const find = (x) => { while (parent[x] !== x) { parent[x] = parent[parent[x]]; x = parent[x]; } return x; };
		const unite = (a, c) => { a = find(a); c = find(c); if (a !== c) parent[a] = c; };
		const byPos = new Map();
		b.order.forEach((v, i) => { const k = [0, 1, 2].map((k2) => Math.round(P[v * 3 + k2] * 1e5)).join(','); if (byPos.has(k)) unite(i, byPos.get(k)); else byPos.set(k, i); });
		for (let t = 0; t < b.index.length; t += 3) { unite(b.index[t], b.index[t + 1]); unite(b.index[t], b.index[t + 2]); }
		const isl = new Map();
		for (let t = 0; t < b.index.length; t += 3) {
			const id = find(b.index[t]);
			if (!isl.has(id)) isl.set(id, { id, tris: 0, lo: [Infinity, Infinity, Infinity], hi: [-Infinity, -Infinity, -Infinity], joints: new Map() });
			const I = isl.get(id);
			I.tris++;
			for (let k = 0; k < 3; k++) {
				const v = b.order[b.index[t + k]];
				const q = point(A, [P[v * 3], P[v * 3 + 1], P[v * 3 + 2]]);
				for (let a = 0; a < 3; a++) { I.lo[a] = Math.min(I.lo[a], q[a]); I.hi[a] = Math.max(I.hi[a], q[a]); }
				const j = pc.skin.lead[v];
				I.joints.set(j, (I.joints.get(j) ?? 0) + 1);
			}
		}
		const all = [...isl.values()].map((I) => ({ ...I, joint: [...I.joints].sort((x, y) => y[1] - x[1])[0][0] }));
		const cut = new Set(all.filter((I) => G.cut?.(I, piece, prim.getMaterial()?.getName())).map((I) => I.id));
		if (process.env.ISLANDS) {
			console.log(`  islands of ${piece} (${prim.getMaterial()?.getName()}): ${all.length}`);
			for (const I of all.sort((x, y) => y.tris - x.tris).slice(0, +process.env.ISLANDS || 40)) console.log(`    ${cut.has(I.id) ? 'CUT ' : '    '}${String(I.tris).padStart(5)} tris  ${I.joint.padEnd(32)} cm [${I.lo.map((x) => (x * 100).toFixed(1))}]..[${I.hi.map((x) => (x * 100).toFixed(1))}]`);
		}
		if (cut.size) {
			const keep = [];
			for (let t = 0; t < b.index.length; t += 3) if (!cut.has(find(b.index[t]))) keep.push(b.index[t], b.index[t + 1], b.index[t + 2]);
			console.log(`  cut ${cut.size} islands, ${(b.index.length - keep.length) / 3} tris, from ${piece}`);
			// (compacted: the cut islands' corners go too)
			const re = new Map(), order = [];
			b.index = keep.map((i) => { if (!re.has(i)) { re.set(i, order.length); order.push(b.order[i]); } return re.get(i); });
			b.order = order;
		}
	}
	for (const [piece, b] of byPiece) {
		const n = b.order.length;
		const p2 = new Float32Array(n * 3), n2 = N ? new Float32Array(n * 3) : null, t2 = T ? new Float32Array(n * 4) : null, uv2 = uv ? new Float32Array(n * 2) : null;
		const e = [];
		b.order.forEach((v, i) => {
			p2.set(point(A, [P[v * 3], P[v * 3 + 1], P[v * 3 + 2]]), i * 3);
			if (n2) n2.set(turn(R, [N[v * 3], N[v * 3 + 1], N[v * 3 + 2]]), i * 3);
			if (t2) t2.set([...turn(R, [T[v * 4], T[v * 4 + 1], T[v * 4 + 2]]), T[v * 4 + 3]], i * 4);
			if (uv2) uv2.set(uv.getElement(v, e).slice(0, 2), i * 2);
		});
		const np = doc.createPrimitive().setMaterial(prim.getMaterial()).setAttribute('POSITION', acc('VEC3', p2)).setIndices(acc('SCALAR', n > 65535 ? new Uint32Array(b.index) : new Uint16Array(b.index)));
		if (n2) np.setAttribute('NORMAL', acc('VEC3', n2));
		if (t2) np.setAttribute('TANGENT', acc('VEC4', t2));
		if (uv2) np.setAttribute('TEXCOORD_0', acc('VEC2', uv2));
		put(piece, doc.createMesh(piece).addPrimitive(np));
	}
}

// ---- bipod legs folded under the barrel, toward the muzzle (Zona's weapons.ts `hinged`)
const qRotate = (q, v) => {
	const [x, y, z, w] = q, [vx, vy, vz] = v;
	const tx = 2 * (y * vz - z * vy), ty = 2 * (z * vx - x * vz), tz = 2 * (x * vy - y * vx);
	return [vx + w * tx + (y * tz - z * ty), vy + w * ty + (z * tx - x * tz), vz + w * tz + (x * ty - y * tx)];
};
const fromUnitVectors = (a, b) => {
	const d = a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
	const c = cross(a, b);
	const q = [c[0], c[1], c[2], 1 + d];
	const l = Math.hypot(...q);
	return q.map((x) => x / l);
};
for (const leg of G.fold ?? []) {
	const legNodes = nodes.filter((n) => n.getName() === leg || n.getName().startsWith(`${leg}_`));
	const allPos = legNodes.flatMap((n) => n.getMesh().listPrimitives().map((p) => p.getAttribute('POSITION')));
	let ymin = Infinity, ymax = -Infinity;
	const v = [];
	for (const pos of allPos) for (let i = 0; i < pos.getCount(); i++) { pos.getElement(i, v); ymin = Math.min(ymin, v[1]); ymax = Math.max(ymax, v[1]); }
	const top = [0, 0, 0], foot = [0, 0, 0];
	let nt = 0, nf = 0;
	for (const pos of allPos) for (let i = 0; i < pos.getCount(); i++) {
		pos.getElement(i, v);
		if (v[1] > ymax - 0.012) { for (let k = 0; k < 3; k++) top[k] += v[k]; nt++; }
		if (v[1] < ymin + 0.012) { for (let k = 0; k < 3; k++) foot[k] += v[k]; nf++; }
	}
	for (let k = 0; k < 3; k++) { top[k] /= Math.max(1, nt); foot[k] /= Math.max(1, nf); }
	const q = fromUnitVectors(unit(foot.map((x, k) => x - top[k])), unit([1, -0.08, 0]));
	for (const n of legNodes) {
		for (const p of n.getMesh().listPrimitives()) {
			const P2 = p.getAttribute('POSITION'), N2 = p.getAttribute('NORMAL'), T2 = p.getAttribute('TANGENT');
			for (let i = 0; i < P2.getCount(); i++) { const r2 = qRotate(q, P2.getElement(i, v).map((x, k) => x - top[k])); P2.setElement(i, r2.map((x, k) => x + top[k])); }
			if (N2) for (let i = 0; i < N2.getCount(); i++) N2.setElement(i, qRotate(q, N2.getElement(i, v)));
			if (T2) for (let i = 0; i < T2.getCount(); i++) { const t4 = T2.getElement(i, [0, 0, 0, 0]); T2.setElement(i, [...qRotate(q, t4.slice(0, 3)), t4[3]]); }
		}
		console.log(`  folded ${n.getName()} about hinge ${top.map((x) => x.toFixed(3)).join(',')}`);
	}
}

// ---- keep only the new nodes
for (const a of root.listAnimations()) { for (const c of a.listChannels()) c.dispose(); for (const sm of a.listSamplers()) sm.dispose(); a.dispose(); }
for (const child of scene.listChildren()) scene.removeChild(child);
for (const n of root.listNodes()) if (!nodes.includes(n)) n.setMesh(null).setSkin(null);
for (const sk of root.listSkins()) sk.dispose();
for (const n of nodes) scene.addChild(n);
for (const a of root.listAccessors()) if (a.listParents().every((p) => p === root)) a.dispose();
await doc.transform(prune({ keepAttributes: true }));

// ---- centre on its box
{
	const b = getBounds(scene);
	const c = b.min.map((v, k) => -(v + b.max[k]) / 2);
	for (const n of nodes) transformMesh(n.getMesh(), move(...c));
}

// ---- one node per piece (base, mag, bolt...), its primitives joined by material: fewer MeshParts, and the
// simplifier works on whole shapes rather than dozens of screws
{
	const groups = new Map();
	for (const n of nodes) { const key = n.getName().replace(/_\d+$/, ''); if (!groups.has(key)) groups.set(key, []); groups.get(key).push(n); }
	const merged = [];
	for (const [key, ns] of groups) {
		const byMat = new Map();
		for (const n of ns) for (const p of n.getMesh().listPrimitives()) { const m = p.getMaterial() ?? null; if (!byMat.has(m)) byMat.set(m, []); byMat.get(m).push(p); }
		const mesh = doc.createMesh(key);
		for (const [m, ps] of byMat) {
			const has = (s) => ps.map((p) => !!p.getAttribute(s));
			const sems = [['POSITION', 3], ['NORMAL', 3], ['TEXCOORD_0', 2], ['TANGENT', 4]].filter(([s]) => (s === 'TEXCOORD_0' ? has(s).some(Boolean) : has(s).every(Boolean)));
			const counts = ps.map((p) => p.getAttribute('POSITION').getCount());
			const nv = counts.reduce((a, c) => a + c, 0);
			const np = doc.createPrimitive().setMaterial(m);
			for (const [s, w] of sems) {
				const arr = new Float32Array(nv * w);
				let o = 0;
				ps.forEach((p, i) => { const a = p.getAttribute(s); const e = []; for (let k = 0; k < counts[i]; k++, o++) if (a) arr.set(a.getElement(k, e).slice(0, w), o * w); });
				np.setAttribute(s, acc(w === 2 ? 'VEC2' : w === 3 ? 'VEC3' : 'VEC4', arr));
			}
			const idx = [];
			let base = 0;
			ps.forEach((p, i) => { const ix = p.getIndices(); for (let k = 0; k < (ix ? ix.getCount() : counts[i]); k++) idx.push(base + (ix ? ix.getScalar(k) : k)); base += counts[i]; });
			np.setIndices(acc('SCALAR', nv > 65535 ? new Uint32Array(idx) : new Uint16Array(idx)));
			mesh.addPrimitive(np);
		}
		merged.push(doc.createNode(key).setMesh(mesh));
	}
	for (const n of nodes) { scene.removeChild(n); n.dispose(); }
	nodes.length = 0;
	for (const n of merged) { nodes.push(n); scene.addChild(n); }
	await doc.transform(prune({ keepAttributes: true }));
}

// ---- materials: drop extensions Roblox ignores; give flat-colour materials a real baseColor texture
const toSrgb = (x) => (x <= 0.0031308 ? 12.92 * x : 1.055 * Math.pow(x, 1 / 2.4) - 0.055);
for (const ext of root.listExtensionsUsed()) if (!['KHR_texture_transform', 'KHR_mesh_quantization'].includes(ext.extensionName)) { console.log('  removed extension', ext.extensionName); ext.dispose(); }
for (const m of root.listMaterials()) {
	if (m.getBaseColorTexture()) continue;
	const fac = m.getBaseColorFactor();
	const occ = m.getOcclusionTexture();
	let png;
	if (occ && occ.getImage()) {
		// colour x ambient occlusion (the AO map's red channel), in linear, written as sRGB
		const { data, info } = await sharp(Buffer.from(occ.getImage())).resize(TEX, TEX, { fit: 'inside' }).removeAlpha().raw().toBuffer({ resolveWithObject: true });
		const out = Buffer.alloc(info.width * info.height * 3);
		const str = m.getOcclusionStrength();
		for (let i = 0; i < info.width * info.height; i++) {
			const ao = 1 + str * (data[i * info.channels] / 255 - 1);
			for (let k = 0; k < 3; k++) out[i * 3 + k] = Math.round(255 * toSrgb(Math.min(1, fac[k] * ao)));
		}
		png = await sharp(out, { raw: { width: info.width, height: info.height, channels: 3 } }).png().toBuffer();
	} else {
		const rgb = [0, 1, 2].map((k) => Math.round(255 * toSrgb(fac[k])));
		png = await sharp({ create: { width: 64, height: 64, channels: 3, background: { r: rgb[0], g: rgb[1], b: rgb[2] } } }).png().toBuffer();
	}
	const tex = doc.createTexture(`${m.getName()}_baseColor`).setImage(new Uint8Array(png)).setMimeType('image/png').setURI(`${m.getName().replace(/[^\w.-]/g, '_')}_baseColor.png`);
	m.setBaseColorTexture(tex).setBaseColorFactor([1, 1, 1, fac[3]]);
	console.log(`  baked baseColor for ${JSON.stringify(m.getName())} from factor ${fac.slice(0, 3).map((x) => x.toFixed(3)).join(',')}${occ ? ' x AO' : ''}`);
}
for (const p of root.listMeshes().flatMap((me) => me.listPrimitives())) if (!p.getAttribute('TEXCOORD_0') && p.getMaterial()?.getBaseColorTexture()) {
	// (a flat-colour piece with no UVs: every point on the one texel of its solid texture)
	p.setAttribute('TEXCOORD_0', acc('VEC2', new Float32Array(p.getAttribute('POSITION').getCount() * 2).fill(0.5)));
	console.log('  added solid-colour UVs to a', p.getMaterial().getName(), 'primitive');
}

// ---- shrink (same steps as the gltf-transform CLI pass: resize, jpeg, weld, simplify 0.15, prune, dedup)
await MeshoptSimplifier.ready;
await doc.transform(
	textureCompress({ encoder: sharp, targetFormat: 'jpeg', resize: [TEX, TEX] }),
	weld(),
	simplify({ simplifier: MeshoptSimplifier, ratio: 0.15, error: 0.0001 }),
	prune({ keepSolidTextures: true }),
	dedup(),
);
// ---- triangle budget (ARSENAL 8.1: <= 8,000 per gun): the big primitives simplified harder, a pass at a time, the
// error allowed growing until the whole is under; primitives under 300 triangles are left as they are
const triCount = (p) => (p.getIndices() ? p.getIndices().getCount() : p.getAttribute('POSITION').getCount()) / 3;
const allPrims = () => root.listMeshes().flatMap((me) => me.listPrimitives());
const total = () => allPrims().reduce((a, p) => a + triCount(p), 0);
const before = total();
// (meshopt's error is a share of the primitive's own extent: given here in metres, so a long gun's body is not let
// move 5 cm where its trigger may move a millimetre)
const extentOf = (p) => { const pos = p.getAttribute('POSITION'); const mn = pos.getMin([]), mx = pos.getMax([]); return Math.max(...mx.map((v, k) => v - mn[k])) || 1; };
for (const abs of [0.0002, 0.0005, 0.001, 0.0015, 0.002, 0.003]) {
	const t = total();
	if (t <= BUDGET) break;
	const small = allPrims().filter((p) => triCount(p) < 300).reduce((a, p) => a + triCount(p), 0);
	const ratio = Math.max(0.02, ((BUDGET * 0.97 - small) / (t - small)));
	for (const p of allPrims()) if (triCount(p) >= 300) simplifyPrimitive(p, { simplifier: MeshoptSimplifier, ratio, error: abs / extentOf(p), lockBorder: false });
	console.log(`  budget pass error ${abs * 1000} mm: ${t} -> ${total()} tris`);
}
// (Still over: shapes drawn with hard edges have every corner split by its normals, which the simplifier treats as
// seams it may not cross, and stays stuck. Those shapes are welded again by position and UV alone (the UV seams kept),
// simplified, and given normals again: each corner the mean of the faces around it within 40 degrees of its own, so
// the hard edges stay hard.)
const startCount = new Map(allPrims().map((p) => [p, triCount(p)]));
function rewelded(p, ratio, err) {
	const pos = p.getAttribute('POSITION'), uv = p.getAttribute('TEXCOORD_0'), ix = p.getIndices();
	const key = new Map(), P = [], U = [], idx = [];
	const q = [], t = [];
	for (let k = 0; k < ix.getCount(); k++) {
		const i = ix.getScalar(k);
		pos.getElement(i, q);
		if (uv) uv.getElement(i, t); else t.splice(0, 2, 0, 0);
		const kk = q.map((x) => Math.round(x * 1e5)).join(',') + '|' + t.map((x) => Math.round(x * 1e4)).join(',');
		let id = key.get(kk);
		if (id === undefined) { id = P.length / 3; key.set(kk, id); P.push(q[0], q[1], q[2]); U.push(t[0], t[1]); }
		idx.push(id);
	}
	const target = Math.max(3, Math.floor((idx.length * ratio) / 3) * 3);
	const [out] = MeshoptSimplifier.simplify(new Uint32Array(idx), new Float32Array(P), 3, target, err, []);
	const nfaces = out.length / 3, FN = [], posKey = (v) => `${Math.round(P[v * 3] * 1e5)},${Math.round(P[v * 3 + 1] * 1e5)},${Math.round(P[v * 3 + 2] * 1e5)}`;
	const around = new Map();
	for (let f = 0; f < nfaces; f++) {
		const [a, b, c] = [out[f * 3], out[f * 3 + 1], out[f * 3 + 2]].map((v) => [P[v * 3], P[v * 3 + 1], P[v * 3 + 2]]);
		const e1 = b.map((x, k) => x - a[k]), e2 = c.map((x, k) => x - a[k]);
		FN.push([e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]]);
		for (let k = 0; k < 3; k++) { const pk = posKey(out[f * 3 + k]); if (!around.has(pk)) around.set(pk, []); around.get(pk).push(f); }
	}
	const unitN = FN.map((n) => { const l = Math.hypot(...n) || 1; return n.map((x) => x / l); });
	const cos = Math.cos((40 * Math.PI) / 180);
	const vmap = new Map(), P2 = [], U2 = [], N2 = [], I2 = [];
	for (let f = 0; f < nfaces; f++) for (let k = 0; k < 3; k++) {
		const v = out[f * 3 + k];
		const n = [0, 0, 0];
		for (const g of around.get(posKey(v))) if (unitN[g][0] * unitN[f][0] + unitN[g][1] * unitN[f][1] + unitN[g][2] * unitN[f][2] > cos) for (let a = 0; a < 3; a++) n[a] += FN[g][a];
		const l = Math.hypot(...n) || 1;
		const nn = n.map((x) => x / l);
		const kk = v + '|' + nn.map((x) => Math.round(x * 100)).join(',');
		let id = vmap.get(kk);
		if (id === undefined) { id = P2.length / 3; vmap.set(kk, id); P2.push(P[v * 3], P[v * 3 + 1], P[v * 3 + 2]); U2.push(U[v * 2], U[v * 2 + 1]); N2.push(...nn); }
		I2.push(id);
	}
	p.setAttribute('POSITION', acc('VEC3', new Float32Array(P2))).setAttribute('NORMAL', acc('VEC3', new Float32Array(N2))).setAttribute('TANGENT', null);
	if (uv) p.setAttribute('TEXCOORD_0', acc('VEC2', new Float32Array(U2)));
	for (const s of p.listSemantics()) if (!['POSITION', 'NORMAL', 'TEXCOORD_0'].includes(s)) p.setAttribute(s, null);
	p.setIndices(acc('SCALAR', P2.length / 3 > 65535 ? new Uint32Array(I2) : new Uint16Array(I2)));
}
for (const abs of [0.001, 0.002, 0.003, 0.004]) {
	const t = total();
	if (t <= BUDGET) break;
	const stuck = allPrims().filter((p) => triCount(p) >= 300 && triCount(p) > 0.5 * startCount.get(p));
	const pool = stuck.length ? stuck : allPrims().filter((p) => triCount(p) >= 300);
	const inPool = pool.reduce((a, p) => a + triCount(p), 0);
	const ratio = Math.max(0.05, (BUDGET * 0.97 - (t - inPool)) / inPool);
	for (const p of pool) rewelded(p, ratio, abs / extentOf(p));
	console.log(`  reweld pass error ${abs * 1000} mm on ${pool.length} stuck primitive(s): ${t} -> ${total()} tris`);
}
// (Last: shapes held by their UV seams: `Permissive` lets the simplifier cross those too, the error still capped in mm.)
for (const abs of [0.001, 0.002, 0.003]) {
	const t = total();
	if (t <= BUDGET) break;
	const pool = allPrims().filter((p) => triCount(p) >= 300);
	const inPool = pool.reduce((a, p) => a + triCount(p), 0);
	const ratio = Math.max(0.05, (BUDGET * 0.97 - (t - inPool)) / inPool);
	for (const p of pool) {
		const ix = p.getIndices(), pos = p.getAttribute('POSITION');
		const target = Math.max(3, Math.floor((ix.getCount() * ratio) / 3) * 3);
		const uvA = p.getAttribute('TEXCOORD_0');
		const [out] = uvA
			? MeshoptSimplifier.simplifyWithAttributes(new Uint32Array(ix.getArray()), new Float32Array(pos.getArray()), 3, new Float32Array(uvA.getArray()), 2, [1, 1], null, target, abs / extentOf(p), ['Permissive'])
			: MeshoptSimplifier.simplify(new Uint32Array(ix.getArray()), new Float32Array(pos.getArray()), 3, target, abs / extentOf(p), ['Permissive']);
		p.setIndices(acc('SCALAR', pos.getCount() > 65535 ? new Uint32Array(out) : new Uint16Array(out)));
		compactPrimitive(p);
	}
	console.log(`  permissive pass error ${abs * 1000} mm: ${t} -> ${total()} tris`);
}
await doc.transform(prune({ keepSolidTextures: true }));
if (total() > BUDGET) console.warn(`  WARNING: still ${total()} tris (> ${BUDGET})`);
else if (before > BUDGET) console.log(`  budget: ${before} -> ${total()} tris`);

// ---- brand text painted out: each rect (UV, 0..1, [u0, v0, u1, v1]) filled from its border, in every picture of
// the materials named (colour, normal, metal/rough, occlusion), so the stamp goes from the relief too
for (const { mat, rects } of G.paint ?? []) {
	const done = new Set();
	for (const m of root.listMaterials().filter((m) => mat.test(m.getName()))) {
		for (const [slot, tex] of [['base', m.getBaseColorTexture()], ['nrm', m.getNormalTexture()], ['mr', m.getMetallicRoughnessTexture()], ['occ', m.getOcclusionTexture()]]) {
			if (!tex || done.has(tex)) continue;
			done.add(tex);
			const { data, info } = await sharp(Buffer.from(tex.getImage())).removeAlpha().raw().toBuffer({ resolveWithObject: true });
			const W = info.width, H = info.height, C = info.channels;
			const px = (x, y, c) => data[(Math.min(H - 1, Math.max(0, y)) * W + Math.min(W - 1, Math.max(0, x))) * C + c];
			for (const [u0, v0, u1, v1] of rects) {
				const x0 = Math.floor(u0 * W), x1 = Math.ceil(u1 * W) - 1, y0 = Math.floor(v0 * H), y1 = Math.ceil(v1 * H) - 1;
				// the ring around the rect: its spread, for grain in the colour picture
				const ring = [];
				for (let x = x0 - 2; x <= x1 + 2; x++) for (const y of [y0 - 2, y0 - 1, y1 + 1, y1 + 2]) ring.push([0, 1, 2].map((c) => px(x, y, c)));
				for (let y = y0; y <= y1; y++) for (const x of [x0 - 2, x0 - 1, x1 + 1, x1 + 2]) ring.push([0, 1, 2].map((c) => px(x, y, c)));
				const mean = [0, 1, 2].map((c) => ring.reduce((a, q) => a + q[c], 0) / ring.length);
				const sd = [0, 1, 2].map((c) => Math.sqrt(ring.reduce((a, q) => a + (q[c] - mean[c]) ** 2, 0) / ring.length));
				const out = new Float32Array((x1 - x0 + 1) * (y1 - y0 + 1) * 3);
				for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
					const a = (x - x0 + 1) / (x1 - x0 + 2), b = (y - y0 + 1) / (y1 - y0 + 2);
					const g = slot === 'base' ? (Math.random() + Math.random() + Math.random() - 1.5) * 0.8 : 0;
					for (let c = 0; c < 3; c++) {
						const L = (px(x0 - 1, y, c) + px(x0 - 2, y, c)) / 2, Rr = (px(x1 + 1, y, c) + px(x1 + 2, y, c)) / 2;
						const T = (px(x, y0 - 1, c) + px(x, y0 - 2, c)) / 2, Bt = (px(x, y1 + 1, c) + px(x, y1 + 2, c)) / 2;
						out[((y - y0) * (x1 - x0 + 1) + (x - x0)) * 3 + c] = (L * (1 - a) + Rr * a + T * (1 - b) + Bt * b) / 2 + g * Math.min(sd[c], 12);
					}
				}
				for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) for (let c = 0; c < 3; c++) data[(y * W + x) * C + c] = Math.max(0, Math.min(255, Math.round(out[((y - y0) * (x1 - x0 + 1) + (x - x0)) * 3 + c])));
			}
			const enc = await sharp(data, { raw: { width: W, height: H, channels: C } }).jpeg({ quality: 90 }).toBuffer();
			tex.setImage(new Uint8Array(enc)).setMimeType('image/jpeg');
			console.log(`  painted ${rects.length} rect(s) in ${slot} of ${JSON.stringify(m.getName())}`);
		}
	}
}

root.getAsset().extras = { ...extras, changes: 'Ember Outpost gun alone: stood in its skeleton pose (FPS arms, spare magazines and animations removed), straightened, flat colours baked to textures, textures re-encoded as JPEG, geometry simplified' };
await io.write(output, doc);
const b = getBounds(scene);
console.log(`${gun}: wrote ${output} ${(fs.statSync(output).size / 1048576).toFixed(2)} MB; size ${b.max.map((v, k) => (v - b.min[k]).toFixed(3)).join(' x ')} m; nodes ${nodes.map((n) => n.getName()).join(', ')}`);
