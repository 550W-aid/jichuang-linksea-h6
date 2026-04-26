from __future__ import annotations

import queue
import socket
import threading
import time
from dataclasses import dataclass
from pathlib import Path

import cv2
import serial
from PySide6.QtCore import QThread, Signal

from .protocol import VideoChunkConfig, chunk_frame_payload


@dataclass(slots=True)
class SerialConfig:
    port: str
    baudrate: int = 115200
    bytesize: int = 8
    stopbits: int = 1
    parity: str = "N"
    timeout: float = 0.01


class SerialWorker(QThread):
    rx = Signal(bytes)
    status = Signal(str)
    error = Signal(str)

    def __init__(self) -> None:
        super().__init__()
        self._cmd_q: queue.SimpleQueue[tuple[str, object]] = queue.SimpleQueue()
        self._running = threading.Event()
        self._running.set()
        self._ser: serial.Serial | None = None

    def open_port(self, cfg: SerialConfig) -> None:
        self._cmd_q.put(("open", cfg))

    def close_port(self) -> None:
        self._cmd_q.put(("close", None))

    def send_data(self, data: bytes) -> None:
        self._cmd_q.put(("send", data))

    def stop(self) -> None:
        self._cmd_q.put(("close", None))
        self._running.clear()

    def _apply_open(self, cfg: SerialConfig) -> None:
        try:
            if self._ser and self._ser.is_open:
                self._ser.close()
            self._ser = serial.Serial(
                port=cfg.port,
                baudrate=cfg.baudrate,
                bytesize=cfg.bytesize,
                stopbits=cfg.stopbits,
                parity=cfg.parity,
                timeout=cfg.timeout,
            )
            self.status.emit(f"Serial connected: {cfg.port} @ {cfg.baudrate}")
        except Exception as exc:
            self.error.emit(f"Serial open failed: {exc}")

    def _apply_close(self) -> None:
        if self._ser:
            try:
                if self._ser.is_open:
                    self._ser.close()
                    self.status.emit("Serial disconnected")
            except Exception as exc:
                self.error.emit(f"Serial close failed: {exc}")
            finally:
                self._ser = None

    def _apply_send(self, data: bytes) -> None:
        if not self._ser or not self._ser.is_open:
            self.error.emit("Serial send failed: port not open")
            return
        try:
            self._ser.write(data)
        except Exception as exc:
            self.error.emit(f"Serial send failed: {exc}")

    def run(self) -> None:
        while self._running.is_set():
            try:
                while True:
                    cmd, payload = self._cmd_q.get_nowait()
                    if cmd == "open":
                        self._apply_open(payload)  # type: ignore[arg-type]
                    elif cmd == "close":
                        self._apply_close()
                    elif cmd == "send":
                        self._apply_send(payload)  # type: ignore[arg-type]
            except queue.Empty:
                pass

            if self._ser and self._ser.is_open:
                try:
                    waiting = self._ser.in_waiting
                    if waiting:
                        data = self._ser.read(waiting)
                        if data:
                            self.rx.emit(data)
                    else:
                        data = self._ser.read(1)
                        if data:
                            self.rx.emit(data)
                except Exception as exc:
                    self.error.emit(f"Serial RX error: {exc}")
                    self._apply_close()
            self.msleep(4)

        self._apply_close()


@dataclass(slots=True)
class UdpConfig:
    bind_ip: str
    bind_port: int
    remote_ip: str
    remote_port: int


