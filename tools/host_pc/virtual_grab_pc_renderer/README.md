# Virtual Grab PC Renderer

## Scope

This folder contains the host-side virtual-item-grab renderer and protocol helpers.

It is the PC-side visualization half of the virtual-grab demo:

- receives 2D coordinates from FPGA or replay source
- maps them into a virtual scene
- renders the hand and virtual cylinder interaction

This folder is host software, not FPGA board RTL.

## Main Files

- `src/main.py`
  renderer entry point

- `src/input_protocol.py`
  line-based frame parsing

- `src/frame_source.py`
  demo / JSONL / TCP / serial frame source selection

- `src/renderer.py`
  Tkinter-based scene rendering

- `src/grab_animation.py`
  host-side grab animation logic

## Supported Inputs

- `demo`
- `jsonl`
- `tcp`
- `serial`

The protocol description is in [PROTOCOL.md](/C:/Users/a2945/Desktop/jichuang-linksea-h6/tools/host_pc/virtual_grab_pc_renderer/PROTOCOL.md).

Sample replay data is in [sample_frames.jsonl](/C:/Users/a2945/Desktop/jichuang-linksea-h6/tools/host_pc/virtual_grab_pc_renderer/sample_frames.jsonl).

## Run Examples

From this folder:

```powershell
python .\src\main.py --input demo
```

```powershell
python .\src\main.py --input jsonl --jsonl-path .\sample_frames.jsonl
```

```powershell
python .\src\main.py --input tcp --tcp-port 9000
```

```powershell
python .\src\main.py --input serial --serial-port COM3 --serial-baud 115200
```

## MATLAB Helpers

MATLAB-side helpers are included in [matlab](/C:/Users/a2945/Desktop/jichuang-linksea-h6/tools/host_pc/virtual_grab_pc_renderer/matlab):

- `start_renderer_tcp.m`
- `send_demo_frames_tcp.m`
- `serial_to_tcp_bridge.m`

These are useful if a teammate wants MATLAB to bridge serial data into the renderer TCP input.

## Tests

Python tests are included in [tests](/C:/Users/a2945/Desktop/jichuang-linksea-h6/tools/host_pc/virtual_grab_pc_renderer/tests).

They were copied from the local working renderer project for teammate-side reuse.

## Integration Relation To FPGA Side

The matching FPGA-side algorithm handoff is in:

[03_virtual_grab_host_algorithm_only](/C:/Users/a2945/Desktop/jichuang-linksea-h6/delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/D_reference_not_direct_board_ip/03_virtual_grab_host_algorithm_only)

Recommended teammate split:

- FPGA teammate:
  integrate UART or Ethernet transport around the algorithm byte-stream interface

- Host teammate:
  run or adapt this renderer and connect it to the selected transport
