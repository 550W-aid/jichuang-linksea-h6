# 固定角旋转

主模块：

- `fixed_angle_rotate_stream_std.v`

来源：

- `F:\codex\staging\ccic_h6a_algo\basic`

依赖：

- `C_shared_dependencies/rtl/frame_latched_u2.v`

怎么用：

- 适合做 `0/90/180/270` 固定角旋转
- 这不是任意角旋转

最少加这些文件：

- `rtl/fixed_angle_rotate_stream_std.v`
- `../../C_shared_dependencies/rtl/frame_latched_u2.v`

验证参考：

- `tb/tb_fixed_angle_rotate_stream_std.v`
- PASS marker: `tb_fixed_angle_rotate_stream_std passed.`

特别注意：

- 角度配置是下一帧生效，不是写了就立刻切
- 不要和任意角旋转那条线混起来讲
