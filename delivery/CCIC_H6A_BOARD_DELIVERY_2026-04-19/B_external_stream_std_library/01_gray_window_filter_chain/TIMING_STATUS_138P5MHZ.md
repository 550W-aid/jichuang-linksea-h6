# Timing Status: 01_gray_window_filter_chain

Status:
- `FAIL`
- Fresh local timing evidence exists for three consuming tops
- `gray_window_gaussian_chain_top.v` and `gray_window_sobel_chain_top.v` now pass on the tested single-lane promoted-top boundary
- `gray_window_median_chain_top.v` still fails, so the chain family is not signed off as a board-ready `138.5MHz` delivery set

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
| `gaussian3x3_stream_std` | `rtl/gray_window_gaussian_chain_top.v` | `PASS` | `0.309ns` | `0.000ns` | `0.127ns` | `0.000ns` | `closed on tested boundary after window-buffer refactor` |
| `median3x3_stream_std` | `rtl/gray_window_median_chain_top.v` | `FAIL` | `-1.566ns` | `-81.746ns` | `0.128ns` | `0.000ns` | `median row-sort compare network` |
| `sobel3x3_stream_std` | `rtl/gray_window_sobel_chain_top.v` | `PASS` | `1.186ns` | `0.000ns` | `0.098ns` | `0.000ns` | `closed on tested boundary after Sobel pipelining` |

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
- The shared `window3x3_stream_std` seam is no longer the dominant blocker on the refreshed Gaussian and Sobel promoted tops.
- The remaining failing top is now `gray_window_median_chain_top.v`.
- The fresh report shows a route-heavy compare/swap network from `stg0_data_reg[*]` to `stg1_rowsort_reg[*]` inside `median3x3_stream_std`.
- This family must not be described as a fully signed-off `138.5MHz clean` delivery chain until the median top also passes.

Next action:
1. Split the `median3x3_stream_std` row-sort network into smaller compare/swap stages instead of keeping the full `sort3_pack` chain in one cycle.
2. Keep the promoted-chain label limited to the tested `MAX_LANES=1`, `640x480` boundary.
3. Re-run fresh OOC timing after the median sorting layers are re-pipelined.
