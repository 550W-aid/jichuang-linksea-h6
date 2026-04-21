# CCIC H6A 交付模块时序分类与分工（2026-04-21）

目标时钟统一为 `138.5MHz`（`period=7.220ns`），器件统一为 `xc7z020clg400-1`。

---

## 1) 已签核，可作为 138.5MHz 交付基线

以下模块已经有明确 OOC 签核结论，可作为“已过 138.5MHz”基线：

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

说明：
- 顶层签核以各目录下 `TIMING_STATUS_138P5MHZ.md` 为准。
- `02_realtime_resize` 当前签核边界为 `MAX_LANES=1` 单通道下采样交付路径，不等同于多通道签核。

---

## 2) 未签核 / 阻塞（必须优先处理）

当前 A 类原阻塞模块 `03_fixed_angle_rotate` 与 `07_affine_wrapper` 已完成 fresh OOC 复验并转入已签核集合。

当前仍不能宣称 “138.5MHz clean” 的重点遗留项为：

1. `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gaussian3x3_stream_std.v`
2. `B_external_stream_std_library/01_gray_window_filter_chain/rtl/median3x3_stream_std.v`
3. `B_external_stream_std_library/01_gray_window_filter_chain/rtl/sobel3x3_stream_std.v`
   - 问题方向：`window3x3_stream_std` 的 line-memory seam 仍是 route-dominated 结构性瓶颈

---

## 3) 尚未作为独立板级 Top 做 138.5MHz 签核（需队友 Codex 接手）

这批模块属于库/依赖层，不是已签核板级 Top；如要对外交付，必须逐个约束+实现+出报告。

### B_external_stream_std_library（待验证）

1. `B_external_stream_std_library/01_gray_window_filter_chain/rtl/gaussian3x3_stream_std.v`
2. `B_external_stream_std_library/01_gray_window_filter_chain/rtl/median3x3_stream_std.v`
3. `B_external_stream_std_library/01_gray_window_filter_chain/rtl/sobel3x3_stream_std.v`
4. `B_external_stream_std_library/02_binary_morphology_chain/rtl/binary_threshold_stream_std.v`
5. `B_external_stream_std_library/02_binary_morphology_chain/rtl/erode3x3_binary_stream_std.v`
6. `B_external_stream_std_library/02_binary_morphology_chain/rtl/dilate3x3_binary_stream_std.v`

### C_shared_dependencies（依赖层，需在消费 Top 下验证）

1. `C_shared_dependencies/rtl/grayscale_stream_std.v`
2. `C_shared_dependencies/rtl/window3x3_stream_std.v`
3. `C_shared_dependencies/rtl/frame_latched_u2.v`
4. `C_shared_dependencies/rtl/frame_latched_s9.v`
5. `C_shared_dependencies/rtl/frame_latched_affine6_s16.v`
6. `C_shared_dependencies/rtl/rgb888_to_ycbcr444_stream_std.v`
7. `C_shared_dependencies/rtl/ycbcr444_luma_gamma_stream_std.v`
8. `C_shared_dependencies/rtl/ycbcr444_to_rgb888_stream_std.v`

---

## 4) 队友 Codex 接手标准（强制）

对“未签核/阻塞/待验证”文件，统一执行：

1. 约束统一为：
   - `create_clock -name clk -period 7.220 [get_ports clk]`
   - Device: `xc7z020clg400-1`
2. 先跑 OOC synth + impl，再给出 `WNS/TNS/WHS/THS`。
3. 若负裕量或组合链过深：
   - 拆分乘加地址链，插入流水线寄存器
   - 避免大体量单 always 组合路径
   - 帧存储走显式 BRAM/SDRAM 接口
4. 每个模块产出同目录 `TIMING_STATUS_138P5MHZ.md`，写清是否 PASS、签核边界、报告路径。
5. 严禁在 RTL 引入仿真语句（`$display/$finish/error/while` 等仿真风格控制语句）。

---

## 5) 你本地与队友的分工建议（当前）

- 你本地：继续处理 `02_realtime_resize` 的后续演进（若改动 datapath，需重签核）。
- 队友 Codex：`03_fixed_angle_rotate`、`07_affine_wrapper` 已完成签核；下一优先级转为 `window3x3_stream_std` 相关 gray-window 链的 138.5MHz 优化。

