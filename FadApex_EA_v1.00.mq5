//+------------------------------------------------------------------+
//| FadApex EA v1.10 - Gold M1 Asymmetric Runner                     |
//| Strategy: Tiny losses, big winners (let profits run)             |
//| Quality-only entries: S-rank with pullback + momentum confirm    |
//| Exit: swing-SL, multi-stage trailing, partial 30% at 2R          |
//+------------------------------------------------------------------+
#property copyright "FadApex EA"
#property version   "1.10"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

CTrade        g_trade;
CPositionInfo g_pos;

//=== INPUTS: Trading ===
input group "=== Trading ==="
input long   InpMagic        = 462010;
input double InpRiskPercent  = 0.3;       // Risk per trade (%) - smaller for survival
input int    InpMaxSlippage  = 30;        // Max slippage in points
input int    InpMaxSpreadPts = 200;       // Max spread (Gold: 200pts) - stricter

//=== INPUTS: Risk Management ===
input group "=== Risk Management ==="
input double InpMaxDailyDD     = 2.0;     // Max daily drawdown (%)
input int    InpMaxConsecLoss  = 3;       // Max consecutive losses before cooldown
input int    InpCooldownHours  = 8;       // Cooldown duration (hours)
input bool   InpFridayFlat     = true;    // Close all positions Friday end

//=== INPUTS: Entry Quality (Asymmetric Runner) ===
input group "=== Entry Quality ==="
input bool   InpEntryRankS    = true;     // Trade Rank S signals (score >= 3)
input bool   InpEntryRankA    = false;    // Trade Rank A signals (score 2) - DEFAULT OFF
input bool   InpEntryRankB    = false;    // Trade Rank B signals (score <= 1)
input int    InpMinADX        = 28;       // Min ADX (28 = strong trend)
input int    InpMinATRPoints  = 400;      // Min ATR (40 pips on Gold)
input bool   InpRequirePullback = true;   // Require pullback + bounce pattern
input int    InpPullbackBars    = 8;      // Lookback for pullback detection
input double InpMaxDistFromEMA  = 1.5;    // Max ATR-distance from EMA21 at entry
input bool   InpRequireMomentumCandle = true; // Strong close in trend direction
input bool   InpRequireVolumeBoost    = true; // Volume above 20-bar avg

//=== INPUTS: SL/TP (Asymmetric: tight SL, runner TP) ===
input group "=== SL/TP (Asymmetric) ==="
input bool   InpUseSwingSL     = true;    // Use swing-point SL (tighter, structural)
input int    InpSwingSLBars    = 5;       // Look back N bars for swing low/high
input double InpSwingSLBufATR  = 0.3;     // Buffer beyond swing = ATR x this
input double InpSLAtrMult      = 1.0;     // Fallback SL = ATR x this (was 1.5)
input double InpTP1RR          = 2.0;     // TP1 = R x this (close 30%)
input int    InpTP1ClosePct    = 30;      // % closed at TP1 (was 50)
input double InpTP2RR          = 6.0;     // Hard TP2 ceiling = R x this
input bool   InpUseTrailing    = true;    // Multi-stage trailing
input double InpTrailStartRR   = 2.0;     // Start trailing after this RR
input double InpTrailDistRR    = 1.2;     // Trail distance = R x this (initial)
input double InpTightTrailRR   = 4.0;     // Tighter trail after this profit (RR)
input double InpTightTrailDist = 0.7;     // Tight trail distance = R x this
input int    InpMinSLPoints    = 250;     // Min SL distance (25 pips)
input int    InpMaxSLPoints    = 1500;    // Max SL distance (150 pips)

//=== INPUTS: Time Filter ===
input group "=== Time Filter ==="
input bool   InpUseTimeFilter = true;     // Use time filter
input int    InpStartHour     = 14;       // Trading start (server time, GMT+2/+3 for XM)
input int    InpEndHour       = 20;       // Trading end (avoid late thin liquidity)
input bool   InpAvoidNewsHour = true;     // Skip first 5 min of each hour

//=== INPUTS: Exit Rules ===
input group "=== Exit Rules ==="
input bool   InpExitOnReverse  = true;    // Close on opposite S-rank signal only
input bool   InpExitOnSignal   = true;    // Close on EXIT signal
input int    InpMaxBarsInTrade = 120;     // Force close after N bars (2hrs M1)

//=== INPUTS: Indicator Params ===
input group "=== Signal Logic (v4.62) ==="
input int    InpEMA1   = 5;
input int    InpEMA2   = 8;
input int    InpEMA3   = 13;
input int    InpEMA4   = 21;
input int    InpEMA5   = 34;
input int    InpEMA6   = 55;
input int    InpEMA7   = 89;
input int    InpEMA8   = 144;
input int    InpSwingLB        = 10;
input int    InpADXPeriod      = 14;
input int    InpATRPeriod      = 14;
input double InpRibbonATRRatio = 0.8;
input int    InpCooldownBars   = 8;
input int    InpExitThreshold  = 45;
input int    InpTrendConfirm   = 1;

//=== GLOBALS ===
int g_hEMA[8];
int g_hATR;
int g_hADX;

ENUM_TIMEFRAMES g_mtfTF[3];

