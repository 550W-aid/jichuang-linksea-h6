from pathlib import Path
import sys
import unittest
from unittest.mock import patch


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = PROJECT_ROOT / "src"
sys.path.insert(0, str(SRC_ROOT))

from frame_source import DemoFrameSource  # type: ignore
from grab_animation import GrabAnimationConfig, GrabAnimator  # type: ignore
from hand_style import build_hand_line_art  # type: ignore
from mapper import map_detection_to_virtual  # type: ignore
from model import VirtualBlob, VirtualFrame, VirtualPoint  # type: ignore
from renderer import RenderConfig  # type: ignore


DEFAULT_RENDER_CONFIG = RenderConfig()
RENDER_WIDTH = DEFAULT_RENDER_CONFIG.width
RENDER_HEIGHT = DEFAULT_RENDER_CONFIG.height
CYLINDER_HEIGHT = DEFAULT_RENDER_CONFIG.cylinder_height
HAND_HEIGHT = DEFAULT_RENDER_CONFIG.hand_height


def build_frame(frame_id: int, red_x: float, blue_x: float) -> VirtualFrame:
    return build_frame_2d(
        frame_id=frame_id,
        red_x=red_x,
        red_y=0.0,
        blue_x=blue_x,
        blue_y=0.0,
    )


def build_frame_2d(
    frame_id: int,
    red_x: float,
    red_y: float,
    blue_x: float,
    blue_y: float,
) -> VirtualFrame:
    return VirtualFrame(
        frame_id=frame_id,
        origin=VirtualPoint(0.0, 0.0),
        green=VirtualBlob(160.0, 0.0, 20.0),
        red=VirtualBlob(red_x, red_y, 20.0),
        blue=VirtualBlob(blue_x, blue_y, 24.0),
        pixels_per_world_unit=1.0,
    )


def project(x: float, y: float, z: float) -> tuple[float, float]:
    cx = RENDER_WIDTH * 0.48
    cy = RENDER_HEIGHT * 0.62
    sx = cx + x - 0.72 * y
    sy = cy + 0.38 * y - z
    return sx, sy


def stroke_bounds(strokes) -> tuple[float, float, float, float]:
    xs = [stroke.points[index] for stroke in strokes for index in range(0, len(stroke.points), 2)]
    ys = [stroke.points[index] for stroke in strokes for index in range(1, len(stroke.points), 2)]
    return min(xs), max(xs), min(ys), max(ys)


def project_with_render_config(config: RenderConfig, x: float, y: float, z: float) -> tuple[float, float]:
    cx = config.width * 0.48
    cy = config.height * 0.62
    return (
        cx + x - 0.72 * y,
        cy + 0.38 * y - z,
    )


def point_distance(ax: float, ay: float, bx: float, by: float) -> float:
    return ((ax - bx) ** 2 + (ay - by) ** 2) ** 0.5


