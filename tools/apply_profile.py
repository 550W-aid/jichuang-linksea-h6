#!/usr/bin/env python3
"""Apply a named preset profile to the FPGA register map over UART."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

CMD_WRITE = 0x01
CMD_READ = 0x02
STATUS_OK = 0x00


REGISTER_ORDER = [
    ("mode", 0x00),
    ("algo_enable", 0x01),
    ("brightness_gain", 0x02),
    ("gamma_sel", 0x03),
    ("scale_sel", 0x04),
    ("rotate_sel", 0x05),
    ("edge_sel", 0x06),
    ("osd_sel", 0x07),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", help="Serial port, for example COM5.")
    parser.add_argument("--baud", type=int, default=115200, help="Baud rate.")
    parser.add_argument("--timeout", type=float, default=0.5, help="Serial timeout in seconds.")
    parser.add_argument("--list", action="store_true", help="List available profiles and exit.")
    parser.add_argument(
        "--verify",
        action="store_true",
        help="Read back each written register and fail if the value does not match.",
    )
    parser.add_argument(
        "--profiles",
        type=Path,
        default=Path("tools/preset_profiles.json"),
        help="Path to the preset profile JSON file.",
    )
    parser.add_argument("name", nargs="?", help="Profile name to apply.")
    return parser.parse_args()


def print_profiles(profiles: dict[str, dict[str, object]]) -> None:
    for name, profile in profiles.items():
        description = str(profile.get("description", "")).strip()
        header = name if not description else f"{name}: {description}"
        print(header)
        for reg_name, _addr in REGISTER_ORDER:
            if reg_name in profile:
                value = int(profile[reg_name])
                print(f"  {reg_name:16s} = 0x{value:04X} ({value})")


def main() -> int:
    args = parse_args()
    profiles = json.loads(args.profiles.read_text(encoding="utf-8"))

    if args.list:
        print_profiles(profiles)
        return 0

    if not args.port:
        raise SystemExit("Missing required argument: --port")

    if not args.name:
        raise SystemExit("Missing profile name. Use --list to inspect available profiles.")

    if args.name not in profiles:
        available = ", ".join(sorted(profiles))
        raise SystemExit(f"Unknown profile '{args.name}'. Available: {available}")

    try:
        from uart_control import UartBridge
    except ImportError as exc:
        raise SystemExit(
            "Missing dependency: pyserial. Install with `pip install pyserial`."
        ) from exc

    profile = profiles[args.name]
    bridge = UartBridge(args.port, args.baud, args.timeout)
    try:
        for reg_name, addr in REGISTER_ORDER:
            if reg_name not in profile:
                continue
            value = int(profile[reg_name])
            resp = bridge.transact(CMD_WRITE, addr=addr, value=value)
            print(
                f"{reg_name:16s} addr=0x{addr:02X} value=0x{value:04X} status=0x{resp.status:02X}"
            )
            if resp.status != STATUS_OK:
                return 1
            if args.verify:
                verify = bridge.transact(CMD_READ, addr=addr)
                match = verify.status == STATUS_OK and verify.value == value
                result = "OK" if match else "MISMATCH"
                print(
                    f"{'verify':16s} addr=0x{addr:02X} value=0x{verify.value:04X} status=0x{verify.status:02X} [{result}]"
                )
                if not match:
                    return 1
    finally:
        bridge.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
