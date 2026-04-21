//+------------------------------------------------------------------+
//| FAD APEX ULTIMATE EDITION                                        |
//| Multi-Timeframe + Smart Money Concepts + AI Fusion               |
//| Components: EMA Ribbon, MTF Structure, BULL/BEAR Signals,        |
//|   Key Levels, EXIT TP, Range Filter, Self-Learning,              |
//|   Liquidity Sweep, Order Block, FVG, ChoCh, Pre-Signal,          |
//|   Dynamic SL/TP Lines, Multi-Stage Exit, ONNX AI Scorer          |
//+------------------------------------------------------------------+
#property copyright "FAD APEX ULTIMATE"
#property link      ""
#property version   "4.60"
#property indicator_chart_window

#property indicator_buffers 21
#property indicator_plots   10

#property indicator_label1  "Ribbon1_2"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  C'70,180,160',C'200,110,110'
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "Ribbon2_3"
#property indicator_type2   DRAW_FILLING
#property indicator_color2  C'60,165,148',C'190,100,100'
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_label3  "Ribbon3_4"
#property indicator_type3   DRAW_FILLING
#property indicator_color3  C'52,150,136',C'178,90,90'
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#property indicator_label4  "Ribbon4_5"
#property indicator_type4   DRAW_FILLING
#property indicator_color4  C'44,135,124',C'166,80,80'
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

#property indicator_label5  "Ribbon5_6"
#property indicator_type5   DRAW_FILLING
#property indicator_color5  C'38,120,112',C'154,72,72'
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

#property indicator_label6  "Ribbon6_7"
#property indicator_type6   DRAW_FILLING
#property indicator_color6  C'32,105,100',C'142,64,64'
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

#property indicator_label7  "Ribbon7_8"
#property indicator_type7   DRAW_FILLING
#property indicator_color7  C'26,90,88',C'130,56,56'
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

#property indicator_label8  "BULL"
#property indicator_type8   DRAW_NONE

#property indicator_label9  "BEAR"
#property indicator_type9   DRAW_NONE

#property indicator_label10 "ColorCandle"
#property indicator_type10  DRAW_COLOR_CANDLES
#property indicator_color10 C'50,205,130',C'230,85,85',C'110,110,125'
#property indicator_style10 STYLE_SOLID
#property indicator_width10 1
//--- Inputs
input int    InpEMA1  = 5;
input int    InpEMA2  = 8;
input int    InpEMA3  = 13;
input int    InpEMA4  = 21;
input int    InpEMA5  = 34;
input int    InpEMA6  = 55;
input int    InpEMA7  = 89;
input int    InpEMA8  = 144;
input int    InpSwingLookback = 10;
input bool   InpShow5min  = true;
input bool   InpShow15min = true;
input bool   InpShow1H    = true;
input int    InpTrendConfirm = 1;
input bool   InpShowLevels   = true;
input int    InpMaxLevels    = 3;
input int    InpLevelExtend  = 50;
input bool   InpPushNotify   = true;
input bool   InpAlertSound   = true;
input int    InpADXPeriod    = 14;       // ADX period for range filter
input int    InpADXThreshold = 18;       // ADX below this = range (suppress signal)
input double InpRibbonATR    = 0.8;      // Ribbon width must be > ATR * this ratio
input int    InpCooldownBars = 8;        // Minimum bars between opposing signals
input bool   InpShowExits    = true;     // Show EXIT take-profit signals
input int    InpExitThreshold = 45;      // EXIT score threshold (0-100)
input color  InpBullColor     = C'0,255,140';   // Bull signal color
input color  InpBearColor     = C'255,50,50';    // Bear signal color

//--- Self-Learning AI (Layer 2)
input bool   InpSelfLearn        = true;    // Enable self-learning parameter tuning
input int    InpLearnLookback    = 20;      // Bars to wait for outcome evaluation
input int    InpLearnWinPips     = 30;      // Pips threshold for WIN
input int    InpLearnLossPips    = 20;      // Pips threshold for LOSS
input bool   InpShowAIPanel      = true;    // Show AI Stats panel (default)
input int    InpAutoTuneMinN     = 20;      // Min evaluated signals before auto-tune activates
input int    InpAutoTuneMaxDelta = 5;       // Max threshold adjustment (clamp ±N)

//--- ONNX AI Scorer (Layer 1)
input bool   InpUseAI            = true;    // Enable ONNX AI win-rate scoring
input string InpAIModelFile      = "FadApex_AI.onnx"; // ONNX model file (MQL5/Files/)
input int    InpAIMinWinRate     = 0;       // Hide signals with AI win% below this (0=off)
input bool   InpAIShowScore      = true;    // Show AI % next to S/A/B rank

//--- Smart Money Concepts (ULTIMATE)
input bool   InpSMC_Sweep        = true;    // Liquidity Sweep detection
input bool   InpSMC_OB           = true;    // Order Block auto-mapping
input bool   InpSMC_FVG          = true;    // Fair Value Gap tracker
input bool   InpSMC_ChoCh        = true;    // Change of Character detection
input bool   InpSMC_PreSig       = true;    // Pre-Signal warning markers
input int    InpSMC_SwingLB      = 10;      // Swing lookback for sweep detection
input int    InpSMC_MaxLiq       = 30;      // Max tracked liquidity levels
input int    InpSMC_MaxOB        = 15;      // Max tracked order blocks
input int    InpSMC_MaxFVG       = 15;      // Max tracked fair value gaps
input double InpSMC_OBStrength   = 3.0;     // OB validation: move > ATR * N
input bool   InpSMC_ShowZones    = true;    // Draw OB/FVG rectangles

//--- Dynamic SL/TP Lines + Multi-Stage Exit (ULTIMATE)
input bool   InpTPLines_Enable   = true;    // Draw SL/TP lines at signals
input double InpTP_SL_ATR        = 1.5;     // SL distance in ATR multiples
input double InpTP_TP1_ATR       = 1.0;     // TP1 distance in ATR multiples
input double InpTP_TP2_ATR       = 2.0;     // TP2 distance in ATR multiples
input double InpTP_TP3_ATR       = 4.0;     // TP3 distance in ATR multiples
input int    InpTPLines_Extend   = 80;      // Bars to extend TP lines forward
input bool   InpTP_ShowBE        = true;    // Show break-even marker on TP1 hit
input int    InpTP_MaxActive     = 10;      // Max concurrent active TP sets

//--- Ribbon buffers (7 fills x 2 = 14)
double g_ema1[];
double g_ema2a[];
double g_ema2b[];
double g_ema3a[];
double g_ema3b[];
double g_ema4a[];
double g_ema4b[];
double g_ema5a[];
double g_ema5b[];
double g_ema6a[];
double g_ema6b[];
double g_ema7a[];
double g_ema7b[];
double g_ema8[];

//--- Signal buffers
double g_bullSignal[];
double g_bearSignal[];

//--- Candle color buffers
double g_candleO[];
double g_candleH[];
double g_candleL[];
double g_candleC[];
double g_candleClr[];

//--- EMA work arrays
double g_ed0[], g_ed1[], g_ed2[], g_ed3[];
double g_ed4[], g_ed5[], g_ed6[], g_ed7[];

//--- EMA handles
int g_hEMA[8];

//--- MTF config
ENUM_TIMEFRAMES g_mtfTF[3];
string g_mtfName[3];

//--- Per-chart-bar trend for each HTF (for BULL/BEAR)
double g_barTrend0[];
double g_barTrend1[];
double g_barTrend2[];

//--- Master trend
int g_masterTrend;

//--- Key levels
string g_prefix;
int    g_hiLvlCnt;
int    g_loLvlCnt;
string g_hiNames[];
string g_loNames[];

//--- Push notification duplicate prevention
datetime g_lastNotifyTime    = 0;
datetime g_lastExitNotify    = 0;
datetime g_lastMSSNotify0    = 0;   // BOS/MSS duplicate prevention per TF
datetime g_lastMSSNotify1    = 0;
datetime g_lastMSSNotify2    = 0;

//--- Trend Status Panel handles (M5/M15/H1/H4)
ENUM_TIMEFRAMES g_trendTF[4];
string g_trendTFName[4];
int g_hTrendEMA20[4];
int g_hTrendEMA50[4];
int g_hTrendATR[4];

//--- Chart ATR handle for adaptive scoring
int g_hChartATR;

//--- ADX handle for range filter
int g_hADX;

//--- Panel visibility toggle
bool g_showMSS    = true;
bool g_showTrend  = true;
bool g_showRibbon = true;
bool g_showAI     = true;      // AI Stats panel visibility

//--- Self-learning data structures (Layer 2)
struct SSignalRec
{
   datetime  logTime;     // bar time at signal
   int       direction;   // +1=BULL, -1=BEAR
   int       rank;        // 3=S, 2=A, 1=B
   int       score;       // raw score 0-100 (entry strength indicator)
   int       regime;      // 0=Trend, 1=Range, 2=Breakout
   int       session;     // 0=Asia, 1=London, 2=NY
   int       dow;         // 0-6 (Sun-Sat, MT5 convention)
   double    entryPrice;  // close at signal
   int       evalStatus;  // 0=PENDING, 1=WIN, 2=LOSS, 3=DRAW
};

SSignalRec g_signalLog[];         // dynamic array of records
int        g_signalLogSize = 0;   // logical size (<= ArraySize)
bool       g_signalLogDirty = false;  // needs save flag
string     g_signalLogFile;       // filename (per symbol+period)

//--- Effective (auto-tuned) thresholds
int    g_effAdxThreshold  = 0;    // initialized from InpADXThreshold in OnInit
int    g_effExitThreshold = 0;    // initialized from InpExitThreshold in OnInit

//--- Last logged bar time per direction (duplicate prevention)
datetime g_lastBullLogTime = 0;
datetime g_lastBearLogTime = 0;

//--- ONNX AI handle + state (Layer 1)
long     g_aiHandle = INVALID_HANDLE;  // OnnxCreate returns long
bool     g_aiEnabled = false;          // true if model loaded OK
datetime g_aiLastTime = 0;             // for cooldown feature
int      g_aiInputDim  = 23;           // expanded feature count (v4.60 SMC)

//+==================================================================+
//|  Smart Money Concepts (ULTIMATE) — storage                       |
//+==================================================================+

//--- Liquidity level: swing high/low that can be swept
struct SLiqLevel
{
   datetime t;        // swing bar time
   int      barIdx;   // bar index (last snapshot)
   double   price;    // swing price
   int      type;     // +1=High, -1=Low
   bool     swept;    // has been taken out
   datetime sweepT;   // time of sweep
};
SLiqLevel g_liq[];
int       g_liqCnt = 0;

//--- Order Block zone
struct SOrderBlock
{
   datetime startT;       // origin candle time
   datetime endT;         // validity end (extended forward)
   int      startBar;     // origin bar index
   double   priceHigh;    // zone upper bound
   double   priceLow;     // zone lower bound
   int      type;         // +1=Bullish, -1=Bearish
   int      strength;     // 1-3 based on subsequent move size
   bool     mitigated;    // price returned into zone
   string   objName;      // rectangle object name
};
SOrderBlock g_ob[];
int         g_obCnt = 0;

//--- Fair Value Gap
struct SFairValueGap
{
   datetime t;            // middle candle time
   int      barIdx;       // middle bar index
   double   gapHigh;      // upper gap bound
   double   gapLow;       // lower gap bound
   int      type;         // +1=Bull FVG, -1=Bear FVG
   bool     filled;       // price has returned to fill
   string   objName;      // rectangle object name
};
SFairValueGap g_fvg[];
int           g_fvgCnt = 0;

//--- Change of Character events (lightweight, not persisted as objects)
datetime g_lastChoChBull = 0;
datetime g_lastChoChBear = 0;

//--- Pre-signal tracking
datetime g_lastPreSigTime = 0;
int      g_lastPreSigDir  = 0;   // +1/-1

//--- Per-bar SMC flags cache (populated during OnCalculate, read at signal firing)
//    Indexed by bar index, booleans packed into int arrays for efficiency
int g_smcFlags[];      // bit0=sweep, bit1=ob, bit2=fvg, bit3=choch, bit4=presig
int g_smcFlagsSize = 0;

//+==================================================================+
//|  Multi-Stage Exit + Dynamic SL/TP Lines (ULTIMATE) — storage     |
//+==================================================================+
struct STPSet
{
   datetime  entryT;       // entry bar time
   int       entryBar;     // entry bar index
   int       direction;    // +1=BULL / -1=BEAR
   double    entryPrice;
   double    slPrice;
   double    tp1Price;
   double    tp2Price;
   double    tp3Price;
   bool      tp1Hit;
   bool      tp2Hit;
   bool      tp3Hit;
   bool      slHit;
   bool      beMoved;      // break-even marker drawn
   string    prefix;       // unique prefix for line objects
};
STPSet g_tpset[];
int    g_tpsetCnt = 0;

//--- Rolling win-rate cache (computed in UpdateAIPanel)
int    g_statTotalEval  = 0;      // total evaluated signals
int    g_statWinS = 0, g_statLossS = 0;
int    g_statWinA = 0, g_statLossA = 0;
int    g_statWinB = 0, g_statLossB = 0;
int    g_statWinTrend = 0, g_statLossTrend = 0;
int    g_statWinRange = 0, g_statLossRange = 0;
int    g_statWinBrk   = 0, g_statLossBrk   = 0;

//+------------------------------------------------------------------+
color DeriveRankColor(color base, int score)
{
   if(score >= 3) return base;
   double f = (score == 2) ? 0.85 : 0.70;
   int r = (int)(((base)       & 0xFF) * f + 128 * (1.0 - f));
   int g = (int)(((base >> 8)  & 0xFF) * f + 128 * (1.0 - f));
   int b = (int)(((base >> 16) & 0xFF) * f + 128 * (1.0 - f));
   if(r > 255) r = 255; if(g > 255) g = 255; if(b > 255) b = 255;
   return (color)(r | (g << 8) | (b << 16));
}

//+==================================================================+
//|  Self-Learning AI (Layer 2) — helpers                            |
//+==================================================================+

//--- Session: 0=Asia(00-08 UTC), 1=London(08-16 UTC), 2=NY(13-21 UTC overlaps)
int DetectSession(datetime t)
{
   MqlDateTime mt;
   TimeToStruct(t, mt);
   int h = mt.hour;
   if(h >= 13 && h < 21) return 2;  // NY (overlap with London 13-16)
   if(h >= 7  && h < 13) return 1;  // London
   return 0;                         // Asia
}

//--- Regime detection (lightweight, runs at signal point)
//    0=Trending, 1=Ranging, 2=Breakout
//    atrArr is non-series (oldest first). atIdx is the signal bar index.
int DetectRegime(double atrCur, const double &atrArr[], int atrCount, int atIdx)
{
   if(atrCount < 30 || atrCur <= 0) return 1;
   int window = 30;
   int lo = atIdx - window + 1;
   int hi = atIdx;
   if(lo < 0) lo = 0;
   if(hi >= atrCount) hi = atrCount - 1;
   int n = hi - lo + 1;
   if(n < 10) return 1;
   double sum = 0.0;
   for(int i = lo; i <= hi; i++) sum += atrArr[i];
   double atrMean = sum / n;
   if(atrMean <= 0) return 1;
   double sq = 0.0;
   for(int i = lo; i <= hi; i++)
   {
      double d = atrArr[i] - atrMean;
      sq += d * d;
   }
   double atrStd = MathSqrt(sq / n);
   double cv = atrStd / atrMean;
   if(atrCur > atrMean * 1.5) return 2;   // Breakout
   if(cv < 0.25)              return 0;   // Trending
   return 1;                               // Ranging
}

//--- Convert price-diff to pips (handles JPY pairs and 3/5-digit brokers)
double PriceToPips(double diff)
{
   double pip = _Point;
   if(_Digits == 3 || _Digits == 5) pip = _Point * 10.0;
   if(pip <= 0) return 0;
   return diff / pip;
}

//--- Per-symbol+period filename (keeps Strategy Tester and live separate)
string SignalLogFilename()
{
   return StringFormat("FAPX_SignalLog_%s_%d.csv", _Symbol, (int)_Period);
}

//--- Parse one CSV line → record. Returns true on success.
bool ParseSignalLine(const string &line, SSignalRec &rec)
{
   string parts[];
   int n = StringSplit(line, ',', parts);
   if(n < 9) return false;
   rec.logTime    = (datetime)StringToInteger(parts[0]);
   rec.direction  = (int)StringToInteger(parts[1]);
   rec.rank       = (int)StringToInteger(parts[2]);
   rec.score      = (int)StringToInteger(parts[3]);
   rec.regime     = (int)StringToInteger(parts[4]);
   rec.session    = (int)StringToInteger(parts[5]);
   rec.dow        = (int)StringToInteger(parts[6]);
   rec.entryPrice = StringToDouble(parts[7]);
   rec.evalStatus = (int)StringToInteger(parts[8]);
   return true;
}

//--- Serialize record to CSV line
string FormatSignalLine(const SSignalRec &rec)
{
   return StringFormat("%I64d,%d,%d,%d,%d,%d,%d,%.8f,%d",
      (long)rec.logTime, rec.direction, rec.rank, rec.score,
      rec.regime, rec.session, rec.dow, rec.entryPrice, rec.evalStatus);
}

