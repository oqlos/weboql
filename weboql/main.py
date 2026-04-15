"""WebOQL — Web-based OQL scenario editor and executor"""

import logging
import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, FileResponse
import uvicorn
from pydantic_settings import BaseSettings, SettingsConfigDict

from weboql.api.editor import router as editor_router
from weboql.api.plugins_api import router as plugins_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class Settings(BaseSettings):
    """Application settings loaded from environment variables and .env file"""
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"
    )
    
    # Server Configuration
    web_port: int = 8203
    web_host: str = "0.0.0.0"
    
    # Scenarios Directory
    scenarios_dir: str = "/home/tom/github/oqlos/oqlos/oqlos/scenarios"
    
    # Hardware Mode
    hardware_mode: str = "mock"
    
    # Hardware Service URLs
    piadc_url: str | None = None
    motor_url: str | None = None
    
    # Modbus Configuration
    modbus_serial_port: str | None = None
    modbus_host: str | None = None
    modbus_port: int | None = None
    
    # Logging
    log_level: str = "INFO"
    
    # CORS Settings
    cors_origins: str = "*"
    
    # Service Metadata
    service_name: str = "weboql"
    service_version: str = "0.1.0"


# Load settings
settings = Settings()
SCENARIOS_DIR = Path(settings.scenarios_dir)
WEB_PORT = settings.web_port

# Create FastAPI app
app = FastAPI(title="WebOQL Editor", version="0.1.0")

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins.split(",") if settings.cors_origins != "*" else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routers
app.include_router(editor_router)
app.include_router(plugins_router)

# Static files
STATIC_DIR = Path(__file__).parent / "api" / "static"


@app.get("/", response_class=HTMLResponse)
async def index_page():
    """Serve the editor UI at root"""
    editor_path = STATIC_DIR / "editor.html"
    if editor_path.exists():
        return FileResponse(editor_path)
    return HTMLResponse("<h1>WebOQL Editor</h1><p>editor.html not found.</p>")


@app.get("/editor", response_class=HTMLResponse)
async def editor_page():
    """Serve the editor UI"""
    editor_path = STATIC_DIR / "editor.html"
    if editor_path.exists():
        return FileResponse(editor_path)
    return HTMLResponse("<h1>WebOQL Editor</h1><p>editor.html not found.</p>")


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "ok",
        "service": settings.service_name,
        "version": settings.service_version,
        "port": WEB_PORT,
        "scenarios_dir": str(SCENARIOS_DIR),
        "hardware_mode": settings.hardware_mode
    }


def run():
    """Entry point for weboql-server console script."""
    uvicorn.run(app, host=settings.web_host, port=WEB_PORT)


if __name__ == "__main__":
    run()
