//+------------------------------------------------------------------+
//| TimeDilationTrendVisualizer.mq5                                  |
//| Pine Script完全移植版 - Time Dilation Trend Visualizer [EZPZ]     |
//| Components: EMA Ribbon, MTF Structure (BOS/MSS),                 |
//|             BULL/BEAR Signals, Key Levels, Candle Coloring       |
//+------------------------------------------------------------------+
#property copyright "Time Dilation Trend Visualizer [EZPZ]"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window

// バッファ数: 14(リボン) + 2(シグナル) + 5(カラーキャンドル=4data+1color) = 21
#property indicator_buffers 21
#property indicator_plots   10

//--- Plot 1-7: EMAリボン fill用ペア (DRAW_FILLING x 7)
#property indicator_label1  "Ribbon1_2"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  C'0,255,65',C'255,23,68'
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "Ribbon2_3"
#property indicator_type2   DRAW_FILLING
#property indicator_color2  C'0,229,58',C'255,45,85'
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_label3  "Ribbon3_4"
#property indicator_type3   DRAW_FILLING
#property indicator_color3  C'0,204,51',C'229,57,53'
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#property indicator_label4  "Ribbon4_5"
#property indicator_type4   DRAW_FILLING
#property indicator_color4  C'0,179,45',C'211,47,47'
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

#property indicator_label5  "Ribbon5_6"
#property indicator_type5   DRAW_FILLING
#property indicator_color5  C'0,153,38',C'198,40,40'
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

#property indicator_label6  "Ribbon6_7"
#property indicator_type6   DRAW_FILLING
#property indicator_color6  C'0,128,32',C'183,28,28'
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

#property indicator_label7  "Ribbon7_8"
#property indicator_type7   DRAW_FILLING
#property indicator_color7  C'0,102,26',C'155,27,27'
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

//--- Plot 8: BULLシグナル
#property indicator_label8  "BULL"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  C'0,230,118'
#property indicator_style8  STYLE_SOLID
#property indicator_width8  4

//--- Plot 9: BEARシグナル
#property indicator_label9  "BEAR"
#property indicator_type9   DRAW_ARROW
#property indicator_color9  C'255,23,68'
#property indicator_style9  STYLE_SOLID
#property indicator_width9  4

//--- Plot 10: ローソク足カラー用 (DRAW_COLOR_CANDLES = 4data + 1color)
#property indicator_label10 "ColorCandle"
#property indicator_type10  DRAW_COLOR_CANDLES
#property indicator_color10 C'0,230,118',C'255,82,82',C'96,96,96'
#property indicator_style10 STYLE_SOLID
#property indicator_width10 1

//+------------------------------------------------------------------+
//| 入力パラメーター                                                    |
//+------------------------------------------------------------------+
input group "══════ MA Ribbon Settings ══════"
input int    InpEMA1  = 5;     // EMA 1 Length
input int    InpEMA2  = 8;     // EMA 2 Length
input int    InpEMA3  = 13;    // EMA 3 Length
input int    InpEMA4  = 21;    // EMA 4 Length
input int    InpEMA5  = 34;    // EMA 5 Length
input int    InpEMA6  = 55;    // EMA 6 Length
input int    InpEMA7  = 89;    // EMA 7 Length
input int    InpEMA8  = 144;   // EMA 8 Length

input group "══════ Structure Detection ══════"
input int    InpSwingLookback = 10;    // Swing Lookback
input bool   InpShow5min      = true;  // Show 5 Min Structure
input bool   InpShow15min     = true;  // Show 15 Min Structure
input bool   InpShow1H        = true;  // Show 1H Structure

input group "══════ BULL/BEAR Signal Settings ══════"
input int    InpTrendConfirm  = 2;     // Min TF Alignment for Signal (1-3)

input group "══════ Key Level Settings ══════"
input bool   InpShowLevels    = true;  // Show Key Levels
input int    InpMaxLevels     = 3;     // Max Levels Per Side
input int    InpLevelExtend   = 50;    // Level Extend (bars)

