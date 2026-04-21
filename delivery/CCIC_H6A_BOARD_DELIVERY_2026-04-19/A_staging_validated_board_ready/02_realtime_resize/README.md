# Realtime Resize

Top RTL:

- `rtl/bilinear_resize_realtime_stream_std.v`
- `rtl/bilinear_rgb888_pipe.v`

What this block is:

- Real-time RGB888 video-stream downscaler
- Bilinear interpolation datapath with explicit pipeline stages
- Timing-closed delivery configuration is the single-lane path (`MAX_LANES=1`)

What this block is not:

- Not signed off as a generic multi-lane scaler
- Not an upscaler
- Not a frame-buffer readback architecture

Interface notes:

- Input and output are stream-style `RGB888`
- `cfg_out_width`, `cfg_out_height`, `cfg_scale_x_fp`, and `cfg_scale_y_fp` are latched on the next `s_sof`
- In the current signed-off delivery build, only lane 0 is populated
- Row storage is currently inferred as LUTRAM, not BRAM

Minimum files to integrate:

- `rtl/bilinear_resize_realtime_stream_std.v`
- `rtl/bilinear_rgb888_pipe.v`

Testbench references:

- `tb/tb_bilinear_resize_realtime_stream_std_smoke.v`
- `tb/tb_bilinear_resize_realtime_stream_std_backpressure.v`
- `tb/tb_bilinear_resize_realtime_stream_std_cfg_commit.v`
- `tb/tb_bilinear_resize_realtime_stream_std_partial_row.v`
- `tb/tb_bilinear_resize_realtime_stream_std_multilane.v`
- `tb/tb_bilinear_resize_realtime_stream_std_default8.v`
- `tb/tb_bilinear_resize_realtime_stream_std_default8_partial.v`

Timing signoff note:

- This folder is signed off at `138.5MHz` for the current single-lane downscale delivery configuration.
- Timing evidence is recorded in `TIMING_STATUS_138P5MHZ.md`.
