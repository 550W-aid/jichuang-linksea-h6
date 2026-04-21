# Timing Status: 07_affine_wrapper

Status:
- `FAIL`
- `FRAME-BUFFER ASSISTED`, not pure video stream
- Fresh local timing evidence exists, but this module is not `138.5MHz clean`

Top RTL:
- `rtl/affine_nearest_stream_std.v`
- Supporting RTL: `rtl/affine_nearest_addr_pipe.v`

Target:
- Device: `xc7z020clg400-1`
- Clock: `138.5MHz`
- Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`
- Tool used for this fresh local evidence: `Vivado 2018.3 OOC synth/place/route`

Signoff boundary:
- External frame-buffer-assisted affine shell with explicit write/read seam
- OOC parameters used for this run: `MAX_LANES=1`, `IMG_WIDTH=1024`, `IMG_HEIGHT=768`, `FB_ADDR_W=32`
- Shared dependency used in the tested top: `C_shared_dependencies/rtl/frame_latched_affine6_s16.v`

Result:
- `WNS=-2.760ns`
- `TNS=-175.336ns`
- `WHS=0.161ns`
- `THS=0.000ns`

Report path:
- `timing_runs/affine_nearest/timing_summary.rpt`
- `timing_runs/affine_nearest/timing_setup.rpt`
- `timing_runs/affine_nearest/timing_hold.rpt`
- `timing_runs/affine_nearest/utilization.rpt`

Current blocker:
- Primary critical-path type: `coordinate math`
- Secondary pressure: `address generation`
- Worst setup paths are concentrated on the affine request side:
- `out_x_q_reg[*] -> u_addr_pipe/stage0_next_out_y_q_reg[*]`
- The current raster-walk metadata still drives too much next-coordinate and affine request preparation in one cycle before the address pipe register boundary

Next action:
1. Add a registered affine-request issue stage between the output raster walker and `affine_nearest_addr_pipe`.
2. Keep coordinate transform stages split from final read-address issue logic.
3. Re-run fresh `138.5MHz` OOC timing after the request-side latency contract is tightened.
