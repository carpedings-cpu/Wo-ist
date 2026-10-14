// Wo ist's? · Autorin: Diana Ziegler
// Stellt die Web-App für die iOS-App zusammen: nur lokale Speicherung, Fuse.js eingebettet.
import { cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const hier = dirname(fileURLToPath(import.meta.url));
const quelle = join(hier, '..');
const ziel = join(hier, 'www');

rmSync(ziel, { recursive: true, force: true });
mkdirSync(ziel, { recursive: true });

for (const datei of ['style.css']) cpSync(join(quelle, datei), join(ziel, datei));
cpSync(join(quelle, 'icons'), join(ziel, 'icons'), { recursive: true });
cpSync(join(hier, 'node_modules', 'fuse.js', 'dist', 'fuse.min.js'), join(ziel, 'fuse.min.js'));

let html = readFileSync(join(quelle, 'index.html'), 'utf8');
html = html.replace(/<script src="https:\/\/cdn\.jsdelivr\.net\/npm\/fuse\.js[^>]*><\/script>/s, '<script src="fuse.min.js" defer></script>');
if (html.includes('cdn.jsdelivr.net')) throw new Error('index.html: CDN-Verweis nicht ersetzt');
html = html.replace(/\s*<link rel="manifest"[^>]*>/, '');
writeFileSync(join(ziel, 'index.html'), html);

let js = readFileSync(join(quelle, 'app.js'), 'utf8');
js = js.replace(/const ABGLEICH = \{[^}]*\};/, "const ABGLEICH = { url: '', schluessel: '' };");
if (!js.includes("const ABGLEICH = { url: '', schluessel: '' };")) throw new Error('app.js: ABGLEICH nicht geleert');
writeFileSync(join(ziel, 'app.js'), js);

console.log('www/ fertig:', ziel);
