# Timing Status: B_external_stream_std_library

Status:
- `MIXED`
- This folder is not signed off as a standalone board-ready top by itself
- Fresh local evidence now exists for promoted consuming tops under this folder

Target:
- Device: `xc7z020clg400-1`
- Clock: `138.5MHz`
- Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`
- Tool used for current local evidence: `Vivado 2024.2` (OOC synthesis timing summary)

Summary by promoted chain:

| Subdirectory | PASS/FAIL | Boundary | Main note |
| --- | --- | --- | --- |
| `01_gray_window_filter_chain` | `PARTIAL PASS` | `MAX_LANES=1`, `640x480` | Gaussian/Sobel pass; median still fails (`WNS=-1.887ns`) |
| `02_binary_morphology_chain` | `PASS` | `MAX_LANES=1`, `640x480` | clean only for this tested single-lane consuming-top boundary |

Rule for collaborators:
1. Do not describe the whole library as `138.5MHz signed off`.
2. Only the specific promoted consuming tops with fresh reports can carry a pass/fail label.
3. Multi-lane or different-image-size claims require a fresh rerun.