datetime g_lastBarTime       = 0;
datetime g_dailyDate         = 0;
double   g_dailyStartBalance = 0;
int      g_consecLosses      = 0;
datetime g_cooldownEnd       = 0;
ulong    g_lastClosedTicket  = 0;

// Trade state
ulong    g_currentTicket = 0;
bool     g_currentBull   = false;
bool     g_tp1Hit        = false;
double   g_entryPrice    = 0;
double   g_initialSL     = 0;
double   g_atrAtEntry    = 0;
double   g_initialRiskPts = 0;          // Distance entry->SL in points (for RR calc)
datetime g_entryBarTime  = 0;           // For max-bars-in-trade timeout
bool     g_tightTrailOn  = false;       // Stage-2 trailing engaged

//=== Signal info struct ===
struct SignalResult
{
   int direction;     // 1=BULL, -1=BEAR, 0=none
   int score;         // 0-4
   string rank;       // "S", "A", "B"
   bool hasExit;
   int exitScore;     // 0-100
   bool qualityPass;  // Passed pullback / momentum / volume filter
   double swingSL;    // Swing-based SL price (0 if N/A)
   double atrAtSig;   // ATR at signal bar
};

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(InpMaxSlippage);
   g_trade.SetTypeFillingBySymbol(_Symbol);

   g_mtfTF[0] = PERIOD_M5;
   g_mtfTF[1] = PERIOD_M15;
   g_mtfTF[2] = PERIOD_H1;

   int lens[8];
   lens[0]=InpEMA1; lens[1]=InpEMA2; lens[2]=InpEMA3; lens[3]=InpEMA4;
   lens[4]=InpEMA5; lens[5]=InpEMA6; lens[6]=InpEMA7; lens[7]=InpEMA8;

   for(int i = 0; i < 8; i++)
   {
      g_hEMA[i] = iMA(_Symbol, PERIOD_CURRENT, lens[i], 0, MODE_EMA, PRICE_CLOSE);
      if(g_hEMA[i] == INVALID_HANDLE)
      {
         Print("Failed to create EMA handle ", i);
         return(INIT_FAILED);
      }
   }
   g_hATR = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   g_hADX = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);
   if(g_hATR == INVALID_HANDLE || g_hADX == INVALID_HANDLE)
   {
      Print("Failed to create ATR/ADX handle");
      return(INIT_FAILED);
   }

   g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dailyDate         = TimeToDate(TimeCurrent());
   g_lastBarTime       = iTime(_Symbol, PERIOD_CURRENT, 0);

   // Reattach existing position state if any
   ScanExistingPosition();

   Print("FadApex EA v1.00 initialized | Symbol: ", _Symbol,
         " | Magic: ", InpMagic, " | Risk: ", InpRiskPercent, "%");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i = 0; i < 8; i++)
      if(g_hEMA[i] != INVALID_HANDLE) IndicatorRelease(g_hEMA[i]);
   if(g_hATR != INVALID_HANDLE) IndicatorRelease(g_hATR);
   if(g_hADX != INVALID_HANDLE) IndicatorRelease(g_hADX);
}

//+------------------------------------------------------------------+
//| Helpers                                                           |
//+------------------------------------------------------------------+
datetime TimeToDate(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);
   st.hour = 0; st.min = 0; st.sec = 0;
   return StructToTime(st);
}

void ScanExistingPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i)
         && g_pos.Symbol() == _Symbol
         && g_pos.Magic()  == InpMagic)
      {
         g_currentTicket = g_pos.Ticket();
         g_currentBull   = (g_pos.PositionType() == POSITION_TYPE_BUY);
         g_entryPrice    = g_pos.PriceOpen();
         g_initialSL     = g_pos.StopLoss();
         // EA restart: skip TP1 partial (assume already done or skip safely)
         g_tp1Hit        = true;
         g_tightTrailOn  = true;  // Conservative: assume already in advanced trail
         g_entryBarTime  = (datetime)g_pos.Time();
         // Initial risk = distance from entry to current SL
         double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(g_initialSL > 0 && pt > 0)
            g_initialRiskPts = MathAbs(g_entryPrice - g_initialSL) / pt;
         else
            g_initialRiskPts = 0;
         // Use current ATR as fallback for trailing distance
         double atrArr[];
         if(CopyBuffer(g_hATR, 0, 1, 1, atrArr) == 1)
            g_atrAtEntry = atrArr[0];
         else
            g_atrAtEntry = 0;
         Print("Reattached existing position ticket=", g_currentTicket,
               " bull=", g_currentBull, " ATR=", g_atrAtEntry,
               " RiskPts=", g_initialRiskPts);
         return;
      }
   }
   g_currentTicket = 0;
}

double FindPivotHigh(const double &a[], int bar, int lb, int rb, int sz)
{
   if(bar - lb < 0 || bar + rb >= sz) return(0.0);
   double v = a[bar];
   for(int i = 1; i <= lb; i++) if(a[bar - i] >= v) return(0.0);
   for(int i = 1; i <= rb; i++) if(a[bar + i] >  v) return(0.0);
   return v;
}

