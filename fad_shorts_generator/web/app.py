"""fad_shorts_generator の Web UI（Flask）。

ブラウザのフォームから値を入れて生成ボタンを押すと、
バックグラウンドで generate.py をサブプロセス起動し、
進捗をポーリングで返す。

起動:
    cd fad_shorts_generator
    source .venv/bin/activate
    python -m web.app          # → http://127.0.0.1:8765
"""
from __future__ import annotations

import datetime as dt
import json
import re
import shutil
import subprocess
import sys
import threading
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path

import requests
import yaml
from flask import Flask, jsonify, render_template, request, send_from_directory


PROJECT_ROOT = Path(__file__).resolve().parent.parent
INPUT_DIR = PROJECT_ROOT / "input"
OUTPUT_DIR = PROJECT_ROOT / "output"
TEMPLATES_DIR = PROJECT_ROOT / "templates"
BGM_DIR = PROJECT_ROOT / "assets" / "bgm"
SFX_DIR = PROJECT_ROOT / "assets" / "sfx"

INPUT_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

app = Flask(
    __name__,
    template_folder=str(Path(__file__).parent / "templates"),
    static_folder=str(Path(__file__).parent / "static"),
)


# ---------------------------------------------------------------------------
# ジョブ状態管理（インメモリ）
# ---------------------------------------------------------------------------

@dataclass
class Job:
    id: str
    state: str = "queued"            # queued | running | done | error
    progress: int = 0                # 0-100
    phase: str = ""                  # "シーン構築中" 等
    output: str | None = None        # 出力 mp4 ファイル名（output/ 配下）
    error: str | None = None
    log: list[str] = field(default_factory=list)
    started_at: float = field(default_factory=time.time)
    finished_at: float | None = None


JOBS: dict[str, Job] = {}
JOBS_LOCK = threading.Lock()


# ---------------------------------------------------------------------------
# 設定ロード
# ---------------------------------------------------------------------------

def load_config() -> dict:
    return yaml.safe_load((PROJECT_ROOT / "config.yaml").read_text(encoding="utf-8"))


def list_templates() -> list[dict]:
    out = []
    for p in sorted(TEMPLATES_DIR.glob("pattern_*.yaml")):
        try:
            data = yaml.safe_load(p.read_text(encoding="utf-8"))
        except Exception:
            continue
        # pattern_a_hook.yaml → "pattern_a"
        key = "_".join(p.stem.split("_")[:2])
        out.append({
            "key": key,
            "name": data.get("name", p.stem),
            "title": data.get("title", ""),
            "hook_text": data.get("hook_text", ""),
            "description": data.get("description", ""),
        })
    return out


def list_bgm() -> list[str]:
    if not BGM_DIR.exists():
        return []
    return sorted([p.name for p in BGM_DIR.iterdir()
                   if p.suffix.lower() in (".mp3", ".wav", ".m4a", ".ogg")])


def list_outputs() -> list[dict]:
    files = sorted(OUTPUT_DIR.glob("*.mp4"), key=lambda p: p.stat().st_mtime, reverse=True)
    return [
        {
            "name": p.name,
            "size_mb": round(p.stat().st_size / (1024 * 1024), 2),
            "mtime": dt.datetime.fromtimestamp(p.stat().st_mtime).strftime("%Y-%m-%d %H:%M"),
        }
        for p in files[:30]
    ]


def voicevox_status() -> dict:
    cfg = load_config()
    endpoint = cfg["voicevox"]["endpoint"]
    try:
        r = requests.get(f"{endpoint}/version", timeout=2)
        if r.status_code == 200:
            return {"alive": True, "version": r.text.strip().strip('"'), "endpoint": endpoint}
    except requests.RequestException:
        pass
    return {"alive": False, "version": None, "endpoint": endpoint}


# ---------------------------------------------------------------------------
# 進捗パース
# ---------------------------------------------------------------------------

FRAME_RE = re.compile(r"frame_index:\s+(\d+)%\|")
CHUNK_RE = re.compile(r"chunk:\s+(\d+)%\|")
DONE_RE = re.compile(r"完了:\s+(.+\.mp4)")
TOTAL_FRAMES = 900


def update_progress_from_line(job: Job, line: str) -> None:
    line = line.strip()
    if not line:
        return
    if "シーン構築開始" in line:
        job.phase = "シーン構築"
        job.progress = max(job.progress, 5)
    elif "総尺" in line:
        job.phase = "音声合成"
        job.progress = max(job.progress, 10)
    elif "MoviePy - Writing audio" in line:
        job.phase = "音声書き出し"
        job.progress = max(job.progress, 15)
    elif "MoviePy - Writing video" in line:
        job.phase = "動画書き出し"
        job.progress = max(job.progress, 20)
    elif m := FRAME_RE.search(line):
        pct = int(m.group(1))
        job.phase = "動画書き出し"
        # 動画書き出しを 20%-95% に割り当て
        job.progress = max(job.progress, 20 + int(pct * 0.75))
    elif m := CHUNK_RE.search(line):
        pct = int(m.group(1))
        job.phase = "音声書き出し"
        job.progress = max(job.progress, 10 + int(pct * 0.05))
    elif m := DONE_RE.search(line):
        out_path = Path(m.group(1))
        job.output = out_path.name
        job.progress = 100
        job.phase = "完了"


