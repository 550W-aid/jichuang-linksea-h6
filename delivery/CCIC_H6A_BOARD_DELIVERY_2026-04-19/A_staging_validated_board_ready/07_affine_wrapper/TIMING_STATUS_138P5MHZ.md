# Timing Status: 07_affine_wrapper

Status:
- `PASS`
- `FRAME-BUFFER ASSISTED`, not pure video stream
- Fresh local timing evidence clears this module for the tested `138.5MHz` boundary below

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
- `WNS=0.585ns`
- `TNS=0.000ns`
- `WHS=0.159ns`
- `THS=0.000ns`

Report path:
- `timing_runs/affine_nearest/timing_summary.rpt`
- `timing_runs/affine_nearest/timing_setup.rpt`
- `timing_runs/affine_nearest/timing_hold.rpt`
- `timing_runs/affine_nearest/utilization.rpt`

Closure note:
- The previous `coordinate math` and request-side `address generation` failures were removed by:
- adding a registered affine request/issue boundary ahead of `affine_nearest_addr_pipe`
- moving raster-walker advancement to request load time
- narrowing capture/address/control intermediates to explicit widths instead of broad `integer` arithmetic

Next action:
1. Keep the module labeled as `frame-buffer assisted` in integration notes.
2. Re-run timing if the consuming boundary changes from this exact OOC top or if the memory seam contract changes.