double FindPivotLow(const double &a[], int bar, int lb, int rb, int sz)
{
   if(bar - lb < 0 || bar + rb >= sz) return(0.0);
   double v = a[bar];
   for(int i = 1; i <= lb; i++) if(a[bar - i] <= v) return(0.0);
   for(int i = 1; i <= rb; i++) if(a[bar + i] <  v) return(0.0);
   return v;
}

int FindHTFIdxByCutoff(const datetime &t[], int total, datetime cutoff)
{
   for(int j = total - 1; j >= 0; j--) if(t[j] <= cutoff) return j;
   return 0;
}

//+------------------------------------------------------------------+
//| Compute HTF trend ARRAY (per chart bar) — needed for replay      |
//+------------------------------------------------------------------+
bool ComputeHTFTrendArray(int tfIdx, int chartTotal,
                          const datetime &chartTime[],
                          double &outTrend[])
{
   ArrayResize(outTrend, chartTotal);
   ArrayInitialize(outTrend, 0.0);

   ENUM_TIMEFRAMES period = g_mtfTF[tfIdx];
   int need = 1500;

   double htfH[], htfL[], htfC[];
   datetime htfT[];
   ArraySetAsSeries(htfH, false); ArraySetAsSeries(htfL, false);
   ArraySetAsSeries(htfC, false); ArraySetAsSeries(htfT, false);

   int cntH = CopyHigh(_Symbol, period, 0, need, htfH);
   int cntL = CopyLow(_Symbol, period, 0, need, htfL);
   int cntC = CopyClose(_Symbol, period, 0, need, htfC);
   int cntT = CopyTime(_Symbol, period, 0, need, htfT);
   int cnt  = MathMin(MathMin(cntH, cntL), MathMin(cntC, cntT));
   int lb   = InpSwingLB;
   if(cnt < 2 * lb + 2) return false;

   double htfPH[], htfPL[];
   ArrayResize(htfPH, cnt); ArrayResize(htfPL, cnt);
   for(int j = 0; j < cnt; j++)
   {
      if(j >= 2 * lb)
      {
         htfPH[j] = FindPivotHigh(htfH, j - lb, lb, lb, cnt);
         htfPL[j] = FindPivotLow(htfL,  j - lb, lb, lb, cnt);
      }
      else { htfPH[j] = 0.0; htfPL[j] = 0.0; }
   }

   double prevSH=0, prevSL=0, lastSH=0, lastSL=0;
   double prevMappedClose=0, prevLastSH=0, prevLastSL=0;
   int prevMappedIdx = -1;
   int trend = 0;
   int chartPeriod = PeriodSeconds(PERIOD_CURRENT);
   int htfPeriod   = PeriodSeconds(period);

   for(int i = 0; i < chartTotal; i++)
   {
      datetime chartClose = chartTime[i] + (datetime)chartPeriod;
      datetime cutoff = chartClose - (datetime)htfPeriod;
      if(i == chartTotal - 1 && chartPeriod <= htfPeriod)
         cutoff -= 1;
      int htfIdx = FindHTFIdxByCutoff(htfT, cnt, cutoff);

      if(htfIdx > prevMappedIdx)
      {
         int startK = (prevMappedIdx >= 0) ? prevMappedIdx + 1 : 0;
         for(int k = startK; k <= htfIdx; k++)
         {
            if(htfPH[k] > 0.0) { prevSH = lastSH; lastSH = htfPH[k]; }
            if(htfPL[k] > 0.0) { prevSL = lastSL; lastSL = htfPL[k]; }
         }
      }

      if(lastSH > 0 && prevSH > 0 && lastSL > 0 && prevSL > 0)
      {
         int s = 0;
         if(lastSH > prevSH) s++;
         if(lastSH < prevSH) s--;
         if(lastSL > prevSL) s++;
         if(lastSL < prevSL) s--;
         if(s > 0) trend = 1;
         else if(s < 0) trend = -1;
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

      double curClose = htfC[htfIdx];
      bool mBu=false, mBe=false;
      if(i > 0 && prevMappedClose > 0)
      {
         bool crossOverSH  = (lastSH > 0 && prevLastSH > 0
                              && curClose > lastSH && prevMappedClose <= prevLastSH);
         bool crossUnderSL = (lastSL > 0 && prevLastSL > 0
                              && curClose < lastSL && prevMappedClose >= prevLastSL);
         if(trend == -1 && crossOverSH)  mBu = true;
         if(trend ==  1 && crossUnderSL) mBe = true;
      }
      if(mBu) trend = 1;
      if(mBe) trend = -1;

      outTrend[i] = (double)trend;

      prevMappedClose = curClose;
      prevLastSH = lastSH;
      prevLastSL = lastSL;
      prevMappedIdx = htfIdx;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Compute signal at the latest CLOSED bar — full replay version     |
//+------------------------------------------------------------------+
SignalResult ComputeSignal()
{
   SignalResult sig;
   sig.direction = 0; sig.score = 0; sig.rank = "";
   sig.hasExit = false; sig.exitScore = 0;
   sig.qualityPass = false; sig.swingSL = 0; sig.atrAtSig = 0;

   int rates_total = Bars(_Symbol, PERIOD_CURRENT);
   int need = 600;
   if(rates_total < need) return sig;

   datetime time[]; double open[], high[], low[], close[];
   long tick_vol[];
   ArraySetAsSeries(time,false);  ArraySetAsSeries(open,false);
   ArraySetAsSeries(high,false);  ArraySetAsSeries(low,false);
   ArraySetAsSeries(close,false); ArraySetAsSeries(tick_vol,false);

   if(CopyTime(_Symbol,PERIOD_CURRENT,0,need,time) != need) return sig;
   if(CopyOpen(_Symbol,PERIOD_CURRENT,0,need,open) != need) return sig;
   if(CopyHigh(_Symbol,PERIOD_CURRENT,0,need,high) != need) return sig;
   if(CopyLow(_Symbol,PERIOD_CURRENT,0,need,low)  != need) return sig;
   if(CopyClose(_Symbol,PERIOD_CURRENT,0,need,close) != need) return sig;
   if(CopyTickVolume(_Symbol,PERIOD_CURRENT,0,need,tick_vol) != need) return sig;

   double e0[], e1[], e2[], e3[], e4[], e5[], e6[], e7[];
   ArraySetAsSeries(e0,false); ArraySetAsSeries(e1,false);
   ArraySetAsSeries(e2,false); ArraySetAsSeries(e3,false);
   ArraySetAsSeries(e4,false); ArraySetAsSeries(e5,false);
   ArraySetAsSeries(e6,false); ArraySetAsSeries(e7,false);
   if(CopyBuffer(g_hEMA[0],0,0,need,e0) != need) return sig;
   if(CopyBuffer(g_hEMA[1],0,0,need,e1) != need) return sig;
   if(CopyBuffer(g_hEMA[2],0,0,need,e2) != need) return sig;
   if(CopyBuffer(g_hEMA[3],0,0,need,e3) != need) return sig;
   if(CopyBuffer(g_hEMA[4],0,0,need,e4) != need) return sig;
   if(CopyBuffer(g_hEMA[5],0,0,need,e5) != need) return sig;
   if(CopyBuffer(g_hEMA[6],0,0,need,e6) != need) return sig;
   if(CopyBuffer(g_hEMA[7],0,0,need,e7) != need) return sig;

   double atrBuf[], adxBuf[];
   ArraySetAsSeries(atrBuf,false); ArraySetAsSeries(adxBuf,false);
   if(CopyBuffer(g_hATR,0,0,need,atrBuf) != need) return sig;
   if(CopyBuffer(g_hADX,0,0,need,adxBuf) != need) return sig;

   // Compute HTF trend arrays for all bars (one-time per signal call)
   double trend0[], trend1[], trend2[];
   if(!ComputeHTFTrendArray(0, need, time, trend0)) return sig;
   if(!ComputeHTFTrendArray(1, need, time, trend1)) return sig;
   if(!ComputeHTFTrendArray(2, need, time, trend2)) return sig;

   int idx = need - 2;  // Latest CLOSED bar

   // Replay prevMaster from a stable starting point
   int prevMaster    = 0;
   int lastSignalBar = -9999;
   int sigBarFinal   = -1;
   bool sigBullFinal = false;
   int  sigScoreFinal = 0;
   int startReplay = MathMax(InpEMA8 + 10, idx - 400);

   for(int i = startReplay; i <= idx; i++)
   {
      int t0 = (int)trend0[i];
      int t1 = (int)trend1[i];
      int t2 = (int)trend2[i];

      int buCnt = 0, beCnt = 0;
      if(t0 == 1)  buCnt++; if(t0 == -1) beCnt++;
      if(t1 == 1)  buCnt++; if(t1 == -1) beCnt++;
      if(t2 == 1)  buCnt++; if(t2 == -1) beCnt++;

      bool rBull = (e0[i] > e7[i]);
      bool aBull = (buCnt >= InpTrendConfirm) && rBull;
      bool aBear = (beCnt >= InpTrendConfirm) && !rBull;

      int nT;
      if(aBull) nT = 1;
      else if(aBear) nT = -1;
      else nT = prevMaster;

      // Range filter
      bool passRange = true;
      if(adxBuf[i] < InpMinADX) passRange = false;
      if(atrBuf[i] > 0)
      {
         double rW = MathAbs(e0[i] - e7[i]);
         if(rW < atrBuf[i] * InpRibbonATRRatio) passRange = false;
      }
      if((i - lastSignalBar) < InpCooldownBars) passRange = false;

      bool isTransition = (nT == 1 && prevMaster != 1) || (nT == -1 && prevMaster != -1);

      if(passRange && isTransition)
      {
         bool isBull = (nT == 1);
         int score = 0;

         // Factor 1: All 3 TFs aligned
         if(isBull && buCnt == 3)  score++;
         if(!isBull && beCnt == 3) score++;

         // Factor 2: Perfect EMA order
         bool perfOrder;
         if(isBull)
            perfOrder = e0[i]>e1[i] && e1[i]>e2[i] && e2[i]>e3[i]
                     && e3[i]>e4[i] && e4[i]>e5[i] && e5[i]>e6[i]
                     && e6[i]>e7[i];
         else
            perfOrder = e0[i]<e1[i] && e1[i]<e2[i] && e2[i]<e3[i]
                     && e3[i]<e4[i] && e4[i]<e5[i] && e5[i]<e6[i]
                     && e6[i]<e7[i];
         if(perfOrder) score++;

         // Factor 3: Candle momentum
         double bodySize = MathAbs(close[i] - open[i]);
         double avgBody = 0;
         int mLook = MathMin(20, i - startReplay);
         if(mLook > 0)
         {
            for(int j = i - mLook; j < i; j++) avgBody += MathAbs(close[j] - open[j]);
            avgBody /= mLook;
         }
         if(avgBody > 0 && bodySize > avgBody * 1.3) score++;

         // Factor 4: Ribbon squeeze expansion
         double curWidth = MathAbs(e0[i] - e7[i]);
         double minW = curWidth;
         int sqLook = MathMin(10, i - startReplay);
         for(int j = i - sqLook; j < i; j++)
            minW = MathMin(minW, MathAbs(e0[j] - e7[j]));
         if(curWidth > 0 && minW < curWidth * 0.5) score++;

         lastSignalBar = i;
         // Track only the LATEST signal bar
         sigBarFinal   = i;
         sigBullFinal  = isBull;
         sigScoreFinal = score;
      }

      // Update prevMaster (matches indicator logic)
      if(!isTransition || passRange)
         prevMaster = nT;
   }

   // Only fire if signal occurred on the latest bar (idx)
   if(sigBarFinal == idx)
   {
      sig.direction = sigBullFinal ? 1 : -1;
      sig.score     = sigScoreFinal;
      sig.rank      = (sigScoreFinal >= 3) ? "S" : (sigScoreFinal == 2) ? "A" : "B";
      sig.atrAtSig  = atrBuf[idx];
      // Quality filter (pullback + momentum + volume)
      sig.qualityPass = PassesQualityFilter(sigBullFinal, idx,
                                             open, high, low, close,
                                             tick_vol, e3, atrBuf);
      // Swing-based SL
      if(InpUseSwingSL)
         sig.swingSL = ComputeSwingSL(sigBullFinal, atrBuf[idx], high, low, idx);
   }

   // EXIT score (if position open)
   if(g_currentTicket != 0)
   {
      sig.exitScore = CalcExitScoreEA(g_currentBull, idx,
                                       e0, e7, close, open, high, low,
                                       tick_vol, atrBuf, adxBuf);
      sig.hasExit = (sig.exitScore >= InpExitThreshold);
   }
   return sig;
}

//+------------------------------------------------------------------+
//| EXIT score (port of v4.62 CalcExitScore)                         |
//+------------------------------------------------------------------+
int CalcExitScoreEA(bool isBullPos, int idx,
                    const double &e0[], const double &e7[],
                    const double &close[], const double &open[],
                    const double &high[], const double &low[],
                    const long &tickVol[], const double &atrBuf[],
                    const double &adxBuf[])
{
   double score = 0.0;
   if(idx < 22) return 0;

   // Layer 1: Price deviation from EMA (30pt)
   double ribbonW = MathAbs(e0[idx] - e7[idx]);
   if(atrBuf[idx] > 0 && ribbonW > 0)
   {
      double dev = isBullPos ? (close[idx] - e0[idx]) : (e0[idx] - close[idx]);
      double atrDev = dev / atrBuf[idx];
      if(atrDev > 1.5)      score += 30.0;
      else if(atrDev > 1.0)  score += 22.0;
      else if(atrDev > 0.6)  score += 15.0;
      else if(atrDev > 0.3)  score += 8.0;
   }

   // Layer 2: EMA slope reversal (25pt)
   double slopeNow  = e0[idx] - e0[idx - 2];
   double slopePrev = e0[idx - 2] - e0[idx - 4];
   if(isBullPos)
   {
      if(slopeNow <= 0)                                    score += 25.0;
      else if(slopePrev > 0 && slopeNow < slopePrev * 0.5) score += 18.0;
      else if(slopePrev > 0 && slopeNow < slopePrev * 0.8) score += 10.0;
   }
   else
   {
      if(slopeNow >= 0)                                    score += 25.0;
      else if(slopePrev < 0 && slopeNow > slopePrev * 0.5) score += 18.0;
      else if(slopePrev < 0 && slopeNow > slopePrev * 0.8) score += 10.0;
   }

   // Layer 3: ADX peak (20pt)
   double adxMax5 = 0;
   for(int j = idx - 4; j <= idx; j++) if(adxBuf[j] > adxMax5) adxMax5 = adxBuf[j];
   bool adx2dec = (adxBuf[idx] < adxBuf[idx-1] && adxBuf[idx-1] < adxBuf[idx-2]);
   bool adx1dec = (adxBuf[idx] < adxBuf[idx-1]);
   if(adxMax5 > 20.0 && adx2dec)         score += 20.0;
   else if(adxMax5 > 20.0 && adx1dec)     score += 12.0;
   else if(adxMax5 > 25.0 && adxBuf[idx] < adxMax5 * 0.85) score += 8.0;
   else if(adx2dec)                        score += 6.0;

   // Layer 4: Volume climax (15pt)
   double avgVol = 0;
   for(int j = idx - 20; j < idx; j++) avgVol += (double)tickVol[j];
   avgVol /= 20.0;
   if(avgVol > 0)
   {
      double v2 = (double)tickVol[idx - 2];
      double v1 = (double)tickVol[idx - 1];
      double v0 = (double)tickVol[idx];
      if(v2 > avgVol * 1.5 && v1 < v2 && v0 < v1)   score += 15.0;
      else if(v1 > avgVol * 1.3 && v0 < v1)          score += 10.0;
      else if(v0 < avgVol * 0.7 && v1 < avgVol * 0.8) score += 5.0;
   }

   // Layer 5: Candle rejection (10pt)
   double range = high[idx] - low[idx];
   double body  = MathAbs(close[idx] - open[idx]);
   if(range > 0)
   {
      if(isBullPos)
      {
         double upWick = high[idx] - MathMax(close[idx], open[idx]);
         if(upWick > range * 0.6)       score += 10.0;
         else if(body < range * 0.25)   score += 7.0;
      }
      else
      {
         double loWick = MathMin(close[idx], open[idx]) - low[idx];
         if(loWick > range * 0.6)       score += 10.0;
         else if(body < range * 0.25)   score += 7.0;
      }
   }
   return (int)MathMin(100.0, MathMax(0.0, score));
}

//+------------------------------------------------------------------+
//| Quality entry filter: pullback + momentum + volume                |
//| Returns true if entry passes ALL quality checks for direction.   |
//+------------------------------------------------------------------+
bool PassesQualityFilter(bool isBull, int idx,
                         const double &open[], const double &high[],
                         const double &low[],  const double &close[],
                         const long   &tickVol[],
                         const double &e3[],   // EMA21
                         const double &atrBuf[])
{
   if(idx < 25) return false;
   double atr = atrBuf[idx];
   if(atr <= 0) return false;

   // (1) Pullback: in last N bars, price must have come within 0.5*ATR of EMA21
   //     (proves we are not chasing an extended move)
   if(InpRequirePullback)
   {
      bool pulled = false;
      int lookback = MathMin(InpPullbackBars, idx);
      for(int j = idx - lookback; j <= idx; j++)
      {
         double dist;
         if(isBull) dist = low[j]  - e3[j];   // for buy, low approached EMA21
         else        dist = e3[j]  - high[j]; // for sell, high approached EMA21
         if(dist < atr * 0.5) { pulled = true; break; }
      }
      if(!pulled) return false;
   }

   // (2) Not too far from EMA21 at entry (avoid late entries)
   double curDist = MathAbs(close[idx] - e3[idx]);
   if(curDist > atr * InpMaxDistFromEMA) return false;

   // (3) Momentum candle: close in top/bottom 30% of bar range, body>50%
   if(InpRequireMomentumCandle)
   {
      double range = high[idx] - low[idx];
      if(range <= 0) return false;
      double body  = MathAbs(close[idx] - open[idx]);
      if(body < range * 0.5) return false;
      if(isBull)
      {
         if(close[idx] < open[idx]) return false;            // must close green
         if((high[idx] - close[idx]) > range * 0.3) return false; // close near high
      }
      else
      {
         if(close[idx] > open[idx]) return false;            // must close red
         if((close[idx] - low[idx]) > range * 0.3) return false;  // close near low
      }
   }

   // (4) Volume boost: above 20-bar average
   if(InpRequireVolumeBoost)
   {
      double sum = 0;
      for(int j = idx - 20; j < idx; j++) sum += (double)tickVol[j];
      double avg = sum / 20.0;
      if(avg <= 0) return false;
      if((double)tickVol[idx] < avg * 1.1) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Compute swing-low / swing-high based SL price                    |
//+------------------------------------------------------------------+
double ComputeSwingSL(bool isBull, double atr,
                      const double &high[], const double &low[], int idx)
{
   if(idx < InpSwingSLBars) return 0;
   double extreme;
   if(isBull)
   {
      extreme = low[idx];
      for(int j = idx - InpSwingSLBars + 1; j <= idx; j++)
         if(low[j] < extreme) extreme = low[j];
      return extreme - atr * InpSwingSLBufATR;
   }
   else
   {
      extreme = high[idx];
      for(int j = idx - InpSwingSLBars + 1; j <= idx; j++)
         if(high[j] > extreme) extreme = high[j];
      return extreme + atr * InpSwingSLBufATR;
   }
}

//+------------------------------------------------------------------+
//| Risk / Filter checks                                              |
//+------------------------------------------------------------------+
bool IsTimeAllowed()
{
   if(!InpUseTimeFilter) return true;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < InpStartHour || dt.hour >= InpEndHour) return false;
   // Avoid first 5 min of each hour (news spike risk)
   if(InpAvoidNewsHour && dt.min < 5) return false;
   return true;
}

bool IsSpreadOK()
{
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread <= InpMaxSpreadPts);
}

bool IsCooldown()
{
   return (TimeCurrent() < g_cooldownEnd);
}

void CheckDailyReset()
{
   datetime today = TimeToDate(TimeCurrent());
   if(today != g_dailyDate)
   {
      g_dailyDate         = today;
      g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      // Don't reset consecLosses across days; keep it persistent
   }
}

bool IsDailyDDExceeded()
{
   double curBal = AccountInfoDouble(ACCOUNT_BALANCE);
   double ddPct  = (g_dailyStartBalance - curBal) / g_dailyStartBalance * 100.0;
   return (ddPct >= InpMaxDailyDD);
}

bool IsFridayClose()
{
   if(!InpFridayFlat) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 5 && dt.hour >= InpEndHour);
}

//+------------------------------------------------------------------+
//| Lot size from risk %                                              |
//+------------------------------------------------------------------+
double CalcLotSize(double slDistancePoints)
{
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(tickValue <= 0 || tickSize <= 0 || point <= 0 || slDistancePoints <= 0)
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double lossPerLot = (slDistancePoints * point / tickSize) * tickValue;
   double lots = riskMoney / lossPerLot;

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots / step) * step;
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;
   return lots;
}

//+------------------------------------------------------------------+
//| Trade execution                                                   |
//+------------------------------------------------------------------+
bool OpenTrade(bool isBull, double atr, double swingSLPrice)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double price = isBull ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Determine SL distance: prefer swing-based, fallback to ATR
   double slDistPts;
   if(InpUseSwingSL && swingSLPrice > 0)
   {
      slDistPts = isBull ? (price - swingSLPrice) / point
                          : (swingSLPrice - price) / point;
   }
   else
   {
      slDistPts = atr * InpSLAtrMult / point;
   }

   if(slDistPts < InpMinSLPoints) slDistPts = InpMinSLPoints;
   if(slDistPts > InpMaxSLPoints) slDistPts = InpMaxSLPoints;

   double stopsLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(slDistPts < stopsLevel + 5.0) slDistPts = stopsLevel + 5.0;

   // TP2 = R x InpTP2RR (from initial risk distance)
   double tp2DistPts = slDistPts * InpTP2RR;
   if(tp2DistPts < stopsLevel + 5.0) tp2DistPts = stopsLevel + 5.0;

   double sl = isBull ? price - slDistPts * point : price + slDistPts * point;
   double tp = isBull ? price + tp2DistPts * point : price - tp2DistPts * point;
   double lots = CalcLotSize(slDistPts);

   bool ok;
   if(isBull) ok = g_trade.Buy(lots, _Symbol, price, sl, tp, "FadApex EA v1.10");
   else        ok = g_trade.Sell(lots, _Symbol, price, sl, tp, "FadApex EA v1.10");

   if(ok)
   {
      g_currentTicket  = g_trade.ResultDeal();
      g_currentBull    = isBull;
      g_entryPrice     = price;
      g_initialSL      = sl;
      g_atrAtEntry     = atr;
      g_initialRiskPts = slDistPts;
      g_entryBarTime   = iTime(_Symbol, PERIOD_CURRENT, 0);
      g_tp1Hit         = false;
      g_tightTrailOn   = false;
      Print("OPEN ", isBull ? "BUY" : "SELL", " @ ", DoubleToString(price, _Digits),
            " SL=", DoubleToString(sl, _Digits),
            " TP=", DoubleToString(tp, _Digits),
            " Lots=", DoubleToString(lots, 2),
            " R=", DoubleToString(slDistPts, 0), "pts");
      return true;
   }
   Print("Trade open failed: ", g_trade.ResultRetcode(),
         " - ", g_trade.ResultRetcodeDescription());
   return false;
}

