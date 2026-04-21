# Timing Status: 01_gray_window_filter_chain

Status:
- `PARTIAL PASS`
- Not signed off as a full board-ready chain at `138.5MHz`

Consuming tops checked:
- `rtl/gray_window_gaussian_chain_top.v`
- `rtl/gray_window_median_chain_top.v`
- `rtl/gray_window_sobel_chain_top.v`

Target:
- Device: `xc7z020clg400-1`
- Clock: `138.5MHz`
- Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`
- Tool: `Vivado 2024.2` (OOC synthesis timing summary)

Signoff boundary:
- Single-lane consuming tops only: `MAX_LANES=1`, `IMG_WIDTH=640`, `IMG_HEIGHT=480`
- This is not a multi-lane signoff claim.

Results:

| Module | Top RTL | PASS/FAIL | WNS | TNS | WHS | THS | Current dominant path |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `gaussian3x3_stream_std` | `rtl/gray_window_gaussian_chain_top.v` | `PASS` | `0.424ns` | `0.000ns` | `0.132ns` | `0.000ns` | `window3x3 -> gaussian` interface path |
| `median3x3_stream_std` | `rtl/gray_window_median_chain_top.v` | `FAIL` | `-1.887ns` | `-90.593ns` | `0.090ns` | `0.000ns` | `stg0_data -> stg1_rowsort` in `median3x3_stream_std` |
| `sobel3x3_stream_std` | `rtl/gray_window_sobel_chain_top.v` | `PASS` | `0.563ns` | `0.000ns` | `0.090ns` | `0.000ns` | `closed after fixed-width signed Sobel datapath rewrite` |

Evidence projects:
- `F:/codex/output/gauss_chain_synth_check_20260421`
- `F:/codex/output/median_chain_synth_check_20260421`
- `F:/codex/output/sobel_chain_synth_check_20260421`

Recent RTL updates in this round:
1. `sobel3x3_stream_std.v` refactored to three data-path stages (`stg0` input latch + `stg1` gradient + `stg2` absolute + output clip stage).
2. `median3x3_stream_std.v` added extra result pipeline stage (`stg3` to `m_out`) to shorten the previous tail path.
3. `sobel3x3_stream_std.v` further switched from integer-heavy math to fixed-width signed datapath (`*2` replaced by shifts), and now closes at `138.5MHz`.
4. `median3x3_stream_std.v` was rewritten into a deeper streaming pipeline (`stg0`~`stg5`) and split the final median compare chain, improving WNS from `-2.283ns` to `-1.887ns`.
5. Results above are refreshed after rebase conflict resolution and fresh reruns with the same `7.220ns` clock constraint.

Next action:
1. Continue pipelining `median3x3_stream_std` row-sort stage (`stg0_data -> stg1_rowsort`), which is now the dominant remaining bottleneck.
2. Focus remaining effort on `median3x3_stream_std` stage-1/stage-2 boundary (currently the only failing top in this chain).
3. Re-run fresh `7.220ns` timing after each change.