class GrabAnimationTests(unittest.TestCase):
    def test_demo_holding_pose_changes_are_large_enough_to_read_visually(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        idle_scene = None
        holding_scene = None

        for frame_index in range(0, 241):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            mapped = map_detection_to_virtual(frame, green_distance=160.0)
            scene = animator.update(mapped)
            if idle_scene is None and abs(t - 1.0) < 1e-9:
                idle_scene = scene
            if holding_scene is None and abs(t - 6.0) < 1e-9:
                holding_scene = scene
                break

        assert idle_scene is not None
        assert holding_scene is not None

        self.assertGreater(
            abs(holding_scene.hand_pitch_deg - idle_scene.hand_pitch_deg),
            35.0,
        )
        self.assertGreater(
            holding_scene.hand_scale - idle_scene.hand_scale,
            0.25,
        )
        self.assertGreater(
            abs(holding_scene.hand_height_offset - idle_scene.hand_height_offset),
            26.0,
        )

    def test_demo_release_begins_soon_enough_to_be_visible_without_waiting_too_long(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        release_time = None

        for frame_index in range(0, 420):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            mapped = map_detection_to_virtual(frame, green_distance=160.0)
            scene = animator.update(mapped)
            if scene.grab_phase == "releasing":
                release_time = t
                break

        assert release_time is not None
        self.assertLessEqual(release_time, 11.5)

    def test_closing_and_holding_apply_visible_hand_scale_change(self) -> None:
        animator = GrabAnimator(
            GrabAnimationConfig(
                grab_distance=52.0,
                release_distance=120.0,
                attach_response=0.3,
                release_response=0.25,
                min_closing_frames=8,
                release_hold_frames=2,
                settle_epsilon=1.0,
            )
        )

        idle = animator.update(build_frame_2d(frame_id=1, red_x=24.0, red_y=-10.0, blue_x=140.0, blue_y=8.0))
        closing = animator.update(build_frame_2d(frame_id=2, red_x=24.0, red_y=-10.0, blue_x=0.0, blue_y=0.0))
        for frame_id in range(3, 16):
            holding = animator.update(
                build_frame_2d(frame_id=frame_id, red_x=24.0, red_y=-10.0, blue_x=0.0, blue_y=0.0)
            )
        releasing = animator.update(build_frame_2d(frame_id=16, red_x=24.0, red_y=-10.0, blue_x=180.0, blue_y=0.0))
        releasing = animator.update(build_frame_2d(frame_id=17, red_x=24.0, red_y=-10.0, blue_x=180.0, blue_y=0.0))

        self.assertEqual(idle.grab_phase, "idle")
        self.assertLess(idle.hand_scale, 1.0)
        self.assertEqual(closing.grab_phase, "closing")
        self.assertGreater(closing.hand_scale, idle.hand_scale + 0.10)
        self.assertEqual(holding.grab_phase, "holding")
        self.assertGreater(holding.hand_scale, idle.hand_scale + 0.14)
        self.assertEqual(releasing.grab_phase, "releasing")
        self.assertLess(releasing.hand_scale, closing.hand_scale)

    def test_holding_uses_dedicated_hold_pose_after_closing(self) -> None:
        config = GrabAnimationConfig(
            grab_distance=52.0,
            release_distance=120.0,
            attach_response=0.3,
            release_response=0.25,
            min_closing_frames=8,
            release_hold_frames=2,
            settle_epsilon=1.0,
        )
        animator = GrabAnimator(config)

        animator.update(
            build_frame_2d(frame_id=1, red_x=24.0, red_y=-10.0, blue_x=140.0, blue_y=8.0)
        )
        animator.update(
            build_frame_2d(frame_id=2, red_x=24.0, red_y=-10.0, blue_x=0.0, blue_y=0.0)
        )

        holding = None
        for frame_id in range(3, 24):
            scene = animator.update(
                build_frame_2d(frame_id=frame_id, red_x=24.0, red_y=-10.0, blue_x=0.0, blue_y=0.0)
            )
            if scene.grab_phase == "holding":
                holding = scene
                break

        assert holding is not None
        self.assertEqual(holding.grab_phase, "holding")
        self.assertAlmostEqual(holding.hand_height_offset, config.hand_height_holding, delta=0.5)
        self.assertAlmostEqual(holding.hand_pitch_deg, config.hand_pitch_holding, delta=0.5)
        self.assertAlmostEqual(holding.hand_scale, config.hand_scale_holding, delta=0.02)
        self.assertAlmostEqual(
            holding.hand_display.x - holding.frame.blue.x,
            config.hand_offset_x_holding,
            delta=0.5,
        )
        self.assertAlmostEqual(
            holding.hand_display.y - holding.frame.blue.y,
            config.hand_offset_y_holding,
            delta=0.5,
        )

    def test_holding_filters_small_blue_tracking_jitter(self) -> None:
        config = GrabAnimationConfig(
            grab_distance=16.0,
            release_distance=120.0,
            attach_response=1.0,
            release_response=0.25,
            min_closing_frames=1,
            release_hold_frames=3,
            settle_epsilon=1.0,
        )
        animator = GrabAnimator(config)

        animator.update(
            build_frame_2d(frame_id=1, red_x=8.0, red_y=-4.0, blue_x=80.0, blue_y=0.0)
        )
        animator.update(
            build_frame_2d(frame_id=2, red_x=8.0, red_y=-4.0, blue_x=0.0, blue_y=0.0)
        )

        holding = None
        for frame_id in range(3, 8):
            scene = animator.update(
                build_frame_2d(frame_id=frame_id, red_x=8.0, red_y=-4.0, blue_x=0.0, blue_y=0.0)
            )
            if scene.grab_phase == "holding":
                holding = scene
                break

        assert holding is not None
        baseline_hand = holding.hand_display
        baseline_anchor = holding.grasp_anchor

        jitter_samples = [
            (1.2, -0.8),
            (-1.1, 0.7),
            (0.9, 1.0),
            (-0.7, -1.2),
            (1.4, 0.5),
        ]
        hand_span = 0.0
        anchor_span = 0.0
        next_frame_id = holding.frame.frame_id + 1
        for offset_x, offset_y in jitter_samples:
            scene = animator.update(
                build_frame_2d(
                    frame_id=next_frame_id,
                    red_x=8.0,
                    red_y=-4.0,
                    blue_x=offset_x,
                    blue_y=offset_y,
                )
            )
            next_frame_id += 1
            self.assertEqual(scene.grab_phase, "holding")
            hand_span = max(
                hand_span,
                point_distance(
                    scene.hand_display.x,
                    scene.hand_display.y,
                    baseline_hand.x,
                    baseline_hand.y,
                ),
            )
            anchor_span = max(
                anchor_span,
                point_distance(
                    scene.grasp_anchor.x,
                    scene.grasp_anchor.y,
                    baseline_anchor.x,
                    baseline_anchor.y,
                ),
            )

        self.assertLess(hand_span, 0.5)
        self.assertLess(anchor_span, 0.5)

    def test_holding_filters_moderate_blue_tracking_jitter_above_deadband(self) -> None:
        config = GrabAnimationConfig(
            grab_distance=16.0,
            release_distance=120.0,
            attach_response=1.0,
            release_response=0.25,
            min_closing_frames=1,
            release_hold_frames=3,
            settle_epsilon=1.0,
        )
        animator = GrabAnimator(config)

        animator.update(
            build_frame_2d(frame_id=1, red_x=8.0, red_y=-4.0, blue_x=80.0, blue_y=0.0)
        )
        animator.update(
            build_frame_2d(frame_id=2, red_x=8.0, red_y=-4.0, blue_x=0.0, blue_y=0.0)
        )

        holding = None
        for frame_id in range(3, 8):
            scene = animator.update(
                build_frame_2d(frame_id=frame_id, red_x=8.0, red_y=-4.0, blue_x=0.0, blue_y=0.0)
            )
            if scene.grab_phase == "holding":
                holding = scene
                break

        assert holding is not None
        baseline_hand = holding.hand_display
        baseline_anchor = holding.grasp_anchor

        jitter_samples = [
            (2.3, -1.8),
            (-2.1, 1.9),
            (1.7, 2.4),
            (-2.4, -1.6),
            (2.0, 2.1),
        ]
        hand_span = 0.0
        anchor_span = 0.0
        next_frame_id = holding.frame.frame_id + 1
        for offset_x, offset_y in jitter_samples:
            scene = animator.update(
                build_frame_2d(
                    frame_id=next_frame_id,
                    red_x=8.0,
                    red_y=-4.0,
                    blue_x=offset_x,
                    blue_y=offset_y,
                )
            )
            next_frame_id += 1
            self.assertEqual(scene.grab_phase, "holding")
            hand_span = max(
                hand_span,
                point_distance(
                    scene.hand_display.x,
                    scene.hand_display.y,
                    baseline_hand.x,
                    baseline_hand.y,
                ),
            )
            anchor_span = max(
                anchor_span,
                point_distance(
                    scene.grasp_anchor.x,
                    scene.grasp_anchor.y,
                    baseline_anchor.x,
                    baseline_anchor.y,
                ),
            )

        self.assertLess(hand_span, 0.9)
        self.assertLess(anchor_span, 0.9)

    def test_holding_follows_consistent_low_speed_carry_without_offset_drift(self) -> None:
        config = GrabAnimationConfig(
            grab_distance=16.0,
            release_distance=120.0,
            attach_response=1.0,
            release_response=0.25,
            min_closing_frames=1,
            release_hold_frames=3,
            settle_epsilon=1.0,
        )
        animator = GrabAnimator(config)

        animator.update(
            build_frame_2d(frame_id=1, red_x=8.0, red_y=-4.0, blue_x=80.0, blue_y=0.0)
        )
        animator.update(
            build_frame_2d(frame_id=2, red_x=8.0, red_y=-4.0, blue_x=0.0, blue_y=0.0)
        )

        holding = animator.update(
            build_frame_2d(frame_id=3, red_x=8.0, red_y=-4.0, blue_x=0.0, blue_y=0.0)
        )
        self.assertEqual(holding.grab_phase, "holding")

        carry_frames = [
            build_frame_2d(frame_id=4, red_x=9.6, red_y=-4.0, blue_x=1.6, blue_y=0.0),
            build_frame_2d(frame_id=5, red_x=11.2, red_y=-4.0, blue_x=3.2, blue_y=0.0),
            build_frame_2d(frame_id=6, red_x=12.8, red_y=-4.0, blue_x=4.8, blue_y=0.0),
        ]
        final_scene = holding
        for frame in carry_frames:
            final_scene = animator.update(frame)
            self.assertEqual(final_scene.grab_phase, "holding")

        offset_error = point_distance(
            final_scene.hand_display.x - final_scene.frame.blue.x,
            final_scene.hand_display.y - final_scene.frame.blue.y,
            config.hand_offset_x_holding,
            config.hand_offset_y_holding,
        )
        self.assertLess(offset_error, 0.1)

    def test_demo_holding_keeps_hand_outline_over_cylinder_top(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        holding_scene = None

        for frame_index in range(0, 181):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            mapped = map_detection_to_virtual(frame, green_distance=160.0)
            scene = animator.update(mapped)
            if abs(t - 6.0) < 1e-9:
                holding_scene = scene
                break

        assert holding_scene is not None
        self.assertEqual(holding_scene.grab_phase, "holding")

        hand_center = project(
            holding_scene.hand_display.x,
            holding_scene.hand_display.y,
            HAND_HEIGHT + holding_scene.hand_height_offset,
        )
        red_top = project(
            holding_scene.red_display.x,
            holding_scene.red_display.y,
            CYLINDER_HEIGHT,
        )
        hand_bounds = stroke_bounds(
            build_hand_line_art(
                hand_center[0],
                hand_center[1],
                28.0,
                grip=holding_scene.hand_grip,
                rotation_deg=holding_scene.hand_pitch_deg,
            )
        )

        self.assertGreaterEqual(red_top[0], hand_bounds[0] - 4.0)
        self.assertLessEqual(red_top[0], hand_bounds[1] + 4.0)
        self.assertLessEqual(red_top[1], hand_bounds[3] + 3.0)

    def test_demo_grab_closing_lasts_long_enough_to_read_visually(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        current_streak = 0
        max_streak = 0

        for frame_index in range(0, 420):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            mapped = map_detection_to_virtual(frame, green_distance=160.0)
            scene = animator.update(mapped)
            if scene.grab_phase == "closing":
                current_streak += 1
                max_streak = max(max_streak, current_streak)
            else:
                current_streak = 0

        self.assertGreaterEqual(max_streak, 24)

    def test_grab_transition_settles_into_holding_without_extra_pose_jump(self) -> None:
        animator = GrabAnimator(
            GrabAnimationConfig(
                grab_distance=52.0,
                release_distance=120.0,
                attach_response=0.3,
                release_response=0.25,
                min_closing_frames=8,
                release_hold_frames=2,
                settle_epsilon=1.0,
            )
        )

        animator.update(build_frame_2d(frame_id=1, red_x=24.0, red_y=-10.0, blue_x=140.0, blue_y=8.0))
        closing_samples = []
        holding = None

        closing = animator.update(build_frame_2d(frame_id=2, red_x=24.0, red_y=-10.0, blue_x=0.0, blue_y=0.0))
        closing_samples.append(closing)
        for frame_id in range(3, 16):
            scene = animator.update(
                build_frame_2d(frame_id=frame_id, red_x=24.0, red_y=-10.0, blue_x=0.0, blue_y=0.0)
            )
            if scene.grab_phase == "closing":
                closing_samples.append(scene)
            elif scene.grab_phase == "holding" and holding is None:
                holding = scene

        assert closing_samples
        assert holding is not None

        late_closing = closing_samples[-1]

        self.assertEqual(closing.grab_phase, "closing")
        self.assertEqual(holding.grab_phase, "holding")
        self.assertLess(
            abs(holding.hand_height_offset - late_closing.hand_height_offset),
            1.0,
        )
        self.assertLess(
            abs(holding.hand_pitch_deg - late_closing.hand_pitch_deg),
            1.0,
        )
        self.assertLess(
            abs(holding.hand_scale - late_closing.hand_scale),
            0.05,
        )
        self.assertLess(
            point_distance(
                holding.hand_display.x,
                holding.hand_display.y,
                late_closing.hand_display.x,
                late_closing.hand_display.y,
            ),
            8.0,
        )

    def test_latches_and_drags_cylinder_with_hand(self) -> None:
        animator = GrabAnimator(
            GrabAnimationConfig(
                grab_distance=16.0,
                release_distance=48.0,
                attach_response=0.5,
                release_response=0.25,
                release_hold_frames=2,
            )
        )

        idle_scene = animator.update(build_frame(frame_id=1, red_x=0.0, blue_x=50.0))
        closing_scene = animator.update(build_frame(frame_id=2, red_x=0.0, blue_x=10.0))
        carry_scene = animator.update(build_frame(frame_id=3, red_x=0.0, blue_x=30.0))

        self.assertEqual(idle_scene.grab_phase, "idle")
        self.assertFalse(idle_scene.is_grabbed)
        self.assertTrue(closing_scene.is_grabbed)
        self.assertIn(closing_scene.grab_phase, {"closing", "holding"})
        self.assertGreater(carry_scene.red_display.x, closing_scene.red_display.x)
        self.assertIn(carry_scene.grab_phase, {"closing", "holding"})

    def test_releases_after_hysteresis_and_holds_release_anchor_until_red_reacquires(self) -> None:
        animator = GrabAnimator(
            GrabAnimationConfig(
                grab_distance=16.0,
                release_distance=48.0,
                attach_response=0.38,
                release_response=0.5,
                min_closing_frames=1,
                release_hold_frames=2,
            )
        )

        animator.update(build_frame(frame_id=1, red_x=0.0, blue_x=10.0))
        latched_scene = animator.update(build_frame(frame_id=2, red_x=20.0, blue_x=30.0))
        for frame_id in range(3, 20):
            tracking_scene = animator.update(build_frame(frame_id=frame_id, red_x=40.0, blue_x=50.0))
        still_held_scene = animator.update(build_frame(frame_id=20, red_x=40.0, blue_x=100.0))
        releasing_scene = animator.update(build_frame(frame_id=21, red_x=40.0, blue_x=100.0))

        self.assertTrue(latched_scene.is_grabbed)
        self.assertIn(tracking_scene.grab_phase, {"closing", "holding"})
        self.assertTrue(still_held_scene.is_grabbed)
        self.assertEqual(still_held_scene.grab_phase, "holding")
        self.assertFalse(releasing_scene.is_grabbed)
        self.assertEqual(releasing_scene.grab_phase, "releasing")
        self.assertAlmostEqual(releasing_scene.red_display.x, still_held_scene.red_display.x, delta=0.25)
        self.assertAlmostEqual(releasing_scene.red_display.y, still_held_scene.red_display.y, delta=0.25)
        self.assertGreater(releasing_scene.red_display.x, 0.0)

    def test_release_snaps_back_to_raw_red_on_large_resync_jump(self) -> None:
        config = GrabAnimationConfig(
            grab_distance=18.0,
            release_distance=48.0,
            attach_response=1.0,
            release_response=0.5,
            min_closing_frames=1,
            release_hold_frames=2,
            release_arm_frames=2,
            release_arm_ready_frames=1,
        )
        animator = GrabAnimator(config)
        anchor_x = 20.0 * config.grasp_anchor_x_ratio
        anchor_y = 20.0 * config.grasp_anchor_y_ratio

        animator.update(build_frame_2d(frame_id=1, red_x=anchor_x, red_y=anchor_y, blue_x=120.0, blue_y=0.0))
        animator.update(build_frame_2d(frame_id=2, red_x=anchor_x, red_y=anchor_y, blue_x=0.0, blue_y=0.0))
        holding_scene = animator.update(
            build_frame_2d(frame_id=3, red_x=45.0 + anchor_x, red_y=anchor_y, blue_x=45.0, blue_y=0.0)
        )
        animator.update(build_frame_2d(frame_id=4, red_x=45.0 + anchor_x, red_y=anchor_y, blue_x=100.0, blue_y=0.0))
        releasing_scene = animator.update(
            build_frame_2d(frame_id=5, red_x=45.0 + anchor_x, red_y=anchor_y, blue_x=100.0, blue_y=0.0)
        )
        after_jump_1 = animator.update(
            build_frame_2d(frame_id=6, red_x=-140.0, red_y=-80.0, blue_x=100.0, blue_y=0.0)
        )
        after_jump_2 = animator.update(
            build_frame_2d(frame_id=7, red_x=-140.0, red_y=-80.0, blue_x=100.0, blue_y=0.0)
        )

        self.assertEqual(holding_scene.grab_phase, "holding")
        self.assertEqual(releasing_scene.grab_phase, "releasing")
        self.assertEqual(after_jump_1.grab_phase, "idle")
        self.assertEqual(after_jump_2.grab_phase, "idle")
        self.assertAlmostEqual(after_jump_1.red_display.x, -140.0, delta=0.25)
        self.assertAlmostEqual(after_jump_1.red_display.y, -80.0, delta=0.25)
        self.assertAlmostEqual(after_jump_2.red_display.x, -140.0, delta=0.25)
        self.assertAlmostEqual(after_jump_2.red_display.y, -80.0, delta=0.25)

    def test_release_reacquires_raw_red_after_contact_window(self) -> None:
        config = GrabAnimationConfig(
            grab_distance=18.0,
            release_distance=48.0,
            attach_response=1.0,
            release_response=0.35,
            min_closing_frames=1,
            release_hold_frames=2,
            release_arm_frames=2,
            release_arm_ready_frames=1,
            release_contact_frames=8,
            min_releasing_frames=10,
        )
        animator = GrabAnimator(config)
        anchor_x = 20.0 * config.grasp_anchor_x_ratio
        anchor_y = 20.0 * config.grasp_anchor_y_ratio

        animator.update(build_frame_2d(frame_id=1, red_x=anchor_x, red_y=anchor_y, blue_x=120.0, blue_y=0.0))
        animator.update(build_frame_2d(frame_id=2, red_x=anchor_x, red_y=anchor_y, blue_x=0.0, blue_y=0.0))
        for frame_id in range(3, 8):
            animator.update(
                build_frame_2d(frame_id=frame_id, red_x=45.0 + anchor_x, red_y=anchor_y, blue_x=45.0, blue_y=0.0)
            )
        animator.update(
            build_frame_2d(frame_id=8, red_x=45.0 + anchor_x, red_y=anchor_y, blue_x=100.0, blue_y=0.0)
        )
        releasing_scene = animator.update(
            build_frame_2d(frame_id=9, red_x=45.0 + anchor_x, red_y=anchor_y, blue_x=100.0, blue_y=0.0)
        )

        settle_scene = releasing_scene
        raw_drop = (130.0, -70.0)
        for frame_id in range(10, 42):
            settle_scene = animator.update(
                build_frame_2d(
                    frame_id=frame_id,
                    red_x=raw_drop[0],
                    red_y=raw_drop[1],
                    blue_x=100.0,
                    blue_y=0.0,
                )
            )

        self.assertEqual(releasing_scene.grab_phase, "releasing")
        self.assertEqual(settle_scene.grab_phase, "idle")
        self.assertLess(
            point_distance(
                settle_scene.red_display.x,
                settle_scene.red_display.y,
                raw_drop[0],
                raw_drop[1],
            ),
            6.0,
        )
        self.assertGreater(
            point_distance(
                settle_scene.red_display.x,
                settle_scene.red_display.y,
                releasing_scene.red_display.x,
                releasing_scene.red_display.y,
            ),
            40.0,
        )

    def test_release_opens_in_place_before_hand_retreats(self) -> None:
        config = GrabAnimationConfig(
            grab_distance=18.0,
            release_distance=48.0,
            attach_response=1.0,
            release_response=0.5,
            min_closing_frames=1,
            release_hold_frames=2,
            release_arm_frames=2,
            release_arm_ready_frames=1,
        )
        animator = GrabAnimator(config)
        initial_red = (20.0 * config.grasp_anchor_x_ratio, 20.0 * config.grasp_anchor_y_ratio)

        animator.update(
            build_frame_2d(frame_id=1, red_x=initial_red[0], red_y=initial_red[1], blue_x=120.0, blue_y=0.0)
        )
        animator.update(
            build_frame_2d(frame_id=2, red_x=initial_red[0], red_y=initial_red[1], blue_x=0.0, blue_y=0.0)
        )
        holding_scene = animator.update(
            build_frame_2d(frame_id=3, red_x=initial_red[0], red_y=initial_red[1], blue_x=0.0, blue_y=0.0)
        )
        animator.update(
            build_frame_2d(frame_id=4, red_x=initial_red[0], red_y=initial_red[1], blue_x=100.0, blue_y=0.0)
        )
        releasing_1 = animator.update(
            build_frame_2d(frame_id=5, red_x=initial_red[0], red_y=initial_red[1], blue_x=100.0, blue_y=0.0)
        )
        releasing_2 = animator.update(
            build_frame_2d(frame_id=6, red_x=initial_red[0], red_y=initial_red[1], blue_x=100.0, blue_y=0.0)
        )

        self.assertEqual(holding_scene.grab_phase, "holding")
        self.assertEqual(releasing_1.grab_phase, "releasing")
        self.assertEqual(releasing_2.grab_phase, "releasing")
        self.assertLess(
            point_distance(
                releasing_1.red_display.x,
                releasing_1.red_display.y,
                releasing_1.grasp_anchor.x,
                releasing_1.grasp_anchor.y,
            ),
            1.5,
        )
        self.assertLess(
            point_distance(
                releasing_2.red_display.x,
                releasing_2.red_display.y,
                releasing_2.grasp_anchor.x,
                releasing_2.grasp_anchor.y,
            ),
            1.5,
        )
        self.assertAlmostEqual(releasing_1.red_display.x, releasing_2.red_display.x, delta=0.5)
        self.assertAlmostEqual(releasing_1.red_display.y, releasing_2.red_display.y, delta=0.5)
        self.assertLess(releasing_2.hand_pitch_deg, -12.0)
        self.assertLess(releasing_2.hand_scale, holding_scene.hand_scale)

    def test_holding_keeps_object_attached_even_if_raw_red_stalls(self) -> None:
        config = GrabAnimationConfig(
                grab_distance=16.0,
                release_distance=120.0,
                attach_response=1.0,
                release_response=0.5,
                min_closing_frames=1,
                release_hold_frames=2,
        )
        animator = GrabAnimator(config)

        animator.update(build_frame(frame_id=1, red_x=0.0, blue_x=50.0))
        grab_scene = animator.update(build_frame(frame_id=2, red_x=0.0, blue_x=10.0))
        carry_scene_1 = animator.update(build_frame(frame_id=3, red_x=0.0, blue_x=30.0))
        carry_scene_2 = animator.update(build_frame(frame_id=4, red_x=0.0, blue_x=50.0))
        expected_x = carry_scene_1.frame.red.radius * config.grasp_anchor_x_ratio
        expected_y = carry_scene_1.frame.red.radius * config.grasp_anchor_y_ratio

        self.assertTrue(grab_scene.is_grabbed)
        self.assertEqual(carry_scene_1.grab_phase, "holding")
        self.assertEqual(carry_scene_2.grab_phase, "holding")
        self.assertGreater(point_distance(
            carry_scene_1.hand_display.x,
            carry_scene_1.hand_display.y,
            carry_scene_1.frame.blue.x,
            carry_scene_1.frame.blue.y,
        ), 6.0)
        self.assertAlmostEqual(carry_scene_1.red_display.x, carry_scene_1.grasp_anchor.x, delta=1.0)
        self.assertAlmostEqual(carry_scene_2.red_display.x, carry_scene_2.grasp_anchor.x, delta=1.0)
        self.assertAlmostEqual(carry_scene_1.red_display.y, carry_scene_1.grasp_anchor.y, delta=1.0)
        self.assertAlmostEqual(carry_scene_2.red_display.y, carry_scene_2.grasp_anchor.y, delta=1.0)
        self.assertGreater(
            point_distance(
                carry_scene_1.grasp_anchor.x,
                carry_scene_1.grasp_anchor.y,
                carry_scene_1.hand_display.x,
                carry_scene_1.hand_display.y,
            ),
            1.0,
        )
        self.assertGreater(
            point_distance(
                carry_scene_2.grasp_anchor.x,
                carry_scene_2.grasp_anchor.y,
                carry_scene_2.hand_display.x,
                carry_scene_2.hand_display.y,
            ),
            1.0,
        )
        self.assertGreater(carry_scene_2.red_display.x, carry_scene_1.red_display.x)

    def test_grabbed_object_stays_rigidly_attached_with_default_attach_response_after_settle(self) -> None:
        config = GrabAnimationConfig(
                grab_distance=16.0,
                release_distance=120.0,
                attach_response=0.38,
                release_response=0.24,
                min_closing_frames=1,
                release_hold_frames=3,
        )
        animator = GrabAnimator(config)

        animator.update(build_frame(frame_id=1, red_x=0.0, blue_x=50.0))
        for frame_id in range(2, 12):
            settled_scene = animator.update(build_frame(frame_id=frame_id, red_x=0.0, blue_x=10.0))
        carry_scene_1 = animator.update(build_frame(frame_id=12, red_x=0.0, blue_x=30.0))
        carry_scene_2 = animator.update(build_frame(frame_id=13, red_x=0.0, blue_x=50.0))

        self.assertTrue(carry_scene_1.is_grabbed)
        self.assertTrue(carry_scene_2.is_grabbed)
        self.assertEqual(settled_scene.grab_phase, "holding")
        self.assertLess(
            point_distance(
                carry_scene_1.red_display.x,
                carry_scene_1.red_display.y,
                carry_scene_1.grasp_anchor.x,
                carry_scene_1.grasp_anchor.y,
            ),
            0.25,
        )
        self.assertLess(
            point_distance(
                carry_scene_2.red_display.x,
                carry_scene_2.red_display.y,
                carry_scene_2.grasp_anchor.x,
                carry_scene_2.grasp_anchor.y,
            ),
            0.25,
        )
        self.assertGreater(carry_scene_2.red_display.x, carry_scene_1.red_display.x)
        self.assertGreater(point_distance(
            carry_scene_2.hand_display.x,
            carry_scene_2.hand_display.y,
            carry_scene_2.frame.blue.x,
            carry_scene_2.frame.blue.y,
        ), 4.0)

    def test_grab_settles_to_canonical_palm_anchor_instead_of_preserving_raw_offset(self) -> None:
        config = GrabAnimationConfig(
            grab_distance=60.0,
            release_distance=120.0,
            attach_response=0.32,
            release_response=0.24,
            min_closing_frames=8,
            release_hold_frames=3,
            settle_epsilon=1.0,
        )
        animator = GrabAnimator(config)

        animator.update(build_frame_2d(frame_id=1, red_x=18.0, red_y=-4.0, blue_x=140.0, blue_y=0.0))
        animator.update(build_frame_2d(frame_id=2, red_x=18.0, red_y=-4.0, blue_x=0.0, blue_y=0.0))
        for frame_id in range(3, 18):
            holding_scene = animator.update(
                build_frame_2d(frame_id=frame_id, red_x=18.0, red_y=-4.0, blue_x=0.0, blue_y=0.0)
            )

        self.assertEqual(holding_scene.grab_phase, "holding")
        self.assertGreater(point_distance(
            holding_scene.hand_display.x,
            holding_scene.hand_display.y,
            holding_scene.frame.blue.x,
            holding_scene.frame.blue.y,
        ), 2.0)
        self.assertLess(
            point_distance(
                holding_scene.red_display.x,
                holding_scene.red_display.y,
                holding_scene.grasp_anchor.x,
                holding_scene.grasp_anchor.y,
            ),
            0.75,
        )
        self.assertGreater(
            point_distance(
                holding_scene.red_display.x,
                holding_scene.red_display.y,
                holding_scene.frame.red.x,
                holding_scene.frame.red.y,
            ),
            6.0,
        )

    def test_grab_closing_spends_multiple_frames_pulling_object_into_hand_anchor(self) -> None:
        animator = GrabAnimator(
            GrabAnimationConfig(
                grab_distance=52.0,
                release_distance=110.0,
                attach_response=0.3,
                release_response=0.25,
                min_closing_frames=8,
                release_hold_frames=2,
                settle_epsilon=1.5,
            )
        )

        animator.update(build_frame_2d(frame_id=1, red_x=36.0, red_y=-24.0, blue_x=140.0, blue_y=12.0))
        closing_1 = animator.update(build_frame_2d(frame_id=2, red_x=36.0, red_y=-24.0, blue_x=0.0, blue_y=0.0))
        closing_2 = animator.update(build_frame_2d(frame_id=3, red_x=36.0, red_y=-24.0, blue_x=0.0, blue_y=0.0))
        late_closing = animator.update(build_frame_2d(frame_id=4, red_x=36.0, red_y=-24.0, blue_x=0.0, blue_y=0.0))
        for frame_id in range(5, 13):
            holding = animator.update(build_frame_2d(frame_id=frame_id, red_x=36.0, red_y=-24.0, blue_x=0.0, blue_y=0.0))

        raw_distance = ((36.0**2) + (24.0**2)) ** 0.5
        closing_1_distance = ((closing_1.red_display.x - closing_1.hand_display.x) ** 2 + (closing_1.red_display.y - closing_1.hand_display.y) ** 2) ** 0.5
        closing_2_distance = ((closing_2.red_display.x - closing_2.hand_display.x) ** 2 + (closing_2.red_display.y - closing_2.hand_display.y) ** 2) ** 0.5
        late_closing_distance = ((late_closing.red_display.x - late_closing.hand_display.x) ** 2 + (late_closing.red_display.y - late_closing.hand_display.y) ** 2) ** 0.5
        holding_distance = ((holding.red_display.x - holding.hand_display.x) ** 2 + (holding.red_display.y - holding.hand_display.y) ** 2) ** 0.5

        self.assertEqual(closing_1.grab_phase, "closing")
        self.assertEqual(closing_2.grab_phase, "closing")
        self.assertLess(closing_2_distance, closing_1_distance)
        self.assertLess(late_closing_distance, raw_distance - 18.0)
        self.assertLess(holding_distance, raw_distance - 10.0)
        self.assertEqual(holding.grab_phase, "holding")

    def test_demo_cycle_releases_only_once_and_not_mid_carry(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        release_times: list[float] = []
        was_grabbed = False

        for frame_index in range(0, 420):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            mapped = map_detection_to_virtual(frame, green_distance=160.0)
            scene = animator.update(mapped)
            if was_grabbed and not scene.is_grabbed:
                release_times.append(t)
            was_grabbed = scene.is_grabbed

        self.assertEqual(len(release_times), 1)
        self.assertGreater(release_times[0], 7.0)

    def test_demo_cycle_grabs_only_once_before_reset(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        grab_times: list[float] = []
        release_times: list[float] = []
        was_grabbed = False

        for frame_index in range(0, 420):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            mapped = map_detection_to_virtual(frame, green_distance=160.0)
            scene = animator.update(mapped)
            if not was_grabbed and scene.is_grabbed:
                grab_times.append(t)
            if was_grabbed and not scene.is_grabbed:
                release_times.append(t)
            was_grabbed = scene.is_grabbed

        self.assertEqual(len(grab_times), 1)
        self.assertEqual(len(release_times), 1)
        self.assertLess(grab_times[0], release_times[0])

    def test_demo_cycle_keeps_closing_visible_long_enough_to_read_as_a_grab(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        closing_frames = 0

        for frame_index in range(0, 361):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            mapped = map_detection_to_virtual(frame, green_distance=160.0)
            scene = animator.update(mapped)
            if scene.grab_phase == "closing":
                closing_frames += 1

        self.assertGreaterEqual(closing_frames, 24)

    def test_demo_grab_starts_only_after_hand_reaches_contact_zone(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        first_closing_scene = None

        for frame_index in range(0, 361):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            scene = animator.update(map_detection_to_virtual(frame, green_distance=160.0))
            if scene.grab_phase == "closing":
                first_closing_scene = scene
                break

        assert first_closing_scene is not None
        raw_gap = point_distance(
            first_closing_scene.frame.red.x,
            first_closing_scene.frame.red.y,
            first_closing_scene.frame.blue.x,
            first_closing_scene.frame.blue.y,
        )
        self.assertLess(raw_gap, 65.0)

    def test_demo_closing_keeps_visible_pose_progress_through_late_frames(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        closing_grips: list[float] = []
        closing_scales: list[float] = []
        closing_heights: list[float] = []

        for frame_index in range(0, 361):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            scene = animator.update(map_detection_to_virtual(frame, green_distance=160.0))
            if scene.grab_phase == "closing":
                closing_grips.append(scene.hand_grip)
                closing_scales.append(scene.hand_scale)
                closing_heights.append(scene.hand_height_offset)

        self.assertGreaterEqual(len(closing_grips), 20)
        self.assertGreater(max(closing_grips[-12:]) - min(closing_grips[-12:]), 0.08)
        self.assertGreater(max(closing_scales[-12:]) - min(closing_scales[-12:]), 0.05)
        self.assertGreater(max(closing_heights[-12:]) - min(closing_heights[-12:]), 4.0)

    def test_demo_holding_keeps_pose_stable_during_carry(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        hand_height_offsets: list[float] = []
        hand_pitches: list[float] = []
        hand_scales: list[float] = []
        hand_grips: list[float] = []
        hand_offsets: list[float] = []

        for frame_index in range(0, 361):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            scene = animator.update(map_detection_to_virtual(frame, green_distance=160.0))
            if 5.2 <= t <= 8.6 and scene.grab_phase == "holding":
                hand_height_offsets.append(scene.hand_height_offset)
                hand_pitches.append(scene.hand_pitch_deg)
                hand_scales.append(scene.hand_scale)
                hand_grips.append(scene.hand_grip)
                hand_offsets.append(
                    point_distance(
                        scene.hand_display.x,
                        scene.hand_display.y,
                        scene.frame.blue.x,
                        scene.frame.blue.y,
                    )
                )

        self.assertGreaterEqual(len(hand_height_offsets), 60)
        self.assertLess(max(hand_height_offsets) - min(hand_height_offsets), 0.2)
        self.assertLess(max(hand_pitches) - min(hand_pitches), 0.5)
        self.assertLess(max(hand_scales) - min(hand_scales), 0.01)
        self.assertLess(max(hand_grips) - min(hand_grips), 0.01)
        self.assertLess(max(hand_offsets) - min(hand_offsets), 1.0)

    def test_demo_holding_keeps_grip_stable_within_visible_pose_range(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        holding_grips: list[float] = []

        for frame_index in range(0, 361):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            scene = animator.update(map_detection_to_virtual(frame, green_distance=160.0))
            if 5.2 <= t <= 8.6 and scene.grab_phase == "holding":
                holding_grips.append(scene.hand_grip)

        self.assertGreaterEqual(len(holding_grips), 60)
        self.assertLessEqual(max(holding_grips), 1.0)
        self.assertLess(max(holding_grips) - min(holding_grips), 0.01)

    def test_demo_holding_stabilizer_keeps_local_hand_offset_within_small_tracking_band(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        config = RenderConfig()
        local_screen_offsets: list[tuple[float, float]] = []
        hand_grips: list[float] = []

        for frame_index in range(0, 361):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            scene = animator.update(map_detection_to_virtual(frame, green_distance=160.0))
            if 5.2 <= t <= 8.6 and scene.grab_phase == "holding":
                hand_screen = project_with_render_config(
                    config,
                    scene.hand_display.x,
                    scene.hand_display.y,
                    config.hand_height + scene.hand_height_offset,
                )
                raw_blue_screen = project_with_render_config(
                    config,
                    scene.frame.blue.x,
                    scene.frame.blue.y,
                    config.hand_height,
                )
                local_screen_offsets.append(
                    (
                        hand_screen[0] - raw_blue_screen[0],
                        hand_screen[1] - raw_blue_screen[1],
                    )
                )
                hand_grips.append(scene.hand_grip)

        self.assertGreaterEqual(len(local_screen_offsets), 60)
        local_offset_span = max(
            point_distance(first[0], first[1], second[0], second[1])
            for first in local_screen_offsets
            for second in local_screen_offsets
        )
        self.assertLess(local_offset_span, 1.5)
        self.assertLess(max(hand_grips) - min(hand_grips), 0.01)

    def test_demo_holding_keeps_anchor_stable_while_object_stays_attached(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        anchor_offsets: list[tuple[float, float]] = []
        hand_pitches: list[float] = []
        hand_scales: list[float] = []
        anchor_errors: list[float] = []

        for frame_index in range(0, 361):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            scene = animator.update(map_detection_to_virtual(frame, green_distance=160.0))
            if 5.2 <= t <= 8.6 and scene.grab_phase == "holding":
                anchor_offsets.append(
                    (
                        scene.red_display.x - scene.hand_display.x,
                        scene.red_display.y - scene.hand_display.y,
                    )
                )
                hand_pitches.append(scene.hand_pitch_deg)
                hand_scales.append(scene.hand_scale)
                anchor_errors.append(
                    point_distance(
                        scene.red_display.x,
                        scene.red_display.y,
                        scene.grasp_anchor.x,
                        scene.grasp_anchor.y,
                    )
                )

        self.assertGreaterEqual(len(anchor_offsets), 60)
        self.assertLess(max(hand_pitches) - min(hand_pitches), 0.5)
        self.assertLess(max(hand_scales) - min(hand_scales), 0.01)

        offset_span = max(
            point_distance(first[0], first[1], second[0], second[1])
            for first in anchor_offsets
            for second in anchor_offsets
        )
        self.assertLess(offset_span, 0.5)
        self.assertLess(max(anchor_errors), 1.0)

    def test_demo_release_reacquires_drop_point_after_contact_window(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        release_index = None
        post_release_raw_gaps: list[float] = []
        was_grabbed = False

        for frame_index in range(0, 420):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            scene = animator.update(map_detection_to_virtual(frame, green_distance=160.0))
            if was_grabbed and not scene.is_grabbed and release_index is None:
                release_index = frame_index
            elif (
                release_index is not None
                and frame_index >= release_index + 15
                and frame_index <= release_index + 24
            ):
                gap_to_raw = (
                    (scene.red_display.x - scene.frame.red.x) ** 2
                    + (scene.red_display.y - scene.frame.red.y) ** 2
                ) ** 0.5
                post_release_raw_gaps.append(gap_to_raw)
            was_grabbed = scene.is_grabbed

        assert release_index is not None
        self.assertGreaterEqual(len(post_release_raw_gaps), 4)
        self.assertLess(max(post_release_raw_gaps), 12.0)
        self.assertLess(max(post_release_raw_gaps) - min(post_release_raw_gaps), 6.0)

    def test_demo_holding_keeps_cylinder_top_within_hand_reach(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        config = RenderConfig()
        holding_frames = 0

        for frame_index in range(0, 420):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            mapped = map_detection_to_virtual(frame, green_distance=160.0)
            scene = animator.update(mapped)
            if scene.grab_phase != "holding":
                continue

            holding_frames += 1
            hand_screen = project_with_render_config(
                config,
                scene.hand_display.x,
                scene.hand_display.y,
                config.hand_height + scene.hand_height_offset,
            )
            cylinder_top_screen = project_with_render_config(
                config,
                scene.red_display.x,
                scene.red_display.y,
                config.cylinder_height,
            )
            screen_dx = abs(cylinder_top_screen[0] - hand_screen[0])
            screen_dy = cylinder_top_screen[1] - hand_screen[1]

            self.assertLess(screen_dx, config.hand_radius * 0.13)
            self.assertLess(screen_dy, config.hand_radius * 0.16)

        self.assertGreater(holding_frames, 30)

    def test_demo_release_keeps_contact_for_first_visible_release_frames(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        config = RenderConfig()
        release_contact_dx: list[float] = []
        release_contact_dy: list[float] = []

        for frame_index in range(0, 361):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            mapped = map_detection_to_virtual(frame, green_distance=160.0)
            scene = animator.update(mapped)
            if scene.grab_phase != "releasing":
                continue
            if len(release_contact_dx) >= 6:
                break

            hand_screen = project_with_render_config(
                config,
                scene.hand_display.x,
                scene.hand_display.y,
                config.hand_height + scene.hand_height_offset,
            )
            cylinder_top_screen = project_with_render_config(
                config,
                scene.red_display.x,
                scene.red_display.y,
                config.cylinder_height,
            )
            release_contact_dx.append(abs(cylinder_top_screen[0] - hand_screen[0]))
            release_contact_dy.append(cylinder_top_screen[1] - hand_screen[1])

        self.assertEqual(len(release_contact_dx), 6)
        self.assertLess(max(release_contact_dx), config.hand_radius * 0.6)
        self.assertLess(max(release_contact_dy), config.hand_radius * 0.25)

    def test_demo_release_keeps_contact_while_hand_still_shows_visible_motion(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        config = RenderConfig()
        release_rows: list[tuple[float, float, float, float, float, float, float]] = []

        for frame_index in range(0, 361):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            mapped = map_detection_to_virtual(frame, green_distance=160.0)
            scene = animator.update(mapped)
            if scene.grab_phase != "releasing":
                continue
            if len(release_rows) >= 6:
                break

            hand_screen = project_with_render_config(
                config,
                scene.hand_display.x,
                scene.hand_display.y,
                config.hand_height + scene.hand_height_offset,
            )
            cylinder_top_screen = project_with_render_config(
                config,
                scene.red_display.x,
                scene.red_display.y,
                config.cylinder_height,
            )
            release_rows.append(
                (
                    hand_screen[0],
                    hand_screen[1],
                    cylinder_top_screen[0],
                    cylinder_top_screen[1],
                    scene.hand_grip,
                    scene.hand_pitch_deg,
                    scene.hand_scale,
                )
            )

        self.assertEqual(len(release_rows), 6)
        base_hand = release_rows[0][:2]
        hand_drifts = [
            point_distance(hand_x, hand_y, base_hand[0], base_hand[1])
            for hand_x, hand_y, *_ in release_rows
        ]
        contact_dx = [abs(cyl_x - hand_x) for hand_x, _, cyl_x, _, *_ in release_rows]
        contact_dy = [abs(cyl_y - hand_y) for hand_x, hand_y, _, cyl_y, *_ in release_rows]
        grips = [grip for *_, grip, _, _ in release_rows]
        pitches = [pitch for *_, pitch, _ in release_rows]
        scales = [scale for *_, scale in release_rows]

        self.assertGreater(max(hand_drifts), 8.0)
        self.assertLess(max(contact_dx), config.hand_radius * 0.6)
        self.assertLess(max(contact_dy), config.hand_radius * 0.25)
        self.assertGreater(grips[0] - grips[-1], 0.18)
        self.assertGreater(abs(pitches[-1] - pitches[0]), 10.0)
        self.assertGreater(abs(scales[-1] - scales[0]), 0.04)

    def test_demo_release_keeps_contact_for_first_ten_visible_frames(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        config = RenderConfig()
        release_rows: list[tuple[float, float, float, float, float]] = []

        for frame_index in range(0, 361):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            mapped = map_detection_to_virtual(frame, green_distance=160.0)
            scene = animator.update(mapped)
            if scene.grab_phase != "releasing":
                continue
            if len(release_rows) >= 10:
                break

            hand_screen = project_with_render_config(
                config,
                scene.hand_display.x,
                scene.hand_display.y,
                config.hand_height + scene.hand_height_offset,
            )
            cylinder_top_screen = project_with_render_config(
                config,
                scene.red_display.x,
                scene.red_display.y,
                config.cylinder_height,
            )
            release_rows.append(
                (
                    hand_screen[0],
                    hand_screen[1],
                    cylinder_top_screen[0],
                    cylinder_top_screen[1],
                    scene.hand_grip,
                )
            )

        self.assertEqual(len(release_rows), 10)
        contact_dx = [abs(cyl_x - hand_x) for hand_x, _, cyl_x, _, _ in release_rows]
        contact_dy = [abs(cyl_y - hand_y) for hand_x, hand_y, _, cyl_y, _ in release_rows]
        grips = [grip for *_, grip in release_rows]

        self.assertLess(max(contact_dx), config.hand_radius * 0.95)
        self.assertLess(max(contact_dy), config.hand_radius * 0.32)
        self.assertGreater(grips[0] - grips[-1], 0.28)

    def test_demo_release_opens_over_object_before_hand_pulls_away(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        config = RenderConfig()
        release_contact_frames = 0
        max_release_grip = 0.0

        for frame_index in range(0, 361):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            mapped = map_detection_to_virtual(frame, green_distance=160.0)
            scene = animator.update(mapped)
            if scene.grab_phase != "releasing":
                continue

            hand_screen = project_with_render_config(
                config,
                scene.hand_display.x,
                scene.hand_display.y,
                config.hand_height + scene.hand_height_offset,
            )
            cylinder_top_screen = project_with_render_config(
                config,
                scene.red_display.x,
                scene.red_display.y,
                config.cylinder_height,
            )
            screen_dx = abs(cylinder_top_screen[0] - hand_screen[0])
            screen_dy = cylinder_top_screen[1] - hand_screen[1]

            if release_contact_frames < 3:
                self.assertLess(screen_dx, config.hand_radius * 0.22)
                self.assertLess(abs(screen_dy), config.hand_radius * 0.18)
                self.assertGreater(scene.hand_grip, 0.18)
            elif release_contact_frames < 6:
                self.assertLess(screen_dx, config.hand_radius * 0.6)
                self.assertLess(abs(screen_dy), config.hand_radius * 0.25)
            max_release_grip = max(max_release_grip, scene.hand_grip)
            release_contact_frames += 1

        self.assertGreaterEqual(release_contact_frames, 10)
        self.assertGreater(max_release_grip, 0.8)

    def test_demo_grab_uses_visible_local_hand_translation_and_shared_anchor(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        local_offsets: list[float] = []
        closing_anchor_error: list[float] = []
        holding_anchor_error: list[float] = []

        for frame_index in range(0, 361):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            scene = animator.update(map_detection_to_virtual(frame, green_distance=160.0))
            if scene.grab_phase not in {"closing", "holding"}:
                continue

            local_offsets.append(
                point_distance(
                    scene.hand_display.x,
                    scene.hand_display.y,
                    scene.frame.blue.x,
                    scene.frame.blue.y,
                )
            )
            anchor_error = point_distance(
                scene.red_display.x,
                scene.red_display.y,
                scene.grasp_anchor.x,
                scene.grasp_anchor.y,
            )
            if scene.grab_phase == "closing":
                closing_anchor_error.append(anchor_error)
            else:
                holding_anchor_error.append(anchor_error)

        self.assertGreater(max(local_offsets), 8.0)
        self.assertGreaterEqual(len(closing_anchor_error), 12)
        self.assertLess(max(closing_anchor_error[-12:]), 1.0)
        self.assertLess(max(holding_anchor_error), 1.0)

    def test_demo_release_keeps_hand_anchor_over_object_before_retreat(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        release_anchor_error: list[float] = []
        release_local_offsets: list[float] = []

        for frame_index in range(0, 361):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            scene = animator.update(map_detection_to_virtual(frame, green_distance=160.0))
            if scene.grab_phase != "releasing":
                continue
            if len(release_anchor_error) >= 6:
                break

            release_anchor_error.append(
                point_distance(
                    scene.red_display.x,
                    scene.red_display.y,
                    scene.grasp_anchor.x,
                    scene.grasp_anchor.y,
                )
            )
            release_local_offsets.append(
                point_distance(
                    scene.hand_display.x,
                    scene.hand_display.y,
                    scene.frame.blue.x,
                    scene.frame.blue.y,
                )
            )

        self.assertEqual(len(release_anchor_error), 6)
        self.assertLess(max(release_anchor_error), 1.0)
        self.assertGreater(max(release_local_offsets), 4.0)

    def test_demo_closing_keeps_object_on_table_until_hand_reaches_contact(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        early_closing_rows: list[tuple[float, float]] = []

        for frame_index in range(0, 361):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            scene = animator.update(map_detection_to_virtual(frame, green_distance=160.0))
            if scene.grab_phase != "closing":
                continue
            if len(early_closing_rows) >= 6:
                break

            early_closing_rows.append(
                (
                    point_distance(
                        scene.red_display.x,
                        scene.red_display.y,
                        scene.frame.red.x,
                        scene.frame.red.y,
                    ),
                    point_distance(
                        scene.hand_display.x,
                        scene.hand_display.y,
                        scene.frame.red.x,
                        scene.frame.red.y,
                    ),
                )
            )

        self.assertEqual(len(early_closing_rows), 6)
        self.assertGreater(min(hand_gap for _, hand_gap in early_closing_rows), 28.0)
        self.assertLess(max(raw_gap for raw_gap, _ in early_closing_rows), 8.0)

    def test_demo_release_phase_reaches_drop_point_before_release_finishes(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        release_anchor_error: list[float] = []
        late_release_raw_gap: list[float] = []

        for frame_index in range(0, 420):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            scene = animator.update(map_detection_to_virtual(frame, green_distance=160.0))
            if scene.grab_phase != "releasing":
                continue

            if len(release_anchor_error) < 10:
                release_anchor_error.append(
                    point_distance(
                        scene.red_display.x,
                        scene.red_display.y,
                        scene.grasp_anchor.x,
                        scene.grasp_anchor.y,
                    )
                )
            else:
                late_release_raw_gap.append(
                    point_distance(
                        scene.red_display.x,
                        scene.red_display.y,
                        scene.frame.red.x,
                        scene.frame.red.y,
                    )
                )

        self.assertGreaterEqual(len(release_anchor_error), 10)
        self.assertLess(max(release_anchor_error), 1.0)
        self.assertGreaterEqual(len(late_release_raw_gap), 4)
        self.assertLess(late_release_raw_gap[-1], 12.0)

    def test_demo_cycle_resets_cleanly_without_release_state_leaking_into_next_loop(self) -> None:
        with patch("frame_source.time.perf_counter", return_value=0.0):
            source = DemoFrameSource()

        animator = GrabAnimator()
        restarted_scene = None

        for frame_index in range(0, 420):
            t = frame_index / 30.0
            with patch("frame_source.time.perf_counter", return_value=t):
                frame = source.get_latest_frame()
            scene = animator.update(map_detection_to_virtual(frame, green_distance=160.0))
            if t >= source._cycle_duration + (1.0 / 30.0):
                restarted_scene = scene
                break

        assert restarted_scene is not None
        raw_gap = point_distance(
            restarted_scene.red_display.x,
            restarted_scene.red_display.y,
            restarted_scene.frame.red.x,
            restarted_scene.frame.red.y,
        )
        self.assertEqual(restarted_scene.grab_phase, "idle")
        self.assertLess(raw_gap, 20.0)


if __name__ == "__main__":
    unittest.main()
