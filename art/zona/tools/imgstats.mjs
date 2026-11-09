// Per-channel mean/min/max of images.  usage: node imgstats.mjs a.png b.png ...
import sharp from 'sharp';
for (const f of process.argv.slice(2)) {
	const s = await sharp(f).stats();
	const m = await sharp(f).metadata();
	console.log(f.split(/[\\/]/).pop(), `${m.width}x${m.height} ch${m.channels}`, s.channels.map((c, i) => `${'RGBA'[i]} mean ${c.mean.toFixed(0)} [${c.min}-${c.max}] sd ${c.stdev.toFixed(0)}`).join(' | '));
}
