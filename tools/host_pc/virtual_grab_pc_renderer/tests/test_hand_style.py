from pathlib import Path
import sys
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = PROJECT_ROOT / "src"
sys.path.insert(0, str(SRC_ROOT))

from hand_style import HAND_STROKE_COLOR, build_hand_line_art  # type: ignore


def _bounds(strokes):
    xs = [stroke.points[index] for stroke in strokes for index in range(0, len(stroke.points), 2)]
    ys = [stroke.points[index] for stroke in strokes for index in range(1, len(stroke.points), 2)]
    return min(xs), max(xs), min(ys), max(ys)


class HandStyleTests(unittest.TestCase):
    def test_builds_svg_based_left_hand_outline(self) -> None:
        center_x = 320.0
        center_y = 260.0
        radius = 36.0
        strokes = build_hand_line_art(center_x, center_y, radius, grip=0.0)

        self.assertGreaterEqual(len(strokes), 5)
        self.assertTrue(all(stroke.color == HAND_STROKE_COLOR for stroke in strokes))
        self.assertTrue(all(stroke.smooth for stroke in strokes))
        self.assertTrue(all(len(stroke.points) >= 20 for stroke in strokes))
        self.assertTrue(all(len(stroke.points) % 2 == 0 for stroke in strokes))

        xs = [stroke.points[index] for stroke in strokes for index in range(0, len(stroke.points), 2)]
        ys = [stroke.points[index] for stroke in strokes for index in range(1, len(stroke.points), 2)]
        self.assertLess(min(xs), center_x - radius)
        self.assertGreater(max(xs), center_x + radius)
        self.assertLess(min(ys), center_y - radius * 0.8)
        self.assertGreater(max(ys), center_y + radius * 0.6)

    def test_grip_changes_hand_pose(self) -> None:
        center_x = 320.0
        center_y = 260.0
        radius = 36.0
        open_strokes = build_hand_line_art(center_x, center_y, radius, grip=0.0)
        closed_strokes = build_hand_line_art(center_x, center_y, radius, grip=1.0)
        release_strokes = build_hand_line_art(center_x, center_y, radius, grip=0.45)

        open_bounds = _bounds(open_strokes)
        closed_bounds = _bounds(closed_strokes)
        release_bounds = _bounds(release_strokes)
        open_width = open_bounds[1] - open_bounds[0]
        closed_width = closed_bounds[1] - closed_bounds[0]
        release_width = release_bounds[1] - release_bounds[0]
        open_height = open_bounds[3] - open_bounds[2]
        closed_height = closed_bounds[3] - closed_bounds[2]

        self.assertLess(closed_width, open_width - radius * 1.05)
        self.assertLess(closed_height, open_height - radius * 0.45)
        self.assertGreater(release_width, closed_width + radius * 0.5)

    def test_rotation_changes_hand_orientation(self) -> None:
        center_x = 320.0
        center_y = 260.0
        radius = 36.0
        neutral_strokes = build_hand_line_art(center_x, center_y, radius, grip=1.0, rotation_deg=0.0)
        rotated_strokes = build_hand_line_art(center_x, center_y, radius, grip=1.0, rotation_deg=18.0)
        neutral_first = neutral_strokes[0].points[:2]
        rotated_first = rotated_strokes[0].points[:2]

        self.assertGreater(abs(rotated_first[0] - neutral_first[0]), radius * 0.08)
        self.assertGreater(abs(rotated_first[1] - neutral_first[1]), radius * 0.08)

    def test_includes_explicit_finger_articulation_strokes_for_grab_readability(self) -> None:
        center_x = 320.0
        center_y = 260.0
        radius = 36.0
        open_strokes = build_hand_line_art(center_x, center_y, radius, grip=0.0)
        closed_strokes = build_hand_line_art(center_x, center_y, radius, grip=1.0)

        self.assertGreaterEqual(len(open_strokes), 10)
        articulated_open = open_strokes[-4:]
        articulated_closed = closed_strokes[-4:]
        fingertip_motion = max(
            (
                (open_stroke.points[-2] - closed_stroke.points[-2]) ** 2
                + (open_stroke.points[-1] - closed_stroke.points[-1]) ** 2
            )
            ** 0.5
            for open_stroke, closed_stroke in zip(articulated_open, articulated_closed)
        )

        self.assertGreater(fingertip_motion, radius * 0.45)


if __name__ == "__main__":
    unittest.main()
