// Vendors one file of aurora-field (https://github.com/mutaaf/aurora-field) pinned by hash.
//   npm run sync:aurora [-- --from ../aurora-field/dist/aurora-field.min.js]
// The build refuses a vendored file that does not match site/vendor/aurora-field.json.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';

const k = process.argv.indexOf('--from');
const from = k > 0 ? process.argv[k + 1] : '../aurora-field/dist/aurora-field.min.js';
const lib = readFileSync(from, 'utf8');
const version = (lib.match(/aurora-field v(\d+\.\d+\.\d+)/) || [])[1];
if (!version) throw new Error('no version banner in ' + from);
const sha256 = createHash('sha256').update(lib).digest('hex');
writeFileSync('site/vendor/aurora-field.min.js', lib);
writeFileSync('site/vendor/aurora-field.json', JSON.stringify({ version, sha256, source: 'https://github.com/mutaaf/aurora-field' }, null, 2) + '\n');
console.log(`aurora-field ${version} vendored (${lib.length} bytes, sha256 ${sha256.slice(0, 12)})`);