//--- Load signal log from file into g_signalLog[]
void LoadSignalLog()
{
   g_signalLogFile = SignalLogFilename();
   g_signalLogSize = 0;
   ArrayResize(g_signalLog, 0);
   int fh = FileOpen(g_signalLogFile, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(fh == INVALID_HANDLE) return;  // No existing log (first run)
   while(!FileIsEnding(fh))
   {
      string line = FileReadString(fh);
      if(StringLen(line) == 0) continue;
      SSignalRec rec;
      if(!ParseSignalLine(line, rec)) continue;
      int k = g_signalLogSize;
      ArrayResize(g_signalLog, k + 1);
      g_signalLog[k] = rec;
      g_signalLogSize = k + 1;
   }
   FileClose(fh);
   // Track duplicate prevention cursors
   for(int i = 0; i < g_signalLogSize; i++)
   {
      if(g_signalLog[i].direction == 1 && g_signalLog[i].logTime > g_lastBullLogTime)
         g_lastBullLogTime = g_signalLog[i].logTime;
      if(g_signalLog[i].direction == -1 && g_signalLog[i].logTime > g_lastBearLogTime)
         g_lastBearLogTime = g_signalLog[i].logTime;
   }
}

//--- Save entire signal log back to file (rewrite)
void SaveSignalLog()
{
   if(!g_signalLogDirty) return;
   int fh = FileOpen(g_signalLogFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(fh == INVALID_HANDLE) return;
   // Keep last 10000 to prevent unbounded growth
   int startIdx = (g_signalLogSize > 10000) ? g_signalLogSize - 10000 : 0;
   for(int i = startIdx; i < g_signalLogSize; i++)
      FileWriteString(fh, FormatSignalLine(g_signalLog[i]) + "\r\n");
   FileClose(fh);
   g_signalLogDirty = false;
}

//--- Append one new signal (in-memory + mark dirty)
//    Trims oldest entries if log exceeds 5000 to prevent unbounded memory growth.
void AppendSignal(datetime t, int direction, int rank, int score,
                  int regime, int session, int dow, double entryPrice)
{
   if(g_signalLogSize >= 5000)
   {
      int dropN = 1000;
      for(int i = 0; i < g_signalLogSize - dropN; i++)
         g_signalLog[i] = g_signalLog[i + dropN];
      g_signalLogSize -= dropN;
      ArrayResize(g_signalLog, g_signalLogSize);
   }
   int k = g_signalLogSize;
   ArrayResize(g_signalLog, k + 1);
   g_signalLog[k].logTime    = t;
   g_signalLog[k].direction  = direction;
   g_signalLog[k].rank       = rank;
   g_signalLog[k].score      = score;
   g_signalLog[k].regime     = regime;
   g_signalLog[k].session    = session;
   g_signalLog[k].dow        = dow;
   g_signalLog[k].entryPrice = entryPrice;
   g_signalLog[k].evalStatus = 0;  // PENDING
   g_signalLogSize = k + 1;
   g_signalLogDirty = true;
}

//--- Log a signal if not already logged for that bar
void LogSignal(datetime t, bool isBull, int score,
               int regime, double entryPrice)
{
   if(!InpSelfLearn) return;
   if(t == 0 || entryPrice <= 0) return;
   if(isBull && t <= g_lastBullLogTime) return;
   if(!isBull && t <= g_lastBearLogTime) return;

   int rank = (score >= 3) ? 3 : (score == 2) ? 2 : 1;
   MqlDateTime mt;
   TimeToStruct(t, mt);
   int session = DetectSession(t);
   int dow = mt.day_of_week;

   AppendSignal(t, isBull ? 1 : -1, rank, score, regime, session, dow, entryPrice);

   if(isBull) g_lastBullLogTime = t;
   else       g_lastBearLogTime = t;
}

//--- Evaluate PENDING signals that have aged InpLearnLookback bars.
//    Uses chart bar arrays (high/low/close) at rates_total-1 anchor.
void EvaluatePendingSignals(const double &high[], const double &low[],
                            const datetime &time[], int rates_total)
{
   if(!InpSelfLearn) return;
   if(rates_total < InpLearnLookback + 2) return;
   if(g_signalLogSize == 0) return;
   double pip = _Point;
   if(_Digits == 3 || _Digits == 5) pip = _Point * 10.0;
   if(pip <= 0) return;
   double winDelta  = InpLearnWinPips  * pip;
   double lossDelta = InpLearnLossPips * pip;

   for(int r = 0; r < g_signalLogSize; r++)
   {
      if(g_signalLog[r].evalStatus != 0) continue;  // only PENDING
      datetime sigT = g_signalLog[r].logTime;

      // Locate bar index for sigT in current time[] (binary search, time is ascending)
      int sigIdx = -1;
      int lo2 = 0, hi2 = rates_total - 1;
      while(lo2 <= hi2)
      {
         int mid = (lo2 + hi2) / 2;
         if(time[mid] == sigT) { sigIdx = mid; break; }
         if(time[mid] < sigT) lo2 = mid + 1;
         else                 hi2 = mid - 1;
      }
      if(sigIdx < 0) continue;            // signal bar not in loaded history (gap/truncation)
      int endIdx = sigIdx + InpLearnLookback;
      if(endIdx > rates_total - 1) continue;  // not aged enough yet

      double entry = g_signalLog[r].entryPrice;
      int dir = g_signalLog[r].direction;
      int result = 3;   // DRAW default
      for(int i = sigIdx + 1; i <= endIdx; i++)
      {
         if(dir > 0)  // BULL
         {
            if(high[i] >= entry + winDelta)  { result = 1; break; }  // WIN
            if(low[i]  <= entry - lossDelta) { result = 2; break; }  // LOSS
         }
         else         // BEAR
         {
            if(low[i]  <= entry - winDelta)  { result = 1; break; }
            if(high[i] >= entry + lossDelta) { result = 2; break; }
         }
      }
      g_signalLog[r].evalStatus = result;
      g_signalLogDirty = true;
   }
}

//--- Recompute stats cache (call after evaluation)
void RecomputeStats()
{
   g_statTotalEval = 0;
   g_statWinS = g_statLossS = 0;
   g_statWinA = g_statLossA = 0;
   g_statWinB = g_statLossB = 0;
   g_statWinTrend = g_statLossTrend = 0;
   g_statWinRange = g_statLossRange = 0;
   g_statWinBrk = g_statLossBrk = 0;
   // Use last 100 evaluated records
   int kept = 0;
   for(int i = g_signalLogSize - 1; i >= 0 && kept < 100; i--)
   {
      int st = g_signalLog[i].evalStatus;
      if(st != 1 && st != 2) continue;  // WIN or LOSS only (skip PENDING/DRAW)
      kept++;
      g_statTotalEval++;
      bool win = (st == 1);
      int rk = g_signalLog[i].rank;
      int rg = g_signalLog[i].regime;
      if(rk == 3)      { if(win) g_statWinS++; else g_statLossS++; }
      else if(rk == 2) { if(win) g_statWinA++; else g_statLossA++; }
      else             { if(win) g_statWinB++; else g_statLossB++; }
      if(rg == 0)      { if(win) g_statWinTrend++; else g_statLossTrend++; }
      else if(rg == 1) { if(win) g_statWinRange++; else g_statLossRange++; }
      else             { if(win) g_statWinBrk++;   else g_statLossBrk++;   }
   }
}

int SafePct(int wins, int losses)
{
   int total = wins + losses;
   if(total == 0) return -1;
   return (int)MathRound(100.0 * wins / total);
}

//--- Auto-tune effective thresholds based on regime-specific win rates
void UpdateEffectiveThresholds()
{
   g_effAdxThreshold  = InpADXThreshold;
   g_effExitThreshold = InpExitThreshold;
   if(!InpSelfLearn) return;
   if(g_statTotalEval < InpAutoTuneMinN) return;

   // ADX threshold: based on Range-regime win rate
   int rangeWR = SafePct(g_statWinRange, g_statLossRange);
   if(rangeWR >= 0)
   {
      int adxDelta = 0;
      if(rangeWR < 40) adxDelta = 3;      // tighten (fewer signals)
      else if(rangeWR > 65) adxDelta = -2; // loosen
      adxDelta = MathMax(-InpAutoTuneMaxDelta, MathMin(InpAutoTuneMaxDelta, adxDelta));
      g_effAdxThreshold = InpADXThreshold + adxDelta;
   }

   // EXIT threshold: based on overall win rate
   int totalWins = g_statWinS + g_statWinA + g_statWinB;
   int totalLoss = g_statLossS + g_statLossA + g_statLossB;
   int overallWR = SafePct(totalWins, totalLoss);
   if(overallWR >= 0)
   {
      int exitDelta = 0;
      if(overallWR < 40) exitDelta = -2;   // lower EXIT threshold (exit earlier)
      else if(overallWR > 60) exitDelta = 2;
      exitDelta = MathMax(-InpAutoTuneMaxDelta, MathMin(InpAutoTuneMaxDelta, exitDelta));
      g_effExitThreshold = InpExitThreshold + exitDelta;
   }

   // Safety clamps
   if(g_effAdxThreshold  < 5)  g_effAdxThreshold  = 5;
   if(g_effAdxThreshold  > 50) g_effAdxThreshold  = 50;
   if(g_effExitThreshold < 20) g_effExitThreshold = 20;
   if(g_effExitThreshold > 80) g_effExitThreshold = 80;
}

//+==================================================================+
//|  AI Stats panel UI                                               |
//+==================================================================+
void DeleteAIPanelObjects()
{
   string names[] = {"AIBg","AITitle","AITotal",
                     "AIRankHdr","AIRankS","AIRankA","AIRankB",
                     "AIRgHdr","AIRgTrend","AIRgRange","AIRgBrk",
                     "AIThreshHdr","AIThrAdx","AIThrExit"};
   for(int i = 0; i < ArraySize(names); i++)
      ObjectDelete(0, g_prefix + names[i]);
}

void MakeAILabel(string key, int xOff, int yOff, string text,
                 color clr, int fsz)
{
   string n = g_prefix + key;
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, xOff);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, yOff);
   ObjectSetString (0, n, OBJPROP_TEXT,      text);
   ObjectSetString (0, n, OBJPROP_FONT,      "Consolas");
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE,  fsz);
   ObjectSetInteger(0, n, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, n, OBJPROP_BACK,      false);
}

void MakeAIBg()
{
   string n = g_prefix + "AIBg";
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, 8);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, 260);
   ObjectSetInteger(0, n, OBJPROP_XSIZE,     250);
   ObjectSetInteger(0, n, OBJPROP_YSIZE,     190);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR,   C'18,22,34');
   ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0, n, OBJPROP_COLOR,     C'60,80,130');
   ObjectSetInteger(0, n, OBJPROP_BACK,      false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE,false);
}

void CreateAIPanel()
{
   if(!g_showAI || !InpShowAIPanel) { DeleteAIPanelObjects(); return; }
   MakeAIBg();
   MakeAILabel("AITitle",    15, 268, "── AI 学習 ───────────", C'140,200,255', 9);
   MakeAILabel("AITotal",    15, 286, "シグナル: 0",             C'200,210,225', 9);
   MakeAILabel("AIRankHdr",  15, 304, "勝率 (直近100件):",       C'150,160,180', 8);
   MakeAILabel("AIRankS",    15, 320, "S=--  A=--  B=--",       C'200,210,225', 9);
   MakeAILabel("AIRgHdr",    15, 340, "相場環境別:",             C'150,160,180', 8);
   MakeAILabel("AIRgTrend",  15, 356, "トレンド=-- レンジ=-- ブレイク=--",C'200,210,225', 9);
   MakeAILabel("AIThreshHdr",15, 378, "自動調整:",              C'150,160,180', 8);
   MakeAILabel("AIThrAdx",   15, 394, "ADX:  --",               C'200,210,225', 9);
   MakeAILabel("AIThrExit",  15, 410, "EXIT: --",               C'200,210,225', 9);
}

string FmtPct(int wins, int losses)
{
   int p = SafePct(wins, losses);
   if(p < 0) return "--";
   return IntegerToString(p) + "%";
}

void UpdateAIPanel()
{
   if(!g_showAI || !InpShowAIPanel) return;
   ObjectSetString(0, g_prefix + "AITotal", OBJPROP_TEXT,
      StringFormat("シグナル: %d (評価済: %d)", g_signalLogSize, g_statTotalEval));

   ObjectSetString(0, g_prefix + "AIRankS", OBJPROP_TEXT,
      StringFormat("S=%s  A=%s  B=%s",
         FmtPct(g_statWinS, g_statLossS),
         FmtPct(g_statWinA, g_statLossA),
         FmtPct(g_statWinB, g_statLossB)));

   ObjectSetString(0, g_prefix + "AIRgTrend", OBJPROP_TEXT,
      StringFormat("トレンド=%s レンジ=%s ブレイク=%s",
         FmtPct(g_statWinTrend, g_statLossTrend),
         FmtPct(g_statWinRange, g_statLossRange),
         FmtPct(g_statWinBrk,   g_statLossBrk)));

   string adxTxt, exitTxt;
   if(g_effAdxThreshold == InpADXThreshold)
      adxTxt = StringFormat("ADX:  %d", g_effAdxThreshold);
   else
      adxTxt = StringFormat("ADX:  %d -> %d", InpADXThreshold, g_effAdxThreshold);
   if(g_effExitThreshold == InpExitThreshold)
      exitTxt = StringFormat("EXIT: %d", g_effExitThreshold);
   else
      exitTxt = StringFormat("EXIT: %d -> %d", InpExitThreshold, g_effExitThreshold);
   ObjectSetString(0, g_prefix + "AIThrAdx",  OBJPROP_TEXT, adxTxt);
   ObjectSetString(0, g_prefix + "AIThrExit", OBJPROP_TEXT, exitTxt);
}

//--- Reset all learning data
void ResetAILearning()
{
   ArrayResize(g_signalLog, 0);
   g_signalLogSize = 0;
   g_signalLogDirty = false;
   g_lastBullLogTime = 0;
   g_lastBearLogTime = 0;
   g_statTotalEval = 0;
   g_statWinS = g_statLossS = 0;
   g_statWinA = g_statLossA = 0;
   g_statWinB = g_statLossB = 0;
   g_statWinTrend = g_statLossTrend = 0;
   g_statWinRange = g_statLossRange = 0;
   g_statWinBrk = g_statLossBrk = 0;
   g_effAdxThreshold  = InpADXThreshold;
   g_effExitThreshold = InpExitThreshold;
   // Delete file
   if(FileIsExist(g_signalLogFile))
      FileDelete(g_signalLogFile);
   UpdateAIPanel();
}

//+==================================================================+
//|  ONNX AI Scorer (Layer 1) — helpers                              |
//+==================================================================+

//--- Build a one-hot float at position p (0..n-1)
void OneHot(float &feat[], int &idx, int p, int n)
{
   for(int k = 0; k < n; k++)
   {
      feat[idx++] = (k == p) ? 1.0f : 0.0f;
   }
}

//--- HTF trend alignment: count of HTFs agreeing with signal direction (0-3)
int HTFAlignCount(int barIdx, bool isBull)
{
   int c = 0;
   int want = isBull ? 1 : -1;
   if((int)g_barTrend0[barIdx] == want) c++;
   if((int)g_barTrend1[barIdx] == want) c++;
   if((int)g_barTrend2[barIdx] == want) c++;
   return c;
}

//--- EMA compression: stdev(8 EMA values) / price (proxy for squeeze)
double EmaCompression(int i, double price)
{
   if(price <= 0) return 0;
   double vals[8];
   vals[0]=g_ed0[i]; vals[1]=g_ed1[i]; vals[2]=g_ed2[i]; vals[3]=g_ed3[i];
   vals[4]=g_ed4[i]; vals[5]=g_ed5[i]; vals[6]=g_ed6[i]; vals[7]=g_ed7[i];
   double mean = 0;
   for(int k = 0; k < 8; k++) mean += vals[k];
   mean /= 8.0;
   double sq = 0;
   for(int k = 0; k < 8; k++) { double d = vals[k] - mean; sq += d*d; }
   double sd = MathSqrt(sq / 8.0);
   return sd / price;
}

