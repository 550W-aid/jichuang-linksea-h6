# CCIC Host GUI (PySide6)

Upper-computer software for CCIC FPGA image-processing demo.

## Features (V1)

- Serial port send/receive (`pyserial`)
- Ethernet send/receive (UDP)
- Single image send over Ethernet
- Real-time video stream send over Ethernet (camera or file)
- Algorithm parameter panel with:
  - direct value send
  - range sweep (`start/end/step/interval`)
- Packet mode switch:
  - `Raw`
  - `CCICv1` framed packet
- Modern UI theme for contest demo / judge presentation

## Quick Start

### First-time setup

```powershell
cd C:\Users\Fangr\OneDrive\Desktop\ccic_host_gui
python -m venv .venv
.\.venv\Scripts\python -m pip install -U pip setuptools wheel
.\.venv\Scripts\python -m pip install -r requirements.txt
```

### Launch

```powershell
cd C:\Users\Fangr\OneDrive\Desktop\ccic_host_gui
.\run_gui.ps1
```

Or double-click:

```text
run_gui.bat
```

## Protocol Notes

Because FPGA-side protocol may differ by team implementation, V1 provides two modes:

1. `Raw`
   - send payload directly.
2. `CCICv1`
   - packet = `magic(4) + type(1) + seq(4, LE) + len(4, LE) + payload`
   - magic: `CCIC`

Image/video default uses chunked UDP transport in order to reduce large-packet drop risk.

## Current FPGA Integration

For the current `02` FPGA build, serial control is connected with a lightweight ASCII command set:

- `Z0` .. `Z3`
  - set resize / zoom level
- `L0` .. `L255`
  - set low-light offset
  - `L0` disables low-light enhancement

The GUI has been adjusted so that, when algorithm commands are sent through the serial channel for:

- `resize.scale`
- `resize.level`
- `resize.zoom`
- `lowlight.gain`
- `lowlight.offset`
- `lowlight.strength`

it automatically emits the compact FPGA serial commands above instead of JSON/CSV payloads.

The GUI also provides real-time sliders for:

- `resize.scale`
- `lowlight.gain`

Notes:

- `lowlight.gain` is linearly adjustable in the GUI (`0` .. `255`)
- current `resize.scale` is exposed as a slider UI, but the present FPGA build still uses 4 discrete zoom levels (`0` .. `3`)

## Files

- `main.py`: app entry
- `app/main_window.py`: main UI
- `app/workers.py`: serial/ethernet/video background workers
- `app/protocol.py`: packet and chunk helpers
- `app/styles.py`: UI stylesheet
