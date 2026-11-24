// Usage: node diagrams/set-image-ref.mjs <ref>
// Points every mapped image URL in the assignments at <ref> (a branch name or main).
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { REPO_ROOT, PAGES, rewriteRefs } from './labs.mjs';

const ref = process.argv[2];
if (!ref) {
  console.error('Usage: node diagrams/set-image-ref.mjs <ref>');
  process.exit(1);
}

for (const { page, file } of Object.values(PAGES)) {
  const path = join(REPO_ROOT, page, 'assignment.md');
  const before = readFileSync(path, 'utf8');
  const after = rewriteRefs(before, page, file, ref);
  if (after !== before) {
    writeFileSync(path, after);
    console.log(`${page}/assignment.md -> ${ref}`);
  }
}
