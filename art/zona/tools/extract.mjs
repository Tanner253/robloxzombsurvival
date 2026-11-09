// Extract only the wanted meshes of a glTF (drop FPS arms, duplicate guns, skins, animations) and write a GLB.
// usage: node extract.mjs in.gltf out.glb "<removeRegex>"
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { prune, dedup, weld } from '@gltf-transform/functions';

const [, , input, output, removePattern] = process.argv;
const remove = new RegExp(removePattern || '^$', 'i');
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(input);
const root = doc.getRoot();

for (const anim of root.listAnimations()) anim.dispose();
let removed = 0;
for (const node of root.listNodes()) {
	const mesh = node.getMesh();
	const name = (mesh && mesh.getName()) || node.getName() || '';
	if (mesh && remove.test(name)) { node.setMesh(null); removed++; }
	if (node.getSkin()) node.setSkin(null);
}
for (const skin of root.listSkins()) skin.dispose();
await doc.transform(dedup(), weld(), prune());
await io.write(output, doc);
const meshes = root.listMeshes().map((m) => m.getName());
console.log(`removed ${removed} mesh refs; kept ${meshes.length}: ${meshes.join(', ')}`);
