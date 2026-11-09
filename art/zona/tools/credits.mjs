// Print credits for Zona sources: WEAPON_PACKS / MODELS entries and glTF asset.extras.
import fs from 'node:fs';
import * as C from 'file:///C:/Users/perci/source/repos/Zona/scripts/assets.config.mjs';
const Z = 'C:/Users/perci/source/repos/Zona/assets-src/models/';
for (const id of ['sniper', 'a91', 'knife', 'pitchfork', 'ar15', 'desert_eagle', 'm9', 'mosin9130']) {
  const c = C.WEAPON_PACKS[id];
  const j = JSON.parse(fs.readFileSync(Z + c.dir + '/' + c.file, 'utf8'));
  console.log(id, '|', c.credit?.name, '|', c.credit?.author, '|', c.credit?.url, '| extras:', JSON.stringify(j.asset.extras || {}), '| license line:', (c.credit?.line || '').match(/licensed under (.*)$/)?.[1]);
}
for (const d of ['baseball_bat', 'hatchet']) {
  const f = fs.readdirSync(Z + d).find((x) => x.endsWith('.gltf'));
  const j = JSON.parse(fs.readFileSync(Z + d + '/' + f, 'utf8'));
  console.log(d, '| asset:', JSON.stringify(j.asset), '| meta:', fs.readFileSync(Z + d + '/_meta.json', 'utf8').slice(0, 300));
  for (const [k, v] of Object.entries(C)) if (v && typeof v === 'object' && v[d]) console.log('   config', k, JSON.stringify(v[d]).slice(0, 400));
}
