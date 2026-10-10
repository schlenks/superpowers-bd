import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

// Install once with:
// npm_config_cache=temp/v3-fixture-npm-cache npm install --prefix temp/v3-fixture-runtime --no-save --no-package-lock express@5.2.1 uuid@11.1.1 typescript@5.9.3
const runtime = resolve(import.meta.dirname, '../../temp/v3-fixture-runtime');
const require = createRequire(resolve(runtime, 'package.json'));
const ts = require('typescript');
const express = require('express');
const root = resolve(import.meta.dirname, 'fixtures');
const out = resolve(runtime, 'dist');
mkdirSync(out, { recursive: true });
for (const name of ['api-v3', 'middleware-v3', 'repository-v3', 'validation-v3']) {
  const source = readFileSync(resolve(root, `${name}.ts`), 'utf8');
  const result = ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS,
    target: ts.ScriptTarget.ES2022,
    esModuleInterop: true,
  }});
  writeFileSync(resolve(out, `${name}.js`), result.outputText);
}

process.env.TASKFLOW_TOKEN_SECRET = 'fixture-test-secret';
const router = require(resolve(out, 'api-v3.js')).default;
const app = express();
app.use(router);
const server = app.listen(0, '127.0.0.1');
await new Promise(resolve => server.once('listening', resolve));
const base = `http://127.0.0.1:${server.address().port}`;
const httpFetch = globalThis.fetch;
const webhookCalls = [];
const auditEntries = [];
const originalStringify = JSON.stringify;
JSON.stringify = function (value, ...args) {
  if (Array.isArray(value) && value.at(-1)?.action) {
    auditEntries.push(structuredClone(value.at(-1)));
  }
  return originalStringify.call(JSON, value, ...args);
};
globalThis.fetch = async (url, opts) => {
  if (String(url).startsWith(base)) return httpFetch(url, opts);
  webhookCalls.push({ url, body: JSON.parse(opts.body) });
  return { status: String(url).endsWith('/fail') ? 500 : 200 };
};

