"""NGワードチェッカー。

仕様：generate.py 実行時、テロップ / ナレ文字列に NG ワードが含まれていれば
生成を即停止する。テンプレート（pattern_*.yaml）のレビューにも使う。
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


NG_WORDS: tuple[str, ...] = (
    "絶対",
    "確実",
    "100%勝てる",
    "必ず勝てる",
    "保証",
    "儲かります",
    "投資助言",
    "投資顧問",
    "推奨",
    "元本保証",
    "リスクなし",
    "誰でも稼げる",
)


class NgWordError(Exception):
    """NGワード検出時に投げる例外。"""


@dataclass(frozen=True)
class NgHit:
    field: str
    word: str
    text: str


def find_hits(text: str, field: str = "") -> list[NgHit]:
    hits: list[NgHit] = []
    if not text:
        return hits
    for w in NG_WORDS:
        if w in text:
            hits.append(NgHit(field=field, word=w, text=text))
    return hits


def assert_clean(items: Iterable[tuple[str, str]]) -> None:
    """`(field_name, text)` の列を受け取り、NGワードがあれば例外送出。"""
    all_hits: list[NgHit] = []
    for field, text in items:
        all_hits.extend(find_hits(text, field=field))
    if all_hits:
        lines = [
            f"  - [{h.field}] NG: 「{h.word}」 in: {h.text!r}" for h in all_hits
        ]
        raise NgWordError(
            "NGワード検出につき動画生成を停止します:\n" + "\n".join(lines)
        )


if __name__ == "__main__":
    # 簡易セルフテスト
    samples = [
        ("ok_text", "今日は控えめに-20pips取りました"),
        ("bad_text", "絶対勝てる手法を公開"),
    ]
    try:
        assert_clean(samples)
    except NgWordError as e:
        print("OK: 期待通り例外発生")
        print(e)
    else:
        print("ERROR: 例外が発生しませんでした")
