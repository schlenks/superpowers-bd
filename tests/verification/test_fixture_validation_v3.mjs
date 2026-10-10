import assert from 'node:assert/strict';
import test from 'node:test';
import {
  validateDescription,
  validateDueDate,
} from './fixtures/validation-v3.ts';

test('description accepts omitted, null, and at most 2000 characters', () => {
  assert.equal(validateDescription(undefined).valid, true);
  assert.equal(validateDescription(null).valid, true);
  assert.equal(validateDescription('a'.repeat(2000)).valid, true);
});

test('description rejects oversized and non-string values', () => {
  assert.equal(validateDescription('a'.repeat(2001)).valid, false);
  assert.equal(validateDescription(123).valid, false);
});

test('due date accepts future ISO date and timezone-qualified datetime', () => {
  assert.equal(validateDueDate('2099-12-31').valid, true);
  assert.equal(validateDueDate('2099-12-31T12:00:00Z').valid, true);
  assert.equal(validateDueDate('2099-12-31T12:00:00+02:00').valid, true);
});

test('due date rejects parseable non-ISO and normalized invalid dates', () => {
  assert.equal(validateDueDate('December 31, 2099').valid, false);
  assert.equal(validateDueDate('2099-02-30').valid, false);
  assert.equal(validateDueDate('2000-01-01').valid, false);
});
