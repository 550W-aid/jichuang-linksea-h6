# Timing Status: 03_fixed_angle_rotate

Status:
- `PASS`
- `FRAME-BUFFER ASSISTED`, not pure video stream
- Fresh local timing evidence clears this module for the tested `138.5MHz` boundary below

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
- `WNS=0.287ns`
- `TNS=0.000ns`
- `WHS=0.132ns`
- `THS=0.000ns`

Report path:
- `timing_runs/fixed_angle_rotate/timing_summary.rpt`
- `timing_runs/fixed_angle_rotate/timing_setup.rpt`
- `timing_runs/fixed_angle_rotate/timing_hold.rpt`
- `timing_runs/fixed_angle_rotate/utilization.rpt`

Closure note:
- The previous `address generation` and `control latency alignment` failures were removed by:
- adding a registered request/issue boundary ahead of `fixed_angle_rotate_addr_pipe`
- moving output raster-walker advancement to request load time
- narrowing capture/address/control intermediates to explicit widths instead of broad `integer` arithmetic

Next action:
1. Keep the module labeled as `frame-buffer assisted` in integration notes.
2. Re-run timing if the consuming boundary changes from this exact OOC top or if the memory seam contract changes.
