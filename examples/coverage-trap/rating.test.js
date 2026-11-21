import { expect, test } from "vitest";
import { averageRating } from "./rating.js";

test("averages the stars of a list of reviews", () => {
  expect(averageRating([{ stars: 5 }, { stars: 4 }, { stars: 3 }])).toBe(4);
});
