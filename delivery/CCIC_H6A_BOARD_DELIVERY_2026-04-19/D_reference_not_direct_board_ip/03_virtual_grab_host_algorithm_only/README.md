# Virtual Grab Host Algorithm Only

## Scope

This folder contains only the virtual-item-grab algorithm body and the host-side application-layer packet interface.

Included here:

- color detection and blob center extraction
- one-shot calibration packet path
- runtime hand-center reporting path
- hidden button event capture for `grab` / `release`
- byte-stream application-layer packet parser and packet generator

Not included here:

- UART PHY / UART top-level wiring
- Ethernet MAC / UDP / TCP transport
- board pin constraints
- camera capture chain
- SDRAM / frame buffer integration
- full-board timing signoff

This means the folder is intended for teammate-side communication integration, not direct board drop-in use.

## Main RTL

- `virtual_grab_detect_top.v`
  color threshold + blob center extraction for white / green / red / blue targets

- `virtual_grab_host_if.v`
  host-facing control state, packet scheduling, frame counter, button event latching

- `virtual_grab_host_bridge_top.v`
  bridge from pixel-stream detection outputs into the host interface

- `virtual_grab_cmd_rx.v`
  fixed packet parser for `CALIBRATE_REQ / START_REQ / STOP_REQ`

- `virtual_grab_packet_tx.v`
  serializer for `CALIBRATE_RSP / HAND_REPORT / STATUS_RSP`

- `virtual_grab_button_event.v`
  debounced hidden-button pulse generator

## Packet Boundary

This algorithm exports a byte-stream application layer:

- input: `rx_valid`, `rx_data`
- output: `tx_valid`, `tx_data`, `tx_last`, `tx_ready`

Teammates should connect this boundary to:

- UART RX/TX wrapper
- or Ethernet-side packetizer / depacketizer

Do not rewrite the algorithm core just to change transport.

## Command Packets

- `0x10` `CALIBRATE_REQ`
- `0x11` `START_REQ`
- `0x12` `STOP_REQ`

Format:

```text
55 AA <msg_type> <length> <payload...> <checksum>
```

Current commands use `length = 0`.

## Response Packets

- `0x20` `CALIBRATE_RSP`
- `0x21` `HAND_REPORT`
- `0x22` `STATUS_RSP`

## Integration Notes For Teammates

1. Connect camera/capture pipeline output to `virtual_grab_host_bridge_top`.
2. Connect your own UART or Ethernet byte stream to `rx_valid/rx_data` and `tx_valid/tx_data/tx_last/tx_ready`.
3. Expose two hidden physical buttons to:
   - `grab_btn_raw`
   - `release_btn_raw`
4. Keep transport outside this folder. The current files are the algorithm body only.

## Verification Status

- `tb_virtual_grab_detect_top.v` exists for the legacy detector path
- `tb_virtual_grab_host_if.v` verifies:
  - calibration request/response
  - start/stop command handling
  - hand report generation
  - hidden button event insertion

Vivado xsim regression was run locally on the host-interface bench before handoff.

## Timing Status

No 138.5 MHz full integration timing signoff is claimed for this folder.

Reason:

- communication transport is intentionally not included
- board-level capture and routing are not yet part of this drop

Teammates should perform timing after integrating this algorithm body into their actual board communication path.
