import { expect, test } from "@playwright/test";

test("thanh toán thành công", async ({ page }) => {
  await page.goto("/checkout");
  await page.getByRole("button", { name: "Đặt hàng" }).click();

  // ❌ Chờ theo đồng hồ: máy CI chậm hơn máy bạn là đỏ
  // await page.waitForTimeout(3000);
  // expect(await page.getByText("Đặt hàng thành công").isVisible()).toBe(true);

  // ✅ Chờ theo điều kiện: assertion tự retry tới khi điều kiện đúng hoặc hết timeout
  await expect(page.getByText("Đặt hàng thành công")).toBeVisible();
});
