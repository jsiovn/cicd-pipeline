import express from "express";
import type { Logger } from "pino";
import { checkoutPage } from "./checkout-page.js";
import type { DbCheck } from "./db.js";
import { cartTotal, shippingFee, type LineItem } from "./pricing/index.js";

interface OrderRequest {
  items: LineItem[];
  isVip?: boolean;
  isExpress?: boolean;
}

export function createApp(logger: Logger, checkDb?: DbCheck) {
  const app = express();
  app.use(express.json());

  app.get("/healthz", async (_req, res) => {
    const uptime = Math.floor(process.uptime());
    if (!checkDb) {
      res.json({ status: "ok", uptime });
      return;
    }
    try {
      await checkDb();
      res.json({ status: "ok", uptime, db: "ok" });
    } catch (error) {
      logger.error(error, "database check failed");
      res.status(503).json({ status: "error", uptime, db: "unreachable" });
    }
  });

  app.get("/checkout", (_req, res) => {
    res.type("html").send(checkoutPage);
  });

  app.post("/orders", (req, res) => {
    const { items = [], isVip = false, isExpress = false } = (req.body ?? {}) as OrderRequest;
    const subtotal = cartTotal(items);
    const shipping = shippingFee({ total: subtotal, isVip, isExpress });
    logger.info({ items: items.length, subtotal, shipping }, "order priced");
    res.status(201).json({ subtotal, shipping, total: subtotal + shipping });
  });

  return app;
}
