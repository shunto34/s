"""narration 単体テスト（VOICEVOX未起動でフォールバックが動くか）。"""
from __future__ import annotations

import sys
import tempfile
import wave
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from narration import VoicePreset, synthesize_to_file  # noqa: E402


def test_silent_fallback_writes_valid_wav():
    preset = VoicePreset(name="test", speaker_id=33, speed=1.1)
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "test.wav"
        synthesize_to_file(
            "これはテストです",
            preset,
            out,
            endpoint="http://localhost:65535",  # 確実に閉じてるポート
            allow_silent_fallback=True,
        )
        assert out.exists()
        with wave.open(str(out), "rb") as w:
            assert w.getnchannels() == 1
            assert w.getsampwidth() == 2
            # ≒ 8文字 / 8mora/s / 1.1 ≒ 0.9秒
            duration = w.getnframes() / w.getframerate()
            assert 0.4 <= duration <= 2.5


if __name__ == "__main__":
    test_silent_fallback_writes_valid_wav()
    print("OK")
