// fad_shorts_generator — front-end
(() => {
  const $ = (id) => document.getElementById(id);
  const dropzone = $("dropzone");
  const chartInput = $("chart");
  const preview = $("chart-preview");
  const generateBtn = $("generate");
  const progressWrap = $("progress-wrap");
  const barFill = $("bar-fill");
  const phaseEl = $("phase");
  const elapsedEl = $("elapsed");
  const logEl = $("log");
  const resultEl = $("result");
  const outputsEl = $("outputs");
  const vvStart = $("vv-start");

  let chartFile = null;
  let currentJobId = null;
  let pollTimer = null;

  // --- dropzone ----------------------------------------------------------
  dropzone.addEventListener("click", () => chartInput.click());
  chartInput.addEventListener("change", (e) => {
    if (e.target.files[0]) setChart(e.target.files[0]);
  });
  ["dragenter", "dragover"].forEach((ev) =>
    dropzone.addEventListener(ev, (e) => { e.preventDefault(); dropzone.classList.add("hover"); })
  );
  ["dragleave", "drop"].forEach((ev) =>
    dropzone.addEventListener(ev, (e) => { e.preventDefault(); dropzone.classList.remove("hover"); })
  );
  dropzone.addEventListener("drop", (e) => {
    if (e.dataTransfer.files[0]) setChart(e.dataTransfer.files[0]);
  });
  function setChart(f) {
    chartFile = f;
    const url = URL.createObjectURL(f);
    preview.src = url;
    preview.hidden = false;
    dropzone.classList.add("has-file");
  }

  // --- VOICEVOX start button --------------------------------------------
  if (vvStart) {
    vvStart.addEventListener("click", async () => {
      vvStart.disabled = true;
      vvStart.textContent = "起動中...";
      try {
        const r = await fetch("/api/voicevox/start", { method: "POST" });
        const j = await r.json();
        if (j.ok) {
          location.reload();
        } else {
          alert("起動失敗: " + (j.error || j.stderr || "不明"));
          vvStart.disabled = false;
          vvStart.textContent = "起動を試す";
        }
      } catch (e) {
        alert("通信エラー: " + e);
        vvStart.disabled = false;
        vvStart.textContent = "起動を試す";
      }
    });
  }

  // --- Generate ---------------------------------------------------------
  generateBtn.addEventListener("click", async () => {
    if (!chartFile) {
      alert("チャート画像を選んでください");
      return;
    }
    const profit = $("profit").value;
    if (!profit || isNaN(parseInt(profit, 10))) {
      alert("損益（整数）を入力してください");
      return;
    }
    const fd = new FormData();
    fd.append("chart", chartFile);
    fd.append("profit", profit);
    fd.append("score", $("score").value || "55");
    fd.append("pips", $("pips").value || "20");
    fd.append("bias", $("bias").value);
    fd.append("voice", $("voice").value);
    fd.append("bgm", $("bgm").value);
    const pattern = document.querySelector('input[name="pattern"]:checked');
    fd.append("pattern", pattern ? pattern.value : "pattern_a");
    fd.append("hook_text", $("hook_text").value);
    if ($("allow_silent_fallback").checked) fd.append("allow_silent_fallback", "on");

    generateBtn.disabled = true;
    generateBtn.textContent = "生成中...";
    setProgressState("running");
    logEl.textContent = "";

    try {
      const r = await fetch("/api/generate", { method: "POST", body: fd });
      if (!r.ok) {
        const j = await r.json().catch(() => ({}));
        throw new Error(j.error || `HTTP ${r.status}`);
      }
      const { job_id } = await r.json();
      currentJobId = job_id;
      startPolling(job_id);
    } catch (e) {
      alert("送信エラー: " + e.message);
      setProgressState("idle");
      generateBtn.disabled = false;
      generateBtn.textContent = "▶ 動画を生成";
    }
  });

  // --- Polling ----------------------------------------------------------
  function startPolling(jobId) {
    if (pollTimer) clearInterval(pollTimer);
    pollTimer = setInterval(() => poll(jobId), 1200);
    poll(jobId);
  }

  async function poll(jobId) {
    let j;
    try {
      const r = await fetch(`/api/jobs/${jobId}`);
      if (!r.ok) throw new Error("status fetch failed");
      j = await r.json();
    } catch (e) {
      return;
    }
    barFill.style.width = (j.progress || 0) + "%";
    phaseEl.textContent = j.phase || j.state;
    elapsedEl.textContent = fmtElapsed(j.elapsed);
    if (j.log_tail && j.log_tail.length) {
      logEl.textContent = j.log_tail.join("\n");
      logEl.scrollTop = logEl.scrollHeight;
    }
    if (j.state === "done") {
      clearInterval(pollTimer); pollTimer = null;
      setProgressState("done");
      showResult(j.output);
      refreshOutputs();
      generateBtn.disabled = false;
      generateBtn.textContent = "▶ 動画を生成";
    } else if (j.state === "error") {
      clearInterval(pollTimer); pollTimer = null;
      setProgressState("error");
      phaseEl.textContent = "エラー";
      alert("生成失敗: " + (j.error || "不明"));
      generateBtn.disabled = false;
      generateBtn.textContent = "▶ 動画を生成";
    }
  }

  // --- Result -----------------------------------------------------------
  function showResult(filename) {
    if (!filename) return;
    const url = `/video/${encodeURIComponent(filename)}?t=${Date.now()}`;
    resultEl.classList.remove("empty");
    resultEl.innerHTML = `
      <video src="${url}" controls autoplay muted playsinline></video>
      <div class="meta">
        <span>${filename}</span>
        <a href="${url}" download="${filename}">⬇ ダウンロード</a>
      </div>
    `;
  }

  async function refreshOutputs() {
    try {
      const r = await fetch("/api/status");
      const j = await r.json();
      outputsEl.innerHTML = (j.outputs || []).map(o => `
        <li>
          <a href="/video/${encodeURIComponent(o.name)}" target="_blank">${o.name}</a>
          <small>${o.mtime} · ${o.size_mb} MB</small>
        </li>
      `).join("") || `<li class="muted">まだ生成された動画はありません。</li>`;
    } catch (e) { /* noop */ }
  }

  function setProgressState(state) {
    progressWrap.classList.remove("idle", "running", "done", "error");
    progressWrap.classList.add(state);
    if (state === "idle") {
      barFill.style.width = "0%";
      phaseEl.textContent = "待機中";
      elapsedEl.textContent = "—";
    }
  }

  function fmtElapsed(sec) {
    if (sec == null) return "—";
    const m = Math.floor(sec / 60), s = sec % 60;
    return `${m}:${String(s).padStart(2, "0")}`;
  }

  // Auto-refresh VOICEVOX status every 15s
  setInterval(async () => {
    try {
      const r = await fetch("/api/status");
      const j = await r.json();
      const dot = document.getElementById("vv-dot");
      if (dot && j.voicevox) {
        dot.classList.toggle("on", j.voicevox.alive);
        dot.classList.toggle("off", !j.voicevox.alive);
      }
    } catch (e) { /* noop */ }
  }, 15000);
})();
