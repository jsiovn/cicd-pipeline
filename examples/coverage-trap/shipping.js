export function shippingFee(total) {
  if (total >= 500_000) return 0;
  return 30_000;
}
