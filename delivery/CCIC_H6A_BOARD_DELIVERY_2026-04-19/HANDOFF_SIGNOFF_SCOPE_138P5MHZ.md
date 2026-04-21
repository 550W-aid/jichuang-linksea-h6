# 交接口径表：138.5MHz 时序签核范围

更新时间：2026-04-21  
统一约束：`create_clock -name clk -period 7.220 [get_ports clk]`  
器件：`xc7z020clg400-1`

## 1) 顶层签核状态（可直接按当前边界交付）

### A_staging_validated_board_ready

| 子目录 | 顶层模块 | 状态 | 备注 |
| --- | --- | --- | --- |
| 01_histogram_equalizer | `rtl/histogram_equalizer_stream_std.v` | PASS | 已有 138.5MHz 报告 |
| 02_realtime_resize | `rtl/bilinear_resize_realtime_stream_std.v` | PASS | 已有 138.5MHz 报告 |
| 03_fixed_angle_rotate | `rtl/fixed_angle_rotate_stream_std.v` | PASS | `FRAME-BUFFER ASSISTED`，非纯流式 |
| 04_low_light_enhance | `rtl/darkness_enhance_rgb888_stream_std.v` | PASS | 已有 138.5MHz 报告 |
| 05_bilateral_filter | `rtl/bilateral_3x3_stream_std.v` | PASS | 已有 138.5MHz 报告 |
| 06_guided_filter | `rtl/guided_filter_3x3_stream_std.v` | PASS | 已有 138.5MHz 报告 |
| 07_affine_wrapper | `rtl/affine_nearest_stream_std.v` | PASS | `FRAME-BUFFER ASSISTED`，非纯流式 |

### B_external_stream_std_library

| 子目录 | 顶层模块（promoted top） | 状态 | 已签核边界 |
| --- | --- | --- | --- |
| 01_gray_window_filter_chain | `gray_window_gaussian_chain_top` / `gray_window_median_chain_top` / `gray_window_sobel_chain_top` | PASS | `MAX_LANES=1`, `640x480` |
| 02_binary_morphology_chain | `gray_threshold_erode_chain_top` | PASS | `MAX_LANES=1`, `640x480` |

说明：B 的 PASS 是“promoted top + 指定边界”意义上的 PASS，不是“所有复用场景无条件 PASS”。

## 2) 子模块签核口径（重点：你提到的暗光处理 4 个子模块）

`darkness_enhance_rgb888_stream_std.v` 依赖的 4 个子模块：

1. `frame_latched_s9`
2. `rgb888_to_ycbcr444_stream_std`
3. `ycbcr444_luma_gamma_stream_std`
4. `ycbcr444_to_rgb888_stream_std`

口径：
- 这 4 个子模块在 `darkness_enhance_rgb888_stream_std` 这个已签核顶层内，可视为“已覆盖签核”。
- 但这 4 个子模块**不按独立 IP 全场景签核**；若脱离该顶层、改参数或改连接方式复用，需要重新跑该新场景时序。

## 3) 什么时候必须让队友重新时序复核

出现以下任一项，必须重跑时序：

1. 改 `MAX_LANES`（例如从 1 改到 2/4/8）。
2. 改图像分辨率边界（例如从 `640x480` 改到 `1280x720` 或 `1920x1080`）。
3. 改顶层拼接方式（新增/替换前后级模块）。
4. 改关键参数（滤波核、插值策略、位宽、流水级数）。
5. 改时钟目标（仍是 138.5MHz 以外，或同频但约束口径变化）。

## 4) 交接一句话模板（可直接发队友）

“A/B 当前列出的顶层在已记录边界下已过 138.5MHz；子模块默认只在这些顶层场景内视为覆盖通过，任何新拓扑/新参数/新分辨率都要重跑 7.220ns 时序。”

