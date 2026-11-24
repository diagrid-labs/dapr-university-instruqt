// Copies out/<scene>-dark.png to <page>/images/<file> for every PAGES entry.
import { copyFileSync, existsSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { REPO_ROOT, PAGES } from './labs.mjs';

for (const [name, { page, file }] of Object.entries(PAGES)) {
  const src = join(REPO_ROOT, 'diagrams', 'out', `${name}-dark.png`);
  if (!existsSync(src)) {
    console.error(`${name}: missing ${src}. Export the scene first.`);
    process.exit(1);
  }
  const dir = join(REPO_ROOT, page, 'images');
  mkdirSync(dir, { recursive: true });
  copyFileSync(src, join(dir, file));
  console.log(`${name}: ${page}/images/${file}`);
}
