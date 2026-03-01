/**
 * Loyalty tier logic (visual only). Based on lifetimeEarned, not current balance.
 */

export const LOYALTY_TIERS = ['Bronze', 'Silver', 'Gold', 'Platinum'] as const;
export type LoyaltyTierName = (typeof LOYALTY_TIERS)[number];

export const TIER_THRESHOLDS: Record<LoyaltyTierName, { min: number; max: number }> = {
  Bronze: { min: 0, max: 199 },
  Silver: { min: 200, max: 499 },
  Gold: { min: 500, max: 999 },
  Platinum: { min: 1000, max: Number.MAX_SAFE_INTEGER },
};

export function getTierFromLifetime(lifetimeEarned: number): LoyaltyTierName {
  if (lifetimeEarned >= 1000) return 'Platinum';
  if (lifetimeEarned >= 500) return 'Gold';
  if (lifetimeEarned >= 200) return 'Silver';
  return 'Bronze';
}

export function getNextTier(lifetimeEarned: number): { name: LoyaltyTierName; remainingPoints: number } | null {
  const current = getTierFromLifetime(lifetimeEarned);
  const idx = LOYALTY_TIERS.indexOf(current);
  if (idx >= LOYALTY_TIERS.length - 1) return null;
  const nextTier = LOYALTY_TIERS[idx + 1];
  const minForNext = TIER_THRESHOLDS[nextTier].min;
  const remaining = Math.max(0, minForNext - lifetimeEarned);
  return { name: nextTier, remainingPoints: remaining };
}

export function getCheapestRewardCost(rewards: { costPoints: number }[]): number | null {
  const active = rewards.filter((r) => r.costPoints > 0);
  if (active.length === 0) return null;
  return Math.min(...active.map((r) => r.costPoints));
}
