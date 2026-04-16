"""Shared DSL schema endpoints for GUI clients."""

from __future__ import annotations

from fastapi import APIRouter

from oqlos.dsl import DslSchema, get_default_dsl_schema

router = APIRouter(prefix="/api/v1/schema", tags=["schema"])


@router.get("", response_model=DslSchema)
async def get_schema() -> DslSchema:
    """Return the canonical CQL/OQL schema for editor clients."""
    return get_default_dsl_schema()