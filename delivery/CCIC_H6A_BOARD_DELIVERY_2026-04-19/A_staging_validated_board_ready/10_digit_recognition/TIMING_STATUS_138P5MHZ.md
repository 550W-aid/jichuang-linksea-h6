# Timing Status: 10_digit_recognition

Status:

- `PASS`
- Detect-then-recognize architecture (`shared preprocess + runtime ROI detector + per-slot cores`) OOC synthesis + route timing passed at `138.5MHz` target clock.

Target:

- Device: `xc7z020clg400-1`
- Clock constraint: `create_clock -name clk -period 7.220 [get_ports clk]`

Top RTL:

- `rtl/digit_template_match_stream_std.v`
- `rtl/digit_template_match_slot_core.v`

Timing evidence:

- Result summary: `F:\codex\output\digit_recog_detect_then_recog_20260423\digit_detect_recog_ooc_route_result.txt`
- Setup WNS: `0.140 ns`
- Hold WHS: `0.122 ns`
- Setup failing paths: `0`
- Hold failing paths: `0`
- Detailed summary: `F:\codex\output\digit_recog_detect_then_recog_20260423\digit_detect_recog_ooc_route_timing_summary.txt`
- Setup paths: `F:\codex\output\digit_recog_detect_then_recog_20260423\digit_detect_recog_ooc_route_timing_paths_setup.txt`
- Hold paths: `F:\codex\output\digit_recog_detect_then_recog_20260423\digit_detect_recog_ooc_route_timing_paths_hold.txt`

Simulation evidence:

- Log: `F:\codex\output\digit_recog_detect_then_recog_20260423\tb_run.log`
- Result line: `TB_PASS detection+recognition multi-digit pipeline works`