//--- Extract 18-dim feature vector at signal firing point
//    Feature layout (must match Python training):
//      [0]  score_mtf     : MTF alignment 0-3 / 3.0
//      [1]  score_emaord  : Perfect EMA order 0/1
//      [2]  score_vol     : body size / avg body
//      [3]  score_mom     : ribbon-width / min-width ratio
//      [4]  score_total   : raw score 0-4 / 4.0
//      [5-7]  regime one-hot (Trend/Range/Brk)
//      [8]  vol_bucket    : atr / atr_mean
//      [9-11] session one-hot (Asia/London/NY)
//      [12] dow_norm      : day_of_week (0-6) / 6.0
//      [13] bars_since    : log1p(bars since last signal)
//      [14] adx_norm      : ADX / 50
//      [15] ema_compress  : stdev8(EMA) / price
//      [16] htf_align     : HTF align count / 3.0
//      [17] direction     : +1 BULL / -1 BEAR
void ExtractAIFeatures(float &feat[], int barIdx, bool isBull, int score,
                       double closePrice, double openPrice,
                       const double &atrBuf[], int atrCnt,
                       const double &adxBuf[], int adxCnt,
                       int regime, datetime barTime,
                       int lastSigBar)
{
   ArrayResize(feat, g_aiInputDim);
   int idx = 0;

   // [0] MTF alignment ratio
   int mtfC = HTFAlignCount(barIdx, isBull);
   feat[idx++] = (float)(mtfC / 3.0);

   // [1] Perfect EMA order (reconstruct)
   bool perfOrder;
   if(isBull)
      perfOrder = g_ed0[barIdx]>g_ed1[barIdx] && g_ed1[barIdx]>g_ed2[barIdx] && g_ed2[barIdx]>g_ed3[barIdx]
               && g_ed3[barIdx]>g_ed4[barIdx] && g_ed4[barIdx]>g_ed5[barIdx] && g_ed5[barIdx]>g_ed6[barIdx]
               && g_ed6[barIdx]>g_ed7[barIdx];
   else
      perfOrder = g_ed0[barIdx]<g_ed1[barIdx] && g_ed1[barIdx]<g_ed2[barIdx] && g_ed2[barIdx]<g_ed3[barIdx]
               && g_ed3[barIdx]<g_ed4[barIdx] && g_ed4[barIdx]<g_ed5[barIdx] && g_ed5[barIdx]<g_ed6[barIdx]
               && g_ed6[barIdx]<g_ed7[barIdx];
   feat[idx++] = perfOrder ? 1.0f : 0.0f;

   // [2] Candle momentum proxy (body size vs ATR)
   double body = MathAbs(closePrice - openPrice);
   double atrV = (atrCnt > barIdx && atrBuf[barIdx] > 0) ? atrBuf[barIdx] : 0.0;
   feat[idx++] = (atrV > 0) ? (float)(body / atrV) : 0.0f;

   // [3] Ribbon expansion (approx): current width / atr
   double curW = MathAbs(g_ed0[barIdx] - g_ed7[barIdx]);
   feat[idx++] = (atrV > 0) ? (float)(curW / atrV) : 0.0f;

   // [4] Raw score 0-4 normalized
   feat[idx++] = (float)(score / 4.0);

   // [5-7] Regime one-hot
   OneHot(feat, idx, regime, 3);

   // [8] Volatility bucket (atr / mean_atr over last 30)
   double atrMean = 0;
   int lo = MathMax(0, barIdx - 29);
   int n  = barIdx - lo + 1;
   if(atrCnt > barIdx && n > 0)
   {
      for(int k = lo; k <= barIdx; k++) atrMean += atrBuf[k];
      atrMean /= n;
   }
   feat[idx++] = (atrMean > 0) ? (float)(atrV / atrMean) : 1.0f;

   // [9-11] Session one-hot
   int sess = DetectSession(barTime);
   OneHot(feat, idx, sess, 3);

   // [12] Day of week (0-6) / 6.0
   MqlDateTime mt;
   TimeToStruct(barTime, mt);
   feat[idx++] = (float)(mt.day_of_week / 6.0);

   // [13] Bars since last signal (log1p)
   int barsSince = (lastSigBar < 0) ? 100 : (barIdx - lastSigBar);
   if(barsSince < 0) barsSince = 0;
   feat[idx++] = (float)MathLog(1.0 + barsSince);

   // [14] ADX normalized (0-50 typical)
   double adxV = (adxCnt > barIdx) ? adxBuf[barIdx] : 20.0;
   feat[idx++] = (float)(adxV / 50.0);

   // [15] EMA compression
   feat[idx++] = (float)EmaCompression(barIdx, closePrice);

   // [16] HTF align count / 3
   feat[idx++] = (float)(mtfC / 3.0);

   // [17] Direction (+1/-1)
   feat[idx++] = isBull ? 1.0f : -1.0f;

   //--- v4.60 SMC-derived features -------------------------------------
   int dir = isBull ? +1 : -1;

   // [18] Liquidity sweep aligned with direction on this bar (0/1)
   int sw = SweepDirectionAt(barTime);
   feat[idx++] = (sw == dir) ? 1.0f : 0.0f;

   // [19] Inside unmitigated Order Block aligned with direction (0/1)
   feat[idx++] = OBConfluenceAt(closePrice, dir) ? 1.0f : 0.0f;

   // [20] Inside unfilled Fair Value Gap aligned with direction (0/1)
   feat[idx++] = FVGActiveAt(closePrice, dir) ? 1.0f : 0.0f;

   // [21] Recent ChoCh in direction within 5 bars (0/1)
   datetime cutoff = barTime - (datetime)(PeriodSeconds() * 5);
   bool chRecent = (dir > 0) ? (g_lastChoChBull >= cutoff)
                             : (g_lastChoChBear >= cutoff);
   feat[idx++] = chRecent ? 1.0f : 0.0f;

   // [22] SMC confluence score normalized (0-7 -> 0-1)
   int smc = SMCConfluenceBonus(dir, closePrice, barTime);
   feat[idx++] = (float)(smc / 7.0);
}

//--- Run ONNX inference and return win probability 0.0-1.0.
//    Returns -1.0 on any failure or when AI disabled.
//    Expects: input  shape [1, 23] float32 (v4.60: 18 base + 5 SMC)
//             output shape [1, 1]  float32 (LGBMRegressor direct output)
double PredictWinRate(const float &feat[])
{
   if(!g_aiEnabled || g_aiHandle == INVALID_HANDLE) return -1.0;
   if(ArraySize(feat) != g_aiInputDim) return -1.0;

   matrixf input_mf(1, g_aiInputDim);
   for(int j = 0; j < g_aiInputDim; j++)
      input_mf[0][j] = feat[j];

   matrixf output_mf(1, 1);

   if(!OnnxRun(g_aiHandle, ONNX_DEFAULT, input_mf, output_mf))
   {
      PrintFormat("FAPX AI: OnnxRun failed (err=%d).", GetLastError());
      return -1.0;
   }

   double p = (double)output_mf[0][0];
   if(p < 0.0) p = 0.0;
   if(p > 1.0) p = 1.0;
   return p;
}

//--- Initialize ONNX model. Returns true on success.
bool InitONNX()
{
   if(!InpUseAI) return false;
   if(TerminalInfoInteger(TERMINAL_BUILD) < 3440)
   {
      PrintFormat("FAPX AI: MT5 build %d < 3440, ONNX unsupported. Falling back.",
                  (int)TerminalInfoInteger(TERMINAL_BUILD));
      return false;
   }
   g_aiHandle = OnnxCreate(InpAIModelFile, ONNX_DEFAULT);
   if(g_aiHandle == INVALID_HANDLE)
   {
      PrintFormat("FAPX AI: OnnxCreate('%s') failed (err=%d). AI disabled, Phase A continues.",
                  InpAIModelFile, GetLastError());
      return false;
   }
   ulong inShape[]  = {1, 23};  // must match g_aiInputDim (FEATURE_DIM in Python)
   ulong outShape[] = {1, 1};
   if(!OnnxSetInputShape(g_aiHandle, 0, inShape))
   {
      PrintFormat("FAPX AI: OnnxSetInputShape failed (err=%d).", GetLastError());
      OnnxRelease(g_aiHandle);
      g_aiHandle = INVALID_HANDLE;
      return false;
   }
   if(!OnnxSetOutputShape(g_aiHandle, 0, outShape))
   {
      PrintFormat("FAPX AI: OnnxSetOutputShape failed (err=%d).", GetLastError());
      OnnxRelease(g_aiHandle);
      g_aiHandle = INVALID_HANDLE;
      return false;
   }
   Print("FAPX AI: ONNX model loaded, win-rate scoring active.");
   return true;
}

//+==================================================================+
//|  SMC: Pivot swing detection (simple non-recursive)               |
//+==================================================================+
bool IsPivotHigh(const double &high[], int idx, int lb, int total)
{
   if(idx - lb < 0 || idx + lb >= total) return false;
   double v = high[idx];
   for(int k = 1; k <= lb; k++)
   {
      if(high[idx - k] >= v) return false;
      if(high[idx + k] >= v) return false;
   }
   return true;
}

bool IsPivotLow(const double &low[], int idx, int lb, int total)
{
   if(idx - lb < 0 || idx + lb >= total) return false;
   double v = low[idx];
   for(int k = 1; k <= lb; k++)
   {
      if(low[idx - k] <= v) return false;
      if(low[idx + k] <= v) return false;
   }
   return true;
}

//--- Push a liquidity level (ring buffer with max cap)
void PushLiqLevel(datetime t, int barIdx, double price, int type)
{
   // De-dup: skip if same time already stored
   for(int k = 0; k < g_liqCnt; k++)
   {
      if(g_liq[k].t == t && g_liq[k].type == type) return;
   }
   if(g_liqCnt >= InpSMC_MaxLiq)
   {
      // Shift oldest out
      for(int k = 1; k < g_liqCnt; k++) g_liq[k - 1] = g_liq[k];
      g_liqCnt--;
   }
   int idx = g_liqCnt;
   ArrayResize(g_liq, idx + 1);
   g_liq[idx].t       = t;
   g_liq[idx].barIdx  = barIdx;
   g_liq[idx].price   = price;
   g_liq[idx].type    = type;
   g_liq[idx].swept   = false;
   g_liq[idx].sweepT  = 0;
   g_liqCnt++;
}

//--- Detect liquidity sweeps + reversal on most recent closed bar.
//--- Input arrays must be MQL-native (non series) sized `total`, index 0 = oldest.
void DetectLiquiditySweeps(const double &high[], const double &low[],
                           const double &open[],  const double &close[],
                           const datetime &time[], int total)
{
   if(!InpSMC_Sweep) return;
   int lb = InpSMC_SwingLB;
   int i  = total - 2;             // last closed bar
   if(i - lb < 0) return;

   // 1) Register new swing pivots (from a bit behind current)
   int pivotIdx = i - lb;
   if(pivotIdx >= lb)
   {
      if(IsPivotHigh(high, pivotIdx, lb, total))
         PushLiqLevel(time[pivotIdx], pivotIdx, high[pivotIdx], +1);
      if(IsPivotLow(low, pivotIdx, lb, total))
         PushLiqLevel(time[pivotIdx], pivotIdx, low[pivotIdx], -1);
   }

   // 2) Check sweep: current bar wicked beyond a stored level AND closed back
   for(int k = 0; k < g_liqCnt; k++)
   {
      if(g_liq[k].swept) continue;
      if(g_liq[k].type == +1)  // swing high = sell-side liquidity above
      {
         if(high[i] > g_liq[k].price && close[i] < g_liq[k].price)
         {
            g_liq[k].swept  = true;
            g_liq[k].sweepT = time[i];
            if(InpSMC_ShowZones)
            {
               string nm = g_prefix + "SW_H_" + IntegerToString((int)time[i]);
               if(ObjectFind(0, nm) < 0)
                  ObjectCreate(0, nm, OBJ_ARROW_DOWN, 0, time[i], high[i]);
               ObjectSetInteger(0, nm, OBJPROP_COLOR, clrMagenta);
               ObjectSetInteger(0, nm, OBJPROP_WIDTH, 2);
            }
         }
      }
      else if(g_liq[k].type == -1)
      {
         if(low[i] < g_liq[k].price && close[i] > g_liq[k].price)
         {
            g_liq[k].swept  = true;
            g_liq[k].sweepT = time[i];
            if(InpSMC_ShowZones)
            {
               string nm = g_prefix + "SW_L_" + IntegerToString((int)time[i]);
               if(ObjectFind(0, nm) < 0)
                  ObjectCreate(0, nm, OBJ_ARROW_UP, 0, time[i], low[i]);
               ObjectSetInteger(0, nm, OBJPROP_COLOR, clrAqua);
               ObjectSetInteger(0, nm, OBJPROP_WIDTH, 2);
            }
         }
      }
   }
}

//--- Returns +1 if BULL sweep fired on given bar, -1 for BEAR, else 0.
int SweepDirectionAt(datetime barT)
{
   for(int k = g_liqCnt - 1; k >= 0; k--)
   {
      if(g_liq[k].swept && g_liq[k].sweepT == barT)
         return (g_liq[k].type == +1) ? -1 : +1;  // swept high -> bearish flip; swept low -> bullish
   }
   return 0;
}

//--- Push Order Block with ring buffer + object draw.
void PushOrderBlock(datetime stT, datetime enT, int stBar,
                    double ph, double pl, int type, int strength)
{
   if(g_obCnt >= InpSMC_MaxOB)
   {
      string oldNm = g_ob[0].objName;
      if(oldNm != "" && ObjectFind(0, oldNm) >= 0) ObjectDelete(0, oldNm);
      for(int k = 1; k < g_obCnt; k++) g_ob[k - 1] = g_ob[k];
      g_obCnt--;
   }
   int idx = g_obCnt;
   ArrayResize(g_ob, idx + 1);
   g_ob[idx].startT    = stT;
   g_ob[idx].endT      = enT;
   g_ob[idx].startBar  = stBar;
   g_ob[idx].priceHigh = ph;
   g_ob[idx].priceLow  = pl;
   g_ob[idx].type      = type;
   g_ob[idx].strength  = strength;
   g_ob[idx].mitigated = false;
   g_ob[idx].objName   = g_prefix + "OB_" + IntegerToString((int)stT) + "_" + IntegerToString(type);
   g_obCnt++;

   if(InpSMC_ShowZones)
   {
      string nm = g_ob[idx].objName;
      if(ObjectFind(0, nm) < 0)
         ObjectCreate(0, nm, OBJ_RECTANGLE, 0, stT, ph, enT, pl);
      ObjectSetInteger(0, nm, OBJPROP_TIME, 0, stT);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, 0, ph);
      ObjectSetInteger(0, nm, OBJPROP_TIME, 1, enT);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, 1, pl);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, (type > 0) ? clrDodgerBlue : clrOrangeRed);
      ObjectSetInteger(0, nm, OBJPROP_FILL, true);
      ObjectSetInteger(0, nm, OBJPROP_BACK, true);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
   }
}

//--- Detect Order Blocks: last opposite candle before a strong ATR move.
void UpdateOrderBlocks(const double &high[], const double &low[],
                       const double &open[],  const double &close[],
                       const datetime &time[], double atrVal, int total)
{
   if(!InpSMC_OB || atrVal <= 0.0) return;
   int i = total - 2;
   if(i - 2 < 0) return;

   double threshold = atrVal * InpSMC_OBStrength;
   // Bull OB: last bearish candle before strong up move of >=threshold
   double move = close[i] - close[i - 1];
   if(move >= threshold && close[i - 1] < open[i - 1])
   {
      // avoid duplicate
      bool dup = false;
      for(int k = g_obCnt - 1; k >= 0 && !dup; k--)
         if(g_ob[k].startT == time[i - 1] && g_ob[k].type == +1) dup = true;
      if(!dup)
      {
         datetime en = time[i] + (datetime)(PeriodSeconds() * InpTPLines_Extend);
         PushOrderBlock(time[i - 1], en, i - 1,
                        MathMax(open[i - 1], high[i - 1]),
                        MathMin(close[i - 1], low[i - 1]),
                        +1, (int)MathRound(move / atrVal));
      }
   }
   if(-move >= threshold && close[i - 1] > open[i - 1])
   {
      bool dup = false;
      for(int k = g_obCnt - 1; k >= 0 && !dup; k--)
         if(g_ob[k].startT == time[i - 1] && g_ob[k].type == -1) dup = true;
      if(!dup)
      {
         datetime en = time[i] + (datetime)(PeriodSeconds() * InpTPLines_Extend);
         PushOrderBlock(time[i - 1], en, i - 1,
                        MathMax(close[i - 1], high[i - 1]),
                        MathMin(open[i - 1], low[i - 1]),
                        -1, (int)MathRound(-move / atrVal));
      }
   }

   // Mitigation: mark as mitigated when price re-enters the zone
   for(int k = 0; k < g_obCnt; k++)
   {
      if(g_ob[k].mitigated) continue;
      if(g_ob[k].type == +1 && low[i] <= g_ob[k].priceHigh && high[i] >= g_ob[k].priceLow)
         g_ob[k].mitigated = true;
      if(g_ob[k].type == -1 && high[i] >= g_ob[k].priceLow && low[i] <= g_ob[k].priceHigh)
         g_ob[k].mitigated = true;
   }
}

//--- Check if price is currently inside an unmitigated OB aligned with dir (+1/-1).
bool OBConfluenceAt(double price, int dir)
{
   for(int k = g_obCnt - 1; k >= 0; k--)
   {
      if(g_ob[k].mitigated) continue;
      if(g_ob[k].type != dir) continue;
      if(price >= g_ob[k].priceLow && price <= g_ob[k].priceHigh) return true;
   }
   return false;
}

//--- Push FVG + draw rectangle.
void PushFVG(datetime t, int barIdx, double gh, double gl, int type)
{
   if(g_fvgCnt >= InpSMC_MaxFVG)
   {
      string oldNm = g_fvg[0].objName;
      if(oldNm != "" && ObjectFind(0, oldNm) >= 0) ObjectDelete(0, oldNm);
      for(int k = 1; k < g_fvgCnt; k++) g_fvg[k - 1] = g_fvg[k];
      g_fvgCnt--;
   }
   int idx = g_fvgCnt;
   ArrayResize(g_fvg, idx + 1);
   g_fvg[idx].t       = t;
   g_fvg[idx].barIdx  = barIdx;
   g_fvg[idx].gapHigh = gh;
   g_fvg[idx].gapLow  = gl;
   g_fvg[idx].type    = type;
   g_fvg[idx].filled  = false;
   g_fvg[idx].objName = g_prefix + "FVG_" + IntegerToString((int)t) + "_" + IntegerToString(type);
   g_fvgCnt++;

   if(InpSMC_ShowZones)
   {
      string nm = g_fvg[idx].objName;
      datetime en = t + (datetime)(PeriodSeconds() * InpTPLines_Extend);
      if(ObjectFind(0, nm) < 0)
         ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t, gh, en, gl);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, (type > 0) ? clrLightSkyBlue : clrLightPink);
      ObjectSetInteger(0, nm, OBJPROP_FILL, true);
      ObjectSetInteger(0, nm, OBJPROP_BACK, true);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
   }
}

//--- 3-candle FVG detection; call once per closed bar.
void DetectFVG(const double &high[], const double &low[],
               const datetime &time[], int total)
{
   if(!InpSMC_FVG) return;
   int i = total - 2;
   if(i - 2 < 0) return;
   // Bullish FVG: low[i] > high[i-2]
   if(low[i] > high[i - 2])
      PushFVG(time[i - 1], i - 1, low[i], high[i - 2], +1);
   // Bearish FVG: high[i] < low[i-2]
   if(high[i] < low[i - 2])
      PushFVG(time[i - 1], i - 1, low[i - 2], high[i], -1);

   // Fill check
   for(int k = 0; k < g_fvgCnt; k++)
   {
      if(g_fvg[k].filled) continue;
      if(g_fvg[k].type == +1 && low[i] <= g_fvg[k].gapLow) g_fvg[k].filled = true;
      if(g_fvg[k].type == -1 && high[i] >= g_fvg[k].gapHigh) g_fvg[k].filled = true;
   }
}

//--- Is price inside an unfilled FVG of given direction?
bool FVGActiveAt(double price, int dir)
{
   for(int k = g_fvgCnt - 1; k >= 0; k--)
   {
      if(g_fvg[k].filled) continue;
      if(g_fvg[k].type != dir) continue;
      if(price >= g_fvg[k].gapLow && price <= g_fvg[k].gapHigh) return true;
   }
   return false;
}

