# 138.5MHz Timing Gate

Target:
- Device: `xc7z020clg400-1`
- Clock: `138.5MHz`
- Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`
- Method: Vivado 2024.2 OOC synth/place/route

Use this file as the timing gate for GitHub collaborators.

## Signed Off For 138.5MHz

Only the following modules are currently cleared for board handoff at `138.5MHz`:

1. `A_staging_validated_board_ready/01_histogram_equalizer`
   - Top RTL: `histogram_equalizer_stream_std.v`
   - Result: `setup_wns=5.082ns`, `hold_whs=0.522ns`
2. `A_staging_validated_board_ready/04_low_light_enhance`
   - Top RTL: `darkness_enhance_rgb888_stream_std.v`
   - Result: `setup_wns=0.682ns`, `hold_whs=0.132ns`
3. `A_staging_validated_board_ready/02_realtime_resize`
   - Top RTL: `bilinear_resize_realtime_stream_std.v`
   - Supporting RTL: `bilinear_rgb888_pipe.v`
   - Result: `setup_wns=0.204ns`, `hold_whs=0.123ns`
   - Signoff boundary: single-lane downscale delivery path (`MAX_LANES=1`)
   - Implementation note: row buffers currently infer as LUTRAM
4. `A_staging_validated_board_ready/05_bilateral_filter`
   - Top RTL: `bilateral_3x3_stream_std.v`
   - Result: `setup_wns=0.199ns`, `hold_whs=0.132ns`
5. `A_staging_validated_board_ready/06_guided_filter`
   - Top RTL: `guided_filter_3x3_stream_std.v`
   - Result: `setup_wns=0.165ns`, `hold_whs=0.132ns`

## Not Signed Off / Do Not Handoff As 138.5MHz Clean

These modules must not be described as `138.5MHz clean` in GitHub handoff notes:

1. `A_staging_validated_board_ready/03_fixed_angle_rotate`
   - Top RTL: `fixed_angle_rotate_stream_std.v`
   - Status: blocked before timing signoff
   - Root issue: frame-sized storage architecture is not synthesizable in current form
   - Required action: redesign around explicit BRAM/SDRAM frame-store architecture; do not treat as a pure one-pass video stream block
2. `A_staging_validated_board_ready/07_affine_wrapper`
   - Top RTL: `affine_nearest_stream_std.v`
   - Status: not signed off
   - Root issue: architecture still depends on frame-style readback assumptions
   - Required action: external memory seam plus pipelined coordinate pipeline and explicit latency contract

## Libraries And Shared Dependencies

- `B_external_stream_std_library`
  - Not signed off as standalone `138.5MHz` board-ready tops
  - These are reusable chains, not yet timing-cleared delivery tops
- `C_shared_dependencies`
  - Not standalone delivery tops
  - Reuse only as dependencies under a separately signed-off top module
- `D_reference_not_direct_board_ip`
  - Reference only
  - Do not hand off as board-ready IP

## Action Notes For GitHub Members

If you pick up any blocked module, follow these rules:

1. Do not claim timing closure without a fresh `138.5MHz` report.
2. Any long multiply-add-address chain must be split into pipeline stages.
3. Do not keep frame-sized arrays in monolithic RTL if they cannot infer to BRAM/URAM.
4. Pure video-stream handoff and frame-buffer-based handoff must be labeled separately.
5. Put timing evidence next to the module before asking others to integrate it.

Primary evidence summary is tracked in:
- `docs/TIMING_STATUS_2026-04-20.md`
