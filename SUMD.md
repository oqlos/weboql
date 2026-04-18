# WebOQL — Web-based OQL Scenario Editor

WebOQL — Web-based OQL scenario editor and executor

## Contents

- [Metadata](#metadata)
- [Architecture](#architecture)
- [Interfaces](#interfaces)
- [Workflows](#workflows)
- [Quality Pipeline (`pyqual.yaml`)](#quality-pipeline-pyqualyaml)
- [Configuration](#configuration)
- [Dependencies](#dependencies)
- [Deployment](#deployment)
- [Environment Variables (`.env.example`)](#environment-variables-envexample)
- [Release Management (`goal.yaml`)](#release-management-goalyaml)
- [Makefile Targets](#makefile-targets)
- [Code Analysis](#code-analysis)
- [Source Map](#source-map)
- [Intent](#intent)

## Metadata

- **name**: `weboql`
- **version**: `0.1.2`
- **python_requires**: `>=3.10`
- **license**: Apache-2.0
- **ai_model**: `openrouter/qwen/qwen3-coder-next`
- **ecosystem**: SUMD + DOQL + testql + taskfile
- **openapi_title**: weboql API v1.0.0
- **generated_from**: pyproject.toml, Taskfile.yml, Makefile, testql(2), openapi(17 ep), app.doql.less, pyqual.yaml, goal.yaml, .env.example, src(1 mod), project/(1 analysis files)

## Architecture

```
SUMD (description) → DOQL/source (code) → taskfile (automation) → testql (verification)
```

### DOQL Application Declaration (`app.doql.less`)

```less markpact:file path=app.doql.less
// LESS format — define @variables here as needed

app {
  name: weboql;
  version: 0.1.2;
}

interface[type="api"] {
  type: rest;
  framework: fastapi;
}

integration[name="modbus"] {
  type: hardware;
}

workflow[name="install"] {
  trigger: manual;
  step-1: run cmd=pip install -e .;
}

workflow[name="dev"] {
  trigger: manual;
  step-1: run cmd=pip install -e ".[dev]";
}

workflow[name="build"] {
  trigger: manual;
  step-1: run cmd=python -m build;
}

workflow[name="run"] {
  trigger: manual;
  step-1: run cmd=HARDWARE_MODE=mock weboql-server;
}

workflow[name="run-prod"] {
  trigger: manual;
  step-1: run cmd=weboql-server;
}

workflow[name="test"] {
  trigger: manual;
  step-1: run cmd=pytest;
}

workflow[name="test-e2e"] {
  trigger: manual;
  step-1: run cmd=./tests/e2e.sh;
}

workflow[name="test-hardware-cli"] {
  trigger: manual;
  step-1: run cmd=./tests/test-hardware-cli.sh;
}

workflow[name="clean"] {
  trigger: manual;
  step-1: run cmd=rm -rf dist/ build/ *.egg-info;
  step-2: run cmd=find . -type d -name __pycache__ -exec rm -rf {} +;
  step-3: run cmd=find . -type f -name "*.pyc" -delete;
}

workflow[name="publish"] {
  trigger: manual;
  step-1: run cmd=twine upload dist/*;
}

workflow[name="publish-test"] {
  trigger: manual;
  step-1: run cmd=twine upload --repository testpypi dist/;
}

workflow[name="quality"] {
  trigger: manual;
  step-1: run cmd=pyqual run;
}

workflow[name="quality:fix"] {
  trigger: manual;
  step-1: run cmd=pyqual run --fix;
}

workflow[name="quality:report"] {
  trigger: manual;
  step-1: run cmd=pyqual report;
}

workflow[name="lint"] {
  trigger: manual;
  step-1: run cmd=ruff check .;
}

workflow[name="fmt"] {
  trigger: manual;
  step-1: run cmd=ruff format .;
}

workflow[name="run:prod"] {
  trigger: manual;
  step-1: run cmd=weboql-server;
}

workflow[name="test:e2e"] {
  trigger: manual;
  step-1: run cmd=testql suite --pattern "testql-scenarios/*api*.testql.toon.yaml";
}

workflow[name="test:hardware"] {
  trigger: manual;
  step-1: run cmd=testql suite --pattern "testql-scenarios/*hardware*.testql.toon.yaml" || echo "No hardware tests found";
}

workflow[name="test:all"] {
  trigger: manual;
  step-1: run cmd=testql suite --path testql-scenarios/;
}

workflow[name="test:list"] {
  trigger: manual;
  step-1: run cmd=testql list --path testql-scenarios/;
}

workflow[name="publish:test"] {
  trigger: manual;
  step-1: run cmd=twine upload --repository testpypi dist/;
}

workflow[name="doql:adopt"] {
  trigger: manual;
  step-1: run cmd=if ! command -v {{.DOQL_CMD}} >/dev/null 2>&1; then
  echo "⚠️  doql not installed. Install: pip install doql"
  exit 1
fi;
  step-2: run cmd={{.DOQL_CMD}} adopt {{.PWD}} --output app.doql.css --force;
  step-3: run cmd={{.DOQL_CMD}} export --format less -o {{.DOQL_OUTPUT}};
  step-4: run cmd=echo "✅ Project structure captured in {{.DOQL_OUTPUT}}";
}

workflow[name="doql:validate"] {
  trigger: manual;
  step-1: run cmd=if [ ! -f "{{.DOQL_OUTPUT}}" ]; then
  echo "❌ {{.DOQL_OUTPUT}} not found. Run: task doql:adopt"
  exit 1
fi;
  step-2: run cmd={{.DOQL_CMD}} validate;
}

workflow[name="doql:doctor"] {
  trigger: manual;
  step-1: run cmd={{.DOQL_CMD}} doctor;
}

workflow[name="doql:build"] {
  trigger: manual;
  step-1: run cmd=if [ ! -f "{{.DOQL_OUTPUT}}" ]; then
  echo "❌ {{.DOQL_OUTPUT}} not found. Run: task doql:adopt"
  exit 1
fi;
  step-2: run cmd=# Regenerate LESS from CSS if CSS exists
if [ -f "app.doql.css" ]; then
  {{.DOQL_CMD}} export --format less -o {{.DOQL_OUTPUT}}
fi;
  step-3: run cmd={{.DOQL_CMD}} build app.doql.css --out build/;
}

workflow[name="help"] {
  trigger: manual;
  step-1: run cmd=task --list;
}

deploy {
  target: makefile;
}

environment[name="local"] {
  runtime: docker-compose;
  env_file: .env;
}
```

### Source Modules

- `weboql.main`

## Interfaces

### CLI Entry Points

- `weboql-server`

### REST API (from `openapi.yaml`)

```yaml markpact:file path=openapi.yaml
components:
  schemas:
    Error:
      properties:
        code:
          type: integer
        error:
          type: string
        message:
          type: string
      type: object
    HealthCheck:
      properties:
        status:
          enum:
          - ok
          - error
          type: string
        timestamp:
          format: date-time
          type: string
        version:
          type: string
      type: object
info:
  description: Auto-generated OpenAPI spec for weboql
  title: weboql API
  version: 1.0.0
openapi: 3.0.3
paths:
  /:
    get:
      operationId: index_page
      responses:
        '200': &id004
          content:
            application/json:
              schema:
                type: object
          description: Success
        '401': &id001
          description: Unauthorized
        '404': &id002
          description: Not Found
        '500': &id003
          description: Internal Server Error
      summary: Serve the editor UI at root
      tags:
      - fastapi
  /api/v1/editor/execute:
    post:
      operationId: execute_scenario
      requestBody:
        content:
          application/json:
            schema:
              type: object
        required: true
      responses:
        '201': &id005
          content:
            application/json:
              schema:
                type: object
          description: Created
        '400': &id006
          content:
            application/json:
              schema:
                properties:
                  detail:
                    type: string
                  error:
                    type: string
                type: object
          description: Bad Request
        '401': *id001
        '404': *id002
        '500': *id003
      summary: Execute a scenario file using oqlos runtime
      tags:
      - v1
      - fastapi
  /api/v1/editor/file/{file_path:path}:
    get:
      operationId: read_file
      parameters:
      - in: path
        name: file_path:path
        required: true
        schema:
          type: string
      - in: query
        name: file_path
        required: false
        schema:
          type: str
      responses:
        '200': *id004
        '401': *id001
        '404': *id002
        '500': *id003
      summary: Read a file's content
      tags:
      - v1
      - fastapi
    post:
      operationId: write_file
      parameters:
      - in: path
        name: file_path:path
        required: true
        schema:
          type: string
      - in: query
        name: file_path
        required: false
        schema:
          type: str
      requestBody:
        content:
          application/json:
            schema:
              type: object
        required: true
      responses:
        '201': *id005
        '400': *id006
        '401': *id001
        '404': *id002
        '500': *id003
      summary: Write content to a file
      tags:
      - v1
      - fastapi
  /api/v1/editor/files:
    get:
      operationId: list_files
      responses:
        '200': *id004
        '401': *id001
        '404': *id002
        '500': *id003
      summary: List all files in the scenarios directory
      tags:
      - v1
      - fastapi
  /api/v1/editor/status:
    get:
      operationId: get_system_status
      responses:
        '200': *id004
        '401': *id001
        '404': *id002
        '500': *id003
      summary: Get system status and configuration.
      tags:
      - v1
      - fastapi
  /api/v1/plugins/config:
    get:
      operationId: get_plugin_config
      responses:
        '200': *id004
        '401': *id001
        '404': *id002
        '500': *id003
      summary: Return the unified plugin YAML config as structured data + raw text.
      tags:
      - v1
      - fastapi
    put:
      operationId: update_plugin_config
      requestBody:
        content:
          application/json:
            schema:
              properties:
                data:
                  type: object
                id:
                  type: string
                name:
                  type: string
              type: object
        required: true
      responses:
        '200': *id004
        '401': *id001
        '404': *id002
        '500': *id003
      summary: Overwrite the unified plugin YAML config with new content.
      tags:
      - v1
      - fastapi
  /api/v1/plugins/execute-line:
    post:
      operationId: execute_line
      requestBody:
        content:
          application/json:
            schema:
              type: object
        required: true
      responses:
        '201': *id005
        '400': *id006
        '401': *id001
        '404': *id002
        '500': *id003
      summary: Execute a single OQL/CQL line or snippet and return the result.
      tags:
      - v1
      - fastapi
  /api/v1/plugins/install:
    post:
      operationId: install_plugin
      requestBody:
        content:
          application/json:
            schema:
              type: object
        required: true
      responses:
        '201': *id005
        '400': *id006
        '401': *id001
        '404': *id002
        '500': *id003
      summary: pip-install a plugin package into the current venv.
      tags:
      - v1
      - fastapi
  /api/v1/plugins/list:
    get:
      operationId: list_plugins
      responses:
        '200': *id004
        '401': *id001
        '404': *id002
        '500': *id003
      summary: List registered plugins (from oqlos.hardware.plugins.PluginRegistry).
      tags:
      - v1
      - fastapi
  /api/v1/plugins/peripherals/{plugin_id}:
    get:
      operationId: get_peripherals
      parameters:
      - in: path
        name: plugin_id
        required: true
        schema:
          type: string
      - in: query
        name: plugin_id
        required: false
        schema:
          type: str
      responses:
        '200': *id004
        '401': *id001
        '404': *id002
        '500': *id003
      summary: Return peripheral definitions for a plugin from the YAML config.
      tags:
      - v1
      - fastapi
  /api/v1/plugins/reload:
    post:
      operationId: reload_plugins
      requestBody:
        content:
          application/json:
            schema:
              type: object
        required: true
      responses:
        '201': *id005
        '400': *id006
        '401': *id001
        '404': *id002
        '500': *id003
      summary: Reload plugin configs from YAML and re-discover entry points.
      tags:
      - v1
      - fastapi
  /api/v1/schema:
    get:
      operationId: get_api_v1_schema
      responses:
        '200': *id004
        '401': *id001
        '404': *id002
        '500': *id003
      summary: GET /api/v1/schema
      tags:
      - inferred-from-tests
      - v1
  /dsl:
    get:
      operationId: dsl_page
      responses:
        '200': *id004
        '401': *id001
        '404': *id002
        '500': *id003
      summary: Serve the shared DSL schema client.
      tags:
      - fastapi
  /editor:
    get:
      operationId: editor_page
      responses:
        '200': *id004
        '401': *id001
        '404': *id002
        '500': *id003
      summary: Serve the editor UI
      tags:
      - fastapi
  /health:
    get:
      operationId: health_check
      responses:
        '200': *id004
        '401': *id001
        '404': *id002
        '500': *id003
      summary: Health check endpoint
      tags:
      - fastapi
servers:
- description: Local development
  url: http://localhost:8101
- description: Relative
  url: /
```

### testql Scenarios

#### `testql-scenarios/generated-api-integration.testql.toon.yaml`

```toon markpact:file path=testql-scenarios/generated-api-integration.testql.toon.yaml
# SCENARIO: API Integration Tests
# TYPE: api
# GENERATED: true

CONFIG[3]{key, value}:
  base_url, http://localhost:8101
  timeout_ms, 30000
  retry_count, 3

API[4]{method, endpoint, expected_status}:
  GET, /health, 200
  GET, /api/v1/status, 200
  POST, /api/v1/test, 201
  GET, /api/v1/docs, 200

ASSERT[2]{field, operator, expected}:
  status, ==, ok
  response_time, <, 1000
```

#### `testql-scenarios/generated-api-smoke.testql.toon.yaml`

```toon markpact:file path=testql-scenarios/generated-api-smoke.testql.toon.yaml
# SCENARIO: Auto-generated API Smoke Tests
# TYPE: api
# GENERATED: true
# DETECTORS: FastAPIDetector, TestEndpointDetector

CONFIG[4]{key, value}:
  base_url, http://localhost:8101
  timeout_ms, 10000
  retry_count, 3
  detected_frameworks, FastAPIDetector, TestEndpointDetector

# REST API Endpoints (14 unique)
API[14]{method, endpoint, expected_status}:
  GET, /, 200  # index_page - Serve the editor UI at root
  GET, /editor, 200  # editor_page - Serve the editor UI
  GET, /dsl, 200  # dsl_page - Serve the shared DSL schema client.
  GET, /health, 200  # health_check - Health check endpoint
  GET, /api/v1/editor/files, 200  # list_files - List all files in the scenarios directory
  GET, /api/v1/editor/status, 200  # get_system_status - Get system status and configuration.
  POST, /api/v1/editor/execute, 201  # execute_scenario - Execute a scenario file using oqlos runtime
  POST, /api/v1/plugins/execute-line, 201  # execute_line - Execute a single OQL/CQL line or snippet and retur
  GET, /api/v1/plugins/config, 200  # get_plugin_config - Return the unified plugin YAML config as structure
  PUT, /api/v1/plugins/config, 201  # update_plugin_config - Overwrite the unified plugin YAML config with new 
  GET, /api/v1/plugins/list, 200  # list_plugins - List registered plugins (from oqlos.hardware.plugi
  POST, /api/v1/plugins/install, 201  # install_plugin - pip-install a plugin package into the current venv
  POST, /api/v1/plugins/reload, 201  # reload_plugins - Reload plugin configs from YAML and re-discover en
  GET, /api/v1/schema, 200

ASSERT[2]{field, operator, expected}:
  status, <, 500
  response_time, <, 2000

# Summary by Framework:
#   fastapi: 16 endpoints
#   inferred-from-tests: 1 endpoints
```

## Workflows

### Taskfile Tasks (`Taskfile.yml`)

```yaml markpact:file path=Taskfile.yml
# Taskfile.yml — weboql (Web OQL Server) project runner
# https://taskfile.dev

version: "3"

vars:
  APP_NAME: weboql
  DOQL_OUTPUT: app.doql.less
  DOQL_CMD: "{{if eq OS \"windows\"}}doql.exe{{else}}doql{{end}}"

env:
  PYTHONPATH: "{{.PWD}}"

tasks:
  # ─────────────────────────────────────────────────────────────────────────────
  # Development
  # ─────────────────────────────────────────────────────────────────────────────

  install:
    desc: Install Python dependencies (editable)
    cmds:
      - pip install -e .[dev]

  dev:
    desc: Install in dev mode
    cmds:
      - pip install -e ".[dev]"

  quality:
    desc: Run pyqual quality pipeline (test + lint + format check)
    cmds:
      - pyqual run

  quality:fix:
    desc: Run pyqual with auto-fix (format + lint fix)
    cmds:
      - pyqual run --fix

  quality:report:
    desc: Generate pyqual quality report
    cmds:
      - pyqual report

  test:
    desc: Run pytest suite
    cmds:
      - pytest -q

  lint:
    desc: Run ruff lint check
    cmds:
      - ruff check .

  fmt:
    desc: Auto-format with ruff
    cmds:
      - ruff format .

  build:
    desc: Build wheel + sdist
    cmds:
      - python -m build

  clean:
    desc: Remove build artefacts
    cmds:
      - rm -rf build/ dist/ *.egg-info

  all:
    desc: Run install, quality check, test
    cmds:
      - task: install
      - task: quality

  # ─────────────────────────────────────────────────────────────────────────────
  # Server / Runtime
  # ─────────────────────────────────────────────────────────────────────────────

  run:
    desc: Run weboql server (mock mode)
    cmds:
      - HARDWARE_MODE=mock weboql-server

  run:prod:
    desc: Run weboql server (production)
    cmds:
      - weboql-server

  # ─────────────────────────────────────────────────────────────────────────────
  # Testing
  # ─────────────────────────────────────────────────────────────────────────────

  test:e2e:
    desc: Run E2E tests via testql
    cmds:
      - testql suite --pattern "testql-scenarios/*api*.testql.toon.yaml"

  test:hardware:
    desc: Run hardware CLI tests via testql
    cmds:
      - testql suite --pattern "testql-scenarios/*hardware*.testql.toon.yaml" || echo "No hardware tests found"

  test:all:
    desc: Run all testql scenarios
    cmds:
      - testql suite --path testql-scenarios/

  test:list:
    desc: List available testql tests
    cmds:
      - testql list --path testql-scenarios/

  # ─────────────────────────────────────────────────────────────────────────────
  # Publishing
  # ─────────────────────────────────────────────────────────────────────────────

  publish:
    desc: Publish to PyPI
    cmds:
      - twine upload dist/*

  publish:test:
    desc: Publish to TestPyPI
    cmds:
      - twine upload --repository testpypi dist/

  # ─────────────────────────────────────────────────────────────────────────────
  # Doql Integration
  # ─────────────────────────────────────────────────────────────────────────────

  doql:adopt:
    desc: Reverse-engineer weboql project structure
    cmds:
      - |
        if ! command -v {{.DOQL_CMD}} >/dev/null 2>&1; then
          echo "⚠️  doql not installed. Install: pip install doql"
          exit 1
        fi
      - "{{.DOQL_CMD}} adopt {{.PWD}} --output app.doql.css --force"
      - "{{.DOQL_CMD}} export --format less -o {{.DOQL_OUTPUT}}"
      - echo "✅ Project structure captured in {{.DOQL_OUTPUT}}"

  doql:validate:
    desc: Validate app.doql.less syntax
    cmds:
      - |
        if [ ! -f "{{.DOQL_OUTPUT}}" ]; then
          echo "❌ {{.DOQL_OUTPUT}} not found. Run: task doql:adopt"
          exit 1
        fi
      - "{{.DOQL_CMD}} validate"

  doql:doctor:
    desc: Run doql health checks
    cmds:
      - "{{.DOQL_CMD}} doctor"

  doql:build:
    desc: Generate code from app.doql.less
    cmds:
      - |
        if [ ! -f "{{.DOQL_OUTPUT}}" ]; then
          echo "❌ {{.DOQL_OUTPUT}} not found. Run: task doql:adopt"
          exit 1
        fi
      - |
        # Regenerate LESS from CSS if CSS exists
        if [ -f "app.doql.css" ]; then
          {{.DOQL_CMD}} export --format less -o {{.DOQL_OUTPUT}}
        fi
      - "{{.DOQL_CMD}} build app.doql.css --out build/"

  analyze:
    desc: Full doql analysis (adopt + validate + doctor)
    cmds:
      - task: doql:adopt
      - task: doql:validate
      - task: doql:doctor

  # ─────────────────────────────────────────────────────────────────────────────
  # Utility
  # ─────────────────────────────────────────────────────────────────────────────

  help:
    desc: Show available tasks
    cmds:
      - task --list
```

## Quality Pipeline (`pyqual.yaml`)

```yaml markpact:file path=pyqual.yaml
pipeline:
  name: quality-loop

  # Quickstart: replace all of this with a single profile line:
  #   profile: python-minimal   # analyze → validate → lint → fix → test
  #   profile: python-publish   # + git-push and make-publish
  #   profile: python-secure    # + pip-audit, bandit, detect-secrets
  #   profile: python           # standard (needs manual stage config)
  #   profile: ci               # CI-only, no fix
  # See: pyqual profiles

  # Quality gates — pipeline iterates until ALL pass
  metrics:
    cc_max: 15           # cyclomatic complexity per function
    vallm_pass_min: 45   # actual: 47.6%
    # coverage_min: 80  # disabled - pytest_cov reports null

  # Pipeline stages — use 'tool:' for built-in presets or 'run:' for custom commands
  # See all presets: pyqual tools
  # when: any_stage_fail    — run only when a prior stage in this iteration failed
  # when: metrics_fail      — run only when quality gates are not yet passing
  # when: first_iteration   — run only on iteration 1 (skip re-runs after fix)
  # when: after_fix         — run only after the fix stage ran in this iteration
  stages:
    - name: analyze
      tool: code2llm-filtered   # uses sensible exclude defaults

    - name: validate
      tool: vallm-filtered      # uses sensible exclude defaults

    - name: prefact
      tool: prefact
      optional: true
      when: any_stage_fail
      timeout: 900

    - name: fix
      tool: llx-fix
      optional: true
      when: any_stage_fail
      timeout: 1800

    - name: security
      tool: bandit
      optional: true
      timeout: 120

    - name: test
      tool: pytest

    - name: push
      tool: git-push            # built-in: git add + commit + push
      optional: true
      timeout: 120

  # Loop behavior
  loop:
    max_iterations: 3
    on_fail: report      # report | create_ticket | block
    ticket_backends:     # backends to sync when on_fail = create_ticket
      - markdown        # TODO.md (default)
      # - github        # GitHub Issues (requires GITHUB_TOKEN)

  # Environment (optional)
  env:
    LLM_MODEL: openrouter/qwen/qwen3-coder-next
```

## Configuration

```yaml
project:
  name: weboql
  version: 0.1.2
  env: local
```

## Dependencies

### Runtime

```text markpact:deps python
fastapi>=0.110
uvicorn>=0.28
pydantic>=2.0
oqlos>=0.1.0
goal>=2.1.0
costs>=0.1.20
pfix>=0.1.60
testql>=0.2.0
```

### Development

```text markpact:deps python scope=dev
pytest
pytest-asyncio
httpx
goal>=2.1.0
costs>=0.1.20
pfix>=0.1.60
```

## Deployment

```bash markpact:run
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

## Code Analysis

### `project/map.toon.yaml`

```toon markpact:file path=project/map.toon.yaml
# weboql | 14f 1919L | python:8,shell:4,css:1,less:1 | 2026-04-18
# stats: 28 func | 8 cls | 14 mod | CC̄=3.0 | critical:0 | cycles:0
# alerts[5]: CC execute_line=8; CC test_schema_endpoint_returns_shared_catalog=6; CC execute_scenario=6; CC _count_scenario_files=5; CC read_file=5
# hotspots[5]: list_files fan=12; execute_scenario fan=12; execute_line fan=12; get_system_status fan=11; install_plugin fan=10
# evolution: baseline
# Keys: M=modules, D=details, i=imports, e=exports, c=classes, f=functions, m=methods
M[14]:
  app.doql.css,178
  app.doql.less,180
  project.sh,35
  tests/e2e.sh,248
  tests/test-hardware-cli.sh,615
  tests/test_schema_api.py,25
  tests/test_weboql.py,12
  tree.sh,2
  weboql/__init__.py,2
  weboql/api/__init__.py,2
  weboql/api/editor.py,252
  weboql/api/plugins_api.py,216
  weboql/api/schema.py,15
  weboql/main.py,137
D:
  tests/test_schema_api.py:
    e: test_schema_endpoint_returns_shared_catalog,test_dsl_page_is_served
    test_schema_endpoint_returns_shared_catalog()
    test_dsl_page_is_served()
  tests/test_weboql.py:
    e: test_placeholder,test_import
    test_placeholder()
    test_import()
  weboql/__init__.py:
  weboql/api/__init__.py:
  weboql/api/editor.py:
    e: SystemStatus,FileInfo,FileContent,ExecutionRequest,_ensure_safe_path,list_files,_check_piadc_health,_check_motor_health,_check_modbus_health,_count_scenario_files,_get_attr_safe,get_system_status,read_file,write_file,execute_scenario
    SystemStatus:  # System status information
    FileInfo:
    FileContent:
    ExecutionRequest:
    _ensure_safe_path(file_path)
    list_files()
    _check_piadc_health(piadc_url)
    _check_motor_health(motor_url)
    _check_modbus_health(modbus_serial_port)
    _count_scenario_files()
    _get_attr_safe(obj;attr;default)
    get_system_status()
    read_file(file_path)
    write_file(file_path;file_content)
    execute_scenario(request)
  weboql/api/plugins_api.py:
    e: LineExecutionRequest,PluginInstallRequest,PluginConfigUpdate,execute_line,get_plugin_config,update_plugin_config,list_plugins,get_peripherals,install_plugin,reload_plugins
    LineExecutionRequest:
    PluginInstallRequest:  # Install a plugin package from PyPI or a local path.
    PluginConfigUpdate:  # Full or partial YAML content to write back.
    execute_line(request)
    get_plugin_config()
    update_plugin_config(body)
    list_plugins()
    get_peripherals(plugin_id)
    install_plugin(request)
    reload_plugins()
  weboql/api/schema.py:
    e: get_schema
    get_schema()
  weboql/main.py:
    e: Settings,index_page,editor_page,dsl_page,health_check,run
    Settings:  # Application settings loaded from environment variables and .
    index_page()
    editor_page()
    dsl_page()
    health_check()
    run()
```

## Source Map

*Top 1 modules by symbol density — signatures for LLM orientation.*

### `weboql.main` (`weboql/main.py`)

```python
def index_page()  # CC=1, fan=2
def editor_page()  # CC=1, fan=2
def dsl_page()  # CC=1, fan=2
def health_check()  # CC=1, fan=2
def run()  # CC=1, fan=1
class Settings:  # Application settings loaded from environment variables and .
```

## Intent

WebOQL — Web-based OQL scenario editor and executor
