/**
 * Loyalty rank logic.
 *
 * Points are spendable currency. Rank is deliberately separate and is based on
 * the member's lifetime number of completed appointments.
 */

export const LOYALTY_RANKS = ['Bronze', 'Silver', 'Gold', 'Diamond', 'Platinum'] as const;
export type LoyaltyRankName = (typeof LOYALTY_RANKS)[number];

// Keep the old "tier" exports as aliases because the current mobile screen
// still names this concept tier. New code should prefer rank terminology.
export const LOYALTY_TIERS = LOYALTY_RANKS;
export type LoyaltyTierName = LoyaltyRankName;

export interface LoyaltyRankTheme {
  accent: string;
  accent2: string;
  glow: string;
  ink: string;
}

export interface LoyaltyRankDefinition {
  name: LoyaltyRankName;
  requiredAppointments: number;
  theme: LoyaltyRankTheme;
}

export const RANK_REQUIREMENTS: Record<LoyaltyRankName, number> = {
  Bronze: 0,
  Silver: 10,
  Gold: 20,
  Diamond: 30,
  Platinum: 50,
};

export const RANK_THEMES: Record<LoyaltyRankName, LoyaltyRankTheme> = {
  Bronze: {
    accent: '#E4975A',
    accent2: '#C4753A',
    glow: 'rgba(228,151,90,.50)',
    ink: '#2A1808',
  },
  Silver: {
    accent: '#BCC3CF',
    accent2: '#7E8794',
    glow: 'rgba(188,195,207,.42)',
    ink: '#191C23',
  },
  Gold: {
    accent: '#F5C542',
    accent2: '#E9A93A',
    glow: 'rgba(245,197,66,.55)',
    ink: '#241A06',
  },
  Diamond: {
    accent: '#8FB4FF',
    accent2: '#B98BFF',
    glow: 'rgba(150,150,255,.55)',
    ink: '#0D1430',
  },
  Platinum: {
    accent: '#DDF6EF',
    accent2: '#84CFC8',
    glow: 'rgba(140,222,210,.50)',
    ink: '#0E2321',
  },
};

export const RANK_DEFINITIONS: LoyaltyRankDefinition[] = LOYALTY_RANKS.map((name) => ({
  name,
  requiredAppointments: RANK_REQUIREMENTS[name],
  theme: RANK_THEMES[name],
}));

function normalizeAppointmentCount(lifetimeAppointments: number): number {
  if (!Number.isFinite(lifetimeAppointments) || lifetimeAppointments <= 0) {
    return 0;
  }

  return Math.floor(lifetimeAppointments);
}

export function getRankFromAppointments(lifetimeAppointments: number): LoyaltyRankName {
  const appointments = normalizeAppointmentCount(lifetimeAppointments);

  if (appointments >= RANK_REQUIREMENTS.Platinum) return 'Platinum';
  if (appointments >= RANK_REQUIREMENTS.Diamond) return 'Diamond';
  if (appointments >= RANK_REQUIREMENTS.Gold) return 'Gold';
  if (appointments >= RANK_REQUIREMENTS.Silver) return 'Silver';
  return 'Bronze';
}

export function getRankDefinition(rank: LoyaltyRankName): LoyaltyRankDefinition {
  return RANK_DEFINITIONS.find((definition) => definition.name === rank) ?? RANK_DEFINITIONS[0];
}

export function getNextRank(
  lifetimeAppointments: number
): { name: LoyaltyRankName; requiredAppointments: number; remainingAppointments: number } | null {
  const current = getRankFromAppointments(lifetimeAppointments);
  const idx = LOYALTY_RANKS.indexOf(current);

  if (idx >= LOYALTY_RANKS.length - 1) {
    return null;
  }

  const nextRank = LOYALTY_RANKS[idx + 1];
  const requiredAppointments = RANK_REQUIREMENTS[nextRank];
  const remainingAppointments = Math.max(
    0,
    requiredAppointments - normalizeAppointmentCount(lifetimeAppointments)
  );

  return { name: nextRank, requiredAppointments, remainingAppointments };
}

export function getRankProgress(lifetimeAppointments: number): number {
  const appointments = normalizeAppointmentCount(lifetimeAppointments);
  const currentRank = getRankFromAppointments(appointments);
  const currentRequirement = RANK_REQUIREMENTS[currentRank];
  const nextRank = getNextRank(appointments);

  if (!nextRank) {
    return 1;
  }

  const span = nextRank.requiredAppointments - currentRequirement;
  if (span <= 0) {
    return 1;
  }

  return Math.min(1, Math.max(0, (appointments - currentRequirement) / span));
}

export function getRankScale(lifetimeAppointments: number) {
  const currentRank = getRankFromAppointments(lifetimeAppointments);
  const appointments = normalizeAppointmentCount(lifetimeAppointments);

  return RANK_DEFINITIONS.map((definition) => ({
    ...definition,
    isCurrent: definition.name === currentRank,
    isReached: appointments >= definition.requiredAppointments,
    remainingAppointments: Math.max(0, definition.requiredAppointments - appointments),
  }));
}

export function getTierFromLifetime(lifetimeAppointments: number): LoyaltyTierName {
  return getRankFromAppointments(lifetimeAppointments);
}

export function getNextTier(lifetimeAppointments: number): {
  name: LoyaltyTierName;
  requiredAppointments: number;
  remainingAppointments: number;
  remainingPoints: number;
} | null {
  const nextRank = getNextRank(lifetimeAppointments);

  if (!nextRank) {
    return null;
  }

  return {
    ...nextRank,
    // Backward-compatible alias for the current mobile parser.
    remainingPoints: nextRank.remainingAppointments,
  };
}

export function getCheapestRewardCost(rewards: { costPoints: number }[]): number | null {
  const active = rewards.filter((r) => r.costPoints > 0);
  if (active.length === 0) return null;
  return Math.min(...active.map((r) => r.costPoints));
}
