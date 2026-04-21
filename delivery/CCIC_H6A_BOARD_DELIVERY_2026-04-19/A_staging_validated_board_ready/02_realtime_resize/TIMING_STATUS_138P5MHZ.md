# Timing Status: 02_realtime_resize

Status:

- `PASS`
- Cleared for `138.5MHz` board handoff only in the current single-lane delivery configuration

Top RTL:

- `rtl/bilinear_resize_realtime_stream_std.v`
- `rtl/bilinear_rgb888_pipe.v`

Signed-off result:

- `setup_wns=0.204ns`
- `hold_whs=0.123ns`

Signoff boundary:

- Device: `xc7z020clg400-1`
- Clock: `138.5MHz`
- Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`
- Method: Vivado 2024.2 OOC synth/place/route
- Intended delivery mode: `MAX_LANES=1`
- Current row-buffer implementation: LUTRAM inference

Evidence:

- `F:\codex\output\resize_timing_20260421_r8_issue_commit\result.txt`
- `F:\codex\output\resize_timing_20260421_r8_issue_commit\timing_summary.txt`
- `F:\codex\output\resize_timing_20260421_r8_issue_commit\timing_paths.txt`
- `F:\codex\output\resize_timing_20260421_r8_issue_commit\utilization.txt`

Current conclusion:

- This module is timing-closed for the current single-lane real-time downscale delivery path.
- Do not generalize this signoff to multi-lane scaling without a fresh timing run.
- The current delivery RTL uses an `issue/commit` split so that output-state updates do not sit in the same cycle as sample-hit detection.
- Current worst routed setup path is now inside the DSP bilinear core, not on the `src_y_fp_q -> out_y_q` control update path.
