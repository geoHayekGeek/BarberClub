/**
 * Multi-slot service loyalty tests.
 *
 * Meches is booked as two consecutive slots for ONE visit, and the client pays
 * once. These tests pin down that only one slot earns loyalty, and - just as
 * importantly - that families booking the SAME service on the SAME day still
 * earn for every haircut they pay for.
 */

import {
  findExtraSlotBookingIds,
  isMultiSlotService,
  type CompletedWebsiteBookingRow,
} from '../src/modules/loyalty_v2/bookingRewards';

type Grant = {
  websiteBookingId: string;
  appUserId: string | null;
  loyaltyAccountId: string | null;
  pointsAwarded: number;
  appointmentsAwarded: number;
};

function booking(
  id: string,
  clientId: string,
  serviceName: string,
  day: string,
  price = 4000
): CompletedWebsiteBookingRow {
  return {
    id,
    client_id: clientId,
    price,
    service_name: serviceName,
    created_at: new Date(`${day}T09:00:00.000Z`),
    date: new Date(`${day}T00:00:00.000Z`),
  };
}

function grants(...ids: string[]): Map<string, Grant> {
  return new Map(
    ids.map((id) => [
      id,
      {
        websiteBookingId: id,
        appUserId: 'user-1',
        loyaltyAccountId: 'acct-1',
        pointsAwarded: 40,
        appointmentsAwarded: 1,
      },
    ])
  );
}

describe('isMultiSlotService', () => {
  it('matches Meches regardless of accent or case', () => {
    expect(isMultiSlotService('Meches')).toBe(true);
    expect(isMultiSlotService('Mèches')).toBe(true);
    expect(isMultiSlotService('MECHES')).toBe(true);
    expect(isMultiSlotService('  mèches  ')).toBe(true);
  });

  it('does not match ordinary services', () => {
    expect(isMultiSlotService('Coupe Homme')).toBe(false);
    expect(isMultiSlotService('Coupe + Barbe')).toBe(false);
    expect(isMultiSlotService('Barbe Uniquement')).toBe(false);
    expect(isMultiSlotService(null)).toBe(false);
    expect(isMultiSlotService('')).toBe(false);
  });
});

describe('findExtraSlotBookingIds', () => {
  it('collapses two Meches slots on the same day into one', () => {
    const rows = [
      booking('b1', 'client-A', 'Meches', '2026-03-02'),
      booking('b2', 'client-A', 'Meches', '2026-03-02'),
    ];
    const extras = findExtraSlotBookingIds(rows, grants());
    expect(extras.size).toBe(1);
    expect(extras.has('b2')).toBe(true);
    expect(extras.has('b1')).toBe(false);
  });

  it('collapses a four-slot Meches day down to one', () => {
    const rows = ['b1', 'b2', 'b3', 'b4'].map((id) =>
      booking(id, 'client-A', 'Meches', '2026-03-02')
    );
    const extras = findExtraSlotBookingIds(rows, grants());
    expect(extras.size).toBe(3);
    expect(extras.has('b1')).toBe(false);
  });

  it('leaves a single Meches booking alone', () => {
    const rows = [booking('b1', 'client-A', 'Meches', '2026-03-02')];
    expect(findExtraSlotBookingIds(rows, grants()).size).toBe(0);
  });

  it('does NOT collapse a family booking the same service on the same day', () => {
    // Three Coupe Homme on one account: father and two sons, three payments.
    const rows = [
      booking('b1', 'client-A', 'Coupe Homme', '2026-03-02', 2700),
      booking('b2', 'client-A', 'Coupe Homme', '2026-03-02', 2700),
      booking('b3', 'client-A', 'Coupe Homme', '2026-03-02', 2700),
    ];
    expect(findExtraSlotBookingIds(rows, grants()).size).toBe(0);
  });

  it('treats Meches on different days as separate visits', () => {
    const rows = [
      booking('b1', 'client-A', 'Meches', '2026-03-02'),
      booking('b2', 'client-A', 'Meches', '2026-03-09'),
    ];
    expect(findExtraSlotBookingIds(rows, grants()).size).toBe(0);
  });

  it('treats Meches for different clients on one day as separate visits', () => {
    const rows = [
      booking('b1', 'client-A', 'Meches', '2026-03-02'),
      booking('b2', 'client-B', 'Meches', '2026-03-02'),
    ];
    expect(findExtraSlotBookingIds(rows, grants()).size).toBe(0);
  });

  it('keeps the already-granted slot so re-running the sync is idempotent', () => {
    // b2 was rewarded on an earlier run; b1 must be skipped, not double-awarded.
    const rows = [
      booking('b1', 'client-A', 'Meches', '2026-03-02'),
      booking('b2', 'client-A', 'Meches', '2026-03-02'),
    ];
    const extras = findExtraSlotBookingIds(rows, grants('b2'));
    expect(extras.has('b1')).toBe(true);
    expect(extras.has('b2')).toBe(false);
  });

  it('ignores rows with no client id', () => {
    const rows = [
      { ...booking('b1', 'x', 'Meches', '2026-03-02'), client_id: null },
      { ...booking('b2', 'x', 'Meches', '2026-03-02'), client_id: null },
    ];
    expect(findExtraSlotBookingIds(rows, grants()).size).toBe(0);
  });

  it('falls back to created_at when the appointment date is missing', () => {
    const rows = [
      { ...booking('b1', 'client-A', 'Meches', '2026-03-02'), date: null },
      { ...booking('b2', 'client-A', 'Meches', '2026-03-02'), date: null },
    ];
    expect(findExtraSlotBookingIds(rows, grants()).size).toBe(1);
  });

  it('does not touch other services while collapsing Meches', () => {
    const rows = [
      booking('m1', 'client-A', 'Meches', '2026-03-02'),
      booking('m2', 'client-A', 'Meches', '2026-03-02'),
      booking('c1', 'client-A', 'Coupe Homme', '2026-03-02', 2700),
      booking('c2', 'client-A', 'Coupe Homme', '2026-03-02', 2700),
    ];
    const extras = findExtraSlotBookingIds(rows, grants());
    expect([...extras]).toEqual(['m2']);
  });
});
