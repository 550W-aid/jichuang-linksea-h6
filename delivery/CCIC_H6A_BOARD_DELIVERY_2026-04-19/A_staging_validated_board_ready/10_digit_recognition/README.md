# 10 Digit Recognition

Top module:

- `rtl/digit_template_match_stream_std.v`
- `rtl/digit_template_match_slot_core.v` (instantiated per slot)

What this module does:

- Accepts real-time RGB888 video stream (`s_valid/s_ready/s_sof/s_eol/s_eof`)
- Uses a multi-slot ROI layout:
  - slot count: `NUM_DIGITS`
  - slot size: `DIGIT_W x DIGIT_H`
  - slot spacing: `DIGIT_GAP`
  - top-left anchor: `ROI_X/ROI_Y`
- Samples each slot on a coarse grid (`SAMPLE_STRIDE`)
- Reuses shared preprocess modules for grayscale + threshold:
  - `C_shared_dependencies/rtl/grayscale_stream_std.v`
  - `B_external_stream_std_library/02_binary_morphology_chain/rtl/binary_threshold_stream_std.v`
- Uses one shared preprocess path + multiple independent per-slot matcher cores
- Converts sampled pixels to foreground/background by binary threshold result
- Compares every slot in one frame against built-in templates for digits `0~9`
- Outputs one frame-level multi-digit classification result:
  - `o_digits_valid` (pulse)
  - `o_digit_ids` (packed per slot)
  - `o_digit_scores` (packed per slot)
  - `o_digit_present` (slot foreground-present mask)
- Keeps backward-compatible single-digit outputs for slot0:
  - `o_digit_valid`
  - `o_digit_id`
  - `o_digit_score`

Stream behavior:

- Pixel stream is passthrough (input to output unchanged)
- Recognition runs in parallel without stalling the stream

Current intended use:

- Fast board demo for camera-captured high-contrast digits
- Best for printed/segment-like digits arranged in fixed horizontal slots
- This is a lightweight on-FPGA real-time baseline, not a full CNN end-to-end classifier

Key parameters:

- `FRAME_WIDTH`, `FRAME_HEIGHT`
- `ROI_X`, `ROI_Y`
- `NUM_DIGITS`, `DIGIT_W`, `DIGIT_H`, `DIGIT_GAP`
- `SAMPLE_STRIDE`
- `THRESHOLD`
- `MIN_FG_PIX`

Testbench:

- `tb/tb_digit_template_match_stream_std.v`