//--- ChoCh: earliest structure break - recent close violates last opposite pivot.
//--- Returns +1 bullish ChoCh, -1 bearish ChoCh, 0 none (on last closed bar).
int DetectChoCh(const double &high[], const double &low[],
                const double &close[], const datetime &time[], int total)
{
   if(!InpSMC_ChoCh) return 0;
   int i = total - 2;
   if(i - InpSMC_SwingLB < 0) return 0;

   // Find most recent opposite swing before this bar
   double lastHi = 0; datetime lastHiT = 0;
   double lastLo = 0; datetime lastLoT = 0;
   for(int k = g_liqCnt - 1; k >= 0; k--)
   {
      if(g_liq[k].type == +1 && lastHiT == 0 && g_liq[k].t < time[i])
      { lastHi = g_liq[k].price; lastHiT = g_liq[k].t; }
      if(g_liq[k].type == -1 && lastLoT == 0 && g_liq[k].t < time[i])
      { lastLo = g_liq[k].price; lastLoT = g_liq[k].t; }
      if(lastHiT != 0 && lastLoT != 0) break;
   }

   if(lastHiT != 0 && close[i] > lastHi && time[i] != g_lastChoChBull)
   {
      g_lastChoChBull = time[i];
      if(InpSMC_ShowZones)
      {
         string nm = g_prefix + "CH_U_" + IntegerToString((int)time[i]);
         if(ObjectFind(0, nm) < 0)
            ObjectCreate(0, nm, OBJ_TEXT, 0, time[i], lastHi);
         ObjectSetString (0, nm, OBJPROP_TEXT, "ChoCh↑");
         ObjectSetInteger(0, nm, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 8);
      }
      return +1;
   }
   if(lastLoT != 0 && close[i] < lastLo && time[i] != g_lastChoChBear)
   {
      g_lastChoChBear = time[i];
      if(InpSMC_ShowZones)
      {
         string nm = g_prefix + "CH_D_" + IntegerToString((int)time[i]);
         if(ObjectFind(0, nm) < 0)
            ObjectCreate(0, nm, OBJ_TEXT, 0, time[i], lastLo);
         ObjectSetString (0, nm, OBJPROP_TEXT, "ChoCh↓");
         ObjectSetInteger(0, nm, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 8);
      }
      return -1;
   }
   return 0;
}

//--- Pre-Signal: EMA8 slope acceleration vs prior bar (early warning).
//--- Call on last-closed-bar-but-one; marks chart if accelerating toward dir.
int DetectPreSignal(const double &ema8[], const double &close[],
                    const datetime &time[], int total)
{
   if(!InpSMC_PreSig) return 0;
   int i = total - 2;
   if(i - 3 < 0) return 0;

   double s1 = ema8[i]     - ema8[i - 1];
   double s0 = ema8[i - 1] - ema8[i - 2];
   double accel = s1 - s0;
   // Magnitude guard: require accel > fraction of typical range
   double px = close[i];
   double thr = px * 0.00005;  // 0.5bp
   if(MathAbs(accel) < thr) return 0;

   int dir = (accel > 0) ? +1 : -1;
   if(g_lastPreSigTime == time[i] && g_lastPreSigDir == dir) return dir;
   g_lastPreSigTime = time[i];
   g_lastPreSigDir  = dir;

   if(InpSMC_ShowZones)
   {
      string nm = g_prefix + "PRE_" + IntegerToString((int)time[i]);
      if(ObjectFind(0, nm) < 0)
         ObjectCreate(0, nm, OBJ_TEXT, 0, time[i], (dir > 0) ? ema8[i] : ema8[i]);
      ObjectSetString (0, nm, OBJPROP_TEXT, (dir > 0) ? "⚡" : "⚡");
      ObjectSetInteger(0, nm, OBJPROP_COLOR, (dir > 0) ? clrYellow : clrOrange);
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 12);
   }
   return dir;
}

//+==================================================================+
//|  Dynamic SL/TP Lines + Multi-Stage Exit                           |
//+==================================================================+
void TPSet_Create(datetime t, int barIdx, int dir, double entry, double atrVal)
{
   if(!InpTPLines_Enable || atrVal <= 0.0) return;
   if(g_tpsetCnt >= InpTP_MaxActive)
   {
      // Retire oldest: remove its objects
      string op = g_tpset[0].prefix;
      ObjectsDeleteAll(0, op);
      for(int k = 1; k < g_tpsetCnt; k++) g_tpset[k - 1] = g_tpset[k];
      g_tpsetCnt--;
   }
   int idx = g_tpsetCnt;
   ArrayResize(g_tpset, idx + 1);
   g_tpset[idx].entryT    = t;
   g_tpset[idx].entryBar  = barIdx;
   g_tpset[idx].direction = dir;
   g_tpset[idx].entryPrice= entry;
   if(dir > 0)
   {
      g_tpset[idx].slPrice  = entry - atrVal * InpTP_SL_ATR;
      g_tpset[idx].tp1Price = entry + atrVal * InpTP_TP1_ATR;
      g_tpset[idx].tp2Price = entry + atrVal * InpTP_TP2_ATR;
      g_tpset[idx].tp3Price = entry + atrVal * InpTP_TP3_ATR;
   }
   else
   {
      g_tpset[idx].slPrice  = entry + atrVal * InpTP_SL_ATR;
      g_tpset[idx].tp1Price = entry - atrVal * InpTP_TP1_ATR;
      g_tpset[idx].tp2Price = entry - atrVal * InpTP_TP2_ATR;
      g_tpset[idx].tp3Price = entry - atrVal * InpTP_TP3_ATR;
   }
   g_tpset[idx].tp1Hit = false; g_tpset[idx].tp2Hit = false;
   g_tpset[idx].tp3Hit = false;
   g_tpset[idx].slHit  = false; g_tpset[idx].beMoved= false;
   g_tpset[idx].prefix = g_prefix + "TP_" + IntegerToString((int)t) + "_";
   g_tpsetCnt++;

   // Draw 4 horizontal lines (entry ray): SL / TP1 / TP2 / TP3
   datetime en = t + (datetime)(PeriodSeconds() * InpTPLines_Extend);
   string  suf[4];  double prc[4];  color  col[4];
   suf[0]="SL";  prc[0]=g_tpset[idx].slPrice;  col[0]=clrCrimson;
   suf[1]="TP1"; prc[1]=g_tpset[idx].tp1Price; col[1]=clrYellowGreen;
   suf[2]="TP2"; prc[2]=g_tpset[idx].tp2Price; col[2]=clrLime;
   suf[3]="TP3"; prc[3]=g_tpset[idx].tp3Price; col[3]=clrDeepSkyBlue;
   for(int L = 0; L < 4; L++)
   {
      string nm = g_tpset[idx].prefix + suf[L];
      if(ObjectFind(0, nm) < 0)
         ObjectCreate(0, nm, OBJ_TREND, 0, t, prc[L], en, prc[L]);
      ObjectSetInteger(0, nm, OBJPROP_TIME, 0, t);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, 0, prc[L]);
      ObjectSetInteger(0, nm, OBJPROP_TIME, 1, en);
      ObjectSetDouble (0, nm, OBJPROP_PRICE, 1, prc[L]);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, col[L]);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, nm, OBJPROP_STYLE, (L == 0) ? STYLE_DASH : STYLE_SOLID);
      ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
      string lb = g_tpset[idx].prefix + suf[L] + "_lbl";
      if(ObjectFind(0, lb) < 0)
         ObjectCreate(0, lb, OBJ_TEXT, 0, en, prc[L]);
      ObjectSetInteger(0, lb, OBJPROP_TIME, 0, en);
      ObjectSetDouble (0, lb, OBJPROP_PRICE, 0, prc[L]);
      ObjectSetString (0, lb, OBJPROP_TEXT, suf[L]);
      ObjectSetInteger(0, lb, OBJPROP_COLOR, col[L]);
      ObjectSetInteger(0, lb, OBJPROP_FONTSIZE, 8);
   }
}

//--- Update hit status for active TP sets and draw stage markers.
void TPSet_Update(const double &high[], const double &low[],
                  const datetime &time[], int total)
{
   if(!InpTPLines_Enable) return;
   int i = total - 2;
   if(i < 0) return;
   double hi = high[i], lo = low[i];
   datetime tt = time[i];

   for(int k = 0; k < g_tpsetCnt; k++)
   {
      if(g_tpset[k].slHit) continue;
      int d = g_tpset[k].direction;

      if(!g_tpset[k].tp1Hit)
      {
         bool hit = (d > 0) ? (hi >= g_tpset[k].tp1Price) : (lo <= g_tpset[k].tp1Price);
         if(hit)
         {
            g_tpset[k].tp1Hit = true;
            string nm = g_tpset[k].prefix + "TP1_hit";
            if(ObjectFind(0, nm) < 0)
               ObjectCreate(0, nm, OBJ_ARROW, 0, tt, g_tpset[k].tp1Price);
            ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, 159);
            ObjectSetInteger(0, nm, OBJPROP_COLOR, clrYellowGreen);
         }
      }
      if(!g_tpset[k].tp2Hit)
      {
         bool hit = (d > 0) ? (hi >= g_tpset[k].tp2Price) : (lo <= g_tpset[k].tp2Price);
         if(hit)
         {
            g_tpset[k].tp2Hit = true;
            string nm = g_tpset[k].prefix + "TP2_hit";
            if(ObjectFind(0, nm) < 0)
               ObjectCreate(0, nm, OBJ_ARROW, 0, tt, g_tpset[k].tp2Price);
            ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, 159);
            ObjectSetInteger(0, nm, OBJPROP_COLOR, clrLime);
         }
      }
      if(!g_tpset[k].tp3Hit)
      {
         bool hit = (d > 0) ? (hi >= g_tpset[k].tp3Price) : (lo <= g_tpset[k].tp3Price);
         if(hit)
         {
            g_tpset[k].tp3Hit = true;
            string nm = g_tpset[k].prefix + "TP3_hit";
            if(ObjectFind(0, nm) < 0)
               ObjectCreate(0, nm, OBJ_ARROW, 0, tt, g_tpset[k].tp3Price);
            ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, 159);
            ObjectSetInteger(0, nm, OBJPROP_COLOR, clrDeepSkyBlue);
         }
      }
      // BE auto-marker after TP1 hit
      if(InpTP_ShowBE && g_tpset[k].tp1Hit && !g_tpset[k].beMoved)
      {
         g_tpset[k].beMoved = true;
         string nm = g_tpset[k].prefix + "BE";
         datetime en = g_tpset[k].entryT + (datetime)(PeriodSeconds() * InpTPLines_Extend);
         if(ObjectFind(0, nm) < 0)
            ObjectCreate(0, nm, OBJ_TREND, 0, g_tpset[k].entryT, g_tpset[k].entryPrice,
                         en, g_tpset[k].entryPrice);
         ObjectSetInteger(0, nm, OBJPROP_COLOR, clrGold);
         ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
      }
      // SL hit
      bool slHit = (d > 0) ? (lo <= g_tpset[k].slPrice) : (hi >= g_tpset[k].slPrice);
      if(slHit)
      {
         g_tpset[k].slHit = true;
         string nm = g_tpset[k].prefix + "SL_hit";
         if(ObjectFind(0, nm) < 0)
            ObjectCreate(0, nm, OBJ_ARROW, 0, tt, g_tpset[k].slPrice);
         ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, 251);
         ObjectSetInteger(0, nm, OBJPROP_COLOR, clrRed);
      }
   }
}

//--- SMC confluence bonus score (0-7).
//--- dir: +1 BULL signal, -1 BEAR signal. price: current close.
int SMCConfluenceBonus(int dir, double price, datetime barT)
{
   int bonus = 0;
   // +2 if sweep detected on this bar aligned with dir
   int swDir = SweepDirectionAt(barT);
   if(swDir == dir) bonus += 2;
   // +2 if inside unmitigated OB aligned with dir
   if(OBConfluenceAt(price, dir)) bonus += 2;
   // +1 if inside unfilled FVG aligned with dir
   if(FVGActiveAt(price, dir)) bonus += 1;
   // +2 if ChoCh happened recently (within 5 bars) aligned with dir
   datetime cutoff = barT - (datetime)(PeriodSeconds() * 5);
   if(dir > 0 && g_lastChoChBull >= cutoff) bonus += 2;
   if(dir < 0 && g_lastChoChBear >= cutoff) bonus += 2;
   return bonus;
}

