# Last Good 1024x600 Triple-Buffer Backup

This backup rewrites the last verified-good 1024x600 camera-to-HDMI version without changing the current main project.

## Version

- Resolution: 1024x600
- Pixel clock path: 50 MHz `sys_clk`
- HDMI timing: 1344 x 625 total, about 59.52 Hz
- SDRAM burst length: 256 words
- Buffering: triple buffering
- SDRAM frame bases:
  - Buffer 0: `24'h000000`
  - Buffer 1: `24'h400000`
  - Buffer 2: `24'h800000`

## Key Source

```text
hdmi_sdram_1024x600_60Hz.srcs/sources_1/TOP1.v
```

The rebuilt `TOP1.v` is based on the clean 256-burst single-buffer backup, then restores the verified triple-buffer bank-separated frame switching logic.

## Generated Bitstreams

Bitgen has been run for this backup copy.

```text
hdmi_sdram_1024x600_60Hz.runs/imple_1/hdmi_sdram_1024x600_60Hz.psk
hdmi_sdram_1024x600_60Hz.runs/imple_1/hdmi_sdram_1024x600_60Hz_comp.psk
```

## Verification

Helper compile/implementation completed on this backup copy with:

```text
0 errors, 33 warnings
3390 logic cells
32 RAM segments
```

Helper bitgen completed and produced `.psk` plus compressed `.psk`.

Note: the copied Quartus `.qsf` had stale absolute paths to the main project. Those paths were updated to this backup directory before the successful compile/bitgen run.
