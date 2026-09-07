#!/usr/bin/env node
/**
 * Read-only audit of how many loyalty points each reservation actually gave.
 *
 * pointsFromPrice() guesses units: values under 100 are treated as euros,
 * 100 and above as cents. This reports what that produced on real data and
 * flags rows where the guess is likely wrong.
 *
 * Prints aggregate numbers only - no names, emails or user identifiers.
 *
 * Usage: node scripts/audit-points-awarded.js
 */
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

function pointsFromPrice(price) {
  if (!Number.isFinite(price) || price <= 0) return 0;
  const n = Math.floor(price);
  return n < 100 ? n : Math.floor(n / 100);
}

function histogram(label, values) {
  console.log(`\n--- ${label} (n=${values.length}) ---`);
  if (values.length === 0) {
    console.log('  no rows');
    return;
  }
  const buckets = {
    '0': 0, '1-9': 0, '10-49': 0, '50-99': 0,
    '100-999': 0, '1000-9999': 0, '10000+': 0,
  };
  for (const v of values) {
    if (v === 0) buckets['0']++;
    else if (v < 10) buckets['1-9']++;
    else if (v < 50) buckets['10-49']++;
    else if (v < 100) buckets['50-99']++;
    else if (v < 1000) buckets['100-999']++;
    else if (v < 10000) buckets['1000-9999']++;
    else buckets['10000+']++;
  }
  for (const [k, n] of Object.entries(buckets)) {
    if (n > 0) console.log(`  ${k.padEnd(12)} ${n}`);
  }
  const sorted = [...values].sort((a, b) => a - b);
  console.log(`  min=${sorted[0]}  median=${sorted[Math.floor(sorted.length / 2)]}  max=${sorted[sorted.length - 1]}`);
}

(async () => {
  // 1. The audit trail: price -> points actually awarded.
  const grants = await prisma.websiteBookingLoyaltyGrant.findMany({
    select: { bookingPrice: true, pointsAwarded: true },
  });

  console.log('=========================================================');
  console.log(' WEBSITE BOOKING GRANTS - price vs points actually given');
  console.log('=========================================================');
  histogram('bookingPrice values', grants.map((g) => g.bookingPrice));
  histogram('pointsAwarded values', grants.map((g) => g.pointsAwarded));

  // Distinct pairs, most common first.
  const pairs = new Map();
  for (const g of grants) {
    const key = `${g.bookingPrice}->${g.pointsAwarded}`;
    pairs.set(key, (pairs.get(key) || 0) + 1);
  }
  console.log('\n--- distinct price -> points pairs (top 25 by frequency) ---');
  [...pairs.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 25)
    .forEach(([k, n]) => {
      const [price, pts] = k.split('->').map(Number);
      const ratio = pts > 0 ? (price / pts).toFixed(1) : 'n/a';
      console.log(`  ${String(price).padStart(7)} -> ${String(pts).padStart(5)} pts   x${String(n).padStart(4)}   ratio ${ratio}`);
    });

  // 2. Rows that crossed the unit-guessing cliff.
  const cliff = grants.filter((g) => g.bookingPrice >= 100);
  const belowCliff = grants.filter((g) => g.bookingPrice > 0 && g.bookingPrice < 100);
  console.log('\n--- the 100 cliff ---');
  console.log(`  priced <100  (treated as EUROS, 1:1):        ${belowCliff.length}`);
  console.log(`  priced >=100 (treated as CENTS, divided 100): ${cliff.length}`);

  // 3. If prices are really euros, how much was under-credited?
  const lost = cliff.reduce((sum, g) => sum + (g.bookingPrice - g.pointsAwarded), 0);
  console.log(`\n  If those >=100 values are actually EUROS, members were`);
  console.log(`  under-credited by ${lost} points in total.`);

  // 4. Cross-check that stored points match the current function.
  const mismatched = grants.filter(
    (g) => g.pointsAwarded !== pointsFromPrice(g.bookingPrice)
  );
  console.log(`\n  rows whose stored points disagree with pointsFromPrice(): ${mismatched.length}`);

  // 5. Offer prices (the admin QR-scan path).
  const offers = await prisma.offer.findMany({ select: { price: true } });
  console.log('\n=========================================================');
  console.log(' OFFERS - the admin QR scan path');
  console.log('=========================================================');
  histogram('Offer.price values', offers.map((o) => o.price));
  const offersOverCliff = offers.filter((o) => o.price >= 100);
  console.log(`\n  offers priced >=100 (would be divided by 100): ${offersOverCliff.length} of ${offers.length}`);
  if (offersOverCliff.length > 0) {
    console.log('  sample of those prices -> points they would give:');
    offersOverCliff.slice(0, 10).forEach((o) => {
      console.log(`    ${String(o.price).padStart(7)} -> ${pointsFromPrice(o.price)} pts`);
    });
  }

  // 6. Booking prices.
  const bookings = await prisma.booking.findMany({
    where: { price: { not: null } },
    select: { price: true },
  });
  console.log('\n=========================================================');
  console.log(' BOOKINGS');
  console.log('=========================================================');
  histogram('Booking.price values', bookings.map((b) => b.price));
})()
  .catch((e) => {
    console.error('FAILED:', e.message);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
