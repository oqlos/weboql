# WebOQL — Web-based OQL Scenario Editor

![Version](https://img.shields.io/badge/version-0.1.2-blue) ![Python](https://img.shields.io/badge/python-3.10+-blue) ![License](https://img.shields.io/badge/license-Apache--2.0-green)

Web-based editor and executor for OQL (Operation Query Language) scenarios.

## Features

- **File Browser**: Browse and select OQL scenario files from the scenarios directory
- **Code Editor**: Edit scenario files with syntax highlighting
- **Execution**: Run scenarios using OqlOS runtime in mock or real mode
- **Live Preview**: Real-time execution logs and status updates

## Installation

### Development Mode

```bash
make install
```

### With Development Dependencies

```bash
make dev
```

## Usage

### Start the Server

```bash
make run
```

The editor will be available at `http://localhost:8203`

### Production Mode

```bash
make run-prod
```

## API Endpoints

- `GET /api/v1/editor/files` - List all scenario files
- `GET /api/v1/editor/file/{path}` - Read file content
- `POST /api/v1/editor/file/{path}` - Write file content
- `POST /api/v1/editor/execute` - Execute a scenario

## Configuration

Environment variables:
- `WEB_PORT` - Server port (default: 8203)
- `HARDWARE_MODE` - Hardware mode: mock|real (default: mock)

## Development

### Build Distribution Packages

```bash
make build
```

### Run Tests

```bash
make test
```

### Clean Build Artifacts

```bash
make clean
```

## Publishing

### Publish to PyPI

```bash
make publish
```

### Publish to Test PyPI

```bash
make publish-test
```

## Project Structure

```
weboql/
├── weboql/
│   ├── __init__.py
│   ├── main.py          # FastAPI application entry point
│   └── api/
│       ├── __init__.py
│       ├── editor.py    # Editor API endpoints
│       └── static/
│           └── editor.html  # Web interface
├── pyproject.toml       # Project configuration
├── Makefile            # Build and deployment automation
└── README.md           # This file
```

## License

Licensed under Apache-2.0.
