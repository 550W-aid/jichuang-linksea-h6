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

```powershell
cd F:\codex\tools\ccic_host_gui
python -m pip install -r requirements.txt
python main.py
```

## Protocol Notes

Because FPGA-side protocol may differ by team implementation, V1 provides two modes:

1. `Raw`
   - send payload directly.
2. `CCICv1`
   - packet = `magic(4) + type(1) + seq(4, LE) + len(4, LE) + payload`
   - magic: `CCIC`

Image/video default uses chunked UDP transport in order to reduce large-packet drop risk.

## Files

- `main.py`: app entry
- `app/main_window.py`: main UI
- `app/workers.py`: serial/ethernet/video background workers
- `app/protocol.py`: packet and chunk helpers
- `app/styles.py`: UI stylesheet
