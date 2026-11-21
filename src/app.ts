import express from "express";
import type { Logger } from "pino";
import { cartTotal, shippingFee, type LineItem } from "./pricing/index.js";

interface OrderRequest {
  items: LineItem[];
  isVip?: boolean;
  isExpress?: boolean;
}

export function createApp(logger: Logger) {
  const app = express();
  app.use(express.json());

  app.get("/healthz", (_req, res) => {
    res.json({ status: "ok", uptime: Math.floor(process.uptime()) });
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
