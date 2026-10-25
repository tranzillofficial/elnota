import test from 'node:test';
import assert from 'node:assert/strict';
import { sha256, randomSecret, isExpired, uuidPattern } from '../supabase/functions/device-login/protocol.ts';
test('browser proof is 256 bits and only its hash belongs in storage', async () => {
  const a = randomSecret(), b = randomSecret();
  assert.match(a, /^[0-9a-f]{64}$/);
  assert.notEqual(a, b);
  assert.notEqual(await sha256(a), a);
  assert.equal(await sha256(a), await sha256(a));
});
test('expired and malformed challenge dates fail closed', () => {
  assert.equal(isExpired('not-a-date'), true);
  assert.equal(isExpired('2026-10-23T00:00:00Z', Date.parse('2026-10-23T00:00:00Z')), true);
  assert.equal(isExpired('2026-10-23T00:03:00Z', Date.parse('2026-10-23T00:00:00Z')), false);
});
test('challenge identifiers are UUIDs, not arbitrary URLs', () => {
  assert.equal(uuidPattern.test(crypto.randomUUID()), true);
  assert.equal(uuidPattern.test('https://attacker.invalid'), false);
});
