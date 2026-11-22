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

async function getHealthz(checkDb?: () => Promise<void>) {
  const app = createApp(pino({ enabled: false }), checkDb).listen(0);
  await new Promise<void>((resolve) => app.once("listening", () => resolve()));
  try {
    const port = (app.address() as AddressInfo).port;
    const response = await fetch(`http://localhost:${port}/healthz`);
    return { status: response.status, body: (await response.json()) as Record<string, unknown> };
  } finally {
    await new Promise<void>((resolve) => app.close(() => resolve()));
  }
}

test("GET /healthz without a database reports only status and uptime", async () => {
  const { status, body } = await getHealthz();

  expect(status).toBe(200);
  expect(Object.keys(body)).toEqual(["status", "uptime"]);
  expect(body.status).toBe("ok");
});

test("GET /healthz queries the database when one is configured", async () => {
  const { status, body } = await getHealthz(async () => {});

  expect(status).toBe(200);
  expect(body).toMatchObject({ status: "ok", db: "ok" });
});

test("GET /healthz answers 503 when the database query fails", async () => {
  const { status, body } = await getHealthz(async () => {
    throw new Error("connection refused");
  });

  expect(status).toBe(503);
  expect(body).toMatchObject({ status: "error", db: "unreachable" });
});
