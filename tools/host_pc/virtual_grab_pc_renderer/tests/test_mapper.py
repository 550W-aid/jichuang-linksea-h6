from pathlib import Path
import sys
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = PROJECT_ROOT / "src"
sys.path.insert(0, str(SRC_ROOT))

from mapper import map_detection_to_virtual  # type: ignore
from model import BlobDetection, DetectionFrame, ImagePoint  # type: ignore


class MapperTests(unittest.TestCase):
    def test_maps_origin_to_zero_and_green_to_positive_x(self) -> None:
        frame = DetectionFrame(
            frame_id=1,
            origin=ImagePoint(100.0, 200.0),
            green=BlobDetection(150.0, 200.0, 20.0),
            red=BlobDetection(125.0, 225.0, 18.0),
            blue=BlobDetection(80.0, 180.0, 25.0),
        )

        mapped = map_detection_to_virtual(frame, green_distance=200.0)

        self.assertAlmostEqual(mapped.origin.x, 0.0)
        self.assertAlmostEqual(mapped.origin.y, 0.0)
        self.assertAlmostEqual(mapped.green.x, 200.0)
        self.assertAlmostEqual(mapped.green.y, 0.0)
        self.assertAlmostEqual(mapped.red.x, 100.0)
        self.assertAlmostEqual(mapped.red.y, -100.0)

    def test_uses_green_vector_as_reference_axis_even_when_rotated(self) -> None:
        frame = DetectionFrame(
            frame_id=2,
            origin=ImagePoint(100.0, 100.0),
            green=BlobDetection(100.0, 140.0, 20.0),
            red=BlobDetection(140.0, 100.0, 18.0),
            blue=BlobDetection(80.0, 100.0, 18.0),
        )

        mapped = map_detection_to_virtual(frame, green_distance=160.0)

        self.assertAlmostEqual(mapped.green.x, 160.0)
        self.assertAlmostEqual(mapped.green.y, 0.0)
        self.assertAlmostEqual(mapped.red.x, 0.0)
        self.assertAlmostEqual(mapped.red.y, 160.0)
        self.assertAlmostEqual(mapped.blue.y, -80.0)


if __name__ == "__main__":
    unittest.main()
