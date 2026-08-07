# Paper Puppet v14 Board Feedback - Motion Still Too Subtle

Date: 2026-08-07

## Board Observation

The current v14 build is no longer a static overlay. The HDMI image now shows
the Wukong atlas sprite, and the pose clearly changes between board photos.

However, two issues remain:

1. the character reads as too fuzzy / blocky on the board camera photo;
2. the motion is still too subtle to be obvious at a glance.

In the two latest board photos:

- one frame looks like a mostly idle / hold pose;
- the other frame already shows the horizontal staff-attack style pose;
- the `Fire Eyes` hand-to-brow / long-beam sequence was not visible in these
  still images.

## Interpretation

This means the action state machine is at least partially firing, but the
visual difference between states is not strong enough for a fast live demo.
The board photo also amplifies the low-resolution atlas and screen moiré, so
the sprite looks much softer than the preview image.

## Requested Next Step

Please keep the current atlas-based approach, but make the next revision read
more aggressively on HDMI:

- exaggerate the idle versus action silhouette difference;
- make sweep / attack more visibly different from idle;
- make `Fire Eyes` much longer and easier to see;
- if possible, sharpen the sprite presentation without bringing back the
  legacy block-monkey overlay;
- keep the target-triggered FSM behavior, but make the triggered pose hold
  a little longer so the camera can capture it.

## Bottom Line

The build is now closer, but the demo effect still needs stronger visual
separation between states.
