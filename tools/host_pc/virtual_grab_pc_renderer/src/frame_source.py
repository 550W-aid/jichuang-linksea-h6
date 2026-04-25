from __future__ import annotations

import subprocess
import queue
import socketserver
import threading
import time
from pathlib import Path

from input_protocol import FrameLineDecoder, load_jsonl_frames
from model import BlobDetection, DetectionFrame, ImagePoint


class FrameSource:
    def get_latest_frame(self) -> DetectionFrame | None:
        raise NotImplementedError

    def close(self) -> None:
        return None


class DemoFrameSource(FrameSource):
    def __init__(self) -> None:
        self._start = time.perf_counter()
        self._frame_id = 0
        self._latest: DetectionFrame | None = None
        self._cycle_duration = 13.2

    def get_latest_frame(self) -> DetectionFrame:
        elapsed = time.perf_counter() - self._start
        if elapsed <= self._cycle_duration:
            t = elapsed
        else:
            t = (elapsed - self._cycle_duration) % self._cycle_duration
        self._frame_id += 1
        origin = ImagePoint(960.0, 540.0)
        green = BlobDetection(1110.0, 540.0, 36.0)
        red_rest = (860.0, 620.0)
        blue_rest = (692.0, 520.0)
        blue_prep = (742.0, 548.0)
        blue_hover = (776.0, 556.0)
        blue_clamp = (842.0, 588.0)
        blue_settle = (848.0, 576.0)
        blue_carry_end = (1188.0, 430.0)
        blue_place = (1270.0, 390.0)
        blue_press = (1290.0, 380.0)
        blue_release_contact = (1302.0, 374.0)
        blue_release_open = (1310.0, 366.0)
        blue_release_hold = (1360.0, 388.0)
        blue_release_end = (1480.0, 320.0)
        held_offset = (9.0, -13.0)

        def held_point(hand_point: tuple[float, float]) -> tuple[float, float]:
            return hand_point[0] + held_offset[0], hand_point[1] + held_offset[1]

        red_drop = held_point(blue_release_open)

        if t < 0.35:
            red_x, red_y = red_rest
            blue_x, blue_y = blue_rest
        elif t < 1.5:
            alpha = _smoothstep((t - 0.35) / 1.15)
            red_x, red_y = red_rest
            blue_x, blue_y = _lerp_point(blue_rest, blue_prep, alpha)
        elif t < 3.1:
            alpha = _smoothstep((t - 1.5) / 1.6)
            red_x, red_y = red_rest
            blue_x, blue_y = _lerp_point(blue_prep, blue_hover, alpha)
        elif t < 4.0:
            alpha = _smoothstep((t - 3.1) / 0.9)
            red_x, red_y = red_rest
            blue_x, blue_y = _lerp_point(blue_hover, blue_clamp, alpha)
        elif t < 5.0:
            alpha = _smoothstep((t - 4.0) / 1.0)
            blue_x, blue_y = _lerp_point(blue_clamp, blue_settle, alpha)
            red_x, red_y = _lerp_point(red_rest, held_point((blue_x, blue_y)), alpha)
        elif t < 7.8:
            alpha = _smoothstep((t - 5.0) / 2.8)
            blue_x, blue_y = _quadratic_bezier(
                blue_settle,
                (1006.0, 446.0),
                blue_carry_end,
                alpha,
            )
            red_x, red_y = held_point((blue_x, blue_y))
        elif t < 8.6:
            alpha = _smoothstep((t - 7.8) / 0.8)
            blue_x, blue_y = _quadratic_bezier(
                blue_carry_end,
                (1216.0, 412.0),
                blue_place,
                alpha,
            )
            red_x, red_y = held_point((blue_x, blue_y))
        elif t < 9.2:
            alpha = _smoothstep((t - 8.6) / 0.6)
            blue_x, blue_y = _lerp_point(blue_place, blue_press, alpha)
            red_x, red_y = held_point((blue_x, blue_y))
        elif t < 9.95:
            alpha = _smoothstep((t - 9.2) / 0.75)
            blue_x, blue_y = _quadratic_bezier(
                blue_press,
                (1210.0, 406.0),
                blue_release_contact,
                alpha,
            )
            red_x, red_y = held_point((blue_x, blue_y))
        elif t < 10.45:
            alpha = _smoothstep((t - 9.95) / 0.5)
            blue_x, blue_y = _lerp_point(blue_release_contact, blue_release_open, alpha)
            red_x, red_y = held_point((blue_x, blue_y))
        elif t < 11.52:
            alpha = _smoothstep((t - 10.45) / 1.07)
            blue_x, blue_y = _quadratic_bezier(
                blue_release_open,
                (1318.0, 362.0),
                blue_release_hold,
                alpha,
            )
            red_x, red_y = red_drop
        elif t < 11.82:
            alpha = _smoothstep((t - 11.52) / 0.3)
            blue_x, blue_y = _quadratic_bezier(
                blue_release_hold,
                (1444.0, 330.0),
                blue_release_end,
                alpha,
            )
            red_x, red_y = red_drop
        else:
            red_x, red_y = red_drop
            blue_x, blue_y = blue_release_end

        red = BlobDetection(red_x, red_y, 42.0)
        blue = BlobDetection(blue_x, blue_y, 58.0)
        self._latest = DetectionFrame(self._frame_id, origin, green, red, blue)
        return self._latest


