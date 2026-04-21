# 导向滤波

主模块：

- `guided_filter_3x3_stream_std.v`

依赖：

- `guided_filter_3x3_core.v`
- `grayscale_stream_std.v`
- `window3x3_stream_std.v`

怎么用：

- 输入 `RGB888`
- 模块内部会完成灰度化和窗口链
- 适合作为另一种平滑增强路径

最少加这些文件：

- `rtl/guided_filter_3x3_stream_std.v`
- `rtl/guided_filter_3x3_core.v`
- `C_shared_dependencies/rtl/grayscale_stream_std.v`
- `C_shared_dependencies/rtl/window3x3_stream_std.v`

验证参考：

- `tb/tb_guided_filter_3x3_core.v`
- `tb/tb_guided_filter_3x3_stream_std.v`

特别注意：

- 看这个模块时不要只看 wrapper，`core` 也一起看
- 当前交付按 `MAX_LANES=1`
- 当前交付按 `PIX_W_OUT=8`
