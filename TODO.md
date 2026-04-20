# weboql TODO

## P0 — Critical

- [ ] pytest coverage not collected — add `pytest-cov` + `.coveragerc`
- [ ] Integration tests in `testql-scenarios/` require running OqlOS server — add mock/stub for CI

## P1 — Quality

- [ ] `weboql/app.py` — extract route handlers to separate modules per resource
- [ ] Frontend JS — no bundler/linter setup; add ESLint or similar
- [ ] WebSocket scenario streaming — error handling on disconnect

## P2 — Features / Backlog

- [ ] `generated/` testql-scenarios folder — review and promote to top-level once validated
- [ ] Scenario editor — syntax highlighting for `.oql` files (CodeMirror/Monaco)
- [ ] Execution log — persist last N run logs to SQLite for replay
- [ ] Dark mode toggle

## Tests

- [ ] Run `testql run testql-scenarios/generated-api-smoke.testql.toon.yaml` (needs server)
- [ ] Run `testql run testql-scenarios/generated-api-integration.testql.toon.yaml`
- [ ] Run `testql run testql-scenarios/cross-project-integration.testql.toon.yaml`

## ✅ Done

- [x] Initial web editor scaffold: file browser, scenario viewer, executor
- [x] WebSocket real-time execution output
- [x] testql-scenarios generated (3 files + generated/ subfolder)
- [x] README AI cost tracking removed; version badge updated to 0.1.2
- [x] CHANGELOG updated with structured entries
