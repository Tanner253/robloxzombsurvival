// Inspect a glTF: nodes, meshes, skins, materials, textures, animations.
// usage: node inspect.mjs in.gltf
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';

const [, , input] = process.argv;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(input);
const root = doc.getRoot();
console.log('asset extras:', JSON.stringify(root.getAsset().extras || {}));
console.log('extensionsUsed:', root.listExtensionsUsed().map((e) => e.extensionName).join(', '));
console.log('--- textures');
for (const t of root.listTextures()) console.log(' ', t.getName(), t.getURI(), t.getMimeType(), t.getImage() ? t.getImage().byteLength : 'NO IMAGE');
console.log('--- materials');
for (const m of root.listMaterials()) {
	const bc = m.getBaseColorTexture();
	const ext = m.listExtensions().map((e) => e.extensionName);
	console.log(' ', JSON.stringify(m.getName()), 'bcTex=', bc ? bc.getURI() || bc.getName() : null, 'bcF=', m.getBaseColorFactor().map((x) => x.toFixed(2)).join(','), 'ext=', ext.join(','), 'alpha=', m.getAlphaMode());
	for (const e of m.listExtensions()) {
		if (e.extensionName === 'KHR_materials_pbrSpecularGlossiness') {
			const d = e.getDiffuseTexture();
			console.log('    specGloss diffuseTex=', d ? d.getURI() : null, 'diffuseF=', e.getDiffuseFactor());
		}
	}
}
console.log('--- meshes');
for (const me of root.listMeshes()) {
	const prims = me.listPrimitives();
	console.log(' ', JSON.stringify(me.getName()), prims.map((p) => `${p.getAttribute('POSITION')?.getCount()}v mat=${JSON.stringify(p.getMaterial()?.getName())} attrs=${p.listSemantics().join('/')}`).join(' | '));
}
console.log('--- mesh nodes');
for (const n of root.listNodes()) {
	if (!n.getMesh()) continue;
	const parents = [];
	for (let p = n.getParentNode(); p; p = p.getParentNode()) parents.push(p.getName());
	console.log(' ', JSON.stringify(n.getName()), 'mesh=', JSON.stringify(n.getMesh().getName()), 'skin=', n.getSkin() ? n.getSkin().listJoints().length + 'j' : '-', 'path=', parents.slice(0, 4).join(' < '));
}
console.log('--- animations');
for (const a of root.listAnimations()) {
	let dur = 0;
	for (const s of a.listSamplers()) dur = Math.max(dur, s.getInput().getMax([])[0]);
	console.log(' ', JSON.stringify(a.getName()), a.listChannels().length, 'ch', dur.toFixed(2) + 's', a.listSamplers()[0]?.getInterpolation());
}
console.log('--- skins');
for (const s of root.listSkins()) console.log(' ', s.getName(), s.listJoints().map((j) => j.getName()).join(', '));
