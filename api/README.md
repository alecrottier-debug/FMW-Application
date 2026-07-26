# Fox Mill Woods API

Azure Functions (Node 20, TypeScript, **v4 programming model**). Deployed to a
**Flex Consumption** plan by `azd` (see `../infra`). Functions are registered in code
via `app.http(...)`; `package.json` `main` globs the compiled `dist/functions/*.js`.

## Endpoints (step 0 — stubs)
| Method | Route                 | Auth      | Purpose                                  |
|--------|-----------------------|-----------|------------------------------------------|
| GET    | `/api/health`         | anonymous | liveness/readiness probe                 |
| POST   | `/api/stripe/webhook` | anonymous | Stripe events (verify signature — §8a)   |

## Run locally
```bash
cp local.settings.json.sample local.settings.json   # gitignored
npm install
npm start            # builds (tsc) then `func start`; needs Azurite for storage
# in another shell:
curl http://localhost:7071/api/health
```
Storage emulation: `npx azurite` (or the VS Code Azurite extension) before `func start`.

## Deploy
From the repo root: `azd up` (provisions infra + deploys this app). Never `az` for
deployments (per CLAUDE.md).

## Next (build order)
Phase 1 adds Entra token validation middleware; phase 5 wires the real Stripe
signature check + event handling here.
