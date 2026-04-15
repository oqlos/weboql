"""WebOQL Plugin management API — config editing, installation, discovery."""

from __future__ import annotations

import asyncio
import logging
import subprocess
import sys
from pathlib import Path
from typing import Any

import yaml
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/plugins", tags=["plugins"])

# Default path to the unified plugin config
_DEFAULT_CONFIG = Path(__file__).resolve().parents[3] / "oqlos" / "oqlos" / "hardware" / "hardware_config.yaml"
# Fallback: look relative to oqlos package
try:
    import oqlos.hardware
    _HW_DIR = Path(oqlos.hardware.__file__).resolve().parent
    _DEFAULT_CONFIG = _HW_DIR / "hardware_config.yaml"
except Exception:
    pass


# ---------- Models ----------

class LineExecutionRequest(BaseModel):
    source: str
    mode: str = "dry-run"
    skip_waits: bool = True


class PluginInstallRequest(BaseModel):
    """Install a plugin package from PyPI or a local path."""
    package: str              # e.g. "oqlos-driver-dri0050>=1.0" or "/path/to/pkg"
    extras: list[str] = Field(default_factory=list)


class PluginConfigUpdate(BaseModel):
    """Full or partial YAML content to write back."""
    yaml_content: str


# ---------- Execute single line / snippet ----------

@router.post("/execute-line")
async def execute_line(request: LineExecutionRequest) -> dict[str, Any]:
    """Execute a single OQL/CQL line or snippet and return the result."""
    try:
        from oqlos.core.interpreter import CqlInterpreter

        # Wrap bare command in minimal scenario envelope if needed
        source = request.source.strip()
        if not source:
            return {"ok": True, "steps": [], "output": "(empty)"}

        # If the user typed a bare line (no SCENARIO header), wrap it
        if not source.upper().startswith("SCENARIO"):
            source = (
                "SCENARIO: inline\n"
                "STEPS:\n"
                f"  {source}\n"
            )

        interpreter = CqlInterpreter(
            mode="dry-run" if request.mode == "mock" else "execute",
            quiet=False,
            skip_waits=request.skip_waits,
            use_plugin_gateway=True,
        )
        doc = interpreter.parse(source, "<repl>")
        result = interpreter.execute(doc)

        return {
            "ok": result.ok,
            "steps_executed": len(result.steps),
            "duration_ms": result.duration_ms,
            "errors": result.errors,
            "warnings": result.warnings,
            "steps": [
                {
                    "line": s.line if hasattr(s, "line") else str(s),
                    "ok": s.ok if hasattr(s, "ok") else True,
                }
                for s in result.steps
            ],
        }
    except Exception as exc:
        logger.error("execute-line error: %s", exc, exc_info=True)
        raise HTTPException(status_code=500, detail=str(exc))


# ---------- Plugin config CRUD ----------

@router.get("/config")
async def get_plugin_config() -> dict[str, Any]:
    """Return the unified plugin YAML config as structured data + raw text."""
    if not _DEFAULT_CONFIG.exists():
        raise HTTPException(status_code=404, detail=f"Config not found: {_DEFAULT_CONFIG}")
    raw = _DEFAULT_CONFIG.read_text(encoding="utf-8")
    data = yaml.safe_load(raw) or {}
    return {
        "path": str(_DEFAULT_CONFIG),
        "raw": raw,
        "plugins": data.get("plugins", {}),
    }


@router.put("/config")
async def update_plugin_config(body: PluginConfigUpdate) -> dict[str, str]:
    """Overwrite the unified plugin YAML config with new content."""
    # Validate YAML before writing
    try:
        parsed = yaml.safe_load(body.yaml_content)
        if not isinstance(parsed, dict) or "plugins" not in parsed:
            raise ValueError("YAML must have a top-level 'plugins:' key")
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid YAML: {exc}")

    _DEFAULT_CONFIG.write_text(body.yaml_content, encoding="utf-8")
    logger.info("Plugin config updated: %s", _DEFAULT_CONFIG)
    return {"status": "saved", "path": str(_DEFAULT_CONFIG)}


@router.get("/list")
async def list_plugins() -> dict[str, Any]:
    """List registered plugins (from oqlos.hardware.plugins.PluginRegistry)."""
    try:
        from oqlos.hardware.plugins import PluginRegistry
        return {"plugins": PluginRegistry.list_plugins()}
    except Exception as exc:
        logger.error("list_plugins error: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc))


@router.get("/peripherals/{plugin_id}")
async def get_peripherals(plugin_id: str) -> dict[str, Any]:
    """Return peripheral definitions for a plugin from the YAML config."""
    if not _DEFAULT_CONFIG.exists():
        raise HTTPException(status_code=404, detail="Config not found")
    data = yaml.safe_load(_DEFAULT_CONFIG.read_text()) or {}
    plugin_data = data.get("plugins", {}).get(plugin_id)
    if not plugin_data:
        raise HTTPException(status_code=404, detail=f"Plugin '{plugin_id}' not in config")
    return {
        "plugin_id": plugin_id,
        "peripherals": plugin_data.get("peripherals", {}),
    }


# ---------- Plugin installation ----------

@router.post("/install")
async def install_plugin(request: PluginInstallRequest) -> dict[str, Any]:
    """
    pip-install a plugin package into the current venv.

    Example request body::

        {"package": "oqlos-driver-dri0050>=1.0"}

    The package should declare ``oqlos_hardware`` entry points so it
    is auto-discovered on next restart / reload.
    """
    pip = [sys.executable, "-m", "pip", "install", request.package]
    if request.extras:
        pip[-1] = f"{request.package}[{','.join(request.extras)}]"

    logger.info("Installing plugin package: %s", " ".join(pip))
    try:
        proc = await asyncio.create_subprocess_exec(
            *pip,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=120)
        output = stdout.decode(errors="replace")
        success = proc.returncode == 0
        if success:
            logger.info("Plugin installed: %s", request.package)
        else:
            logger.error("pip install failed: %s", output[-500:])
        return {
            "success": success,
            "package": request.package,
            "output": output[-2000:],  # cap output size
            "returncode": proc.returncode,
        }
    except asyncio.TimeoutError:
        raise HTTPException(status_code=504, detail="pip install timed out (120s)")
    except Exception as exc:
        logger.error("install_plugin error: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/reload")
async def reload_plugins() -> dict[str, Any]:
    """Reload plugin configs from YAML and re-discover entry points."""
    try:
        from oqlos.hardware.plugins import PluginRegistry
        configs = PluginRegistry.load_configs_from_yaml(_DEFAULT_CONFIG)
        discovered = PluginRegistry.discover_entry_point_plugins()
        return {
            "configs_loaded": len(configs),
            "entry_points_discovered": discovered,
            "plugins": list(configs.keys()),
        }
    except Exception as exc:
        logger.error("reload error: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc))
