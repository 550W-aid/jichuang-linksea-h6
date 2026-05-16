# SD Card Memory

## Current Conclusion

For this board, the SD card should be used in SPI mode as a large static repository.

We are no longer treating native SD 4-bit as the main delivery route.

## Why Native SD 4-bit Was Dropped

The board schematic shows that the TF socket bus is shared with `FT232HQ`.

Shared signals:

- `SD_CLK`
- `SD_CMD`
- `SD_D0`
- `SD_D1`
- `SD_D2`
- `SD_D3`

This board-level sharing is the main reason native SD 4-bit stayed stuck at `CMD8`.

Practical result:

- SPI mode works on real hardware
- native SD 4-bit repeatedly fails during early command response

## Working Project Baseline

Main SPI baseline:

- `F:\\sd_table_repo_4bit_loader_v1`

Native SD debug branch:

- `F:\\sd_table_repo_native4_v1`

Do not use the native branch as the delivery baseline.

## Current SPI Milestones

Already verified on board:

- `CMD0`
- `CMD8`
- `CMD55`
- `ACMD41`
- `CMD58`
- `CMD17`

This means:

- card init works
- OCR read works
- single-block read works
- repository-header probing works

## Current SPI Clocking

Current design uses two SPI speeds:

- init phase: about `195.3125 kHz`
- transfer phase: about `12.5 MHz`

This is the current safe fast version.

## Repository Format

Host packer:

- `F:\\codex\\tools\\sd_repo_pack.py`

Format:

- header magic: `H6SDREP0`
- default header LBA: `2048`
- header size: `512 bytes`
- directory entry size: `64 bytes`
- payload alignment: `4096 bytes`

Supported content:

- lookup tables
- algorithm parameters
- model weights
- metadata

Supported destination types:

- `BRAM`
- `SDRAM`

## What SD Should Be Used For

Suitable:

- rotation lookup tables
- bilateral filter parameters
- `gamma/log/LUT`
- calibration tables
- CNN weights
- algorithm profiles

Not suitable as main purpose:

- real-time frame buffer replacement
- direct pixel-stream memory
- frame-by-frame video source

## Recommended Architecture

Recommended path:

- `TF(SPI) -> repository loader -> BRAM/SDRAM -> algorithm`

Not recommended:

- `TF -> algorithm datapath directly`

## Recommended Control Strategy

Best practical strategy:

- load static tables at startup
- keep them resident in `BRAM` or `SDRAM`
- reload only when switching algorithm or profile

This keeps SD traffic away from the hard real-time video path.

## Current Host Tools

Key files:

- `F:\\codex\\tools\\sd_repo_pack.py`
- `F:\\codex\\tools\\sd_repo_write.py`

These already support:

- repository image generation
- fixed `header_lba`
- segmented objects
- safe write flow

## Next Engineering Direction

The next useful work is:

1. keep SPI as the official SD route
2. add generic repository directory parsing in FPGA
3. add object lookup by `object_id`
4. add segmented payload loading
5. write payloads into `BRAM/SDRAM`
6. let later algorithms reuse the same loader

## Final Decision

The SD card is now treated as:

- a large static asset repository
- a startup / mode-switch loader source
- a support module for later algorithms

This is the practical and stable direction for the current project.
