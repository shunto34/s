"""VOICEVOX ENGINE 経由のナレーション生成。

VOICEVOX が起動していない場合は推定秒数の無音 WAV を返すフォールバックを持つ。
（CI / サンドボックス / 開発初期に動画パイプラインだけ通したいケース用。）

API 仕様: https://voicevox.github.io/voicevox_engine/api/
"""
from __future__ import annotations

import io
import json
import logging
import struct
import wave
from dataclasses import dataclass
from pathlib import Path

import requests


log = logging.getLogger(__name__)


@dataclass
class VoicePreset:
    name: str
    speaker_id: int
    speed: float = 1.0
    pitch: float = 0.0
    intonation: float = 1.0


class VoicevoxUnavailable(RuntimeError):
    """VOICEVOX に接続できないとき。"""


class VoicevoxClient:
    def __init__(self, endpoint: str = "http://localhost:50021", timeout: float = 30.0):
        self.endpoint = endpoint.rstrip("/")
        self.timeout = timeout

    def ping(self) -> bool:
        try:
            r = requests.get(f"{self.endpoint}/version", timeout=3)
            return r.status_code == 200
        except requests.RequestException:
            return False

    def synthesize(self, text: str, preset: VoicePreset) -> bytes:
        """テキストを WAV バイト列に変換。"""
        if not self.ping():
            raise VoicevoxUnavailable(
                f"VOICEVOX ENGINE に接続できません ({self.endpoint})."
            )
        # 1) audio_query
        q = requests.post(
            f"{self.endpoint}/audio_query",
            params={"text": text, "speaker": preset.speaker_id},
            timeout=self.timeout,
        )
        q.raise_for_status()
        query = q.json()
        query["speedScale"] = preset.speed
        query["pitchScale"] = preset.pitch
        query["intonationScale"] = preset.intonation
        # 2) synthesis
        s = requests.post(
            f"{self.endpoint}/synthesis",
            params={"speaker": preset.speaker_id},
            data=json.dumps(query),
            headers={"Content-Type": "application/json"},
            timeout=self.timeout,
        )
        s.raise_for_status()
        return s.content


# --- フォールバック ---------------------------------------------------------

def _silent_wav(duration_seconds: float, sample_rate: int = 24000) -> bytes:
    """指定秒数の 16bit モノラル無音 WAV を生成して返す。"""
    n_samples = max(1, int(round(duration_seconds * sample_rate)))
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(struct.pack("<" + "h" * n_samples, *([0] * n_samples)))
    return buf.getvalue()


def _estimate_duration(text: str, speed: float = 1.0) -> float:
    """日本語テキストのおおまかな読み上げ時間（秒）。"""
    # 約 8 mora/秒（標準速度）。1文字 ≒ 1モーラとして粗算。
    chars = len(text)
    base = chars / 8.0
    return max(0.4, base / max(0.5, speed))


# --- 高レベル API -----------------------------------------------------------

def synthesize_to_file(
    text: str,
    preset: VoicePreset,
    out_path: Path,
    *,
    endpoint: str = "http://localhost:50021",
    allow_silent_fallback: bool = False,
) -> Path:
    """テキストを WAV ファイルに保存して返す。

    allow_silent_fallback=True かつ VOICEVOX に接続できない場合、
    推定秒数の無音 WAV を書き出す（開発用）。
    """
    out_path.parent.mkdir(parents=True, exist_ok=True)
    client = VoicevoxClient(endpoint=endpoint)
    try:
        data = client.synthesize(text, preset)
    except VoicevoxUnavailable:
        if not allow_silent_fallback:
            raise
        log.warning(
            "VOICEVOX 未起動: 無音 WAV にフォールバック (%s)", out_path.name
        )
        data = _silent_wav(_estimate_duration(text, preset.speed))
    out_path.write_bytes(data)
    return out_path


def load_presets_from_config(cfg: dict) -> dict[str, VoicePreset]:
    out: dict[str, VoicePreset] = {}
    for name, params in (cfg.get("voicevox") or {}).get("voices", {}).items():
        out[name] = VoicePreset(
            name=name,
            speaker_id=int(params["speaker_id"]),
            speed=float(params.get("speed", 1.0)),
            pitch=float(params.get("pitch", 0.0)),
            intonation=float(params.get("intonation", 1.0)),
        )
    return out


if __name__ == "__main__":
    import sys
    import tempfile

    text = sys.argv[1] if len(sys.argv) > 1 else "これはVOICEVOXのテストです"
    preset = VoicePreset(name="test", speaker_id=33, speed=1.1)
    out = Path(tempfile.gettempdir()) / "voicevox_test.wav"
    synthesize_to_file(text, preset, out, allow_silent_fallback=True)
    print(f"wrote {out} ({out.stat().st_size} bytes)")
