"""
FAD APEX AI Model Trainer
=========================
Builds a sigmoid classifier that predicts win-rate (0..1) for BULL/BEAR
signals produced by FadApex_v4.59.mq5 (Phase B / Layer 1).

Pipeline:
  1. Load MT5 historical OHLC CSV (exported from History Center or mt5 Python API)
  2. Re-simulate v4.59 signal logic offline in Python
  3. Label each signal with WIN (1) / LOSS (0) using +InpLearnWinPips / -InpLearnLossPips
     within the next InpLearnLookback bars
  4. Train LightGBM classifier on the 18-dim feature vector
  5. Export to ONNX (FadApex_AI.onnx) — drop into MQL5/Files/

Usage:
    python FadApex_AI_train.py --csv USDJPY_M15.csv --symbol USDJPY --pip 0.01
"""

from __future__ import annotations

import argparse
import os
from dataclasses import dataclass

import numpy as np
import pandas as pd

try:
    import lightgbm as lgb
    from sklearn.model_selection import train_test_split
    from sklearn.metrics import roc_auc_score, mean_squared_error
    from skl2onnx import convert_sklearn, update_registered_converter
    from skl2onnx.common.data_types import FloatTensorType
    from skl2onnx.common.shape_calculator import calculate_linear_regressor_output_shapes
    from onnxmltools.convert.lightgbm.operator_converters.LightGbm import (
        convert_lightgbm,
    )
except ImportError as e:
    raise SystemExit(
        f"Missing dependencies: {e}\n"
        "Install with:\n"
        "  pip install lightgbm scikit-learn skl2onnx onnxmltools onnxruntime pandas numpy"
    )


# --------------------------------------------------------------------------- #
# Configuration (must match FadApex_v4.59 defaults)
# --------------------------------------------------------------------------- #
EMA_LENS = [5, 8, 13, 21, 34, 55, 89, 144]
ADX_PERIOD = 14
ATR_PERIOD = 14
ADX_THRESHOLD = 18
RIBBON_ATR_RATIO = 0.8
COOLDOWN_BARS = 8
SWING_LOOKBACK = 10
LEARN_LOOKBACK = 20
LEARN_WIN_PIPS = 30
LEARN_LOSS_PIPS = 20

FEATURE_DIM = 18


# --------------------------------------------------------------------------- #
# Indicator calculations (vectorized)
# --------------------------------------------------------------------------- #
def ema(series: pd.Series, period: int) -> pd.Series:
    return series.ewm(span=period, adjust=False).mean()


def atr(high: pd.Series, low: pd.Series, close: pd.Series, period: int) -> pd.Series:
    tr = pd.concat(
        [
            high - low,
            (high - close.shift()).abs(),
            (low - close.shift()).abs(),
        ],
        axis=1,
    ).max(axis=1)
    return tr.ewm(alpha=1 / period, adjust=False).mean()


def adx(high: pd.Series, low: pd.Series, close: pd.Series, period: int) -> pd.Series:
    up = high.diff()
    dn = -low.diff()
    plus_dm = np.where((up > dn) & (up > 0), up, 0.0)
    minus_dm = np.where((dn > up) & (dn > 0), dn, 0.0)
    tr = pd.concat(
        [high - low, (high - close.shift()).abs(), (low - close.shift()).abs()],
        axis=1,
    ).max(axis=1)
    atr_s = tr.ewm(alpha=1 / period, adjust=False).mean()
    plus_di = 100 * pd.Series(plus_dm, index=high.index).ewm(alpha=1 / period, adjust=False).mean() / atr_s
    minus_di = 100 * pd.Series(minus_dm, index=high.index).ewm(alpha=1 / period, adjust=False).mean() / atr_s
    dx = 100 * (plus_di - minus_di).abs() / (plus_di + minus_di).replace(0, np.nan)
    return dx.ewm(alpha=1 / period, adjust=False).mean().fillna(0)


