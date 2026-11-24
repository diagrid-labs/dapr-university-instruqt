// Scene name -> the lab page it illustrates and the image file name there.
// Tasks that add a scene add its entry here and register the scene in scenes/index.mjs.
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

/** @type {Record<string, { page: string, file: string }>} */
export const PAGES = {
  'bindings-1-cron': { page: 'dapr-bindings/1-cron-input-binding', file: 'cron.png' },
  'bindings-1-directions': { page: 'dapr-bindings/1-cron-input-binding', file: 'directions.png' },
  'bindings-2-output': { page: 'dapr-bindings/2-postgres-output-binding', file: 'output.png' },
  'bindings-3-two-components': { page: 'dapr-bindings/3-state-vs-binding', file: 'two-components.png' },
  'bindings-4-subspace-beacon': { page: 'dapr-bindings/4-subspace-beacon', file: 'subspace-beacon.png' },
  'pubsub-1-components': { page: 'dapr-pubsub/1-subscription-types', file: 'pubsub-components.png' },
  'pubsub-1-demo': { page: 'dapr-pubsub/1-subscription-types', file: 'demo.png' },
  'pubsub-1-pattern': { page: 'dapr-pubsub/1-subscription-types', file: 'pubsub-pattern.png' },
  'pubsub-2-streaming': { page: 'dapr-pubsub/2-streaming-subscriptions', file: 'streaming.png' },
  'pubsub-3-envelope': { page: 'dapr-pubsub/3-cloudevents', file: 'envelope.png' },
  'pubsub-4-bulk': { page: 'dapr-pubsub/4-bulk-messages', file: 'bulk.png' },
  'pubsub-5-routing': { page: 'dapr-pubsub/5-routing-and-dead-letters', file: 'routing.png' },
  'secrets-1-cloud-stores': { page: 'dapr-secrets/1-what-is-the-secrets-api', file: 'secrets-cloud-stores.png' },
  'secrets-2-secret-ref': { page: 'dapr-secrets/2-component-and-parameters', file: 'secret-ref.png' },
  'secrets-3-scoping': { page: 'dapr-secrets/3-secret-scoping', file: 'scoping.png' },
  'workflow-101-1-architecture': { page: 'dapr-workflow-101/1-durable-execution', file: 'architecture.png' },
  'workflow-101-1-replay': { page: 'dapr-workflow-101/1-durable-execution', file: 'replay.png' },
  'workflow-101-2-chain': { page: 'dapr-workflow-101/2-task-chaining', file: 'chain.png' },
  'workflow-101-3-fan-out': { page: 'dapr-workflow-101/3-fan-out-fan-in', file: 'fan-out.png' },
  'workflow-101-4-monitor': { page: 'dapr-workflow-101/4-monitor', file: 'monitor.png' },
  'workflow-101-5-approval': { page: 'dapr-workflow-101/5-human-in-the-loop', file: 'approval.png' },
  'workflow-101-6-lifecycle': { page: 'dapr-workflow-101/6-management', file: 'lifecycle.png' },
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
