# WebOQL — Web-based OQL Scenario Editor

WebOQL — Web-based OQL scenario editor and executor

## Metadata

- **name**: `weboql`
- **version**: `0.1.2`
- **python_requires**: `>=3.10`
- **license**: Apache-2.0
- **ai_model**: `openrouter/qwen/qwen3-coder-next`
- **ecosystem**: SUMD + DOQL + testql + taskfile
- **openapi_title**: weboql API v1.0.0
- **generated_from**: pyproject.toml, Taskfile.yml, Makefile, testql(2), openapi(17 ep), app.doql.less, app.doql.css, pyqual.yaml, goal.yaml, .env.example, src(1 mod)

## Intent

WebOQL — Web-based OQL scenario editor and executor

## Architecture

```
SUMD (description) → DOQL/source (code) → taskfile (automation) → testql (verification)
```

### DOQL Application Declaration (`app.doql.less`, `app.doql.css`)

```less
app {
  name: weboql;
  version: 0.1.2;
}
```

### DOQL Interfaces

- `interface[type="api"]` — type: rest, framework: fastapi

### DOQL Integrations

- `integration[name="modbus"]` — type: hardware
- `integration[name="modbus"]` — type: "hardware"

### Source Modules

- `weboql.main`

## Interfaces

### CLI Entry Points

- `weboql-server`

### REST API (from `openapi.yaml`)

| Method | Path | OperationId | Summary |
|--------|------|-------------|---------|
| `GET` | `/` | `index_page` | Serve the editor UI at root |
| `POST` | `/api/v1/editor/execute` | `execute_scenario` | Execute a scenario file using oqlos runtime |
| `GET` | `/api/v1/editor/file/{file_path:path}` | `read_file` | Read a file's content |
| `POST` | `/api/v1/editor/file/{file_path:path}` | `write_file` | Write content to a file |
| `GET` | `/api/v1/editor/files` | `list_files` | List all files in the scenarios directory |
| `GET` | `/api/v1/editor/status` | `get_system_status` | Get system status and configuration. |
| `GET` | `/api/v1/plugins/config` | `get_plugin_config` | Return the unified plugin YAML config as structured data + raw text. |
| `PUT` | `/api/v1/plugins/config` | `update_plugin_config` | Overwrite the unified plugin YAML config with new content. |
| `POST` | `/api/v1/plugins/execute-line` | `execute_line` | Execute a single OQL/CQL line or snippet and return the result. |
| `POST` | `/api/v1/plugins/install` | `install_plugin` | pip-install a plugin package into the current venv. |
| `GET` | `/api/v1/plugins/list` | `list_plugins` | List registered plugins (from oqlos.hardware.plugins.PluginRegistry). |
| `GET` | `/api/v1/plugins/peripherals/{plugin_id}` | `get_peripherals` | Return peripheral definitions for a plugin from the YAML config. |
| `POST` | `/api/v1/plugins/reload` | `reload_plugins` | Reload plugin configs from YAML and re-discover entry points. |
| `GET` | `/api/v1/schema` | `get_api_v1_schema` | GET /api/v1/schema |
| `GET` | `/dsl` | `dsl_page` | Serve the shared DSL schema client. |
| `GET` | `/editor` | `editor_page` | Serve the editor UI |
| `GET` | `/health` | `health_check` | Health check endpoint |

**Schemas**: `Error`, `HealthCheck`

### testql Scenarios

#### `generated-api-integration.testql.toon.yaml`

- **name**: API Integration Tests
- **type**: `api`
- **base_url**: `http://localhost:8101`
- **timeout_ms**: `30000`
- **retry_count**: `3`
- **endpoints**:
  - `GET /health` → `200`
  - `GET /api/v1/status` → `200`
  - `POST /api/v1/test` → `201`
  - `GET /api/v1/docs` → `200`
- **asserts**:
  - `status == ok`
  - `response_time < 1000`

#### `generated-api-smoke.testql.toon.yaml`

