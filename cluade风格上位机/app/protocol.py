from __future__ import annotations

import json
import struct
from dataclasses import dataclass


MAGIC_CCIC = b"CCIC"
MAGIC_VF = b"VF"


class PacketType:
    COMMAND = 0x01
    IMAGE = 0x02
    VIDEO = 0x03
    ALGO = 0x04


def build_ccic_packet(pkt_type: int, seq: int, payload: bytes) -> bytes:
    header = MAGIC_CCIC + bytes([pkt_type]) + struct.pack("<II", seq & 0xFFFFFFFF, len(payload))
    return header + payload


def parse_hex_string(text: str) -> bytes:
    cleaned = text.replace("0x", "").replace(" ", "").replace("\n", "").replace("\r", "")
    if len(cleaned) % 2 == 1:
        cleaned = "0" + cleaned
    return bytes.fromhex(cleaned)


def to_hex_line(data: bytes, group: int = 1) -> str:
    if group <= 1:
        return data.hex(" ").upper()
    hex_str = data.hex().upper()
    chunks = [hex_str[i : i + group * 2] for i in range(0, len(hex_str), group * 2)]
    return " ".join(chunks)


def build_algo_payload_json(algorithm: str, param: str, value: float | int | str) -> bytes:
    obj = {"alg": algorithm, "param": param, "value": value}
    return json.dumps(obj, ensure_ascii=False).encode("utf-8")


def build_algo_payload_csv(algorithm: str, param: str, value: float | int | str) -> bytes:
    return f"{algorithm},{param},{value}\n".encode("utf-8")


@dataclass(slots=True)
class VideoChunkConfig:
    mtu_payload: int = 1200


def chunk_frame_payload(frame_id: int, payload: bytes, cfg: VideoChunkConfig) -> list[bytes]:
    # header: magic(2) + frame_id(u32) + idx(u16) + total(u16) + len(u16)
    max_chunk_data = max(128, cfg.mtu_payload)
    total = (len(payload) + max_chunk_data - 1) // max_chunk_data
    out: list[bytes] = []
    for idx in range(total):
        start = idx * max_chunk_data
        end = min(len(payload), start + max_chunk_data)
        part = payload[start:end]
        header = MAGIC_VF + struct.pack("<IHHH", frame_id & 0xFFFFFFFF, idx, total, len(part))
        out.append(header + part)
    return out
