import { describe, expect, it } from "vitest";
import { cartTotal, isFreeShipping, shippingFee } from "./index.js";

describe("cartTotal", () => {
  it("returns 0 for an empty cart", () => {
    expect(cartTotal([])).toBe(0);
  });

  it("sums unit price times quantity across lines", () => {
    const total = cartTotal([
      { sku: "TSHIRT", unitPrice: 150_000, quantity: 2 },
      { sku: "CAP", unitPrice: 90_000, quantity: 1 },
    ]);
    expect(total).toBe(390_000);
  });

  it("subtracts a line discount", () => {
    const total = cartTotal([{ sku: "TSHIRT", unitPrice: 150_000, quantity: 2, discount: 20_000 }]);
    expect(total).toBe(280_000);
  });
});

describe("isFreeShipping", () => {
  it("is free from 500,000 VND", () => {
    expect(isFreeShipping({ total: 500_000, isVip: false, isExpress: false })).toBe(true);
    expect(isFreeShipping({ total: 499_999, isVip: false, isExpress: false })).toBe(false);
  });

  it("is free for VIP customers below the threshold", () => {
    expect(isFreeShipping({ total: 100_000, isVip: true, isExpress: false })).toBe(true);
  });

  it("is never free for express delivery", () => {
    expect(isFreeShipping({ total: 900_000, isVip: true, isExpress: true })).toBe(false);
  });
});

describe("shippingFee", () => {
  it("charges the standard fee below the threshold", () => {
    expect(shippingFee({ total: 200_000, isVip: false, isExpress: false })).toBe(30_000);
  });

  it("charges the express fee for express delivery", () => {
    expect(shippingFee({ total: 900_000, isVip: false, isExpress: true })).toBe(50_000);
  });

  it("charges nothing when shipping is free", () => {
    expect(shippingFee({ total: 600_000, isVip: false, isExpress: false })).toBe(0);
  });
});
