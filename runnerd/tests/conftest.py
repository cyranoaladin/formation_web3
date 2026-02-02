"""Pytest fixtures for runnerd."""

from __future__ import annotations

import os
from typing import Generator

import pytest

try:
    from fastapi.testclient import TestClient
except Exception:  # pragma: no cover
    TestClient = None  # type: ignore[assignment]
from runnerd.app.settings import get_settings


@pytest.fixture()
def runnerd_client(tmp_path) -> Generator[TestClient, None, None]:
    """Create a TestClient with isolated workspaces directory via env override."""
    if TestClient is None:
        pytest.skip("fastapi is not installed; skipping API client tests")

    from runnerd.app.main import app

    workspaces_dir = tmp_path / "workspaces"
    workspaces_dir.mkdir(parents=True, exist_ok=True)

    old_env = dict(os.environ)
    os.environ["RUNNERD_WORKSPACES_DIR"] = str(workspaces_dir)
    os.environ["RUNNERD_LOCK_STALE_AFTER_S"] = "1"

    # Clear settings cache so new env is read
    get_settings.cache_clear()

    try:
        yield TestClient(app)
    finally:
        os.environ.clear()
        os.environ.update(old_env)
        get_settings.cache_clear()