void CloseAllPositions(string reason)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_pos.SelectByIndex(i)
         && g_pos.Symbol() == _Symbol
         && g_pos.Magic() == InpMagic)
      {
         g_trade.PositionClose(g_pos.Ticket());
         Print("CLOSE ticket ", g_pos.Ticket(), " reason: ", reason);
      }
   }
   g_currentTicket = 0;
   g_tp1Hit = false;
}

//+------------------------------------------------------------------+
//| Manage open position: TP1 partial + multi-stage R-based trailing  |
//+------------------------------------------------------------------+
void ManageOpenPosition()
{
   if(g_currentTicket == 0) return;
   if(!g_pos.SelectByTicket(g_currentTicket))
   {
      // Position no longer exists — was closed (SL/TP/manual)
      OnPositionClosed();
      g_currentTicket  = 0;
      g_tp1Hit         = false;
      g_tightTrailOn   = false;
      g_initialRiskPts = 0;
      return;
   }

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double curPrice = g_currentBull ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double profitPts = g_currentBull ? (curPrice - g_entryPrice) / point
                                     : (g_entryPrice - curPrice) / point;

   // Safety: skip management without a valid risk reference
   if(g_initialRiskPts <= 0) return;

   double R = g_initialRiskPts;            // 1R in points
   double rrNow = profitPts / R;           // current profit in R-multiples
   double curSL = g_pos.StopLoss();
   double curTP = g_pos.TakeProfit();

   // --- Max bars in trade timeout ---
   if(InpMaxBarsInTrade > 0 && g_entryBarTime > 0)
   {
      int barSec = PeriodSeconds(PERIOD_CURRENT);
      if(barSec > 0)
      {
         long elapsed = (long)(TimeCurrent() - g_entryBarTime) / barSec;
         if(elapsed >= InpMaxBarsInTrade)
         {
            Print("Max bars in trade reached (", elapsed, "). Closing.");
            g_trade.PositionClose(g_currentTicket);
            return;
         }
      }
   }

   // --- TP1 partial + move SL to BE ---
   if(!g_tp1Hit && rrNow >= InpTP1RR)
   {
      double curVol = g_pos.Volume();
      double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double partial = MathFloor(curVol * InpTP1ClosePct / 100.0 / step) * step;
      if(partial >= minVol && partial < curVol)
      {
         if(g_trade.PositionClosePartial(g_currentTicket, partial))
            Print("TP1 partial @", rrNow, "R: ", DoubleToString(partial, 2),
                  " lots @ ", DoubleToString(curPrice, _Digits));
      }
      // Move SL to BE + small buffer
      double bufPts = 5.0;
      double newSL = g_currentBull ? g_entryPrice + bufPts * point
                                    : g_entryPrice - bufPts * point;
      if((g_currentBull && newSL > curSL) || (!g_currentBull && newSL < curSL))
         g_trade.PositionModify(g_currentTicket, newSL, curTP);
      g_tp1Hit = true;
      return;  // Defer further trail to next tick after stable state
   }

   // --- Multi-stage trailing after TP1 ---
   if(!g_tp1Hit || !InpUseTrailing) return;

   // Engage tighter trail once we're at significant profit
   if(!g_tightTrailOn && rrNow >= InpTightTrailRR) g_tightTrailOn = true;

   double trailDistPts = g_tightTrailOn ? R * InpTightTrailDist
                                          : R * InpTrailDistRR;
   if(rrNow < InpTrailStartRR) return;  // Don't trail until trail-start RR reached

   double newSL = g_currentBull ? curPrice - trailDistPts * point
                                 : curPrice + trailDistPts * point;
   if(g_currentBull && newSL > curSL)
      g_trade.PositionModify(g_currentTicket, newSL, curTP);
   else if(!g_currentBull && newSL < curSL)
      g_trade.PositionModify(g_currentTicket, newSL, curTP);
}

