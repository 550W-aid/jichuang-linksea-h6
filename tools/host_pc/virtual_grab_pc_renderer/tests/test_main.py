from pathlib import Path
import sys
import unittest
from unittest.mock import patch


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = PROJECT_ROOT / "src"
sys.path.insert(0, str(SRC_ROOT))

from main import build_source, main, parse_args  # type: ignore


class MainTests(unittest.TestCase):
    def test_parse_args_supports_serial_input(self) -> None:
        args = parse_args(["--input", "serial", "--serial-port", "COM5", "--serial-baud", "921600"])

        self.assertEqual(args.input, "serial")
        self.assertEqual(args.serial_port, "COM5")
        self.assertEqual(args.serial_baud, 921600)

    def test_build_source_dispatches_to_serial_source(self) -> None:
        args = parse_args(["--input", "serial", "--serial-port", "COM7"])
        with patch("main.SerialJsonFrameSource") as serial_source_cls:
            serial_source_cls.return_value = object()
            source = build_source(args)

        serial_source_cls.assert_called_once_with("COM7", 115200)
        self.assertIs(source, serial_source_cls.return_value)

    def test_main_accepts_explicit_argv_for_smoke_test(self) -> None:
        fake_source = object()
        with (
            patch("main.build_source", return_value=fake_source) as build_source_mock,
            patch("main.VirtualGrabRenderer") as renderer_cls,
        ):
            renderer = renderer_cls.return_value
            exit_code = main(["--input", "demo", "--smoke-test"])

        self.assertEqual(exit_code, 0)
        build_source_mock.assert_called_once()
        renderer_cls.assert_called_once_with(fake_source)
        renderer.render_once.assert_called_once_with()
        renderer.close.assert_called_once_with()
        renderer.run.assert_not_called()

    def test_main_runs_renderer_loop_when_not_smoke_test(self) -> None:
        fake_source = object()
        with (
            patch("main.build_source", return_value=fake_source) as build_source_mock,
            patch("main.VirtualGrabRenderer") as renderer_cls,
        ):
            renderer = renderer_cls.return_value
            exit_code = main(["--input", "demo"])

        self.assertEqual(exit_code, 0)
        build_source_mock.assert_called_once()
        renderer_cls.assert_called_once_with(fake_source)
        renderer.run.assert_called_once_with()
        renderer.close.assert_called_once_with()
        renderer.render_once.assert_not_called()


if __name__ == "__main__":
    unittest.main()
