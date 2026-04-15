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


@router.get("/status")
async def get_system_status() -> SystemStatus:
    """Get system status and configuration"""
    try:
        # Load settings from environment and .env
        from weboql.main import settings
        
        # Count scenario files
        scenarios_count = 0
        if SCENARIOS_DIR.exists():
            scenarios_count = len([f for f in SCENARIOS_DIR.iterdir() if f.is_file() and f.suffix == '.oql'])
        
        return SystemStatus(
            scenarios_dir=str(SCENARIOS_DIR),
            scenarios_dir_exists=SCENARIOS_DIR.exists(),
            scenarios_count=scenarios_count,
            hardware_mode=settings.hardware_mode,
            piadc_url=settings.piadc_url if hasattr(settings, 'piadc_url') else None,
            motor_url=settings.motor_url if hasattr(settings, 'motor_url') else None,
            modbus_serial=settings.modbus_serial_port if hasattr(settings, 'modbus_serial_port') else None,
            modbus_host=settings.modbus_host if hasattr(settings, 'modbus_host') else None,
            modbus_port=settings.modbus_port if hasattr(settings, 'modbus_port') else None
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
