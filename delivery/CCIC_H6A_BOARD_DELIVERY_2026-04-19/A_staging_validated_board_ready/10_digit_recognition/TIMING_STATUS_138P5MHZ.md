# Timing Status: 10_digit_recognition

Status:

- `PASS`
- OOC synthesis + route timing passed at `138.5MHz` target clock.

Target:

- Device: `xc7z020clg400-1`
- Clock constraint: `create_clock -name clk -period 7.220 [get_ports clk]`

Top RTL:

- `rtl/digit_template_match_stream_std.v`

Timing evidence:

- Result summary: `F:\codex\output\digit_recog_try_20260422\digit_ooc_route_result.txt`
- Setup WNS: `0.213 ns`
- Hold WHS: `0.215 ns`
- Setup failing paths: `0`
- Hold failing paths: `0`
- Detailed summary: `F:\codex\output\digit_recog_try_20260422\digit_ooc_route_timing_summary.txt`
- Setup paths: `F:\codex\output\digit_recog_try_20260422\digit_ooc_route_timing_paths_setup.txt`
- Hold paths: `F:\codex\output\digit_recog_try_20260422\digit_ooc_route_timing_paths_hold.txt`

Simulation evidence:

- Log: `F:\codex\output\digit_recog_try_20260422\tb_run.log`
- Result line: `TB_PASS digit template matching works for frame-wise recognition`