//+------------------------------------------------------------------+
int OnInit()
{
   for(int i = 0; i < 8; i++) g_hEMA[i] = INVALID_HANDLE;
   for(int i = 0; i < 4; i++)
   {  g_hTrendEMA20[i] = INVALID_HANDLE;
      g_hTrendEMA50[i] = INVALID_HANDLE;
      g_hTrendATR[i]   = INVALID_HANDLE; }
   g_hChartATR = INVALID_HANDLE;
   g_hADX = INVALID_HANDLE;

   g_mtfTF[0] = PERIOD_M5;
   g_mtfTF[1] = PERIOD_M15;
   g_mtfTF[2] = PERIOD_H1;
   g_mtfName[0] = "5Min";
   g_mtfName[1] = "15Min";
   g_mtfName[2] = "1H";

   SetIndexBuffer(0,  g_ema1,      INDICATOR_DATA);
   SetIndexBuffer(1,  g_ema2a,     INDICATOR_DATA);
   SetIndexBuffer(2,  g_ema2b,     INDICATOR_DATA);
   SetIndexBuffer(3,  g_ema3a,     INDICATOR_DATA);
   SetIndexBuffer(4,  g_ema3b,     INDICATOR_DATA);
   SetIndexBuffer(5,  g_ema4a,     INDICATOR_DATA);
   SetIndexBuffer(6,  g_ema4b,     INDICATOR_DATA);
   SetIndexBuffer(7,  g_ema5a,     INDICATOR_DATA);
   SetIndexBuffer(8,  g_ema5b,     INDICATOR_DATA);
   SetIndexBuffer(9,  g_ema6a,     INDICATOR_DATA);
   SetIndexBuffer(10, g_ema6b,     INDICATOR_DATA);
   SetIndexBuffer(11, g_ema7a,     INDICATOR_DATA);
   SetIndexBuffer(12, g_ema7b,     INDICATOR_DATA);
   SetIndexBuffer(13, g_ema8,      INDICATOR_DATA);
   SetIndexBuffer(14, g_bullSignal,INDICATOR_DATA);
   SetIndexBuffer(15, g_bearSignal,INDICATOR_DATA);
   SetIndexBuffer(16, g_candleO,   INDICATOR_DATA);
   SetIndexBuffer(17, g_candleH,   INDICATOR_DATA);
   SetIndexBuffer(18, g_candleL,   INDICATOR_DATA);
   SetIndexBuffer(19, g_candleC,   INDICATOR_DATA);
   SetIndexBuffer(20, g_candleClr, INDICATOR_COLOR_INDEX);

   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(8, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   int lens[8];
   lens[0]=InpEMA1; lens[1]=InpEMA2; lens[2]=InpEMA3; lens[3]=InpEMA4;
   lens[4]=InpEMA5; lens[5]=InpEMA6; lens[6]=InpEMA7; lens[7]=InpEMA8;

   for(int i = 0; i < 8; i++)
   {
      g_hEMA[i] = iMA(_Symbol, PERIOD_CURRENT, lens[i], 0, MODE_EMA, PRICE_CLOSE);
      if(g_hEMA[i] == INVALID_HANDLE) return(INIT_FAILED);
   }

   g_masterTrend = 0;
   g_hiLvlCnt = 0;
   g_loLvlCnt = 0;
   ArrayResize(g_hiNames, 0);
   ArrayResize(g_loNames, 0);

   // Trend Status Panel: EMA20/50 + ATR for M5/M15/H1/H4
   g_trendTF[0] = PERIOD_M5;  g_trendTFName[0] = "M5";
   g_trendTF[1] = PERIOD_M15; g_trendTFName[1] = "M15";
   g_trendTF[2] = PERIOD_H1;  g_trendTFName[2] = "H1";
   g_trendTF[3] = PERIOD_H4;  g_trendTFName[3] = "H4";

   for(int i = 0; i < 4; i++)
   {
      g_hTrendEMA20[i] = iMA(_Symbol, g_trendTF[i], 20, 0, MODE_EMA, PRICE_CLOSE);
      g_hTrendEMA50[i] = iMA(_Symbol, g_trendTF[i], 50, 0, MODE_EMA, PRICE_CLOSE);
      g_hTrendATR[i]   = iATR(_Symbol, g_trendTF[i], 14);
      if(g_hTrendEMA20[i]==INVALID_HANDLE || g_hTrendEMA50[i]==INVALID_HANDLE || g_hTrendATR[i]==INVALID_HANDLE)
         return(INIT_FAILED);
   }
   g_hChartATR = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(g_hChartATR == INVALID_HANDLE) return(INIT_FAILED);
   g_hADX = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);
   if(g_hADX == INVALID_HANDLE) return(INIT_FAILED);

   CreateUI();
   CreateWatermark();
   CreateMSSPanel();
   CreateTrendPanel();
   CreateToggleButtons();

   //--- AI Self-Learning initialization (Layer 2)
   g_showAI = InpShowAIPanel;
   g_effAdxThreshold  = InpADXThreshold;
   g_effExitThreshold = InpExitThreshold;
   g_signalLogFile    = SignalLogFilename();
   if(InpSelfLearn)
   {
      LoadSignalLog();
      RecomputeStats();
      UpdateEffectiveThresholds();
   }
   if(g_showAI && InpShowAIPanel)
   {
      CreateAIPanel();
      UpdateAIPanel();
   }

   //--- ONNX AI Scorer initialization (Layer 1)
   g_aiEnabled = InitONNX();

   IndicatorSetString(INDICATOR_SHORTNAME, "FAD APEX");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, g_prefix);
   for(int i = 0; i < 8; i++)
      if(g_hEMA[i] != INVALID_HANDLE)
         IndicatorRelease(g_hEMA[i]);
   for(int i = 0; i < 4; i++)
   {
      if(g_hTrendEMA20[i] != INVALID_HANDLE) IndicatorRelease(g_hTrendEMA20[i]);
      if(g_hTrendEMA50[i] != INVALID_HANDLE) IndicatorRelease(g_hTrendEMA50[i]);
      if(g_hTrendATR[i] != INVALID_HANDLE) IndicatorRelease(g_hTrendATR[i]);
   }
   if(g_hChartATR != INVALID_HANDLE) IndicatorRelease(g_hChartATR);
   if(g_hADX != INVALID_HANDLE) IndicatorRelease(g_hADX);
   //--- AI self-learning: persist final state before exit
   if(InpSelfLearn && g_signalLogDirty) SaveSignalLog();
   //--- Release ONNX handle
   if(g_aiHandle != INVALID_HANDLE)
   {
      OnnxRelease(g_aiHandle);
      g_aiHandle = INVALID_HANDLE;
      g_aiEnabled = false;
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
void MakeButtonCorner(string name, string text, int x, int y, int w, int h,
                      ENUM_BASE_CORNER corner)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_COLOR, C'180,190,210');
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'30,32,48');
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'60,80,130');
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
void CreateUI()
{
   int x = 10, y = 50, w = 42, h = 24, gap = 2;
   MakeButtonCorner(g_prefix+"BtnM1",  "M1",  x,             y, w, h, CORNER_LEFT_UPPER);
   MakeButtonCorner(g_prefix+"BtnM5",  "M5",  x+(w+gap),     y, w, h, CORNER_LEFT_UPPER);
   MakeButtonCorner(g_prefix+"BtnM15", "M15", x+2*(w+gap),   y, w, h, CORNER_LEFT_UPPER);
   MakeButtonCorner(g_prefix+"BtnH1",  "H1",  x+3*(w+gap),   y, w, h, CORNER_LEFT_UPPER);
   MakeButtonCorner(g_prefix+"BtnH4",  "H4",  x+4*(w+gap),   y, w, h, CORNER_LEFT_UPPER);
   MakeButtonCorner(g_prefix+"BtnD1",  "D1",  x+5*(w+gap),   y, w, h, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
void DeleteMSSPanelObjects()
{
   string names[] = {"MSSBg","MSSTitle","MSSScore","MSSDir","MSSSfx",
                     "MSSBarBg","MSSBarFill","MSSLevel","MSSSep","MSSTFHdr",
                     "MSSTF0","MSSTF1","MSSTF2",
                     "MSSArr0","MSSArr1","MSSArr2"};
   for(int i = 0; i < ArraySize(names); i++)
      ObjectDelete(0, g_prefix + names[i]);
}

void DeleteTrendPanelObjects()
{
   ObjectDelete(0, g_prefix + "TrendBg");
   ObjectDelete(0, g_prefix + "TrendTitle");
   for(int i = 0; i < 4; i++)
   {
      ObjectDelete(0, g_prefix + "TrTF" + IntegerToString(i));
      ObjectDelete(0, g_prefix + "TrSt" + IntegerToString(i));
   }
}

void CreateToggleButtons()
{
   // Place toggle buttons in the top bar, right after TF buttons (M1..D1)
   int x0 = 280, y = 50, w = 42, h = 24;
   MakeButtonCorner(g_prefix+"TogMSS",    "MSS", x0,             y, w, h, CORNER_LEFT_UPPER);
   MakeButtonCorner(g_prefix+"TogTrend",  "TRD", x0 + (w+2),     y, w, h, CORNER_LEFT_UPPER);
   MakeButtonCorner(g_prefix+"TogRibbon", "EMA", x0 + 2*(w+2),   y, w, h, CORNER_LEFT_UPPER);
   MakeButtonCorner(g_prefix+"TogAI",     "AI",  x0 + 3*(w+2),   y, w, h, CORNER_LEFT_UPPER);
   MakeButtonCorner(g_prefix+"BtnAIRst",  "Rst", x0 + 4*(w+2),   y, w, h, CORNER_LEFT_UPPER);
   UpdateToggleButtons();
}

void UpdateToggleButtons()
{
   string mss = g_prefix + "TogMSS";
   if(ObjectFind(0, mss) >= 0)
   {
      ObjectSetString(0, mss, OBJPROP_TEXT, g_showMSS ? "MSS" : "mss");
      ObjectSetInteger(0, mss, OBJPROP_BGCOLOR, g_showMSS ? C'25,80,60' : C'80,30,30');
      ObjectSetInteger(0, mss, OBJPROP_STATE, false);
   }
   string trd = g_prefix + "TogTrend";
   if(ObjectFind(0, trd) >= 0)
   {
      ObjectSetString(0, trd, OBJPROP_TEXT, g_showTrend ? "TRD" : "trd");
      ObjectSetInteger(0, trd, OBJPROP_BGCOLOR, g_showTrend ? C'25,80,60' : C'80,30,30');
      ObjectSetInteger(0, trd, OBJPROP_STATE, false);
   }
   string rbn = g_prefix + "TogRibbon";
   if(ObjectFind(0, rbn) >= 0)
   {
      ObjectSetString(0, rbn, OBJPROP_TEXT, g_showRibbon ? "EMA" : "ema");
      ObjectSetInteger(0, rbn, OBJPROP_BGCOLOR, g_showRibbon ? C'25,80,60' : C'80,30,30');
      ObjectSetInteger(0, rbn, OBJPROP_STATE, false);
   }
   string ai = g_prefix + "TogAI";
   if(ObjectFind(0, ai) >= 0)
   {
      ObjectSetString(0, ai, OBJPROP_TEXT, g_showAI ? "AI" : "ai");
      ObjectSetInteger(0, ai, OBJPROP_BGCOLOR, g_showAI ? C'40,70,130' : C'50,40,60');
      ObjectSetInteger(0, ai, OBJPROP_STATE, false);
   }
   string rst = g_prefix + "BtnAIRst";
   if(ObjectFind(0, rst) >= 0)
   {
      ObjectSetString(0, rst, OBJPROP_TEXT, "Rst");
      ObjectSetInteger(0, rst, OBJPROP_BGCOLOR, C'80,40,40');
      ObjectSetInteger(0, rst, OBJPROP_STATE, false);
   }
}

void EnforcePanelVisibility()
{
   if(!g_showMSS)   DeleteMSSPanelObjects();
   if(!g_showTrend) DeleteTrendPanelObjects();
   if(!g_showAI || !InpShowAIPanel)
      DeleteAIPanelObjects();
   UpdateToggleButtons();
}

//--- Apply ribbon visibility to all existing buffers immediately.
//    On hide: clear 14 ribbon buffers with EMPTY_VALUE.
//    On show: refill ribbon buffers from EMA indicator handles.
void ApplyRibbonVisibility()
{
   int total = Bars(_Symbol, _Period);
   if(total <= 0) return;

   if(!g_showRibbon)
   {
      for(int i = 0; i < total; i++)
      {
         g_ema1[i]  = EMPTY_VALUE;
         g_ema2a[i] = EMPTY_VALUE; g_ema2b[i] = EMPTY_VALUE;
         g_ema3a[i] = EMPTY_VALUE; g_ema3b[i] = EMPTY_VALUE;
         g_ema4a[i] = EMPTY_VALUE; g_ema4b[i] = EMPTY_VALUE;
         g_ema5a[i] = EMPTY_VALUE; g_ema5b[i] = EMPTY_VALUE;
         g_ema6a[i] = EMPTY_VALUE; g_ema6b[i] = EMPTY_VALUE;
         g_ema7a[i] = EMPTY_VALUE; g_ema7b[i] = EMPTY_VALUE;
         g_ema8[i]  = EMPTY_VALUE;
      }
      return;
   }

   double b0[], b1[], b2[], b3[], b4[], b5[], b6[], b7[];
   ArraySetAsSeries(b0, false); ArraySetAsSeries(b1, false);
   ArraySetAsSeries(b2, false); ArraySetAsSeries(b3, false);
   ArraySetAsSeries(b4, false); ArraySetAsSeries(b5, false);
   ArraySetAsSeries(b6, false); ArraySetAsSeries(b7, false);

   if(CopyBuffer(g_hEMA[0],0,0,total,b0) != total) return;
   if(CopyBuffer(g_hEMA[1],0,0,total,b1) != total) return;
   if(CopyBuffer(g_hEMA[2],0,0,total,b2) != total) return;
   if(CopyBuffer(g_hEMA[3],0,0,total,b3) != total) return;
   if(CopyBuffer(g_hEMA[4],0,0,total,b4) != total) return;
   if(CopyBuffer(g_hEMA[5],0,0,total,b5) != total) return;
   if(CopyBuffer(g_hEMA[6],0,0,total,b6) != total) return;
   if(CopyBuffer(g_hEMA[7],0,0,total,b7) != total) return;

   for(int i = 0; i < total; i++)
   {
      g_ema1[i]  = b0[i];
      g_ema2a[i] = b1[i]; g_ema2b[i] = b1[i];
      g_ema3a[i] = b2[i]; g_ema3b[i] = b2[i];
      g_ema4a[i] = b3[i]; g_ema4b[i] = b3[i];
      g_ema5a[i] = b4[i]; g_ema5b[i] = b4[i];
      g_ema6a[i] = b5[i]; g_ema6b[i] = b5[i];
      g_ema7a[i] = b6[i]; g_ema7b[i] = b6[i];
      g_ema8[i]  = b7[i];
   }
}

//+------------------------------------------------------------------+
void CreateWatermark()
{
   string nm = g_prefix + "Watermark";
   if(ObjectFind(0, nm) >= 0) ObjectDelete(0, nm);
   ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR, ANCHOR_CENTER);
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, chartW / 2);
   ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, chartH / 2);
   string tf = EnumToString(Period());
   StringReplace(tf, "PERIOD_", "");
   ObjectSetString(0, nm, OBJPROP_TEXT, _Symbol + " " + tf + " | FAD APEX");
   ObjectSetString(0, nm, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 22);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, C'50,50,60');
   ObjectSetInteger(0, nm, OBJPROP_BACK, true);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
