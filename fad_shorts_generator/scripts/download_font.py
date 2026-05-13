"""Noto Sans CJK JP Bold を assets/fonts/ に DL する。

setup.sh から呼び出される想定。既に同名ファイルがあればスキップ。
本体は github.com/notofonts/noto-cjk からダウンロード。
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path
from urllib.request import Request, urlopen


PROJECT_ROOT = Path(__file__).resolve().parent.parent
FONT_DIR = PROJECT_ROOT / "assets" / "fonts"

FONTS = [
    {
        "name": "NotoSansCJKjp-Bold.otf",
        "url": "https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/Japanese/NotoSansCJKjp-Bold.otf",
    },
    {
        "name": "NotoSansCJKjp-Regular.otf",
        "url": "https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/Japanese/NotoSansCJKjp-Regular.otf",
    },
]


def download(url: str, out: Path) -> None:
    req = Request(url, headers={"User-Agent": "fad_shorts_generator/1.0"})
    with urlopen(req, timeout=60) as r, out.open("wb") as f:
        while True:
            chunk = r.read(64 * 1024)
            if not chunk:
                break
            f.write(chunk)


def main() -> int:
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    for f in FONTS:
        out = FONT_DIR / f["name"]
        if out.exists() and out.stat().st_size > 1024 * 1024:
            print(f"[skip] {out} (already {out.stat().st_size:,} bytes)")
            continue
        print(f"[dl ] {f['url']} -> {out}")
        try:
            download(f["url"], out)
        except Exception as e:
            print(f"[err ] {f['name']}: {e}", file=sys.stderr)
            return 1
        print(f"[ok ] {out} ({out.stat().st_size:,} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
