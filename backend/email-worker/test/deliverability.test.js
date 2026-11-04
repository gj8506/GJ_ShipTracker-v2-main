import assert from 'node:assert/strict';
import test from 'node:test';

import {
  assertDeliverableFrom,
  describeDeliverability,
  isBlockedSenderDomain,
  normalizeEmail,
  sanitizeName,
  senderAddress,
  senderDomain,
} from '../src/index.js';

test('senderAddress reads the address from a display-name header', () => {
  assert.equal(
    senderAddress('GJandAsher Digital Printing <notifications@mail.gjandasher.ph>'),
    'notifications@mail.gjandasher.ph',
  );
  assert.equal(senderAddress('  Notifications@GJandAsher.PH '), 'notifications@gjandasher.ph');
});

test('senderDomain returns the bare domain or an empty string', () => {
  assert.equal(senderDomain('Name <a@mail.example.org>'), 'mail.example.org');
  assert.equal(senderDomain('a@example.org'), 'example.org');
  assert.equal(senderDomain('not-an-email'), '');
  assert.equal(senderDomain(''), '');
});

test('isBlockedSenderDomain flags Firebase and free mailbox domains', () => {
  for (const domain of [
    'firebaseapp.com',
    'shiptracker-v2.firebaseapp.com',
    'web.app',
    'gmail.com',
    'mail.gmail.com',
    'outlook.com',
    'EXAMPLE.com',
    'gmail.com.',
  ]) {
    assert.equal(isBlockedSenderDomain(domain), true, domain);
  }

  assert.equal(isBlockedSenderDomain('mail.gjandasher.ph'), false);
  assert.equal(isBlockedSenderDomain(''), false);
});

test('assertDeliverableFrom rejects spam-filtered senders', () => {
  assert.throws(
    () => assertDeliverableFrom('ShipTracker <noreply@shiptracker-v2.firebaseapp.com>'),
    /spam|Spam/i,
  );
  assert.throws(
    () => assertDeliverableFrom('GJandAsher <notifications@gmail.com>'),
    /spam|Spam/i,
  );
});

test('assertDeliverableFrom rejects malformed senders', () => {
  assert.throws(() => assertDeliverableFrom(''), /valid address/i);
  assert.throws(() => assertDeliverableFrom('not-an-email'), /valid address/i);
  assert.throws(() => assertDeliverableFrom('Name <>'), /valid address/i);
});

test('assertDeliverableFrom accepts a verified custom domain', () => {
  assert.equal(
    assertDeliverableFrom(
      'GJandAsher Digital Printing <notifications@mail.gjandasher.ph>',
    ),
    'mail.gjandasher.ph',
  );
});

test('normalizeEmail trims, lowercases and rejects bad input', () => {
  assert.equal(normalizeEmail('  Customer@Example.COM '), 'customer@example.com');
  assert.equal(normalizeEmail('no-at-sign'), '');
  assert.equal(normalizeEmail('a b@example.com'), '');
  assert.equal(normalizeEmail(''), '');
  assert.equal(normalizeEmail(null), '');
  assert.equal(normalizeEmail(42), '');
  assert.equal(normalizeEmail(`${'a'.repeat(250)}@example.com`), '');
});

test('sanitizeName removes line breaks and caps length', () => {
  assert.equal(sanitizeName('  Jane\r\nDoe\t '), 'Jane  Doe');
  assert.equal(sanitizeName('x'.repeat(200)).length, 120);
  assert.equal(sanitizeName(null), '');
});

test('describeDeliverability reports an unusable Firebase sender', () => {
  const report = describeDeliverability({
    MAIL_FROM: 'ShipTracker <noreply@shiptracker-v2.firebaseapp.com>',
    REPLY_TO: 'support@gjandasher.ph',
    COMPANY_ADDRESS: 'Laguna, Philippines',
    RESEND_API_KEY: 're_test',
    FIREBASE_PROJECT_ID: 'shiptracker-v2',
    FIREBASE_CLIENT_EMAIL: 'service@example.iam.gserviceaccount.com',
    FIREBASE_PRIVATE_KEY: 'key',
  });

  assert.equal(report.mailFromDomain, 'shiptracker-v2.firebaseapp.com');
  assert.equal(report.mailFromUsable, false);
  assert.match(report.mailFromProblem, /spam|Spam/i);
  assert.equal(report.replyToConfigured, true);
  assert.equal(report.passwordResetConfigured, true);
});

test('describeDeliverability reports a usable verified sender', () => {
  const report = describeDeliverability({
    MAIL_FROM: 'GJandAsher <notifications@mail.gjandasher.ph>',
    REPLY_TO: 'support@gjandasher.ph',
    COMPANY_ADDRESS: 'Laguna, Philippines',
    RESEND_API_KEY: 're_test',
  });

  assert.equal(report.mailFromDomain, 'mail.gjandasher.ph');
  assert.equal(report.mailFromUsable, true);
  assert.equal(report.mailFromProblem, null);
  assert.equal(report.passwordResetConfigured, false);
});

test('describeDeliverability reports a missing sender', () => {
  const report = describeDeliverability({});

  assert.equal(report.mailFromDomain, null);
  assert.equal(report.mailFromUsable, false);
  assert.match(report.mailFromProblem, /missing/i);
});