//+------------------------------------------------------------------+
//| グローバル変数                                                      |
//+------------------------------------------------------------------+

// EMAリボン用バッファ (7 fills × 2 = 14 buffers)
double g_ema1[], g_ema2a[];  // fill 1: EMA1-EMA2
double g_ema2b[], g_ema3a[]; // fill 2: EMA2-EMA3
double g_ema3b[], g_ema4a[]; // fill 3: EMA3-EMA4
double g_ema4b[], g_ema5a[]; // fill 4: EMA4-EMA5
double g_ema5b[], g_ema6a[]; // fill 5: EMA5-EMA6
double g_ema6b[], g_ema7a[]; // fill 6: EMA6-EMA7
double g_ema7b[], g_ema8[];  // fill 7: EMA7-EMA8

// シグナルバッファ
double g_bullSignal[], g_bearSignal[];

// ローソク足カラーバッファ (4 data + 1 color index)
double g_candleOpen[], g_candleHigh[], g_candleLow[], g_candleClose[];
double g_candleColor[];

// EMAインジケーターハンドル
int g_hEMA[8];

// EMAデータ取得用の個別配列（MQL5は2D動的配列不可のため）
double g_emaD0[], g_emaD1[], g_emaD2[], g_emaD3[];
double g_emaD4[], g_emaD5[], g_emaD6[], g_emaD7[];

// MTF用（5min, 15min, 1H）
ENUM_TIMEFRAMES g_mtfPeriods[3] = {PERIOD_M5, PERIOD_M15, PERIOD_H1};
string g_mtfLabels[3] = {"5Min", "15Min", "1H"};

// 構造検出状態
struct StructureState
{
   double prevSH;
   double prevSL;
   double lastSH;
   double lastSL;
   int    trend;  // 1=up, -1=down, 0=neutral
};
StructureState g_structState[3];

// マスタートレンド
int g_masterTrend;

// キーレベル管理
string g_prefix = "TDTV_";
int    g_highLevelCount;
int    g_lowLevelCount;
string g_highLevelNames[];
string g_lowLevelNames[];

// 前回のBOS/MSSバー記録（重複防止）
int g_lastBOS_Bull[3], g_lastBOS_Bear[3];
int g_lastMSS_Bull[3], g_lastMSS_Bear[3];

