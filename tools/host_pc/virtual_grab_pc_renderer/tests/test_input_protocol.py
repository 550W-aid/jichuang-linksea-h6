from pathlib import Path
import sys
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = PROJECT_ROOT / "src"
sys.path.insert(0, str(SRC_ROOT))

from input_protocol import FrameLineDecoder, parse_frame_line  # type: ignore


class InputProtocolTests(unittest.TestCase):
    def test_parses_json_line_into_detection_frame(self) -> None:
        frame = parse_frame_line(
            '{"frame_id":7,"origin":{"x":960,"y":540},'
            '"green":{"x":1080,"y":540,"radius":30},'
            '"red":{"x":850,"y":610,"radius":42},'
            '"blue":{"x":810,"y":560,"radius":55}}'
        )

        self.assertEqual(frame.frame_id, 7)
        self.assertEqual(frame.origin.x, 960.0)
        self.assertEqual(frame.green.radius, 30.0)
        self.assertEqual(frame.red.y, 610.0)
        self.assertEqual(frame.blue.x, 810.0)

    def test_rejects_missing_origin(self) -> None:
        with self.assertRaises(ValueError):
            parse_frame_line('{"frame_id":1,"red":{"x":1,"y":2,"radius":3}}')

    def test_decodes_fragmented_utf8_stream(self) -> None:
        decoder = FrameLineDecoder()
        chunk_1 = (
            b'{"frame_id":8,"origin":{"x":960,"y":540},"green":{"x":1080,"y":540,"radius":30},'
        )
        chunk_2 = (
            b'"red":{"x":850,"y":610,"radius":42},"blue":{"x":810,"y":560,"radius":55}}\n'
            b'{"frame_id":9,"origin":{"x":960,"y":540},"green":{"x":1080,"y":540,"radius":30},'
            b'"red":{"x":840,"y":620,"radius":42},"blue":{"x":800,"y":570,"radius":55}}\n'
        )

        first = decoder.feed(chunk_1)
        second = decoder.feed(chunk_2)

        self.assertEqual(first, [])
        self.assertEqual(len(second), 2)
        self.assertEqual(second[0].frame_id, 8)
        self.assertEqual(second[1].red.x, 840.0)


if __name__ == "__main__":
    unittest.main()
