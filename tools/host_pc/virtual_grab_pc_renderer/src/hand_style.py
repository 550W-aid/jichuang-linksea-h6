from __future__ import annotations

import math
from dataclasses import dataclass


HAND_STROKE_COLOR = "#111111"


@dataclass(frozen=True)
class HandStroke:
    points: tuple[float, ...]
    color: str = HAND_STROKE_COLOR
    width: int = 3
    smooth: bool = True


# Mirrored from the user-provided SVG reference so the rendered hand is a left hand.
LEFT_HAND_SVG_PATHS: tuple[tuple[tuple[float, float], ...], ...] = (
    (
        (0.1940, -0.9897),
        (0.2463, -0.9732),
        (0.2927, -0.9490),
        (0.3077, -0.9444),
        (0.3566, -0.9510),
        (0.5635, -0.9643),
        (0.7113, -0.9331),
        (0.7604, -0.9002),
        (0.7941, -0.8530),
        (0.8063, -0.8310),
        (0.8137, -0.8267),
        (0.8931, -0.8405),
        (0.9992, -0.8442),
        (1.0737, -0.8376),
        (1.1363, -0.8216),
        (1.2576, -0.7399),
        (1.3000, -0.6051),
        (1.2895, -0.5316),
        (1.2522, -0.4690),
        (1.0856, -0.3661),
        (0.7904, -0.3114),
        (0.6361, -0.2899),
        (0.4920, -0.2488),
        (0.3460, -0.1774),
        (0.2637, -0.0908),
        (0.2537, -0.0659),
        (0.2516, -0.0420),
        (0.2576, -0.0074),
        (0.2788, 0.0136),
        (0.2975, 0.0207),
        (0.3324, 0.0220),
        (0.4057, 0.0129),
        (0.5045, -0.0204),
        (0.6339, -0.0623),
        (0.7534, -0.0723),
        (0.8419, -0.0665),
        (0.9100, -0.0420),
        (0.9817, 0.0084),
        (1.0309, 0.0793),
        (1.0486, 0.1234),
        (1.0531, 0.1625),
        (1.0212, 0.2590),
        (0.9258, 0.3346),
        (0.8152, 0.3756),
        (0.6776, 0.4043),
        (0.6015, 0.4174),
        (0.5328, 0.4369),
        (0.4089, 0.4885),
        (0.2634, 0.5774),
        (0.1368, 0.6504),
        (0.0104, 0.6926),
        (-0.0811, 0.7091),
        (-0.1846, 0.7165),
        (-0.2920, 0.8075),
        (-0.3661, 0.9096),
        (-0.4749, 0.9774),
        (-0.6220, 0.9899),
        (-0.7224, 0.9581),
        (-0.8064, 0.8931),
        (-0.9546, 0.7643),
        (-1.0750, 0.6599),
        (-1.1774, 0.5711),
        (-1.2483, 0.5081),
        (-1.2753, 0.4777),
        (-1.2912, 0.4301),
        (-1.3000, 0.3193),
        (-1.2698, 0.2021),
        (-1.1991, 0.1230),
        (-1.1173, 0.0827),
        (-1.0586, 0.0733),
        (-1.0478, 0.0695),
        (-1.0479, 0.0599),
        (-1.0500, 0.0339),
        (-1.0533, -0.0309),
        (-1.0438, -0.1340),
        (-1.0029, -0.2789),
        (-0.8845, -0.4879),
        (-0.6888, -0.7423),
        (-0.5112, -0.8874),
        (-0.4080, -0.9269),
        (-0.3741, -0.9303),
        (-0.3237, -0.9305),
        (-0.2914, -0.9265),
        (-0.2632, -0.9171),
        (-0.2365, -0.9051),
        (-0.2163, -0.8939),
        (-0.2024, -0.8867),
        (-0.1967, -0.8867),
        (-0.1840, -0.8939),
        (-0.1285, -0.9256),
        (-0.0150, -0.9706),
        (0.0636, -0.9891),
        (0.1049, -0.9929),
        (0.1506, -0.9926),
        (0.1844, -0.9909),
        (0.1940, -0.9897),
    ),
    (
        (0.0583, -0.9277),
        (-0.0581, -0.8916),
        (-0.1681, -0.8334),
        (-0.1891, -0.8204),
        (-0.2001, -0.8149),
        (-0.2111, -0.8204),
        (-0.2324, -0.8338),
        (-0.3164, -0.8699),
        (-0.4045, -0.8658),
        (-0.5071, -0.8201),
        (-0.6170, -0.7297),
        (-0.6999, -0.6379),
        (-0.8150, -0.4822),
        (-0.9139, -0.3293),
        (-0.9669, -0.2003),
        (-0.9930, -0.0565),
        (-0.9841, 0.0759),
        (-0.9754, 0.1215),
        (-0.9828, 0.1365),
        (-0.9912, 0.1430),
        (-0.9989, 0.1433),
        (-1.0541, 0.1326),
        (-1.1070, 0.1416),
        (-1.1909, 0.1956),
        (-1.2374, 0.2820),
        (-1.2394, 0.3522),
        (-1.2323, 0.4255),
        (-1.2169, 0.4557),
        (-1.1495, 0.5168),
        (-1.0812, 0.5758),
        (-0.9996, 0.6464),
        (-0.9295, 0.7073),
        (-0.8885, 0.7427),
        (-0.8575, 0.7699),
        (-0.8113, 0.8101),
        (-0.7046, 0.8976),
        (-0.6355, 0.9263),
        (-0.5736, 0.9331),
        (-0.5116, 0.9263),
        (-0.4170, 0.8751),
        (-0.3446, 0.7781),
        (-0.3228, 0.7265),
        (-0.3051, 0.6703),
        (-0.1461, 0.6545),
        (-0.0551, 0.6452),
        (0.0516, 0.6197),
        (0.1727, 0.5637),
        (0.3042, 0.4798),
        (0.3859, 0.4320),
        (0.4825, 0.3902),
        (0.5985, 0.3570),
        (0.7114, 0.3383),
        (0.8207, 0.3117),
        (0.9171, 0.2712),
        (0.9829, 0.2075),
        (0.9928, 0.1425),
        (0.9646, 0.0812),
        (0.8976, 0.0190),
        (0.7867, -0.0133),
        (0.6721, -0.0081),
        (0.5817, 0.0155),
        (0.4032, 0.0745),
        (0.2442, 0.0616),
        (0.1970, 0.0001),
        (0.1931, -0.0240),
        (0.1943, -0.0713),
        (0.2089, -0.1167),
        (0.2689, -0.1932),
        (0.4075, -0.2802),
        (0.5680, -0.3356),
        (0.7116, -0.3624),
        (0.9879, -0.4005),
        (1.2078, -0.5084),
        (1.2333, -0.6580),
        (1.1416, -0.7555),
        (1.0020, -0.7843),
        (0.8659, -0.7770),
        (0.7906, -0.7625),
        (0.7720, -0.7623),
        (0.7651, -0.7694),
        (0.7587, -0.7848),
        (0.7425, -0.8255),
        (0.7078, -0.8660),
        (0.6273, -0.8977),
        (0.4694, -0.9033),
        (0.3451, -0.8893),
        (0.3131, -0.8839),
        (0.2966, -0.8804),
        (0.2800, -0.8863),
        (0.2419, -0.9094),
        (0.1953, -0.9280),
        (0.1478, -0.9346),
        (0.0856, -0.9318),
        (0.0583, -0.9277),
    ),
)