//+------------------------------------------------------------------+
//| OnInit                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   // --- バッファ設定 (合計21バッファ) ---
   // Fill 1: EMA1-EMA2 (buf 0,1)
   SetIndexBuffer(0,  g_ema1,   INDICATOR_DATA);
   SetIndexBuffer(1,  g_ema2a,  INDICATOR_DATA);
   // Fill 2: EMA2-EMA3 (buf 2,3)
   SetIndexBuffer(2,  g_ema2b,  INDICATOR_DATA);
   SetIndexBuffer(3,  g_ema3a,  INDICATOR_DATA);
   // Fill 3: EMA3-EMA4 (buf 4,5)
   SetIndexBuffer(4,  g_ema3b,  INDICATOR_DATA);
   SetIndexBuffer(5,  g_ema4a,  INDICATOR_DATA);
   // Fill 4: EMA4-EMA5 (buf 6,7)
   SetIndexBuffer(6,  g_ema4b,  INDICATOR_DATA);
   SetIndexBuffer(7,  g_ema5a,  INDICATOR_DATA);
   // Fill 5: EMA5-EMA6 (buf 8,9)
   SetIndexBuffer(8,  g_ema5b,  INDICATOR_DATA);
   SetIndexBuffer(9,  g_ema6a,  INDICATOR_DATA);
   // Fill 6: EMA6-EMA7 (buf 10,11)
   SetIndexBuffer(10, g_ema6b,  INDICATOR_DATA);
   SetIndexBuffer(11, g_ema7a,  INDICATOR_DATA);
   // Fill 7: EMA7-EMA8 (buf 12,13)
   SetIndexBuffer(12, g_ema7b,  INDICATOR_DATA);
   SetIndexBuffer(13, g_ema8,   INDICATOR_DATA);

   // BULLシグナル (buf 14)
   SetIndexBuffer(14, g_bullSignal, INDICATOR_DATA);
   PlotIndexSetInteger(7, PLOT_ARROW, 159);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // BEARシグナル (buf 15)
   SetIndexBuffer(15, g_bearSignal, INDICATOR_DATA);
   PlotIndexSetInteger(8, PLOT_ARROW, 159);
   PlotIndexSetDouble(8, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // ローソク足カラー (buf 16-20: 4data + 1color)
   SetIndexBuffer(16, g_candleOpen,  INDICATOR_DATA);
   SetIndexBuffer(17, g_candleHigh,  INDICATOR_DATA);
   SetIndexBuffer(18, g_candleLow,   INDICATOR_DATA);
   SetIndexBuffer(19, g_candleClose, INDICATOR_DATA);
   SetIndexBuffer(20, g_candleColor, INDICATOR_COLOR_INDEX);

   // EMAインジケーターハンドル作成
   int emaLengths[8];
   emaLengths[0] = InpEMA1; emaLengths[1] = InpEMA2;
   emaLengths[2] = InpEMA3; emaLengths[3] = InpEMA4;
   emaLengths[4] = InpEMA5; emaLengths[5] = InpEMA6;
   emaLengths[6] = InpEMA7; emaLengths[7] = InpEMA8;

   for(int i = 0; i < 8; i++)
   {
      g_hEMA[i] = iMA(_Symbol, PERIOD_CURRENT, emaLengths[i], 0, MODE_EMA, PRICE_CLOSE);
      if(g_hEMA[i] == INVALID_HANDLE)
      {
         PrintFormat("EMA[%d] ハンドル作成失敗 (Period=%d)", i, emaLengths[i]);
         return(INIT_FAILED);
      }
   }

   // 構造検出状態初期化
   for(int i = 0; i < 3; i++)
   {
      g_structState[i].prevSH = 0;
      g_structState[i].prevSL = 0;
      g_structState[i].lastSH = 0;
      g_structState[i].lastSL = 0;
      g_structState[i].trend  = 0;
      g_lastBOS_Bull[i] = -1;
      g_lastBOS_Bear[i] = -1;
      g_lastMSS_Bull[i] = -1;
      g_lastMSS_Bear[i] = -1;
   }

   g_masterTrend    = 0;
   g_highLevelCount = 0;
   g_lowLevelCount  = 0;
   ArrayResize(g_highLevelNames, 0);
   ArrayResize(g_lowLevelNames, 0);

   IndicatorSetString(INDICATOR_SHORTNAME, "TDTV [EZPZ]");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, g_prefix);

   for(int i = 0; i < 8; i++)
   {
      if(g_hEMA[i] != INVALID_HANDLE)
         IndicatorRelease(g_hEMA[i]);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| PivotHigh - スイングハイ検出                                        |
//+------------------------------------------------------------------+
double PivotHigh(const double &high[], int bar, int leftBars, int rightBars, int total)
{
   if(bar - leftBars < 0 || bar + rightBars >= total)
      return(0);

   double pivotVal = high[bar];

   for(int i = 1; i <= leftBars; i++)
   {
      if(high[bar - i] >= pivotVal) return(0);
   }
   for(int i = 1; i <= rightBars; i++)
   {
      if(high[bar + i] >= pivotVal) return(0);
   }

   return(pivotVal);
}

//+------------------------------------------------------------------+
//| PivotLow - スイングロー検出                                         |
//+------------------------------------------------------------------+
double PivotLow(const double &low[], int bar, int leftBars, int rightBars, int total)
{
   if(bar - leftBars < 0 || bar + rightBars >= total)
      return(0);

   double pivotVal = low[bar];

   for(int i = 1; i <= leftBars; i++)
   {
      if(low[bar - i] <= pivotVal) return(0);
   }
   for(int i = 1; i <= rightBars; i++)
   {
      if(low[bar + i] <= pivotVal) return(0);
   }

   return(pivotVal);
}

//+------------------------------------------------------------------+
//| GetMTFPivots - MTFデータからピボット検出                             |
//+------------------------------------------------------------------+
void GetMTFPivots(ENUM_TIMEFRAMES tf, int lookback,
                  double &outPH, double &outPL, double &outClose)
{
   outPH    = 0;
   outPL    = 0;
   outClose = 0;

   int barsNeeded = lookback * 2 + 5;
   double highs[], lows[], closes[];
   ArraySetAsSeries(highs, false);
   ArraySetAsSeries(lows, false);
   ArraySetAsSeries(closes, false);

   int copiedH = CopyHigh(_Symbol, tf, 0, barsNeeded, highs);
   int copiedL = CopyLow(_Symbol, tf, 0, barsNeeded, lows);
   int copiedC = CopyClose(_Symbol, tf, 0, barsNeeded, closes);

   if(copiedH < barsNeeded || copiedL < barsNeeded || copiedC < barsNeeded)
      return;

   outClose = closes[copiedC - 1];

   int checkBar = copiedH - 1 - lookback;
   if(checkBar < lookback) return;

   outPH = PivotHigh(highs, checkBar, lookback, lookback, copiedH);
   outPL = PivotLow(lows, checkBar, lookback, lookback, copiedL);
}

//+------------------------------------------------------------------+
//| UpdateStructure - 構造ブレイク検出ロジック                           |
//| Pine Script f_structure_logic() の完全移植                          |
//+------------------------------------------------------------------+
void UpdateStructure(int tfIdx, double pivotHigh, double pivotLow, double closePrice,
                     bool &bosBull, bool &bosBear, bool &mssBull, bool &mssBear)
{
   bosBull = false;
   bosBear = false;
   mssBull = false;
   mssBear = false;

   // スイングハイ更新
   if(pivotHigh > 0)
   {
      g_structState[tfIdx].prevSH = g_structState[tfIdx].lastSH;
      g_structState[tfIdx].lastSH = pivotHigh;
   }

   // スイングロー更新
   if(pivotLow > 0)
   {
      g_structState[tfIdx].prevSL = g_structState[tfIdx].lastSL;
      g_structState[tfIdx].lastSL = pivotLow;
   }

   double lastSH = g_structState[tfIdx].lastSH;
   double lastSL = g_structState[tfIdx].lastSL;
   double prevSH = g_structState[tfIdx].prevSH;
   double prevSL = g_structState[tfIdx].prevSL;

   // トレンド判定（HH+HL=上昇、LL+LH=下降）
   if(lastSH > 0 && prevSH > 0 && lastSL > 0 && prevSL > 0)
   {
      if(lastSH > prevSH && lastSL > prevSL)
         g_structState[tfIdx].trend = 1;
      else if(lastSH < prevSH && lastSL < prevSL)
         g_structState[tfIdx].trend = -1;
   }

   int trend = g_structState[tfIdx].trend;

   // BOS検出（トレンド継続方向のブレイク）
   if(trend == 1 && lastSH > 0 && closePrice > lastSH)
      bosBull = true;
   if(trend == -1 && lastSL > 0 && closePrice < lastSL)
      bosBear = true;

   // MSS検出（トレンド逆方向のブレイク = Market Structure Shift）
   if(trend == -1 && lastSH > 0 && closePrice > lastSH)
      mssBull = true;
   if(trend == 1 && lastSL > 0 && closePrice < lastSL)
      mssBear = true;

   // MSSでトレンド更新
   if(mssBull)
      g_structState[tfIdx].trend = 1;
   if(mssBear)
      g_structState[tfIdx].trend = -1;
}

//+------------------------------------------------------------------+
//| CreateBOSLabel - BOS/MSSラベルをチャート上に描画                      |
//+------------------------------------------------------------------+
void CreateBOSLabel(string tag, datetime timeVal, double price,
                    string text, color clr, bool isAbove)
{
   string name = g_prefix + tag;

   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_TEXT, 0, timeVal, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,
                    isAbove ? ANCHOR_LOWER : ANCHOR_UPPER);
}

