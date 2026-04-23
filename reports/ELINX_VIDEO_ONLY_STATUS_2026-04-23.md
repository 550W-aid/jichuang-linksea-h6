# eLinx Board-Facing Video-Only Status 2026-04-22

## Scope

- Project root:
  `D:\Work\FPGA\eLinx\VideoProc`
- Board-facing top:
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.srcs\sources_1\new\VP_Top.v`
- Board mode in this pass:
  `BOARD_VIDEO_ONLY = 1'b1`
- Intent:
  remove `eth_udp_loop` from the image signoff boundary so the VGA-side
  image-processing path can be checked honestly in the eLinx flow

## Local RTL change

- File changed:
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.srcs\sources_1\new\VP_Top.v`
- Change summary:
  - added a `BOARD_VIDEO_ONLY` localparam
  - wrapped `eth_udp_loop` in a generate block
  - tied Ethernet-facing outputs and status wires to safe constants when
    video-only mode is enabled
  - kept `vga_top` active so the board-facing image path remains present

## Fresh eLinx evidence

- Native pack:
  `D:\eLinx\eLinx3.0\bin\shell\bin\Implementation.exe -f D:\Work\FPGA\eLinx\VideoProc\VideoProcess.runs\synth_1\VideoProcess_pack.tcl -silence`
- Native route:
  `D:\eLinx\eLinx3.0\bin\shell\bin\Implementation.exe -f D:\Work\FPGA\eLinx\VideoProc\VideoProcess.runs\imple_1\VideoProcess_route.tcl -silence`
- Clean Passkey STA:
  `powershell -ExecutionPolicy Bypass -File D:\Work\FPGA\eLinx\VideoProc\scripts\timing\run_elinx_sta_clean.ps1`
- Local setup/hold replay:
  `D:\eLinx\eLinx3.0\bin\Passkey\bin\quartus_sta.exe -t D:\Work\FPGA\eLinx\VideoProc\VideoProcess.srcs\sources_1\new\DELIV\tools\elinx\video_only_setup_hold_20260422.tcl`

## Result

- Board-facing image signoff boundary:
  `PASS`
- Overall setup:
  `WNS = +6.620 ns`
- Overall hold:
  `WHS = +1.226 ns`
- Total negative slack:
  `TNS = 0.000 ns`
- Total hold slack:
  `THS = 0.000 ns`
- Route-side summary:
  `ClockName = sys_clk_in, ClockFmax = 102.934 MHz, WNS/WHS/TNS/THS = 0/0/0/0`

## Key path boundary after video-only isolation

- Overall worst setup path is no longer the old `eth_rxc` receive cone.
- The intermediate `125 MHz` monitor-only path was also removed by holding the
  Ethernet monitor registers at constants in `BOARD_VIDEO_ONLY` mode.
- Current overall worst setup now comes from the `sys_clk` SDRAM control domain:
  - from:
    `sdram_top:u_sdram_top|sdram_control:sdram_control|sdram_ctrl:sdram_ctrl|O_cnt_clk[4]`
  - to:
    `sdram_top:u_sdram_top|sdram_control:sdram_control|sdram_ctrl:sdram_ctrl|O_cnt_clk[2]`
  - launch/latch clock:
    `sys_clk`
- VGA-side image path remains comfortably inside margin:
  - setup:
    `WNS = +11.591 ns`
  - hold:
    `WHS = +1.600 ns`
  - representative path:
    `vga_top:u_vga_top|src_x[*] -> grayscale_stream_std:u_grayscale_stream_std|m_data[*]`

## Honest interpretation

- This pass does not prove the Ethernet feature is signed off.
- This pass does prove the board-facing VGA image chain can be checked in the
  native eLinx flow without the old `eth_udp_loop` negative-slack path
  contaminating the image signoff boundary.
- There are no remaining `125 MHz` setup paths in the clean `PLL_125M` report
  for this mode.
- The overall top limiter has moved to `sys_clk` SDRAM control logic, while the
  VGA image chain still keeps double-digit setup margin.

## Evidence files

- Clean STA report:
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.runs\sta_clean\VideoProcess_postmap_sta_clean.rpt`
- Local setup/hold report:
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.srcs\sources_1\new\DELIV\docs\ELINX_VIDEO_ONLY_SETUP_HOLD_2026-04-22.txt`
- Route artifacts:
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.runs\imple_1\VideoProcess.edi`
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.runs\imple_1\VideoProcess.slack.rpt`

## Next action

1. Keep `BOARD_VIDEO_ONLY` as the board-facing image signoff mode until the
   Ethernet workstream is intentionally reintroduced.
2. If Ethernet must coexist in the same top again, attack the remaining
   `125 MHz` non-image logic separately instead of letting it define the image
   delivery boundary.

## Update 2026-04-22 20:50 HKT

### Why this update exists

- The integrated root project now defaults back to mixed-feature behavior:
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.srcs\sources_1\new\VP_Top.v`
  keeps `BOARD_VIDEO_ONLY = 1'b0` unless the macro is defined.
