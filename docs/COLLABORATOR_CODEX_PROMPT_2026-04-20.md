# Prompt For Collaborator And Their Codex

Copy the prompt below into the collaborator's Codex session.

```text
You are helping on the CCIC H6A FPGA image-processing delivery set.

First, locate this delivery bundle on the local F drive:
- CCIC_H6A_BOARD_DELIVERY_2026-04-19

Treat that folder as the source of truth.

Read these files first:
1. CCIC_H6A_BOARD_DELIVERY_2026-04-19\04_TIMING_SIGNOFF_GATE_138P5MHZ.md
2. CCIC_H6A_BOARD_DELIVERY_2026-04-19\docs\TIMING_STATUS_2026-04-20.md

Hard rules:
- Target device: xc7z020clg400-1
- Target clock: 138.5MHz
- Do not call any module board-ready without fresh timing evidence
- Large multiply/add/address chains must be pipelined
- If a module uses frame memory, label it honestly as frame-buffer assisted, not pure video stream
- No simulation-only logic in synthesizable RTL
- Keep comments clear on inputs, outputs, always blocks, and helper functions

Task ownership split:
- 02_realtime_resize is being fixed locally by another owner right now
- Do NOT spend time on 02_realtime_resize unless explicitly reassigned

Your scope:
1. Focus on the remaining timing-risk modules:
   - 03_fixed_angle_rotate
   - 07_affine_wrapper
   - any promoted chain from B_external_stream_std_library only if you first define a real board-facing top
2. Check whether the current architecture is truly pure stream or actually frame-buffer assisted
3. If arithmetic depth is the issue, pipeline it
4. If architecture is the issue, write that clearly instead of forcing a fake stream label
5. Produce timing evidence or a precise blocker report

Expected deliverables:
1. A short status note per module:
   - PASS / FAIL / BLOCKED
   - top RTL file
   - current blocker
   - next action
2. If you modify RTL, list exactly which files changed
3. If timing still fails, identify the likely critical path type:
   - coordinate math
   - interpolation math
   - address generation
   - memory seam
   - control latency alignment

Current known status:
- Signed off:
  - 01_histogram_equalizer
  - 04_low_light_enhance
  - 05_bilateral_filter
  - 06_guided_filter
- Not signed off:
  - 03_fixed_angle_rotate
  - 07_affine_wrapper
- Already owned by someone else:
  - 02_realtime_resize

Work carefully and do not overwrite other owners' tasks.
```
