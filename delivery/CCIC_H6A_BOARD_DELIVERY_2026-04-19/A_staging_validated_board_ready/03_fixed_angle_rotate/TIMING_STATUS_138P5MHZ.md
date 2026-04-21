# Timing Status: 03_fixed_angle_rotate

Status:
- `FAIL`
- `FRAME-BUFFER ASSISTED`, not pure video stream
- Fresh local timing evidence exists, but this module is not `138.5MHz clean`

Top RTL:
- `rtl/fixed_angle_rotate_stream_std.v`
- Supporting RTL: `rtl/fixed_angle_rotate_addr_pipe.v`

Target:
- Device: `xc7z020clg400-1`
- Clock: `138.5MHz`
- Constraint: `create_clock -name clk -period 7.220 [get_ports clk]`
- Tool used for this fresh local evidence: `Vivado 2018.3 OOC synth/place/route`

Signoff boundary:
- External frame-buffer-assisted rotate shell with explicit write/read seam
- OOC parameters used for this run: `MAX_LANES=8`, `IMG_WIDTH=640`, `IMG_HEIGHT=480`, `FB_ADDR_W=32`
- Shared dependency used in the tested top: `C_shared_dependencies/rtl/frame_latched_u2.v`

Result:
- `WNS=-5.028ns`
- `TNS=-605.641ns`
- `WHS=0.146ns`
- `THS=0.000ns`

Report path:
- `timing_runs/fixed_angle_rotate/timing_summary.rpt`
- `timing_runs/fixed_angle_rotate/timing_setup.rpt`
- `timing_runs/fixed_angle_rotate/timing_hold.rpt`
- `timing_runs/fixed_angle_rotate/utilization.rpt`

Current blocker:
- Primary critical-path type: `address generation`
- Secondary pressure: `control latency alignment`
- Worst setup paths are now real timing paths, not synthesis blockers:
- `capture_count_q_reg[*] -> capture_count_q_reg[*]` shows a long carry-chain in capture/write-address progression
- `out_x_q_reg[*] -> u_addr_pipe/stage0_next_out_y_q_reg[*]` shows the output raster walker still feeds too much combinational next-coordinate logic into the address pipe input

Next action:
1. Split capture write-address progression away from the current loop-carried counter update.
2. Insert one more registered issue stage between output raster walking and `fixed_angle_rotate_addr_pipe`.
3. Re-run fresh `138.5MHz` OOC timing after control-latency realignment.