class JsonlReplayFrameSource(FrameSource):
    def __init__(self, path: str | Path, replay_hz: float = 20.0) -> None:
        frames = list(load_jsonl_frames(path))
        if not frames:
            raise ValueError("jsonl file does not contain any frames")
        self._frames = frames
        self._interval = 1.0 / replay_hz
        self._next_deadline = time.perf_counter()
        self._index = 0
        self._latest = frames[0]

    def get_latest_frame(self) -> DetectionFrame:
        now = time.perf_counter()
        if now >= self._next_deadline:
            self._latest = self._frames[self._index]
            self._index = (self._index + 1) % len(self._frames)
            self._next_deadline = now + self._interval
        return self._latest


class TcpJsonFrameSource(FrameSource):
    def __init__(self, host: str = "127.0.0.1", port: int = 9000) -> None:
        self._queue: queue.Queue[DetectionFrame] = queue.Queue()
        self._latest: DetectionFrame | None = None
        queue_ref = self._queue

        class Handler(socketserver.StreamRequestHandler):
            def handle(self) -> None:
                decoder = FrameLineDecoder()
                while True:
                    raw_chunk = self.rfile.read(256)
                    if not raw_chunk:
                        break
                    for frame in decoder.feed(raw_chunk):
                        queue_ref.put(frame)

        self._server = socketserver.ThreadingTCPServer((host, port), Handler)
        self._server.daemon_threads = True
        self._thread = threading.Thread(
            target=self._server.serve_forever,
            name="tcp-json-frame-source",
            daemon=True,
        )
        self._thread.start()

    def get_latest_frame(self) -> DetectionFrame | None:
        while True:
            try:
                self._latest = self._queue.get_nowait()
            except queue.Empty:
                break
        return self._latest

    def close(self) -> None:
        self._server.shutdown()
        self._server.server_close()
        self._thread.join(timeout=1.0)


class SerialJsonFrameSource(FrameSource):
    def __init__(self, port: str, baud: int = 115200) -> None:
        self._queue: queue.Queue[DetectionFrame] = queue.Queue()
        self._latest: DetectionFrame | None = None
        self._running = True
        self._port = _normalize_serial_port_name(port)
        self._device_path = _serial_device_path(self._port)
        self._decoder = FrameLineDecoder()

        _configure_serial_port(self._port, baud)
        try:
            self._handle = open(self._device_path, "rb", buffering=0)
        except OSError as exc:
            raise RuntimeError(
                f"failed to open serial port {self._port}; "
                "check FPGA connection and COM port name"
            ) from exc

        self._thread = threading.Thread(
            target=self._read_loop,
            name=f"serial-json-frame-source-{self._port}",
            daemon=True,
        )
        self._thread.start()

    def get_latest_frame(self) -> DetectionFrame | None:
        while True:
            try:
                self._latest = self._queue.get_nowait()
            except queue.Empty:
                break
        return self._latest

    def close(self) -> None:
        self._running = False
        try:
            self._handle.close()
        except OSError:
            pass
        self._thread.join(timeout=1.0)

    def _read_loop(self) -> None:
        while self._running:
            try:
                raw_chunk = self._handle.read(256)
            except OSError:
                break

            if not raw_chunk:
                time.sleep(0.01)
                continue

            for frame in self._decoder.feed(raw_chunk):
                self._queue.put(frame)


def _normalize_serial_port_name(port: str) -> str:
    return port.strip().rstrip(":").upper()


def _serial_device_path(port: str) -> str:
    return rf"\\.\{port}"


def _configure_serial_port(port: str, baud: int) -> None:
    command = f"mode {port}: BAUD={baud} PARITY=n DATA=8 STOP=1"
    result = subprocess.run(
        ["cmd", "/c", command],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        error_text = (result.stdout + result.stderr).strip()
        raise RuntimeError(f"failed to configure serial port {port}: {error_text}")


def _lerp_point(
    start: tuple[float, float],
    end: tuple[float, float],
    alpha: float,
) -> tuple[float, float]:
    weight = _clamp01(alpha)
    return (
        start[0] + (end[0] - start[0]) * weight,
        start[1] + (end[1] - start[1]) * weight,
    )


def _quadratic_bezier(
    start: tuple[float, float],
    control: tuple[float, float],
    end: tuple[float, float],
    alpha: float,
) -> tuple[float, float]:
    weight = _clamp01(alpha)
    one_minus = 1.0 - weight
    return (
        one_minus * one_minus * start[0]
        + 2.0 * one_minus * weight * control[0]
        + weight * weight * end[0],
        one_minus * one_minus * start[1]
        + 2.0 * one_minus * weight * control[1]
        + weight * weight * end[1],
    )


def _smoothstep(value: float) -> float:
    weight = _clamp01(value)
    return weight * weight * (3.0 - 2.0 * weight)


def _clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))
