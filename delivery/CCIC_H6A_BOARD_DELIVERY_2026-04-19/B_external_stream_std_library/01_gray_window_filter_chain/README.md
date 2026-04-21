# 外部库灰度窗口滤波链

来源：

- `F:\图像处理\规范流式接口`

这组文件不是“单文件直接吃 RGB 相机流”的完整盒子，而是一条标准链。

推荐接法：

1. `C_shared_dependencies/rtl/grayscale_stream_std.v`
2. `C_shared_dependencies/rtl/window3x3_stream_std.v`
3. 三选一：
   - `gaussian3x3_stream_std.v`
   - `median3x3_stream_std.v`
   - `sobel3x3_stream_std.v`

适用场景：

- Gaussian：平滑
- Median：椒盐噪声抑制
- Sobel：边缘强度

最少加这些文件：

- `C_shared_dependencies/rtl/grayscale_stream_std.v`
- `C_shared_dependencies/rtl/window3x3_stream_std.v`
- `rtl/gaussian3x3_stream_std.v` 或 `rtl/median3x3_stream_std.v` 或 `rtl/sobel3x3_stream_std.v`

验证参考：

- `tb/tb_grayscale_stream_std.v`
- `tb/tb_window3x3_stream_std_unit.v`
- `tb/tb_gray_window_gaussian_std.v`
- `tb/tb_gray_window_median_std.v`
- `tb/tb_gray_window_sobel_std.v`
- `tb/tb_gray_window_sobel_small_std.v`

特别注意：

- `gaussian3x3_stream_std.v`、`median3x3_stream_std.v`、`sobel3x3_stream_std.v`
  的输入是 `3x3` 窗口流，不是原始 `RGB888`
- 所以下一个 Codex 不要直接拿它们去接摄像头口
- 为了避免同名 RTL 冲突，这包里统一使用 `C_shared_dependencies` 里的
  `grayscale_stream_std.v` 和 `window3x3_stream_std.v`
