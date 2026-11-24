// Usage: node diagrams/preview.mjs <name>
// Renders out/<name>-dark.png at 424 CSS px on #16181d (the Instruqt column) into preview/<name>.png.
import { readFileSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = dirname(fileURLToPath(import.meta.url));
const { chromium } = createRequire(join(dir, 'package.json'))('playwright');

const name = process.argv[2];
if (!name) {
  console.error('Usage: node diagrams/preview.mjs <name>');
  process.exit(1);
}
const png = readFileSync(join(dir, 'out', `${name}-dark.png`));
const html = `<!doctype html><html><body style="background:#16181d;margin:16px">
<div id="box" style="width:424px"><img style="width:100%;display:block" src="data:image/png;base64,${png.toString('base64')}"></div>
</body></html>`;

mkdirSync(join(dir, 'preview'), { recursive: true });
const browser = await chromium.launch();
try {
  const page = await browser.newPage({ viewport: { width: 480, height: 800 }, deviceScaleFactor: 2 });
  await page.setContent(html);
  await page.waitForFunction(() => document.querySelector('img').complete);
  const out = join(dir, 'preview', `${name}.png`);
  await page.locator('#box').screenshot({ path: out });
  console.log(out);
} finally {
  await browser.close();
}
