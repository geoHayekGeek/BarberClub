#!/usr/bin/env node
/**
 * Rescue users stuck in the "mode invité / Se connecter goes Home" dead end.
 *
 * Background: the app keeps two independent sessions (this backend + the
 * reservation API). If the reservation session dies but the app session
 * survives, the router refuses to show /login and the user can never sign in
 * again. Revoking their refresh token here forces the app to a clean
 * unauthenticated state, which unblocks the login screen.
 *
 * ADMIN accounts are skipped by default so barbers are not logged out
 * mid-shift while using the QR scanner.
 *
 * Usage:
 *   node scripts/rescue-stuck-sessions.js                    # dry run, all non-admins
 *   node scripts/rescue-stuck-sessions.js --apply            # execute
 *   node scripts/rescue-stuck-sessions.js --email a@b.c      # single user, dry run
 *   node scripts/rescue-stuck-sessions.js --email a@b.c --apply
 *   node scripts/rescue-stuck-sessions.js --include-admins --apply
 *
 * Effect is gradual: access tokens stay valid for up to 15 minutes.
 */
const { PrismaClient } = require('@prisma/client');

const argv = process.argv.slice(2);
const apply = argv.includes('--apply');
const includeAdmins = argv.includes('--include-admins');
const emailIdx = argv.indexOf('--email');
const email = emailIdx !== -1 ? argv[emailIdx + 1] : null;

if (emailIdx !== -1 && !email) {
  console.error('--email requires a value');
  process.exit(1);
}

const prisma = new PrismaClient();

async function main() {
  const where = { revokedAt: null };

  if (email) {
    const user = await prisma.user.findFirst({
      where: { email },
      select: { id: true, role: true },
    });
    if (!user) {
      console.error('No user found for that email. Nothing to do.');
      process.exit(1);
    }
    where.userId = user.id;
    console.log(`Scope: single user (role=${user.role})`);
  } else if (!includeAdmins) {
    const admins = await prisma.user.findMany({
      where: { role: 'ADMIN' },
      select: { id: true },
    });
    if (admins.length > 0) {
      where.userId = { notIn: admins.map((a) => a.id) };
    }
    console.log(`Scope: all non-admin users (${admins.length} admin(s) skipped)`);
  } else {
    console.log('Scope: ALL users, including admins');
  }

  const tokens = await prisma.refreshToken.count({ where });
  const distinct = await prisma.refreshToken.groupBy({ by: ['userId'], where });

  console.log(`Active refresh tokens matched: ${tokens}`);
  console.log(`Distinct users affected:       ${distinct.length}`);

  if (tokens === 0) {
    console.log('\nNothing to revoke.');
    return;
  }

  if (!apply) {
    console.log('\nDRY RUN — nothing changed. Re-run with --apply to execute.');
    return;
  }

  const result = await prisma.refreshToken.updateMany({
    where,
    data: { revokedAt: new Date() },
  });

  console.log(`\nRevoked ${result.count} refresh token(s).`);
  console.log('Users will be signed out as their access tokens expire (<=15 min),');
  console.log('then can log in again normally.');
}

main()
  .catch((e) => {
    console.error('FAILED:', e.message);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
