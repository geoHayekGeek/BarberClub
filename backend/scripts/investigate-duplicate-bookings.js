#!/usr/bin/env node
/**
 * Determines WHY some services produce several bookings for the same client on
 * the same day: two slots for ONE visit, or two DIFFERENT people.
 *
 * That distinction decides the fix. Same barber + back-to-back slots means the
 * loyalty sync is double-counting one visit. Different barbers or identical
 * start times means they are separate customers and the current behaviour is
 * correct.
 *
 * Reads the WEBSITE (reservation) database read-only, via Prisma $queryRawUnsafe
 * so no extra dependency is needed.
 *
 * Usage:
 *   WEBSITE_DATABASE_URL='postgresql://...' node scripts/investigate-duplicate-bookings.js
 *   WEBSITE_DATABASE_URL='...' node scripts/investigate-duplicate-bookings.js --service "Meches" --control "Coupe Homme"
 *
 * Client ids are replaced with anonymous refs (C1, C2...). No names, emails or
 * phone numbers are read or printed.
 */
const { PrismaClient } = require('@prisma/client');

const argv = process.argv.slice(2);
function flag(name, dflt) {
  const i = argv.indexOf(name);
  return i !== -1 ? argv[i + 1] : dflt;
}
const TARGET = flag('--service', 'Meches');
const CONTROL = flag('--control', 'Coupe Homme');

const url = process.env.WEBSITE_DATABASE_URL;
if (!url) {
  console.error('Set WEBSITE_DATABASE_URL - copy it from the Railway variables of the API service.');
  console.error("Example:  WEBSITE_DATABASE_URL='postgresql://...' node scripts/investigate-duplicate-bookings.js");
  process.exit(1);
}

const db = new PrismaClient({ datasources: { db: { url } }, log: ['error'] });

const anon = new Map();
const ref = (id) => {
  if (!anon.has(id)) anon.set(id, 'C' + (anon.size + 1));
  return anon.get(id);
};

const fmt = (v) => {
  if (v === null || v === undefined) return '-';
  if (v instanceof Date) return v.toISOString().replace('T', ' ').slice(0, 19);
  return String(v);
};

async function columnsOf(table) {
  return db.$queryRawUnsafe(
    `SELECT column_name, data_type FROM information_schema.columns
     WHERE table_name = $1 ORDER BY ordinal_position`,
    table
  );
}

async function analyse(serviceName, label, cols) {
  console.log(`\n${'='.repeat(78)}`);
  console.log(` ${label}: "${serviceName}"`);
  console.log('='.repeat(78));

  const has = (c) => cols.includes(c);
  const timeCols = ['date', 'start_date_time', 'start_time', 'starts_at', 'start',
    'end_date_time', 'end_time', 'ends_at', 'duration', 'duration_minutes'].filter(has);
  const extraCols = ['resource_id', 'barber_id', 'staff_id', 'employee_id', 'branch_id'].filter(has);

  const select = ['b.id', 'b.client_id', 'COALESCE(b.price,0) AS price', 'b.created_at']
    .concat(timeCols.map((c) => `b.${c}`))
    .concat(extraCols.map((c) => `b.${c}`))
    .join(', ');

  const rows = await db.$queryRawUnsafe(
    `SELECT ${select}
     FROM bookings b LEFT JOIN services s ON s.id = b.service_id
     WHERE s.name = $1 AND b.status = 'completed' AND b.deleted_at IS NULL
     ORDER BY b.client_id, ${has('date') ? 'b.date' : 'b.created_at'}`,
    serviceName
  );

  console.log(`completed bookings: ${rows.length}`);
  console.log(`time columns:  ${timeCols.join(', ') || '(none)'}`);
  console.log(`actor columns: ${extraCols.join(', ') || '(none)'}`);
  if (rows.length === 0) {
    console.log('\nNo rows - check the exact service name spelling.');
    return;
  }

  const dayKey = (r) => (r.date ? fmt(r.date).slice(0, 10) : fmt(r.created_at).slice(0, 10));
  const groups = new Map();
  for (const r of rows) {
    const k = `${r.client_id}|${dayKey(r)}`;
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k).push(r);
  }

  const multi = [...groups.entries()].filter(([, a]) => a.length > 1);
  const pct = groups.size ? ((multi.length / groups.size) * 100).toFixed(0) : '0';
  console.log(`client-days: ${groups.size}   with >1 booking: ${multi.length} (${pct}%)`);

  console.log('\n--- duplicate groups (up to 8) ---');
  for (const [k, arr] of multi.slice(0, 8)) {
    const [cid, day] = k.split('|');
    console.log(`\n  ${ref(cid)} on ${day} - ${arr.length} bookings`);
    for (const r of arr) {
      const t = timeCols.map((c) => `${c}=${fmt(r[c])}`).join('  ');
      const x = extraCols.map((c) => `${c}=${fmt(r[c])}`).join('  ');
      console.log(`    price=${fmt(r.price)}  ${t}  ${x}`);
    }
  }

  const resCol = extraCols.find((c) => /resource|barber|staff|employee/.test(c));
  const startCol = timeCols.find((c) => /start/.test(c)) || (has('date') ? 'date' : null);
  let sameRes = 0, diffRes = 0, sameStart = 0, within90 = 0, farApart = 0;
  for (const [, arr] of multi) {
    if (resCol) {
      new Set(arr.map((r) => String(r[resCol]))).size === 1 ? sameRes++ : diffRes++;
    }
    if (startCol) {
      const ts = arr.map((r) => new Date(r[startCol]).getTime()).filter((n) => !Number.isNaN(n)).sort((a, b) => a - b);
      if (ts.length > 1) {
        const gap = ts[1] - ts[0];
        if (gap === 0) sameStart++;
        else if (gap <= 90 * 60 * 1000) within90++;
        else farApart++;
      }
    }
  }

  console.log(`\n--- pattern over ${multi.length} duplicate groups ---`);
  if (resCol) {
    console.log(`  same ${resCol}:       ${sameRes}`);
    console.log(`  different ${resCol}:  ${diffRes}`);
  }
  if (startCol) {
    console.log(`  identical start:      ${sameStart}`);
    console.log(`  <= 90 min apart:      ${within90}`);
    console.log(`  > 90 min apart:       ${farApart}`);
  }
}

(async () => {
  console.log('Website (reservation) database - read only\n');
  const bcols = await columnsOf('bookings');
  console.log('=== bookings table columns ===');
  bcols.forEach((c) => console.log(`  ${String(c.column_name).padEnd(24)} ${c.data_type}`));
  const cols = bcols.map((c) => c.column_name);

  await analyse(TARGET, 'TARGET', cols);
  await analyse(CONTROL, 'CONTROL', cols);

  console.log('\n--- interpretation ---');
  console.log('  same barber + slots <=90 min apart -> ONE visit split across slots');
  console.log('                                        => loyalty double-counts, needs fixing');
  console.log('  different barbers OR identical start -> DIFFERENT people');
  console.log('                                        => loyalty is already correct');
})()
  .catch((e) => {
    console.error('FAILED:', e.message);
    process.exitCode = 1;
  })
  .finally(() => db.$disconnect().catch(() => {}));
