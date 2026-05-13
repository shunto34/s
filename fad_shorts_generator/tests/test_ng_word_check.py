"""ng_word_check 単体テスト（pytestなし、最小実装）。"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ng_word_check import NgWordError, assert_clean, find_hits  # noqa: E402


def test_clean_text():
    assert find_hits("今日は控えめに-20pips取りました") == []


def test_detects_word():
    hits = find_hits("絶対に勝てる手法")
    assert len(hits) == 1
    assert hits[0].word == "絶対"


def test_assert_raises():
    try:
        assert_clean([("a", "投資助言です")])
    except NgWordError:
        return
    raise AssertionError("expected NgWordError")


def test_assert_ok_passes():
    assert_clean([
        ("a", "今日のスコア55"),
        ("b", "↓ 30分後 ↓"),
        ("c", "続きはDiscordで毎日配信中"),
    ])


if __name__ == "__main__":
    fns = [test_clean_text, test_detects_word, test_assert_raises, test_assert_ok_passes]
    for fn in fns:
        fn()
        print(f"OK: {fn.__name__}")
    print("all passed")
