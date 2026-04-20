#!/usr/bin/env python3
"""Check no-board OV5640 register-read readiness for the Link-Sea-H6A flow."""

from __future__ import annotations

import argparse
import importlib
import os
import sys
from pathlib import Path

try:
    from serial.tools import list_ports  # type: ignore
except ImportError:  # pragma: no cover - environment dependent
    list_ports = None


ROOT = Path(__file__).resolve().parents[1]
IGNORED_NAMES = {"README.md", ".gitkeep", "__pycache__"}
OFFICIAL_ROOT = ROOT / "集创赛-中科亿海微杯"

CORE_FILES = [
    ROOT / "README.md",
    ROOT / "docs" / "start-here.md",
    ROOT / "docs" / "board-quick-reference.md",
    ROOT / "docs" / "camera-regread-workflow.md",
    ROOT / "fpga" / "rtl" / "link_sea_h6_bringup_top.v",
    ROOT / "fpga" / "rtl" / "video_pipeline_top.v",
    ROOT / "tools" / "uart_control.py",
    ROOT / "tools" / "ov5640_reg_access.py",
    ROOT / "tools" / "run_camera_sims.py",
]

OFFICIAL_FILES = [
    OFFICIAL_ROOT / "中科亿海微Link-Sea-H6A图像处理套件快速使用指南.pdf",
    OFFICIAL_ROOT / "Link_Sea_H6A板卡接口IO对应关系表.xlsx",
    OFFICIAL_ROOT / "常见问题答复.xls",
    OFFICIAL_ROOT / "板卡硬件原理图" / "集创赛EQ6HL130核心板-原理图.pdf",
    OFFICIAL_ROOT / "板卡硬件原理图" / "集创赛图像底板-原理图.pdf",
]


def print_status(level: str, label: str, detail: str) -> None:
    print(f"[{level}] {label}: {detail}")


def directory_has_payload(path: Path) -> bool:
    if not path.exists():
        return False
    for child in path.iterdir():
        if child.name in IGNORED_NAMES:
            continue
        return True
    return False


def check_python() -> tuple[int, int]:
    if sys.version_info >= (3, 10):
        print_status("OK", "Python", f"{sys.version.split()[0]} at {sys.executable}")
        return 1, 0
    print_status("FAIL", "Python", f"Need Python >= 3.10, found {sys.version.split()[0]}")
    return 0, 1


def check_package(name: str, hint: str, required: bool = True) -> tuple[int, int]:
    try:
        module = importlib.import_module(name)
    except ImportError:
        level = "FAIL" if required else "WARN"
        print_status(level, f"Python package {name}", hint)
        return 0, 1

    version = getattr(module, "__version__", getattr(module, "VERSION", "unknown"))
    print_status("OK", f"Python package {name}", f"Detected version {version}")
    return 1, 0


def check_path(name: str, candidates: list[Path], required: bool) -> tuple[int, int]:
    for candidate in candidates:
        if candidate.exists():
            print_status("OK", name, str(candidate))
            return 1, 0
    level = "FAIL" if required else "WARN"
    print_status(level, name, "Not found in expected locations.")
    return 0, 1


def check_verilator_runtime() -> tuple[int, int]:
    candidates = [
        Path(os.environ.get("VERILATOR_ROOT", "")),
        Path(r"D:\eLinx3.0\share\verilator"),
        Path(r"D:\verilator\share\verilator"),
        Path(r"C:\verilator\share\verilator"),
    ]
    for candidate in candidates:
        if str(candidate) and (candidate / "include" / "verilated.mk").exists():
            print_status("OK", "Verilator runtime", str(candidate))
            return 1, 0

    print_status(
        "WARN",
        "Verilator runtime",
        "Missing include/verilated.mk. Current eLinx bundle can still do lint-only checks.",
    )
    return 0, 1


def is_likely_board_uart(description: str) -> bool:
    desc = description.lower()
    positive_tokens = ("ch340", "usb-serial", "usb serial", "uart", "wch", "cp210", "ftdi")
    negative_tokens = ("bluetooth", "virtual bluetooth", "rfcomm")
    return any(token in desc for token in positive_tokens) and not any(
        token in desc for token in negative_tokens
    )


def check_serial_ports() -> tuple[int, int]:
    if list_ports is None:
        print_status("WARN", "Serial ports", "pyserial unavailable, cannot enumerate COM ports.")
        return 0, 1

    ports = list(list_ports.comports())
    if not ports:
        print_status(
            "WARN",
            "Serial ports",
            "No COM ports detected. This is acceptable before the board is connected.",
        )
        return 0, 1

    print_status("OK", "Serial ports", f"Detected {len(ports)} port(s)")
    likely_board = []
    for port in ports:
        description = port.description or "Unknown device"
        print(f"       - {port.device}: {description}")
        if is_likely_board_uart(description):
            likely_board.append(port.device)

    if likely_board:
        print_status("OK", "Likely board UART", ", ".join(likely_board))
        return 2, 0

    print_status(
        "WARN",
        "Likely board UART",
        "No CH340/USB-UART style port detected yet. This is expected if the board is not connected.",
    )
    return 1, 1


