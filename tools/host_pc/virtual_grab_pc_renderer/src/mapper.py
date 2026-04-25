from __future__ import annotations

import math

from model import DetectionFrame, VirtualBlob, VirtualFrame, VirtualPoint


def map_detection_to_virtual(
    frame: DetectionFrame,
    green_distance: float = 160.0,
) -> VirtualFrame:
    dx = frame.green.x - frame.origin.x
    dy = frame.green.y - frame.origin.y
    reference_pixels = math.hypot(dx, dy)
    if reference_pixels <= 1e-6:
        raise ValueError("green reference must not overlap origin")

    x_axis = (dx / reference_pixels, dy / reference_pixels)
    y_axis = (x_axis[1], -x_axis[0])
    scale = green_distance / reference_pixels

    def project(x: float, y: float) -> tuple[float, float]:
        rel_x = x - frame.origin.x
        rel_y = y - frame.origin.y
        world_x = (rel_x * x_axis[0] + rel_y * x_axis[1]) * scale
        world_y = (rel_x * y_axis[0] + rel_y * y_axis[1]) * scale
        return world_x, world_y

    def map_blob(blob_x: float, blob_y: float, radius: float) -> VirtualBlob:
        world_x, world_y = project(blob_x, blob_y)
        return VirtualBlob(world_x, world_y, radius * scale)

    green = map_blob(frame.green.x, frame.green.y, frame.green.radius)
    red = map_blob(frame.red.x, frame.red.y, frame.red.radius)
    blue = map_blob(frame.blue.x, frame.blue.y, frame.blue.radius)

    return VirtualFrame(
        frame_id=frame.frame_id,
        origin=VirtualPoint(0.0, 0.0),
        green=green,
        red=red,
        blue=blue,
        pixels_per_world_unit=1.0 / scale,
    )
