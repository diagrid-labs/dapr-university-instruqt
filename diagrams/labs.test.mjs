import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { scenes } from './scenes/index.mjs';
import { REPO_ROOT, PAGES, imageUrl, findImageRefs, rewriteRefs } from './labs.mjs';

test('imageUrl builds the blob URL', () => {
  assert.equal(imageUrl('dapr-pubsub/1-subscription-types', 'pubsub-pattern.png'),
    'https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-pubsub/1-subscription-types/images/pubsub-pattern.png?raw=true');
  assert.match(imageUrl('a/b', 'c.png', 'dev-1-x'), /\/blob\/dev-1-x\/a\/b\/images\/c\.png\?raw=true$/);
});

test('findImageRefs finds main and branch refs, ignores other images', () => {
  const md = `![x](${imageUrl('a/b', 'c.png')})\n![y](${imageUrl('a/b', 'c.png', 'dev-1-x')})\n![z](${imageUrl('a/b', 'd.png')})`;
  assert.deepEqual(findImageRefs(md, 'a/b', 'c.png'), ['main', 'dev-1-x']);
});

test('rewriteRefs changes only the mapped image', () => {
  const md = `![x](${imageUrl('a/b', 'c.png')}) ![z](${imageUrl('a/b', 'd.png')})`;
  const out = rewriteRefs(md, 'a/b', 'c.png', 'dev-1-x');
  assert.deepEqual(findImageRefs(out, 'a/b', 'c.png'), ['dev-1-x']);
  assert.deepEqual(findImageRefs(out, 'a/b', 'd.png'), ['main']);
});

test('findImageRefs and rewriteRefs handle regex characters in names', () => {
  const md = `![x](${imageUrl('a/b', 'c.png', 'feat/x+y')})`;
  assert.deepEqual(findImageRefs(md, 'a/b', 'c.png'), ['feat/x+y']);
  assert.deepEqual(findImageRefs(rewriteRefs(md, 'a/b', 'c.png', 'main'), 'a/b', 'c.png'), ['main']);
  assert.equal(rewriteRefs(md, 'a/b', 'cxpng', 'main'), md);
});

// Repo checks, over every PAGES entry and every registered scene.
const entries = Object.entries(PAGES);
const assignment = (page) => readFileSync(join(REPO_ROOT, page, 'assignment.md'), 'utf8');

test('scenes and PAGES match', () => {
  assert.deepEqual(Object.keys(scenes).sort(), Object.keys(PAGES).sort());
});

test('scenes fit the column', () => {
  for (const [name, scene] of Object.entries(scenes)) {
    assert.ok(scene.width >= 440 && scene.width <= 500, `${name}: width ${scene.width} outside 440-500`);
    assert.ok(scene.width / scene.height >= 1.33, `${name}: aspect ${(scene.width / scene.height).toFixed(2)} below 1.33`);
  }
});

test('page images match out', () => {
  for (const [name, { page, file }] of entries) {
    const img = join(REPO_ROOT, page, 'images', file);
    const out = join(REPO_ROOT, 'diagrams', 'out', `${name}-dark.png`);
    assert.ok(existsSync(img), `${name}: missing ${img}`);
    assert.ok(existsSync(out), `${name}: missing ${out}`);
    assert.ok(readFileSync(img).equals(readFileSync(out)), `${name}: ${page}/images/${file} differs from out/${name}-dark.png (run copy-to-labs.mjs)`);
  }
});

test('each image is placed once', () => {
  for (const [name, { page, file }] of entries) {
    assert.equal(findImageRefs(assignment(page), page, file).length, 1, `${name}: expected one image line in ${page}/assignment.md`);
  }
});

test('refs point at main', { skip: process.env.ALLOW_BRANCH_REFS === '1' }, () => {
  for (const [name, { page, file }] of entries) {
    for (const ref of findImageRefs(assignment(page), page, file)) {
      assert.equal(ref, 'main', `${name}: ${page}/assignment.md points at ref '${ref}'`);
    }
  }
});