//+------------------------------------------------------------------+
//| CreateKeyLevel - 水平キーレベル描画                                  |
//+------------------------------------------------------------------+
void CreateKeyLevel(bool isHigh, double price, datetime startTime, datetime endTime)
{
   string name;
   color  clr;

   if(isHigh)
   {
      g_highLevelCount++;
      name = g_prefix + "HL_" + IntegerToString(g_highLevelCount);
      clr  = C'0,229,255';  // シアン (#00E5FF)

      int sz = ArraySize(g_highLevelNames);
      ArrayResize(g_highLevelNames, sz + 1);
      g_highLevelNames[sz] = name;

      // 古いレベルを削除（MaxLevels超過分）
      while(ArraySize(g_highLevelNames) > InpMaxLevels)
      {
         ObjectDelete(0, g_highLevelNames[0]);
         int arrSz = ArraySize(g_highLevelNames);
         for(int i = 0; i < arrSz - 1; i++)
            g_highLevelNames[i] = g_highLevelNames[i + 1];
         ArrayResize(g_highLevelNames, arrSz - 1);
      }
   }
   else
   {
      g_lowLevelCount++;
      name = g_prefix + "LL_" + IntegerToString(g_lowLevelCount);
      clr  = C'255,64,129';  // マゼンタ/ピンク (#FF4081)

      int sz = ArraySize(g_lowLevelNames);
      ArrayResize(g_lowLevelNames, sz + 1);
      g_lowLevelNames[sz] = name;

      while(ArraySize(g_lowLevelNames) > InpMaxLevels)
      {
         ObjectDelete(0, g_lowLevelNames[0]);
         int arrSz = ArraySize(g_lowLevelNames);
         for(int i = 0; i < arrSz - 1; i++)
            g_lowLevelNames[i] = g_lowLevelNames[i + 1];
         ArrayResize(g_lowLevelNames, arrSz - 1);
      }
   }

   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_TREND, 0, startTime, price, endTime, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| CopyEMAData - 8本のEMAデータをそれぞれ個別配列にコピー                |
//+------------------------------------------------------------------+
bool CopyEMAData(int rates_total)
{
   if(CopyBuffer(g_hEMA[0], 0, 0, rates_total, g_emaD0) < rates_total) return(false);
   if(CopyBuffer(g_hEMA[1], 0, 0, rates_total, g_emaD1) < rates_total) return(false);
   if(CopyBuffer(g_hEMA[2], 0, 0, rates_total, g_emaD2) < rates_total) return(false);
   if(CopyBuffer(g_hEMA[3], 0, 0, rates_total, g_emaD3) < rates_total) return(false);
   if(CopyBuffer(g_hEMA[4], 0, 0, rates_total, g_emaD4) < rates_total) return(false);
   if(CopyBuffer(g_hEMA[5], 0, 0, rates_total, g_emaD5) < rates_total) return(false);
   if(CopyBuffer(g_hEMA[6], 0, 0, rates_total, g_emaD6) < rates_total) return(false);
   if(CopyBuffer(g_hEMA[7], 0, 0, rates_total, g_emaD7) < rates_total) return(false);
   return(true);
}

//+------------------------------------------------------------------+
//| OnCalculate                                                        |
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
                const long &spread[])
{
   if(rates_total < InpEMA8 + 10) return(0);

   int start = (prev_calculated == 0) ? 0 : prev_calculated - 1;

   // ═══════════════════════════════════════════════════════════════
   // EMAデータ取得（個別配列）
   // ═══════════════════════════════════════════════════════════════
   ArraySetAsSeries(g_emaD0, false);
   ArraySetAsSeries(g_emaD1, false);
   ArraySetAsSeries(g_emaD2, false);
   ArraySetAsSeries(g_emaD3, false);
   ArraySetAsSeries(g_emaD4, false);
   ArraySetAsSeries(g_emaD5, false);
   ArraySetAsSeries(g_emaD6, false);
   ArraySetAsSeries(g_emaD7, false);

   if(!CopyEMAData(rates_total))
      return(0);

   // ═══════════════════════════════════════════════════════════════
   // COMPONENT A: EMA RIBBON + CANDLE COLORING
   // ═══════════════════════════════════════════════════════════════
   for(int i = start; i < rates_total; i++)
   {
      double e1 = g_emaD0[i];
      double e2 = g_emaD1[i];
      double e3 = g_emaD2[i];
      double e4 = g_emaD3[i];
      double e5 = g_emaD4[i];
      double e6 = g_emaD5[i];
      double e7 = g_emaD6[i];
      double e8 = g_emaD7[i];

      // Fill 1: EMA1-EMA2
      g_ema1[i]  = e1;
      g_ema2a[i] = e2;
      // Fill 2: EMA2-EMA3
      g_ema2b[i] = e2;
      g_ema3a[i] = e3;
      // Fill 3: EMA3-EMA4
      g_ema3b[i] = e3;
      g_ema4a[i] = e4;
      // Fill 4: EMA4-EMA5
      g_ema4b[i] = e4;
      g_ema5a[i] = e5;
      // Fill 5: EMA5-EMA6
      g_ema5b[i] = e5;
      g_ema6a[i] = e6;
      // Fill 6: EMA6-EMA7
      g_ema6b[i] = e6;
      g_ema7a[i] = e7;
      // Fill 7: EMA7-EMA8
      g_ema7b[i] = e7;
      g_ema8[i]  = e8;

      // ローソク足カラーリング
      g_candleOpen[i]  = open[i];
      g_candleHigh[i]  = high[i];
      g_candleLow[i]   = low[i];
      g_candleClose[i] = close[i];
      // 0=Bull(緑), 1=Bear(赤), 2=ニュートラル(グレー)
      if(e1 > e8)
         g_candleColor[i] = 0;  // Bull: 緑
      else if(e1 < e8)
         g_candleColor[i] = 1;  // Bear: 赤
      else
         g_candleColor[i] = 2;  // Neutral: グレー

      // シグナル初期化
      g_bullSignal[i] = EMPTY_VALUE;
      g_bearSignal[i] = EMPTY_VALUE;
   }

   // ═══════════════════════════════════════════════════════════════
   // COMPONENT B: MTF STRUCTURE DETECTION (BOS / MSS)
   // ═══════════════════════════════════════════════════════════════
   int lastBar = rates_total - 1;

   for(int tf = 0; tf < 3; tf++)
   {
      if(tf == 0 && !InpShow5min)  continue;
      if(tf == 1 && !InpShow15min) continue;
      if(tf == 2 && !InpShow1H)    continue;

      double ph = 0, pl = 0, cls = 0;
      GetMTFPivots(g_mtfPeriods[tf], InpSwingLookback, ph, pl, cls);

      bool bosBull = false, bosBear = false, mssBull = false, mssBear = false;
      UpdateStructure(tf, ph, pl, cls, bosBull, bosBear, mssBull, mssBear);

      // BOS/MSSラベル描画（重複防止）
      if(bosBull && g_lastBOS_Bull[tf] != lastBar)
      {
         g_lastBOS_Bull[tf] = lastBar;
         string tag = "BOS_Bull_" + g_mtfLabels[tf] + "_" + IntegerToString(lastBar);
         CreateBOSLabel(tag, time[lastBar], low[lastBar],
                       "BOS\n" + g_mtfLabels[tf],
                       C'0,230,118', false);
      }

      if(bosBear && g_lastBOS_Bear[tf] != lastBar)
      {
         g_lastBOS_Bear[tf] = lastBar;
         string tag = "BOS_Bear_" + g_mtfLabels[tf] + "_" + IntegerToString(lastBar);
         CreateBOSLabel(tag, time[lastBar], high[lastBar],
                       "BOS\n" + g_mtfLabels[tf],
                       C'255,82,82', true);
      }

      if(mssBull && g_lastMSS_Bull[tf] != lastBar)
      {
         g_lastMSS_Bull[tf] = lastBar;
         string tag = "MSS_Bull_" + g_mtfLabels[tf] + "_" + IntegerToString(lastBar);
         CreateBOSLabel(tag, time[lastBar], low[lastBar],
                       "MSS\n" + g_mtfLabels[tf],
                       C'0,191,165', false);
      }

      if(mssBear && g_lastMSS_Bear[tf] != lastBar)
      {
         g_lastMSS_Bear[tf] = lastBar;
         string tag = "MSS_Bear_" + g_mtfLabels[tf] + "_" + IntegerToString(lastBar);
         CreateBOSLabel(tag, time[lastBar], high[lastBar],
                       "MSS\n" + g_mtfLabels[tf],
                       C'255,64,129', true);
      }
   }

   // ═══════════════════════════════════════════════════════════════
   // COMPONENT C: BULL / BEAR TREND CHANGE SIGNALS
   // ═══════════════════════════════════════════════════════════════
   int bullCount = 0, bearCount = 0;
   for(int tf = 0; tf < 3; tf++)
   {
      if(g_structState[tf].trend == 1)  bullCount++;
      if(g_structState[tf].trend == -1) bearCount++;
   }

   // EMAリボン状態
   double ema1Last = g_emaD0[lastBar];
   double ema8Last = g_emaD7[lastBar];
   bool ribbonBull = (ema1Last > ema8Last);

   // 複合確認
   bool allBull = (bullCount >= InpTrendConfirm) && ribbonBull;
   bool allBear = (bearCount >= InpTrendConfirm) && !ribbonBull;

   int newTrend = allBull ? 1 : (allBear ? -1 : g_masterTrend);

   bool isBullSignal = (newTrend == 1 && g_masterTrend != 1);
   bool isBearSignal = (newTrend == -1 && g_masterTrend != -1);

   g_masterTrend = newTrend;

   if(isBullSignal)
      g_bullSignal[lastBar] = low[lastBar];

   if(isBearSignal)
      g_bearSignal[lastBar] = high[lastBar];

   // ═══════════════════════════════════════════════════════════════
   // COMPONENT D: HORIZONTAL KEY LEVELS
   // ═══════════════════════════════════════════════════════════════
   if(InpShowLevels)
   {
      int pivotBar = lastBar - InpSwingLookback;
      if(pivotBar >= InpSwingLookback)
      {
         double curPH = PivotHigh(high, pivotBar, InpSwingLookback, InpSwingLookback, rates_total);
         double curPL = PivotLow(low, pivotBar, InpSwingLookback, InpSwingLookback, rates_total);

         if(curPH > 0)
         {
            datetime startT = time[pivotBar];
            int endIdx = pivotBar + InpLevelExtend;
            datetime endT;
            if(endIdx <= lastBar)
               endT = time[endIdx];
            else
               endT = time[lastBar] + (datetime)((endIdx - lastBar) * PeriodSeconds());
            CreateKeyLevel(true, curPH, startT, endT);
         }

         if(curPL > 0)
         {
            datetime startT = time[pivotBar];
            int endIdx = pivotBar + InpLevelExtend;
            datetime endT;
            if(endIdx <= lastBar)
               endT = time[endIdx];
            else
               endT = time[lastBar] + (datetime)((endIdx - lastBar) * PeriodSeconds());
            CreateKeyLevel(false, curPL, startT, endT);
         }
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
