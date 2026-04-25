from __future__ import annotations

import math
from dataclasses import dataclass

from model import VirtualBlob, VirtualFrame, VirtualPoint


@dataclass(frozen=True)
class GrabAnimationConfig:
    grab_distance: float = 64.0
    release_distance: float = 88.0
    attach_response: float = 0.38
    release_response: float = 0.3
    min_closing_frames: int = 25
    release_hold_frames: int = 2
    release_arm_frames: int = 20
    release_arm_ready_frames: int = 1
    red_reacquire_distance: float = 150.0
    release_follow_distance: float = 44.0
    offset_adaptation: float = 0.2
    settle_epsilon: float = 2.0
    min_releasing_frames: int = 18
    release_pose_lead_in: float = 0.5
    release_grip_lead_in: float = 0.04
    release_start_grip: float = 0.94
    release_contact_frames: int = 10
    release_hand_follow_response: float = 0.22
    holding_hand_deadband: float = 1.5
    holding_hand_follow_response: float = 0.55
    holding_hand_motion_step_threshold: float = 1.5
    holding_hand_motion_direction_cos: float = 0.35
    holding_hand_catchup_distance: float = 2.2
    release_contact_shift_x: float = 28.0
    release_contact_shift_y: float = 6.0
    resync_snap_distance: float = 180.0
    grasp_anchor_x_ratio: float = 0.22
    grasp_anchor_y_ratio: float = 0.32
    grasp_anchor_max_ratio: float = 1.1
    grasp_anchor_min_distance: float = 18.0
    hand_base_radius: float = 28.0
    projection_shear_y: float = 0.72
    projection_depth_scale: float = 0.38
    grasp_anchor_top_x_ratio: float = 0.0
    grasp_anchor_top_y_ratio: float = -0.07
    grasp_anchor_grip_shift_x_ratio: float = -0.08
    grasp_anchor_grip_shift_y_ratio: float = 0.055
    grasp_anchor_rotation_ratio: float = 1.0
    hand_height_idle: float = 4.0
    hand_height_closing: float = -34.0
    hand_height_holding: float = -23.0
    hand_height_releasing: float = -12.0
    hand_offset_x_idle: float = 0.0
    hand_offset_x_closing: float = 10.0
    hand_offset_x_holding: float = 8.0
    hand_offset_x_releasing: float = 4.0
    hand_offset_y_idle: float = 0.0
    hand_offset_y_closing: float = -14.0
    hand_offset_y_holding: float = -8.0
    hand_offset_y_releasing: float = -4.0
    hand_pitch_idle: float = -10.0
    hand_pitch_closing: float = 38.0
    hand_pitch_holding: float = 28.0
    hand_pitch_releasing: float = -102.0
    hand_scale_idle: float = 0.86
    hand_scale_closing: float = 1.4
    hand_scale_holding: float = 1.14
    hand_scale_releasing: float = 0.54
    hand_grip_close_response: float = 0.34
    hand_grip_open_response: float = 0.24
    hand_pose_rise_response: float = 0.22
    hand_pose_fall_response: float = 0.62
    hand_pitch_rise_response: float = 0.58
    hand_pitch_fall_response: float = 0.6
    hand_scale_rise_response: float = 0.58
    hand_scale_fall_response: float = 0.45
    holding_motion_period_frames: float = 18.0
    holding_height_amplitude: float = 14.0
    holding_offset_x_amplitude: float = 13.0
    holding_offset_y_amplitude: float = 18.0
    holding_pitch_amplitude: float = 28.0
    holding_scale_amplitude: float = 0.23
    holding_grip_base: float = 0.24
    holding_grip_amplitude: float = 0.64
    closing_lift_start: float = 0.24
    closing_lift_end: float = 0.44
    closing_contact_ratio: float = 1.15
    closing_contact_padding: float = 6.0


@dataclass(frozen=True)
class AnimatedScene:
    frame: VirtualFrame
    red_display: VirtualBlob
    red_target: VirtualBlob
    hand_display: VirtualPoint
    grasp_anchor: VirtualPoint
    grab_phase: str
    is_grabbed: bool
    grab_strength: float
    hand_grip: float
    hand_height_offset: float
    hand_pitch_deg: float
    hand_scale: float


