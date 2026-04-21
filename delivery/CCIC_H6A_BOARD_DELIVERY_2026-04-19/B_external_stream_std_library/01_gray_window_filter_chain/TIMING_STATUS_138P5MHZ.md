# Timing Status: 01_gray_window_filter_chain

Status:
- `PASS` (on the tested signoff boundary)
- All three promoted consuming tops now meet `138.5MHz` timing on this boundary

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
| `gaussian3x3_stream_std` | `rtl/gray_window_gaussian_chain_top.v` | `PASS` | `0.424ns` | `0.000ns` | `0.090ns` | `0.000ns` | `window3x3 -> gaussian` interface path |
| `median3x3_stream_std` | `rtl/gray_window_median_chain_top.v` | `PASS` | `0.983ns` | `0.000ns` | `0.090ns` | `0.000ns` | `closed after splitting row-sort into two pipeline stages (stg1a/stg1)` |
| `sobel3x3_stream_std` | `rtl/gray_window_sobel_chain_top.v` | `PASS` | `0.563ns` | `0.000ns` | `0.090ns` | `0.000ns` | `closed after fixed-width signed Sobel datapath rewrite` |

Evidence projects:
- `F:/codex/output/gauss_chain_synth_check_20260421`
- `F:/codex/output/median_chain_synth_check_20260421`
- `F:/codex/output/sobel_chain_synth_check_20260421`

Recent RTL updates in this round:
1. `sobel3x3_stream_std.v` refactored to three data-path stages (`stg0` input latch + `stg1` gradient + `stg2` absolute + output clip stage).
2. `median3x3_stream_std.v` added extra result pipeline stage (`stg3` to `m_out`) to shorten the previous tail path.
3. `sobel3x3_stream_std.v` further switched from integer-heavy math to fixed-width signed datapath (`*2` replaced by shifts), and now closes at `138.5MHz`.
4. `median3x3_stream_std.v` was rewritten into a deeper streaming pipeline and then further split row-sort into two stages (`stg1a` + `stg1`), closing median timing at `138.5MHz`.
5. Results above are refreshed after rebase conflict resolution and fresh reruns with the same `7.220ns` clock constraint.

Next action:
1. If you need multi-lane signoff (`MAX_LANES>1`) or larger resolutions, rerun timing on that exact boundary before board-level claim.
2. Keep the same 7.220ns timing-closure rules for all future algorithm additions in this chain.
