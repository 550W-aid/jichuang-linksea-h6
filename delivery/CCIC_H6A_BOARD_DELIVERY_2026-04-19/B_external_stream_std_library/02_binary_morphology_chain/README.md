# 外部库二值形态学链

来源：

- `F:\图像处理\规范流式接口`

推荐接法：

1. 如果输入是 `RGB888`，先接 `C_shared_dependencies/rtl/grayscale_stream_std.v`
2. `binary_threshold_stream_std.v`
3. `C_shared_dependencies/rtl/window3x3_stream_std.v`
4. 二选一：
   - `erode3x3_binary_stream_std.v`
   - `dilate3x3_binary_stream_std.v`

最少加这些文件：

- `rtl/binary_threshold_stream_std.v`
- `rtl/erode3x3_binary_stream_std.v` 或 `rtl/dilate3x3_binary_stream_std.v`
- `C_shared_dependencies/rtl/window3x3_stream_std.v`
- 如果前级还是彩色流，再加 `C_shared_dependencies/rtl/grayscale_stream_std.v`

验证参考：

- `tb/tb_gray_threshold_small_std.v`
- `tb/tb_gray_threshold_erode_small_std.v`
- `tb/tb_gray_threshold_dilate_small_std.v`

特别注意：

- `erode3x3_binary_stream_std.v` 和 `dilate3x3_binary_stream_std.v` 吃的是 `3x3` 窗口流
- 它们不是直接吃单像素灰度流
- 这包里统一不再复制第二份同名 `window3x3_stream_std.v`
