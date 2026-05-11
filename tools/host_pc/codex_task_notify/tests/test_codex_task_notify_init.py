import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(r"F:\codex\.worktrees\jichuang-linksea-h6-dev-person-2")
CLI = ROOT / "tools" / "host_pc" / "codex_task_notify" / "main.py"


class CodexTaskNotifyInitTests(unittest.TestCase):
    def test_init_writes_config_to_env_override_path(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            config_path = Path(tmpdir) / "config.json"
            env = os.environ.copy()
            env["CODEX_TASK_NOTIFY_CONFIG"] = str(config_path)

            result = subprocess.run(
                [
                    sys.executable,
                    str(CLI),
                    "init",
                    "--server",
                    "https://ntfy.sh",
                    "--topic",
                    "codex-test-topic-123",
                    "--title-prefix",
                    "Codex",
                    "--long-run-minutes",
                    "15",
                    "--desktop-toast",
                    "on",
                ],
                capture_output=True,
                text=True,
                env=env,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(config_path.exists())

            config = json.loads(config_path.read_text(encoding="utf-8"))
            self.assertEqual(config["provider"], "ntfy")
            self.assertEqual(config["server"], "https://ntfy.sh")
            self.assertEqual(config["topic"], "codex-test-topic-123")
            self.assertEqual(config["title_prefix"], "Codex")
            self.assertEqual(config["long_run_minutes"], 15)
            self.assertTrue(config["desktop_toast"])

    def test_event_rejects_unknown_type(self):
        result = subprocess.run(
            [
                sys.executable,
                str(CLI),
                "event",
                "--type",
                "unknown",
                "--message",
                "x",
            ],
            capture_output=True,
            text=True,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid choice", result.stderr.lower())

    def test_init_rejects_empty_topic(self):
        result = subprocess.run(
            [
                sys.executable,
                str(CLI),
                "init",
                "--server",
                "https://ntfy.sh",
                "--topic",
                "   ",
            ],
            capture_output=True,
            text=True,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("topic", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
