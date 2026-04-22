# 10 Digit Recognition

Top module:

- `rtl/digit_template_match_stream_std.v`

What this module does:

- Accepts real-time RGB888 video stream (`s_valid/s_ready/s_sof/s_eol/s_eof`)
- Samples a fixed ROI (`ROI_X/Y/W/H`) on a coarse grid (`SAMPLE_STRIDE`)
- Converts sampled pixels to foreground/background by grayscale threshold
- Compares one frame against built-in templates for digits `0~9`
- Outputs one frame-level classification result:
  - `o_digit_valid` (pulse)
  - `o_digit_id`
  - `o_digit_score`

Stream behavior:

- Pixel stream is passthrough (input to output unchanged)
- Recognition runs in parallel without stalling the stream

Current intended use:

- Fast board demo for camera-captured high-contrast digits
- Best for printed/segment-like digits inside a fixed ROI
- This is a lightweight on-FPGA real-time baseline, not a full CNN end-to-end classifier

Key parameters:

- `FRAME_WIDTH`, `FRAME_HEIGHT`
- `ROI_X`, `ROI_Y`, `ROI_W`, `ROI_H`
- `SAMPLE_STRIDE`
- `THRESHOLD`

Testbench:

- `tb/tb_digit_template_match_stream_std.v`
