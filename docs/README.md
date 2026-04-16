<!-- code2docs:start --># weboql

![version](https://img.shields.io/badge/version-0.1.0-blue) ![python](https://img.shields.io/badge/python-%3E%3D3.10-blue) ![coverage](https://img.shields.io/badge/coverage-unknown-lightgrey) ![functions](https://img.shields.io/badge/functions-24-green)
> **24** functions | **8** classes | **8** files | CC̄ = 3.0

> Auto-generated project documentation from source code analysis.

**Author:** Tom Softreck <tom@sapletta.com>  
**License:** Apache-2.0[(LICENSE)](./LICENSE)  
**Repository:** [https://github.com/oqlos/weboql](https://github.com/oqlos/weboql)

## Installation

### From PyPI

```bash
pip install weboql
```

### From Source

```bash
git clone https://github.com/oqlos/weboql
cd weboql
pip install -e .
```

### Optional Extras

```bash
pip install weboql[dev]    # development tools
```

## Quick Start

### CLI Usage

```bash
# Generate full documentation for your project
weboql ./my-project

# Only regenerate README
weboql ./my-project --readme-only

# Preview what would be generated (no file writes)
weboql ./my-project --dry-run

# Check documentation health
weboql check ./my-project

# Sync — regenerate only changed modules
weboql sync ./my-project
```

### Python API

```python
from weboql import generate_readme, generate_docs, Code2DocsConfig

# Quick: generate README
generate_readme("./my-project")

# Full: generate all documentation
config = Code2DocsConfig(project_name="mylib", verbose=True)
docs = generate_docs("./my-project", config=config)
```

## Generated Output

When you run `weboql`, the following files are produced:

```
<project>/
├── README.md                 # Main project README (auto-generated sections)
├── docs/
│   ├── api.md               # Consolidated API reference
│   ├── modules.md           # Module documentation with metrics
│   ├── architecture.md      # Architecture overview with diagrams
│   ├── dependency-graph.md  # Module dependency graphs
│   ├── coverage.md          # Docstring coverage report
│   ├── getting-started.md   # Getting started guide
│   ├── configuration.md    # Configuration reference
│   └── api-changelog.md    # API change tracking
├── examples/
│   ├── quickstart.py       # Basic usage examples
│   └── advanced_usage.py   # Advanced usage examples
├── CONTRIBUTING.md         # Contribution guidelines
└── mkdocs.yml             # MkDocs site configuration
```

## Configuration

Create `weboql.yaml` in your project root (or run `weboql init`):

```yaml
project:
  name: my-project
  source: ./
  output: ./docs/

readme:
  sections:
    - overview
    - install
    - quickstart
    - api
    - structure
  badges:
    - version
    - python
    - coverage
  sync_markers: true

docs:
  api_reference: true
  module_docs: true
  architecture: true
  changelog: true

examples:
  auto_generate: true
  from_entry_points: true

sync:
  strategy: markers    # markers | full | git-diff
  watch: false
  ignore:
    - "tests/"
    - "__pycache__"
```

## Sync Markers

weboql can update only specific sections of an existing README using HTML comment markers:

```markdown
<!-- weboql:start -->
# Project Title
... auto-generated content ...
<!-- weboql:end -->
```

Content outside the markers is preserved when regenerating. Enable this with `sync_markers: true` in your configuration.

## Architecture

```
weboql/
├── project├── tree        ├── schema    ├── api/├── weboql/    ├── main        ├── plugins_api        ├── editor```

## API Overview

### Classes

- **`Settings`** — Application settings loaded from environment variables and .env file
- **`LineExecutionRequest`** — —
- **`PluginInstallRequest`** — Install a plugin package from PyPI or a local path.
- **`PluginConfigUpdate`** — Full or partial YAML content to write back.
- **`SystemStatus`** — System status information
- **`FileInfo`** — —
- **`FileContent`** — —
- **`ExecutionRequest`** — —

### Functions

- `get_schema()` — Return the canonical CQL/OQL schema for editor clients.
- `index_page()` — Serve the editor UI at root
- `editor_page()` — Serve the editor UI
- `dsl_page()` — Serve the shared DSL schema client.
- `health_check()` — Health check endpoint
- `run()` — Entry point for weboql-server console script.
- `execute_line(request)` — Execute a single OQL/CQL line or snippet and return the result.
- `get_plugin_config()` — Return the unified plugin YAML config as structured data + raw text.
- `update_plugin_config(body)` — Overwrite the unified plugin YAML config with new content.
- `list_plugins()` — List registered plugins (from oqlos.hardware.plugins.PluginRegistry).
- `get_peripherals(plugin_id)` — Return peripheral definitions for a plugin from the YAML config.
- `install_plugin(request)` — pip-install a plugin package into the current venv.
- `reload_plugins()` — Reload plugin configs from YAML and re-discover entry points.
- `list_files()` — List all files in the scenarios directory
- `get_system_status()` — Get system status and configuration.
- `read_file(file_path)` — Read a file's content
- `write_file(file_path, file_content)` — Write content to a file
- `execute_scenario(request)` — Execute a scenario file using oqlos runtime


## Project Structure

📄 `project`
📄 `tree`
📦 `weboql`
📦 `weboql.api`
📄 `weboql.api.editor` (11 functions, 4 classes)
📄 `weboql.api.plugins_api` (7 functions, 3 classes)
📄 `weboql.api.schema` (1 functions)
📄 `weboql.main` (5 functions, 1 classes)

## Requirements

- Python >= >=3.10
- fastapi >=0.110- uvicorn >=0.28- pydantic >=2.0- oqlos >=0.1.0- goal >=2.1.0- costs >=0.1.20- pfix >=0.1.60

## Contributing

**Contributors:**
- Tom Softreck <tom@sapletta.com>
- Tom Sapletta <tom-sapletta-com@users.noreply.github.com>

We welcome contributions! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

### Development Setup

```bash
# Clone the repository
git clone https://github.com/oqlos/weboql
cd weboql

# Install in development mode
pip install -e ".[dev]"

# Run tests
pytest
```

## Documentation

- 📖 [Full Documentation](https://github.com/oqlos/weboql/tree/main/docs) — API reference, module docs, architecture
- 🚀 [Getting Started](https://github.com/oqlos/weboql/blob/main/docs/getting-started.md) — Quick start guide
- 📚 [API Reference](https://github.com/oqlos/weboql/blob/main/docs/api.md) — Complete API documentation
- 🔧 [Configuration](https://github.com/oqlos/weboql/blob/main/docs/configuration.md) — Configuration options
- 💡 [Examples](./examples) — Usage examples and code samples

### Generated Files

| Output | Description | Link |
|--------|-------------|------|
| `README.md` | Project overview (this file) | — |
| `docs/api.md` | Consolidated API reference | [View](./docs/api.md) |
| `docs/modules.md` | Module reference with metrics | [View](./docs/modules.md) |
| `docs/architecture.md` | Architecture with diagrams | [View](./docs/architecture.md) |
| `docs/dependency-graph.md` | Dependency graphs | [View](./docs/dependency-graph.md) |
| `docs/coverage.md` | Docstring coverage report | [View](./docs/coverage.md) |
| `docs/getting-started.md` | Getting started guide | [View](./docs/getting-started.md) |
| `docs/configuration.md` | Configuration reference | [View](./docs/configuration.md) |
| `docs/api-changelog.md` | API change tracking | [View](./docs/api-changelog.md) |
| `CONTRIBUTING.md` | Contribution guidelines | [View](./CONTRIBUTING.md) |
| `examples/` | Usage examples | [Browse](./examples) |
| `mkdocs.yml` | MkDocs configuration | — |

<!-- code2docs:end -->