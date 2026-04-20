#!/usr/bin/env python3
"""Simple UART register tool for the Link-Sea-H6 FPGA control plane."""

from __future__ import annotations

import argparse
import sys
import time
from dataclasses import dataclass

try:
    import serial
except ImportError as exc:  # pragma: no cover - user environment dependent
    raise SystemExit(
        "Missing dependency: pyserial. Install with `pip install pyserial`."
    ) from exc


FRAME_HEAD = 0x55
RESP_HEAD = 0xAA
CMD_WRITE = 0x01
CMD_READ = 0x02
CMD_PING = 0x03

STATUS_OK = 0x00

REGISTER_NAMES = {
    0x00: "mode",
    0x01: "algo_enable",
    0x02: "brightness_gain",
    0x03: "gamma_sel",
    0x04: "scale_sel",
    0x05: "rotate_sel",
    0x06: "edge_sel",
    0x07: "osd_sel",
    0x08: "status",
    0x09: "fps_counter",
    0x0A: "heartbeat",
    0x10: "cam_cmd",
    0x11: "cam_reg_addr",
    0x12: "cam_wr_data",
    0x13: "cam_rd_data",
    0x14: "cam_status",
    0x15: "cam_frame_count",
    0x16: "cam_line_count",
    0x17: "cam_last_pixel",
    0x18: "cam_error_count",
}


def parse_int(value: str) -> int:
    return int(value, 0)


def checksum(data: bytes) -> int:
    value = 0
    for byte in data:
        value ^= byte
    return value & 0xFF


@dataclass
class Response:
    status: int
    addr: int
    value: int


class UartBridge:
    def __init__(self, port: str, baud: int, timeout: float) -> None:
        self.ser = serial.Serial(port=port, baudrate=baud, timeout=timeout)

    def close(self) -> None:
        self.ser.close()

    def transact(self, cmd: int, addr: int = 0, value: int = 0) -> Response:
        frame = bytes(
            [
                FRAME_HEAD,
                cmd & 0xFF,
                addr & 0xFF,
                (value >> 8) & 0xFF,
                value & 0xFF,
                0,
            ]
        )
        frame = frame[:-1] + bytes([checksum(frame[:-1])])
        self.ser.reset_input_buffer()
        self.ser.write(frame)
        self.ser.flush()
        resp = self.ser.read(6)
        if len(resp) != 6:
            raise RuntimeError("Timeout waiting for FPGA response.")
        if resp[0] != RESP_HEAD:
            raise RuntimeError(f"Invalid response head: 0x{resp[0]:02X}")
        if checksum(resp[:-1]) != resp[-1]:
            raise RuntimeError("Response checksum error.")
        return Response(status=resp[1], addr=resp[2], value=(resp[3] << 8) | resp[4])


def print_response(resp: Response) -> None:
    name = REGISTER_NAMES.get(resp.addr, "unknown")
    print(
        f"addr=0x{resp.addr:02X} ({name}) status=0x{resp.status:02X} value=0x{resp.value:04X} ({resp.value})"
    )


def cmd_ping(bridge: UartBridge, _args: argparse.Namespace) -> int:
    resp = bridge.transact(CMD_PING)
    print_response(resp)
    return 0 if resp.status == STATUS_OK else 1


def cmd_read(bridge: UartBridge, args: argparse.Namespace) -> int:
    resp = bridge.transact(CMD_READ, addr=args.addr)
    print_response(resp)
    return 0 if resp.status == STATUS_OK else 1


def cmd_write(bridge: UartBridge, args: argparse.Namespace) -> int:
    resp = bridge.transact(CMD_WRITE, addr=args.addr, value=args.value)
    print_response(resp)
    return 0 if resp.status == STATUS_OK else 1


def cmd_dump(bridge: UartBridge, _args: argparse.Namespace) -> int:
    rc = 0
    for addr in sorted(REGISTER_NAMES):
        resp = bridge.transact(CMD_READ, addr=addr)
        print_response(resp)
        if resp.status != STATUS_OK:
            rc = 1
    return rc


def cmd_mode(bridge: UartBridge, args: argparse.Namespace) -> int:
    resp = bridge.transact(CMD_WRITE, addr=0x00, value=args.value)
    print_response(resp)
    time.sleep(0.05)
    verify = bridge.transact(CMD_READ, addr=0x00)
    print_response(verify)
    return 0 if verify.status == STATUS_OK else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", required=True, help="Serial port, for example COM5.")
    parser.add_argument("--baud", type=int, default=115200, help="Baud rate.")
    parser.add_argument("--timeout", type=float, default=0.5, help="Serial timeout in seconds.")

    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("ping", help="Send a ping command.")

    read_p = sub.add_parser("read", help="Read a register.")
    read_p.add_argument("--addr", type=parse_int, required=True, help="Register address.")

    write_p = sub.add_parser("write", help="Write a register.")
    write_p.add_argument("--addr", type=parse_int, required=True, help="Register address.")
    write_p.add_argument("--value", type=parse_int, required=True, help="16-bit value.")

    sub.add_parser("dump", help="Dump known registers.")

    mode_p = sub.add_parser("mode", help="Write the mode register.")
    mode_p.add_argument("--value", type=parse_int, required=True, help="Mode value.")

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    bridge = UartBridge(args.port, args.baud, args.timeout)
    try:
        handlers = {
            "ping": cmd_ping,
            "read": cmd_read,
            "write": cmd_write,
            "dump": cmd_dump,
            "mode": cmd_mode,
        }
        return handlers[args.command](bridge, args)
    finally:
        bridge.close()


if __name__ == "__main__":
    sys.exit(main())