class GrabAnimator:
    def __init__(self, config: GrabAnimationConfig | None = None) -> None:
        self.config = config or GrabAnimationConfig()
        self._red_display: VirtualBlob | None = None
        self._is_grabbed = False
        self._grip_settled = False
        self._closing_frames = 0
        self._release_counter = 0
        self._release_armed_frames = 0
        self._releasing_frames = 0
        self._offset_x = 0.0
        self._offset_y = 0.0
        self._release_anchor: VirtualBlob | None = None
        self._release_hand_anchor: VirtualPoint | None = None
        self._holding_hand_anchor: VirtualPoint | None = None
        self._last_raw_hand_display: VirtualPoint | None = None
        self._last_raw_hand_step: VirtualPoint | None = None
        self._hand_grip = 0.0
        self._hand_height_offset = 0.0
        self._hand_offset_x = 0.0
        self._hand_offset_y = 0.0
        self._hand_pitch_deg = self.config.hand_pitch_idle
        self._hand_scale = self.config.hand_scale_idle
        self._phase_name = "idle"
        self._phase_frames = 0
        self._holding_frames = 0
        self._phase_entry_grip = self._hand_grip
        self._phase_entry_height_offset = self._hand_height_offset
        self._phase_entry_offset_x = self._hand_offset_x
        self._phase_entry_offset_y = self._hand_offset_y
        self._phase_entry_pitch_deg = self._hand_pitch_deg
        self._phase_entry_scale = self._hand_scale
        self._phase_entry_grasp_offset_x = self._offset_x
        self._phase_entry_grasp_offset_y = self._offset_y
        self._closing_attachment_blend = 0.0
        self._previous_detected_distance: float | None = None

    def update(self, frame: VirtualFrame) -> AnimatedScene:
        if self._red_display is None:
            self._red_display = frame.red

        detected_distance = _distance(frame.red, frame.blue)
        moving_away = (
            self._previous_detected_distance is not None
            and detected_distance > self._previous_detected_distance + 0.75
        )
        just_grabbed = False
        just_released = False

        if (
            not self._is_grabbed
            and self._releasing_frames > 0
            and self._red_display is not None
            and _distance(self._red_display, frame.red) > self.config.resync_snap_distance
        ):
            self._release_anchor = None
            self._release_hand_anchor = None
            self._releasing_frames = 0

        if self._is_grabbed:
            held_target = self._held_target(frame)
            raw_gap = _distance(frame.red, held_target)
            if raw_gap <= self.config.red_reacquire_distance:
                self._release_armed_frames = min(
                    self.config.release_arm_frames,
                    self._release_armed_frames + 1,
                )
            else:
                self._release_armed_frames = max(0, self._release_armed_frames - 1)

            if (
                self._release_armed_frames >= self.config.release_arm_ready_frames
                and (
                    detected_distance > self.config.release_distance
                    or (
                        moving_away
                        and detected_distance > self.config.release_follow_distance
                    )
                )
            ):
                self._release_counter += 1
                if self._release_counter >= self.config.release_hold_frames:
                    assert self._red_display is not None
                    self._is_grabbed = False
                    self._grip_settled = False
                    self._closing_frames = 0
                    self._release_counter = 0
                    self._release_armed_frames = 0
                    self._release_anchor = self._red_display
                    self._release_hand_anchor = VirtualPoint(
                        self._red_display.x - self._offset_x,
                        self._red_display.y - self._offset_y,
                    )
                    self._releasing_frames = self.config.min_releasing_frames
                    just_released = True
            else:
                self._release_counter = 0
        elif self._releasing_frames == 0 and detected_distance <= self.config.grab_distance:
            self._is_grabbed = True
            self._grip_settled = False
            self._closing_frames = 0
            self._closing_attachment_blend = 0.0
            self._release_counter = 0
            self._release_armed_frames = 0
            self._releasing_frames = 0
            self._release_anchor = None
            self._release_hand_anchor = None
            just_grabbed = True

        phase = self._phase_for(just_grabbed=just_grabbed, just_released=just_released)
        self._advance_phase_counters(phase)
        hand_grip = self._update_hand_grip(phase)
        hand_height_offset = self._update_hand_height_offset(phase)
        hand_offset_x = self._update_hand_offset_x(phase)
        hand_offset_y = self._update_hand_offset_y(phase)
        hand_pitch_deg = self._update_hand_pitch_deg(phase)
        hand_scale = self._update_hand_scale(phase)
        offset_x, offset_y = self._resolve_grab_offset(
            phase=phase,
            red_radius=frame.red.radius,
            hand_height_offset=hand_height_offset,
            hand_pitch_deg=hand_pitch_deg,
            hand_scale=hand_scale,
            hand_grip=hand_grip,
        )
        release_target = self._release_target(frame, phase)
        raw_hand_display = VirtualPoint(
            frame.blue.x + hand_offset_x,
            frame.blue.y + hand_offset_y,
        )
        hand_display = self._resolve_hand_display(
            phase,
            raw_hand_display,
            offset_x,
            offset_y,
            release_target,
        )
        self._offset_x, self._offset_y = offset_x, offset_y
        grasp_anchor = VirtualPoint(
            hand_display.x + self._offset_x,
            hand_display.y + self._offset_y,
        )
        target = self._target_red(frame, grasp_anchor, phase, release_target)
        if (
            not self._is_grabbed
            and phase == "idle"
            and self._red_display is not None
            and _distance(self._red_display, frame.red) > self.config.resync_snap_distance
        ):
            # Large discontinuities are usually demo-loop or input-resync jumps; snap
            # back to the raw target instead of dragging the old release state across
            # the scene.
            self._red_display = frame.red
            self._release_anchor = None
            self._release_hand_anchor = None
            self._releasing_frames = 0
            target = frame.red
        if self._is_grabbed:
            if not self._grip_settled:
                self._closing_frames += 1
                self._red_display = target
                if (
                    self._closing_frames >= self.config.min_closing_frames
                    and _distance(self._red_display, target) <= self.config.settle_epsilon
                ):
                    self._grip_settled = True
            else:
                self._red_display = target
        else:
            self._closing_frames = 0
            self._closing_attachment_blend = 0.0
            if self._release_anchor is not None:
                self._red_display = target
            else:
                self._red_display = _lerp_blob(self._red_display, target, self.config.release_response)

        phase = self._finalize_phase(phase, target)
        strength = self._strength_for(phase, target)
        if self._releasing_frames > 0:
            self._releasing_frames -= 1
        self._previous_detected_distance = detected_distance

        return AnimatedScene(
            frame=frame,
            red_display=self._red_display,
            red_target=target,
            hand_display=hand_display,
            grasp_anchor=grasp_anchor,
            grab_phase=phase,
            is_grabbed=self._is_grabbed,
            grab_strength=strength,
            hand_grip=hand_grip,
            hand_height_offset=hand_height_offset,
            hand_pitch_deg=hand_pitch_deg,
            hand_scale=hand_scale,
        )

    def _target_red(
        self,
        frame: VirtualFrame,
        grasp_anchor: VirtualPoint,
        phase: str,
        release_target: VirtualBlob | None,
    ) -> VirtualBlob:
        if self._is_grabbed:
            if phase == "closing":
                closing_target = VirtualBlob(
                    x=grasp_anchor.x,
                    y=grasp_anchor.y,
                    radius=frame.red.radius,
                )
                return _blend_blob(
                    frame.red,
                    closing_target,
                    self._closing_lift_blend(frame),
                )
            return VirtualBlob(
                x=grasp_anchor.x,
                y=grasp_anchor.y,
                radius=frame.red.radius,
            )

        if self._release_anchor is None:
            return frame.red

        if phase == "releasing":
            return release_target or self._release_anchor

        self._release_anchor = None
        return frame.red

    def _resolve_hand_display(
        self,
        phase: str,
        raw_hand_display: VirtualPoint,
        offset_x: float,
        offset_y: float,
        release_target: VirtualBlob | None,
    ) -> VirtualPoint:
        raw_step = self._measure_raw_hand_step(raw_hand_display)
        if phase == "holding":
            self._release_hand_anchor = None
            hand_display = self._stabilize_holding_hand_display(raw_hand_display, raw_step)
            self._remember_raw_hand_motion(raw_hand_display, raw_step)
            return hand_display

        self._holding_hand_anchor = None
        hand_display: VirtualPoint
        if phase != "releasing":
            if self._release_hand_anchor is None:
                hand_display = raw_hand_display
            else:
                self._release_hand_anchor = VirtualPoint(
                    _lerp(
                        self._release_hand_anchor.x,
                        raw_hand_display.x,
                        self.config.release_hand_follow_response,
                    ),
                    _lerp(
                        self._release_hand_anchor.y,
                        raw_hand_display.y,
                        self.config.release_hand_follow_response,
                    ),
                )
                if (
                    _distance_points(self._release_hand_anchor, raw_hand_display)
                    <= self.config.settle_epsilon
                ):
                    self._release_hand_anchor = None
                    hand_display = raw_hand_display
                else:
                    hand_display = self._release_hand_anchor
            self._remember_raw_hand_motion(raw_hand_display, raw_step)
            return hand_display

        if release_target is None:
            if self._release_hand_anchor is None:
                self._release_hand_anchor = raw_hand_display
                hand_display = raw_hand_display
            else:
                self._release_hand_anchor = VirtualPoint(
                    _lerp(
                        self._release_hand_anchor.x,
                        raw_hand_display.x,
                        self.config.release_hand_follow_response,
                    ),
                    _lerp(
                        self._release_hand_anchor.y,
                        raw_hand_display.y,
                        self.config.release_hand_follow_response,
                    ),
                )
                hand_display = self._release_hand_anchor
            self._remember_raw_hand_motion(raw_hand_display, raw_step)
            return hand_display

        contact_hand_display = VirtualPoint(
            release_target.x - offset_x,
            release_target.y - offset_y,
        )
        if self._phase_frames <= self.config.release_contact_frames:
            self._release_hand_anchor = contact_hand_display
            hand_display = contact_hand_display
        else:
            retreat_progress = self._release_follow_progress()
            self._release_hand_anchor = VirtualPoint(
                _lerp(contact_hand_display.x, raw_hand_display.x, retreat_progress),
                _lerp(contact_hand_display.y, raw_hand_display.y, retreat_progress),
            )
            hand_display = self._release_hand_anchor
        self._remember_raw_hand_motion(raw_hand_display, raw_step)
        return hand_display

    def _stabilize_holding_hand_display(
        self,
        raw_hand_display: VirtualPoint,
        raw_step: VirtualPoint | None,
    ) -> VirtualPoint:
        if self._holding_hand_anchor is None:
            self._holding_hand_anchor = raw_hand_display
            return raw_hand_display

        delta_x = raw_hand_display.x - self._holding_hand_anchor.x
        delta_y = raw_hand_display.y - self._holding_hand_anchor.y
        distance = math.hypot(delta_x, delta_y)
        if distance <= self.config.holding_hand_deadband:
            return self._holding_hand_anchor

        if self._phase_frames == 1:
            self._holding_hand_anchor = raw_hand_display
            return self._holding_hand_anchor

        raw_step_distance = 0.0 if raw_step is None else math.hypot(raw_step.x, raw_step.y)
        if (
            raw_step_distance < self.config.holding_hand_motion_step_threshold
            and distance >= self.config.holding_hand_catchup_distance
        ):
            self._holding_hand_anchor = raw_hand_display
            return self._holding_hand_anchor

        if self._holding_motion_is_consistent(raw_step):
            self._holding_hand_anchor = raw_hand_display
            return self._holding_hand_anchor

        follow_distance = distance - self.config.holding_hand_deadband
        follow_step = follow_distance * self.config.holding_hand_follow_response
        if follow_step <= 0.0:
            return self._holding_hand_anchor

        step_ratio = min(follow_step / distance, 1.0)
        self._holding_hand_anchor = VirtualPoint(
            self._holding_hand_anchor.x + delta_x * step_ratio,
            self._holding_hand_anchor.y + delta_y * step_ratio,
        )
        return self._holding_hand_anchor

    def _measure_raw_hand_step(self, raw_hand_display: VirtualPoint) -> VirtualPoint | None:
        if self._last_raw_hand_display is None:
            return None
        return VirtualPoint(
            raw_hand_display.x - self._last_raw_hand_display.x,
            raw_hand_display.y - self._last_raw_hand_display.y,
        )

    def _remember_raw_hand_motion(
        self,
        raw_hand_display: VirtualPoint,
        raw_step: VirtualPoint | None,
    ) -> None:
        self._last_raw_hand_display = raw_hand_display
        self._last_raw_hand_step = raw_step

    def _holding_motion_is_consistent(self, raw_step: VirtualPoint | None) -> bool:
        if raw_step is None or self._last_raw_hand_step is None:
            return False

        raw_step_distance = math.hypot(raw_step.x, raw_step.y)
        previous_step_distance = math.hypot(
            self._last_raw_hand_step.x,
            self._last_raw_hand_step.y,
        )
        if (
            raw_step_distance < self.config.holding_hand_motion_step_threshold
            or previous_step_distance < self.config.holding_hand_motion_step_threshold
        ):
            return False

        alignment = (
            raw_step.x * self._last_raw_hand_step.x
            + raw_step.y * self._last_raw_hand_step.y
        ) / (raw_step_distance * previous_step_distance)
        return alignment >= self.config.holding_hand_motion_direction_cos

    def _release_target(self, frame: VirtualFrame, phase: str) -> VirtualBlob | None:
        if phase != "releasing" or self._release_anchor is None:
            return None

        if self._phase_frames <= self.config.release_contact_frames:
            return self._release_anchor

        return _blend_blob(
            self._release_anchor,
            frame.red,
            self._release_follow_progress(),
        )

    def _held_target(self, frame: VirtualFrame) -> VirtualBlob:
        return VirtualBlob(
            x=frame.blue.x + self._hand_offset_x + self._offset_x,
            y=frame.blue.y + self._hand_offset_y + self._offset_y,
            radius=frame.red.radius,
        )

    def _resolve_grab_offset(
        self,
        phase: str,
        red_radius: float,
        hand_height_offset: float,
        hand_pitch_deg: float,
        hand_scale: float,
        hand_grip: float,
    ) -> tuple[float, float]:
        base_offset = (
            red_radius * self.config.grasp_anchor_x_ratio,
            red_radius * self.config.grasp_anchor_y_ratio,
        )
        if phase == "releasing":
            release_pose_offset = self._pose_grab_offset(
                red_radius,
                hand_pitch_deg,
                hand_scale,
                hand_grip,
            )
            release_progress = _clamp01(
                self._phase_frames / max(self.config.release_contact_frames, 1)
            )
            release_pose_offset = (
                release_pose_offset[0] + self.config.release_contact_shift_x * release_progress,
                release_pose_offset[1] + self.config.release_contact_shift_y * release_progress,
            )
            return (
                _lerp(
                    self._phase_entry_grasp_offset_x,
                    release_pose_offset[0],
                    release_progress,
                ),
                _lerp(
                    self._phase_entry_grasp_offset_y,
                    release_pose_offset[1],
                    release_progress,
                ),
            )
        if phase not in {"closing", "holding"}:
            return base_offset

        return self._pose_grab_offset(
            red_radius,
            hand_pitch_deg,
            hand_scale,
            hand_grip,
        )

    def _pose_grab_offset(
        self,
        red_radius: float,
        hand_pitch_deg: float,
        hand_scale: float,
        hand_grip: float,
    ) -> tuple[float, float]:
        base_offset = (
            red_radius * self.config.grasp_anchor_x_ratio,
            red_radius * self.config.grasp_anchor_y_ratio,
        )
        hand_radius = self.config.hand_base_radius * max(hand_scale, 0.4)
        local_screen_x = hand_radius * (
            self.config.grasp_anchor_top_x_ratio
            + self.config.grasp_anchor_grip_shift_x_ratio * hand_grip
        )
        local_screen_y = hand_radius * (
            self.config.grasp_anchor_top_y_ratio
            + self.config.grasp_anchor_grip_shift_y_ratio * hand_grip
        )
        rotated_screen_x, rotated_screen_y = _rotate_2d(
            local_screen_x,
            local_screen_y,
            hand_pitch_deg * self.config.grasp_anchor_rotation_ratio,
        )
        pose_world_y = rotated_screen_y / max(self.config.projection_depth_scale, 1e-6)
        pose_world_x = rotated_screen_x + self.config.projection_shear_y * pose_world_y
        return (
            base_offset[0] + pose_world_x,
            base_offset[1] + pose_world_y,
        )

    def _phase_for(self, just_grabbed: bool, just_released: bool) -> str:
        if just_grabbed:
            return "closing"
        if just_released or self._releasing_frames > 0:
            return "releasing"
        if self._is_grabbed:
            if not self._grip_settled:
                return "closing"
            return "holding"
        return "idle"

    def _finalize_phase(self, phase: str, target: VirtualBlob) -> str:
        if phase in {"closing", "holding", "releasing"}:
            return phase
        return "idle"

    def _strength_for(self, phase: str, target: VirtualBlob) -> float:
        assert self._red_display is not None
        if phase == "idle":
            return 0.0
        if phase == "holding":
            return 1.0

        scale = max(self.config.release_distance, self.config.grab_distance, 1.0)
        remaining = _distance(self._red_display, target)
        return max(0.25, 1.0 - min(1.0, remaining / scale))

    def _advance_phase_counters(self, phase: str) -> None:
        if phase == self._phase_name:
            self._phase_frames += 1
        else:
            self._phase_entry_grip = self._hand_grip
            self._phase_entry_height_offset = self._hand_height_offset
            self._phase_entry_offset_x = self._hand_offset_x
            self._phase_entry_offset_y = self._hand_offset_y
            self._phase_entry_pitch_deg = self._hand_pitch_deg
            self._phase_entry_scale = self._hand_scale
            self._phase_entry_grasp_offset_x = self._offset_x
            self._phase_entry_grasp_offset_y = self._offset_y
            self._phase_name = phase
            self._phase_frames = 1

        if phase == "holding":
            self._holding_frames += 1
        else:
            self._holding_frames = 0

    def _update_hand_grip(self, phase: str) -> float:
        if phase == "closing":
            progress = self._phase_progress(phase, lead_in=0.42)
            self._hand_grip = _clamp01(_lerp(self._phase_entry_grip, 0.98, progress))
            return self._hand_grip

        if phase == "releasing":
            progress = self._phase_progress(phase, lead_in=self.config.release_grip_lead_in)
            self._hand_grip = _clamp01(
                _lerp(
                    max(self._phase_entry_grip, self.config.release_start_grip),
                    0.0,
                    progress,
                )
            )
            return self._hand_grip

        if phase == "holding":
            self._hand_grip = self._phase_entry_grip
            return self._hand_grip

        grip_targets = {
            "idle": 0.0,
        }
        target = grip_targets.get(phase, 0.0)
        response = (
            self.config.hand_grip_close_response
            if target >= self._hand_grip
            else self.config.hand_grip_open_response
        )
        self._hand_grip = _clamp01(_lerp(self._hand_grip, target, response))
        return self._hand_grip

    def _update_hand_height_offset(self, phase: str) -> float:
        if phase == "closing":
            progress = self._phase_progress(phase, lead_in=0.42)
            self._hand_height_offset = _lerp(
                self._phase_entry_height_offset,
                self.config.hand_height_holding,
                progress,
            )
            return self._hand_height_offset

        if phase == "releasing":
            progress = self._phase_progress(phase, lead_in=self.config.release_pose_lead_in)
            self._hand_height_offset = _lerp(
                self._phase_entry_height_offset,
                self.config.hand_height_releasing,
                progress,
            )
            return self._hand_height_offset

        if phase == "holding":
            self._hand_height_offset = self.config.hand_height_holding
            return self._hand_height_offset

        targets = {
            "idle": self.config.hand_height_idle,
        }
        target = targets.get(phase, self.config.hand_height_idle)
        self._hand_height_offset = self._update_pose_value(
            self._hand_height_offset,
            target,
            rise_response=self.config.hand_pose_rise_response,
            fall_response=self.config.hand_pose_fall_response,
        )
        return self._hand_height_offset

    def _update_hand_offset_x(self, phase: str) -> float:
        if phase == "closing":
            progress = self._phase_progress(phase, lead_in=0.42)
            self._hand_offset_x = _lerp(
                self._phase_entry_offset_x,
                self.config.hand_offset_x_holding,
                progress,
            )
            return self._hand_offset_x

        if phase == "releasing":
            progress = self._phase_progress(phase, lead_in=self.config.release_pose_lead_in)
            self._hand_offset_x = _lerp(
                self._phase_entry_offset_x,
                self.config.hand_offset_x_releasing,
                progress,
            )
            return self._hand_offset_x

        if phase == "holding":
            self._hand_offset_x = self.config.hand_offset_x_holding
            return self._hand_offset_x

        targets = {
            "idle": self.config.hand_offset_x_idle,
        }
        target = targets.get(phase, self.config.hand_offset_x_idle)
        self._hand_offset_x = self._update_pose_value(
            self._hand_offset_x,
            target,
            rise_response=self.config.hand_pose_rise_response,
            fall_response=self.config.hand_pose_fall_response,
        )
        return self._hand_offset_x

    def _update_hand_offset_y(self, phase: str) -> float:
        if phase == "closing":
            progress = self._phase_progress(phase, lead_in=0.42)
            self._hand_offset_y = _lerp(
                self._phase_entry_offset_y,
                self.config.hand_offset_y_holding,
                progress,
            )
            return self._hand_offset_y

        if phase == "releasing":
            progress = self._phase_progress(phase, lead_in=self.config.release_pose_lead_in)
            self._hand_offset_y = _lerp(
                self._phase_entry_offset_y,
                self.config.hand_offset_y_releasing,
                progress,
            )
            return self._hand_offset_y

        if phase == "holding":
            self._hand_offset_y = self.config.hand_offset_y_holding
            return self._hand_offset_y

        targets = {
            "idle": self.config.hand_offset_y_idle,
        }
        target = targets.get(phase, self.config.hand_offset_y_idle)
        self._hand_offset_y = self._update_pose_value(
            self._hand_offset_y,
            target,
            rise_response=self.config.hand_pose_rise_response,
            fall_response=self.config.hand_pose_fall_response,
        )
        return self._hand_offset_y

    def _update_hand_pitch_deg(self, phase: str) -> float:
        if phase == "closing":
            progress = self._phase_progress(phase, lead_in=0.42)
            self._hand_pitch_deg = _lerp(
                self._phase_entry_pitch_deg,
                self.config.hand_pitch_holding,
                progress,
            )
            return self._hand_pitch_deg

        if phase == "releasing":
            progress = self._phase_progress(phase, lead_in=self.config.release_pose_lead_in)
            self._hand_pitch_deg = _lerp(
                self._phase_entry_pitch_deg,
                self.config.hand_pitch_releasing,
                progress,
            )
            return self._hand_pitch_deg

        if phase == "holding":
            self._hand_pitch_deg = self.config.hand_pitch_holding
            return self._hand_pitch_deg

        targets = {
            "idle": self.config.hand_pitch_idle,
        }
        target = targets.get(phase, self.config.hand_pitch_idle)
        self._hand_pitch_deg = self._update_pose_value(
            self._hand_pitch_deg,
            target,
            rise_response=self.config.hand_pitch_rise_response,
            fall_response=self.config.hand_pitch_fall_response,
        )
        return self._hand_pitch_deg

    def _update_hand_scale(self, phase: str) -> float:
        if phase == "closing":
            progress = self._phase_progress(phase, lead_in=0.42)
            self._hand_scale = _lerp(
                self._phase_entry_scale,
                self.config.hand_scale_holding,
                progress,
            )
            return self._hand_scale

        if phase == "releasing":
            progress = self._phase_progress(phase, lead_in=self.config.release_pose_lead_in)
            self._hand_scale = _lerp(
                self._phase_entry_scale,
                self.config.hand_scale_releasing,
                progress,
            )
            return self._hand_scale

        if phase == "holding":
            self._hand_scale = self.config.hand_scale_holding
            return self._hand_scale

        targets = {
            "idle": self.config.hand_scale_idle,
        }
        target = targets.get(phase, self.config.hand_scale_idle)
        self._hand_scale = self._update_pose_value(
            self._hand_scale,
            target,
            rise_response=self.config.hand_scale_rise_response,
            fall_response=self.config.hand_scale_fall_response,
        )
        return self._hand_scale

    def _update_pose_value(
        self,
        current: float,
        target: float,
        rise_response: float,
        fall_response: float,
    ) -> float:
        response = rise_response if target >= current else fall_response
        return _lerp(current, target, response)

    def _holding_wave(self, phase_offset: float = 0.0) -> float:
        period = max(self.config.holding_motion_period_frames, 1.0)
        angle = ((self._holding_frames - 1) / period) * math.tau + phase_offset
        return math.sin(angle)

    def _phase_progress(self, phase: str, lead_in: float = 0.0) -> float:
        if phase == "closing":
            duration = max(self.config.min_closing_frames, 1)
        elif phase == "releasing":
            duration = max(self.config.min_releasing_frames, 1)
        else:
            return 1.0

        normalized = _clamp01(self._phase_frames / duration)
        eased = _smoothstep(normalized)
        return _clamp01(lead_in + (1.0 - lead_in) * eased)

    def _release_follow_progress(self) -> float:
        follow_frames = max(
            self.config.min_releasing_frames - self.config.release_contact_frames,
            1,
        )
        follow_index = max(self._phase_frames - self.config.release_contact_frames + 1, 0)
        return _smoothstep(follow_index / follow_frames)

    def _closing_lift_blend(self, frame: VirtualFrame) -> float:
        start = min(self.config.closing_lift_start, self.config.closing_lift_end)
        end = max(self.config.closing_lift_start, self.config.closing_lift_end)
        progress = self._phase_progress("closing", lead_in=0.0)
        if end - start <= 1e-6:
            progress_blend = 1.0
        else:
            progress_blend = _smoothstep((progress - start) / (end - start))

        contact_distance = max(
            frame.red.radius * self.config.closing_contact_ratio,
            frame.red.radius + self.config.closing_contact_padding,
        )
        if contact_distance <= 1e-6:
            self._closing_attachment_blend = max(self._closing_attachment_blend, progress_blend)
            return self._closing_attachment_blend
        contact_blend = _smoothstep(
            (contact_distance - _distance(frame.red, frame.blue)) / contact_distance
        )
        self._closing_attachment_blend = max(
            self._closing_attachment_blend,
            progress_blend,
            contact_blend,
        )
        return self._closing_attachment_blend


