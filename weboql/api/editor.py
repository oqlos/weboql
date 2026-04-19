"""File editor service for managing and executing OQL scenarios"""

from __future__ import annotations

import logging
import os
import pathlib
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/editor", tags=["editor"])

SCENARIOS_DIR = pathlib.Path(os.getenv("SCENARIOS_DIR", "/home/tom/github/oqlos/oqlos/oqlos/scenarios"))


class SystemStatus(BaseModel):
    """System status information"""
    scenarios_dir: str
    scenarios_dir_exists: bool
    scenarios_count: int
    hardware_mode: str
    piadc_url: str | None
    motor_url: str | None
    modbus_serial: str | None
    modbus_host: str | None
    modbus_port: int | None
    piadc_available: bool = False
    motor_available: bool = False
    modbus_available: bool = False


class FileInfo(BaseModel):
    name: str
    path: str
    size: int
    is_directory: bool


class FileContent(BaseModel):
    path: str
    content: str


class ExecutionRequest(BaseModel):
    scenario_file: str
    mode: str = "mock"
    speed: float = 1.0
    execution_id: str | None = None
    timestamp: str | None = None


def _ensure_safe_path(file_path: str) -> pathlib.Path:
    """Ensure the file path is within the scenarios directory"""
    full_path = (SCENARIOS_DIR / file_path).resolve()
    if not str(full_path).startswith(str(SCENARIOS_DIR.resolve())):
        raise HTTPException(status_code=403, detail="Access denied: path outside scenarios directory")
    return full_path


@router.get("/files")
async def list_files() -> dict[str, Any]:
    """List all files in the scenarios directory"""
    try:
        files = []
        for item in SCENARIOS_DIR.iterdir():
            relative_path = item.relative_to(SCENARIOS_DIR)
            files.append(FileInfo(
                name=item.name,
                path=str(relative_path),
                size=item.stat().st_size if item.is_file() else 0,
                is_directory=item.is_dir()
            ))
        return {"files": sorted(files, key=lambda x: (not x.is_directory, x.name))}
    except Exception as e:
        logger.error(f"Error listing files: {e}")
        raise HTTPException(status_code=500, detail=str(e))


async def _check_http_health(url: str | None) -> bool:
    """Check an HTTP service health endpoint."""
    if not url:
        return False
    try:
        import httpx
        async with httpx.AsyncClient(timeout=2.0) as client:
            response = await client.get(f"{url}/health")
            return response.status_code == 200
    except:
        return False


async def _check_piadc_health(piadc_url: str | None) -> bool:
    """Check PIADC service health."""
    return await _check_http_health(piadc_url)


async def _check_motor_health(motor_url: str | None) -> bool:
    """Check Motor service health."""
    return await _check_http_health(motor_url)


def _check_modbus_health(modbus_serial_port: str | None) -> bool:
    """Check Modbus serial port availability."""
    if not modbus_serial_port:
        return False
    try:
        import serial.tools.list_ports
        ports = [port.device for port in serial.tools.list_ports.comports()]
        return modbus_serial_port in ports
    except:
        return False


def _count_scenario_files() -> int:
    """Count .oql scenario files in scenarios directory."""
    if not SCENARIOS_DIR.exists():
        return 0
    return len([f for f in SCENARIOS_DIR.iterdir() if f.is_file() and f.suffix == '.oql'])


def _get_attr_safe(obj, attr: str, default=None):
    """Safely get attribute from object."""
    return getattr(obj, attr, default) if hasattr(obj, attr) else default


@router.get("/status")
async def get_system_status() -> SystemStatus:
    """Get system status and configuration.

    Refactored from CC=18 to CC<10 using helper functions.
    """
    try:
        from weboql.main import settings

        # Gather all health checks
        piadc_available = await _check_piadc_health(_get_attr_safe(settings, 'piadc_url'))
        motor_available = await _check_motor_health(_get_attr_safe(settings, 'motor_url'))
        modbus_available = _check_modbus_health(_get_attr_safe(settings, 'modbus_serial_port'))

        return SystemStatus(
            scenarios_dir=str(SCENARIOS_DIR),
            scenarios_dir_exists=SCENARIOS_DIR.exists(),
            scenarios_count=_count_scenario_files(),
            hardware_mode=_get_attr_safe(settings, 'hardware_mode', 'mock'),
            piadc_url=_get_attr_safe(settings, 'piadc_url'),
            motor_url=_get_attr_safe(settings, 'motor_url'),
            modbus_serial=_get_attr_safe(settings, 'modbus_serial_port'),
            modbus_host=_get_attr_safe(settings, 'modbus_host'),
            modbus_port=_get_attr_safe(settings, 'modbus_port'),
            piadc_available=piadc_available,
            motor_available=motor_available,
            modbus_available=modbus_available
        )
    except Exception as e:
        logger.error(f"Error getting system status: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/file/{file_path:path}")
async def read_file(file_path: str) -> FileContent:
    """Read a file's content"""
    try:
        full_path = _ensure_safe_path(file_path)
        if not full_path.exists():
            raise HTTPException(status_code=404, detail="File not found")
        if full_path.is_dir():
            raise HTTPException(status_code=400, detail="Path is a directory")
        
        content = full_path.read_text(encoding="utf-8")
        return FileContent(path=file_path, content=content)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error reading file: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/file/{file_path:path}")
async def write_file(file_path: str, file_content: FileContent) -> dict[str, str]:
    """Write content to a file"""
    try:
        full_path = _ensure_safe_path(file_path)
        
        # Create parent directories if they don't exist
        full_path.parent.mkdir(parents=True, exist_ok=True)
        
        full_path.write_text(file_content.content, encoding="utf-8")
        return {"status": "success", "path": file_path}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error writing file: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/execute")
async def execute_scenario(request: ExecutionRequest) -> dict[str, Any]:
    """Execute a scenario file using oqlos runtime"""
    try:
        # Log execution parameters
        logger.info(f"Executing scenario: file={request.scenario_file}, mode={request.mode}, speed={request.speed}, execution_id={request.execution_id}, timestamp={request.timestamp}")

        from oqlos.core.interpreter import CqlInterpreter
        
        # Read the scenario file
        full_path = _ensure_safe_path(request.scenario_file)
        if not full_path.exists():
            logger.error(f"Scenario file not found: {request.scenario_file}")
            raise HTTPException(status_code=404, detail="Scenario file not found")
        
        content = full_path.read_text(encoding="utf-8")
        
        # Create interpreter with appropriate mode
        interpreter_mode = "dry-run" if request.mode == "mock" else "execute"
        logger.info(f"Using interpreter mode: {interpreter_mode}")
        
        interpreter = CqlInterpreter(
            mode=interpreter_mode,
            quiet=False,
            skip_waits=request.speed > 2.0
        )
        
        # Parse and execute the scenario
        doc = interpreter.parse(content, request.scenario_file)
        logger.info(f"Parsed scenario: {doc.metadata.scenario_name}")
        
        result = interpreter.execute(doc)
        logger.info(f"Execution result: ok={result.ok}, steps={len(result.steps)}, duration_ms={result.duration_ms}")
        
        return {
            "status": "success",
            "ok": result.ok,
            "scenario_name": doc.metadata.scenario_name or request.scenario_file,
            "steps_executed": len(result.steps),
            "duration_ms": result.duration_ms,
            "errors": result.errors,
            "warnings": result.warnings,
            "execution_id": request.execution_id,
            "timestamp": request.timestamp
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error executing scenario: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
