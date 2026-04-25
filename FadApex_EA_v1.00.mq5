//+------------------------------------------------------------------+
//| FadApex EA v1.00 - Gold M1 Auto-Trader                           |
//| Based on FadApex v4.62 indicator signal logic                    |
//| Optimized for XAUUSD M1 scalping                                 |
//+------------------------------------------------------------------+
#property copyright "FadApex EA"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

CTrade        g_trade;
CPositionInfo g_pos;

//=== INPUTS: Trading ===
input group "=== Trading ==="
input long   InpMagic        = 462001;
input double InpRiskPercent  = 0.5;       // Risk per trade (%)
input int    InpMaxSlippage  = 30;        // Max slippage in points
input int    InpMaxSpreadPts = 300;       // Max spread (Gold: 300 pts = 30 pips)

//=== INPUTS: Risk Management ===
input group "=== Risk Management ==="
input double InpMaxDailyDD     = 2.5;     // Max daily drawdown (%)
input int    InpMaxConsecLoss  = 4;       // Max consecutive losses before cooldown
input int    InpCooldownHours  = 6;       // Cooldown duration (hours)
input bool   InpFridayFlat     = true;    // Close all positions Friday end

//=== INPUTS: Entry Filters ===
input group "=== Entry Filters ==="
input bool   InpEntryRankS    = true;     // Trade Rank S signals
input bool   InpEntryRankA    = true;     // Trade Rank A signals
input bool   InpEntryRankB    = false;    // Trade Rank B signals
input int    InpMinADX        = 22;       // Min ADX for entry
input int    InpMinATRPoints  = 300;      // Min ATR (Gold: 300 pts = 30 pips)

//=== INPUTS: SL/TP (ATR-based) ===
input group "=== SL/TP ==="
input double InpSLAtrMult     = 1.5;      // SL = ATR x this
input double InpTP1AtrMult    = 1.2;      // TP1 = ATR x this (50% close)
input int    InpTP1ClosePct   = 50;       // % closed at TP1
input double InpTP2AtrMult    = 3.0;      // TP2 = ATR x this (remaining close)
input bool   InpUseTrailing   = true;     // Use trailing stop after TP1
input double InpTrailAtrMult  = 1.5;      // Trail distance = ATR x this
input int    InpMinSLPoints   = 300;      // Min SL distance (Gold: 30 pips)
input int    InpMaxSLPoints   = 2000;     // Max SL distance (Gold: 200 pips)

//=== INPUTS: Time Filter ===
input group "=== Time Filter ==="
input bool   InpUseTimeFilter = true;     // Use time filter
input int    InpStartHour     = 13;       // Trading start hour (server time)
input int    InpEndHour       = 21;       // Trading end hour

//=== INPUTS: Exit Rules ===
input group "=== Exit Rules ==="
input bool   InpExitOnReverse  = true;    // Close on opposite signal
input bool   InpExitOnSignal   = true;    // Close on EXIT signal

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
double   g_lastPositionProfit = 0;
ulong    g_lastClosedTicket  = 0;

// Trade state
ulong    g_currentTicket = 0;
bool     g_currentBull   = false;
bool     g_tp1Hit        = false;
double   g_entryPrice    = 0;
double   g_initialSL     = 0;
double   g_atrAtEntry    = 0;

//=== Signal info struct ===
struct SignalResult
{
   int direction;   // 1=BULL, -1=BEAR, 0=none
   int score;       // 0-4
   string rank;     // "S", "A", "B"
   bool hasExit;
   int exitScore;   // 0-100
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
         g_tp1Hit        = false;
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
//| Compute HTF barTrend at LATEST chart bar (simulates ProcessHTF)  |
//+------------------------------------------------------------------+
int ComputeHTFTrend(int tfIdx, int chartTotal,
                    const datetime &chartTime[])
{
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
   if(cnt < 2 * lb + 2) return 0;

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

   // Replay from beginning of chart bars to compute trend at latest
   int startI = MathMax(0, chartTotal - 600);
   for(int i = startI; i < chartTotal; i++)
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

      prevMappedClose = curClose;
      prevLastSH = lastSH;
      prevLastSL = lastSL;
      prevMappedIdx = htfIdx;
   }
   return trend;
}