# --------------------------------------------------------------------------- #
# Feature extraction at each signal bar (must match MQL5 ExtractAIFeatures)
# --------------------------------------------------------------------------- #
@dataclass
class BarContext:
    i: int
    is_bull: bool
    score: int
    regime: int  # 0=trend 1=range 2=brkout
    session: int
    dow: int
    last_sig_bar: int


def detect_regime(atr_cur: float, atr_win: np.ndarray) -> int:
    if len(atr_win) < 10 or atr_cur <= 0:
        return 1
    mean = float(atr_win.mean())
    if mean <= 0:
        return 1
    std = float(atr_win.std())
    cv = std / mean
    if atr_cur > mean * 1.5:
        return 2
    if cv < 0.25:
        return 0
    return 1


def detect_session(ts: pd.Timestamp) -> int:
    h = ts.hour
    if 13 <= h < 21:
        return 2
    if 7 <= h < 13:
        return 1
    return 0


def extract_features(ctx: BarContext, df: pd.DataFrame, emas: list[np.ndarray],
                     atr_arr: np.ndarray, adx_arr: np.ndarray,
                     htf_align_count: int) -> np.ndarray:
    i = ctx.i
    row = df.iloc[i]
    prev = df.iloc[i - 1] if i > 0 else row
    close = float(row["close"])
    open_ = float(row["open"])
    atr_v = float(atr_arr[i]) if atr_arr[i] > 0 else 0.0
    adx_v = float(adx_arr[i])

    # EMA values at bar i
    ed = [float(e[i]) for e in emas]

    # [1] Perfect EMA order
    if ctx.is_bull:
        perf = all(ed[k] > ed[k + 1] for k in range(7))
    else:
        perf = all(ed[k] < ed[k + 1] for k in range(7))

    # [3] Ribbon width / ATR
    ribbon_w = abs(ed[0] - ed[7])
    feat_ribbon = (ribbon_w / atr_v) if atr_v > 0 else 0.0

    # [2] Body / ATR
    body = abs(close - open_)
    feat_body = (body / atr_v) if atr_v > 0 else 0.0

    # [8] Vol bucket
    lo = max(0, i - 29)
    win = atr_arr[lo : i + 1]
    atr_mean = float(win.mean()) if len(win) else 0.0
    vol_bucket = (atr_v / atr_mean) if atr_mean > 0 else 1.0

    # [13] Bars since last signal
    if ctx.last_sig_bar < 0:
        bars_since = 100
    else:
        bars_since = i - ctx.last_sig_bar
    bars_since_log = float(np.log1p(max(0, bars_since)))

    # [15] EMA compression
    ema_vals = np.array(ed)
    ema_std = float(ema_vals.std())
    ema_compress = (ema_std / close) if close > 0 else 0.0

    feat = np.zeros(FEATURE_DIM, dtype=np.float32)
    feat[0] = htf_align_count / 3.0
    feat[1] = 1.0 if perf else 0.0
    feat[2] = feat_body
    feat[3] = feat_ribbon
    feat[4] = ctx.score / 4.0
    # [5-7] Regime one-hot
    feat[5 + ctx.regime] = 1.0
    feat[8] = vol_bucket
    # [9-11] Session one-hot
    feat[9 + ctx.session] = 1.0
    feat[12] = ctx.dow / 6.0
    feat[13] = bars_since_log
    feat[14] = adx_v / 50.0
    feat[15] = ema_compress
    feat[16] = htf_align_count / 3.0
    feat[17] = 1.0 if ctx.is_bull else -1.0
    return feat