void MakePanelLabel(string name, int x, int y, string text, string font,
                    int fontSize, color clr, ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER)
{
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void MakePanelRect(string name, int x, int y, int w, int h,
                   color bgClr, color borderClr)
{
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void CreateMSSPanel()
{
   if(!g_showMSS) return;
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int pw = 165, ph = 195;
   int px = 8;
   int py = chartH - ph - 22;

   // Background
   MakePanelRect(g_prefix+"MSSBg", px, py, pw, ph, C'14,16,30', C'45,52,90');

   // Row 1: Title
   MakePanelLabel(g_prefix+"MSSTitle", px+30, py+8, "CONFIDENCE", "Arial Bold", 9, C'100,110,145');

   // Row 2: Direction
   MakePanelLabel(g_prefix+"MSSDir", px+10, py+28, "---", "Arial Bold", 10, C'100,100,115');

   // Row 3: Score + /100
   MakePanelLabel(g_prefix+"MSSScore", px+10, py+50, "---", "Arial Bold", 22, C'100,100,115');
   MakePanelLabel(g_prefix+"MSSSfx", px+110, py+58, "/100", "Arial", 9, C'55,60,82');

   // Row 4: Confidence bar  (score 22pt ≈ 30px, so bar at py+88 = 8px gap)
   MakePanelRect(g_prefix+"MSSBarBg", px+10, py+88, pw-20, 6, C'30,34,52', C'30,34,52');
   MakePanelRect(g_prefix+"MSSBarFill", px+10, py+88, 1, 6, C'100,100,115', C'100,100,115');

   // Row 5: Level text
   MakePanelLabel(g_prefix+"MSSLevel", px+10, py+102, "---", "Arial Bold", 9, C'100,100,115');

   // Row 6: Separator line
   MakePanelRect(g_prefix+"MSSSep", px+10, py+122, pw-20, 1, C'40,44,68', C'40,44,68');

   // Row 7: TF section header
   MakePanelLabel(g_prefix+"MSSTFHdr", px+10, py+130, "MTF ALIGN", "Arial", 8, C'70,76,105');

   // Row 8: TF labels with status text (no Wingdings — use plain text arrows)
   //         "M5  UP"  "M15  DN"  "H1  --"
   int tfY[3] = {py+150, py+150, py+150};
   int tfX[3] = {px+10, px+60, px+115};
   string tfLabels[3] = {"M5", "M15", "H1"};

   for(int i = 0; i < 3; i++)
   {
      // TF name
      MakePanelLabel(g_prefix+"MSSTF"+IntegerToString(i),
                     tfX[i], tfY[i], tfLabels[i], "Arial Bold", 9, C'100,110,145');

      // Status below TF name
      MakePanelLabel(g_prefix+"MSSArr"+IntegerToString(i),
                     tfX[i], tfY[i]+16, "--", "Arial Bold", 9, C'90,90,108');
   }
}

//+------------------------------------------------------------------+
int CalcMSSScore(int t0, int t1, int t2,
                 const double &close[], const double &open[], const double &high[],
                 const double &low[], const long &tickVol[], int idx, int total)
{
   // Determine dominant direction
   int buCnt = 0, beCnt = 0;
   if(t0 == 1)  buCnt++; if(t0 == -1) beCnt++;
   if(t1 == 1)  buCnt++; if(t1 == -1) beCnt++;
   if(t2 == 1)  buCnt++; if(t2 == -1) beCnt++;
   bool isBull = (buCnt >= beCnt);
   int dir = isBull ? 1 : -1;
   double score = 0.0;

   // === MARKET REGIME DETECTION (adaptive weights) ===
   // ATR coefficient of variation: low = trending, high = ranging/volatile
   double regimeBoostAlign = 0.0, regimeBoostEMA = 0.0, regimeBoostBreakout = 0.0;
   if(idx >= 20 && idx < total)
   {
      double atrArr[1];
      if(CopyBuffer(g_hChartATR, 0, total - 1 - idx, 1, atrArr) == 1 && atrArr[0] > 0)
      {
         // Calculate ATR mean and variance over 20 bars
         double atrSum = 0, atrSqSum = 0;
         int atrCopied = 0;
         for(int ab = 0; ab < 20; ab++)
         {
            double atrB[1];
            if(CopyBuffer(g_hChartATR, 0, total - 1 - idx + ab, 1, atrB) == 1)
            {
               atrSum += atrB[0];
               atrSqSum += atrB[0] * atrB[0];
               atrCopied++;
            }
         }
         if(atrCopied > 1)
         {
            double atrMean = atrSum / atrCopied;
            double atrVar = (atrSqSum / atrCopied) - (atrMean * atrMean);
            double atrStd = (atrVar > 0) ? MathSqrt(atrVar) : 0;
            double atrCV = (atrMean > 0) ? atrStd / atrMean : 0;

            bool isTrending = (atrCV < 0.25);       // Stable ATR = trending
            bool isBreakout = (atrArr[0] > atrMean * 1.5); // ATR spike = breakout

            // Adaptive weight adjustments (±5pt shift)
            if(isTrending)
            {
               regimeBoostAlign = 5.0;  // Trending: trust MTF alignment more
               regimeBoostEMA = 3.0;    // Trending: EMA structure more reliable
            }
            if(isBreakout)
            {
               regimeBoostBreakout = 5.0; // Breakout: key level break matters more
            }
            if(!isTrending && !isBreakout)
            {
               regimeBoostAlign = -3.0;   // Ranging: MTF alignment less reliable
               regimeBoostBreakout = 3.0;  // Ranging: breakout more important
            }
         }
      }
   }

   // === A. MTF Alignment (base 35pt + regime adjust) ===
   double alignMax = 35.0 + regimeBoostAlign;
   if(t0 == dir) score += 10.0;
   if(t1 == dir) score += 12.0;
   if(t2 == dir) score += 13.0;
   if(t0 == dir && t1 == dir && t2 == dir) score += 8.0;
   if(score > alignMax) score = alignMax;

   // === B. EMA Structure (base 25pt + regime adjust) ===
   double emaMax = 25.0 + regimeBoostEMA;
   double emaScore = 0.0;
   if(idx >= 0 && idx < total)
   {
      bool perfOrder;
      if(isBull)
         perfOrder = g_ed0[idx]>g_ed1[idx] && g_ed1[idx]>g_ed2[idx] && g_ed2[idx]>g_ed3[idx]
                  && g_ed3[idx]>g_ed4[idx] && g_ed4[idx]>g_ed5[idx] && g_ed5[idx]>g_ed6[idx]
                  && g_ed6[idx]>g_ed7[idx];
      else
         perfOrder = g_ed0[idx]<g_ed1[idx] && g_ed1[idx]<g_ed2[idx] && g_ed2[idx]<g_ed3[idx]
                  && g_ed3[idx]<g_ed4[idx] && g_ed4[idx]<g_ed5[idx] && g_ed5[idx]<g_ed6[idx]
                  && g_ed6[idx]<g_ed7[idx];
      if(perfOrder) emaScore += 12.0;

      // Ribbon squeeze expansion
      double curWidth = MathAbs(g_ed0[idx] - g_ed7[idx]);
      double minW = curWidth;
      int sqLook = MathMin(10, idx);
      for(int j = idx - sqLook; j < idx; j++)
         minW = MathMin(minW, MathAbs(g_ed0[j] - g_ed7[j]));
      if(curWidth > 0 && minW < curWidth * 0.5) emaScore += 8.0;

      // EMA slope acceleration
      if(idx >= 5)
      {
         double slope1 = g_ed0[idx] - g_ed0[idx - 3];
         int backIdx = (idx - 6 >= 0) ? idx - 6 : 0;
         double slope2 = g_ed0[idx - 3] - g_ed0[backIdx];
         bool accel = isBull ? (slope1 > slope2 && slope1 > 0) : (slope1 < slope2 && slope1 < 0);
         if(accel) emaScore += 5.0;
      }
   }
   if(emaScore > emaMax) emaScore = emaMax;
   score += emaScore;

   // === C. Volume Confirmation (max 15pt) ===
   if(idx >= 20 && idx < total)
   {
      double avgVol = 0;
      for(int j = idx - 20; j < idx; j++) avgVol += (double)tickVol[j];
      avgVol /= 20.0;
      if(avgVol > 0 && (double)tickVol[idx] > avgVol * 1.5) score += 8.0;

      // Volume increasing trend (last 5 bars)
      if(idx >= 5)
      {
         int volUp = 0;
         for(int j = idx - 4; j <= idx; j++)
            if(j > 0 && tickVol[j] > tickVol[j-1]) volUp++;
         if(volUp >= 3) score += 7.0;
      }
   }

   // === D. Momentum Acceleration (max 15pt) ===
   if(idx >= 20 && idx < total)
   {
      // Body/ATR ratio
      double atrVal[1];
      if(CopyBuffer(g_hChartATR, 0, total - 1 - idx, 1, atrVal) == 1 && atrVal[0] > 0)
      {
         double bodySize = MathAbs(close[idx] - open[idx]);
         if(bodySize / atrVal[0] > 0.7) score += 5.0;
      }

      // Consecutive same-direction candles
      int consec = 0;
      for(int j = idx; j >= MathMax(0, idx - 5); j--)
      {
         if(isBull && close[j] > open[j]) consec++;
         else if(!isBull && close[j] < open[j]) consec++;
         else break;
      }
      if(consec >= 3) score += 5.0;

      // ADX-like strength (manual DI+/DI- calculation)
      double dmPlus = 0, dmMinus = 0, tr = 0;
      int adxLen = MathMin(14, idx);
      for(int j = idx - adxLen + 1; j <= idx; j++)
      {
         if(j <= 0) continue;
         double hDiff = high[j] - high[j-1];
         double lDiff = low[j-1] - low[j];
         if(hDiff > lDiff && hDiff > 0) dmPlus += hDiff;
         if(lDiff > hDiff && lDiff > 0) dmMinus += lDiff;
         double trVal = MathMax(high[j]-low[j], MathMax(MathAbs(high[j]-close[j-1]), MathAbs(low[j]-close[j-1])));
         tr += trVal;
      }
      if(tr > 0)
      {
         double diPlus = dmPlus / tr * 100;
         double diMinus = dmMinus / tr * 100;
         double adxStr = MathAbs(diPlus - diMinus);
         if(isBull && diPlus > diMinus && adxStr > 15) score += 5.0;
         if(!isBull && diMinus > diPlus && adxStr > 15) score += 5.0;
      }
   }

   // === E. Key Level Breakout (base 10pt + regime adjust) ===
   double breakMax = 10.0 + regimeBoostBreakout;
   double breakScore = 0.0;
   if(idx >= 20 && idx < total)
   {
      double hh = high[idx], ll = low[idx];
      for(int j = idx - 20; j < idx; j++)
      {
         if(high[j] > hh) hh = high[j];
         if(low[j] < ll) ll = low[j];
      }
      if(isBull && close[idx] >= hh) breakScore += 5.0;
      if(!isBull && close[idx] <= ll) breakScore += 5.0;

      // No pullback (momentum sustained)
      if(idx >= 3)
      {
         bool sustained = true;
         for(int j = idx - 2; j <= idx; j++)
         {
            if(isBull && close[j] < open[j]) { sustained = false; break; }
            if(!isBull && close[j] > open[j]) { sustained = false; break; }
         }
         if(sustained) breakScore += 5.0;
      }
   }
   if(breakScore > breakMax) breakScore = breakMax;
   score += breakScore;

   int finalScore = (int)MathMin(100.0, MathMax(0.0, score));
   return(finalScore);
}

//+------------------------------------------------------------------+
// CalcExitScore: 5-layer momentum exhaustion detection
// Detects when a trend is about to reverse — fires EXIT take-profit signal
//+------------------------------------------------------------------+
int CalcExitScore(bool isBullPos, int idx, int total,
                  const double &close[], const double &open[],
                  const double &high[], const double &low[],
                  const long &tickVol[],
                  const double &adxBuf[], int adxCnt,
                  const double &atrBuf[], int atrCnt)
{
   double score = 0.0;
   if(idx < 10) return(0);

   //=== Layer 1: Price deviation from EMA ribbon (30pt) ===
   // When price stretches too far from fastest EMA → mean reversion imminent
   double ribbonW = MathAbs(g_ed0[idx] - g_ed7[idx]);
   if(atrCnt > idx && atrBuf[idx] > 0 && ribbonW > 0)
   {
      double priceDeviation;
      if(isBullPos)
         priceDeviation = close[idx] - g_ed0[idx];  // How far above EMA5
      else
         priceDeviation = g_ed0[idx] - close[idx];  // How far below EMA5

      double atrDev = priceDeviation / atrBuf[idx];  // ATR-normalized

      if(atrDev > 1.5)      score += 30.0;
      else if(atrDev > 1.0)  score += 22.0;
      else if(atrDev > 0.6)  score += 15.0;
      else if(atrDev > 0.3)  score += 8.0;
   }

   //=== Layer 2: EMA slope reversal detection (25pt) ===
   // Fastest EMA curling back = trend tip breaking
   if(idx >= 5)
   {
      double slopeNow  = g_ed0[idx] - g_ed0[idx - 2];
      double slopePrev = g_ed0[idx - 2] - g_ed0[idx - 4];

      if(isBullPos)
      {
         if(slopeNow <= 0)                                   score += 25.0;
         else if(slopePrev > 0 && slopeNow < slopePrev * 0.5) score += 18.0;
         else if(slopePrev > 0 && slopeNow < slopePrev * 0.8) score += 10.0;
      }
      else
      {
         if(slopeNow >= 0)                                   score += 25.0;
         else if(slopePrev < 0 && slopeNow > slopePrev * 0.5) score += 18.0;
         else if(slopePrev < 0 && slopeNow > slopePrev * 0.8) score += 10.0;
      }

      // Bonus: EMA5-EMA8 gap shrinking = ribbon tip converging
      double gap01     = MathAbs(g_ed0[idx] - g_ed1[idx]);
      double gap01prev = MathAbs(g_ed0[idx - 3] - g_ed1[idx - 3]);
      if(gap01prev > 0 && gap01 < gap01prev * 0.6)
         score += 5.0;
   }

   //=== Layer 3: ADX peak detection (20pt) ===
   // ADX peaking and declining = trend power past its peak
   if(adxCnt > idx && idx >= 5)
   {
      double adxMax5 = 0;
      for(int j = idx - 4; j <= idx; j++)
         if(j >= 0 && j < adxCnt && adxBuf[j] > adxMax5) adxMax5 = adxBuf[j];

      double adxNow = adxBuf[idx];
      bool adx2decline = (idx >= 2 && adxBuf[idx] < adxBuf[idx-1] && adxBuf[idx-1] < adxBuf[idx-2]);
      bool adx1decline = (idx >= 1 && adxBuf[idx] < adxBuf[idx-1]);

      if(adxMax5 > 20.0 && adx2decline)         score += 20.0;
      else if(adxMax5 > 20.0 && adx1decline)     score += 12.0;
      else if(adxMax5 > 25.0 && adxNow < adxMax5 * 0.85) score += 8.0;
      else if(adx2decline)                        score += 6.0;  // Any ADX level declining
   }

   //=== Layer 4: Volume climax pattern (15pt) ===
   // Spike in volume followed by declining volume = distribution complete
   if(idx >= 22)
   {
      double avgVol = 0;
      for(int j = idx - 20; j < idx; j++)
         avgVol += (double)tickVol[j];
      avgVol /= 20.0;

      if(avgVol > 0 && idx >= 2)
      {
         double vol2ago = (double)tickVol[idx - 2];
         double vol1ago = (double)tickVol[idx - 1];
         double volNow  = (double)tickVol[idx];

         if(vol2ago > avgVol * 1.5 && vol1ago < vol2ago && volNow < vol1ago)
            score += 15.0;
         else if(vol1ago > avgVol * 1.3 && volNow < vol1ago)
            score += 10.0;
         else if(volNow < avgVol * 0.7 && vol1ago < avgVol * 0.8)
            score += 5.0;
      }
   }

   //=== Layer 5: Candle rejection pattern (10pt) ===
   // Pin bars, doji, engulfing at trend extremes
   double range = high[idx] - low[idx];
   double body  = MathAbs(close[idx] - open[idx]);

   if(range > 0)
   {
      if(isBullPos)
      {
         double upperWick = high[idx] - MathMax(close[idx], open[idx]);
         if(upperWick > range * 0.6)       score += 10.0;  // Pin bar (upper wick)
         else if(body < range * 0.25)      score += 7.0;   // Doji
      }
      else
      {
         double lowerWick = MathMin(close[idx], open[idx]) - low[idx];
         if(lowerWick > range * 0.6)       score += 10.0;  // Pin bar (lower wick)
         else if(body < range * 0.25)      score += 7.0;   // Doji
      }

      // Engulfing pattern (opposite direction large candle)
      if(idx > 0)
      {
         double prevBody = MathAbs(close[idx-1] - open[idx-1]);
         if(isBullPos && close[idx] < open[idx] && body > prevBody * 1.2)
            score += 5.0;  // Bearish engulfing
         if(!isBullPos && close[idx] > open[idx] && body > prevBody * 1.2)
            score += 5.0;  // Bullish engulfing
      }
   }

   int finalScore = (int)MathMin(100.0, MathMax(0.0, score));
   return(finalScore);
}

void UpdateMSSPanel(int trend0, int trend1, int trend2,
                    const double &close[], const double &open[], const double &high[],
                    const double &low[], const long &tickVol[], int idx, int total)
{
   if(!g_showMSS) return;
   int trends[3];
   trends[0] = trend0; trends[1] = trend1; trends[2] = trend2;

   // Update TF direction arrows
   for(int i = 0; i < 3; i++)
   {
      string arrLbl = g_prefix + "MSSArr" + IntegerToString(i);
      if(ObjectFind(0, arrLbl) < 0) continue;
      if(trends[i] == 1)
      {
         ObjectSetString(0, arrLbl, OBJPROP_TEXT, "UP");
         ObjectSetInteger(0, arrLbl, OBJPROP_COLOR, C'0,220,120');
      }
      else if(trends[i] == -1)
      {
         ObjectSetString(0, arrLbl, OBJPROP_TEXT, "DN");
         ObjectSetInteger(0, arrLbl, OBJPROP_COLOR, C'255,60,60');
      }
      else
      {
         ObjectSetString(0, arrLbl, OBJPROP_TEXT, "--");
         ObjectSetInteger(0, arrLbl, OBJPROP_COLOR, C'90,90,105');
      }
   }

   // Calculate confidence score
   int score = CalcMSSScore(trend0, trend1, trend2, close, open, high, low, tickVol, idx, total);

   // Determine direction
   int buCnt = 0, beCnt = 0;
   if(trend0==1) buCnt++; if(trend0==-1) beCnt++;
   if(trend1==1) buCnt++; if(trend1==-1) beCnt++;
   if(trend2==1) buCnt++; if(trend2==-1) beCnt++;
   bool isBull = (buCnt >= beCnt);
   bool allAligned = (buCnt == 3 || beCnt == 3);

   // Direction label
   string dl = g_prefix + "MSSDir";
   if(ObjectFind(0, dl) >= 0)
   {
      string dirTxt;
      color dirClr;
      if(allAligned && isBull)       { dirTxt = "BULL >>"; dirClr = C'0,230,130'; }
      else if(allAligned && !isBull) { dirTxt = "BEAR <<"; dirClr = C'255,65,65'; }
      else if(buCnt > beCnt)         { dirTxt = "BULL BIAS >"; dirClr = C'60,180,110'; }
      else if(beCnt > buCnt)         { dirTxt = "BEAR BIAS <"; dirClr = C'200,80,80'; }
      else                           { dirTxt = "NEUTRAL  -"; dirClr = C'120,120,135'; }
      ObjectSetString(0, dl, OBJPROP_TEXT, dirTxt);
      ObjectSetInteger(0, dl, OBJPROP_COLOR, dirClr);
   }

   // Score number
   color scoreClr;
   if(score >= 75)      scoreClr = isBull ? C'0,255,140' : C'255,70,70';
   else if(score >= 55) scoreClr = C'255,210,50';
   else if(score >= 35) scoreClr = C'150,155,175';
   else                 scoreClr = C'90,90,105';

   string sv = g_prefix + "MSSScore";
   if(ObjectFind(0, sv) >= 0)
   {
      ObjectSetString(0, sv, OBJPROP_TEXT, IntegerToString(score));
      ObjectSetInteger(0, sv, OBJPROP_COLOR, scoreClr);
   }

   // Confidence bar fill
   string barFill = g_prefix + "MSSBarFill";
   if(ObjectFind(0, barFill) >= 0)
   {
      int barMaxW = 145;  // pw(165) - 20 padding
      int barW = (int)(barMaxW * MathMin(100, score) / 100.0);
      if(barW < 1) barW = 1;
      ObjectSetInteger(0, barFill, OBJPROP_XSIZE, barW);
      ObjectSetInteger(0, barFill, OBJPROP_BGCOLOR, scoreClr);
      ObjectSetInteger(0, barFill, OBJPROP_BORDER_COLOR, scoreClr);
   }

   // Confidence level text — actionable guidance
   string lvl = g_prefix + "MSSLevel";
   if(ObjectFind(0, lvl) >= 0)
   {
      string lvlTxt;
      color lvlClr;
      if(score >= 75)
      {
         lvlTxt = "HIGH - ENTRY OK";
         lvlClr = isBull ? C'0,240,130' : C'255,80,80';
      }
      else if(score >= 55)
      {
         lvlTxt = "MEDIUM - WAIT";
         lvlClr = C'240,200,50';
      }
      else if(score >= 35)
      {
         lvlTxt = "LOW - NO ENTRY";
         lvlClr = C'140,140,155';
      }
      else
      {
         lvlTxt = "WEAK - STAY OUT";
         lvlClr = C'100,60,60';
      }
      ObjectSetString(0, lvl, OBJPROP_TEXT, lvlTxt);
      ObjectSetInteger(0, lvl, OBJPROP_COLOR, lvlClr);
   }

   // Panel border highlight on strong conviction
   string bg = g_prefix + "MSSBg";
   string tt = g_prefix + "MSSTitle";
   if(ObjectFind(0, bg) < 0) return;

   if(score >= 75 && isBull)
   {
      ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'10,38,22');
      ObjectSetInteger(0, bg, OBJPROP_BORDER_COLOR, C'0,190,100');
      if(ObjectFind(0, tt) >= 0) ObjectSetInteger(0, tt, OBJPROP_COLOR, C'0,220,110');
   }
   else if(score >= 75 && !isBull)
   {
      ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'42,10,16');
      ObjectSetInteger(0, bg, OBJPROP_BORDER_COLOR, C'210,50,50');
      if(ObjectFind(0, tt) >= 0) ObjectSetInteger(0, tt, OBJPROP_COLOR, C'255,75,75');
   }
   else
   {
      ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'14,16,30');
      ObjectSetInteger(0, bg, OBJPROP_BORDER_COLOR, C'45,52,90');
      if(ObjectFind(0, tt) >= 0) ObjectSetInteger(0, tt, OBJPROP_COLOR, C'100,110,145');
   }
}

//+------------------------------------------------------------------+
void CreateTrendPanel()
{
   if(!g_showTrend) return;
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int pw = 160, ph = 135;
   int px = chartW - pw - 75;  // 75px clears price scale
   int py = chartH - ph - 28;  // 28px above bottom TF tabs

   // Background
   MakePanelRect(g_prefix+"TrendBg", px, py, pw, ph, C'14,16,30', C'45,52,90');

   // Title
   MakePanelLabel(g_prefix+"TrendTitle", px+52, py+6, "TREND", "Arial Bold", 9, C'100,110,145');

   // 4 rows: TF name + status  (28px between rows)
   for(int i = 0; i < 4; i++)
   {
      int rowY = py + 28 + i * 26;

      MakePanelLabel(g_prefix+"TrTF"+IntegerToString(i),
                     px+12, rowY, g_trendTFName[i], "Arial Bold", 10, C'140,148,175');

      MakePanelLabel(g_prefix+"TrSt"+IntegerToString(i),
                     px+55, rowY, "---", "Arial Bold", 10, C'100,100,115');
   }
}

void UpdateTrendPanel()
{
   if(!g_showTrend) return;
   for(int i = 0; i < 4; i++)
   {
      double ema20[6], ema50[6], atrVal[1], closeVal[1];
      int copied20 = CopyBuffer(g_hTrendEMA20[i], 0, 0, 6, ema20);
      int copied50 = CopyBuffer(g_hTrendEMA50[i], 0, 0, 6, ema50);
      int copiedATR = CopyBuffer(g_hTrendATR[i], 0, 0, 1, atrVal);
      int copiedC = CopyClose(_Symbol, g_trendTF[i], 0, 1, closeVal);

      string stLbl = g_prefix + "TrSt" + IntegerToString(i);
      if(ObjectFind(0, stLbl) < 0) continue;

      if(copied20 < 6 || copied50 < 6 || copiedATR < 1 || copiedC < 1)
      {
         ObjectSetString(0, stLbl, OBJPROP_TEXT, "---");
         ObjectSetInteger(0, stLbl, OBJPROP_COLOR, C'100,100,115');
         continue;
      }

      // EMA20 vs EMA50 position
      bool ema20Above = (ema20[5] > ema50[5]);
      double price = closeVal[0];
      bool priceAboveEMA20 = (price > ema20[5]);
      bool priceBelowEMA20 = (price < ema20[5]);

      // EMA20 slope (linear regression over 5 bars)
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for(int j = 0; j < 5; j++)
      {
         sumX  += j;
         sumY  += ema20[j+1];
         sumXY += j * ema20[j+1];
         sumX2 += j * j;
      }
      double emaSlope = (5.0 * sumXY - sumX * sumY) / (5.0 * sumX2 - sumX * sumX);

      // Normalize slope by ATR
      double normSlope = (atrVal[0] > 0) ? emaSlope / atrVal[0] : 0;

      // 5-level trend determination
      string statusTxt;
      color statusClr;

      if(ema20Above && priceAboveEMA20 && normSlope > 0.15)
      {
         statusTxt = "STR UP";
         statusClr = C'0,220,100';
      }
      else if(ema20Above && normSlope > 0.02)
      {
         statusTxt = "UP";
         statusClr = C'80,200,120';
      }
      else if(!ema20Above && priceBelowEMA20 && normSlope < -0.15)
      {
         statusTxt = "STR DN";
         statusClr = C'255,60,60';
      }
      else if(!ema20Above && normSlope < -0.02)
      {
         statusTxt = "DOWN";
         statusClr = C'220,90,90';
      }
      else
      {
         statusTxt = "RANGE";
         statusClr = C'140,140,155';
      }

      ObjectSetString(0, stLbl, OBJPROP_TEXT, statusTxt);
      ObjectSetInteger(0, stLbl, OBJPROP_COLOR, statusClr);
   }
}