def _distance(left: VirtualBlob, right: VirtualBlob) -> float:
    return math.hypot(left.x - right.x, left.y - right.y)


def _distance_points(left: VirtualPoint, right: VirtualPoint) -> float:
    return math.hypot(left.x - right.x, left.y - right.y)


def _lerp_blob(current: VirtualBlob, target: VirtualBlob, alpha: float) -> VirtualBlob:
    weight = _clamp01(alpha)
    return VirtualBlob(
        x=_lerp(current.x, target.x, weight),
        y=_lerp(current.y, target.y, weight),
        radius=_lerp(current.radius, target.radius, weight),
    )


def _blend_blob(start: VirtualBlob, end: VirtualBlob, alpha: float) -> VirtualBlob:
    weight = _clamp01(alpha)
    return VirtualBlob(
        x=_lerp(start.x, end.x, weight),
        y=_lerp(start.y, end.y, weight),
        radius=_lerp(start.radius, end.radius, weight),
    )


def _lerp(start: float, end: float, alpha: float) -> float:
    return start + (end - start) * alpha


def _rotate_2d(x: float, y: float, angle_deg: float) -> tuple[float, float]:
    if angle_deg == 0.0:
        return x, y
    angle = math.radians(angle_deg)
    cos_angle = math.cos(angle)
    sin_angle = math.sin(angle)
    return (
        x * cos_angle - y * sin_angle,
        x * sin_angle + y * cos_angle,
    )


def _clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))


def _smoothstep(value: float) -> float:
    weight = _clamp01(value)
    return weight * weight * (3.0 - 2.0 * weight)
