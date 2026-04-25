from __future__ import annotations

import tkinter as tk
from dataclasses import dataclass

from frame_source import FrameSource
from grab_animation import AnimatedScene, GrabAnimator
from hand_style import build_hand_line_art
from mapper import map_detection_to_virtual


@dataclass(frozen=True)
class RenderConfig:
    width: int = 1280
    height: int = 760
    plane_half_width: float = 340.0
    plane_half_depth: float = 220.0
    cylinder_height: float = 85.0
    hand_height: float = 100.0
    hand_radius: float = 28.0
    green_zone_size: float = 55.0
    green_distance: float = 160.0


class VirtualGrabRenderer:
    def __init__(self, source: FrameSource, config: RenderConfig | None = None) -> None:
        self.source = source
        self.config = config or RenderConfig()
        self.root = tk.Tk()
        self.root.title("Virtual Grab Renderer")
        self.root.protocol("WM_DELETE_WINDOW", self.close)
        self.canvas = tk.Canvas(
            self.root,
            width=self.config.width,
            height=self.config.height,
            bg="#e9ecf1",
            highlightthickness=0,
        )
        self.canvas.pack(fill=tk.BOTH, expand=True)
        self._animator = GrabAnimator()
        self._scene: AnimatedScene | None = None
        self._running = False
        self._closed = False

    def render_once(self, present: bool = True) -> None:
        detection_frame = self.source.get_latest_frame()
        if detection_frame is not None:
            mapped_frame = map_detection_to_virtual(
                detection_frame,
                green_distance=self.config.green_distance,
            )
            self._scene = self._animator.update(mapped_frame)
        self._draw_scene()
        if present:
            self.root.update_idletasks()
            self.root.update()

    def run(self) -> None:
        self._running = True
        self._tick()
        self.root.mainloop()

    def close(self) -> None:
        if self._closed:
            return
        self._closed = True
        self._running = False
        try:
            self.source.close()
        finally:
            try:
                if self.root.winfo_exists():
                    self.root.destroy()
            except tk.TclError:
                return

    def _tick(self) -> None:
        if not self._running:
            return
        self.render_once(present=False)
        self.root.after(33, self._tick)

    def _draw_scene(self) -> None:
        self.canvas.delete("all")
        self._draw_plane()
        if self._scene is None:
            self.canvas.create_text(
                self.config.width / 2,
                40,
                text="Waiting for frame data...",
                fill="#22303c",
                font=("Consolas", 16, "bold"),
            )
            return

        self._draw_origin()
        self._draw_green_zone()
        body_fill, outline, top_fill = self._cylinder_palette(self._scene.grab_phase)
        self._draw_cylinder(
            self._scene.red_display.x,
            self._scene.red_display.y,
            self._scene.red_display.radius,
            self.config.cylinder_height,
            fill=body_fill,
            outline=outline,
            top_fill=top_fill,
        )
        self._draw_grab_feedback(self._scene)
        self._draw_hand(
            self._scene.hand_display.x,
            self._scene.hand_display.y,
            self.config.hand_height + self._scene.hand_height_offset,
            self._scene.hand_grip,
            self._scene.hand_pitch_deg,
            self._scene.hand_scale,
        )
        self._draw_status()

    def _project(self, x: float, y: float, z: float) -> tuple[float, float]:
        cx = self.config.width * 0.48
        cy = self.config.height * 0.62
        sx = cx + x - 0.72 * y
        sy = cy + 0.38 * y - z
        return sx, sy

    def _draw_plane(self) -> None:
        cfg = self.config
        corners = [
            self._project(-cfg.plane_half_width, -cfg.plane_half_depth, 0.0),
            self._project(cfg.plane_half_width, -cfg.plane_half_depth, 0.0),
            self._project(cfg.plane_half_width, cfg.plane_half_depth, 0.0),
            self._project(-cfg.plane_half_width, cfg.plane_half_depth, 0.0),
        ]
        flat = [value for point in corners for value in point]
        self.canvas.create_polygon(
            flat,
            fill="#ffffff",
            outline="#b9c2cf",
            width=2,
        )

        for offset in range(-300, 301, 60):
            start = self._project(offset, -cfg.plane_half_depth, 0.0)
            end = self._project(offset, cfg.plane_half_depth, 0.0)
            self.canvas.create_line(*start, *end, fill="#edf1f6")
        for offset in range(-180, 181, 45):
            start = self._project(-cfg.plane_half_width, offset, 0.0)
            end = self._project(cfg.plane_half_width, offset, 0.0)
            self.canvas.create_line(*start, *end, fill="#edf1f6")

    def _draw_origin(self) -> None:
        x, y = self._project(0.0, 0.0, 0.0)
        self.canvas.create_oval(x - 7, y - 7, x + 7, y + 7, fill="#222", outline="")
        self.canvas.create_text(x + 18, y - 14, text="O", fill="#111", font=("Consolas", 16, "bold"))

    def _draw_green_zone(self) -> None:
        size = self.config.green_zone_size
        cx = self.config.green_distance
        corners = [
            self._project(cx - size, -size * 0.8, 0.0),
            self._project(cx + size, -size * 0.8, 0.0),
            self._project(cx + size, size * 0.8, 0.0),
            self._project(cx - size, size * 0.8, 0.0),
        ]
        flat = [value for point in corners for value in point]
        self.canvas.create_polygon(
            flat,
            fill="#58b65c",
            outline="#2f7f34",
            width=2,
        )
        label_x, label_y = self._project(cx, 0.0, 4.0)
        self.canvas.create_text(
            label_x,
            label_y - 25,
            text="Green Ref",
            fill="#245827",
            font=("Consolas", 12, "bold"),
        )

    def _draw_cylinder(
        self,
        x: float,
        y: float,
        radius: float,
        height: float,
        fill: str,
        outline: str,
        top_fill: str,
    ) -> None:
        base_x, base_y = self._project(x, y, 0.0)
        top_x, top_y = self._project(x, y, height)
        rx = max(radius, 10.0)
        ry = max(radius * 0.38, 5.0)
        self.canvas.create_rectangle(
            base_x - rx,
            top_y,
            base_x + rx,
            base_y,
            fill=fill,
            outline=outline,
            width=2,
        )
        self.canvas.create_oval(
            top_x - rx,
            top_y - ry,
            top_x + rx,
            top_y + ry,
            fill=top_fill,
            outline=outline,
            width=2,
        )
        self.canvas.create_oval(
            base_x - rx,
            base_y - ry,
            base_x + rx,
            base_y + ry,
            outline=outline,
            width=2,
        )

    def _draw_hand(
        self,
        x: float,
        y: float,
        z: float,
        grip: float,
        rotation_deg: float,
        scale: float,
    ) -> None:
        self._draw_hand_shadow(x, y, z, scale)
        center_x, center_y = self._project(x, y, z)
        for stroke in build_hand_line_art(
            center_x,
            center_y,
            self.config.hand_radius * scale,
            grip=grip,
            rotation_deg=rotation_deg,
        ):
            self.canvas.create_line(
                *stroke.points,
                fill=stroke.color,
                width=stroke.width,
                smooth=stroke.smooth,
                capstyle=tk.ROUND,
                joinstyle=tk.ROUND,
            )

    def _draw_hand_shadow(self, x: float, y: float, z: float, scale: float) -> None:
        ground_x, ground_y = self._project(x, y, 0.0)
        closeness = max(0.0, min(1.0, 1.0 - z / max(self.config.hand_height, 1.0)))
        shadow_rx = self.config.hand_radius * (0.78 + 0.22 * scale - 0.2 * closeness)
        shadow_ry = shadow_rx * (0.22 + 0.08 * closeness)
        shadow_fill = "#b9c1cb" if closeness < 0.45 else "#9aa3ae"
        self.canvas.create_oval(
            ground_x - shadow_rx,
            ground_y - shadow_ry,
            ground_x + shadow_rx,
            ground_y + shadow_ry,
            fill=shadow_fill,
            outline="",
        )

    def _draw_grab_feedback(self, scene: AnimatedScene) -> None:
        if scene.grab_phase == "idle":
            return

        halo_x, halo_y = self._project(
            scene.red_display.x,
            scene.red_display.y,
            self.config.cylinder_height + 10.0,
        )
        radius = max(scene.red_display.radius + 10.0 + 8.0 * scene.grab_strength, 22.0)
        flatten = max(radius * 0.34, 8.0)

        if scene.grab_phase == "closing":
            colors = ("#f0ad34", "#ffd77b")
        elif scene.grab_phase == "holding":
            colors = ("#e5941f", "#ffcf63")
        else:
            colors = ("#d58f54",)

        for index, color in enumerate(colors):
            spread = index * 10.0
            self.canvas.create_oval(
                halo_x - radius - spread,
                halo_y - flatten - spread * 0.24,
                halo_x + radius + spread,
                halo_y + flatten + spread * 0.24,
                outline=color,
                width=2,
            )

    def _cylinder_palette(self, grab_phase: str) -> tuple[str, str, str]:
        if grab_phase == "closing":
            return "#df4b4b", "#d08d22", "#ff8f73"
        if grab_phase == "holding":
            return "#e25555", "#d48d18", "#ffae7a"
        if grab_phase == "releasing":
            return "#dd5b5b", "#bf6b25", "#f28b75"
        return "#d62f2f", "#8b1f1f", "#f07070"

    def _draw_status(self) -> None:
        assert self._scene is not None
        status = (
            f"frame={self._scene.frame.frame_id}  "
            f"grab={self._scene.grab_phase}  "
            f"hand={self._scene.hand_grip:.2f}  "
            f"hand_z={self._scene.hand_height_offset:+.1f}  "
            f"hand_rot={self._scene.hand_pitch_deg:+.1f}  "
            f"hand_s={self._scene.hand_scale:.2f}  "
            f"hand_v=({self._scene.hand_display.x:.1f}, {self._scene.hand_display.y:.1f})  "
            f"red_v=({self._scene.red_display.x:.1f}, {self._scene.red_display.y:.1f})  "
            f"red_r=({self._scene.frame.red.x:.1f}, {self._scene.frame.red.y:.1f})  "
            f"blue=({self._scene.frame.blue.x:.1f}, {self._scene.frame.blue.y:.1f})"
        )
        self.canvas.create_rectangle(20, 20, 1210, 65, fill="#10253f", outline="")
        self.canvas.create_text(
            34,
            43,
            anchor="w",
            text=status,
            fill="#eff6ff",
            font=("Consolas", 14, "bold"),
        )
