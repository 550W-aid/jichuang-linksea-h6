# Timing Status: 02_binary_morphology_chain

Status:
- `PASS`
- Fresh local timing evidence exists for two consuming tops
- Signed off only for the tested single-lane boundary below

Consuming tops used for signoff:
- `rtl/gray_threshold_erode_chain_top.v`
- `rtl/gray_threshold_dilate_chain_top.v`

Target:
- Device: `xc7z020clg400-1`
- Clock: `138.5MHz`
- Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`
- Tool used for this fresh local evidence: `Vivado 2018.3 OOC synth/place/route`

Signoff boundary:
- Single-lane consuming tops only: `MAX_LANES=1`, `IMG_WIDTH=640`, `IMG_HEIGHT=480`
- This is a promoted-chain signoff, not a blanket multi-lane signoff

Results:

| Module | Top RTL | PASS/FAIL | WNS | TNS | WHS | THS |
| --- | --- | --- | --- | --- | --- | --- |
| `binary_threshold_stream_std + erode3x3_binary_stream_std` | `rtl/gray_threshold_erode_chain_top.v` | `PASS` | `0.230ns` | `0.000ns` | `0.191ns` | `0.000ns` |
| `binary_threshold_stream_std + dilate3x3_binary_stream_std` | `rtl/gray_threshold_dilate_chain_top.v` | `PASS` | `0.131ns` | `0.000ns` | `0.158ns` | `0.000ns` |

Report path:
- Erode:
- `timing_runs/gray_threshold_erode/timing_summary.rpt`
- `timing_runs/gray_threshold_erode/timing_setup.rpt`
- Dilate:
- `timing_runs/gray_threshold_dilate/timing_summary.rpt`
- `timing_runs/gray_threshold_dilate/timing_setup.rpt`

Next action:
1. Keep the current signoff label tied to the tested single-lane boundary.
2. If multi-lane promotion is needed later, re-run fresh signoff for that exact boundary.
