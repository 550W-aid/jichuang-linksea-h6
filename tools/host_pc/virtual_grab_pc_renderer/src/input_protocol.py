from __future__ import annotations

import json
from pathlib import Path
from typing import Iterator

from model import BlobDetection, DetectionFrame, ImagePoint


class FrameLineDecoder:
    def __init__(self) -> None:
        self._buffer = bytearray()

    def feed(self, chunk: bytes) -> list[DetectionFrame]:
        self._buffer.extend(chunk)
        frames: list[DetectionFrame] = []

        while True:
            try:
                line_end = self._buffer.index(0x0A)
            except ValueError:
                break

            raw_line = bytes(self._buffer[:line_end]).rstrip(b"\r")
            del self._buffer[: line_end + 1]
            if not raw_line:
                continue

            try:
                frames.append(parse_frame_line(raw_line.decode("utf-8")))
            except (UnicodeDecodeError, ValueError, json.JSONDecodeError):
                continue

        return frames


def parse_frame_line(line: str) -> DetectionFrame:
    payload = json.loads(line)

    if "origin" not in payload:
        raise ValueError("frame is missing origin")
    for key in ("green", "red", "blue"):
        if key not in payload:
            raise ValueError(f"frame is missing {key}")

    return DetectionFrame(
        frame_id=int(payload.get("frame_id", 0)),
        origin=_parse_point(payload["origin"]),
        green=_parse_blob(payload["green"]),
        red=_parse_blob(payload["red"]),
        blue=_parse_blob(payload["blue"]),
    )


def load_jsonl_frames(path: str | Path) -> Iterator[DetectionFrame]:
    with Path(path).open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            yield parse_frame_line(line)


def _parse_point(payload: dict) -> ImagePoint:
    return ImagePoint(float(payload["x"]), float(payload["y"]))


def _parse_blob(payload: dict) -> BlobDetection:
    return BlobDetection(
        x=float(payload["x"]),
        y=float(payload["y"]),
        radius=float(payload.get("radius", 0.0)),
    )
