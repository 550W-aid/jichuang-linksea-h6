# CCIC H6A 138.5MHz Timing Gate

Target:
- Device: `xc7z020clg400-1`
- Clock: `138.5MHz`
- Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`
- Method: Vivado 2024.2 OOC synth/place/route

This document is the current timing gate for the delivery bundle:
- `CCIC_H6A_BOARD_DELIVERY_2026-04-19`

## Signed Off For 138.5MHz

Only the following modules are currently cleared for `138.5MHz` handoff.

1. `01_histogram_equalizer`
   - Folder:
     - `CCIC_H6A_BOARD_DELIVERY_2026-04-19/A_staging_validated_board_ready/01_histogram_equalizer`
   - Top RTL:
     - `histogram_equalizer_stream_std.v`
   - Result:
     - `setup_wns=5.082ns`
     - `hold_whs=0.522ns`

2. `04_low_light_enhance`
   - Folder:
     - `CCIC_H6A_BOARD_DELIVERY_2026-04-19/A_staging_validated_board_ready/04_low_light_enhance`
   - Top RTL:
     - `darkness_enhance_rgb888_stream_std.v`
   - Result:
     - `setup_wns=0.682ns`
     - `hold_whs=0.132ns`

3. `05_bilateral_filter`
   - Folder:
     - `CCIC_H6A_BOARD_DELIVERY_2026-04-19/A_staging_validated_board_ready/05_bilateral_filter`
   - Top RTL:
     - `bilateral_3x3_stream_std.v`
   - Result:
     - `setup_wns=0.199ns`
     - `hold_whs=0.132ns`
   - Note:
     - This passing version already includes arithmetic pipeline restructuring and a dedicated divider pipeline.

4. `06_guided_filter`
   - Folder:
     - `CCIC_H6A_BOARD_DELIVERY_2026-04-19/A_staging_validated_board_ready/06_guided_filter`
   - Top RTL:
     - `guided_filter_3x3_stream_std.v`
   - Result:
     - `setup_wns=0.165ns`
     - `hold_whs=0.132ns`
   - Note:
     - This passing version depends on the pipeline split already added to the arithmetic core.

## Not Signed Off / Do Not Handoff As 138.5MHz Clean

These modules must not be described as `138.5MHz clean`.

1. `02_realtime_resize`
   - Folder:
     - `CCIC_H6A_BOARD_DELIVERY_2026-04-19/A_staging_validated_board_ready/02_realtime_resize`
   - Top RTL:
     - `bilinear_resize_realtime_stream_std.v`
   - Status:
     - `FAIL`
   - Current result:
     - `setup_wns=-30.471ns`
     - `hold_whs=0.271ns`
   - Root problem:
     - Long bilinear coordinate and interpolation arithmetic path
   - Required action:
     - Split scale-factor math, coordinate math, interpolation multiply/add chain, and output pack path into pipeline stages
   - Ownership:
     - Being fixed locally now by the current owner
     - Other collaborators should not duplicate this task unless reassigned

2. `03_fixed_angle_rotate`
   - Folder:
     - `CCIC_H6A_BOARD_DELIVERY_2026-04-19/A_staging_validated_board_ready/03_fixed_angle_rotate`
   - Top RTL:
     - `fixed_angle_rotate_stream_std.v`
   - Status:
     - `BLOCKED BEFORE TIMING SIGNOFF`
   - Root problem:
     - Current implementation expands into frame-sized storage that does not infer cleanly to BRAM and cannot be dissolved into registers
   - Required action:
     - Redesign around explicit BRAM/SDRAM frame-store architecture
     - Do not present as a pure one-pass video-stream block in current form

3. `07_affine_wrapper`
   - Folder:
     - `CCIC_H6A_BOARD_DELIVERY_2026-04-19/A_staging_validated_board_ready/07_affine_wrapper`
   - Top RTL:
     - `affine_nearest_stream_std.v`
   - Status:
     - `NOT SIGNED OFF`
   - Root problem:
     - Architecture still depends on frame-style readback assumptions and memory-side contract is not clean enough for board handoff
   - Required action:
     - Separate stream shell from memory-backed sampler
     - Pipeline coordinate transform and address math
     - Re-sign off timing after architecture cleanup

## Libraries And Shared Dependencies

These folders are useful, but not signed off as standalone board-facing tops:

1. `B_external_stream_std_library`
   - Reusable chains only
   - Not yet individually signed off at `138.5MHz`

2. `C_shared_dependencies`
   - Dependency layer only
   - Not standalone board-ready tops

3. `D_reference_not_direct_board_ip`
   - Reference only
   - Not for direct board handoff

## Collaboration Rules

1. Do not call a module `board-ready` without a fresh `138.5MHz` timing report.
2. Any long multiply/add/address chain must be pipelined.
3. If a module really depends on frame memory, label it as `frame-buffer assisted` instead of pretending it is a pure video-stream block.
4. Timing evidence must sit next to the module before integration handoff.
5. Keep `02_realtime_resize` ownership with the current owner unless task ownership is explicitly changed.
