// The page the Playwright smoke test (e2e/checkout.spec.ts) drives: one button
// that places a fixed order through POST /orders and reports the result.
export const checkoutPage = `<!doctype html>
<html lang="vi">
  <head>
    <meta charset="utf-8">
    <title>Checkout</title>
  </head>
  <body>
    <h1>Checkout</h1>
    <button type="button" id="order">Đặt hàng</button>
    <p id="result" role="status"></p>
    <script>
      const result = document.getElementById("result");
      document.getElementById("order").addEventListener("click", async () => {
        const response = await fetch("/orders", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ items: [{ sku: "TSHIRT", unitPrice: 150000, quantity: 2 }] }),
        });
        result.textContent = response.ok ? "Đặt hàng thành công" : "Đặt hàng thất bại";
      });
    </script>
  </body>
</html>
`;
