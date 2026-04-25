from __future__ import annotations

import argparse
from pathlib import Path

from frame_source import (
    DemoFrameSource,
    JsonlReplayFrameSource,
    SerialJsonFrameSource,
    TcpJsonFrameSource,
)
from renderer import VirtualGrabRenderer


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Virtual grab renderer")
    parser.add_argument(
        "--input",
        choices=("demo", "jsonl", "tcp", "serial"),
        default="demo",
        help="frame source type",
    )
    parser.add_argument(
        "--jsonl-path", 
        default=Path(__file__).resolve().parents[1] / "sample_frames.jsonl",
        help="jsonl replay file path",
    )
    parser.add_argument("--tcp-host", default="127.0.0.1", help="TCP listen host")
    parser.add_argument("--tcp-port", type=int, default=9000, help="TCP listen port")
    parser.add_argument("--serial-port", default="COM3", help="serial COM port name")
    parser.add_argument("--serial-baud", type=int, default=115200, help="serial baud rate")
    parser.add_argument(
        "--smoke-test",
        action="store_true",
        help="render one frame and exit",
    )
    return parser.parse_args(argv)


def build_source(args: argparse.Namespace):
    if args.input == "demo":
        return DemoFrameSource()
    if args.input == "jsonl":
        return JsonlReplayFrameSource(args.jsonl_path)
    if args.input == "tcp":
        return TcpJsonFrameSource(args.tcp_host, args.tcp_port)
    return SerialJsonFrameSource(args.serial_port, args.serial_baud)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    source = build_source(args)
    app = VirtualGrabRenderer(source)
    if args.smoke_test:
        app.render_once()
        app.close()
        return 0

    try:
        app.run()
    finally:
        app.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
