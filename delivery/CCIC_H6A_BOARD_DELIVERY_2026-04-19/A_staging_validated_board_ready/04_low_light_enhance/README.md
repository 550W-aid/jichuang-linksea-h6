# 低照度增强

主模块：

- `darkness_enhance_rgb888_stream_std.v`

依赖：

- `frame_latched_s9.v`
- `rgb888_to_ycbcr444_stream_std.v`
- `ycbcr444_luma_gamma_stream_std.v`
- `ycbcr444_to_rgb888_stream_std.v`

怎么用：

- 这是完整的 `RGB888 -> 低照度增强 -> RGB888` 算法盒子
- 适合直接插到摄像头后、显示前的链路里

最少加这些文件：

- `rtl/darkness_enhance_rgb888_stream_std.v`
- `C_shared_dependencies/rtl/frame_latched_s9.v`
- `C_shared_dependencies/rtl/rgb888_to_ycbcr444_stream_std.v`
- `C_shared_dependencies/rtl/ycbcr444_luma_gamma_stream_std.v`
- `C_shared_dependencies/rtl/ycbcr444_to_rgb888_stream_std.v`

验证参考：

- `tb/tb_darkness_enhance_frame_latch.v`
- `tb/tb_darkness_enhance_frame_commit_output.v`

特别注意：

- 亮度参数是下一帧生效
- 这模块是算法层，不负责视频时序和显示控制
