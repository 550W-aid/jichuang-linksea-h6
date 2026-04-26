# Low-Light Enhance Update 2026-04-26

## Scope

This note records the design intent for the updated low-light enhancement path used by the shared RGB888 video-stream chain.

Target files:

- `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/C_shared_dependencies/rtl/ycbcr444_luma_gamma_stream_std.v`
- `delivery/CCIC_H6A_BOARD_DELIVERY_2026-04-19/C_shared_dependencies/rtl/darkness_enhance_rgb888_stream_std.v`

## Problem

The previous low-light path effectively behaved like:

- global luma gamma
- followed by global brightness lift

That approach raises the whole frame together. It can make dark areas brighter, but it also over-lifts already bright regions, so the screen looks washed out.

## New Design Direction

The updated path keeps the original real-time streaming interface and still works on the Y channel only, but changes the enhancement model to:

- segmented brightness regions
- plus adaptive dark-region lifting

This means:

- very dark pixels get the strongest enhancement
- mid-dark pixels get moderate enhancement
- bright pixels get little to no enhancement

## Core Idea

For positive enhancement strength, the new logic does not use a plain:

- `Y' = Y + offset`

Instead it uses two controls:

1. **Segmented region gain**

The input luma is divided into several ranges:

- `Y < 48`: strongest boost
- `48 <= Y < 96`: strong boost
- `96 <= Y < 144`: medium boost
- `144 <= Y < 192`: light boost
- `Y >= 192`: nearly no boost

2. **Adaptive headroom weighting**

The enhancement is also weighted by:

- `headroom = 255 - Y`

So even if the configured strength is high, a bright pixel has very little remaining headroom and is therefore protected from over-brightening.

## Resulting Behavior

Compared with the old version:

- shadow regions are lifted more aggressively
- mid tones are lifted in a controlled way
- highlights are preserved much better
- the full frame is less likely to turn gray-white

## Interface Compatibility

No frame buffer was added.

No stream protocol change was introduced.

The module remains:

- real-time
- streaming
- one-pixel-lane compatible
- frame-latched for configuration

## Parameter Meaning

`cfg_brightness_offset` should now be understood as:

- enhancement strength

not as:

- pure linear whole-frame brightness offset

Negative values still fall back to linear dimming behavior.

## Future Iteration Guidance

If this algorithm needs further improvement later, continue in this direction instead of returning to whole-frame linear lift:

1. Keep the streaming architecture.
2. Preserve highlight protection.
3. Prefer dark-region selective enhancement over global brightness raise.
4. If more quality is needed, refine the segment boundaries or region gains first.
5. Only after that consider adding local statistics or neighborhood-aware enhancement.

## Vivado Verification Status

This update has been reworked into a deeper pipeline and checked again with the repository OOC signoff flow at the current board-side target clock:

- top: `rgb_ycbcr_gamma_rgb_chain_top`
- clock: `clk = 7.220ns = 138.5MHz`
- report directory: `reports/vivado_ooc/low_light_2026-04-26_138p5MHz_pipe1/`

Key results:

- `WNS = 0.455ns`
- `TNS = 0.000ns`
- `WHS = 0.132ns`
- `THS = 0.000ns`

Current conclusion:

- this shared low-light stream chain passes OOC timing at `138.5MHz`
- the positive result comes from turning the dark-lift datapath into a multi-stage pipeline instead of keeping both multiplies and the final add in one cycle
- this is module-level timing evidence, not full-board in-context timing closure

If a later top-level integration changes fanout, placement pressure, or cross-module timing context, run full-project signoff again instead of relying only on this OOC result.
