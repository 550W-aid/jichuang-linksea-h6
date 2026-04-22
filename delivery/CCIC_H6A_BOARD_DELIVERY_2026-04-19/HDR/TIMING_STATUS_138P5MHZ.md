# Timing Status: 08_hdr_tonemap

Status:

- `PASS`
- Cleared for `138.5MHz` under OOC synth/place/route timing run.

Target:

- Device: `xc7z020clg400-1`
- Clock: `138.5MHz`
- Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`

Top RTL:

- `rtl/hdr_enhance_rgb888_stream_std.v`

Result:

- `setup_wns=0.411ns`
- `hold_whs=0.124ns`
- `setup_fail_paths=0`
- `hold_fail_paths=0`

Evidence:

- `F:\codex\output\hdr_try_20260422\hdr_ooc_route_result_r2.txt`
- `F:\codex\output\hdr_try_20260422\hdr_ooc_route_timing_summary_r2.txt`
- `F:\codex\output\hdr_try_20260422\hdr_ooc_route_timing_paths_setup_r2.txt`
- `F:\codex\output\hdr_try_20260422\hdr_ooc_route_timing_paths_hold_r2.txt`
- `F:\codex\output\hdr_try_20260422\hdr_ooc_route_utilization_r2.txt`

Verification note:

- A dedicated behavioral testbench passed:
  - `tb/tb_hdr_enhance_frame_commit_output.v`
- Test run evidence:
  - `TB_PASS hdr frame-latched tone-mapping behavior is correct`
