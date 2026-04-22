# 08 HDR Tone Map

Top module:

- `hdr_enhance_rgb888_stream_std.v`

Internal algorithm chain:

- `RGB888 -> YCbCr444 -> HDR luma tone map -> RGB888`

Local RTL in this package:

- `rtl/hdr_enhance_rgb888_stream_std.v`
- `rtl/hdr_luma_tonemap_stream_std.v`

Shared dependency RTL:

- `C_shared_dependencies/rtl/frame_latched_u2.v`
- `C_shared_dependencies/rtl/rgb888_to_ycbcr444_stream_std.v`
- `C_shared_dependencies/rtl/ycbcr444_to_rgb888_stream_std.v`

Control interface (frame-latched):

- `cfg_shadow_level[1:0]`
- `cfg_highlight_level[1:0]`

Both controls are committed at frame boundary (`s_valid && s_ready && s_sof`).

Behavior summary:

- Shadows (`Y < 96`) are lifted based on `cfg_shadow_level`.
- Highlights (`Y > 160`) are compressed based on `cfg_highlight_level`.
- Higher control level means stronger effect.

Testbench:

- `tb/tb_hdr_enhance_frame_commit_output.v`

