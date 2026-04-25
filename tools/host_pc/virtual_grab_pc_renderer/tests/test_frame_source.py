from pathlib import Path
import sys
import unittest
from unittest.mock import patch


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = PROJECT_ROOT / "src"
sys.path.insert(0, str(SRC_ROOT))

from frame_source import DemoFrameSource  # type: ignore


class DemoFrameSourceTests(unittest.TestCase):
    def test_demo_sequence_starts_visible_motion_within_first_second(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        with patch("frame_source.time.perf_counter", return_value=0.3):
            idle_frame = source.get_latest_frame()
        with patch("frame_source.time.perf_counter", return_value=0.9):
            moving_frame = source.get_latest_frame()

        self.assertAlmostEqual(idle_frame.red.x, 860.0, delta=1.0)
        self.assertGreater(moving_frame.blue.x, idle_frame.blue.x + 20.0)
        self.assertGreater(moving_frame.blue.y, idle_frame.blue.y + 8.0)
        self.assertAlmostEqual(moving_frame.red.x, idle_frame.red.x, delta=1.0)
        self.assertAlmostEqual(moving_frame.red.y, idle_frame.red.y, delta=1.0)

    def test_demo_sequence_contains_idle_carry_and_release_moments(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        with patch("frame_source.time.perf_counter", return_value=1.0):
            idle_frame = source.get_latest_frame()
        with patch("frame_source.time.perf_counter", return_value=6.8):
            carry_frame = source.get_latest_frame()
        with patch("frame_source.time.perf_counter", return_value=11.0):
            release_frame = source.get_latest_frame()

        self.assertAlmostEqual(idle_frame.red.x, 860.0, delta=1.0)
        self.assertAlmostEqual(idle_frame.red.y, 620.0, delta=1.0)
        self.assertLess(idle_frame.blue.x, idle_frame.red.x - 80.0)

        self.assertGreater(carry_frame.blue.x, idle_frame.blue.x + 220.0)
        self.assertGreater(carry_frame.red.x, idle_frame.red.x + 120.0)
        self.assertLess(
            ((carry_frame.red.x - carry_frame.blue.x) ** 2 + (carry_frame.red.y - carry_frame.blue.y) ** 2)
            ** 0.5,
            72.0,
        )

        self.assertGreater(release_frame.red.x, 1000.0)
        self.assertLess(abs(release_frame.blue.x - release_frame.red.x), 55.0)
        self.assertLess(abs(release_frame.blue.y - release_frame.red.y), 55.0)

    def test_demo_sequence_has_visible_grab_dwell_before_carry(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        with patch("frame_source.time.perf_counter", return_value=4.2):
            dwell_start = source.get_latest_frame()
        with patch("frame_source.time.perf_counter", return_value=4.8):
            dwell_end = source.get_latest_frame()
        with patch("frame_source.time.perf_counter", return_value=6.4):
            carry_frame = source.get_latest_frame()

        self.assertLess(abs(dwell_start.blue.x - dwell_end.blue.x), 20.0)
        self.assertLess(abs(dwell_start.blue.y - dwell_end.blue.y), 20.0)
        self.assertLess(abs(dwell_start.blue.x - dwell_start.red.x), 80.0)
        self.assertLess(abs(dwell_end.blue.x - dwell_end.red.x), 80.0)
        self.assertGreater(carry_frame.blue.x, dwell_end.blue.x + 120.0)
        self.assertGreater(carry_frame.red.x, dwell_end.red.x + 120.0)

    def test_demo_sequence_keeps_object_at_drop_after_release(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        with patch("frame_source.time.perf_counter", return_value=11.5):
            release_frame = source.get_latest_frame()
        with patch("frame_source.time.perf_counter", return_value=11.8):
            settled_frame = source.get_latest_frame()

        self.assertAlmostEqual(settled_frame.red.x, release_frame.red.x, delta=2.0)
        self.assertAlmostEqual(settled_frame.red.y, release_frame.red.y, delta=2.0)
        self.assertGreaterEqual(settled_frame.blue.x, release_frame.blue.x + 40.0)

    def test_demo_sequence_opens_over_object_before_hand_retreats(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        with patch("frame_source.time.perf_counter", return_value=11.0):
            release_contact = source.get_latest_frame()
        with patch("frame_source.time.perf_counter", return_value=11.5):
            release_drop = source.get_latest_frame()
        with patch("frame_source.time.perf_counter", return_value=11.8):
            retreat_frame = source.get_latest_frame()

        release_gap = (
            (release_contact.blue.x - release_contact.red.x) ** 2
            + (release_contact.blue.y - release_contact.red.y) ** 2
        ) ** 0.5
        release_drop_gap = (
            (release_drop.blue.x - release_drop.red.x) ** 2
            + (release_drop.blue.y - release_drop.red.y) ** 2
        ) ** 0.5
        retreat_gap = (
            (retreat_frame.blue.x - retreat_frame.red.x) ** 2
            + (retreat_frame.blue.y - retreat_frame.red.y) ** 2
        ) ** 0.5

        self.assertLess(release_gap, 55.0)
        self.assertLess(release_drop_gap, 55.0)
        self.assertLess(
            release_drop_gap,
            retreat_gap,
        )
        self.assertGreater(retreat_gap, 140.0)
        self.assertAlmostEqual(retreat_frame.red.x, release_drop.red.x, delta=2.0)
        self.assertAlmostEqual(retreat_frame.red.y, release_drop.red.y, delta=2.0)

    def test_demo_sequence_restarts_after_final_pose_instead_of_freezing(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        with patch("frame_source.time.perf_counter", return_value=source._cycle_duration):
            final_frame = source.get_latest_frame()
        with patch("frame_source.time.perf_counter", return_value=source._cycle_duration + 0.5):
            restarted_frame = source.get_latest_frame()

        self.assertAlmostEqual(final_frame.red.x, 1319.0, delta=2.0)
        self.assertAlmostEqual(final_frame.blue.x, 1480.0, delta=2.0)
        self.assertLess(restarted_frame.blue.x, restarted_frame.red.x - 80.0)
        self.assertLess(restarted_frame.blue.x, final_frame.blue.x - 500.0)


if __name__ == "__main__":
    unittest.main()
