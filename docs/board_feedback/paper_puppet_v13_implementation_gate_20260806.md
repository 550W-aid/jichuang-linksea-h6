# Paper Puppet v13 Implementation Gate - 2026-08-06

## Board Result From v12

The v12 artwork quality is acceptable, but the board image still shows the
legacy red/orange block monkey behind the Wukong sprite. The old layer is
clearly visible as a rectangular torso/background and a detached vertical bar.
The action also remains visually static: the current result looks like one
sprite with small coordinate offsets rather than a connected animation.

Board photo:

![v12 block layer remains](IMG_20260806_185727_v12_block_layer_remains.jpg)

## Confirmed RTL Cause

The v12 overlay module still combines the sprite with the procedural legacy
geometry:

- `overlay_w` is asserted by `staff_w`, `head_w`, `ears_w`, `body_w`,
  `jump_arm_w`, and `marker_w` in addition to `sprite_opaque_w`.
- The final RGB mux still has fallback branches for `staff_s1_r`,
  `face_s1_r`, `belt_s1_r`, `head_s1_r`, `ears_s1_r`, and the old red
  fallback color.
- The ROM contains only one `160x270` Wukong sprite frame.
- `ACTION_IDLE`, `ACTION_LEFT`, `ACTION_RIGHT`, `ACTION_JUMP`, and
  `ACTION_SWEEP` currently change offsets/state colors, but do not select
  distinct character poses.

This is why the board shows **Wukong sprite + old block layer**, and why the
motion is not convincing.

## Mandatory v13 Changes

### 1. One visible character layer

The final HDMI composition must contain only:

1. camera pixels outside the target replacement region;
2. the Wukong sprite or Wukong action frame inside that region;
3. an optional tiny debug marker behind a compile-time/test-mode switch.

Remove the legacy procedural monkey from the visible output. Do not leave any
fallback `head/body/ears/face/belt/staff` branch capable of painting the old
red/orange blocks when the Wukong overlay is enabled.

The tracking marker must not be rendered as a large blue or white square in
the normal demo path.

### 2. Real frame-based animation

Use a small FPGA-friendly frame sequencer. A full-frame buffer is not needed.
The minimum accepted action sequence is:

```text
IDLE -> PREPARE -> ACTION -> RECOVER -> IDLE
```

Required visible actions:

- **Idle**: at least two frames with breathing or cloth/staff sway.
- **Move left/right**: at least two directional poses; body, feet, arms, and
  staff must follow the direction.
- **Jump/fly**: compressed or separated legs plus vertical movement and a short
  cloud/afterimage accent if resources permit.
- **Sweep/attack**: preparation, staff-through-body attack, and recovery;
  never show only a detached vertical line.
- **Fire Eyes**: hand rises to brow over multiple frames, then a long beam
  emits from the eyes, followed by beam retract/recovery.

If the art is stored in ROM, use a small atlas or several indexed pose ROMs and
select `frame_id` from the FSM. Do not claim animation if only the sprite
origin is moving.

### 3. Preserve the stable video path

Keep the v10A camera/HDMI baseline unchanged, including:

- OV5640 register `3036 = 8'h54`;
- existing capture, SDRAM, timing, and HDMI pass-through path;
- target detection and blue-marker center tracking unless a change is
  required to anchor the sprite.

The v13 change should be isolated to the paper-puppet overlay and its ROM/FSM.

## Review Required Before Packaging

Do not produce or burn the next JPSK until all of the following are attached
to the commit:

1. an HDMI preview showing no residual red/orange block layer;
2. a frame-by-frame preview for idle, move, jump, attack, and Fire Eyes;
3. the updated ROM format and frame dimensions;
4. a short resource estimate for ROM bits and logic;
5. confirmation that the camera-only path remains unchanged.

## Board Acceptance Criteria

The next board build passes only if:

- no old red/orange rectangular monkey pixels remain around the Wukong sprite;
- the character is recognizable as Sun Wukong without explanation;
- at least one idle change is visible while the target is held still;
- move/jump/attack visibly change the pose, not only the position;
- Fire Eyes includes the hand-to-brow transition and a long eye beam;
- the HDMI camera path remains stable before the overlay is enabled.
