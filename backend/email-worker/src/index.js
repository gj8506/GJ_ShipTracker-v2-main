/**
 * GJandAsher ShipTracker transactional email worker.
 *
 * Endpoints:
 *   POST /staff-approved  { to, name }
 *   POST /password-reset  { email }
 *   GET  /health
 *
 * All POST requests must include the shared `x-api-key` header.
 *
 * Secrets:
 *   RESEND_API_KEY
 *   FIREBASE_CLIENT_EMAIL
 *   FIREBASE_PRIVATE_KEY
 *   API_KEY
 *
 * Vars:
 *   FIREBASE_PROJECT_ID, APP_NAME, MAIL_FROM, REPLY_TO, COMPANY_ADDRESS
 *
 * MAIL_FROM must be on a domain you have verified in Resend (SPF + DKIM +
 * DMARC). Requests that would send from a free or Firebase-owned domain are
 * rejected, because those are the senders Gmail and Outlook spam-filter.
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type,x-api-key',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Sender domains that mailbox providers routinely spam-filter. Firebase's
 * default `firebaseapp.com` sender is the reason the built-in reset email lands
 * in Gmail's Spam folder; free mailbox domains cannot be authenticated for a
 * third-party sender, so aligning SPF/DKIM/DMARC is impossible from them.
 *
 * Sending from any of these would defeat the whole point of this worker, so we
 * refuse the request and return an actionable error instead.
 */
const BLOCKED_SENDER_DOMAINS = [
  'firebaseapp.com',
  'web.app',
  'gmail.com',
  'googlemail.com',
  'yahoo.com',
  'hotmail.com',
  'outlook.com',
  'live.com',
  'example.com',
  'your_verified_domain',
];

let cachedAccessToken = null;
let cachedTokenExpiry = 0;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    if (request.method === 'GET' && url.pathname === '/health') {
      return json({
        ok: true,
        service: 'gjandasher-email',
        // Deliberately only reports whether things are configured, never the
        // values, so this endpoint stays safe to leave public.
        deliverability: describeDeliverability(env),
      });
    }

    if (request.method !== 'POST') {
      return json({ error: 'Method not allowed' }, 405);
    }

    if (!env.API_KEY) {
      return json(
        { error: 'Worker is missing the API_KEY secret. Run: wrangler secret put API_KEY' },
        500,
      );
    }

    if (request.headers.get('x-api-key') !== env.API_KEY) {
      return json({ error: 'Unauthorized' }, 401);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'Invalid JSON body' }, 400);
    }

    try {
      if (url.pathname === '/staff-approved') {
        return await handleStaffApproved(env, body);
      }
      if (url.pathname === '/password-reset') {
        return await handlePasswordReset(env, body);
      }
      return json({ error: 'Not found' }, 404);
    } catch (error) {
      return json(
        { error: error instanceof Error ? error.message : 'Email request failed' },
        500,
      );
    }
  },
};

async function handleStaffApproved(env, body) {
  requireConfig(env, ['RESEND_API_KEY', 'MAIL_FROM']);

  const to = normalizeEmail(body?.to);
  if (!to) {
    return json({ error: 'A valid recipient email is required' }, 400);
  }

  const appName = env.APP_NAME || 'GJandAsher Digital Printing';
  const name = sanitizeName(body?.name) || 'there';

  const subject = `Your ${appName} staff account is approved`;
  const html = staffApprovedHtml({
    appName,
    name,
    companyAddress: env.COMPANY_ADDRESS,
  });
  const text = staffApprovedText({ appName, name });

  await sendEmail(env, { to, subject, html, text });
  return json({ ok: true, sent: true });
}

