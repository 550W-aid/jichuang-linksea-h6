#!/usr/bin/env python3
"""High-level OV5640 register access helper over the existing UART bridge."""

from __future__ import annotations

import argparse
import sys
import time

from uart_control import UartBridge, parse_int, print_response


REG_CAM_CMD = 0x10
REG_CAM_REG_ADDR = 0x11
REG_CAM_WR_DATA = 0x12
REG_CAM_RD_DATA = 0x13
REG_CAM_STATUS = 0x14
REG_CAM_FRAME_COUNT = 0x15
REG_CAM_LINE_COUNT = 0x16
REG_CAM_LAST_PIXEL = 0x17
REG_CAM_ERROR_COUNT = 0x18

CAM_CMD_READ = 0x0001
CAM_CMD_WRITE = 0x0002
CAM_CMD_CLEAR = 0x0004

CAM_STATUS_BUSY = 1 << 0
CAM_STATUS_DONE = 1 << 1
CAM_STATUS_ACK_OK = 1 << 2
CAM_STATUS_NACK = 1 << 3
CAM_STATUS_TIMEOUT = 1 << 4
CAM_STATUS_INIT_DONE = 1 << 5
CAM_STATUS_SENSOR_PRESENT = 1 << 6
CAM_STATUS_DATA_ACTIVE = 1 << 7

OV5640_CHIP_ID_HIGH_REG = 0x300A
OV5640_CHIP_ID_LOW_REG = 0x300B
OV5640_CHIP_ID_HIGH_VALUE = 0x56
OV5640_CHIP_ID_LOW_VALUE = 0x40


def read_fpga_reg(bridge: UartBridge, addr: int) -> int:
    resp = bridge.transact(0x02, addr=addr)
    print_response(resp)
    return resp.value


def write_fpga_reg(bridge: UartBridge, addr: int, value: int) -> None:
    resp = bridge.transact(0x01, addr=addr, value=value)
    print_response(resp)


def decode_status(value: int) -> str:
    bits = []
    if value & CAM_STATUS_BUSY:
        bits.append("busy")
    if value & CAM_STATUS_DONE:
        bits.append("done")
    if value & CAM_STATUS_ACK_OK:
        bits.append("ack_ok")
    if value & CAM_STATUS_NACK:
        bits.append("nack")
    if value & CAM_STATUS_TIMEOUT:
        bits.append("timeout")
    if value & CAM_STATUS_INIT_DONE:
        bits.append("init_done")
    if value & CAM_STATUS_SENSOR_PRESENT:
        bits.append("sensor_present")
    if value & CAM_STATUS_DATA_ACTIVE:
        bits.append("data_active")
    return ", ".join(bits) if bits else "none"


def clear_camera_status(bridge: UartBridge) -> None:
    write_fpga_reg(bridge, REG_CAM_CMD, CAM_CMD_CLEAR)


def wait_camera_done(bridge: UartBridge, timeout_s: float, poll_s: float) -> int:
    deadline = time.time() + timeout_s
    last_status = 0
    while time.time() < deadline:
        last_status = read_fpga_reg(bridge, REG_CAM_STATUS)
        if last_status & CAM_STATUS_DONE:
            return last_status
        time.sleep(poll_s)
    raise RuntimeError(
        f"Timed out waiting for cam_status.done. Last status=0x{last_status:04X} ({decode_status(last_status)})"
    )


def camera_read(bridge: UartBridge, reg_addr: int, timeout_s: float, poll_s: float) -> tuple[int, int]:
    clear_camera_status(bridge)
    write_fpga_reg(bridge, REG_CAM_REG_ADDR, reg_addr)
    write_fpga_reg(bridge, REG_CAM_CMD, CAM_CMD_READ)
    status = wait_camera_done(bridge, timeout_s, poll_s)
    value = read_fpga_reg(bridge, REG_CAM_RD_DATA) & 0x00FF
    return value, status


def camera_write(
    bridge: UartBridge,
    reg_addr: int,
    data: int,
    timeout_s: float,
    poll_s: float,
) -> int:
    clear_camera_status(bridge)
    write_fpga_reg(bridge, REG_CAM_REG_ADDR, reg_addr)
    write_fpga_reg(bridge, REG_CAM_WR_DATA, data & 0x00FF)
    write_fpga_reg(bridge, REG_CAM_CMD, CAM_CMD_WRITE)
    return wait_camera_done(bridge, timeout_s, poll_s)


