# Timing Status: C_shared_dependencies

Status:
- `DEPENDENCY LAYER`
- Not signed off in isolation
- Fresh local evidence now exists under real consuming tops

Target:
- Device: `xc7z020clg400-1`
- Clock: `138.5MHz`
- Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`
- Tool used for this fresh local evidence: `Vivado 2018.3 OOC synth/place/route`

Evidence under consuming tops:

| Dependency or dependency group | Consuming top | PASS/FAIL | WNS | TNS | WHS | THS | Main note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `rgb888_to_ycbcr444_stream_std`, `ycbcr444_luma_gamma_stream_std`, `ycbcr444_to_rgb888_stream_std` | `rtl/rgb_ycbcr_gamma_rgb_chain_top.v` | `PASS` | `0.744ns` | `0.000ns` | `0.159ns` | `0.000ns` | safe only for this tested consuming-top boundary |
| `grayscale_stream_std` in threshold morphology path | `B_external_stream_std_library/02_binary_morphology_chain/rtl/gray_threshold_erode_chain_top.v` | `PASS` | `0.230ns` | `0.000ns` | `0.191ns` | `0.000ns` | passes under promoted single-lane morphology top |
| `grayscale_stream_std` in threshold morphology path | `B_external_stream_std_library/02_binary_morphology_chain/rtl/gray_threshold_dilate_chain_top.v` | `PASS` | `0.131ns` | `0.000ns` | `0.158ns` | `0.000ns` | passes under promoted single-lane morphology top |
| `window3x3_stream_std` feeding gray-window chains | `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_gaussian_chain_top.v` and peers | `FAIL` | `-1.205ns` to `-2.307ns` | non-zero negative | positive hold | `0.000ns` | current memory seam is the main blocker |
| `frame_latched_u2` | `A_staging_validated_board_ready/03_fixed_angle_rotate/rtl/fixed_angle_rotate_stream_std.v` | `PASS` | `0.287ns` | `0.000ns` | `0.132ns` | `0.000ns` | passes only as part of the tested frame-buffer-assisted rotate top |
| `frame_latched_affine6_s16` | `A_staging_validated_board_ready/07_affine_wrapper/rtl/affine_nearest_stream_std.v` | `PASS` | `0.585ns` | `0.000ns` | `0.159ns` | `0.000ns` | passes only as part of the tested frame-buffer-assisted affine top |

Rule for collaborators:
1. Timing signoff belongs to the consuming top, not to this folder alone.
2. Reuse is allowed, but pass/fail claims must cite the exact consuming top and boundary.
3. `window3x3_stream_std` still needs seam-level timing work before gray-window chains can be handed off.