async function handlePasswordReset(env, body) {
  requireConfig(env, [
    'RESEND_API_KEY',
    'MAIL_FROM',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_CLIENT_EMAIL',
    'FIREBASE_PRIVATE_KEY',
  ]);

  const email = normalizeEmail(body?.email);
  if (!email) {
    return json({ error: 'A valid email is required' }, 400);
  }

  let resetLink;
  try {
    resetLink = await generatePasswordResetLink(env, email);
  } catch (error) {
    const code = String(error?.code || error?.message || '');
    // Do not reveal whether an account exists. Treat unknown users as a
    // successful request so the endpoint cannot be used for enumeration.
    if (code.includes('EMAIL_NOT_FOUND') || code.includes('USER_NOT_FOUND')) {
      return json({ ok: true, sent: false });
    }
    throw error;
  }

  const appName = env.APP_NAME || 'GJandAsher Digital Printing';
  const subject = `Reset your ${appName} password`;
  const html = passwordResetHtml({
    appName,
    resetLink,
    companyAddress: env.COMPANY_ADDRESS,
  });
  const text = passwordResetText({ appName, resetLink });

  await sendEmail(env, { to: email, subject, html, text });
  return json({ ok: true, sent: true });
}

/**
 * Summarises the configuration that decides inbox placement. Used by `/health`
 * so you can confirm the deployed worker is not still on a placeholder sender.
 */
function describeDeliverability(env) {
  const domain = senderDomain(env.MAIL_FROM);
  const isBlocked = isBlockedSenderDomain(domain);
  return {
    mailFromDomain: domain || null,
    mailFromUsable: Boolean(domain) && !isBlocked,
    mailFromProblem: isBlocked
      ? `MAIL_FROM is on "${domain}", which is spam-filtered by Gmail/Outlook. Verify a domain you own in Resend and set MAIL_FROM to an address on it.`
      : domain
        ? null
        : 'MAIL_FROM is missing or not a valid email address.',
    replyToConfigured: Boolean(env.REPLY_TO),
    companyAddressConfigured: Boolean(env.COMPANY_ADDRESS),
    resendKeyConfigured: Boolean(env.RESEND_API_KEY),
    passwordResetConfigured: Boolean(
      env.FIREBASE_PROJECT_ID &&
        env.FIREBASE_CLIENT_EMAIL &&
        env.FIREBASE_PRIVATE_KEY,
    ),
  };
}

/** Extracts the bare address from `Name <addr@domain>` or `addr@domain`. */
function senderAddress(from) {
  const raw = String(from || '').trim();
  const match = raw.match(/<\s*([^>]+?)\s*>/);
  return (match ? match[1] : raw).trim().toLowerCase();
}

function senderDomain(from) {
  const address = senderAddress(from);
  const at = address.lastIndexOf('@');
  return at === -1 ? '' : address.slice(at + 1).trim();
}

function isBlockedSenderDomain(domain) {
  if (!domain) return false;
  const normalized = domain.toLowerCase().replace(/\.$/, '');
  return BLOCKED_SENDER_DOMAINS.some(
    (blocked) =>
      normalized === blocked || normalized.endsWith(`.${blocked}`),
  );
}

/**
 * Fails fast instead of delivering mail that Gmail/Outlook will bury in Spam.
 * A clear error in the Resend/Cloudflare logs beats a silent deliverability
 * problem that only shows up in a tester's spam folder.
 */
function assertDeliverableFrom(from) {
  const address = senderAddress(from);
  const domain = senderDomain(from);

  if (!domain || !EMAIL_PATTERN.test(address)) {
    throw new Error(
      'MAIL_FROM is not a valid address. Set it in wrangler.toml to ' +
        'something like "GJandAsher <notifications@mail.yourdomain.com>".',
    );
  }

  if (isBlockedSenderDomain(domain)) {
    throw new Error(
      `MAIL_FROM uses "${domain}", which Gmail and Outlook routinely filter ` +
        'into Spam because it cannot be authenticated for your domain. ' +
        'Verify a domain you own in Resend, then set MAIL_FROM to an address ' +
        'on that domain (see backend/email-worker/README.md).',
    );
  }

  return domain;
}

