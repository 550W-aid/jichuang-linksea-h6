from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = PROJECT_ROOT / "src"
sys.path.insert(0, str(SRC_ROOT))

from renderer import VirtualGrabRenderer  # type: ignore


class RendererLoopTests(unittest.TestCase):
    def test_tick_does_not_reenter_tk_update_during_normal_run(self) -> None:
        root = Mock()
        root.title = Mock()
        root.protocol = Mock()
        root.after = Mock()
        root.mainloop = Mock()
        root.update = Mock()
        root.update_idletasks = Mock()
        root.destroy = Mock()
        root.winfo_exists = Mock(return_value=True)

        canvas = Mock()
        canvas.pack = Mock()
        canvas.delete = Mock()
        canvas.create_text = Mock()
        canvas.create_polygon = Mock()
        canvas.create_line = Mock()
        canvas.create_rectangle = Mock()
        canvas.create_oval = Mock()

        source = Mock()
        source.get_latest_frame.return_value = None

        with (
            patch("renderer.tk.Tk", return_value=root),
            patch("renderer.tk.Canvas", return_value=canvas),
        ):
            renderer = VirtualGrabRenderer(source)

        renderer._running = True
        renderer._tick()

        root.update.assert_not_called()
        root.update_idletasks.assert_not_called()
        root.after.assert_called_once()


if __name__ == "__main__":
    unittest.main()
