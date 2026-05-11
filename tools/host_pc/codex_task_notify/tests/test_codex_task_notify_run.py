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
CLI = ROOT / "tools" / "host_pc" / "codex_task_notify" / "main.py"


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


class CodexTaskNotifyRunTests(unittest.TestCase):
    def setUp(self):
        RecordingHandler.records = []

    def test_run_emits_success_and_returns_zero(self):
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
                        "run",
                        "--",
                        sys.executable,
                        "-c",
                        "print('ok')",
                    ],
                    capture_output=True,
                    text=True,
                    env=env,
                )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("ok", result.stdout)
            self.assertEqual(RecordingHandler.records[-1]["title"], "Codex: success")
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

    def test_run_emits_failure_and_returns_child_exit_code(self):
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
                        "run",
                        "--",
                        sys.executable,
                        "-c",
                        "import sys; sys.exit(3)",
                    ],
                    capture_output=True,
                    text=True,
                    env=env,
                )

            self.assertEqual(result.returncode, 3)
            self.assertEqual(RecordingHandler.records[-1]["title"], "Codex: failure")
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

    def test_run_emits_long_run_finished_when_threshold_is_reached(self):
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
                            "long_run_minutes": 0,
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
                        "run",
                        "--",
                        sys.executable,
                        "-c",
                        "import time; time.sleep(0.2)",
                    ],
                    capture_output=True,
                    text=True,
                    env=env,
                )

            self.assertEqual(result.returncode, 0, result.stderr)
            titles = [record["title"] for record in RecordingHandler.records]
            self.assertIn("Codex: long-run-finished", titles)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)


if __name__ == "__main__":
    unittest.main()