FINGER_GUIDE_CURVES: tuple[tuple[tuple[float, float], ...], ...] = (
    ((0.66, -0.56), (0.45, -0.22), (0.17, 0.04)),
    ((0.38, -0.46), (0.16, -0.12), (-0.08, 0.12)),
    ((0.02, -0.34), (-0.15, -0.04), (-0.30, 0.18)),
    ((-0.74, -0.10), (-0.54, 0.08), (-0.34, 0.28)),
)

ARTICULATED_FINGER_CURVES: tuple[
    tuple[tuple[tuple[float, float], ...], tuple[tuple[float, float], ...]],
    ...,
] = (
    (
        ((0.30, 0.04), (0.54, -0.22), (0.76, -0.62)),
        ((0.20, 0.10), (0.16, -0.02), (0.02, 0.12)),
    ),
    (
        ((0.06, 0.10), (0.24, -0.18), (0.40, -0.54)),
        ((0.02, 0.16), (0.02, 0.00), (-0.10, 0.18)),
    ),
    (
        ((-0.18, 0.18), (-0.02, -0.06), (0.10, -0.38)),
        ((-0.16, 0.20), (-0.12, 0.06), (-0.22, 0.22)),
    ),
    (
        ((-0.42, 0.18), (-0.66, 0.04), (-0.92, -0.12)),
        ((-0.36, 0.20), (-0.48, 0.08), (-0.42, 0.00)),
    ),
)


