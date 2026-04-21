# Timing Status: C_shared_dependencies

Status:
- `DEPENDENCY LAYER`
- Not signed off in isolation
- Fresh local evidence now exists under real consuming tops
- This table only lists consuming-top evidence that is still fresh after the current `window3x3_stream_std` refactor

Target:
- Device: `xc7z020clg400-1`
- Clock: `138.5MHz`
- Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`
- Tool used for this fresh local evidence: `Vivado 2018.3 OOC synth/place/route`

Evidence under consuming tops:

| Dependency or dependency group | Consuming top | PASS/FAIL | WNS | TNS | WHS | THS | Main note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `rgb888_to_ycbcr444_stream_std`, `ycbcr444_luma_gamma_stream_std`, `ycbcr444_to_rgb888_stream_std` | `rtl/rgb_ycbcr_gamma_rgb_chain_top.v` | `PASS` | `0.744ns` | `0.000ns` | `0.159ns` | `0.000ns` | safe only for this tested consuming-top boundary |
| `window3x3_stream_std` feeding Gaussian chain | `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_gaussian_chain_top.v` | `PASS` | `0.309ns` | `0.000ns` | `0.127ns` | `0.000ns` | passes on the tested promoted single-lane boundary after the request/response window-buffer refactor |
| `window3x3_stream_std` feeding Median chain | `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_median_chain_top.v` | `FAIL` | `-1.566ns` | `-81.746ns` | `0.128ns` | `0.000ns` | shared seam is improved, but the promoted top still fails because the median compare network remains heavy |
| `window3x3_stream_std` feeding Sobel chain | `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_sobel_chain_top.v` | `PASS` | `1.186ns` | `0.000ns` | `0.098ns` | `0.000ns` | passes on the tested promoted single-lane boundary after the window refactor and Sobel pipelining |
| `frame_latched_u2` | `A_staging_validated_board_ready/03_fixed_angle_rotate/rtl/fixed_angle_rotate_stream_std.v` | `PASS` | `0.287ns` | `0.000ns` | `0.132ns` | `0.000ns` | passes only as part of the tested frame-buffer-assisted rotate top |
| `frame_latched_affine6_s16` | `A_staging_validated_board_ready/07_affine_wrapper/rtl/affine_nearest_stream_std.v` | `PASS` | `0.585ns` | `0.000ns` | `0.159ns` | `0.000ns` | passes only as part of the tested frame-buffer-assisted affine top |

Rule for collaborators:
1. Timing signoff belongs to the consuming top, not to this folder alone.
2. Reuse is allowed, but pass/fail claims must cite the exact consuming top and boundary.
3. The refreshed `window3x3_stream_std` evidence only covers the consuming tops listed above.
4. Any other `window3x3_stream_std` consumer must be re-run before claiming fresh `138.5MHz` closure.
