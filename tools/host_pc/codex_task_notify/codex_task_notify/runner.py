from __future__ import annotations

import subprocess
import sys
import time


def run_wrapped_command(command: list[str], dispatch, long_run_minutes: float) -> int:
    started = time.monotonic()
    completed = subprocess.run(command, text=True, stdout=sys.stdout, stderr=sys.stderr)
    runtime_seconds = time.monotonic() - started
    if completed.returncode == 0:
        dispatch("success", f"Command finished in {runtime_seconds:.1f}s")
    else:
        dispatch("failure", f"Command failed with exit code {completed.returncode}")
    threshold_seconds = max(long_run_minutes, 0.0) * 60.0
    if runtime_seconds >= threshold_seconds:
        dispatch("long-run-finished", f"Long task finished in {runtime_seconds:.1f}s")
    return completed.returncode
