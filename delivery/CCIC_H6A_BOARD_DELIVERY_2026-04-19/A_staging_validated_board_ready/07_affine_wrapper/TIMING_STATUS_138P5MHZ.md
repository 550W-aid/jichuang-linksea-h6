# Timing Status: 07_affine_wrapper

Status:
- `NOT SIGNED OFF`
- Do not hand off as `138.5MHz clean`

Top RTL:
- `rtl/affine_nearest_stream_std.v`

Current conclusion:
- This block is still in the `needs architecture cleanup` state.
- It should not be mixed into the same board-ready set as the signed-off stream filters.

Why it is blocked:
1. The implementation model still assumes frame-style readback behavior.
2. Coordinate generation, memory seam, and latency contract are not yet finalized for board integration.
3. Even after arithmetic pipelining, the memory-side contract still needs to be made explicit.

Required action for GitHub members:
1. Separate `video-stream shell` from `memory-backed sampler`.
2. Pipeline coordinate transform and address math.
3. Re-run fresh `138.5MHz` timing only after the architecture is fixed.