- **name**: Auto-generated API Smoke Tests
- **type**: `api`
- **detectors**: FastAPIDetector, TestEndpointDetector
- **base_url**: `http://localhost:8101`
- **timeout_ms**: `10000`
- **retry_count**: `3`
- **endpoints**:
  - `GET /editor` → `200` — `editor_page`: Serve the editor UI
  - `GET /dsl` → `200` — `dsl_page`: Serve the shared DSL schema client.
  - `GET /health` → `200` — `health_check`: Health check endpoint
  - `GET /api/v1/editor/files` → `200` — `list_files`: List all files in the scenarios directory
  - `GET /api/v1/editor/status` → `200` — `get_system_status`: Get system status and configuration.
  - `POST /api/v1/editor/execute` → `201` — `execute_scenario`: Execute a scenario file using oqlos runtime
  - `POST /api/v1/plugins/execute-line` → `201` — `execute_line`: Execute a single OQL/CQL line or snippet and retur
  - `GET /api/v1/plugins/config` → `200` — `get_plugin_config`: Return the unified plugin YAML config as structure
  - `PUT /api/v1/plugins/config` → `201` — `update_plugin_config`: Overwrite the unified plugin YAML config with new
  - `GET /api/v1/plugins/list` → `200` — `list_plugins`: List registered plugins (from oqlos.hardware.plugi
  - `POST /api/v1/plugins/install` → `201` — `install_plugin`: pip-install a plugin package into the current venv
  - `POST /api/v1/plugins/reload` → `201` — `reload_plugins`: Reload plugin configs from YAML and re-discover en
  - `GET /api/v1/schema` → `200`
- **asserts**:
  - `status < 500`
  - `response_time < 2000`

## Workflows

### DOQL Workflows (`app.doql.less`, `app.doql.css`)

- **install** `[manual]`: `pip install -e .`
- **dev** `[manual]`: `pip install -e ".[dev]"`
- **build** `[manual]`: `python -m build`
- **run** `[manual]`: `HARDWARE_MODE=mock weboql-server`
- **run-prod** `[manual]`: `weboql-server`
- **test** `[manual]`: `pytest`
- **test-e2e** `[manual]`: `./tests/e2e.sh`
- **test-hardware-cli** `[manual]`: `./tests/test-hardware-cli.sh`
- **clean** `[manual]`: `rm -rf dist/ build/ *.egg-info;`
- **publish** `[manual]`: `twine upload dist/*`
- **publish-test** `[manual]`: `twine upload --repository testpypi dist/`
- **quality** `[manual]`: `pyqual run`
- **quality:fix** `[manual]`: `pyqual run --fix`
- **quality:report** `[manual]`: `pyqual report`
- **lint** `[manual]`: `ruff check .`
- **fmt** `[manual]`: `ruff format .`
- **run:prod** `[manual]`: `weboql-server`
- **test:e2e** `[manual]`: `testql suite --pattern "testql-scenarios/*api*.testql.toon.yaml"`
- **test:hardware** `[manual]`: `testql suite --pattern "testql-scenarios/*hardware*.testql.toon.yaml" || echo "No hardware tests found"`
- **test:all** `[manual]`: `testql suite --path testql-scenarios/`
- **test:list** `[manual]`: `testql list --path testql-scenarios/`
- **publish:test** `[manual]`: `twine upload --repository testpypi dist/`
- **doql:adopt** `[manual]`: `if ! command -v {{.DOQL_CMD}} >/dev/null 2>&1; then`
- **doql:validate** `[manual]`: `if [ ! -f "{{.DOQL_OUTPUT}}" ]; then`
- **doql:doctor** `[manual]`: `{{.DOQL_CMD}} doctor`
- **doql:build** `[manual]`: `if [ ! -f "{{.DOQL_OUTPUT}}" ]; then`
- **help** `[manual]`: `task --list`

### Taskfile Tasks (`Taskfile.yml`)

```yaml
tasks:
  install:
    desc: "Install Python dependencies (editable)"
    cmds:
      - pip install -e .[dev]
  dev:
    desc: "Install in dev mode"
    cmds:
      - pip install -e ".[dev]"
  quality:
    desc: "Run pyqual quality pipeline (test + lint + format check)"
    cmds:
      - pyqual run
  quality:fix:
    desc: "Run pyqual with auto-fix (format + lint fix)"
    cmds:
      - pyqual run --fix
  quality:report:
    desc: "Generate pyqual quality report"
    cmds:
      - pyqual report
  test:
    desc: "Run pytest suite"
    cmds:
      - pytest -q
  lint:
    desc: "Run ruff lint check"
    cmds:
      - ruff check .
  fmt:
    desc: "Auto-format with ruff"
    cmds:
      - ruff format .
  build:
    desc: "Build wheel + sdist"
    cmds:
      - python -m build
  clean:
    desc: "Remove build artefacts"
    cmds:
      - rm -rf build/ dist/ *.egg-info
  all:
    desc: "Run install, quality check, test"
  run:
    desc: "Run weboql server (mock mode)"
    cmds:
      - HARDWARE_MODE=mock weboql-server
  run:prod:
    desc: "Run weboql server (production)"
    cmds:
      - weboql-server
  test:e2e:
    desc: "Run E2E tests via testql"
    cmds:
      - testql suite --pattern "testql-scenarios/*api*.testql.toon.yaml"
  test:hardware:
    desc: "Run hardware CLI tests via testql"
    cmds:
      - testql suite --pattern "testql-scenarios/*hardware*.testql.toon.yaml" || echo "No hardware tests found"
  test:all:
    desc: "Run all testql scenarios"
    cmds:
      - testql suite --path testql-scenarios/
  test:list:
    desc: "List available testql tests"
    cmds:
      - testql list --path testql-scenarios/
  publish:
    desc: "Publish to PyPI"
    cmds:
      - twine upload dist/*
  publish:test:
    desc: "Publish to TestPyPI"
    cmds:
      - twine upload --repository testpypi dist/
  doql:adopt:
    desc: "Reverse-engineer weboql project structure"
    cmds:
      - if ! command -v {{.DOQL_CMD}} >/dev/null 2>&1; then
  echo "⚠️  doql not installed. Install: pip install doql"
  exit 1
fi
  doql:validate:
    desc: "Validate app.doql.less syntax"
    cmds:
      - if [ ! -f "{{.DOQL_OUTPUT}}" ]; then
  echo "❌ {{.DOQL_OUTPUT}} not found. Run: task doql:adopt"
  exit 1
fi
  doql:doctor:
    desc: "Run doql health checks"
    cmds:
      - {{.DOQL_CMD}} doctor
  doql:build:
    desc: "Generate code from app.doql.less"
    cmds:
      - if [ ! -f "{{.DOQL_OUTPUT}}" ]; then
  echo "❌ {{.DOQL_OUTPUT}} not found. Run: task doql:adopt"
  exit 1
fi
  analyze:
    desc: "Full doql analysis (adopt + validate + doctor)"
  help:
    desc: "Show available tasks"
    cmds:
      - task --list
```

## Quality Pipeline (`pyqual.yaml`)

**Pipeline**: `quality-loop`

### Metrics / Thresholds

- `cc_max`: `15`
- `vallm_pass_min`: `45`

### Stages

- **analyze**: `code2llm-filtered`
- **validate**: `vallm-filtered`
- **prefact**: `prefact` *(optional)*
- **fix**: `llx-fix` *(optional)*
- **security**: `bandit` *(optional)*
- **test**: `pytest`
- **push**: `git-push` *(optional)*

### Loop Behavior

- `max_iterations`: `3`
- `on_fail`: `report`
- `ticket_backends`: `['markdown']`

## Configuration

```yaml
project:
  name: weboql
  version: 0.1.2
  env: local
```

## Dependencies

### Runtime

- `fastapi>=0.110`
- `uvicorn>=0.28`
- `pydantic>=2.0`
- `oqlos>=0.1.0`
- `goal>=2.1.0`
- `costs>=0.1.20`
- `pfix>=0.1.60`
- `testql>=0.2.0`

### Development

- `pytest`
- `pytest-asyncio`
- `httpx`
- `goal>=2.1.0`
- `costs>=0.1.20`
- `pfix>=0.1.60`

## Deployment

```bash
pip install weboql

# development install
pip install -e .[dev]
```

## Environment Variables (`.env.example`)

| Variable | Default | Description |
|----------|---------|-------------|
| `WEB_PORT` | `8203` | Server Configuration |
| `WEB_HOST` | `0.0.0.0` |  |
| `SCENARIOS_DIR` | `/home/tom/github/oqlos/oqlos/oqlos/scenarios` | Scenarios Directory |
| `PIADC_URL` | `http://localhost:8080` | Hardware Service URLs |
| `MOTOR_URL` | `http://localhost:49055` |  |
| `HARDWARE_MODE` | `mock` | Hardware Mode (mock \| real) |
| `LOG_LEVEL` | `INFO` | Logging (DEBUG \| INFO \| WARNING \| ERROR) |
| `CORS_ORIGINS` | `*` | CORS Settings (comma-separated origins or * for all) |
| `SERVICE_NAME` | `weboql` | Service Metadata |
| `SERVICE_VERSION` | `0.1.0` |  |

## Release Management (`goal.yaml`)

- **versioning**: `semver`
- **commits**: `conventional` scope=`weboql`
- **changelog**: `keep-a-changelog`
- **build strategies**: `python`, `nodejs`, `rust`
- **version files**: `VERSION`, `pyproject.toml:version`, `.venv/lib/python3.13/site-packages/httpcore/__init__.py:__version__`

## Makefile Targets

- `help`
- `install`
- `dev`
- `build`
- `run`
- `run-prod`
- `test`
- `test-e2e`
- `test-hardware-cli`
- `clean`
- `publish`
- `publish-test`