//+------------------------------------------------------------------+
//| Compute signal at the latest CLOSED bar                          |
//+------------------------------------------------------------------+
SignalResult ComputeSignal()
{
   SignalResult sig;
   sig.direction = 0; sig.score = 0; sig.rank = "";
   sig.hasExit = false; sig.exitScore = 0;

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

   double e[8][];
   for(int k = 0; k < 8; k++)
   {
      ArraySetAsSeries(e[k],false);
      ArrayResize(e[k], need);
      if(CopyBuffer(g_hEMA[k],0,0,need,e[k]) != need) return sig;
   }
   double atrBuf[], adxBuf[];
   ArraySetAsSeries(atrBuf,false); ArraySetAsSeries(adxBuf,false);
   if(CopyBuffer(g_hATR,0,0,need,atrBuf) != need) return sig;
   if(CopyBuffer(g_hADX,0,0,need,adxBuf) != need) return sig;

   // Latest CLOSED bar
   int idx = need - 2;

   // HTF trends at this chart bar (use full ProcessHTF on shifted view)
   int t0 = ComputeHTFTrendAt(0, time, idx, need);
   int t1 = ComputeHTFTrendAt(1, time, idx, need);
   int t2 = ComputeHTFTrendAt(2, time, idx, need);

   // Replay master state up to idx
   int prevMaster = 0;
   int lastSignalBar = -9999;
   int latestSigBar  = -1;
   bool latestBull   = false;
   int  latestScore  = 0;

   for(int i = 200; i <= idx; i++)
   {
      // Recompute trends at each bar — too slow; instead replay simplified
      // Use direct indicator value for last 100 bars
   }

   // Simplified single-bar evaluation at idx
   int buCnt=0, beCnt=0;
   if(t0==1) buCnt++; if(t0==-1) beCnt++;
   if(t1==1) buCnt++; if(t1==-1) beCnt++;
   if(t2==1) buCnt++; if(t2==-1) beCnt++;

   bool rBull = (e[0][idx] > e[7][idx]);
   bool aBull = (buCnt >= InpTrendConfirm) && rBull;
   bool aBear = (beCnt >= InpTrendConfirm) && !rBull;

   // For prev bar
   bool rBullPrev = (e[0][idx-1] > e[7][idx-1]);

   // Range filter
   bool passRange = true;
   if(adxBuf[idx] < InpMinADX) passRange = false;
   if(atrBuf[idx] > 0)
   {
      double rW = MathAbs(e[0][idx] - e[7][idx]);
      if(rW < atrBuf[idx] * InpRibbonATRRatio) passRange = false;
   }

   // Determine if latest bar is a transition
   // We need prev master = trend before this bar; approximate by prev bar's aBull/aBear
   int buCntPrev=0, beCntPrev=0;
   // Approximate: ribbon at prev bar
   // For simplicity, use HTF trend from previous bar (same period since HTF rarely flips)
   // Use whether prev bar was clearly bull/bear
   bool prevBull = rBullPrev;
   int approxPrev = (prevBull && rBullPrev) ? 1 : (!prevBull && !rBullPrev) ? -1 : 0;

   // Better: use sign of EMA0-EMA7 trend persistence over last 5 bars
   int emaSignBar = idx - 1;
   double diff = e[0][emaSignBar] - e[7][emaSignBar];
   approxPrev = (diff > 0) ? 1 : (diff < 0) ? -1 : 0;

   bool isBullTransition = aBull && approxPrev != 1;
   bool isBearTransition = aBear && approxPrev != -1;

   if(passRange && (isBullTransition || isBearTransition))
   {
      bool isBull = isBullTransition;
      int score = 0;

      // Factor 1: All 3 TFs aligned
      if(isBull && buCnt == 3) score++;
      if(!isBull && beCnt == 3) score++;

      // Factor 2: Perfect EMA order
      bool perfOrder;
      if(isBull)
         perfOrder = e[0][idx]>e[1][idx] && e[1][idx]>e[2][idx] && e[2][idx]>e[3][idx]
                  && e[3][idx]>e[4][idx] && e[4][idx]>e[5][idx] && e[5][idx]>e[6][idx]
                  && e[6][idx]>e[7][idx];
      else
         perfOrder = e[0][idx]<e[1][idx] && e[1][idx]<e[2][idx] && e[2][idx]<e[3][idx]
                  && e[3][idx]<e[4][idx] && e[4][idx]<e[5][idx] && e[5][idx]<e[6][idx]
                  && e[6][idx]<e[7][idx];
      if(perfOrder) score++;

      // Factor 3: Candle momentum
      double bodySize = MathAbs(close[idx] - open[idx]);
      double avgBody = 0;
      for(int j = idx - 20; j < idx; j++) avgBody += MathAbs(close[j] - open[j]);
      avgBody /= 20.0;
      if(avgBody > 0 && bodySize > avgBody * 1.3) score++;

      // Factor 4: Ribbon squeeze expansion
      double curWidth = MathAbs(e[0][idx] - e[7][idx]);
      double minW = curWidth;
      for(int j = idx - 10; j < idx; j++)
         minW = MathMin(minW, MathAbs(e[0][j] - e[7][j]));
      if(curWidth > 0 && minW < curWidth * 0.5) score++;

      sig.direction = isBull ? 1 : -1;
      sig.score = score;
      sig.rank = (score >= 3) ? "S" : (score == 2) ? "A" : "B";
   }

   // EXIT score (if position open)
   if(g_currentTicket != 0)
   {
      sig.exitScore = CalcExitScoreEA(g_currentBull, idx, e, close, open, high, low,
                                       tick_vol, atrBuf, adxBuf);
      sig.hasExit = (sig.exitScore >= InpExitThreshold);
   }
   return sig;
}