def check_files(label: str, files: list[Path], required: bool) -> tuple[int, int]:
    ok = 0
    issues = 0
    for path in files:
        if path.exists():
            print_status("OK", label, str(path.relative_to(ROOT)))
            ok += 1
        else:
            level = "FAIL" if required else "WARN"
            print_status(level, label, f"Missing {path.relative_to(ROOT)}")
            issues += 1
    return ok, issues


def check_external_assets(strict: bool) -> tuple[int, int]:
    ok = 0
    issues = 0
    checks = [
        ("Reference docs", directory_has_payload(ROOT / "reference" / "board-docs")),
        ("Datasheets", directory_has_payload(ROOT / "reference" / "datasheets")),
        ("FPGA constraints", directory_has_payload(ROOT / "fpga" / "constraints")),
        ("OV5640 init table", (ROOT / "fpga" / "rtl" / "camera" / "ov5640_init_table.mem").exists()),
        ("Vendor PLL files", directory_has_payload(ROOT / "fpga" / "vendor" / "pll")),
        ("Vendor SDRAM files", directory_has_payload(ROOT / "fpga" / "vendor" / "sdram")),
        ("Vendor project files", directory_has_payload(ROOT / "fpga" / "vendor" / "project")),
    ]

    for label, ready in checks:
        if ready:
            print_status("OK", label, "Ready")
            ok += 1
        else:
            level = "FAIL" if strict else "WARN"
            detail = "Missing or empty. Fill this before moving to the matching bring-up stage."
            print_status(level, label, detail)
            issues += 1
    return ok, issues


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat missing board assets and vendor files as failures instead of warnings.",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()

    ok_total = 0
    warn_total = 0
    fail_total = 0

    print("== Core Environment ==")
    ok, fail = check_python()
    ok_total += ok
    fail_total += fail

    ok, fail = check_package("serial", "Install with `pip install pyserial`.")
    ok_total += ok
    fail_total += fail

    ok, fail = check_package("pypdf", "Install with `pip install pypdf`.")
    ok_total += ok
    fail_total += fail

    ok, fail = check_package("openpyxl", "Install with `pip install openpyxl`.")
    ok_total += ok
    fail_total += fail

    ok, warn = check_serial_ports()
    ok_total += ok
    warn_total += warn

    print("\n== Tool Detection ==")
    ok, fail = check_path(
        "eLinx Design Suite",
        [
            Path(r"D:\eLinx3.0\eLinx3.0.exe"),
            Path(r"D:\eLinx3.0\eLinx3.0.bat"),
            Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "eLinx3.0" / "eLinx3.0.exe",
        ],
        required=True,
    )
    ok_total += ok
    fail_total += fail

    ok, fail = check_path(
        "Verilator",
        [
            Path(r"D:\eLinx3.0\verilator\verilator.exe"),
            Path(r"C:\eLinx3.0\verilator\verilator.exe"),
        ],
        required=True,
    )
    ok_total += ok
    fail_total += fail

    ok, warn = check_verilator_runtime()
    ok_total += ok
    warn_total += warn

    ok, fail = check_path(
        "GHDL",
        [
            Path(r"D:\eLinx3.0\ghdl\bin\ghdl.exe"),
            Path(r"C:\eLinx3.0\ghdl\bin\ghdl.exe"),
        ],
        required=True,
    )
    ok_total += ok
    fail_total += fail

    ok, warn = check_path(
        "STM32CubeMX",
        [
            Path(r"D:\Cube MX"),
            Path(r"C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeMX"),
        ],
        required=False,
    )
    ok_total += ok
    warn_total += warn

    ok, warn = check_path(
        "STM32CubeCLT",
        [
            Path(r"D:\STM32CubeCLT_1.20.0"),
            Path(r"C:\ST\STM32CubeCLT_1.20.0"),
        ],
        required=False,
    )
    ok_total += ok
    warn_total += warn

    ok, warn = check_path(
        "STM32CubeIDE",
        [
            Path(r"C:\ST\STM32CubeIDE_1.16.0"),
            Path(r"C:\ST\STM32CubeIDE_1.15.1"),
            Path(r"C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeIDE"),
        ],
        required=False,
    )
    ok_total += ok
    warn_total += warn

    print("\n== Official Source Files ==")
    ok, fail = check_files("Official file", OFFICIAL_FILES, required=True)
    ok_total += ok
    fail_total += fail

    print("\n== Repository Files ==")
    ok, fail = check_files("Repo file", CORE_FILES, required=True)
    ok_total += ok
    fail_total += fail

    print("\n== External Assets ==")
    ok, issues = check_external_assets(strict=args.strict)
    ok_total += ok
    if args.strict:
        fail_total += issues
    else:
        warn_total += issues

    print("\n== Summary ==")
    print(f"Ready checks passed: {ok_total}")
    print(f"Warnings: {warn_total}")
    print(f"Failures: {fail_total}")
    if fail_total:
        print(
            "Next step: install missing Python packages, then open "
            "docs/board-quick-reference.md and docs/camera-regread-workflow.md."
        )
        return 1
    if warn_total:
        print(
            "No-board development can continue. Review warnings before the matching board bring-up stage."
        )
        return 0

    print("No-board OV5640 register-read setup is ready. Continue with tools/run_camera_sims.py.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
