// Print each material's texture slots with texCoord index and image size/mime.
// usage: node texinfo.mjs file.(gltf|glb)
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { MeshoptDecoder } from 'meshoptimizer';

await MeshoptDecoder.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ 'meshopt.decoder': MeshoptDecoder });
const doc = await io.read(process.argv[2]);
const root = doc.getRoot();
console.log('extensionsUsed:', root.listExtensionsUsed().map((e) => e.extensionName).join(', '));
for (const m of root.listMaterials()) {
	const slots = [
		['base', m.getBaseColorTexture(), m.getBaseColorTextureInfo()],
		['mr', m.getMetallicRoughnessTexture(), m.getMetallicRoughnessTextureInfo()],
		['nrm', m.getNormalTexture(), m.getNormalTextureInfo()],
		['occ', m.getOcclusionTexture(), m.getOcclusionTextureInfo()],
		['emi', m.getEmissiveTexture(), m.getEmissiveTextureInfo()],
	];
	const s = slots.filter(([, t]) => t).map(([k, t, i]) => `${k}:uv${i.getTexCoord()}:${t.getMimeType()}:${t.getSize()?.join('x')}`).join(' ');
	console.log(JSON.stringify(m.getName()), 'bcF', m.getBaseColorFactor().map((x) => +x.toFixed(3)).join(','), 'met', m.getMetallicFactor(), 'rough', m.getRoughnessFactor(), '|', s);
}
for (const me of root.listMeshes()) for (const p of me.listPrimitives()) console.log('  mesh', JSON.stringify(me.getName()), p.getAttribute('POSITION').getCount() + 'v', p.listSemantics().join('/'), 'mat', JSON.stringify(p.getMaterial()?.getName()));