//+------------------------------------------------------------------+
void SendSignalAlert(string direction, double price)
{
   string tf = EnumToString(Period());
   StringReplace(tf, "PERIOD_", "");
   string msg = StringFormat("[%s] %s @ %s | %s | %s",
                _Symbol, direction,
                DoubleToString(price, _Digits),
                tf, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   if(InpAlertSound)
      PlaySound("alert.wav");
   Alert(msg);
   if(InpPushNotify)
      SendNotification(msg);
   Print("FAD APEX: ", msg);
}

//+------------------------------------------------------------------+
double FindPivotHigh(const double &a[], int bar, int lb, int rb, int sz)
{
   if(bar - lb < 0 || bar + rb >= sz) return(0.0);
   double v = a[bar];
   for(int i = 1; i <= lb; i++)
      if(a[bar - i] >= v) return(0.0);
   for(int i = 1; i <= rb; i++)
      if(a[bar + i] >= v) return(0.0);
   return(v);
}

//+------------------------------------------------------------------+
double FindPivotLow(const double &a[], int bar, int lb, int rb, int sz)
{
   if(bar - lb < 0 || bar + rb >= sz) return(0.0);
   double v = a[bar];
   for(int i = 1; i <= lb; i++)
      if(a[bar - i] <= v) return(0.0);
   for(int i = 1; i <= rb; i++)
      if(a[bar + i] <= v) return(0.0);
   return(v);
}

//+------------------------------------------------------------------+
void CreateBOSLabel(string tag, datetime dt, double pr,
                    string txt, color c, bool above)
{
   string nm = g_prefix + tag;
   if(ObjectFind(0, nm) >= 0) return;
   ObjectCreate(0, nm, OBJ_TEXT, 0, dt, pr);
   ObjectSetString(0, nm, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 13);
   ObjectSetString(0, nm, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR,
                    above ? ANCHOR_LOWER : ANCHOR_UPPER);
}

//+------------------------------------------------------------------+
void CreateSignalLabel(string tag, datetime dt, double pr,
                       string txt, color c, bool above, int fontSize = 10)
{
   string nm = g_prefix + tag;
   if(ObjectFind(0, nm) >= 0) return;
   ObjectCreate(0, nm, OBJ_TEXT, 0, dt, pr);
   ObjectSetString(0, nm, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, nm, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR,
                    above ? ANCHOR_LOWER : ANCHOR_UPPER);
}

void CreateSignalDot(string tag, datetime dt, double pr,
                     color c, bool above, int dotSize = 28)
{
   string nm = g_prefix + tag;
   if(ObjectFind(0, nm) >= 0) return;
   ObjectCreate(0, nm, OBJ_TEXT, 0, dt, pr);
   ObjectSetString(0, nm, OBJPROP_TEXT, CharToString(108));  // Wingdings large dot
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, dotSize);
   ObjectSetString(0, nm, OBJPROP_FONT, "Wingdings");
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR,
                    above ? ANCHOR_LOWER : ANCHOR_UPPER);
}

//+------------------------------------------------------------------+
void MakeKeyLevel(bool isHi, double pr, datetime t1, datetime t2)
{
   string nm;
   color c;
   if(isHi)
   {
      g_hiLvlCnt++;
      nm = g_prefix + "HL" + IntegerToString(g_hiLvlCnt);
      c = C'100,180,240';
      int s = ArraySize(g_hiNames);
      ArrayResize(g_hiNames, s + 1);
      g_hiNames[s] = nm;
      while(ArraySize(g_hiNames) > InpMaxLevels)
      {
         ObjectDelete(0, g_hiNames[0]);
         int n = ArraySize(g_hiNames);
         for(int i = 0; i < n - 1; i++) g_hiNames[i] = g_hiNames[i + 1];
         ArrayResize(g_hiNames, n - 1);
      }
   }
   else
   {
      g_loLvlCnt++;
      nm = g_prefix + "LL" + IntegerToString(g_loLvlCnt);
      c = C'220,90,130';
      int s = ArraySize(g_loNames);
      ArrayResize(g_loNames, s + 1);
      g_loNames[s] = nm;
      while(ArraySize(g_loNames) > InpMaxLevels)
      {
         ObjectDelete(0, g_loNames[0]);
         int n = ArraySize(g_loNames);
         for(int i = 0; i < n - 1; i++) g_loNames[i] = g_loNames[i + 1];
         ArrayResize(g_loNames, n - 1);
      }
   }
   if(ObjectFind(0, nm) >= 0) ObjectDelete(0, nm);
   ObjectCreate(0, nm, OBJ_TREND, 0, t1, pr, t2, pr);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, nm, OBJPROP_BACK, true);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
// Find chart bar index for a given time (binary search)
//+------------------------------------------------------------------+
int FindChartBar(const datetime &time[], int total, datetime target)
{
   if(total <= 0) return(0);
   if(target <= time[0]) return(0);
   if(target >= time[total - 1]) return(total - 1);
   int lo = 0, hi = total - 1;
   while(lo < hi)
   {
      int mid = (lo + hi + 1) / 2;
      if(time[mid] <= target) lo = mid;
      else hi = mid - 1;
   }
   return(lo);
}

