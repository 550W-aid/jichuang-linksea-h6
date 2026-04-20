#!/usr/bin/env python3
"""Generate a simple gamma LUT file for FPGA experiments."""

from __future__ import annotations

import argparse
import math
from pathlib import Path


def build_lut(gamma: float) -> list[int]:
    table: list[int] = []
    for i in range(256):
        value = int(round((pow(i / 255.0, gamma)) * 255.0))
        table.append(max(0, min(255, value)))
    return table


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gamma", type=float, default=0.7, help="Gamma exponent, <1 brightens shadows.")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("fpga/rtl/algorithms/gamma_lut.mem"),
        help="Output file path.",
    )
    args = parser.parse_args()

    lut = build_lut(args.gamma)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii") as fh:
        for value in lut:
            fh.write(f"{value:02X}\n")

    print(f"Wrote {len(lut)} LUT entries to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

