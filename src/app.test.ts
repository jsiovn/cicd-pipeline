import type { AddressInfo } from "node:net";
import type { Server } from "node:http";
import pino from "pino";
import { afterAll, beforeAll, expect, test } from "vitest";
import { createApp } from "./app.js";

let server: Server;
let baseUrl: string;

beforeAll(async () => {
  server = createApp(pino({ enabled: false })).listen(0);
  await new Promise<void>((resolve) => server.once("listening", () => resolve()));
  baseUrl = `http://localhost:${(server.address() as AddressInfo).port}`;
});

afterAll(() => new Promise<void>((resolve) => server.close(() => resolve())));

test("GET /checkout serves the page with the order button", async () => {
  const response = await fetch(`${baseUrl}/checkout`);

  expect(response.status).toBe(200);
  expect(response.headers.get("content-type")).toMatch(/^text\/html/);
  expect(await response.text()).toContain("Đặt hàng");
});
