"""Executable contract checks for the V3 review fixture middleware."""

import subprocess
import unittest
from pathlib import Path


MIDDLEWARE = Path(__file__).resolve().parent / "fixtures" / "middleware-v3.ts"


def run_node(script: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["node", "--experimental-strip-types", "--input-type=module", "-e", script],
        capture_output=True,
        text=True,
        timeout=10,
    )


class MiddlewareFixtureTest(unittest.TestCase):
    def test_planted_rate_limit_and_cors_findings_remain_observable(self):
        script = f"""
import assert from 'node:assert/strict';
import {{ rateLimiter, corsMiddleware }} from {MIDDLEWARE.as_uri()!r};
const call = (credential) => {{
  const req = {{userId:'alice', headers:{{authorization:credential}}, method:'GET'}};
  const res = {{headers:{{}}, set(key,value) {{this.headers[key]=value;}},
    status(code) {{this.code=code; return this;}}, json() {{return this;}}}};
  let passed=false;
  rateLimiter(req,res,() => {{passed=true;}});
  return {{passed,res}};
}};
for (let i=0; i<120; i++) assert.equal(call('Bearer token-a').passed, true);
assert.equal(call('Bearer token-a').res.code, 429);
assert.equal(call('Bearer token-b').passed, true);
const cors = {{headers:{{}}, set(key,value) {{this.headers[key]=value;}},
  status() {{return this;}}, end() {{}}}};
corsMiddleware({{method:'GET',headers:{{origin:'https://unapproved.example'}}}},cors,() => {{}});
assert.equal(cors.headers['Access-Control-Allow-Origin'], '*');
assert.equal(cors.headers['Access-Control-Allow-Credentials'], 'true');
"""
        result = run_node(script)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_signed_claims_and_expiry_cannot_be_bypassed_by_request_header(self):
        script = f"""
import assert from 'node:assert/strict';
import {{ createHmac }} from 'node:crypto';
import {{ authMiddleware }} from {MIDDLEWARE.as_uri()!r};
process.env.TASKFLOW_TOKEN_SECRET = 'fixture-secret';
const sign = (claims) => {{
  const payload = Buffer.from(JSON.stringify(claims)).toString('base64url');
  return payload + '.' + createHmac('sha256', process.env.TASKFLOW_TOKEN_SECRET).update(payload).digest('base64url');
}};
const call = (token, path = '/tasks', extraHeaders = {{}}) => {{
  const req = {{headers: {{authorization: 'Bearer ' + token, ...extraHeaders}}, path,
    app: {{locals: {{taskRepo: {{existsAcrossUsers: () => true}}}}}}}};
  const res = {{status(code) {{ this.code = code; return this; }}, json(body) {{ this.body = body; return this; }}}};
  let nextCalled = false;
  authMiddleware(req, res, () => {{nextCalled = true;}});
  return {{req, res, nextCalled}};
}};
const good = sign({{userId:'alice', scope:'admin', exp: Math.floor(Date.now()/1000)+60}});
const accepted = call(good);
assert.equal(accepted.nextCalled, true);
assert.equal(accepted.req.userId, 'alice');
assert.equal(accepted.req.tokenScope, 'admin');
const expired = call(sign({{userId:'alice', scope:'user', exp: 1}}));
assert.equal(expired.res.code, 401);
assert.equal(expired.res.body.error.code, 'TOKEN_EXPIRED');
// Change a significant signature character; changing trailing base64url
// padding bits can leave the decoded signature unchanged.
const [payload, signature] = good.split('.');
const forgedToken = payload + '.' + (signature[0] === 'A' ? 'B' : 'A') + signature.slice(1);
const forged = call(forgedToken, '/tasks/task-123', {{'x-auth-validated':'true'}});
assert.equal(forged.nextCalled, false);
assert.equal(forged.res.code, 401);
assert.match(forged.res.body.error.message, /task-123/);
const malformed = call('nonsense', '/tasks/task-123');
assert.equal(malformed.res.code, 401);
assert.doesNotMatch(malformed.res.body.error.message, /task-123/);
delete process.env.TASKFLOW_TOKEN_SECRET;
assert.equal(call(good).res.code, 401);
assert.doesNotMatch(call(good, '/tasks/task-123').res.body.error.message, /task-123/);
"""
        result = run_node(script)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_audit_records_actual_resource_changes_and_webhook_failure(self):
        script = f"""
import assert from 'node:assert/strict';
import {{ recordAudit, recordWebhookFailure }} from {MIDDLEWARE.as_uri()!r};
const original = JSON.stringify;
const entries = [];
JSON.stringify = (value) => {{
  if (Array.isArray(value) && value.length && value.at(-1)?.action) entries.push(value.at(-1));
  return original(value);
}};
recordAudit({{userId:'alice', method:'PATCH', path:'/tasks/id-1', headers:{{'user-agent':'fixture'}}}},
  'task.updated', 'id-1', {{title:{{before:'old', after:'new'}}}});
assert.equal(entries.at(-1).resource_id, 'id-1');
assert.equal(entries.at(-1).user_id, 'alice');
assert.deepEqual(entries.at(-1).changes, {{title:{{before:'old',after:'new'}}}});
assert.match(entries.at(-1).timestamp, /Z$/);
recordWebhookFailure('https://example.test/hook', 'id-1');
assert.equal(entries.at(-1).action, 'webhook.delivery_failed');
assert.equal(entries.at(-1).resource_id, 'id-1');
JSON.stringify = original;
"""
        result = run_node(script)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
