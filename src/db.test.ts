import { expect, test } from "vitest";
import { createDbCheck } from "./db.js";

test("no DATABASE_URL, no database check", () => {
  expect(createDbCheck(undefined)).toBeUndefined();
  expect(createDbCheck("")).toBeUndefined();
});

test("a DATABASE_URL gives a check function (the pool connects lazily)", () => {
  expect(createDbCheck("postgres://user:pass@localhost:5432/orders")).toBeTypeOf("function");
});