function token(userId, scope = 'user', expires = Date.now() / 1000 + 3600) {
  const payload = Buffer.from(JSON.stringify({ userId, scope, exp: Math.floor(expires) })).toString('base64url');
  const signature = createHmac('sha256', process.env.TASKFLOW_TOKEN_SECRET).update(payload).digest('base64url');
  return `${payload}.${signature}`;
}
async function request(path, method = 'GET', body, credential = token('alice')) {
  const headers = { Authorization: `Bearer ${credential}` };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const res = await httpFetch(`${base}${path}`, {
    method, headers, body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: res.status, headers: res.headers, body: res.status === 204 ? null : await res.json() };
}

try {
  const created = await request('/tasks', 'POST', { title: 'Task A', description: 'valid' });
  assert.equal(created.status, 201);
  const id = created.body.data.id;
  assert.equal(auditEntries.at(-1).resource_id, id);
  assert.equal(auditEntries.at(-1).user_id, 'alice');
  assert.equal(created.body.data.owner_id, undefined);
  assert.equal((await request('/tasks')).body.data.tasks.length, 1);
  assert.equal((await request('/tasks', 'GET', undefined, token('bob'))).body.data.tasks.length, 0);
  assert.equal((await request('/tasks?status=')).status, 400);
  for (const query of ['sort=', 'order=', 'page=abc', 'limit=1.5']) {
    assert.equal((await request(`/tasks?${query}`)).status, 400, query);
  }
  const boundary = await request('/tasks', 'POST', { title: 'Boundary' });
  const boundaryId = boundary.body.data.id;
  const maxUpdate = {
    id: boundaryId,
    title: 't'.repeat(200),
    description: '\u0000'.repeat(2000),
    priority: 5,
    status: 'done',
  };
  const maximumBulk = { updates: Array.from({ length: 100 }, () => maxUpdate) };
  assert.ok(Buffer.byteLength(JSON.stringify(maximumBulk)) > 1_000_000);
  const maximumResult = await request('/tasks/bulk', 'PATCH', maximumBulk);
  assert.equal(maximumResult.status, 200);
  assert.equal(maximumResult.body.data.updated, 100);
  assert.equal((await request(`/tasks/${boundaryId}`, 'DELETE')).status, 200);
  assert.equal((await request(`/tasks/${id}`, 'PATCH', { title: 'stolen' }, token('bob'))).status, 404);
  assert.equal((await request(`/tasks/${id}`, 'DELETE', undefined, token('bob'))).status, 404);

  const admin = token('alice', 'admin');
  assert.equal((await request('/webhooks/register', 'POST', { url: 'https://example.com/hook', events: ['task.updated'] }, admin)).status, 201);
  assert.equal((await request('/webhooks/register', 'POST', { url: 'https://example.com/hook', events: ['task.updated'] }, token('alice'))).status, 403);
  const invalidAdminBody = await httpFetch(`${base}/webhooks/register`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token('alice')}`, 'Content-Type': 'application/json' },
    body: '{',
  });
  assert.equal(invalidAdminBody.status, 403);
  const forged = token('alice', 'admin').split('.')[0] + '.invalid';
  assert.equal((await request('/webhooks/register', 'POST', { url: 'https://example.com/hook', events: ['task.updated'] }, forged)).status, 401);
  const emptyBearer = await httpFetch(`${base}/tasks`, { headers: { Authorization: 'Bearer ' } });
  assert.equal(emptyBearer.status, 401);
  assert.equal((await emptyBearer.json()).error.code, 'TOKEN_INVALID');
  assert.equal(emptyBearer.headers.get('x-ratelimit-limit'), '120');
  const preflight = await httpFetch(`${base}/tasks`, { method: 'OPTIONS' });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('x-ratelimit-limit'), '120');
  const leak = await request(`/tasks/${id}`, 'PATCH', { title: 'x' }, forged);
  assert.equal(leak.status, 401);
  assert.match(leak.body.error.message, new RegExp(id));
  const missing = await request('/tasks/missing', 'PATCH', { title: 'x' }, forged);
  assert.equal(missing.status, 401);
  assert.doesNotMatch(missing.body.error.message, /missing/);

  assert.equal((await request('/tasks', 'POST', { title: 'x', description: 'x'.repeat(2001) })).status, 400);
  assert.equal((await request(`/tasks/${id}`, 'PATCH', { due_date: 'tomorrow' })).status, 400);
  assert.equal((await request('/tasks/bulk', 'PATCH', { updates: [{ id, description: 'x'.repeat(2001) }] })).body.data.updated, 0);
  assert.equal((await request('/tasks/bulk', 'PATCH', { updates: [{ id, due_date: 'tomorrow' }] })).body.data.updated, 0);
  assert.equal((await request('/tasks?order=sideways')).status, 400);
  const updated = await request(`/tasks/${id}`, 'PATCH', { title: 'Task A2' });
  assert.equal(updated.status, 200);
  assert.deepEqual(auditEntries.at(-1).changes.title, { before: 'Task A', after: 'Task A2' });
  assert.equal(webhookCalls.length, 1);
  assert.equal(webhookCalls[0].body.changed_fields, undefined); // B11
  const updateHooksBeforeBulk = webhookCalls.length;
  assert.equal((await request('/tasks/bulk', 'PATCH', { updates: [{ id, title: 'Bulk webhook task' }] })).status, 200);
  assert.equal(webhookCalls.length, updateHooksBeforeBulk + 1);

  const malformed = await httpFetch(`${base}/tasks`, { method: 'POST', headers: { Authorization: `Bearer ${token('alice')}`, 'Content-Type': 'application/json' }, body: '{' });
  assert.equal(malformed.status, 400);
  assert.equal((await malformed.json()).error.code, 'VALIDATION_ERROR');
  const oversized = await httpFetch(`${base}/tasks`, { method: 'POST', headers: { Authorization: `Bearer ${token('alice')}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ title: 'x', description: 'x'.repeat(2_100_000) }) });
  assert.equal(oversized.status, 413);
  assert.equal((await oversized.json()).error.code, 'PAYLOAD_TOO_LARGE');
  const unauthOversized = await httpFetch(`${base}/tasks`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ title: 'x', description: 'x'.repeat(2_100_000) }) });
  assert.equal(unauthOversized.status, 401);

  const second = await request('/tasks', 'POST', { title: 'Task B' });
  const secondId = second.body.data.id;
  assert.equal((await request('/tasks/bulk', 'DELETE', { ids: [secondId, 'missing'] })).status, 404);
  assert.equal((await request('/tasks')).body.data.tasks.length, 1); // B9
  assert.equal(auditEntries.at(-1).resource_id, secondId);
  assert.equal(auditEntries.at(-1).action, 'task.deleted');

  assert.equal((await request('/webhooks/register', 'POST', { url: 'https://example.com/deleted', events: ['task.deleted'] }, admin)).status, 201);
  const third = await request('/tasks', 'POST', { title: 'Bulk delete webhook task' });
  assert.equal((await request('/tasks/bulk', 'DELETE', { ids: [third.body.data.id] })).status, 200);
  assert.equal(webhookCalls.filter(call => String(call.url).endsWith('/deleted')).length, 1);

  assert.equal((await request('/webhooks/register', 'POST', { url: 'https://example.com/fail', events: ['task.updated'] }, admin)).status, 201);
  assert.equal((await request(`/tasks/${id}`, 'PATCH', { status: 'done' })).status, 200);
  const statusAudit = auditEntries.findLast(entry => entry.action === 'task.updated');
  assert.equal(statusAudit.changes.status.after, 'done');
  assert.ok(statusAudit.changes.closed_at.after);
  for (let i = 0; i < 80 && auditEntries.at(-1)?.action !== 'webhook.delivery_failed'; i++) {
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  assert.equal(auditEntries.at(-1).action, 'webhook.delivery_failed');
  assert.equal(auditEntries.at(-1).resource_id, id);
  assert.equal(webhookCalls.filter(call => String(call.url).endsWith('/fail')).length, 4);
  console.log('HTTP fixture checks passed');
} finally {
  JSON.stringify = originalStringify;
  server.close();
}
