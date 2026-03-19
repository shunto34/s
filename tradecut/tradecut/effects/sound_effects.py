"""Programmatic sound effect generation using numpy.

Generates transition sounds, impact hits, success chimes, etc.
without requiring external audio files.
"""

from __future__ import annotations

import numpy as np
from moviepy import AudioClip


# Standard audio sample rate
SAMPLE_RATE = 44100


def _envelope(duration: float, attack: float = 0.01, release: float = 0.1) -> np.ndarray:
    """Create an amplitude envelope with attack and release."""
    n = int(duration * SAMPLE_RATE)
    env = np.ones(n)
    attack_samples = int(attack * SAMPLE_RATE)
    release_samples = int(release * SAMPLE_RATE)

    if attack_samples > 0:
        env[:attack_samples] = np.linspace(0, 1, attack_samples)
    if release_samples > 0 and release_samples < n:
        env[-release_samples:] = np.linspace(1, 0, release_samples)

    return env


def _to_audio_clip(samples: np.ndarray, duration: float) -> AudioClip:
    """Convert a numpy array of samples to a moviepy AudioClip."""
    # Normalize to [-1, 1]
    peak = np.max(np.abs(samples))
    if peak > 0:
        samples = samples / peak

    def make_frame(t):
        # t can be a float or array
        indices = np.int64(np.atleast_1d(t) * SAMPLE_RATE)
        indices = np.clip(indices, 0, len(samples) - 1)
        result = samples[indices]
        # Return stereo (2 channels)
        return np.column_stack([result, result])

    return AudioClip(make_frame, duration=duration, fps=SAMPLE_RATE)


def generate_whoosh(duration: float = 0.4, volume: float = 0.3) -> AudioClip:
    """Generate a 'whoosh' sweep sound for transitions.

    A frequency sweep from low to high with noise modulation.
    """
    n = int(duration * SAMPLE_RATE)
    t = np.linspace(0, duration, n)

    # Frequency sweep from 200Hz to 2000Hz
    freq = np.linspace(200, 2000, n)
    phase = 2 * np.pi * np.cumsum(freq) / SAMPLE_RATE
    sweep = np.sin(phase) * 0.5

    # Add filtered noise for texture
    noise = np.random.randn(n) * 0.3
    # Simple low-pass by averaging
    kernel_size = 50
    kernel = np.ones(kernel_size) / kernel_size
    noise = np.convolve(noise, kernel, mode="same")

    samples = (sweep + noise) * _envelope(duration, attack=0.02, release=duration * 0.4)
    samples *= volume

    return _to_audio_clip(samples, duration)


def generate_impact(duration: float = 0.3, volume: float = 0.5) -> AudioClip:
    """Generate a deep impact/hit sound.

    Low-frequency burst that decays quickly - the 'DON' effect.
    """
    n = int(duration * SAMPLE_RATE)
    t = np.linspace(0, duration, n)

    # Low frequency body (60-80Hz with decay)
    freq_decay = 80 * np.exp(-t * 3)
    phase = 2 * np.pi * np.cumsum(freq_decay) / SAMPLE_RATE
    body = np.sin(phase)

    # Sub-bass punch
    sub = np.sin(2 * np.pi * 40 * t) * np.exp(-t * 8)

    # Transient click at the start
    click_dur = int(0.005 * SAMPLE_RATE)
    click = np.zeros(n)
    click[:click_dur] = np.random.randn(click_dur) * 2

    samples = (body * 0.6 + sub * 0.3 + click * 0.1) * _envelope(duration, attack=0.001, release=duration * 0.8)
    samples *= volume

    return _to_audio_clip(samples, duration)


def generate_success(duration: float = 0.6, volume: float = 0.35) -> AudioClip:
    """Generate a success/win chime.

    Ascending two-tone with harmonics - a positive notification sound.
    """
    n = int(duration * SAMPLE_RATE)
    t = np.linspace(0, duration, n)

    half = n // 2
    samples = np.zeros(n)

    # First note: C5 (523Hz)
    t1 = t[:half]
    note1 = np.sin(2 * np.pi * 523 * t1) + 0.3 * np.sin(2 * np.pi * 1046 * t1)
    note1 *= _envelope(duration / 2, attack=0.01, release=0.1)
    samples[:half] = note1

    # Second note: E5 (659Hz) - major third up
    t2 = t[half:]
    note2 = np.sin(2 * np.pi * 659 * t2) + 0.3 * np.sin(2 * np.pi * 1318 * t2)
    note2 *= _envelope(duration / 2, attack=0.01, release=0.15)
    samples[half:] = note2

    samples *= volume

    return _to_audio_clip(samples, duration)


def generate_fail(duration: float = 0.5, volume: float = 0.3) -> AudioClip:
    """Generate a loss/fail sound.

    Descending tone - conveys negative result.
    """
    n = int(duration * SAMPLE_RATE)
    t = np.linspace(0, duration, n)

    # Descending frequency from 400Hz to 200Hz
    freq = np.linspace(400, 200, n)
    phase = 2 * np.pi * np.cumsum(freq) / SAMPLE_RATE
    samples = np.sin(phase) + 0.2 * np.sin(phase * 2)

    samples *= _envelope(duration, attack=0.01, release=duration * 0.5)
    samples *= volume

    return _to_audio_clip(samples, duration)


def generate_tick(duration: float = 0.05, volume: float = 0.2) -> AudioClip:
    """Generate a short tick sound for count-up animations."""
    n = int(duration * SAMPLE_RATE)
    t = np.linspace(0, duration, n)

    # Short high-frequency click
    samples = np.sin(2 * np.pi * 1200 * t) * np.exp(-t * 60)
    samples *= volume

    return _to_audio_clip(samples, duration)


def generate_notification(duration: float = 0.4, volume: float = 0.3) -> AudioClip:
    """Generate a notification chime sound.

    A pleasant short bell-like tone.
    """
    n = int(duration * SAMPLE_RATE)
    t = np.linspace(0, duration, n)

    # Bell-like: fundamental + inharmonic overtones
    f0 = 880  # A5
    samples = (
        np.sin(2 * np.pi * f0 * t) * 1.0
        + np.sin(2 * np.pi * f0 * 2.76 * t) * 0.3  # inharmonic
        + np.sin(2 * np.pi * f0 * 5.4 * t) * 0.1
    )

    samples *= np.exp(-t * 6)  # Fast decay like a bell
    samples *= _envelope(duration, attack=0.001, release=0.05)
    samples *= volume

    return _to_audio_clip(samples, duration)
