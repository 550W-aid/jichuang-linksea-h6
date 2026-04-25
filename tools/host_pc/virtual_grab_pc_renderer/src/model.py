from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class ImagePoint:
    x: float
    y: float


@dataclass(frozen=True)
class BlobDetection:
    x: float
    y: float
    radius: float


@dataclass(frozen=True)
class DetectionFrame:
    frame_id: int
    origin: ImagePoint
    green: BlobDetection
    red: BlobDetection
    blue: BlobDetection


@dataclass(frozen=True)
class VirtualPoint:
    x: float
    y: float


@dataclass(frozen=True)
class VirtualBlob:
    x: float
    y: float
    radius: float


@dataclass(frozen=True)
class VirtualFrame:
    frame_id: int
    origin: VirtualPoint
    green: VirtualBlob
    red: VirtualBlob
    blue: VirtualBlob
    pixels_per_world_unit: float
