# Timing Status: 06_guided_filter

Status:
- `PASS`
- Cleared for `138.5MHz` handoff under OOC timing signoff

Top RTL:
- `rtl/guided_filter_3x3_stream_std.v`

Signed-off result:
- `setup_wns=0.165ns`
- `hold_whs=0.132ns`

Evidence:
- `F:\codex\output\guided_timing_20260420_r2\result.txt`
- `F:\codex\output\guided_timing_20260420_r2\timing_summary.txt`
- `F:\codex\output\guided_timing_20260420_r2\timing_paths.txt`

Implementation note:
- The current passing version depends on the pipeline split already added to the arithmetic core.
- If anyone edits the datapath depth, re-run `138.5MHz` signoff.
