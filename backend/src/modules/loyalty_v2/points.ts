/**
 * Shared loyalty points calculation.
 * Prices under 100 are treated as euros; prices 100 and above are treated as cents.
 */

export function pointsFromPrice(price: number): number {
  if (!Number.isFinite(price) || price <= 0) {
    return 0;
  }

  const normalized = Math.floor(price);
  return normalized < 100 ? normalized : Math.floor(normalized / 100);
}
