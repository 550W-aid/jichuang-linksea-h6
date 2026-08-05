# Paper Puppet Hardware Design Question - 2026-08-05

## Why This Question Exists

Before making the physical puppet, we need the FPGA-side author to confirm what
kind of paper puppet is actually easiest for the current detector to recognize.

The board operator can prepare a custom paper puppet, background board, colors,
and lighting. Please answer in GitHub so the physical object can be made to
match the FPGA algorithm instead of guessing.

## Current Detector Understanding From v9 RTL

File inspected:

`01_FPGA/ov5640_hdmi_1080p.srcs/sources_1/paper_puppet/paper_puppet_h6_overlay.v`

The current detector appears to classify a pixel as target when one RGB channel
is strongly dominant:

- Red target:
  - `R > 150`
  - `R > G + 45`
  - `R > B + 45`
- Green target:
  - `G > 150`
  - `G > R + 45`
  - `G > B + 45`
- Blue target:
  - `B > 150`
  - `B > R + 45`
  - `B > G + 45`

The current target center is then computed from the bounding box of all
saturated target pixels in the frame:

- `min_x`, `max_x`, `min_y`, `max_y`
- `target_center_x = (min_x + max_x) / 2`
- `target_center_y = (min_y + max_y) / 2`
- current `MIN_TARGET_PIXELS = 64`

So the current FPGA does not appear to recognize a detailed human contour. It
recognizes a saturated-color blob/region and uses the blob bounding-box center
as the puppet anchor.

## Initial Hardware Guess

Based on the RTL, the most reliable physical object is probably not a thin,
detailed Sun Wukong silhouette. The most reliable target is likely:

- one large matte saturated-color body region,
- simple external contour,
- no thin saturated limbs that would pull the bounding box center around,
- high contrast against the background,
- stable lighting with no strong reflection.

For example, a good first physical puppet might be:

- A4-size white/black background board.
- A 20-28 cm tall paper puppet.
- A large central pure-blue or pure-red oval/rounded-rectangle torso marker.
- Optional black/gold printed decorative outline around it, but the saturated
  recognition region should remain large and clean.

Please confirm or correct this.

## Questions For FPGA-Side Author

1. Which physical target color is most recommended for the current FPGA
   threshold under ordinary indoor lighting: pure red, pure green, or pure blue?

2. What minimum on-screen target size should the operator prepare?
   Please answer in approximate HDMI pixels and in approximate real size at the
   expected camera distance if possible.

3. Should the physical puppet be:
   - a full pure-color human-shaped cutout, or
   - a normal-looking puppet with only a large pure-color recognition patch?

4. If the puppet has arms, staff, hat feathers, or other thin protrusions in
   the same saturated color, will the bounding-box center drift too much?

5. Is the current detector intended to track the whole puppet, or only a
   central colored marker carried by the puppet?

6. Does the FPGA overlay assume the target center should be near the puppet's
   head, chest, or geometric center?

7. Should the background be white, black, gray, or another color to reduce false
   saturated detections?

8. Should the physical puppet avoid red/gold decorations because the overlay
   itself uses red/gold, or does that not matter because detection uses the
   camera input before overlay replacement?

9. If we need a Sun Wukong-looking puppet for the final demo, what is the
   safest compromise between recognition stability and visual recognizability?
   Please give a concrete drawing rule, such as:
   - "large blue torso marker + black silhouette outline",
   - "pure red full body with no thin staff",
   - "green rectangle marker hidden behind printed puppet",
   - or another FPGA-friendly structure.

## Requested Output

Please return one concrete recommended physical design:

- color,
- approximate dimensions,
- shape,
- background,
- whether to use a central marker or full-body color,
- any forbidden features,
- and whether the current RTL should be changed to better support this puppet.

This answer will be used to make the actual paper puppet hardware.