def cmd_status(bridge: UartBridge, _args: argparse.Namespace) -> int:
    status = read_fpga_reg(bridge, REG_CAM_STATUS)
    frame_count = read_fpga_reg(bridge, REG_CAM_FRAME_COUNT)
    line_count = read_fpga_reg(bridge, REG_CAM_LINE_COUNT)
    last_pixel = read_fpga_reg(bridge, REG_CAM_LAST_PIXEL)
    error_count = read_fpga_reg(bridge, REG_CAM_ERROR_COUNT)

    print(f"cam_status bits: {decode_status(status)}")
    print(f"cam_frame_count: {frame_count}")
    print(f"cam_line_count: {line_count}")
    print(f"cam_last_pixel: 0x{last_pixel:04X}")
    print(f"cam_error_count: {error_count}")
    return 0


def cmd_read(bridge: UartBridge, args: argparse.Namespace) -> int:
    value, status = camera_read(bridge, args.reg, args.op_timeout, args.poll_interval)
    print(
        f"OV5640[0x{args.reg:04X}] = 0x{value:02X}; cam_status=0x{status:04X} ({decode_status(status)})"
    )
    return 0 if status & CAM_STATUS_ACK_OK else 1


def cmd_write(bridge: UartBridge, args: argparse.Namespace) -> int:
    status = camera_write(bridge, args.reg, args.value, args.op_timeout, args.poll_interval)
    print(
        f"OV5640[0x{args.reg:04X}] <= 0x{args.value & 0xFF:02X}; cam_status=0x{status:04X} ({decode_status(status)})"
    )
    return 0 if status & CAM_STATUS_ACK_OK else 1


def cmd_probe_id(bridge: UartBridge, args: argparse.Namespace) -> int:
    high, high_status = camera_read(
        bridge, OV5640_CHIP_ID_HIGH_REG, args.op_timeout, args.poll_interval
    )
    low, low_status = camera_read(
        bridge, OV5640_CHIP_ID_LOW_REG, args.op_timeout, args.poll_interval
    )
    status = read_fpga_reg(bridge, REG_CAM_STATUS)

    print(f"chip_id_high: 0x{high:02X} expected 0x{OV5640_CHIP_ID_HIGH_VALUE:02X}")
    print(f"chip_id_low : 0x{low:02X} expected 0x{OV5640_CHIP_ID_LOW_VALUE:02X}")
    print(f"status bits : {decode_status(status)}")

    ok = (
        high == OV5640_CHIP_ID_HIGH_VALUE
        and low == OV5640_CHIP_ID_LOW_VALUE
        and (high_status & CAM_STATUS_ACK_OK)
        and (low_status & CAM_STATUS_ACK_OK)
        and (status & CAM_STATUS_SENSOR_PRESENT)
    )
    return 0 if ok else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", required=True, help="Serial port, for example COM5.")
    parser.add_argument("--baud", type=int, default=115200, help="UART baud rate.")
    parser.add_argument("--timeout", type=float, default=0.5, help="Serial timeout in seconds.")
    parser.add_argument(
        "--op-timeout",
        type=float,
        default=2.0,
        help="Operation timeout while polling cam_status.done.",
    )
    parser.add_argument(
        "--poll-interval",
        type=float,
        default=0.05,
        help="Polling interval in seconds while waiting for camera commands to finish.",
    )

    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("probe-id", help="Read OV5640 chip ID registers 0x300A and 0x300B.")

    read_p = sub.add_parser("read", help="Read one OV5640 register through SCCB.")
    read_p.add_argument("--reg", type=parse_int, required=True, help="16-bit OV5640 register address.")

    write_p = sub.add_parser("write", help="Write one OV5640 register through SCCB.")
    write_p.add_argument("--reg", type=parse_int, required=True, help="16-bit OV5640 register address.")
    write_p.add_argument("--value", type=parse_int, required=True, help="8-bit data value.")

    sub.add_parser("status", help="Read camera-facing FPGA status and counters.")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    bridge = UartBridge(args.port, args.baud, args.timeout)
    try:
        handlers = {
            "probe-id": cmd_probe_id,
            "read": cmd_read,
            "write": cmd_write,
            "status": cmd_status,
        }
        return handlers[args.command](bridge, args)
    finally:
        bridge.close()


if __name__ == "__main__":
    sys.exit(main())
