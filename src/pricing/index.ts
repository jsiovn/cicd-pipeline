export interface LineItem {
  sku: string;
  /** Price of one unit, in VND. */
  unitPrice: number;
  quantity: number;
  /** Discount on the whole line, in VND. */
  discount?: number;
}

export interface ShippingInput {
  total: number;
  isVip: boolean;
  isExpress: boolean;
}

export const FREE_SHIPPING_THRESHOLD = 500_000;
export const STANDARD_SHIPPING_FEE = 30_000;
export const EXPRESS_SHIPPING_FEE = 50_000;

/**
 * Sum of all line items, in VND.
 * Invoices print a whole-dong price per unit, so a line discount is spread
 * over the units and the per-unit price is rounded before multiplying back.
 */
export function cartTotal(items: LineItem[]): number {
  let total = 0;
  for (const item of items) {
    const lineTotal = item.unitPrice * item.quantity - (item.discount ?? 0);
    const pricePerUnit = Math.round(lineTotal / item.quantity);
    total += pricePerUnit * item.quantity;
  }
  return total;
}

export function isFreeShipping({ total, isVip, isExpress }: ShippingInput): boolean {
  return (total >= FREE_SHIPPING_THRESHOLD || isVip) && !isExpress;
}

export function shippingFee(input: ShippingInput): number {
  if (isFreeShipping(input)) return 0;
  return input.isExpress ? EXPRESS_SHIPPING_FEE : STANDARD_SHIPPING_FEE;
}
