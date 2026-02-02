from __future__ import annotations

from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    runnerd_workspaces_dir: str = "/workspaces"
    runnerd_runner_image: str = "rbk-runner-base:0.1.0"
    runnerd_max_log_bytes: int = 200_000
    runnerd_max_out_bytes: int = 2_000_000
    runnerd_lock_stale_after_s: int = 300


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