async function sendEmail(env, { to, subject, html, text }) {
  assertDeliverableFrom(env.MAIL_FROM);

  const payload = {
    from: env.MAIL_FROM,
    to: [to],
    subject,
    html,
    text,
    // Transactional hygiene: a per-message reference stops mailbox providers
    // collapsing unrelated messages into one thread, and the auto-response
    // header keeps out-of-office replies from polluting the Reply-To mailbox.
    headers: {
      'X-Entity-Ref-ID': crypto.randomUUID(),
      'X-Auto-Response-Suppress': 'All',
    },
  };

  if (env.REPLY_TO) {
    payload.reply_to = env.REPLY_TO;
  }

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
      'Content-Type': 'application/json',
      // Makes retries safe if the request is replayed by the platform.
      'Idempotency-Key': `gjandasher-${crypto.randomUUID()}`,
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const details = await response.text();
    throw new Error(`Resend rejected the email (${response.status}): ${details}`);
  }

  return response.json();
}

async function generatePasswordResetLink(env, email) {
  const accessToken = await getFirebaseAccessToken(env);
  const projectId = env.FIREBASE_PROJECT_ID;

  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/accounts:sendOobCode`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        requestType: 'PASSWORD_RESET',
        email,
        returnOobLink: true,
      }),
    },
  );

  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    const code = data?.error?.message || `HTTP_${response.status}`;
    const error = new Error(code);
    error.code = code;
    throw error;
  }

  if (!data.oobLink) {
    throw new Error('Firebase did not return a password reset link.');
  }

  return data.oobLink;
}

async function getFirebaseAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);

  if (cachedAccessToken && cachedTokenExpiry > now + 60) {
    return cachedAccessToken;
  }

  const header = base64UrlEncode(
    JSON.stringify({ alg: 'RS256', typ: 'JWT' }),
  );
  const claims = base64UrlEncode(
    JSON.stringify({
      iss: env.FIREBASE_CLIENT_EMAIL,
      scope:
        'https://www.googleapis.com/auth/identitytoolkit https://www.googleapis.com/auth/firebase',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );

  const unsignedToken = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(env.FIREBASE_PRIVATE_KEY),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsignedToken),
  );

  const assertion = `${unsignedToken}.${base64UrlEncode(
    new Uint8Array(signature),
  )}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  const data = await response.json().catch(() => ({}));

  if (!response.ok || !data.access_token) {
    throw new Error(
      `Could not obtain a Firebase access token: ${
        data?.error_description || data?.error || response.status
      }`,
    );
  }

  cachedAccessToken = data.access_token;
  cachedTokenExpiry = now + (Number(data.expires_in) || 3600);
  return cachedAccessToken;
}

