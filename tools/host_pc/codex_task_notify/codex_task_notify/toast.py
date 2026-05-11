from __future__ import annotations

import subprocess


def _escape_single_quotes(text: str) -> str:
    return text.replace("'", "''")


def build_toast_command(title: str, body: str) -> list[str]:
    safe_title = _escape_single_quotes(title)
    safe_body = _escape_single_quotes(body)
    script = (
        "Add-Type -AssemblyName System.Windows.Forms; "
        "$notify = New-Object System.Windows.Forms.NotifyIcon; "
        "$notify.Icon = [System.Drawing.SystemIcons]::Information; "
        "$notify.BalloonTipTitle = '{title}'; "
        "$notify.BalloonTipText = '{body}'; "
        "$notify.Visible = $true; "
        "$notify.ShowBalloonTip(5000); "
        "Start-Sleep -Milliseconds 5500; "
        "$notify.Dispose()"
    ).format(title=safe_title, body=safe_body)
    return ["powershell", "-NoProfile", "-Command", script]


def send_windows_toast(title: str, body: str) -> None:
    subprocess.run(
        build_toast_command(title, body),
        check=True,
        capture_output=True,
        text=True,
    )
