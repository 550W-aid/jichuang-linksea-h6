`timescale 1 ps / 1 ps

// Board-video-only wrapper that reuses the integrated VP_Top RTL while
// forcing the image-only signoff mode through a compile-time macro.
`define CODEX_BOARD_VIDEO_ONLY
`define CODEX_BOARD_VIDEO_GAUSSIAN_ONLY
`include "VP_Top.v"
`undef CODEX_BOARD_VIDEO_GAUSSIAN_ONLY
`undef CODEX_BOARD_VIDEO_ONLY