//+------------------------------------------------------------------+
//| HTF trend at specific chart bar idx                              |
//+------------------------------------------------------------------+
int ComputeHTFTrendAt(int tfIdx, const datetime &chartTime[],
                      int idx, int chartTotal)
{
   datetime chartTimeSlice[];
   ArrayResize(chartTimeSlice, idx + 1);
   for(int i = 0; i <= idx; i++) chartTimeSlice[i] = chartTime[i];
   return ComputeHTFTrend(tfIdx, idx + 1, chartTimeSlice);
}

//+------------------------------------------------------------------+
//| EXIT score (port of v4.62 CalcExitScore)                         |
//+------------------------------------------------------------------+
int CalcExitScoreEA(bool isBullPos, int idx, const double &e[][],
                    const double &close[], const double &open[],
                    const double &high[], const double &low[],
                    const long &tickVol[], const double &atrBuf[],
                    const double &adxBuf[])
{
   double score = 0.0;
   if(idx < 22) return 0;

   // Layer 1: Price deviation from EMA (30pt)
   double ribbonW = MathAbs(e[0][idx] - e[7][idx]);
   if(atrBuf[idx] > 0 && ribbonW > 0)
   {
      double dev = isBullPos ? (close[idx] - e[0][idx]) : (e[0][idx] - close[idx]);
      double atrDev = dev / atrBuf[idx];
      if(atrDev > 1.5)      score += 30.0;
      else if(atrDev > 1.0)  score += 22.0;
      else if(atrDev > 0.6)  score += 15.0;
      else if(atrDev > 0.3)  score += 8.0;
   }

   // Layer 2: EMA slope reversal (25pt)
   double slopeNow  = e[0][idx] - e[0][idx - 2];
   double slopePrev = e[0][idx - 2] - e[0][idx - 4];
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
//| Risk / Filter checks                                              |
//+------------------------------------------------------------------+
bool IsTimeAllowed()
{
   if(!InpUseTimeFilter) return true;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < InpStartHour || dt.hour >= InpEndHour) return false;
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
bool OpenTrade(bool isBull, double atr)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double price = isBull ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double slDistPts = atr * InpSLAtrMult / point;
   if(slDistPts < InpMinSLPoints) slDistPts = InpMinSLPoints;
   if(slDistPts > InpMaxSLPoints) slDistPts = InpMaxSLPoints;

   double tp2DistPts = atr * InpTP2AtrMult / point;

   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(slDistPts < stopsLevel + 5)  slDistPts  = stopsLevel + 5;
   if(tp2DistPts < stopsLevel + 5) tp2DistPts = stopsLevel + 5;

   double sl = isBull ? price - slDistPts * point : price + slDistPts * point;
   double tp = isBull ? price + tp2DistPts * point : price - tp2DistPts * point;
   double lots = CalcLotSize(slDistPts);

   bool ok;
   if(isBull) ok = g_trade.Buy(lots, _Symbol, price, sl, tp, "FadApex EA");
   else        ok = g_trade.Sell(lots, _Symbol, price, sl, tp, "FadApex EA");

   if(ok)
   {
      g_currentTicket = g_trade.ResultDeal();
      g_currentBull   = isBull;
      g_entryPrice    = price;
      g_initialSL     = sl;
      g_atrAtEntry    = atr;
      g_tp1Hit        = false;
      Print("OPEN ", isBull ? "BUY" : "SELL", " @ ", price,
            " SL=", sl, " TP=", tp, " Lots=", lots);
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
//| Manage open position: TP1 partial, trailing                       |
//+------------------------------------------------------------------+
void ManageOpenPosition()
{
   if(g_currentTicket == 0) return;
   if(!g_pos.SelectByTicket(g_currentTicket))
   {
      // Position no longer exists — was closed (SL/TP/manual)
      OnPositionClosed();
      g_currentTicket = 0;
      g_tp1Hit = false;
      return;
   }

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double curPrice = g_currentBull ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double profitPts = g_currentBull ? (curPrice - g_entryPrice) / point
                                     : (g_entryPrice - curPrice) / point;

   double tp1Pts = g_atrAtEntry * InpTP1AtrMult / point;

   // TP1 partial close + move SL to BE
   if(!g_tp1Hit && profitPts >= tp1Pts)
   {
      double curVol = g_pos.Volume();
      double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double partial = MathFloor(curVol * InpTP1ClosePct / 100.0 / step) * step;
      if(partial >= minVol && partial < curVol)
      {
         if(g_trade.PositionClosePartial(g_currentTicket, partial))
         {
            Print("TP1 partial close: ", partial, " lots @ ", curPrice);
         }
      }
      // Move SL to BE
      double newSL = g_entryPrice;
      double curSL = g_pos.StopLoss();
      double curTP = g_pos.TakeProfit();
      if((g_currentBull && newSL > curSL) || (!g_currentBull && newSL < curSL))
      {
         g_trade.PositionModify(g_currentTicket, newSL, curTP);
      }
      g_tp1Hit = true;
   }

   // Trailing stop after TP1
   if(g_tp1Hit && InpUseTrailing)
   {
      double trailDist = g_atrAtEntry * InpTrailAtrMult;
      double newSL = g_currentBull ? curPrice - trailDist : curPrice + trailDist;
      double curSL = g_pos.StopLoss();
      double curTP = g_pos.TakeProfit();
      if(g_currentBull && newSL > curSL)
         g_trade.PositionModify(g_currentTicket, newSL, curTP);
      else if(!g_currentBull && newSL < curSL)
         g_trade.PositionModify(g_currentTicket, newSL, curTP);
   }
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

   // ATR check
   double atrArr[];
   if(CopyBuffer(g_hATR, 0, 1, 1, atrArr) != 1) return;
   double atr = atrArr[0];
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr / point < InpMinATRPoints) return;

   bool isBull = (sig.direction == 1);
   OpenTrade(isBull, atr);
}
