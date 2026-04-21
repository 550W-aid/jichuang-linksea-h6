# 双边滤波

主模块：

- `bilateral_3x3_stream_std.v`

依赖：

- `bilateral_3x3_core.v`
- `grayscale_stream_std.v`
- `window3x3_stream_std.v`

怎么用：

- 输入 `RGB888`
- 模块内部会先灰度化，再做窗口展开，再做双边滤波
- 适合直接作为平滑增强模块上板

最少加这些文件：

- `rtl/bilateral_3x3_stream_std.v`
- `rtl/bilateral_3x3_core.v`
- `C_shared_dependencies/rtl/grayscale_stream_std.v`
- `C_shared_dependencies/rtl/window3x3_stream_std.v`

验证参考：

- `tb/tb_bilateral_3x3_stream_std.v`
- PASS marker: `tb_bilateral_3x3_stream_std passed.`

参数边界：

- 当前交付按 `MAX_LANES=1`
- 当前交付按 `PIX_W_OUT=8`
