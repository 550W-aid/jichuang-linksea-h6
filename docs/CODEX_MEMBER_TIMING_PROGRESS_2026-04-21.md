# Codex Member Timing Progress (2026-04-21)

Scope in this update:
- Worked on `03_fixed_angle_rotate`
- Worked on `07_affine_wrapper`
- Promoted real consuming tops for `B_external_stream_std_library`
- Collected consuming-top evidence for `C_shared_dependencies`
- Did not modify `02_realtime_resize`

Environment used for fresh local evidence:
- Device: `xc7z020clg400-1`
- Clock: `138.5MHz`
- Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`
- Tool available on this host: `Vivado 2018.3`

Top-level summary:

| Module or promoted chain | Top RTL | Pure stream or frame-buffer assisted | 138.5MHz result | WNS | TNS | WHS | THS | Main bottleneck | Next action |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `03_fixed_angle_rotate` | `A_staging_validated_board_ready/03_fixed_angle_rotate/rtl/fixed_angle_rotate_stream_std.v` | `frame-buffer assisted` | `PASS` | `0.287ns` | `0.000ns` | `0.132ns` | `0.000ns` | `closed on tested boundary` | keep frame-buffer-assisted label and re-run only if the consuming boundary changes |
| `07_affine_wrapper` | `A_staging_validated_board_ready/07_affine_wrapper/rtl/affine_nearest_stream_std.v` | `frame-buffer assisted` | `PASS` | `0.585ns` | `0.000ns` | `0.159ns` | `0.000ns` | `closed on tested boundary` | keep frame-buffer-assisted label and re-run only if the consuming boundary changes |
| `B/01_gray_window_filter_chain` gaussian | `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_gaussian_chain_top.v` | `pure stream promoted top` | `FAIL` | `-1.205ns` | `-2811.878ns` | `0.132ns` | `0.000ns` | `memory seam` | re-pipeline `window3x3_stream_std` handoff |
| `B/01_gray_window_filter_chain` median | `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_median_chain_top.v` | `pure stream promoted top` | `FAIL` | `-1.925ns` | `-3972.344ns` | `0.098ns` | `0.000ns` | `memory seam` | re-pipeline `window3x3_stream_std` handoff |
| `B/01_gray_window_filter_chain` sobel | `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_sobel_chain_top.v` | `pure stream promoted top` | `FAIL` | `-2.307ns` | `-6404.348ns` | `0.176ns` | `0.000ns` | `memory seam` | re-pipeline `window3x3_stream_std` handoff |
| `B/02_binary_morphology_chain` erode | `B_external_stream_std_library/02_binary_morphology_chain/rtl/gray_threshold_erode_chain_top.v` | `pure stream promoted top` | `PASS` | `0.230ns` | `0.000ns` | `0.191ns` | `0.000ns` | `none on tested boundary` | keep signoff limited to single-lane `640x480` |
| `B/02_binary_morphology_chain` dilate | `B_external_stream_std_library/02_binary_morphology_chain/rtl/gray_threshold_dilate_chain_top.v` | `pure stream promoted top` | `PASS` | `0.131ns` | `0.000ns` | `0.158ns` | `0.000ns` | `none on tested boundary` | keep signoff limited to single-lane `640x480` |
| `C/rgb_ycbcr_gamma_rgb` consuming top | `C_shared_dependencies/rtl/rgb_ycbcr_gamma_rgb_chain_top.v` | `pure stream promoted top` | `PASS` | `0.744ns` | `0.000ns` | `0.159ns` | `0.000ns` | `none on tested boundary` | reusable only when the consuming top matches the tested boundary |

RTL files changed in this work:
- `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/A_staging_validated_board_ready/03_fixed_angle_rotate/rtl/fixed_angle_rotate_stream_std.v`
- `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/A_staging_validated_board_ready/03_fixed_angle_rotate/rtl/fixed_angle_rotate_addr_pipe.v`
- `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/A_staging_validated_board_ready/07_affine_wrapper/rtl/affine_nearest_stream_std.v`
- `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/A_staging_validated_board_ready/07_affine_wrapper/rtl/affine_nearest_addr_pipe.v`
- `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_gaussian_chain_top.v`
- `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_median_chain_top.v`
- `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_sobel_chain_top.v`
- `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/B_external_stream_std_library/02_binary_morphology_chain/rtl/gray_threshold_erode_chain_top.v`
- `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/B_external_stream_std_library/02_binary_morphology_chain/rtl/gray_threshold_dilate_chain_top.v`
- `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/C_shared_dependencies/rtl/rgb_ycbcr_gamma_rgb_chain_top.v`

Fresh report roots used in this update:
- `timing_runs/fixed_angle_rotate`
- `timing_runs/affine_nearest`
- `timing_runs/gray_window_gaussian`
- `timing_runs/gray_window_median`
- `timing_runs/gray_window_sobel`
- `timing_runs/gray_threshold_erode`
- `timing_runs/gray_threshold_dilate`
- `timing_runs/rgb_ycbcr_gamma_rgb`

Latest closure note:
- `03_fixed_angle_rotate` is now signed off on the tested OOC boundary after adding a registered request stage and narrowing address/control arithmetic widths.
- `07_affine_wrapper` is now signed off on the tested OOC boundary after adding a registered affine request stage and narrowing address/control arithmetic widths.
- The remaining shared blocker in this delivery slice is `window3x3_stream_std`, where the gray-window chains still fail on a route-dominated line-memory seam.
