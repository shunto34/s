"""Text-to-speech integration using edge-tts.

Generates Japanese narration audio from caption text.
"""

from __future__ import annotations

import asyncio
import logging
import tempfile
from pathlib import Path

from moviepy import AudioFileClip

logger = logging.getLogger(__name__)

# Default Japanese voice options
VOICES = {
    "nanami": "ja-JP-NanamiNeural",    # Female, natural
    "keita": "ja-JP-KeitaNeural",       # Male, natural
}

DEFAULT_VOICE = "ja-JP-NanamiNeural"


async def _generate_tts_async(
    text: str,
    output_path: str,
    voice: str = DEFAULT_VOICE,
    rate: str = "+0%",
    pitch: str = "+0Hz",
) -> str:
    """Generate TTS audio file asynchronously using edge-tts."""
    import edge_tts

    communicate = edge_tts.Communicate(
        text=text,
        voice=voice,
        rate=rate,
        pitch=pitch,
    )
    await communicate.save(output_path)
    return output_path


def generate_tts(
    text: str,
    voice: str = DEFAULT_VOICE,
    rate: str = "+0%",
    pitch: str = "+0Hz",
    output_dir: str | Path | None = None,
) -> AudioFileClip | None:
    """Generate TTS audio from text and return as a moviepy AudioClip.

    Args:
        text: Text to speak (Japanese supported).
        voice: edge-tts voice name.
        rate: Speech rate adjustment (e.g., "+10%", "-5%").
        pitch: Pitch adjustment (e.g., "+5Hz").
        output_dir: Directory for temp files. Uses system temp if None.

    Returns:
        AudioFileClip or None if generation fails.
    """
    if not text or not text.strip():
        return None

    try:
        if output_dir:
            Path(output_dir).mkdir(parents=True, exist_ok=True)
            tmp_file = Path(output_dir) / f"tts_{hash(text) & 0xFFFFFFFF:08x}.mp3"
            output_path = str(tmp_file)
        else:
            tmp = tempfile.NamedTemporaryFile(suffix=".mp3", delete=False)
            output_path = tmp.name
            tmp.close()

        # Run async edge-tts
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = None

        if loop and loop.is_running():
            # We're inside an existing event loop - use a new thread
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                future = pool.submit(
                    asyncio.run,
                    _generate_tts_async(text, output_path, voice, rate, pitch),
                )
                future.result(timeout=30)
        else:
            asyncio.run(
                _generate_tts_async(text, output_path, voice, rate, pitch)
            )

        clip = AudioFileClip(output_path)
        logger.info(f"TTS generated: {len(text)} chars -> {clip.duration:.1f}s")
        return clip

    except ImportError:
        logger.warning("edge-tts not installed. Run: pip install edge-tts")
        return None
    except Exception as e:
        logger.warning(f"TTS generation failed: {e}")
        return None


def generate_segment_narrations(
    captions: list[tuple[str, float]],
    voice: str = DEFAULT_VOICE,
    output_dir: str | Path | None = None,
) -> list[tuple[AudioFileClip | None, float]]:
    """Generate TTS for multiple segments.

    Args:
        captions: List of (text, start_time) tuples.
        voice: Voice to use for all segments.
        output_dir: Directory for temp audio files.

    Returns:
        List of (AudioClip or None, start_time) tuples.
    """
    results = []
    for text, start_time in captions:
        clip = generate_tts(text, voice=voice, output_dir=output_dir)
        results.append((clip, start_time))
    return results
