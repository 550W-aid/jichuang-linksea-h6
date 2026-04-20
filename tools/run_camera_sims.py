#!/usr/bin/env python3
"""Run no-board OV5640 register-read simulations with Verilator."""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VIDEO_REGS = ROOT / "fpga" / "rtl" / "common" / "video_regs.vh"
SIM_BUILD_ROOT = ROOT / "build" / "sim"
DEFAULT_VERILATOR = Path(r"D:\eLinx3.0\verilator\verilator.exe")
DEFAULT_TOOLCHAIN_BIN = Path(r"D:\eLinx3.0\bin\Passkey\bin\cygwin\bin")

RTL_SOURCES = sorted((ROOT / "fpga" / "rtl").rglob("*.v"))
SIM_MODEL = ROOT / "fpga" / "sim" / "ov5640_sccb_model.v"

TESTBENCH_SOURCES = {
    "tb_sccb_master": [SIM_MODEL, ROOT / "fpga" / "sim" / "tb_sccb_master.v"],
    "tb_ov5640_reg_if": [SIM_MODEL, ROOT / "fpga" / "sim" / "tb_ov5640_reg_if.v"],
    "tb_uart_camera_readback": [
        SIM_MODEL,
        ROOT / "fpga" / "sim" / "tb_uart_camera_readback.v",
    ],
    "tb_video_pipeline_smoke": [
        SIM_MODEL,
        ROOT / "fpga" / "sim" / "tb_video_pipeline_smoke.v",
    ],
}


