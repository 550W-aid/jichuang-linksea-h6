# Retinex Low-Light Handoff 2026-05-02

## Scope

- Git branch for this note:
  `dev/person-3`
- Active FPGA WIP project:
  `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501`
- Reference project kept for comparison only:
  `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63`
- Important rule:
  all Retinex / low-light work in this pass was kept in the `63_retinex_port_wip_20260501`
  copy; `63` should remain the reference baseline.

## What is done

- Retinex low-light enhancement path has been integrated into the WIP project.
- The Retinex algorithm is split into dedicated source files under:
  `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501\ov5640_hdmi_1080p.srcs\sources_1\retinex`
- Current Retinex module set:
  - `retinex_rgb888_stream_top.v`
  - `retinex_core.v`
  - `retinex_gaussian_5x5.v`
  - `retinex_gain_divider.v`
  - `retinex_log2_approx.v`
  - `retinex_log_wrapper.v`
  - `retinex_output_stage.v`
  - `retinex_stream_delay.v`
  - `retinex_weighted_sum3_u8.v`
  - `retinex_capture_bridge.v`
- FPGA-side control register wrapper is present in:
  `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501\ov5640_hdmi_1080p.srcs\sources_1\algo_control_regs.v`
- FPGA-side serial command parser is:
  `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501\ov5640_hdmi_1080p.srcs\sources_1\uart_algo_ctrl.v`

## Display corruption fix

- Symptom before fix:
  severe center block / striping / split-screen corruption after inserting the
  Retinex path.
- Root-cause fix file:
  `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501\ov5640_hdmi_1080p.srcs\sources_1\retinex\retinex_capture_bridge.v`
- Effective change:
  output-side left/right split selection is now tracked by emitted pixel count
  aligned to `m_sof`, instead of depending on the internal `m_eol` sideband.
- Additional safety:
  `write_right_o` is gated with `retinex_m_valid_w`.
- Board result after this fix:
  live image returned to normal; the last board-side user feedback for this
  build was that the picture is now fully normal.

## Build, implementation, and programming status

- Preferred local flow:
  use local eLinx tools and `elinx-helper` first.
- Known synthesis blocker in pure native eLinx synth:
  `ERROR: Current [Optimization Technique] mode does not support FIFO.`
- Practical workaround used in this pass:
  helper-compatible synthesis fallback, then local eLinx route / pack / bitgen.
- Route recovery:
  a custom fast-route TCL was used to recover timing after the slow/default route
  path gave poor slack.
- Fast-route TCL:
  `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501\codex_run_route.tcl`
- Bitgen helper TCLs:
  `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501\codex_run_pack.tcl`
  `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501\codex_run_bitgen.tcl`
- Latest generated programmable file:
  `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501\ov5640_hdmi_1080p.runs\imple_1\ov5640_hdmi_1080p.jpsk`
- Latest `jpsk` timestamp:
  `2026-05-01 23:30:57`
- Programming tool used on this workstation:
  `D:\eLinx\eLinx3.0\bin\shell\bin\Programmer_core.exe`
- Last successful programming result in this pass:
  `Successful: (No_11)JTAG down FPGA successful.`

## Current timing and utilization

- Constraint file:
  `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501\ov5640_hdmi_1080p.sdc`
- Current OV5640 pixel clock constraint:
  `create_clock -name ov5640_pclk -period 14.286`
- Interpretation:
  `ov5640_pclk` is currently constrained as `70 MHz`.
- Current route timing report:
  `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501\ov5640_hdmi_1080p.runs\imple_1\ov5640_hdmi_1080p.slack.rpt`
- Current placed utilization report:
  `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501\ov5640_hdmi_1080p.runs\imple_1\ov5640_hdmi_1080p_utilization_placed.rpt`
- Current route summary:
  - `sys_clk Fmax = 71.979 MHz`
  - `ov5640_pclk Fmax = 85.310 MHz`
  - `all_path_min_slack = -0.101 ns`
- Current utilization summary:
  - `LUTs = 5555 / 136160 (4%)`
  - `FFs = 3064 / 136160 (2%)`
  - `Memorys = 36 / 1200 (3%)`
  - `DSPs = 2 / 48 (4%)`
  - `PLLs = 2 / 8 (25%)`
- Current honest statement:
  routed design is usable for board validation and has already produced a normal
  picture on hardware, but there is still a small remaining routed min-slack
  issue to clean up later.

## Host GUI integration

- Host GUI root:
  `D:\Work\FPGA\eLinx\ccic_host_gui`
- Main GUI file changed:
  `D:\Work\FPGA\eLinx\ccic_host_gui\app\main_window.py`
- User-facing protocol note updated in:
  `D:\Work\FPGA\eLinx\ccic_host_gui\README.md`
- Current Retinex serial commands:
  - `Z<n>` zoom-out / resize level
  - `X<n>` zoom-in / crop level
  - `H<n>` pan-x
  - `V<n>` pan-y
  - `L<n>` Retinex strength
- GUI integration updates in this pass:
  - `retinex.level` now maps to FPGA serial `L<n>`
  - old `lowlight.*` aliases remain supported
  - quick presets added for `0 / 32 / 64 / 96 / 128`
  - lowlight detail text is shown by strength range
  - serial port ranking prefers `COM15` / `COM16`
- Recommended board tuning sweep:
  `L0`, `L32`, `L64`, `L96`, `L128`

## Evidence files

- FPGA implementation directory:
  `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501\ov5640_hdmi_1080p.runs\imple_1`
- Key reports:
  - `ov5640_hdmi_1080p.slack.rpt`
  - `ov5640_hdmi_1080p_route_status.rpt`
  - `ov5640_hdmi_1080p_utilization_placed.rpt`
- Bitstream/package artifacts:
  - `ov5640_hdmi_1080p.jpsk`
  - `ov5640_hdmi_1080p.psk`
  - `ov5640_hdmi_1080p_comp.psk`

## Recommended next work

1. Use the host GUI to sweep `L0 / L32 / L64 / L96 / L128` on hardware and
   capture side-by-side image results.
2. After image quality is acceptable, close the remaining small
   `all_path_min_slack = -0.101 ns` issue.
3. Keep using the WIP copy for further Retinex tuning; do not edit the `63`
   reference project directly.
4. If this work needs to be shared in source form later, sync the external WIP
   project and the host GUI updates into a versioned delivery tree instead of
   relying only on workstation-local paths.
