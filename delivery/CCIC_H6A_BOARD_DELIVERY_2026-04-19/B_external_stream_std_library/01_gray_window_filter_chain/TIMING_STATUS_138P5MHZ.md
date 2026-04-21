# Timing Status: 01_gray_window_filter_chain

Status:
- `FAIL`
- Fresh local timing evidence exists for three consuming tops
- Not signed off as a board-ready `138.5MHz` chain

Consuming tops used for signoff:
- `rtl/gray_window_gaussian_chain_top.v`
- `rtl/gray_window_median_chain_top.v`
- `rtl/gray_window_sobel_chain_top.v`

Target:
- Device: `xc7z020clg400-1`
- Clock: `138.5MHz`
- Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`
- Tool used for this fresh local evidence: `Vivado 2018.3 OOC synth/place/route`

Signoff boundary:
- Single-lane consuming tops only: `MAX_LANES=1`, `IMG_WIDTH=640`, `IMG_HEIGHT=480`
- This boundary is intentionally limited to one lane because the current delivery of `window3x3_stream_std` is only board-facing safe on lane 0 in this promoted-chain form
- This is not a multi-lane signoff

Results:

| Module | Top RTL | PASS/FAIL | WNS | TNS | WHS | THS | Likely critical path |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `gaussian3x3_stream_std` | `rtl/gray_window_gaussian_chain_top.v` | `FAIL` | `-1.205ns` | `-2811.878ns` | `0.132ns` | `0.000ns` | `memory seam` |
| `median3x3_stream_std` | `rtl/gray_window_median_chain_top.v` | `FAIL` | `-1.925ns` | `-3972.344ns` | `0.098ns` | `0.000ns` | `memory seam` |
| `sobel3x3_stream_std` | `rtl/gray_window_sobel_chain_top.v` | `FAIL` | `-2.307ns` | `-6404.348ns` | `0.176ns` | `0.000ns` | `memory seam` |

Report path:
- Gaussian:
- `timing_runs/gray_window_gaussian/timing_summary.rpt`
- `timing_runs/gray_window_gaussian/timing_setup.rpt`
- Median:
- `timing_runs/gray_window_median/timing_summary.rpt`
- `timing_runs/gray_window_median/timing_setup.rpt`
- Sobel:
- `timing_runs/gray_window_sobel/timing_summary.rpt`
- `timing_runs/gray_window_sobel/timing_setup.rpt`

Current blocker:
- The shared pressure is not a small arithmetic tail issue.
- The fresh reports show heavy route-dominated paths around `window3x3_stream_std` storage and the handoff from the line-memory seam into the downstream 3x3 operator.
- This chain must not be described as `138.5MHz clean` in its current promoted-top form.

Next action:
1. Rework `window3x3_stream_std` storage and handoff so the line-memory seam is more timing-friendly.
2. If promoted again, keep the chain labeled with the actual tested lane boundary.
3. Re-run fresh OOC timing after the seam is re-pipelined.