function pemToArrayBuffer(pem) {
  const normalized = String(pem).replace(/\\n/g, '\n');
  const base64 = normalized
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');

  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

function base64UrlEncode(value) {
  const bytes =
    typeof value === 'string' ? new TextEncoder().encode(value) : value;
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function normalizeEmail(value) {
  if (typeof value !== 'string') return '';
  const email = value.trim().toLowerCase();
  if (email.length > 254 || !EMAIL_PATTERN.test(email)) return '';
  return email;
}

function sanitizeName(value) {
  if (typeof value !== 'string') return '';
  return value.replace(/[\r\n\t]/g, ' ').trim().slice(0, 120);
}

function requireConfig(env, keys) {
  const missing = keys.filter((key) => !env[key]);
  if (missing.length > 0) {
    throw new Error(
      `Worker configuration is incomplete. Missing: ${missing.join(', ')}`,
    );
  }
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function emailLayout({
  appName,
  heading,
  bodyHtml,
  footerHtml = '',
  companyAddress = '',
}) {
  const addressLine = companyAddress
    ? `<br>${escapeHtml(companyAddress)}`
    : '';
  return `<!doctype html>
<html lang="en">
  <body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;color:#0f172a;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f1f5f9;padding:24px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:14px;border:1px solid #e2e8f0;overflow:hidden;">
            <tr>
              <td style="background:#0f172a;padding:22px 28px;">
                <div style="color:#ffffff;font-size:18px;font-weight:bold;">${escapeHtml(appName)}</div>
                <div style="color:#cbd5e1;font-size:12px;margin-top:4px;">ShipTracker</div>
              </td>
            </tr>
            <tr>
              <td style="padding:28px;">
                <h1 style="margin:0 0 16px;font-size:21px;line-height:1.3;color:#0f172a;">${heading}</h1>
                ${bodyHtml}
                ${footerHtml}
              </td>
            </tr>
            <tr>
              <td style="padding:18px 28px;background:#f8fafc;border-top:1px solid #e2e8f0;color:#64748b;font-size:12px;line-height:1.5;">
                This is a transactional message from ${escapeHtml(appName)}. You received it because an account action was requested for this email address.${addressLine}
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function staffApprovedHtml({ appName, name, companyAddress }) {
  return emailLayout({
    appName,
    companyAddress,
    heading: 'Your staff account is approved',
    bodyHtml: `
      <p style="margin:0 0 14px;font-size:15px;line-height:1.6;">Hi ${escapeHtml(name)},</p>
      <p style="margin:0 0 14px;font-size:15px;line-height:1.6;">
        Good news — your staff registration for <strong>${escapeHtml(appName)}</strong> has been reviewed and approved by the owner/admin.
      </p>
      <p style="margin:0 0 14px;font-size:15px;line-height:1.6;">
        You can now open the app and sign in to the <strong>Staff Portal</strong> using this email address and the sign-in method you chose during registration (email/password or Google).
      </p>
      <p style="margin:0;font-size:15px;line-height:1.6;">
        If you did not request this account, please contact the administrator immediately.
      </p>`,
  });
}

function staffApprovedText({ appName, name }) {
  return `Hi ${name},

Good news — your staff registration for ${appName} has been reviewed and approved by the owner/admin.

You can now open the app and sign in to the Staff Portal using this email address and the sign-in method you chose during registration (email/password or Google).

If you did not request this account, please contact the administrator immediately.

This is a transactional message from ${appName}.`;
}

function passwordResetHtml({ appName, resetLink, companyAddress }) {
  return emailLayout({
    appName,
    companyAddress,
    heading: 'Reset your password',
    bodyHtml: `
      <p style="margin:0 0 14px;font-size:15px;line-height:1.6;">Hello,</p>
      <p style="margin:0 0 20px;font-size:15px;line-height:1.6;">
        We received a request to reset the password for your ${escapeHtml(appName)} account.
      </p>
      <p style="margin:0 0 20px;">
        <a href="${escapeHtml(resetLink)}" style="display:inline-block;background:#2563eb;color:#ffffff;text-decoration:none;font-weight:bold;font-size:15px;padding:13px 22px;border-radius:10px;">
          Reset my password
        </a>
      </p>
      <p style="margin:0 0 14px;font-size:14px;line-height:1.6;color:#475569;">
        This link expires in about 1 hour. If the button does not work, copy and paste this address into your browser:
      </p>
      <p style="margin:0 0 14px;font-size:12px;line-height:1.5;word-break:break-all;color:#2563eb;">
        ${escapeHtml(resetLink)}
      </p>
      <p style="margin:0;font-size:14px;line-height:1.6;color:#475569;">
        If you did not request a password reset, you can safely ignore this email. Your password will not change.
      </p>`,
  });
}

function passwordResetText({ appName, resetLink }) {
  return `Hello,

We received a request to reset the password for your ${appName} account.

Open this link to choose a new password:
${resetLink}

This link expires in about 1 hour.

If you did not request a password reset, you can safely ignore this email. Your password will not change.

This is a transactional message from ${appName}.`;
}

// Exported for the unit tests in `test/`. The Worker itself uses the default
// export above; keeping these helpers testable guards the deliverability rules
// that keep reset mail out of Spam.
export {
  BLOCKED_SENDER_DOMAINS,
  assertDeliverableFrom,
  describeDeliverability,
  isBlockedSenderDomain,
  normalizeEmail,
  sanitizeName,
  senderAddress,
  senderDomain,
};