- A direct `quartus_map --verilog_macro=CODEX_BOARD_VIDEO_ONLY` attempt did not
  produce an honest eth-free synthesized netlist in the root project, so the
  board-facing image signoff path was rebuilt as a standalone custom project
  under the writable delivery area instead of forcing the default integration top.

### Standalone custom project boundary

- Custom project root:
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.srcs\sources_1\new\DELIV\elinx_video_only_project`
- Wrapper top file:
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.srcs\sources_1\new\VP_Top_board_video_only.v`
- Custom project generator:
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.srcs\sources_1\new\DELIV\tools\elinx\setup_video_only_project.ps1`
- Quartus clean-STA helper:
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.srcs\sources_1\new\DELIV\tools\elinx\run_quartus_sta_clean_generic.ps1`

### Fresh standalone evidence

- Quartus map:
  `quartus_map VideoProcess_video_only -c VideoProcess_video_only`
- Explicit VQM export:
  `quartus_cdb VideoProcess_video_only -c VideoProcess_video_only --netlist_type=map --vqm=.../VideoProcess_video_only.vqm`
- Native pack:
  `Implementation.exe -f ...\VideoProcess_video_only.runs\synth_1\VideoProcess_video_only_pack.tcl -silence`
- Native route:
  `Implementation.exe -f ...\VideoProcess_video_only.runs\imple_1\VideoProcess_video_only_route.tcl -silence`

### Result

- Standalone board-facing image boundary:
  `PASS`
- Native route summary:
  `WNS = 0.000 ns`
  `WHS = 0.000 ns`
  `TNS = 0.000 ns`
  `THS = 0.000 ns`
- Reported clock limits:
  `sys_clk Fmax = 309.310 MHz`
  `clk_25m domain Fmax = 25.099 MHz`
  `mdio dri_clk Fmax = 164.908 MHz`
- Smallest routed setup margin:
  `all_path_min_slack = 0.158 ns`

### What changed versus the earlier root-project attempt

- `VideoProcess_video_only.vqm` contains no `g_eth_udp_loop`, `u_eth_udp_loop`,
  `checksum_acc`, or `eth_udp_loop` instance hierarchy.
- The custom VQM also shows SDRAM outputs statically tied off, for example:
  `assign O_sdram_clk = gnd;`
- This means the standalone custom project is now an honest image-only
  board-facing boundary, instead of relying on the earlier root-project macro
  attempt that still left UDP logic inside the synthesized netlist.

### Clean Passkey STA status

- Status:
  `BLOCKED`
- Command:
  `powershell -ExecutionPolicy Bypass -File ...\run_quartus_sta_clean_generic.ps1 -ProjectDir ...\elinx_video_only_project -ProjectName VideoProcess_video_only`
- Tool blocker:
  `quartus_sta` exits before timing evaluation with
  `package "xibiso" isn't loaded statically`
- Raw log:
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.srcs\sources_1\new\DELIV\elinx_video_only_project\VideoProcess_video_only.runs\sta_clean\VideoProcess_video_only_postmap_sta_raw.log`
- Interpretation:
  this is a standalone-tool environment blocker in TimeQuest on the custom
  project, not an RTL timing failure in the image path itself

### Current best honest statement

- eLinx native board-facing route on the standalone image-only project passes.
- The custom synthesized netlist proves `eth_udp_loop` is removed from the
  board-facing image signoff boundary.
- Clean Passkey STA for this standalone project is still blocked by the
  `xibiso` package-load failure, so no new standalone TimeQuest WNS/TNS/WHS/THS
  claim should be made beyond the native eLinx route evidence.

## Update 2026-04-23 19:10 HKT

### Short-path standalone project

- Stable short-path project root:
  `D:\Work\FPGA\eLinx\VideoProc\VideoOnlySTA`
- Wrapper top file:
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.srcs\sources_1\new\VP_Top_board_video_only.v`
- Script default project root now points to this D-drive short path:
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.srcs\sources_1\new\DELIV\tools\elinx\setup_video_only_project.ps1`
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.srcs\sources_1\new\DELIV\tools\elinx\run_elinx_video_only_project.ps1`

