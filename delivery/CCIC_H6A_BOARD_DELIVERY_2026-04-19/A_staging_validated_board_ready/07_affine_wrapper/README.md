# 仿射变换包装版

主模块：

- `affine_nearest_stream_std.v`

依赖：

- `frame_latched_affine6_s16.v`

怎么用：

- 这是能直接产生可见仿射效果的包装版
- 当前边界是 `RGB888`、最近邻、局部帧缓存

最少加这些文件：

- `rtl/affine_nearest_stream_std.v`
- `C_shared_dependencies/rtl/frame_latched_affine6_s16.v`

验证参考：

- `tb/tb_affine_nearest_stream_std.v`
- `tb/tb_affine_nearest_stream_std_flip.v`
- `tb/tb_affine_nearest_stream_std_scale.v`
- `tb/tb_affine_nearest_stream_std_shear.v`
- `tb/tb_affine_nearest_stream_std_multilane.v`
- `tb/tb_affine_nearest_stream_std_default8.v`
- `tb/tb_affine_nearest_stream_std_default8_partial.v`
- `tb/tb_affine_nearest_stream_std_default8_stress.v`

特别注意：

- 这是主交付的 affine 版本
- 不要把下面参考层里的 `affine_readback_path.v` 当成同类独立上板 IP
