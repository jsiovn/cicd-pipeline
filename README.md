# cicd-pipeline

One small Node.js "orders" API taken through PR checks, tests, Docker images and deploys with GitHub Actions. The app is deliberately tiny: the pipeline around it is the product.

It backs these articles on [JavaScript.io.vn](https://javascript.io.vn/) (in Vietnamese):

- [CI/CD với GitHub Actions cho dự án JavaScript từ đầu](https://javascript.io.vn/2026/11/17/cicd-github-actions-cho-du-an-javascript/)
- [Test cái gì trước? Chiến lược testing pyramid và trophy](https://javascript.io.vn/2026/11/18/chien-luoc-testing-pyramid-trophy-test-gi-truoc/)
- [Docker cho Node.js: multi-stage build và giảm image size](https://javascript.io.vn/2026/11/19/docker-cho-nodejs-multi-stage-build-image-size/)
- [Deploy app JavaScript: static, serverless hay container?](https://javascript.io.vn/2026/11/20/deploy-app-javascript-static-serverless-container/)

## The app

| Path | What it does |
| --- | --- |
| `src/server.ts` | Starts the Express 5 server on `PORT` (default 3000), logs with pino, drains connections on `SIGTERM` |
| `src/app.ts` | `GET /healthz` returns `{"status":"ok","uptime":<seconds>}`; `POST /orders` prices a cart |
| `src/pricing/` | `cartTotal`, `isFreeShipping`, `shippingFee` and their unit tests |

```sh
nvm use            # Node 26 (.nvmrc); Node 22 and 24 are supported too
npm ci
npm run dev        # tsx watch src/server.ts
npm run lint
npm run typecheck  # tsc --noEmit
npm test           # vitest run
npm run build      # tsc -> dist/
npm start          # node dist/server.js
```

```sh
curl -s -X POST localhost:3000/orders -H 'content-type: application/json' \
  -d '{"items":[{"sku":"TSHIRT","unitPrice":150000,"quantity":2}]}'
# {"subtotal":300000,"shipping":30000,"total":330000}
```

## Post section -> file -> where to watch it

| Post section | File | Where to watch it |
| --- | --- | --- |

Measured numbers quoted by the posts live in [docs/measurements.md](docs/measurements.md).
