# Timing Status: C_shared_dependencies

Status:
- `DEPENDENCY LAYER`
- Not signed off in isolation
- Current evidence is attached to specific consuming tops and boundaries

Target:
- Device: `xc7z020clg400-1`
- Clock: `138.5MHz`
- Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`

Evidence under consuming tops:

| Dependency or dependency group | Consuming top | PASS/FAIL | WNS | TNS | WHS | THS | Boundary / note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `frame_latched_s9`, `rgb888_to_ycbcr444_stream_std`, `ycbcr444_luma_gamma_stream_std`, `ycbcr444_to_rgb888_stream_std` | `rtl/rgb_ycbcr_gamma_rgb_chain_top.v` | `PASS` | `0.866ns` | `0.000ns` | `0.132ns` | `0.000ns` | Fresh rerun in this round (Vivado 2024.2 OOC) |
| `window3x3_stream_std` feeding Gaussian chain | `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_gaussian_chain_top.v` | `PASS` | `0.424ns` | `0.000ns` | `0.090ns` | `0.000ns` | Promoted-top boundary: `MAX_LANES=1`, `640x480` |
| `window3x3_stream_std` feeding Median chain | `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_median_chain_top.v` | `PASS` | `0.983ns` | `0.000ns` | `0.090ns` | `0.000ns` | Promoted-top boundary: `MAX_LANES=1`, `640x480` |
| `window3x3_stream_std` feeding Sobel chain | `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_sobel_chain_top.v` | `PASS` | `0.563ns` | `0.000ns` | `0.090ns` | `0.000ns` | Promoted-top boundary: `MAX_LANES=1`, `640x480` |
| `frame_latched_u2` | `A_staging_validated_board_ready/03_fixed_angle_rotate/rtl/fixed_angle_rotate_stream_std.v` | `PASS` | `0.287ns` | `0.000ns` | `0.132ns` | `0.000ns` | Frame-buffer-assisted rotate shell boundary |
| `frame_latched_affine6_s16` | `A_staging_validated_board_ready/07_affine_wrapper/rtl/affine_nearest_stream_std.v` | `PASS` | `0.585ns` | `0.000ns` | `0.159ns` | `0.000ns` | Frame-buffer-assisted affine shell boundary |

Rule for collaborators:
1. Timing signoff belongs to the consuming top, not this folder alone.
2. Reuse is allowed, but PASS claims must cite exact top + parameters + boundary.
3. Any change in lane count, resolution, topology, or clock constraint requires rerun.
