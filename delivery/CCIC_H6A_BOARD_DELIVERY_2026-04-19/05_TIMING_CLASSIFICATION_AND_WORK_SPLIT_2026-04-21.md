# CCIC H6A Timing Classification And Work Split (2026-04-21)

Unified signoff target:
- Device: `xc7z020clg400-1`
- Clock: `138.5MHz`
- Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`

## 1. Signed Off On The Tested Boundary

These modules now have fresh `138.5MHz` OOC evidence on their stated boundary:

1. `A_staging_validated_board_ready/01_histogram_equalizer/rtl/histogram_equalizer_stream_std.v`
2. `A_staging_validated_board_ready/02_realtime_resize/rtl/bilinear_resize_realtime_stream_std.v`
3. `A_staging_validated_board_ready/02_realtime_resize/rtl/bilinear_rgb888_pipe.v`
4. `A_staging_validated_board_ready/04_low_light_enhance/rtl/darkness_enhance_rgb888_stream_std.v`
5. `A_staging_validated_board_ready/05_bilateral_filter/rtl/bilateral_3x3_stream_std.v`
6. `A_staging_validated_board_ready/05_bilateral_filter/rtl/bilateral_3x3_core.v`
7. `A_staging_validated_board_ready/05_bilateral_filter/rtl/u16_u10_div_pipe8.v`
8. `A_staging_validated_board_ready/06_guided_filter/rtl/guided_filter_3x3_stream_std.v`
9. `A_staging_validated_board_ready/06_guided_filter/rtl/guided_filter_3x3_core.v`
10. `A_staging_validated_board_ready/03_fixed_angle_rotate/rtl/fixed_angle_rotate_stream_std.v`
11. `A_staging_validated_board_ready/03_fixed_angle_rotate/rtl/fixed_angle_rotate_addr_pipe.v`
12. `A_staging_validated_board_ready/07_affine_wrapper/rtl/affine_nearest_stream_std.v`
13. `A_staging_validated_board_ready/07_affine_wrapper/rtl/affine_nearest_addr_pipe.v`

Notes:
- `02_realtime_resize` remains signed off only on its tested single-lane delivery path.
- `03_fixed_angle_rotate` and `07_affine_wrapper` must keep the honest label `frame-buffer assisted`.

## 2. Current Blockers

These items are still not signed off as of the latest fresh evidence:

1. `B_external_stream_std_library/01_gray_window_filter_chain/rtl/median3x3_stream_std.v`
   - Failing promoted top: `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_median_chain_top.v`
   - Current result: `WNS=-1.566ns`, `TNS=-81.746ns`, `WHS=0.128ns`, `THS=0.000ns`
   - Likely blocker: route-heavy row-sort compare network from `stg0_data_reg[*]` to `stg1_rowsort_reg[*]`
   - Required next action: split the `sort3_pack` work across more compare/swap stages

## 3. Promoted B-Library Status

Fresh promoted-top evidence now exists for:

1. `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_gaussian_chain_top.v`
   - `PASS`
   - `WNS=0.309ns`, `TNS=0.000ns`, `WHS=0.127ns`, `THS=0.000ns`
   - Main change that helped: `window3x3_stream_std` line-buffer request/response refactor
2. `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_sobel_chain_top.v`
   - `PASS`
   - `WNS=1.186ns`, `TNS=0.000ns`, `WHS=0.098ns`, `THS=0.000ns`
   - Main change that helped: Sobel pipeline split into weighted-sum, absolute-value, and saturation stages
3. `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gray_window_median_chain_top.v`
   - `FAIL`
   - `WNS=-1.566ns`, `TNS=-81.746ns`, `WHS=0.128ns`, `THS=0.000ns`
   - Main blocker: median row-sort compare network

These promoted-top results are limited to:
- `MAX_LANES=1`
- `IMG_WIDTH=640`
- `IMG_HEIGHT=480`

They are not multi-lane signoff claims.

## 4. Shared Dependency Status

`C_shared_dependencies` is still a dependency layer, not a standalone delivery layer.

Fresh current-round consuming-top evidence now exists for:

1. `window3x3_stream_std` under Gaussian promoted top: `PASS`
2. `window3x3_stream_std` under Sobel promoted top: `PASS`
3. `window3x3_stream_std` under Median promoted top: `FAIL`
4. `frame_latched_u2` under rotate top: `PASS`
5. `frame_latched_affine6_s16` under affine top: `PASS`
6. `rgb888_to_ycbcr444_stream_std`, `ycbcr444_luma_gamma_stream_std`, `ycbcr444_to_rgb888_stream_std` under `rgb_ycbcr_gamma_rgb_chain_top.v`: `PASS`

Rule:
- Do not claim a dependency is board-ready by itself.
- Cite the exact consuming top and the exact tested boundary.
- Any other `window3x3_stream_std` consumer must be re-run after the current refactor before anyone calls it fresh.

## 5. Recommended Work Split From Here

- Local owner: continue `02_realtime_resize` only if reassigned or if its boundary changes.
- Codex timing owner: continue on `median3x3_stream_std` until the promoted median top is also clean at `138.5MHz`.
- Other collaborators: avoid reworking `03_fixed_angle_rotate` and `07_affine_wrapper` unless the consuming boundary changes, because they now have fresh passing evidence.
