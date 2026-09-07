#!/usr/bin/env node
/**
 * Read-only: lists every service/cut and how many loyalty points it awards.
 *
 * Sources:
 *   WebsiteBookingLoyaltyGrant - real awards from website bookings
 *   Offer                      - the admin QR-scan catalogue
 *
 * Prints service names, prices and points only - no customer data.
 *
 * Usage: node scripts/points-per-service.js
 */
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

function pad(s, n) {
  return String(s).padEnd(n);
}
function padL(s, n) {
  return String(s).padStart(n);
}

(async () => {
  // ---- 1. Website bookings: what was actually awarded, per service ----
  const grants = await prisma.websiteBookingLoyaltyGrant.findMany({
    select: { serviceName: true, bookingPrice: true, pointsAwarded: true },
  });

  const byService = new Map();
  for (const g of grants) {
    const name = (g.serviceName || '(unnamed)').trim();
    if (!byService.has(name)) byService.set(name, new Map());
    const variants = byService.get(name);
    const key = `${g.bookingPrice}|${g.pointsAwarded}`;
    variants.set(key, (variants.get(key) || 0) + 1);
  }

  console.log('==========================================================================');
  console.log(' POINTS PER SERVICE - website bookings (actual awards)');
  console.log('==========================================================================');
  console.log(`${pad('SERVICE', 42)} ${padL('PRICE', 9)} ${padL('POINTS', 7)} ${padL('BOOKINGS', 9)}`);
  console.log('-'.repeat(74));

  const rows = [];
  for (const [name, variants] of byService) {
    for (const [key, count] of variants) {
      const [price, points] = key.split('|').map(Number);
      rows.push({ name, price, points, count });
    }
  }
  rows.sort((a, b) => b.count - a.count);
  for (const r of rows) {
    const euros = (r.price / 100).toFixed(2);
    console.log(
      `${pad(r.name.slice(0, 42), 42)} ${padL(euros + ' EUR', 9)} ${padL(r.points, 7)} ${padL(r.count, 9)}`
    );
  }

  const totalBookings = rows.reduce((s, r) => s + r.count, 0);
  const totalPoints = rows.reduce((s, r) => s + r.points * r.count, 0);
  console.log('-'.repeat(74));
  console.log(`${pad('TOTAL', 42)} ${padL('', 9)} ${padL(totalPoints, 7)} ${padL(totalBookings, 9)}`);
  console.log(`\ndistinct services: ${byService.size}`);
  console.log(`average points per booking: ${(totalPoints / totalBookings).toFixed(1)}`);

  // ---- 2. Offers catalogue (admin QR scan path) ----
  const offers = await prisma.offer.findMany({
    select: { title: true, price: true },
    orderBy: { price: 'asc' },
  });

  console.log('\n==========================================================================');
  console.log(' POINTS PER OFFER - admin QR scan catalogue');
  console.log('==========================================================================');
  console.log(`${pad('OFFER', 52)} ${padL('PRICE', 9)} ${padL('POINTS', 7)}`);
  console.log('-'.repeat(72));
  for (const o of offers) {
    // Offer.price is stored in euros, so points == price (values are all <100).
    const points = o.price < 100 ? o.price : Math.floor(o.price / 100);
    const warn = o.price >= 100 ? '  <-- CLIFF: divided by 100' : '';
    console.log(
      `${pad((o.title || '(untitled)').slice(0, 52), 52)} ${padL(o.price + ' EUR', 9)} ${padL(points, 7)}${warn}`
    );
  }
  console.log(`\ndistinct offers: ${offers.length}`);
})()
  .catch((e) => {
    console.error('FAILED:', e.message);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
