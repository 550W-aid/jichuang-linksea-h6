import json
import os
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


ROOT = Path(r"F:\codex\.worktrees\jichuang-linksea-h6-dev-person-2")
TOOL_DIR = ROOT / "tools" / "host_pc" / "codex_task_notify"
CLI = TOOL_DIR / "main.py"

if str(TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(TOOL_DIR))


from codex_task_notify.dispatch import EVENT_PRIORITIES, dispatch_event  # noqa: E402
from codex_task_notify.toast import build_toast_command  # noqa: E402


class RecordingHandler(BaseHTTPRequestHandler):
    records = []

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8")
        self.__class__.records.append(
            {
                "path": self.path,
                "title": self.headers.get("Title"),
                "priority": self.headers.get("Priority"),
                "body": body,
            }
        )
        self.send_response(200)
        self.end_headers()

    def log_message(self, format, *args):
        return


class CodexTaskNotifyEventTests(unittest.TestCase):
    def setUp(self):
        RecordingHandler.records = []

    def test_event_posts_to_ntfy_topic(self):
        server = HTTPServer(("127.0.0.1", 0), RecordingHandler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()

        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                config_path = Path(tmpdir) / "config.json"
                config_path.write_text(
                    json.dumps(
                        {
                            "provider": "ntfy",
                            "server": f"http://127.0.0.1:{server.server_port}",
                            "topic": "codex-topic",
                            "token": None,
                            "title_prefix": "Codex",
                            "long_run_minutes": 15,
                            "desktop_toast": False,
                        }
                    ),
                    encoding="utf-8",
                )
                env = os.environ.copy()
                env["CODEX_TASK_NOTIFY_CONFIG"] = str(config_path)

                result = subprocess.run(
                    [
                        sys.executable,
                        str(CLI),
                        "event",
                        "--type",
                        "manual-attention",
                        "--message",
                        "Need confirmation before overwrite",
                    ],
                    capture_output=True,
                    text=True,
                    env=env,
                )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len(RecordingHandler.records), 1)
            self.assertEqual(RecordingHandler.records[0]["path"], "/codex-topic")
            self.assertIn("Need confirmation", RecordingHandler.records[0]["body"])
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

    def test_powershell_wrapper_can_forward_test_command(self):
        server = HTTPServer(("127.0.0.1", 0), RecordingHandler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()

        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                config_path = Path(tmpdir) / "config.json"
                config_path.write_text(
                    json.dumps(
                        {
                            "provider": "ntfy",
                            "server": f"http://127.0.0.1:{server.server_port}",
                            "topic": "codex-topic",
                            "token": None,
                            "title_prefix": "Codex",
                            "long_run_minutes": 15,
                            "desktop_toast": False,
                        }
                    ),
                    encoding="utf-8",
                )
                env = os.environ.copy()
                env["CODEX_TASK_NOTIFY_CONFIG"] = str(config_path)

                result = subprocess.run(
                    [
                        "powershell",
                        "-ExecutionPolicy",
                        "Bypass",
                        "-File",
                        str(TOOL_DIR / "codex-task-notify.ps1"),
                        "test",
                    ],
                    capture_output=True,
                    text=True,
                    env=env,
                )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len(RecordingHandler.records), 1)
            self.assertEqual(RecordingHandler.records[0]["title"], "Codex: success")
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)


class DispatchSafetyTests(unittest.TestCase):
    def test_success_and_long_run_priority_map(self):
        self.assertEqual(EVENT_PRIORITIES["success"], "3")
        self.assertEqual(EVENT_PRIORITIES["long-run-finished"], "4")

    def test_toast_failure_does_not_abort_provider_send(self):
        sent = []

        class FakeProvider:
            def send(self, title, body, priority):
                sent.append((title, body, priority))

        def broken_toast(*args, **kwargs):
            raise RuntimeError("toast failed")

        dispatch_event(
            provider=FakeProvider(),
            title_prefix="Codex",
            event_type="success",
            message="Done",
            toast_enabled=True,
            toast_sender=broken_toast,
        )

        self.assertEqual(len(sent), 1)

    def test_build_toast_command_embeds_title_and_body(self):
        command = build_toast_command("Codex: success", "Done body")
        rendered = " ".join(command)

        self.assertIn("powershell", command[0].lower())
        self.assertIn("Codex: success", rendered)
        self.assertIn("Done body", rendered)


if __name__ == "__main__":
    unittest.main()
