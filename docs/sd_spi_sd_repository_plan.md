# SPI-SD Repository Plan

## 1. Current Decision

We will use the TF card in SPI mode as a large static data repository.

This is the chosen engineering direction because:

- the board has already verified SPI init and block-read on real hardware
- native SD 4-bit is blocked by board-level bus sharing with FT232HQ
- the target use case is mainly large table / parameter / weight storage
- this use case does not require SD native 4-bit bandwidth

## 2. Board Facts

### 2.1 TF Bus Sharing

On the baseboard schematic, the following signals are shared:

- `SD_CLK`
- `SD_CMD`
- `SD_D0`
- `SD_D1`
- `SD_D2`
- `SD_D3`

These signals connect to both:

- `CARD1` TF socket
- `FT232HQ`

This is the main reason native SD mode is high risk on this board.

### 2.2 Practical Consequence

- SPI mode works and is already board-proven
- native SD 4-bit repeatedly fails at `CMD8`
- continuing to push native SD is not the best use of project time

## 3. Current Working Project

Primary SPI baseline:

- `F:\sd_table_repo_4bit_loader_v1`

Native SD debug branch:

- `F:\sd_table_repo_native4_v1`

Only the SPI project should be treated as the delivery baseline for SD repository work.

## 4. Current SPI Capability

The SPI path has already verified:

1. `CMD0`
2. `CMD8`
3. `CMD55`
4. `ACMD41`
5. `CMD58`
6. `CMD17`

Board-proven milestones:

- card leaves idle successfully
- OCR can be read successfully
- single-block read completes successfully
- repository header probe at fixed LBA is working

Current transfer-rate structure:

- init phase: about `195.3125 kHz`
- transfer phase: about `12.5 MHz`

This comes from:

- `sys_clk = 50 MHz`
- init divider half-period `128`
- transfer divider half-period `2`

## 5. Repository Format

Host tool:

- `F:\codex\tools\sd_repo_pack.py`

Current repository format:

- header magic: `H6SDREP0`
- default header LBA: `2048`
- header size: `512 bytes`
- directory entry size: `64 bytes`
- payload alignment: `4096 bytes`

Supported object metadata:

- `object_id`
- `object_type`
- `dst_kind`
- `load_flags`
- `segment_index`
- `segment_count`
- `start_lba`
- `sector_count`
- `byte_len`
- `dst_addr`
- `crc32`
- `name`

Supported object types:

- `LUT`
- `PARAM`
- `MODEL_WEIGHT`
- `META`

Supported destination kinds:

- `BRAM`
- `SDRAM`

## 6. Recommended Use Cases

Suitable data to store on TF card:

- rotation lookup tables
- bilateral filter parameters
- gamma / log / inverse-log tables
- piecewise correction tables
- calibration parameter blocks
- CNN weights
- multi-version algorithm parameter sets

Not recommended as the main use case:

- direct real-time video frame source
- frame-by-frame streaming into real-time rotation path
- latency-critical per-frame dynamic random access

## 7. Recommended System Role of SD

The TF card should be treated as:

- a large cold-storage repository
- a startup or mode-switch loader source
- a versioned algorithm asset container

The TF card should not be treated as:

- a replacement for line buffers
- a replacement for frame buffers
- a direct high-rate real-time image processing memory

## 8. Suggested FPGA Architecture

Recommended data path:

1. host packs repository image
2. TF card stores repository image
3. FPGA boot or mode-switch logic reads repository directory
4. FPGA finds object by `object_id`
5. FPGA loads object payload by segment
6. payload is copied into:
   - `BRAM` for small hot tables
   - `SDRAM` for large tables / weights
7. algorithm module reads from BRAM/SDRAM locally

This keeps SD access off the hard real-time pixel critical path.

## 9. Recommended Loader Interface

Suggested top-level loader interface:

```verilog
input  wire        repo_load_req_i;
input  wire [15:0] repo_object_id_i;
output wire        repo_load_busy_o;
output wire        repo_load_done_o;
output wire        repo_load_error_o;
output wire [7:0]  repo_load_error_code_o;
```

Suggested internal outputs after directory lookup:

```verilog
output wire [31:0] repo_start_lba_o;
output wire [15:0] repo_sector_count_o;
output wire [31:0] repo_dst_addr_o;
output wire [1:0]  repo_dst_kind_o;
output wire [31:0] repo_byte_len_o;
```

Suggested destination write-side interface:

```verilog
output wire        repo_wr_en_o;
output wire [31:0] repo_wr_addr_o;
output wire [7:0]  repo_wr_data_o;
output wire        repo_wr_last_o;
```

## 10. Recommended Firmware / Control Strategy

For the current project, the simplest reliable behavior is:

- load required static assets once at startup
- keep them resident in BRAM or SDRAM
- only reload when:
  - algorithm changes
  - parameter profile changes
  - user explicitly requests another model/table set

This avoids repeated SD traffic during video processing.

## 11. Bandwidth Guidance

SPI is slower than native SD 4-bit, but for table loading it is usually enough.

Example perspective:

- `12.5 MHz` SPI clock means theoretical raw bit rate is about `12.5 Mbit/s`
- theoretical byte rate is about `1.56 MB/s`
- effective payload throughput will be lower because of command / token / response overhead

Practical implication:

- loading a small LUT is effectively instant
- loading medium parameter blocks is acceptable
- loading large CNN weights is acceptable if done at startup or mode switch
- loading full video frames continuously is not the right target

## 12. Priority Improvements

Recommended next optimization order:

1. keep current stable SPI path as baseline
2. add directory parser and object lookup by `object_id`
3. add segmented multi-block repository loader
4. add BRAM/SDRAM write-back destination interface
5. benchmark practical payload throughput
6. only then test higher SPI clock if needed

## 13. Future CNN Recommendation

For CNN integration:

- store weights on TF card
- load selected model or weight block into SDRAM before inference
- if model is too large, split by layer group or segment
- avoid weight reads directly from TF during every MAC cycle

Recommended approach:

- `TF -> SDRAM/BRAM -> CNN engine`

Not:

- `TF -> CNN engine directly`

## 14. Files To Reuse

Main reusable host files:

- `F:\codex\tools\sd_repo_pack.py`
- `F:\codex\tools\sd_repo_write.py`

Main reusable FPGA baseline:

- `F:\sd_table_repo_4bit_loader_v1\ov5640_hdmi_1080p.srcs\sources_1\sd\sd_boot_ctrl.v`

Main documentation references:

- `F:\sd_table_repo_4bit_loader_v1\README_SD.md`
- `F:\sd_table_repo_native4_v1\README_SD.md`

## 15. Final Engineering Conclusion

For this board and this competition project:

- native SD 4-bit is not the preferred delivery path
- SPI mode is the practical path
- TF card should be used as a large static repository, not real-time frame memory
- the next engineering target is a generic repository loader interface for algorithm tables and weights

This is the most stable route that preserves project momentum and supports later algorithm integration.