//+------------------------------------------------------------------+
// Process one HTF timeframe: detect BOS/MSS at CHART BAR frequency
// Simulates Pine Script's request.security + f_structure_logic behavior
//+------------------------------------------------------------------+
void ProcessHTF(int tfIdx, int lb,
                const datetime &chartTime[], const double &chartHigh[],
                const double &chartLow[], int chartTotal,
                bool fullRecalc, double &barTrend[])
{
   ENUM_TIMEFRAMES period = g_mtfTF[tfIdx];
   int need = 5000;

   double htfH[], htfL[], htfC[];
   datetime htfT[];
   ArraySetAsSeries(htfH, false);
   ArraySetAsSeries(htfL, false);
   ArraySetAsSeries(htfC, false);
   ArraySetAsSeries(htfT, false);

   int cntH = CopyHigh(_Symbol, period, 0, need, htfH);
   int cntL = CopyLow(_Symbol, period, 0, need, htfL);
   int cntC = CopyClose(_Symbol, period, 0, need, htfC);
   int cntT = CopyTime(_Symbol, period, 0, need, htfT);
   int cnt = MathMin(MathMin(cntH, cntL), MathMin(cntC, cntT));

   if(cnt < 2 * lb + 2) return;

   // Pre-compute pivots at HTF bar level
   double htfPH[], htfPL[];
   ArrayResize(htfPH, cnt);
   ArrayResize(htfPL, cnt);
   for(int j = 0; j < cnt; j++)
   {
      if(j >= 2 * lb)
      {
         htfPH[j] = FindPivotHigh(htfH, j - lb, lb, lb, cnt);
         htfPL[j] = FindPivotLow(htfL, j - lb, lb, lb, cnt);
      }
      else
      {
         htfPH[j] = 0.0;
         htfPL[j] = 0.0;
      }
   }

   // Structure state (Pine's var equivalents, persist across chart bars)
   double prevSH = 0, prevSL = 0, lastSH = 0, lastSL = 0;
   int trend = 0;

   // Previous chart bar's values for crossover detection
   double prevMappedClose = 0;
   double prevLastSH = 0;
   double prevLastSL = 0;
   int prevMappedIdx = -1;

   // Period in seconds for request.security mapping
   int chartPeriod = PeriodSeconds(PERIOD_CURRENT);
   int htfPeriod = PeriodSeconds(period);

   string tfName = g_mtfName[tfIdx];

   // Process at CHART BAR frequency (matches Pine's f_structure_logic)
   for(int i = 0; i < chartTotal; i++)
   {
      // Simulate request.security(lookahead=off):
      // Find latest HTF bar that CLOSED by chart bar's close time
      datetime chartClose = chartTime[i] + (datetime)chartPeriod;
      datetime cutoff = chartClose - (datetime)htfPeriod;
      // Real-time bar safety: on the last bar, subtract 1 to avoid referencing unclosed HTF bar
      if(i == chartTotal - 1 && chartPeriod <= htfPeriod)
         cutoff -= 1;
      int htfIdx = FindChartBar(htfT, cnt, cutoff);

      // Update swing levels for all new HTF bars since last chart bar
      if(htfIdx > prevMappedIdx)
      {
         int startK = (prevMappedIdx >= 0) ? prevMappedIdx + 1 : 0;
         for(int k = startK; k <= htfIdx; k++)
         {
            if(htfPH[k] > 0.0) { prevSH = lastSH; lastSH = htfPH[k]; }
            if(htfPL[k] > 0.0) { prevSL = lastSL; lastSL = htfPL[k]; }
         }
      }

      // Determine trend (relaxed: HH OR HL sufficient, with early init)
      if(lastSH > 0 && prevSH > 0 && lastSL > 0 && prevSL > 0)
      {
         int structScore = 0;
         if(lastSH > prevSH) structScore++;
         if(lastSH < prevSH) structScore--;
         if(lastSL > prevSL) structScore++;
         if(lastSL < prevSL) structScore--;
         if(structScore > 0) trend = 1;
         else if(structScore < 0) trend = -1;
      }
      else if(lastSH > 0 && prevSH > 0)
      {
         if(lastSH > prevSH) trend = 1;
         else if(lastSH < prevSH) trend = -1;
      }
      else if(lastSL > 0 && prevSL > 0)
      {
         if(lastSL > prevSL) trend = 1;
         else if(lastSL < prevSL) trend = -1;
      }

      // Crossover at CHART BAR frequency (ta.crossover/ta.crossunder)
      double curClose = htfC[htfIdx];
      bool bBu = false, bBe = false, mBu = false, mBe = false;

      if(i > 0 && prevMappedClose > 0)
      {
         bool crossOverSH = (lastSH > 0 && prevLastSH > 0
                             && curClose > lastSH && prevMappedClose <= prevLastSH);
         bool crossUnderSL = (lastSL > 0 && prevLastSL > 0
                              && curClose < lastSL && prevMappedClose >= prevLastSL);

         if(trend == 1 && crossOverSH)   bBu = true;
         if(trend == -1 && crossUnderSL)  bBe = true;
         if(trend == -1 && crossOverSH)   mBu = true;
         if(trend == 1 && crossUnderSL)   mBe = true;
      }

      // Update trend on MSS
      if(mBu) trend = 1;
      if(mBe) trend = -1;

      barTrend[i] = (double)trend;

      // Store for next chart bar's crossover
      prevMappedClose = curClose;
      prevLastSH = lastSH;
      prevLastSL = lastSL;
      prevMappedIdx = htfIdx;

      // Create BOS/MSS labels
      if(bBu || bBe || mBu || mBe)
      {
         bool isRecent = (fullRecalc && i > chartTotal - 500) ||
                         (!fullRecalc && i >= chartTotal - 3);
         if(isRecent)
         {
            string timeSuffix = IntegerToString((long)chartTime[i]);

            if(bBu)
               CreateBOSLabel("BBu" + tfName + timeSuffix,
                  chartTime[i], chartLow[i],
                  "B", C'0,230,118', false);
            if(bBe)
               CreateBOSLabel("BBe" + tfName + timeSuffix,
                  chartTime[i], chartHigh[i],
                  "B", C'255,82,82', true);
            if(mBu)
               CreateBOSLabel("MBu" + tfName + timeSuffix,
                  chartTime[i], chartLow[i],
                  "M", C'0,190,160', false);
            if(mBe)
               CreateBOSLabel("MBe" + tfName + timeSuffix,
                  chartTime[i], chartHigh[i],
                  "M", C'255,80,150', true);

            // MSS/BOS push notification (latest bars only, per-TF duplicate prevention)
            // Get per-TF last notify time
            datetime lastMSS = (tfIdx == 0) ? g_lastMSSNotify0 : (tfIdx == 1) ? g_lastMSSNotify1 : g_lastMSSNotify2;
            if(!fullRecalc && i >= chartTotal - 3 && chartTime[i] > lastMSS)
            {
               // Notify ALL events on this bar (not just first one)
               string mssTypes[];
               int mssCount = 0;
               ArrayResize(mssTypes, 4);
               if(mBu) { mssTypes[mssCount] = "MSS Bull"; mssCount++; }
               if(mBe) { mssTypes[mssCount] = "MSS Bear"; mssCount++; }
               if(bBu) { mssTypes[mssCount] = "BOS Bull"; mssCount++; }
               if(bBe) { mssTypes[mssCount] = "BOS Bear"; mssCount++; }

               if(mssCount > 0)
               {
                  // Update per-TF timestamp
                  if(tfIdx == 0) g_lastMSSNotify0 = chartTime[i];
                  else if(tfIdx == 1) g_lastMSSNotify1 = chartTime[i];
                  else g_lastMSSNotify2 = chartTime[i];

                  string tfStr2 = EnumToString(Period());
                  StringReplace(tfStr2, "PERIOD_", "");
                  for(int m = 0; m < mssCount; m++)
                  {
                     string mssMsg = StringFormat("[%s] %s %s | %s",
                        _Symbol, mssTypes[m], tfName, tfStr2);
                     Alert(mssMsg);
                     if(InpPushNotify)
                        SendNotification(mssMsg);
                     Print("FAD APEX MSS: ", mssMsg);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < InpEMA8 + 10) return(0);

   int start = (prev_calculated == 0) ? 0 : prev_calculated - 1;
   bool fullRecalc = (prev_calculated == 0);
   bool newBar = (prev_calculated > 0 && prev_calculated < rates_total);

   //=== Phase 1: Copy EMA data ===
   ArraySetAsSeries(g_ed0, false); ArraySetAsSeries(g_ed1, false);
   ArraySetAsSeries(g_ed2, false); ArraySetAsSeries(g_ed3, false);
   ArraySetAsSeries(g_ed4, false); ArraySetAsSeries(g_ed5, false);
   ArraySetAsSeries(g_ed6, false); ArraySetAsSeries(g_ed7, false);

   if(CopyBuffer(g_hEMA[0],0,0,rates_total,g_ed0)<rates_total) return(0);
   if(CopyBuffer(g_hEMA[1],0,0,rates_total,g_ed1)<rates_total) return(0);
   if(CopyBuffer(g_hEMA[2],0,0,rates_total,g_ed2)<rates_total) return(0);
   if(CopyBuffer(g_hEMA[3],0,0,rates_total,g_ed3)<rates_total) return(0);
   if(CopyBuffer(g_hEMA[4],0,0,rates_total,g_ed4)<rates_total) return(0);
   if(CopyBuffer(g_hEMA[5],0,0,rates_total,g_ed5)<rates_total) return(0);
   if(CopyBuffer(g_hEMA[6],0,0,rates_total,g_ed6)<rates_total) return(0);
   if(CopyBuffer(g_hEMA[7],0,0,rates_total,g_ed7)<rates_total) return(0);

   //=== Phase 1b: Fill ribbon + candle buffers ===
   for(int i = start; i < rates_total; i++)
   {
      double e1=g_ed0[i], e2=g_ed1[i], e3=g_ed2[i], e4=g_ed3[i];
      double e5=g_ed4[i], e6=g_ed5[i], e7=g_ed6[i], e8=g_ed7[i];

      if(g_showRibbon)
      {
         g_ema1[i]=e1;   g_ema2a[i]=e2;
         g_ema2b[i]=e2;  g_ema3a[i]=e3;
         g_ema3b[i]=e3;  g_ema4a[i]=e4;
         g_ema4b[i]=e4;  g_ema5a[i]=e5;
         g_ema5b[i]=e5;  g_ema6a[i]=e6;
         g_ema6b[i]=e6;  g_ema7a[i]=e7;
         g_ema7b[i]=e7;  g_ema8[i]=e8;
      }
      else
      {
         g_ema1[i]=EMPTY_VALUE;  g_ema2a[i]=EMPTY_VALUE;
         g_ema2b[i]=EMPTY_VALUE; g_ema3a[i]=EMPTY_VALUE;
         g_ema3b[i]=EMPTY_VALUE; g_ema4a[i]=EMPTY_VALUE;
         g_ema4b[i]=EMPTY_VALUE; g_ema5a[i]=EMPTY_VALUE;
         g_ema5b[i]=EMPTY_VALUE; g_ema6a[i]=EMPTY_VALUE;
         g_ema6b[i]=EMPTY_VALUE; g_ema7a[i]=EMPTY_VALUE;
         g_ema7b[i]=EMPTY_VALUE; g_ema8[i]=EMPTY_VALUE;
      }

      g_candleO[i]=open[i];
      g_candleH[i]=high[i];
      g_candleL[i]=low[i];
      g_candleC[i]=close[i];
      if(e1 > e8)      g_candleClr[i] = 0.0;
      else if(e1 < e8) g_candleClr[i] = 1.0;
      else              g_candleClr[i] = 2.0;
   }

   //=== Phase 2-4: MTF Structure + Signals (on full recalc or new bar) ===
   if(fullRecalc || newBar)
   {
      // Clear all signal buffers
      ArrayInitialize(g_bullSignal, EMPTY_VALUE);
      ArrayInitialize(g_bearSignal, EMPTY_VALUE);

      if(fullRecalc)
      {
         ObjectsDeleteAll(0, g_prefix);
         g_hiLvlCnt = 0;
         g_loLvlCnt = 0;
         ArrayResize(g_hiNames, 0);
         ArrayResize(g_loNames, 0);
         // Reset SMC state on full recalc (objects already deleted above)
         g_liqCnt   = 0;
         g_obCnt    = 0;
         g_fvgCnt   = 0;
         g_tpsetCnt = 0;
         g_lastChoChBull = 0;
         g_lastChoChBear = 0;
         g_lastPreSigTime = 0;
         g_lastPreSigDir  = 0;
         // Re-create UI after ObjectsDeleteAll
         CreateUI();
         CreateWatermark();
         CreateMSSPanel();
         CreateTrendPanel();
         CreateToggleButtons();
         EnforcePanelVisibility();
      }

      // Resize per-bar trend arrays
      ArrayResize(g_barTrend0, rates_total);
      ArrayResize(g_barTrend1, rates_total);
      ArrayResize(g_barTrend2, rates_total);
      ArrayInitialize(g_barTrend0, 0.0);
      ArrayInitialize(g_barTrend1, 0.0);
      ArrayInitialize(g_barTrend2, 0.0);

      //=== Phase 2: Process each HTF for BOS/MSS ===
      int lb = InpSwingLookback;

      if(InpShow5min)
         ProcessHTF(0, lb, time, high, low, rates_total,
                    fullRecalc, g_barTrend0);
      if(InpShow15min)
         ProcessHTF(1, lb, time, high, low, rates_total,
                    fullRecalc, g_barTrend1);
      if(InpShow1H)
         ProcessHTF(2, lb, time, high, low, rates_total,
                    fullRecalc, g_barTrend2);

      //=== Phase 3: BULL/BEAR signals with S/A/B ranking + range filter ===
      int prevMaster = 0;
      int startSig = InpEMA8 + 10;
      int lastSignalBar = -9999;  // Anti-whipsaw: track last signal bar
      int lastExitBar   = -9999;  // EXIT cooldown tracker

      // Get ADX + ATR buffers for range filter
      double adxBuf[];
      double atrBuf[];
      ArraySetAsSeries(adxBuf, false);
      ArraySetAsSeries(atrBuf, false);
      int adxCopied = CopyBuffer(g_hADX, 0, 0, rates_total, adxBuf);
      int atrCopied = CopyBuffer(g_hChartATR, 0, 0, rates_total, atrBuf);

      //=== SMC detectors: run once per OnCalculate on last closed bar ===
      double atrNow = (atrCopied > rates_total - 2 && rates_total - 2 >= 0)
                      ? atrBuf[rates_total - 2] : 0.0;
      DetectLiquiditySweeps(high, low, open, close, time, rates_total);
      UpdateOrderBlocks    (high, low, open, close, time, atrNow, rates_total);
      DetectFVG            (high, low, time, rates_total);
      DetectChoCh          (high, low, close, time, rates_total);
      DetectPreSignal      (g_ed7, close, time, rates_total);
      TPSet_Update         (high, low, time, rates_total);

      for(int i = startSig; i < rates_total; i++)
      {
         int buCnt = 0, beCnt = 0;
         if((int)g_barTrend0[i] == 1)  buCnt++;
         if((int)g_barTrend0[i] == -1) beCnt++;
         if((int)g_barTrend1[i] == 1)  buCnt++;
         if((int)g_barTrend1[i] == -1) beCnt++;
         if((int)g_barTrend2[i] == 1)  buCnt++;
         if((int)g_barTrend2[i] == -1) beCnt++;

         bool rBull = (g_ed0[i] > g_ed7[i]);
         bool aBull = (buCnt >= InpTrendConfirm) && rBull;
         bool aBear = (beCnt >= InpTrendConfirm) && !rBull;

         int nT;
         if(aBull) nT = 1;
         else if(aBear) nT = -1;
         else nT = prevMaster;

         // --- Range Filter: 3-layer check ---
         bool passRange = true;

         // Filter 1: ADX threshold — low ADX = ranging market
         if(adxCopied > i && adxBuf[i] < g_effAdxThreshold)
            passRange = false;

         // Filter 2: Ribbon width vs ATR — narrow ribbon = chop
         if(atrCopied > i && atrBuf[i] > 0)
         {
            double ribbonW = MathAbs(g_ed0[i] - g_ed7[i]);
            if(ribbonW < atrBuf[i] * InpRibbonATR)
               passRange = false;
         }

         // Filter 3: Anti-whipsaw cooldown — prevent rapid flipping
         if((i - lastSignalBar) < InpCooldownBars)
            passRange = false;

         // --- Signal scoring (S/A/B rank) ---
         if(passRange && ((nT == 1 && prevMaster != 1) || (nT == -1 && prevMaster != -1)))
         {
            int score = 0;
            bool isBull = (nT == 1);

            // Factor 1: All 3 TFs aligned
            if(isBull && buCnt == 3) score++;
            if(!isBull && beCnt == 3) score++;

            // Factor 2: Perfect EMA order
            bool perfOrder;
            if(isBull)
               perfOrder = g_ed0[i]>g_ed1[i] && g_ed1[i]>g_ed2[i] && g_ed2[i]>g_ed3[i]
                        && g_ed3[i]>g_ed4[i] && g_ed4[i]>g_ed5[i] && g_ed5[i]>g_ed6[i]
                        && g_ed6[i]>g_ed7[i];
            else
               perfOrder = g_ed0[i]<g_ed1[i] && g_ed1[i]<g_ed2[i] && g_ed2[i]<g_ed3[i]
                        && g_ed3[i]<g_ed4[i] && g_ed4[i]<g_ed5[i] && g_ed5[i]<g_ed6[i]
                        && g_ed6[i]<g_ed7[i];
            if(perfOrder) score++;

            // Factor 3: Candle momentum (body > 1.3x avg of last 20)
            double bodySize = MathAbs(close[i] - open[i]);
            double avgBody = 0;
            int mLook = MathMin(20, i - startSig);
            if(mLook > 0)
            {
               for(int j = i - mLook; j < i; j++)
                  avgBody += MathAbs(close[j] - open[j]);
               avgBody /= mLook;
            }
            if(avgBody > 0 && bodySize > avgBody * 1.3) score++;

            // Factor 4: Ribbon squeeze expansion
            double curWidth = MathAbs(g_ed0[i] - g_ed7[i]);
            double minW = curWidth;
            int sqLook = MathMin(10, i - startSig);
            for(int j = i - sqLook; j < i; j++)
               minW = MathMin(minW, MathAbs(g_ed0[j] - g_ed7[j]));
            if(curWidth > 0 && minW < curWidth * 0.5) score++;

            // --- SMC Confluence boost (live bar only) ---
            // Apply bonus ONLY to the last closed bar so historical signal count
            // is unchanged; current bar gets score boost for rank uplift.
            int smcBonus = 0;
            if(i >= rates_total - 2)
               smcBonus = SMCConfluenceBonus(isBull ? +1 : -1, close[i], time[i]);
            // Convert bonus to score uplift: +2 smcBonus -> +1 score, capped at +2
            int scoreBoost = (smcBonus >= 5) ? 2 : (smcBonus >= 3) ? 1 : 0;
            score += scoreBoost;
            if(score > 4) score = 4;

            // Rank: S(3-4), A(2), B(0-1) — all ranks show dot + text

            // --- ONNX AI win-rate prediction (Layer 1) ---
            int rg = DetectRegime((atrCopied > i) ? atrBuf[i] : 0, atrBuf, atrCopied, i);
            double aiProb = -1.0;
            int aiPct = -1;
            if(g_aiEnabled)
            {
               float feat[];
               ExtractAIFeatures(feat, i, isBull, score, close[i], open[i],
                                 atrBuf, atrCopied, adxBuf, adxCopied,
                                 rg, time[i], lastSignalBar);
               aiProb = PredictWinRate(feat);
               if(aiProb >= 0.0) aiPct = (int)MathRound(aiProb * 100.0);
            }
            // Filter signals below min AI win rate: suppress drawing + logging
            bool aiSuppress = (InpAIMinWinRate > 0 && aiPct >= 0 && aiPct < InpAIMinWinRate);
            string aiSfx = (InpAIShowScore && aiPct >= 0) ? (" " + IntegerToString(aiPct) + "%") : "";

            if(aiSuppress) { /* skip draw/log, but still update trend below */ }
            else if(isBull)
            {
               g_bullSignal[i] = low[i];
               color dotC = DeriveRankColor(InpBullColor, score);
               int dotSz = (score >= 3) ? 32 : (score == 2) ? 28 : 24;
               int txtSz = (score >= 3) ? 12 : (score == 2) ? 10 : 9;
               CreateSignalDot("DotBull" + IntegerToString(i),
                  time[i], low[i], dotC, false, dotSz);
               string bTxt = (score >= 3) ? "BULL S \x2605" : (score == 2) ? "BULL A" : "BULL B";
               bTxt += aiSfx;
               double lblOfs = (atrCopied > i && atrBuf[i] > 0) ? atrBuf[i] * 0.5 : 0;
               CreateSignalLabel("SigBull" + IntegerToString(i),
                  time[i], low[i] - lblOfs, bTxt, dotC, false, txtSz);
               // AI self-learning: log this signal
               LogSignal(time[i], true, score, rg, close[i]);
               // Dynamic SL/TP lines (only for live/last-closed bar to avoid clutter)
               if(i >= rates_total - 2)
                  TPSet_Create(time[i], i, +1, close[i],
                               (atrCopied > i) ? atrBuf[i] : 0.0);
            }
            else
            {
               g_bearSignal[i] = high[i];
               color dotC = DeriveRankColor(InpBearColor, score);
               int dotSz = (score >= 3) ? 32 : (score == 2) ? 28 : 24;
               int txtSz = (score >= 3) ? 12 : (score == 2) ? 10 : 9;
               CreateSignalDot("DotBear" + IntegerToString(i),
                  time[i], high[i], dotC, true, dotSz);
               string bTxt = (score >= 3) ? "BEAR S \x2605" : (score == 2) ? "BEAR A" : "BEAR B";
               bTxt += aiSfx;
               double lblOfs = (atrCopied > i && atrBuf[i] > 0) ? atrBuf[i] * 0.5 : 0;
               CreateSignalLabel("SigBear" + IntegerToString(i),
                  time[i], high[i] + lblOfs, bTxt, dotC, true, txtSz);
               // AI self-learning: log this signal
               LogSignal(time[i], false, score, rg, close[i]);
               // Dynamic SL/TP lines (only for live/last-closed bar to avoid clutter)
               if(i >= rates_total - 2)
                  TPSet_Create(time[i], i, -1, close[i],
                               (atrCopied > i) ? atrBuf[i] : 0.0);
            }

            if(!aiSuppress)
            {
               lastSignalBar = i;  // Update anti-whipsaw tracker
               lastExitBar = -9999;  // Reset exit tracker on new entry signal

               // Alert on latest bar
               if(i == rates_total - 1 && prev_calculated > 0 && time[i] > g_lastNotifyTime)
               {
                  g_lastNotifyTime = time[i];
                  string rank = (score >= 3) ? "S" : (score == 2) ? "A" : "B";
                  SendSignalAlert(isBull ? "BULL " + rank : "BEAR " + rank, close[i]);
               }
            }
         }

         //=== EXIT take-profit signal: momentum exhaustion detection ===
         if(InpShowExits && prevMaster != 0 && (i - lastSignalBar) > 3
            && (i - lastExitBar) >= InpCooldownBars)
         {
            bool isBullPos = (prevMaster == 1);
            int exitScore = CalcExitScore(isBullPos, i, rates_total,
                                          close, open, high, low, tick_volume,
                                          adxBuf, adxCopied, atrBuf, atrCopied);
            if(exitScore >= g_effExitThreshold)
            {
               lastExitBar = i;
               bool isStrong = (exitScore >= 65);
               color exitC = isStrong ? C'255,140,0' : C'255,200,50';
               int eSz = isStrong ? 28 : 22;
               int eTxtSz = isStrong ? 12 : 10;
               string eTxt = isStrong ? "EXIT \x2605" : "EXIT";

               double lblOfs = (atrCopied > i && atrBuf[i] > 0) ? atrBuf[i] * 0.5 : 0;
               if(isBullPos)
               {
                  // Exit long: marker above price
                  CreateSignalDot("DotExit" + IntegerToString(i),
                     time[i], high[i], exitC, true, eSz);
                  CreateSignalLabel("SigExit" + IntegerToString(i),
                     time[i], high[i] + lblOfs, eTxt, exitC, true, eTxtSz);
               }
               else
               {
                  // Exit short: marker below price
                  CreateSignalDot("DotExit" + IntegerToString(i),
                     time[i], low[i], exitC, false, eSz);
                  CreateSignalLabel("SigExit" + IntegerToString(i),
                     time[i], low[i] - lblOfs, eTxt, exitC, false, eTxtSz);
               }

               // EXIT push notification (latest bar only, M15/H1)
               if(i == rates_total - 1 && prev_calculated > 0 && time[i] > g_lastExitNotify)
               {
                  g_lastExitNotify = time[i];
                  string tfStr = EnumToString(Period());
                  StringReplace(tfStr, "PERIOD_", "");
                  string exitMsg = StringFormat("[%s] %s %s @ %s | %s",
                     _Symbol, eTxt, isBullPos ? "LONG TP" : "SHORT TP",
                     DoubleToString(close[i], _Digits), tfStr);
                  if(InpAlertSound) PlaySound("alert.wav");
                  Alert(exitMsg);
                  if(InpPushNotify)
                     SendNotification(exitMsg);
                  Print("FAD APEX EXIT: ", exitMsg);
               }
            }
         }

         // Only update master trend when signal actually fires or no transition
         // If range filter blocked a transition, keep prevMaster so signal retries later
         bool isTransition = (nT == 1 && prevMaster != 1) || (nT == -1 && prevMaster != -1);
         if(!isTransition || passRange)
            prevMaster = nT;
      }
      g_masterTrend = prevMaster;

      // Update MSS Score Panel + Trend Status Panel (moved to outside block below)

      //=== Phase 4: Key Levels ===
      if(InpShowLevels && fullRecalc)
      {
         int lastBar = rates_total - 1;
         int keyStart = MathMax(lb, lastBar - 500);

         for(int i = keyStart; i <= lastBar - lb; i++)
         {
            double cPH = FindPivotHigh(high, i, lb, lb, rates_total);
            double cPL = FindPivotLow(low, i, lb, lb, rates_total);

            if(cPH > 0.0)
            {
               datetime t1 = time[i];
               int ei = i + InpLevelExtend;
               datetime t2;
               if(ei <= lastBar) t2 = time[ei];
               else t2 = time[lastBar] + (datetime)((ei - lastBar) * PeriodSeconds());
               MakeKeyLevel(true, cPH, t1, t2);
            }
            if(cPL > 0.0)
            {
               datetime t1 = time[i];
               int ei = i + InpLevelExtend;
               datetime t2;
               if(ei <= lastBar) t2 = time[ei];
               else t2 = time[lastBar] + (datetime)((ei - lastBar) * PeriodSeconds());
               MakeKeyLevel(false, cPL, t1, t2);
            }
         }
      }

      ChartRedraw();
   }

   // Update MSS Score Panel + Trend Status Panel — EVERY TICK (outside fullRecalc||newBar)
   if(rates_total > 0)
   {
      int lastIdx = rates_total - 1;
      UpdateMSSPanel((int)g_barTrend0[lastIdx],
                     (int)g_barTrend1[lastIdx],
                     (int)g_barTrend2[lastIdx],
                     close, open, high, low, tick_volume,
                     lastIdx, rates_total);
      UpdateTrendPanel();
   }

   //=== AI Self-Learning (Layer 2): evaluate pending signals on new bar ===
   if(InpSelfLearn && (fullRecalc || newBar))
   {
      EvaluatePendingSignals(high, low, time, rates_total);
      RecomputeStats();
      UpdateEffectiveThresholds();
      if(g_signalLogDirty) SaveSignalLog();
      UpdateAIPanel();
   }

   EnforcePanelVisibility();

   return(rates_total);
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      CreateWatermark();
      CreateMSSPanel();
      CreateTrendPanel();
      CreateToggleButtons();
      if(g_showAI && InpShowAIPanel)
      {
         CreateAIPanel();
         UpdateAIPanel();
      }
      EnforcePanelVisibility();
      return;
   }

   if(id != CHARTEVENT_OBJECT_CLICK) return;

   // MSS panel toggle
   if(sparam == g_prefix+"TogMSS")
   {
      g_showMSS = !g_showMSS;
      if(!g_showMSS) DeleteMSSPanelObjects();
      else           CreateMSSPanel();
      // Update button appearance WITHOUT delete/recreate
      UpdateToggleButtons();
      ChartRedraw();
      return;
   }

   // Trend panel toggle
   if(sparam == g_prefix+"TogTrend")
   {
      g_showTrend = !g_showTrend;
      if(!g_showTrend) DeleteTrendPanelObjects();
      else             CreateTrendPanel();
      // Update button appearance WITHOUT delete/recreate
      UpdateToggleButtons();
      ChartRedraw();
      return;
   }

   // Ribbon (EMA) toggle
   if(sparam == g_prefix+"TogRibbon")
   {
      g_showRibbon = !g_showRibbon;
      ApplyRibbonVisibility();
      UpdateToggleButtons();
      ChartRedraw();
      return;
   }

   // AI Stats panel toggle
   if(sparam == g_prefix+"TogAI")
   {
      g_showAI = !g_showAI;
      if(!g_showAI || !InpShowAIPanel) DeleteAIPanelObjects();
      else { CreateAIPanel(); UpdateAIPanel(); }
      UpdateToggleButtons();
      ChartRedraw();
      return;
   }

   // AI Reset button
   if(sparam == g_prefix+"BtnAIRst")
   {
      ResetAILearning();
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ChartRedraw();
      return;
   }

   if(sparam == g_prefix+"BtnM1")
   { ChartSetSymbolPeriod(0, _Symbol, PERIOD_M1);  ObjectSetInteger(0, sparam, OBJPROP_STATE, false); }
   else if(sparam == g_prefix+"BtnM5")
   { ChartSetSymbolPeriod(0, _Symbol, PERIOD_M5);  ObjectSetInteger(0, sparam, OBJPROP_STATE, false); }
   else if(sparam == g_prefix+"BtnM15")
   { ChartSetSymbolPeriod(0, _Symbol, PERIOD_M15); ObjectSetInteger(0, sparam, OBJPROP_STATE, false); }
   else if(sparam == g_prefix+"BtnH1")
   { ChartSetSymbolPeriod(0, _Symbol, PERIOD_H1);  ObjectSetInteger(0, sparam, OBJPROP_STATE, false); }
   else if(sparam == g_prefix+"BtnH4")
   { ChartSetSymbolPeriod(0, _Symbol, PERIOD_H4);  ObjectSetInteger(0, sparam, OBJPROP_STATE, false); }
   else if(sparam == g_prefix+"BtnD1")
   { ChartSetSymbolPeriod(0, _Symbol, PERIOD_D1);  ObjectSetInteger(0, sparam, OBJPROP_STATE, false); }
}
//+------------------------------------------------------------------+
