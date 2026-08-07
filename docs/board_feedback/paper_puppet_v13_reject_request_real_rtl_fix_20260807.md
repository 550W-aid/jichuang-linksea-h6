# Paper Puppet v13 Rejected - Request Real RTL Fix

Date: 2026-08-07

## Delivery Verification

The package currently uploaded as:

`PaperPuppet_H6_v13_wukong_m4k_printable_20260807.zip`

was downloaded and checked locally.

Verified facts:

- v13 JPSK SHA256:
  `7EF8B4887A3BFB0D99DD685692062518AF177AB169597F18A8B78C92640F3E7C`
- v12 JPSK SHA256:
  `7EF8B4887A3BFB0D99DD685692062518AF177AB169597F18A8B78C92640F3E7C`
- v13 and v12 `paper_puppet_h6_overlay.v` SHA256:
  `234062A8E41A47D74F9952B37AFDB740E708FC21DDBEF14AEE27CACC8508D92E`

Therefore v13 is a printable-target-only delivery. It does not contain an
FPGA RTL, ROM, FSM, or JPSK change. It cannot fix the two board problems
reported for v12.

## Board Problems Still Open

The board still shows:

1. the old red/orange block monkey behind and around the Wukong sprite;
2. a mostly static character with no convincing connected action.

Do not close this feedback by changing only the paper target, artwork file
name, README, or package version.

## Required FPGA Changes

### A. Remove the legacy visible layer

In the final HDMI RGB composition:

- the Wukong sprite/action frame must be the only character layer;
- remove or hard-disable the legacy `staff/head/ears/face/body/belt` drawing
  branches;
- remove the old red/orange fallback color path;
- do not let transparent sprite pixels fall through to the old procedural
  monkey geometry;
- keep the blue target only for detection and coordinate anchoring;
- keep any state marker disabled in the normal demo path or reduce it to a
  tiny test-only marker.

The expected output is:

```text
camera pixel outside replacement area
Wukong action frame inside replacement area
```

It must not be:

```text
Wukong sprite + legacy block geometry
```

### B. Add real frame-based animation

The next FPGA package must contain a small pose/frame sequencer:

```text
IDLE -> PREPARE -> ACTION -> RECOVER -> IDLE
```

Minimum visible animation:

- idle breathing or cloth/staff sway using at least two frames;
- left/right movement with different body and staff poses;
- jump/fly with a changed leg/body pose;
- staff attack with prepare, sweep, and recovery frames;
- Fire Eyes: hand-to-brow preparation, long eye beam, beam retract.

Changing only `pose_cx`, `pose_cy`, or a sprite origin is not sufficient and
must not be described as multi-frame animation.

The implementation may use a compact indexed ROM atlas and a frame ID. It
must remain compatible with the stable v10A camera/HDMI path, including
OV5640 register `3036 = 8'h54`.

## Mandatory Review Before Repackaging

Before providing another JPSK or asking for board programming, upload all of
the following to the repository:

1. HDMI preview with no red/orange block remnants;
2. preview of at least two idle frames;
3. preview of move, jump, attack, and Fire Eyes frame sequences;
4. updated RTL and ROM/frame dimensions;
5. resource summary;
6. new JPSK SHA256 that differs from v12;
7. explicit statement that camera-only output was not changed.

Do not call the next package v13 if the FPGA image is still byte-identical to
v12. Use a new version number and state the actual changed files.