# --------------------------------------------------------------------------- #
# Signal detection + labeling (chart-timeframe only, single-TF simplification)
# --------------------------------------------------------------------------- #
def build_dataset(df: pd.DataFrame, pip: float) -> tuple[np.ndarray, np.ndarray]:
    """
    Re-simulates v4.59 signal logic on single timeframe (approximation of
    multi-TF alignment — uses EMA structure + ADX to proxy HTF agreement).
    Returns (X, y) where X shape = (N, 18), y in {0, 1}.
    """
    high = df["high"].values
    low = df["low"].values
    close = df["close"].values
    open_ = df["open"].values

    # Indicators
    emas = [ema(df["close"], L).values for L in EMA_LENS]
    atr_arr = atr(df["high"], df["low"], df["close"], ATR_PERIOD).values
    adx_arr = adx(df["high"], df["low"], df["close"], ADX_PERIOD).values

    n = len(df)
    feats: list[np.ndarray] = []
    labels: list[int] = []
    last_sig_bar = -1
    start_i = max(EMA_LENS[-1] + 10, SWING_LOOKBACK + 10)

    for i in range(start_i, n - LEARN_LOOKBACK - 1):
        e0, e7 = emas[0][i], emas[7][i]
        r_bull = e0 > e7

        # Transition: r_bull flipped from previous bar
        prev_bull = emas[0][i - 1] > emas[7][i - 1]
        if r_bull == prev_bull:
            continue

        is_bull = r_bull

        # Range filter
        if adx_arr[i] < ADX_THRESHOLD:
            continue
        ribbon_w = abs(e0 - e7)
        if atr_arr[i] > 0 and ribbon_w < atr_arr[i] * RIBBON_ATR_RATIO:
            continue
        if (i - last_sig_bar) < COOLDOWN_BARS:
            continue

        # --- Score 0-4 ---
        score = 0
        # Factor 1 (approx): ADX strength proxy for MTF alignment
        if adx_arr[i] >= 25:
            score += 1
        # Factor 2: Perfect EMA order
        if is_bull:
            perf = all(emas[k][i] > emas[k + 1][i] for k in range(7))
        else:
            perf = all(emas[k][i] < emas[k + 1][i] for k in range(7))
        if perf:
            score += 1
        # Factor 3: Candle momentum
        body = abs(close[i] - open_[i])
        look = min(20, i - start_i)
        avg_body = np.mean(np.abs(close[i - look : i] - open_[i - look : i])) if look > 0 else 0
        if avg_body > 0 and body > avg_body * 1.3:
            score += 1
        # Factor 4: Ribbon squeeze expansion
        sq_look = min(10, i - start_i)
        cur_w = ribbon_w
        min_w = cur_w
        for j in range(i - sq_look, i):
            min_w = min(min_w, abs(emas[0][j] - emas[7][j]))
        if cur_w > 0 and min_w < cur_w * 0.5:
            score += 1

        # Regime + session/dow
        lo = max(0, i - 29)
        regime = detect_regime(atr_arr[i], atr_arr[lo : i + 1])
        ts = df.index[i]
        session = detect_session(ts)
        dow = ts.dayofweek  # 0=Mon..4=Fri

        # HTF align count (proxy via EMA alignment over slower windows)
        # Count how many slower-EMA pairs confirm direction
        htf_align = 0
        if is_bull:
            if emas[2][i] > emas[5][i]: htf_align += 1  # "short HTF"
            if emas[3][i] > emas[6][i]: htf_align += 1  # "mid HTF"
            if emas[4][i] > emas[7][i]: htf_align += 1  # "long HTF"
        else:
            if emas[2][i] < emas[5][i]: htf_align += 1
            if emas[3][i] < emas[6][i]: htf_align += 1
            if emas[4][i] < emas[7][i]: htf_align += 1

        ctx = BarContext(
            i=i, is_bull=is_bull, score=score, regime=regime,
            session=session, dow=dow, last_sig_bar=last_sig_bar,
        )
        feat = extract_features(ctx, df, emas, atr_arr, adx_arr, htf_align)

        # --- Label: WIN=1, LOSS=0 (drop DRAW from training) ---
        win_delta = LEARN_WIN_PIPS * pip
        loss_delta = LEARN_LOSS_PIPS * pip
        entry = close[i]
        label = None
        for k in range(1, LEARN_LOOKBACK + 1):
            j = i + k
            if is_bull:
                if high[j] >= entry + win_delta:
                    label = 1
                    break
                if low[j] <= entry - loss_delta:
                    label = 0
                    break
            else:
                if low[j] <= entry - win_delta:
                    label = 1
                    break
                if high[j] >= entry + loss_delta:
                    label = 0
                    break
        if label is None:
            # DRAW — skip from training
            last_sig_bar = i
            continue

        feats.append(feat)
        labels.append(label)
        last_sig_bar = i

    X = np.stack(feats) if feats else np.zeros((0, FEATURE_DIM), dtype=np.float32)
    y = np.array(labels, dtype=np.int64)
    return X, y


