import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeScannedCode } from '../lib/barcode.ts';

test('accepts numeric and QR product identifiers without changing them', () => {
  assert.equal(normalizeScannedCode(' 6221234567890 '), '6221234567890');
  assert.equal(normalizeScannedCode('EL-005'), 'EL-005');
});
test('rejects empty, oversized, or control-character scan results', () => {
  assert.equal(normalizeScannedCode('   '), '');
  assert.equal(normalizeScannedCode('A'.repeat(101)), '');
  assert.equal(normalizeScannedCode('A\nB'), '');
});
