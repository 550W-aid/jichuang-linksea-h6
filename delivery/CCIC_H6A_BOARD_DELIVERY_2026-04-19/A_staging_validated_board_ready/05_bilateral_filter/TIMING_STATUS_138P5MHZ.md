# Timing Status: 05_bilateral_filter

Status:
- `PASS`
- Cleared for `138.5MHz` handoff under OOC timing signoff

Top RTL:
- `rtl/bilateral_3x3_stream_std.v`

Signed-off result:
- `setup_wns=0.199ns`
- `hold_whs=0.132ns`

Evidence:
- `F:\codex\output\bilateral_timing_20260420_r3\result.txt`
- `F:\codex\output\bilateral_timing_20260420_r3\timing_summary.txt`
- `F:\codex\output\bilateral_timing_20260420_r3\timing_paths.txt`

Implementation note:
- The current passing version already includes pipeline restructuring and a dedicated divider pipeline.
- If anyone edits the arithmetic path, re-run `138.5MHz` signoff.