# --------------------------------------------------------------------------- #
# ONNX export — LGBMRegressor produces single [batch, 1] output simplifying MQL5
# --------------------------------------------------------------------------- #
def export_onnx(model: lgb.LGBMRegressor, out_path: str) -> None:
    update_registered_converter(
        lgb.LGBMRegressor,
        "LightGbmLGBMRegressor",
        calculate_linear_regressor_output_shapes,
        convert_lightgbm,
    )
    initial = [("features", FloatTensorType([None, FEATURE_DIM]))]
    onx = convert_sklearn(
        model,
        initial_types=initial,
        target_opset=15,
    )
    with open(out_path, "wb") as f:
        f.write(onx.SerializeToString())
    print(f"[ok] ONNX written: {out_path}")


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def load_csv(path: str) -> pd.DataFrame:
    """
    Expects CSV with header: time, open, high, low, close, volume
    time can be ISO-8601 or MT5 export format 'YYYY.MM.DD HH:MM:SS'.
    """
    df = pd.read_csv(path)
    if "time" not in df.columns:
        # Try MT5 default export with <DATE> <TIME>
        if "<DATE>" in df.columns and "<TIME>" in df.columns:
            df["time"] = pd.to_datetime(df["<DATE>"] + " " + df["<TIME>"],
                                        format="%Y.%m.%d %H:%M:%S")
            df = df.rename(columns={
                "<OPEN>": "open", "<HIGH>": "high",
                "<LOW>": "low", "<CLOSE>": "close",
                "<TICKVOL>": "volume",
            })
        else:
            raise SystemExit(f"Unrecognized CSV format: {path}")
    df["time"] = pd.to_datetime(df["time"])
    df = df.set_index("time").sort_index()
    df = df[["open", "high", "low", "close"]].astype(float)
    return df


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", required=True, help="MT5 historical CSV")
    ap.add_argument("--pip", type=float, default=0.01,
                    help="Pip size (0.01 for JPY, 0.0001 for others)")
    ap.add_argument("--out", default="FadApex_AI.onnx", help="Output ONNX path")
    ap.add_argument("--symbol", default="", help="Symbol label (logged only)")
    args = ap.parse_args()

    print(f"[load] {args.csv} (pip={args.pip})")
    df = load_csv(args.csv)
    print(f"[load] {len(df)} bars from {df.index[0]} to {df.index[-1]}")

    print("[build] extracting signals + labeling...")
    X, y = build_dataset(df, args.pip)
    if len(X) < 100:
        raise SystemExit(f"Too few training samples ({len(X)}). Use more historical data.")
    print(f"[build] {len(X)} samples; win-rate in data = {y.mean():.3f}")

    print("[split] train/test split 80/20")
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2,
                                                         random_state=42, stratify=y)

    print("[train] LightGBM regressor (target: WIN prob 0..1)...")
    model = lgb.LGBMRegressor(
        n_estimators=200,
        max_depth=6,
        learning_rate=0.05,
        min_child_samples=20,
        subsample=0.8,
        colsample_bytree=0.8,
        random_state=42,
        objective="regression",
        verbose=-1,
    )
    model.fit(X_train, y_train.astype(np.float32))

    p_test = np.clip(model.predict(X_test), 0.0, 1.0)
    print(f"[eval] test AUC     = {roc_auc_score(y_test, p_test):.4f}")
    print(f"[eval] test RMSE    = {mean_squared_error(y_test, p_test, squared=False):.4f}")

    print(f"[export] writing {args.out}")
    export_onnx(model, args.out)
    size_kb = os.path.getsize(args.out) / 1024
    print(f"[done] model size = {size_kb:.1f} KB")
    print(f"[done] place '{args.out}' into MetaTrader5 -> Files -> MQL5/Files/")


if __name__ == "__main__":
    main()
