// Scene name -> the lab page it illustrates and the image file name there.
// Tasks that add a scene add its entry here and register the scene in scenes/index.mjs.
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

/** @type {Record<string, { page: string, file: string }>} */
export const PAGES = {
  'workflow-101-1-architecture': { page: 'dapr-workflow-101/1-durable-execution', file: 'architecture.png' },
  'workflow-101-1-replay': { page: 'dapr-workflow-101/1-durable-execution', file: 'replay.png' },
  'workflow-101-2-chain': { page: 'dapr-workflow-101/2-task-chaining', file: 'chain.png' },
  'workflow-101-3-fan-out': { page: 'dapr-workflow-101/3-fan-out-fan-in', file: 'fan-out.png' },
  'workflow-101-4-monitor': { page: 'dapr-workflow-101/4-monitor', file: 'monitor.png' },
};

const BASE = 'https://github.com/diagrid-labs/dapr-university-instruqt/blob';

export function imageUrl(page, file, ref = 'main') {
  return `${BASE}/${ref}/${page}/images/${file}?raw=true`;
}

const escape = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

function pattern(page, file) {
  return new RegExp(`${escape(BASE)}/([^/\\s)]+(?:/[^/\\s)]+)*?)/${escape(page)}/images/${escape(file)}\\?raw=true`, 'g');
}

export function findImageRefs(markdown, page, file) {
  return [...markdown.matchAll(pattern(page, file))].map((m) => m[1]);
}

export function rewriteRefs(markdown, page, file, ref) {
  return markdown.replace(pattern(page, file), () => imageUrl(page, file, ref));
}
