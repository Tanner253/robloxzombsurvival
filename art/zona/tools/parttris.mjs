// Triangles per Zona `parts` entry of a weapon pack (rigid packs).  usage: node parttris.mjs <packId>
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { WEAPON_PACKS } from 'file:///C:/Users/perci/source/repos/Zona/scripts/assets.config.mjs';
const cfg = WEAPON_PACKS[process.argv[2]];
const doc = await new NodeIO().registerExtensions(ALL_EXTENSIONS).read(`C:/Users/perci/source/repos/Zona/assets-src/models/${cfg.dir}/${cfg.file}`);
const tally = new Map();
for (const n of doc.getRoot().listNodes()) {
	if (!n.getMesh()) continue;
	let part = null;
	for (let p = n; p; p = p.getParentNode()) if (p.getName() in cfg.parts) { part = p.getName(); break; }
	const t = n.getMesh().listPrimitives().reduce((a, p) => a + (p.getIndices() ? p.getIndices().getCount() : p.getAttribute('POSITION').getCount()) / 3, 0);
	tally.set(part ?? '(none)', (tally.get(part ?? '(none)') ?? 0) + t);
}
console.log([...tally].sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k}: ${v}`).join('\n'));