class EthernetWorker(QThread):
    rx = Signal(bytes, str, int)
    status = Signal(str)
    error = Signal(str)

    def __init__(self) -> None:
        super().__init__()
        self._cmd_q: queue.SimpleQueue[tuple[str, object]] = queue.SimpleQueue()
        self._tx_q: queue.SimpleQueue[bytes] = queue.SimpleQueue()
        self._running = threading.Event()
        self._running.set()
        self._sock: socket.socket | None = None
        self._remote: tuple[str, int] = ("127.0.0.1", 6000)

    def configure_udp(self, cfg: UdpConfig) -> None:
        self._cmd_q.put(("configure", cfg))

    def close_socket(self) -> None:
        self._cmd_q.put(("close", None))

    def send_data(self, data: bytes) -> None:
        self._tx_q.put(data)

    def stop(self) -> None:
        self._cmd_q.put(("close", None))
        self._running.clear()

    def _apply_configure(self, cfg: UdpConfig) -> None:
        try:
            if self._sock:
                self._sock.close()
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sock.bind((cfg.bind_ip, cfg.bind_port))
            sock.setblocking(False)
            self._sock = sock
            self._remote = (cfg.remote_ip, cfg.remote_port)
            self.status.emit(
                f"Ethernet UDP ready: bind {cfg.bind_ip}:{cfg.bind_port} -> remote {cfg.remote_ip}:{cfg.remote_port}"
            )
        except Exception as exc:
            self.error.emit(f"Ethernet configure failed: {exc}")

    def _apply_close(self) -> None:
        if self._sock:
            try:
                self._sock.close()
            except Exception as exc:
                self.error.emit(f"Ethernet close failed: {exc}")
            finally:
                self._sock = None
                self.status.emit("Ethernet socket closed")

    def run(self) -> None:
        while self._running.is_set():
            try:
                while True:
                    cmd, payload = self._cmd_q.get_nowait()
                    if cmd == "configure":
                        self._apply_configure(payload)  # type: ignore[arg-type]
                    elif cmd == "close":
                        self._apply_close()
            except queue.Empty:
                pass

            if self._sock:
                try:
                    for _ in range(8):
                        try:
                            data, addr = self._sock.recvfrom(65535)
                        except BlockingIOError:
                            break
                        if data:
                            self.rx.emit(data, addr[0], addr[1])
                except Exception as exc:
                    self.error.emit(f"Ethernet RX error: {exc}")

                try:
                    for _ in range(16):
                        data = self._tx_q.get_nowait()
                        self._sock.sendto(data, self._remote)
                except queue.Empty:
                    pass
                except Exception as exc:
                    self.error.emit(f"Ethernet TX error: {exc}")

            self.msleep(2)

        self._apply_close()


@dataclass(slots=True)
class VideoStreamConfig:
    source: str
    fps: int
    jpeg_quality: int
    mtu_payload: int
    width: int
    height: int


class VideoStreamWorker(QThread):
    packet_ready = Signal(bytes)
    status = Signal(str)
    error = Signal(str)
    frame_stat = Signal(int, int)

    def __init__(self) -> None:
        super().__init__()
        self._running = threading.Event()
        self._running.clear()
        self._cfg: VideoStreamConfig | None = None

    def start_stream(self, cfg: VideoStreamConfig) -> None:
        self._cfg = cfg
        if not self.isRunning():
            self._running.set()
            self.start()

    def stop_stream(self) -> None:
        self._running.clear()

    def _open_capture(self, source: str) -> cv2.VideoCapture:
        if source.isdigit():
            return cv2.VideoCapture(int(source))
        return cv2.VideoCapture(source)

    def _encode_jpeg(self, frame, quality: int) -> bytes:
        ok, buf = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), quality])
        if not ok:
            raise RuntimeError("JPEG encode failed")
        return bytes(buf)

    def run(self) -> None:
        if not self._cfg:
            self.error.emit("Video stream config missing")
            return

        cfg = self._cfg
        cap = self._open_capture(cfg.source)
        if not cap.isOpened():
            self.error.emit(f"Video open failed: {cfg.source}")
            return

        self.status.emit(f"Video streaming started: source={cfg.source}")
        frame_id = 0
        last_tick = time.perf_counter()
        frame_count = 0
        period = 1.0 / max(1, cfg.fps)
        chunk_cfg = VideoChunkConfig(mtu_payload=cfg.mtu_payload)

        try:
            while self._running.is_set():
                begin = time.perf_counter()
                ok, frame = cap.read()
                if not ok:
                    self.status.emit("Video ended or read failed")
                    break

                if cfg.width > 0 and cfg.height > 0:
                    frame = cv2.resize(frame, (cfg.width, cfg.height), interpolation=cv2.INTER_LINEAR)

                payload = self._encode_jpeg(frame, cfg.jpeg_quality)
                packets = chunk_frame_payload(frame_id=frame_id, payload=payload, cfg=chunk_cfg)
                for pkt in packets:
                    self.packet_ready.emit(pkt)

                frame_id += 1
                frame_count += 1
                now = time.perf_counter()
                if now - last_tick >= 1.0:
                    self.frame_stat.emit(frame_count, len(payload))
                    frame_count = 0
                    last_tick = now

                spent = time.perf_counter() - begin
                wait_s = period - spent
                if wait_s > 0:
                    time.sleep(wait_s)
        except Exception as exc:
            self.error.emit(f"Video stream error: {exc}")
        finally:
            cap.release()
            self.status.emit("Video streaming stopped")