def build_hand_line_art(
    center_x: float,
    center_y: float,
    radius: float,
    grip: float = 0.0,
    rotation_deg: float = 0.0,
) -> list[HandStroke]:
    r = max(radius, 12.0)
    width = max(2, round(r * 0.1))
    guide_width = max(2, round(r * 0.075))
    pose = _clamp01(grip)
    strokes: list[HandStroke] = []

    for normalized_path in LEFT_HAND_SVG_PATHS:
        points: list[float] = []
        for norm_x, norm_y in normalized_path:
            posed_x, posed_y = _apply_grip_pose(norm_x, norm_y, pose)
            posed_x, posed_y = _rotate_point(posed_x, posed_y, rotation_deg)
            points.extend((center_x + posed_x * r, center_y + posed_y * r))
        strokes.append(HandStroke(points=tuple(points), width=width))

    for guide_curve in FINGER_GUIDE_CURVES:
        guide_points: list[float] = []
        for norm_x, norm_y in _sample_quadratic_curve(guide_curve):
            posed_x, posed_y = _apply_grip_pose(norm_x, norm_y, pose)
            posed_x, posed_y = _rotate_point(posed_x, posed_y, rotation_deg)
            guide_points.extend((center_x + posed_x * r, center_y + posed_y * r))
        strokes.append(HandStroke(points=tuple(guide_points), width=guide_width))

    articulation_width = max(2, round(r * 0.095))
    articulation_pose = _smoothstep(pose)
    for open_curve, closed_curve in ARTICULATED_FINGER_CURVES:
        articulated_curve = _interpolate_curve(open_curve, closed_curve, articulation_pose)
        articulated_points: list[float] = []
        for norm_x, norm_y in _sample_quadratic_curve(articulated_curve, samples=10):
            posed_x, posed_y = _rotate_point(norm_x, norm_y, rotation_deg)
            articulated_points.extend((center_x + posed_x * r, center_y + posed_y * r))
        strokes.append(HandStroke(points=tuple(articulated_points), width=articulation_width))

    return strokes


def _apply_grip_pose(norm_x: float, norm_y: float, grip: float) -> tuple[float, float]:
    if grip <= 0.0:
        return norm_x, norm_y

    palm_x = -0.24
    palm_y = 0.24
    pose = grip * grip * (2.2 - 1.2 * grip)
    finger_zone = _smoothstep((-norm_y + 0.04) / 1.02)
    finger_side = _smoothstep((norm_x - palm_x + 0.22) / 1.65)
    thumb_zone = _smoothstep((palm_x - norm_x + 0.18) / 0.85) * _smoothstep((-norm_y + 0.10) / 0.92)
    curl = _smoothstep(min(1.0, pose * finger_zone * 1.18))
    thumb_curl = pose * thumb_zone

    posed_x = palm_x + (norm_x - palm_x) * (1.0 - 1.06 * curl)
    posed_y = palm_y + (norm_y - palm_y) * (1.0 - 0.98 * curl)
    posed_x = _lerp(posed_x, palm_x + (norm_x - palm_x) * -0.12, 0.94 * curl)
    posed_x -= 0.84 * pose * finger_side
    posed_x += 0.24 * thumb_curl
    posed_y += 0.58 * curl
    posed_y += 0.22 * pose * finger_side
    posed_y -= 0.08 * thumb_curl
    return posed_x, posed_y


def _lerp(start: float, end: float, alpha: float) -> float:
    return start + (end - start) * _clamp01(alpha)


def _sample_quadratic_curve(
    control_points: tuple[tuple[float, float], ...],
    samples: int = 10,
) -> tuple[tuple[float, float], ...]:
    start, control, end = control_points
    points: list[tuple[float, float]] = []
    for index in range(samples):
        t = index / (samples - 1)
        one_minus = 1.0 - t
        x = one_minus * one_minus * start[0] + 2.0 * one_minus * t * control[0] + t * t * end[0]
        y = one_minus * one_minus * start[1] + 2.0 * one_minus * t * control[1] + t * t * end[1]
        points.append((x, y))
    return tuple(points)


def _interpolate_curve(
    start_curve: tuple[tuple[float, float], ...],
    end_curve: tuple[tuple[float, float], ...],
    alpha: float,
) -> tuple[tuple[float, float], ...]:
    pose = _clamp01(alpha)
    return tuple(
        (
            _lerp(start_point[0], end_point[0], pose),
            _lerp(start_point[1], end_point[1], pose),
        )
        for start_point, end_point in zip(start_curve, end_curve)
    )


def _rotate_point(norm_x: float, norm_y: float, rotation_deg: float) -> tuple[float, float]:
    if rotation_deg == 0.0:
        return norm_x, norm_y

    angle = rotation_deg * 3.141592653589793 / 180.0
    cos_angle = math.cos(angle)
    sin_angle = math.sin(angle)
    return (
        norm_x * cos_angle - norm_y * sin_angle,
        norm_x * sin_angle + norm_y * cos_angle,
    )


def _smoothstep(value: float) -> float:
    weight = _clamp01(value)
    return weight * weight * (3.0 - 2.0 * weight)


def _clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))