# ---------------------------------------------------------------------------
# 実行スレッド
# ---------------------------------------------------------------------------

def run_job(job: Job, args: list[str]) -> None:
    job.state = "running"
    job.log.append(f"$ python generate.py {' '.join(args)}")
    try:
        proc = subprocess.Popen(
            [sys.executable, "generate.py", *args],
            cwd=str(PROJECT_ROOT),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
    except Exception as e:
        job.state = "error"
        job.error = str(e)
        job.finished_at = time.time()
        return

    assert proc.stdout is not None
    for raw in proc.stdout:
        line = raw.rstrip()
        # tqdm が \r で更新するため複数の進捗が同じ行に来る場合がある
        for sub in line.replace("\r", "\n").split("\n"):
            if not sub.strip():
                continue
            job.log.append(sub[:400])
            if len(job.log) > 400:
                del job.log[: len(job.log) - 400]
            update_progress_from_line(job, sub)

    rc = proc.wait()
    job.finished_at = time.time()
    if rc != 0 and not job.output:
        job.state = "error"
        job.error = f"generate.py が終了コード {rc} で失敗"
        return
    if not job.output:
        # ログから完了行を検出できなかった場合、最新の mp4 を拾う
        files = sorted(OUTPUT_DIR.glob("*.mp4"), key=lambda p: p.stat().st_mtime, reverse=True)
        if files and files[0].stat().st_mtime >= job.started_at - 1:
            job.output = files[0].name
    job.state = "done"
    job.progress = 100
    job.phase = "完了"


# ---------------------------------------------------------------------------
# ルート
# ---------------------------------------------------------------------------

@app.route("/")
def index():
    return render_template(
        "index.html",
        templates=list_templates(),
        bgm_files=list_bgm(),
        voicevox=voicevox_status(),
        outputs=list_outputs(),
    )


@app.route("/api/status")
def api_status():
    return jsonify({
        "voicevox": voicevox_status(),
        "outputs": list_outputs(),
        "bgm_files": list_bgm(),
    })


@app.post("/api/generate")
def api_generate():
    f = request.files.get("chart")
    if not f or not f.filename:
        return jsonify({"error": "チャート画像が必要です"}), 400

    # 入力ファイル保存
    ts = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    ext = Path(f.filename).suffix.lower() or ".png"
    if ext not in (".png", ".jpg", ".jpeg", ".webp"):
        return jsonify({"error": f"未対応の画像形式: {ext}"}), 400
    saved = INPUT_DIR / f"web_{ts}{ext}"
    f.save(str(saved))

    form = request.form

    def _int(key, default):
        v = form.get(key)
        try:
            return int(v) if v not in (None, "") else default
        except ValueError:
            return default

    profit = _int("profit", None)
    if profit is None:
        return jsonify({"error": "損益を整数で入力してください"}), 400

    args = [
        "--chart", str(saved),
        "--profit", str(profit),
        "--score", str(_int("score", 55)),
        "--bias", form.get("bias", "BEAR"),
        "--pattern", form.get("pattern", "pattern_a"),
        "--pips", str(_int("pips", 20)),
        "--voice", form.get("voice", "genno"),
    ]
    if hook := form.get("hook_text", "").strip():
        args += ["--hook-text", hook]
    if bgm := form.get("bgm", "").strip():
        args += ["--bgm", bgm]
    if form.get("allow_silent_fallback") == "on":
        args += ["--allow-silent-fallback"]

    job_id = uuid.uuid4().hex[:12]
    job = Job(id=job_id)
    with JOBS_LOCK:
        JOBS[job_id] = job

    t = threading.Thread(target=run_job, args=(job, args), daemon=True)
    t.start()
    return jsonify({"job_id": job_id})


@app.get("/api/jobs/<job_id>")
def api_job(job_id: str):
    with JOBS_LOCK:
        job = JOBS.get(job_id)
    if not job:
        return jsonify({"error": "job not found"}), 404
    return jsonify({
        "id": job.id,
        "state": job.state,
        "progress": job.progress,
        "phase": job.phase,
        "output": job.output,
        "error": job.error,
        "log_tail": job.log[-30:],
        "elapsed": int((job.finished_at or time.time()) - job.started_at),
    })


@app.get("/video/<path:filename>")
def serve_video(filename: str):
    return send_from_directory(str(OUTPUT_DIR), filename, conditional=True)


@app.post("/api/voicevox/start")
def api_voicevox_start():
    """Docker のVOICEVOX起動を試行。"""
    try:
        r = subprocess.run(
            ["docker", "start", "voicevox"],
            capture_output=True, text=True, timeout=15,
        )
        ok = r.returncode == 0
        # 起動待ち
        for _ in range(10):
            time.sleep(1)
            if voicevox_status()["alive"]:
                ok = True
                break
        return jsonify({"ok": ok, "stdout": r.stdout, "stderr": r.stderr,
                        "status": voicevox_status()})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main() -> None:
    port = 8765
    print(f"\n  fad_shorts_generator Web UI")
    print(f"  → http://127.0.0.1:{port}\n")
    app.run(host="127.0.0.1", port=port, debug=False, threaded=True)


if __name__ == "__main__":
    main()
