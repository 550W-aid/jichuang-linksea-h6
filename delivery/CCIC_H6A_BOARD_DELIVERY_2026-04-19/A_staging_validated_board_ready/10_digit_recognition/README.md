# 10 Digit Recognition

Top module:

- `rtl/digit_template_match_stream_std.v`
- `rtl/digit_template_match_slot_core.v` (instantiated per slot)

What this module does:

- Accepts real-time RGB888 video stream (`s_valid/s_ready/s_sof/s_eol/s_eof`)
- Uses `detect-then-recognize` flow in stream:
  - stage1 (detector): accumulates foreground projection in `DETECT_X/DETECT_Y/DETECT_W/DETECT_H`
  - stage2 (matcher): runtime ROIs are fed to per-slot matcher cores
  - slot count: `NUM_DIGITS`
  - slot size: `DIGIT_W x DIGIT_H`
- Samples each slot on a coarse grid (`SAMPLE_STRIDE`)
- Reuses shared preprocess modules for grayscale + threshold:
  - `C_shared_dependencies/rtl/grayscale_stream_std.v`
  - `B_external_stream_std_library/02_binary_morphology_chain/rtl/binary_threshold_stream_std.v`
- Uses one shared preprocess path + multiple independent per-slot matcher cores (`rtl/digit_template_match_slot_core.v`)
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
- Supports multiple digits at runtime-detected positions (not fixed static slots)
- This is a lightweight on-FPGA real-time baseline, not a full CNN end-to-end classifier

Key parameters:

- `FRAME_WIDTH`, `FRAME_HEIGHT`
- `ROI_X`, `ROI_Y` (fallback/default slot anchors)
- `DETECT_X`, `DETECT_Y`, `DETECT_W`, `DETECT_H`
- `NUM_DIGITS`, `DIGIT_W`, `DIGIT_H`
- `DETECT_BIN_SHIFT`, `COL_THRESH`, `MIN_RUN_W`
- `SAMPLE_STRIDE`
- `THRESHOLD`
- `MIN_FG_PIX`

Testbench:

- `tb/tb_digit_template_match_stream_std.v`
