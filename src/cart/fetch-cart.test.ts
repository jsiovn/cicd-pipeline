import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";
import { afterAll, afterEach, beforeAll, expect, test } from "vitest";
import { fetchCart } from "./fetch-cart.js";

const server = setupServer(
  http.get("https://api.example.com/cart", () => {
    return HttpResponse.json({
      items: [{ id: "sku-1", price: 250_000, quantity: 2 }],
      total: 500_000,
    });
  }),
);

beforeAll(() => server.listen({ onUnhandledFrame: "error" }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

test("fetchCart parses the cart the API returns", async () => {
  await expect(fetchCart()).resolves.toEqual({
    items: [{ id: "sku-1", price: 250_000, quantity: 2 }],
    total: 500_000,
  });
});

test("fetchCart turns a 500 into an error", async () => {
  server.use(
    http.get("https://api.example.com/cart", () => {
      return new HttpResponse(null, { status: 500 });
    }),
  );
  await expect(fetchCart()).rejects.toThrow("GET /cart failed with status 500");
});
