# CCIC Host GUI Handoff 2026-05-02

## Scope

- Git branch for this handoff note:
  `dev/person-3`
- Host GUI local project root:
  `D:\Work\FPGA\eLinx\ccic_host_gui`
- Important boundary:
  the host GUI source itself is currently not stored inside this git repo.
  This branch only carries the handoff note for the current workstation copy and
  its FPGA integration behavior.

## Current local project layout

- App entry:
  `D:\Work\FPGA\eLinx\ccic_host_gui\main.py`
- Main window and most integration logic:
  `D:\Work\FPGA\eLinx\ccic_host_gui\app\main_window.py`
- Background workers:
  `D:\Work\FPGA\eLinx\ccic_host_gui\app\workers.py`
- Packet helpers:
  `D:\Work\FPGA\eLinx\ccic_host_gui\app\protocol.py`
- UI stylesheet:
  `D:\Work\FPGA\eLinx\ccic_host_gui\app\styles.py`
- Local project README:
  `D:\Work\FPGA\eLinx\ccic_host_gui\README.md`
- Launch helper:
  `D:\Work\FPGA\eLinx\ccic_host_gui\run_gui.ps1`
- Dependencies:
  `D:\Work\FPGA\eLinx\ccic_host_gui\requirements.txt`

## What changed in this pass

- File changed for the FPGA integration:
  `D:\Work\FPGA\eLinx\ccic_host_gui\app\main_window.py`
- File changed for local project notes:
  `D:\Work\FPGA\eLinx\ccic_host_gui\README.md`
- Main functional updates:
  - added `retinex.level` alias support
  - kept old `lowlight.*` aliases working
  - added low-light presets `0 / 32 / 64 / 96 / 128`
  - added clearer low-light strength status text
  - added serial-port preference for `COM15` and `COM16`
  - connected GUI low-light control to compact FPGA serial command `L<n>`

## Current FPGA-side protocol contract

The current FPGA integration target is:

- `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501`

For this Retinex build, the GUI should treat serial mode as the primary live-tuning
path. The current compact ASCII command set is:

- `Z0` .. `Z255`
  - zoom-out / resize level
- `X0` .. `X255`
  - zoom-in / crop level
- `H0` .. `H255`
  - pan X
- `V0` .. `V255`
  - pan Y
- `L0` .. `L255`
  - Retinex low-light enhancement strength

GUI-side mapping currently expected by the board:

- `resize.scale`
- `resize.level`
- `resize.zoom`
  - emit `Z<n>` and clear `X`
- `zoom_in.level`
- `zoom_in.scale`
- `zoom_in.zoom`
  - emit `X<n>` and clear `Z`
- `view.pan_x`
  - emit `H<n>`
- `view.pan_y`
  - emit `V<n>`
- `lowlight.gain`
- `lowlight.offset`
- `lowlight.strength`
- `retinex.level`
  - all map to `L<n>`

## Recommended bring-up flow for the next owner

1. Enter:
   `D:\Work\FPGA\eLinx\ccic_host_gui`
2. If `.venv` is missing, create it and install:
   - `PySide6>=6.7.0`
   - `pyserial>=3.5`
   - `opencv-python>=4.8.0`
3. Launch with:
   `.\run_gui.ps1`
4. Connect the serial port first.
5. Prefer `COM15` or `COM16` if both are present.
6. Set packet mode to raw serial command usage for board tuning.
7. Use Retinex presets in this order:
   `L0`, `L32`, `L64`, `L96`, `L128`
8. Capture side-by-side board images while changing only one level at a time.

## Validation status from this pass

- Static validation completed:
  - `main.py`
  - `app/main_window.py`
  - `app/workers.py`
  all passed `py_compile`
- GUI source update completed:
  local code and README both reflect the current Retinex serial contract
- Hardware-side live image status after the paired FPGA fix:
  the user later confirmed the board picture became fully normal
- Important limitation:
  in this pass the GUI was not re-run through a full click-by-click desktop test
  after the final FPGA image normalization result

## Important operational notes

- The host GUI README already documents the current Retinex protocol, but until
  this note was added there was no dedicated handoff file inside git for another
  person to follow.
- This repo still does not contain the actual `ccic_host_gui` source tree.
  Anyone taking over from git alone will still need the workstation path above
  or a later source sync into version control.
- If the team wants true handoff safety, the next step should be to version the
  whole `ccic_host_gui` project instead of only documenting the local copy.

## Minimum read order for a new owner

1. This handoff note
2. `D:\Work\FPGA\eLinx\ccic_host_gui\README.md`
3. `D:\Work\FPGA\eLinx\ccic_host_gui\app\main_window.py`
4. FPGA-side UART command parsing:
   `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501\ov5640_hdmi_1080p.srcs\sources_1\uart_algo_ctrl.v`
5. FPGA-side control register wrapper:
   `D:\Work\FPGA\eLinx\ov5640_hdmi_2_compare_20260428_211959\63_retinex_port_wip_20260501\ov5640_hdmi_1080p.srcs\sources_1\algo_control_regs.v`

## Honest next step

- Keep this note in git as the handoff entry.
- If the host GUI will continue evolving, sync the real `ccic_host_gui` source
  tree into a versioned repo branch so future owners do not depend on a local
  workstation path.