def relative_path(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def detect_verilator(user_path: str | None) -> Path:
    candidates: list[Path] = []
    if user_path:
        candidates.append(Path(user_path))
    candidates.append(DEFAULT_VERILATOR)

    which_path = shutil.which("verilator")
    if which_path:
        candidates.append(Path(which_path))

    for candidate in candidates:
        if candidate.exists():
            return candidate

    raise SystemExit(
        "Could not find Verilator. Expected D:\\eLinx3.0\\verilator\\verilator.exe "
        "or a verilator executable on PATH."
    )


def detect_verilator_runtime(user_root: str | None, verilator: Path) -> Path | None:
    candidates: list[Path] = []
    if user_root:
        candidates.append(Path(user_root))

    env_root = os.environ.get("VERILATOR_ROOT")
    if env_root:
        candidates.append(Path(env_root))

    candidates.extend(
        [
            verilator.parent.parent / "share" / "verilator",
            Path(r"D:\verilator\share\verilator"),
            Path(r"C:\verilator\share\verilator"),
        ]
    )

    for candidate in candidates:
        if (candidate / "include" / "verilated.mk").exists():
            return candidate
    return None


def build_subprocess_env() -> dict[str, str]:
    env = os.environ.copy()
    if DEFAULT_TOOLCHAIN_BIN.exists():
        current_path = env.get("PATH", "")
        env["PATH"] = str(DEFAULT_TOOLCHAIN_BIN) + os.pathsep + current_path
        make_exe = DEFAULT_TOOLCHAIN_BIN / "make.exe"
        sh_exe = DEFAULT_TOOLCHAIN_BIN / "sh.exe"
        if make_exe.exists():
            env.setdefault("MAKE", str(make_exe))
        if sh_exe.exists():
            env.setdefault("SHELL", str(sh_exe))
    return env


def parse_header_defines() -> dict[str, str]:
    define_re = re.compile(r"^\s*`define\s+(\w+)\s+(.+?)\s*$")
    defines: dict[str, str] = {}

    for line in VIDEO_REGS.read_text(encoding="utf-8").splitlines():
        match = define_re.match(line)
        if not match:
            continue
        name, value = match.groups()
        if name == "VIDEO_REGS_VH":
            continue
        defines[name] = value

    if not defines:
        raise SystemExit(f"No macro defines parsed from {VIDEO_REGS}")

    return defines


def render_source_for_verilator(source: Path, destination: Path, defines: dict[str, str]) -> None:
    text = source.read_text(encoding="utf-8")
    rendered_lines: list[str] = []
    for line in text.splitlines():
        if "video_regs.vh" in line:
            continue
        rendered_lines.append(line)
    rendered_text = "\n".join(rendered_lines) + "\n"

    for name, value in sorted(defines.items(), key=lambda item: len(item[0]), reverse=True):
        rendered_text = re.sub(rf"`{name}\b", value, rendered_text)

    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(rendered_text, encoding="utf-8")


def prepare_generated_sources(testbench: str, generated_root: Path) -> list[str]:
    defines = parse_header_defines()
    sources = RTL_SOURCES + TESTBENCH_SOURCES[testbench]
    rendered_paths: list[str] = []

    for source in sources:
        relative = source.relative_to(ROOT)
        destination = generated_root / relative
        render_source_for_verilator(source, destination, defines)
        rendered_paths.append(relative_path(destination))

    return rendered_paths


def build_verilator_args(verilator: Path, testbench: str, lint_only: bool, keep_build: bool) -> tuple[list[str], Path]:
    build_dir = SIM_BUILD_ROOT / testbench
    if build_dir.exists() and not keep_build:
        shutil.rmtree(build_dir)
    build_dir.mkdir(parents=True, exist_ok=True)
    generated_root = build_dir / "generated"
    rendered_sources = prepare_generated_sources(testbench, generated_root)

    args = [
        str(verilator),
        "--timing",
        "-Wall",
        "-Wno-fatal",
        "-Wno-DECLFILENAME",
        "-Wno-PINCONNECTEMPTY",
        "-Wno-TIMESCALEMOD",
        "-Wno-WIDTH",
        "-Wno-BLKSEQ",
        "-Wno-INITIALDLY",
        "-Wno-SYNCASYNCNET",
        "-Wno-UNUSEDSIGNAL",
        "-Wno-UNUSEDPARAM",
        "-Wno-UNUSED",
        "--top-module",
        testbench,
        "--Mdir",
        relative_path(build_dir),
    ]

    args.extend(rendered_sources)

    if lint_only:
        args.append("--lint-only")
    else:
        args.extend(["--binary", "-j", "0"])

    return args, build_dir


def run_command(args: list[str], runtime_root: Path | None = None) -> int:
    env = build_subprocess_env()
    if runtime_root is not None:
        env["VERILATOR_ROOT"] = str(runtime_root)
    result = subprocess.run(args, cwd=ROOT, text=True, env=env)
    return result.returncode


def run_testbench(
    verilator: Path,
    runtime_root: Path | None,
    testbench: str,
    lint_only: bool,
    keep_build: bool,
) -> int:
    args, build_dir = build_verilator_args(verilator, testbench, lint_only, keep_build)
    print(f"== {testbench} ==")
    rc = run_command(args, runtime_root=runtime_root)
    if rc != 0:
        return rc

    if lint_only:
        print(f"{testbench}: lint OK")
        return 0

    binary = build_dir / f"V{testbench}.exe"
    if not binary.exists():
        print(f"{testbench}: built successfully but missing executable {binary}")
        return 1

    rc = run_command([str(binary)], runtime_root=runtime_root)
    if rc == 0:
        print(f"{testbench}: PASS")
    return rc


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "targets",
        nargs="*",
        help="Specific testbenches to run. Defaults to all camera bring-up simulations.",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List supported simulation targets and exit.",
    )
    parser.add_argument(
        "--lint-only",
        action="store_true",
        help="Only run Verilator lint/elaboration without building executables.",
    )
    parser.add_argument(
        "--keep-build",
        action="store_true",
        help="Keep existing build directories instead of cleaning before each run.",
    )
    parser.add_argument(
        "--verilator",
        help="Override the Verilator executable path.",
    )
    parser.add_argument(
        "--verilator-root",
        help="Override VERILATOR_ROOT when a full runtime install is available.",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()

    if args.list:
        for name in TESTBENCH_SOURCES:
            print(name)
        return 0

    targets = args.targets or list(TESTBENCH_SOURCES)
    unknown = [target for target in targets if target not in TESTBENCH_SOURCES]
    if unknown:
        print(f"Unknown simulation target(s): {', '.join(unknown)}")
        return 1

    verilator = detect_verilator(args.verilator)
    runtime_root = detect_verilator_runtime(args.verilator_root, verilator)
    if not args.lint_only and runtime_root is None:
        print(
            "Full Verilator runtime files were not found. "
            "This eLinx bundle supports lint/elaboration, but executable simulation "
            "also needs a runtime tree containing include/verilated.mk."
        )
        print("Run with --lint-only for the current machine, or provide --verilator-root later.")
        return 1

    overall_rc = 0
    for target in targets:
        rc = run_testbench(verilator, runtime_root, target, args.lint_only, args.keep_build)
        if rc != 0:
            overall_rc = rc
            break
    return overall_rc


if __name__ == "__main__":
    raise SystemExit(main())
