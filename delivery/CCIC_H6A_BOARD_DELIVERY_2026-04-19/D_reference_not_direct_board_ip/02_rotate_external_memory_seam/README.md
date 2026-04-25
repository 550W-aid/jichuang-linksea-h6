# Rotate External Memory Seam

This folder contains the non-SDRAM part of the realtime nearest-rotation path.

## Scope

This delivery stops at the explicit external frame-store seam.

Included:

- stream capture wrapper
- frame-latched angle commit
- rotated read-request planning
- rotated replay path
- RGB888 wrapper
- basic self-check testbench

Not included:

- SDRAM controller
- DDR controller
- AXI memory adapter
- final board-level top integration

## Main RTL

- `rtl/rotate_nearest_stream_mem_seam.v`
- `rtl/rotate_nearest_rgb888_stream_mem_seam.v`

## Helper RTL

- `rtl/frame_latched_s9.v`
- `rtl/rotate_trig_lut.v`
- `rtl/rotate_nearest_coord_mapper.v`
- `rtl/rotate_nearest_linear_index_mapper.v`
- `rtl/rotate_nearest_multilane_request_planner.v`
- `rtl/rotate_nearest_multilane_readback_path.v`

## External Memory Boundary

Write side:

- `fb_wr_valid`
- `fb_wr_ready`
- `fb_wr_addr`
- `fb_wr_data`
- `fb_wr_keep`
- `fb_wr_sof`
- `fb_wr_eol`
- `fb_wr_eof`

Read side:

- `fb_rd_cmd_valid`
- `fb_rd_cmd_ready`
- `fb_rd_cmd_addr`
- `fb_rd_cmd_keep`
- `fb_rd_rsp_valid`
- `fb_rd_rsp_ready`
- `fb_rd_rsp_data`

Interpretation:

- the rotate wrapper captures one full input frame through `fb_wr_*`
- after frame end, it replays the rotated output by issuing read requests on `fb_rd_cmd_*`
- the external memory wrapper must return one packed response beat on `fb_rd_rsp_*`
- zero-filled out-of-frame lanes are already handled inside the rotate seam and are masked out of `fb_rd_cmd_keep`

## Current Delivery Boundary

- This is a reference/integration seam, not final board-delivery IP.
- No local frame-store placeholder remains in the main seam.
- The intended next owner is the teammate who owns SDRAM / external memory integration.

## Verification

Testbench:

- `tb/tb_rotate_nearest_stream_mem_seam.v`

Verified in local xsim:

- identity-angle frame replay passes through the external seam
- runtime angle update commits on the next frame start

## Timing Status

- Timing signoff has not been claimed in this folder.
- This folder is placed under `D_reference_not_direct_board_ip` on purpose.
