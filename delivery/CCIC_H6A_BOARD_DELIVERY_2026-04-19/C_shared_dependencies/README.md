# 公共依赖

这一层是为了避免重名和漏依赖。

这里统一放所有主交付模块都会复用的公共 RTL：

- `grayscale_stream_std.v`
- `window3x3_stream_std.v`
- `frame_latched_u2.v`
- `frame_latched_s9.v`
- `frame_latched_affine6_s16.v`
- `rgb888_to_ycbcr444_stream_std.v`
- `ycbcr444_luma_gamma_stream_std.v`
- `ycbcr444_to_rgb888_stream_std.v`

交接建议：

- Vivado 里优先把 `C_shared_dependencies/rtl` 整层加进去
- 再加具体算法目录里的 `rtl`

这层做过的选择：

- `grayscale_stream_std.v` 和 `window3x3_stream_std.v` 只保留一份统一版本
- 外部库链路不再单独复制它们，避免同名模块冲突
