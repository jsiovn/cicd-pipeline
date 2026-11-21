import pino from "pino";
import { createApp } from "./app.js";

const logger = pino();
const port = Number(process.env.PORT ?? 3000);
const app = createApp(logger);

const server = app.listen(port, (error) => {
  if (error) {
    logger.error(error, `cannot listen on ${port}`);
    process.exit(1);
  }
  logger.info(`listening on ${port}`);
});

process.on("SIGTERM", () => {
  logger.info("SIGTERM received, draining connections");
  server.close(() => process.exit(0));
});
