# WebOQL — Web-based OQL Scenario Editor

SUMD - Structured Unified Markdown Descriptor for AI-aware project refactorization

## Contents

- [Metadata](#metadata)
- [Architecture](#architecture)
- [Workflows](#workflows)
- [Quality Pipeline (`pyqual.yaml`)](#quality-pipeline-pyqualyaml)
- [Dependencies](#dependencies)
- [Source Map](#source-map)
- [Call Graph](#call-graph)
- [Test Contracts](#test-contracts)
- [Refactoring Analysis](#refactoring-analysis)
- [Intent](#intent)

## Metadata

- **name**: `weboql`
- **version**: `0.1.2`
- **python_requires**: `>=3.10`
- **license**: Apache-2.0
- **ai_model**: `openrouter/qwen/qwen3-coder-next`
- **ecosystem**: SUMD + DOQL + testql + taskfile
- **openapi_title**: weboql API v1.0.0
- **generated_from**: pyproject.toml, Taskfile.yml, Makefile, testql(3), openapi(17 ep), app.doql.less, pyqual.yaml, goal.yaml, .env.example, src(1 mod), project/(6 analysis files)

## Architecture

```
SUMD (description) → DOQL/source (code) → taskfile (automation) → testql (verification)
```

### DOQL Application Declaration (`app.doql.less`)

```less markpact:doql path=app.doql.less
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

## Workflows

### Taskfile Tasks (`Taskfile.yml`)

```yaml markpact:taskfile path=Taskfile.yml
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

  deps:update:
    desc: Upgrade all outdated Python packages in the active / project venv
    cmds:
      - |
        PIP="pip"
        [ -f "{{.PWD}}/.venv/bin/pip" ] && PIP="{{.PWD}}/.venv/bin/pip"
        $PIP install --upgrade pip
        OUTDATED=$($PIP list --outdated --format=columns 2>/dev/null | tail -n +3 | awk '{print $1}')
        if [ -z "$OUTDATED" ]; then
          echo "✅ All packages are up to date."
        else
          echo "📦 Upgrading: $OUTDATED"
          echo "$OUTDATED" | xargs $PIP install --upgrade
          echo "✅ Done."
        fi

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

```yaml markpact:pyqual path=pyqual.yaml
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

## Source Map

*Top 1 modules by symbol density — signatures for LLM orientation.*

### `weboql.main` (`weboql/main.py`)

```python
def _serve_page(html_file, missing_title, missing_message)  # CC=1, fan=1
def index_page()  # CC=1, fan=2
def editor_page()  # CC=1, fan=2
def dsl_page()  # CC=1, fan=2
def health_check()  # CC=1, fan=2
def run()  # CC=1, fan=1
class Settings:  # Application settings loaded from environment variables and .
```

## Call Graph

*9 nodes · 7 edges · 1 modules · CC̄=3.0*

### Hubs (by degree)

| Function | CC | in | out | total |
|----------|----|----|-----|-------|
| `get_system_status` *(in weboql.api.editor)* | 2 | 0 | 20 | **20** |
| `execute_scenario` *(in weboql.api.editor)* | 6 | 0 | 18 | **18** |
| `read_file` *(in weboql.api.editor)* | 5 | 0 | 11 | **11** |
| `_ensure_safe_path` *(in weboql.api.editor)* | 2 | 3 | 6 | **9** |
| `write_file` *(in weboql.api.editor)* | 3 | 0 | 7 | **7** |
| `_check_motor_health` *(in weboql.api.editor)* | 3 | 1 | 2 | **3** |
| `_check_piadc_health` *(in weboql.api.editor)* | 3 | 1 | 2 | **3** |
| `_get_attr_safe` *(in weboql.api.editor)* | 2 | 1 | 2 | **3** |

```toon markpact:analysis path=project/calls.toon.yaml
# code2llm call graph | /home/tom/github/oqlos/weboql
# nodes: 9 | edges: 7 | modules: 1
# CC̄=3.0

HUBS[20]:
  weboql.api.editor.get_system_status
    CC=2  in:0  out:20  total:20
  weboql.api.editor.execute_scenario
    CC=6  in:0  out:18  total:18
  weboql.api.editor.read_file
    CC=5  in:0  out:11  total:11
  weboql.api.editor._ensure_safe_path
    CC=2  in:3  out:6  total:9
  weboql.api.editor.write_file
    CC=3  in:0  out:7  total:7
  weboql.api.editor._check_motor_health
    CC=3  in:1  out:2  total:3
  weboql.api.editor._check_piadc_health
    CC=3  in:1  out:2  total:3
  weboql.api.editor._get_attr_safe
    CC=2  in:1  out:2  total:3
  weboql.api.editor._check_modbus_health
    CC=4  in:1  out:1  total:2

MODULES:
  weboql.api.editor  [9 funcs]
    _check_modbus_health  CC=4  out:1
    _check_motor_health  CC=3  out:2
    _check_piadc_health  CC=3  out:2
    _ensure_safe_path  CC=2  out:6
    _get_attr_safe  CC=2  out:2
    execute_scenario  CC=6  out:18
    get_system_status  CC=2  out:20
    read_file  CC=5  out:11
    write_file  CC=3  out:7

EDGES:
  weboql.api.editor.get_system_status → weboql.api.editor._check_modbus_health
  weboql.api.editor.get_system_status → weboql.api.editor._check_piadc_health
  weboql.api.editor.get_system_status → weboql.api.editor._check_motor_health
  weboql.api.editor.get_system_status → weboql.api.editor._get_attr_safe
  weboql.api.editor.read_file → weboql.api.editor._ensure_safe_path
  weboql.api.editor.write_file → weboql.api.editor._ensure_safe_path
  weboql.api.editor.execute_scenario → weboql.api.editor._ensure_safe_path
```

## Test Contracts

*Scenarios as contract signatures — what the system guarantees.*

### Api (2)

**`API Integration Tests`**
- `GET /health` → `200`
- `GET /api/v1/status` → `200`
- `POST /api/v1/test` → `201`
- assert `status == ok`
- assert `response_time < 1000`

**`Auto-generated API Smoke Tests`**
- `GET /editor` → `200`
- `GET /dsl` → `200`
- `GET /health` → `200`
- assert `status < 500`
- assert `response_time < 2000`
- detectors: FastAPIDetector, OpenAPIDetector, TestEndpointDetector

### Integration (1)

**`Cross-Project Integration Tests`**

## Refactoring Analysis

*Pre-refactoring snapshot — use this section to identify targets. Generated from `project/` toon files.*

### Call Graph & Complexity (`project/calls.toon.yaml`)

```toon markpact:analysis path=project/calls.toon.yaml
# code2llm call graph | /home/tom/github/oqlos/weboql
# nodes: 9 | edges: 7 | modules: 1
# CC̄=3.0

HUBS[20]:
  weboql.api.editor.get_system_status
    CC=2  in:0  out:20  total:20
  weboql.api.editor.execute_scenario
    CC=6  in:0  out:18  total:18
  weboql.api.editor.read_file
    CC=5  in:0  out:11  total:11
  weboql.api.editor._ensure_safe_path
    CC=2  in:3  out:6  total:9
  weboql.api.editor.write_file
    CC=3  in:0  out:7  total:7
  weboql.api.editor._check_motor_health
    CC=3  in:1  out:2  total:3
  weboql.api.editor._check_piadc_health
    CC=3  in:1  out:2  total:3
  weboql.api.editor._get_attr_safe
    CC=2  in:1  out:2  total:3
  weboql.api.editor._check_modbus_health
    CC=4  in:1  out:1  total:2

MODULES:
  weboql.api.editor  [9 funcs]
    _check_modbus_health  CC=4  out:1
    _check_motor_health  CC=3  out:2
    _check_piadc_health  CC=3  out:2
    _ensure_safe_path  CC=2  out:6
    _get_attr_safe  CC=2  out:2
    execute_scenario  CC=6  out:18
    get_system_status  CC=2  out:20
    read_file  CC=5  out:11
    write_file  CC=3  out:7

EDGES:
  weboql.api.editor.get_system_status → weboql.api.editor._check_modbus_health
  weboql.api.editor.get_system_status → weboql.api.editor._check_piadc_health
  weboql.api.editor.get_system_status → weboql.api.editor._check_motor_health
  weboql.api.editor.get_system_status → weboql.api.editor._get_attr_safe
  weboql.api.editor.read_file → weboql.api.editor._ensure_safe_path
  weboql.api.editor.write_file → weboql.api.editor._ensure_safe_path
  weboql.api.editor.execute_scenario → weboql.api.editor._ensure_safe_path
```

### Code Analysis (`project/analysis.toon.yaml`)

```toon markpact:analysis path=project/analysis.toon.yaml
# code2llm | 8f 655L | python:6,shell:2 | 2026-04-19
# CC̄=3.0 | critical:0/24 | dups:0 | cycles:0

HEALTH[0]: ok

REFACTOR[0]: none needed

PIPELINES[18]:
  [1] Src [get_schema]: get_schema
      PURITY: 100% pure
  [2] Src [index_page]: index_page
      PURITY: 100% pure
  [3] Src [editor_page]: editor_page
      PURITY: 100% pure
  [4] Src [dsl_page]: dsl_page
      PURITY: 100% pure
  [5] Src [health_check]: health_check
      PURITY: 100% pure

LAYERS:
  weboql/                         CC̄=3.0    ←in:0  →out:0
  │ editor                     251L  4C   11m  CC=6      ←0
  │ plugins_api                215L  3C    7m  CC=8      ←0
  │ main                       136L  1C    5m  CC=1      ←0
  │ schema                      15L  0C    1m  CC=1      ←0
  │ __init__                     1L  0C    0m  CC=0.0    ←0
  │ __init__                     1L  0C    0m  CC=0.0    ←0
  │
  ./                              CC̄=0.0    ←in:0  →out:0
  │ project.sh                  35L  0C    0m  CC=0.0    ←0
  │ tree.sh                      1L  0C    0m  CC=0.0    ←0
  │

COUPLING: no cross-package imports detected

EXTERNAL:
  validation: run `vallm batch .` → validation.toon
  duplication: run `redup scan .` → duplication.toon
```

### Duplication (`project/duplication.toon.yaml`)

```toon markpact:analysis path=project/duplication.toon.yaml
# redup/duplication | 2 groups | 6f 619L | 2026-04-18

SUMMARY:
  files_scanned: 6
  total_lines:   619
  dup_groups:    2
  dup_fragments: 5
  saved_lines:   25
  scan_ms:       3836

HOTSPOTS[2] (files with most duplication):
  weboql/api/editor.py  dup=22L  groups=1  frags=2  (3.6%)
  weboql/main.py  dup=21L  groups=1  frags=3  (3.4%)

DUPLICATES[2] (ranked by impact):
  [e8a0e90bdc6dded9]   STRU  index_page  L=7 N=3 saved=14 sim=1.00
      weboql/main.py:88-94  (index_page)
      weboql/main.py:98-104  (editor_page)
      weboql/main.py:108-114  (dsl_page)
  [53e1aeacc054dc31]   STRU  _check_piadc_health  L=11 N=2 saved=11 sim=1.00
      weboql/api/editor.py:82-92  (_check_piadc_health)
      weboql/api/editor.py:95-105  (_check_motor_health)

REFACTOR[2] (ranked by priority):
  [1] ○ extract_function   → weboql/utils/index_page.py
      WHY: 3 occurrences of 7-line block across 1 files — saves 14 lines
      FILES: weboql/main.py
  [2] ○ extract_function   → weboql/api/utils/_check_piadc_health.py
      WHY: 2 occurrences of 11-line block across 1 files — saves 11 lines
      FILES: weboql/api/editor.py

QUICK_WINS[2] (low risk, high savings — do first):
  [1] extract_function   saved=14L  → weboql/utils/index_page.py
      FILES: main.py
  [2] extract_function   saved=11L  → weboql/api/utils/_check_piadc_health.py
      FILES: editor.py

EFFORT_ESTIMATE (total ≈ 0.8h):
  easy   index_page                          saved=14L  ~28min
  easy   _check_piadc_health                 saved=11L  ~22min

METRICS-TARGET:
  dup_groups:  2 → 0
  saved_lines: 25 lines recoverable
```

### Evolution / Churn (`project/evolution.toon.yaml`)

```toon markpact:analysis path=project/evolution.toon.yaml
# code2llm/evolution | 24 func | 4f | 2026-04-19

NEXT[0]: no refactoring needed

RISKS[0]: none

METRICS-TARGET:
  CC̄:          3.0 → ≤2.1
  max-CC:      8 → ≤4
  god-modules: 0 → 0
  high-CC(≥15): 0 → ≤0
  hub-types:   0 → ≤0

PATTERNS (language parser shared logic):
  _extract_declarations() in base.py — unified extraction for:
    - TypeScript: interfaces, types, classes, functions, arrow funcs
    - PHP: namespaces, traits, classes, functions, includes
    - Ruby: modules, classes, methods, requires
    - C++: classes, structs, functions, #includes
    - C#: classes, interfaces, methods, usings
    - Java: classes, interfaces, methods, imports
    - Go: packages, functions, structs
    - Rust: modules, functions, traits, use statements

  Shared regex patterns per language:
    - import: language-specific import/require/using patterns
    - class: class/struct/trait declarations with inheritance
    - function: function/method signatures with visibility
    - brace_tracking: for C-family languages ({ })
    - end_keyword_tracking: for Ruby (module/class/def...end)

  Benefits:
    - Consistent extraction logic across all languages
    - Reduced code duplication (~70% reduction in parser LOC)
    - Easier maintenance: fix once, apply everywhere
    - Standardized FunctionInfo/ClassInfo models

HISTORY:
  prev CC̄=3.0 → now CC̄=3.0
```

### Validation (`project/validation.toon.yaml`)

```toon markpact:analysis path=project/validation.toon.yaml
# vallm batch | 42f | 20✓ 0⚠ 0✗ | 2026-04-18

SUMMARY:
  scanned: 42  passed: 20 (47.6%)  warnings: 0  errors: 0  unsupported: 22

UNSUPPORTED[5]{bucket,count}:
  *.md,7
  *.txt,1
  *.yml,2
  *.example,1
  other,11
```

## Intent

WebOQL — Web-based OQL scenario editor and executor