//+------------------------------------------------------------------+
//| Track position close result for consecutive loss tracking         |
//+------------------------------------------------------------------+
void OnPositionClosed()
{
   // Check the last closed deal for this magic
   HistorySelect(TimeCurrent() - 86400, TimeCurrent() + 60);
   int total = HistoryDealsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      if(dealTicket == g_lastClosedTicket) return;

      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                    + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                    + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

      if(profit < 0) g_consecLosses++;
      else if(profit > 0) g_consecLosses = 0;

      if(g_consecLosses >= InpMaxConsecLoss)
      {
         g_cooldownEnd = TimeCurrent() + InpCooldownHours * 3600;
         Print("Cooldown triggered: ", g_consecLosses, " consecutive losses. Cooldown until ", g_cooldownEnd);
         g_consecLosses = 0;
      }
      g_lastClosedTicket = dealTicket;
      return;
   }
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   CheckDailyReset();

   // Always manage open positions
   ManageOpenPosition();

   // Friday flatten
   if(IsFridayClose() && g_currentTicket != 0)
   {
      CloseAllPositions("Friday flat");
      return;
   }

   // New bar detection
   datetime curBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool newBar = (curBarTime != g_lastBarTime);
   if(!newBar) return;
   g_lastBarTime = curBarTime;

   // Calculate signal at the just-CLOSED bar
   SignalResult sig = ComputeSignal();

   // Exit logic on existing position
   if(g_currentTicket != 0)
   {
      // Reverse signal exit
      if(InpExitOnReverse && sig.direction != 0)
      {
         bool isReverse = (g_currentBull && sig.direction == -1)
                        || (!g_currentBull && sig.direction == 1);
         bool rankOK = (sig.rank == "S" && InpEntryRankS)
                    || (sig.rank == "A" && InpEntryRankA);
         if(isReverse && rankOK)
         {
            CloseAllPositions("Reverse signal " + sig.rank);
         }
      }
      // EXIT signal
      if(InpExitOnSignal && sig.hasExit)
      {
         CloseAllPositions("EXIT signal " + IntegerToString(sig.exitScore));
      }
      return;  // Don't open new while one is open
   }

   // Entry logic
   if(IsCooldown())             return;
   if(IsDailyDDExceeded())      return;
   if(!IsTimeAllowed())         return;
   if(!IsSpreadOK())            return;
   if(IsFridayClose())          return;

   if(sig.direction == 0) return;

   // Rank filter
   bool rankOK = false;
   if(sig.rank == "S" && InpEntryRankS) rankOK = true;
   if(sig.rank == "A" && InpEntryRankA) rankOK = true;
   if(sig.rank == "B" && InpEntryRankB) rankOK = true;
   if(!rankOK) return;

   // Quality filter (pullback + momentum + volume) - the heart of v1.10
   if(!sig.qualityPass) return;

   // ATR check
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double atr = sig.atrAtSig;
   if(atr <= 0)
   {
      double atrArr[];
      if(CopyBuffer(g_hATR, 0, 1, 1, atrArr) != 1) return;
      atr = atrArr[0];
   }
   if(atr / point < InpMinATRPoints) return;

   bool isBull = (sig.direction == 1);
   OpenTrade(isBull, atr, sig.swingSL);
}