### Additional RTL boundary cleanup

- File changed:
  `D:\Work\FPGA\eLinx\VideoProc\VideoProcess.srcs\sources_1\new\VP_Top.v`
- Change summary:
  the Ethernet `GTX_CLK` `altddio_out` clock-forwarding primitive is now only
  instantiated when `BOARD_VIDEO_ONLY == 1'b0`; in the video-only signoff
  boundary `GTX_CLK` is tied low. The Ethernet `mdio_rw_test` management block
  is also excluded from `BOARD_VIDEO_ONLY`; `eth_mdc` is held low and
  `eth_mdio` is released.
- Reason:
  the eLinx packer rejects the Quartus DDIO IO atom generated for the Ethernet
  clock-forwarding pin with:
  `Unsupported case: .ddiodatain port on the I/O element is specified.`
- Boundary proof:
  regenerated `VideoOnlySTA.vqm` has no `g_eth_udp_loop`, no `eth_udp_loop`
  hierarchy, no `mdio_rw_test` / `mdio_dri` hierarchy, and no
  `altddio_out:u_gtx_clk_fwd` / `.ddiodatain` atom.

### Fresh short-path clean STA evidence

- Command:
  `powershell -ExecutionPolicy Bypass -File ...\run_quartus_sta_clean_generic.ps1 -ProjectDir D:\Work\FPGA\eLinx\VideoProc\VideoOnlySTA -ProjectName VideoOnlySTA -Revision VideoOnlySTA -SdcPath D:\Work\FPGA\eLinx\VideoProc\VideoOnlySTA\constraints\VideoOnlySTA_sta_clean.sdc`
- Report:
  `D:\Work\FPGA\eLinx\VideoProc\VideoOnlySTA\VideoOnlySTA.runs\sta_clean\VideoOnlySTA_postmap_sta_clean.rpt`
- Result:
  `PASS`
- Overall setup:
  `WNS = +11.591 ns`, `TNS = 0.000 ns`
- Overall hold:
  `WHS = +1.600 ns`, `THS = 0.000 ns`
- Video 25 MHz setup/hold:
  `WNS = +11.591 ns`, `WHS = +1.600 ns`
- PLL 125 MHz report:
  no setup or hold paths found in this video-only boundary.
- Tool result:
  `quartus_sta` completed with `0 errors, 0 warnings`.

### Fresh short-path native eLinx route evidence

- Native pack log:
  `D:\Work\FPGA\eLinx\VideoProc\VideoOnlySTA\VideoOnlySTA.runs\synth_1\VideoOnlySTA_pack_stdout.log`
- Native route log:
  `D:\Work\FPGA\eLinx\VideoProc\VideoOnlySTA\VideoOnlySTA.runs\imple_1\VideoOnlySTA_route_stdout.log`
- Route slack report:
  `D:\Work\FPGA\eLinx\VideoProc\VideoOnlySTA\VideoOnlySTA.runs\imple_1\VideoOnlySTA.slack.rpt`
- Route status report:
  `D:\Work\FPGA\eLinx\VideoProc\VideoOnlySTA\VideoOnlySTA.runs\imple_1\VideoOnlySTA_route_status.rpt`
- Result:
  `PASS`
- Native route summary:
  `WNS = 0.000 ns`
  `WHS = 0.000 ns`
  `TNS = 0.000 ns`
  `THS = 0.000 ns`
- Reported clock limits:
  `sys_clk Fmax = 330.469 MHz`
  `clk_25m domain Fmax = 25.038 MHz`
- Smallest routed setup margin:
  `all_path_min_slack = 0.061 ns`
- Routing errors:
  `0`

### Updated honest statement

- The short-path standalone video-only project is the preferred eLinx
  board-facing image signoff project.
- The earlier `xibiso` clean STA blocker is classified as a long/deep project
  path or standalone-location issue; it is not present when the same boundary is
  built at `D:\Work\FPGA\eLinx\VideoProc\VideoOnlySTA`.
- The video-only board-facing image boundary now has both clean Passkey STA and
  native eLinx route evidence. Ethernet and SDRAM remain intentionally outside
  this image signoff boundary.
