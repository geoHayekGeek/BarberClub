#!/usr/bin/env node
/**
 * Measures the ACTUAL access-token lifetime of the deployed API by logging in
 * and reading the JWT's own iat/exp claims. Use this when you cannot see the
 * Railway dashboard variables.
 *
 * Prints only the computed lifetimes - never the tokens or any account data.
 *
 * Usage:
 *   node scripts/check-token-ttl.js
 *   node scripts/check-token-ttl.js --email me@example.com
 *   PASSWORD='...' node scripts/check-token-ttl.js --email me@example.com
 *   node scripts/check-token-ttl.js --url http://localhost:3000
 *
 * Tip: prefix the command with a space to keep it out of shell history when
 * using PASSWORD=...
 */
const https = require('https');
const http = require('http');
const readline = require('readline');

const argv = process.argv.slice(2);
function flag(name) {
  const i = argv.indexOf(name);
  return i !== -1 ? argv[i + 1] : null;
}

// The app talks to two independent backends, each with its own login
// contract. --reservation targets the booking API instead of the app API.
const RESERVATION = argv.includes('--reservation');

const TARGETS = {
  app: {
    label: 'APP API (Railway)',
    base: 'https://barberclub-production-d46a.up.railway.app',
    path: '/api/v1/auth/login',
    body: (email, password) => ({ email, password }),
    accessKeys: ['accessToken', 'access_token'],
    refreshKeys: ['refreshToken', 'refresh_token'],
  },
  reservation: {
    label: 'RESERVATION API',
    base: 'https://api.barberclub-grenoble.fr/api',
    path: '/auth/login',
    body: (email, password) => ({ email, password, type: 'client' }),
    accessKeys: ['access_token', 'accessToken'],
    refreshKeys: ['refresh_token', 'refreshToken'],
  },
};

const TARGET = RESERVATION ? TARGETS.reservation : TARGETS.app;
const BASE = flag('--url') || TARGET.base;

const CR = 13;
const LF = 10;
const EOT = 4;
const ETX = 3;
const BACKSPACE = 8;
const DEL = 127;

function askPlain(question) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

// Read a line from a TTY without echoing. Deliberately avoids readline:
// mixing readline with raw-mode stdin is what broke the first version
// (it resolved instantly with an empty string).
function askHidden(question) {
  return new Promise((resolve, reject) => {
    const stdin = process.stdin;
    if (!stdin.isTTY) {
      reject(new Error('stdin is not a TTY - use PASSWORD=... instead'));
      return;
    }
    process.stdout.write(question);
    stdin.setRawMode(true);
    stdin.resume();
    let buf = '';
    const cleanup = () => {
      stdin.setRawMode(false);
      stdin.pause();
      stdin.removeListener('data', onData);
    };
    const onData = (chunk) => {
      for (const byte of chunk) {
        if (byte === CR || byte === LF || byte === EOT) {
          cleanup();
          process.stdout.write('\n');
          resolve(buf);
          return;
        }
        if (byte === ETX) {
          cleanup();
          process.stdout.write('\n');
          process.exit(130);
        }
        if (byte === BACKSPACE || byte === DEL) {
          buf = buf.slice(0, -1);
        } else if (byte >= 32) {
          buf += String.fromCharCode(byte);
        }
      }
    };
    stdin.on('data', onData);
  });
}

function post(urlStr, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(urlStr);
    const lib = u.protocol === 'https:' ? https : http;
    const payload = JSON.stringify(body);
    const req = lib.request(
      {
        hostname: u.hostname,
        port: u.port || (u.protocol === 'https:' ? 443 : 80),
        path: u.pathname,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => resolve({ status: res.statusCode, body: data }));
      }
    );
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

function claims(jwt) {
  const parts = String(jwt).split('.');
  if (parts.length !== 3) return null;
  try {
    const b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(Buffer.from(b64, 'base64').toString('utf8'));
  } catch {
    return null;
  }
}

function human(seconds) {
  if (seconds % 86400 === 0) return `${seconds / 86400}d`;
  if (seconds % 3600 === 0) return `${seconds / 3600}h`;
  if (seconds % 60 === 0) return `${seconds / 60}m`;
  return `${seconds}s`;
}

function report(label, token) {
  const c = claims(token);
  if (!c) {
    console.log(`${label}: not a decodable JWT (opaque token?)`);
    return;
  }
  if (!c.exp) {
    console.log(`${label}: no exp claim - token does not self-expire`);
    return;
  }
  if (!c.iat) {
    const secondsLeft = c.exp - Math.floor(Date.now() / 1000);
    console.log(`${label}: no iat claim; ${human(secondsLeft)} remaining from now`);
    return;
  }
  const ttl = c.exp - c.iat;
  console.log(`${label}: ${human(ttl)}  (${ttl}s)`);
}

function pick(obj, keys) {
  for (const k of keys) {
    if (typeof obj[k] === 'string' && obj[k].length > 0) return obj[k];
  }
  return null;
}

(async () => {
  console.log(`${TARGET.label}`);
  console.log(`Target: ${BASE}${TARGET.path}\n`);

  const email = flag('--email') || (await askPlain('Email: '));
  if (!email) {
    console.error('No email provided.');
    process.exit(1);
  }

  const password = process.env.PASSWORD || (await askHidden('Password (hidden, then Enter): '));
  if (!password) {
    console.error('\nNo password captured - aborting before hitting the API.');
    process.exit(1);
  }

  const res = await post(`${BASE}${TARGET.path}`, TARGET.body(email, password));

  if (res.status !== 200) {
    console.error(`\nLogin failed (HTTP ${res.status}).`);
    if (res.status === 401) {
      console.error('401 means the credentials were rejected by THIS backend.');
      console.error('The app has two independent logins - a password that works on');
      console.error('one backend may not exist or may differ on the other.');
    }
    process.exit(1);
  }

  let parsed;
  try {
    parsed = JSON.parse(res.body);
  } catch {
    console.error('Unparseable response body.');
    process.exit(1);
  }

  const payload = parsed.data ?? parsed;
  const access = pick(payload, TARGET.accessKeys);
  const refresh = pick(payload, TARGET.refreshKeys);

  if (!access) {
    console.error('Response had no access token. Keys seen: ' + Object.keys(payload).join(', '));
    process.exit(1);
  }

  console.log('');
  report('ACCESS  token lifetime', access);
  if (refresh) report('REFRESH token lifetime', refresh);

  console.log('\nHeads up: this login issued a NEW refresh token for this account,');
  console.log('so it is no longer part of the revoked set.');
})().catch((e) => {
  console.error('FAILED:', e.message);
  process.exit(1);
});
