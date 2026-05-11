from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass
class NotifyConfig:
    provider: str
    server: str
    topic: str
    token: str | None
    title_prefix: str
    long_run_minutes: float
    desktop_toast: bool


def resolve_config_path() -> Path:
    override = os.environ.get("CODEX_TASK_NOTIFY_CONFIG")
    if override:
        return Path(override)
    return Path.home() / ".codex-task-notify" / "config.json"


def write_config(config: NotifyConfig) -> Path:
    path = resolve_config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(asdict(config), indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    return path


def load_config() -> NotifyConfig:
    path = resolve_config_path()
    data = json.loads(path.read_text(encoding="utf-8"))
    return NotifyConfig(
        provider=data["provider"],
        server=data["server"],
        topic=data["topic"],
        token=data.get("token"),
        title_prefix=data["title_prefix"],
        long_run_minutes=float(data["long_run_minutes"]),
        desktop_toast=bool(data["desktop_toast"]),
    )
