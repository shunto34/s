//+------------------------------------------------------------------+
//| TimeDilationTrendVisualizer.mq5                                  |
//| Pine Script - Time Dilation Trend Visualizer [EZPZ]              |
//| Components: EMA Ribbon, MTF Structure (BOS/MSS),                 |
//|             BULL/BEAR Signals, Key Levels, Candle Coloring        |
//+------------------------------------------------------------------+
#property copyright "Time Dilation Trend Visualizer [EZPZ]"
#property link      ""
#property version   "4.00"
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
#property indicator_type8   DRAW_ARROW
#property indicator_color8  C'0,220,120'
#property indicator_style8  STYLE_SOLID
#property indicator_width8  9

#property indicator_label9  "BEAR"
#property indicator_type9   DRAW_ARROW
#property indicator_color9  C'255,70,70'
#property indicator_style9  STYLE_SOLID
#property indicator_width9  9

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
input int    InpTrendConfirm = 2;
input bool   InpShowLevels   = true;
input int    InpMaxLevels    = 3;
input int    InpLevelExtend  = 50;
input bool   InpPushNotify   = false;
input bool   InpAlertSound   = true;

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
datetime g_lastNotifyTime = 0;

//--- Trend Status Panel handles (M5/M15/H1/H4)
ENUM_TIMEFRAMES g_trendTF[4];
string g_trendTFName[4];
int g_hTrendEMA20[4];
int g_hTrendEMA50[4];
int g_hTrendATR[4];

//--- Chart ATR handle for adaptive scoring
int g_hChartATR;

//+------------------------------------------------------------------+
int OnInit()
{
   g_prefix = "TDTV_";
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

   PlotIndexSetInteger(7, PLOT_ARROW, 159);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(8, PLOT_ARROW, 159);
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

   CreateUI();
   CreateWatermark();
   CreateMSSPanel();
   CreateTrendPanel();

   IndicatorSetString(INDICATOR_SHORTNAME, "[FAD]TimeDilationTrendVisualizer");
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
   ChartRedraw();
}

//+------------------------------------------------------------------+
void MakeButtonCorner(string name, string text, int x, int y, int w, int h,
                      ENUM_BASE_CORNER corner)
{
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
   ObjectSetString(0, nm, OBJPROP_TEXT, _Symbol + " " + tf + " | [FAD] TDTV");
   ObjectSetString(0, nm, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 22);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, C'50,50,60');
   ObjectSetInteger(0, nm, OBJPROP_BACK, true);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
void CreateMSSPanel()
{
   int px = 10, py = 190, pw = 165, ph = 175;

   string bg = g_prefix + "MSSBg";
   if(ObjectFind(0, bg) < 0)
   {
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, px);
      ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, py);
      ObjectSetInteger(0, bg, OBJPROP_XSIZE, pw);
      ObjectSetInteger(0, bg, OBJPROP_YSIZE, ph);
      ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'20,22,38');
      ObjectSetInteger(0, bg, OBJPROP_BORDER_COLOR, C'50,65,110');
      ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bg, OBJPROP_BACK, false);
      ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
   }

   // Title
   string tt = g_prefix + "MSSTitle";
   if(ObjectFind(0, tt) < 0)
   {
      ObjectCreate(0, tt, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, tt, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, tt, OBJPROP_XDISTANCE, px + 22);
      ObjectSetInteger(0, tt, OBJPROP_YDISTANCE, py - 8);
      ObjectSetString(0, tt, OBJPROP_TEXT, "MSS SCORE");
      ObjectSetString(0, tt, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, tt, OBJPROP_FONTSIZE, 11);
      ObjectSetInteger(0, tt, OBJPROP_COLOR, C'160,170,200');
      ObjectSetInteger(0, tt, OBJPROP_BACK, false);
      ObjectSetInteger(0, tt, OBJPROP_SELECTABLE, false);
   }

   // Score value (big number)
   string sv = g_prefix + "MSSScore";
   if(ObjectFind(0, sv) < 0)
   {
      ObjectCreate(0, sv, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, sv, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, sv, OBJPROP_XDISTANCE, px + 45);
      ObjectSetInteger(0, sv, OBJPROP_YDISTANCE, py - 42);
      ObjectSetString(0, sv, OBJPROP_TEXT, "---");
      ObjectSetString(0, sv, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, sv, OBJPROP_FONTSIZE, 28);
      ObjectSetInteger(0, sv, OBJPROP_COLOR, C'100,100,115');
      ObjectSetInteger(0, sv, OBJPROP_BACK, false);
      ObjectSetInteger(0, sv, OBJPROP_SELECTABLE, false);
   }

   // Direction label
   string dl = g_prefix + "MSSDir";
   if(ObjectFind(0, dl) < 0)
   {
      ObjectCreate(0, dl, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, dl, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, dl, OBJPROP_XDISTANCE, px + 30);
      ObjectSetInteger(0, dl, OBJPROP_YDISTANCE, py - 82);
      ObjectSetString(0, dl, OBJPROP_TEXT, "---");
      ObjectSetString(0, dl, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, dl, OBJPROP_FONTSIZE, 11);
      ObjectSetInteger(0, dl, OBJPROP_COLOR, C'100,100,115');
      ObjectSetInteger(0, dl, OBJPROP_BACK, false);
      ObjectSetInteger(0, dl, OBJPROP_SELECTABLE, false);
   }

   // TF dots row (M5 M15 H1)
   string tfLabels[3] = {"M5", "M15", "H1"};
   int dotX[3] = {px + 12, px + 60, px + 115};
   int dotY = py - 110;

   for(int i = 0; i < 3; i++)
   {
      string tfLbl = g_prefix + "MSSTF" + IntegerToString(i);
      if(ObjectFind(0, tfLbl) < 0)
      {
         ObjectCreate(0, tfLbl, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, tfLbl, OBJPROP_CORNER, CORNER_LEFT_LOWER);
         ObjectSetInteger(0, tfLbl, OBJPROP_XDISTANCE, dotX[i]);
         ObjectSetInteger(0, tfLbl, OBJPROP_YDISTANCE, dotY);
         ObjectSetString(0, tfLbl, OBJPROP_TEXT, tfLabels[i]);
         ObjectSetString(0, tfLbl, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, tfLbl, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, tfLbl, OBJPROP_COLOR, C'130,140,160');
         ObjectSetInteger(0, tfLbl, OBJPROP_BACK, false);
         ObjectSetInteger(0, tfLbl, OBJPROP_SELECTABLE, false);
      }

      string arrLbl = g_prefix + "MSSArr" + IntegerToString(i);
      if(ObjectFind(0, arrLbl) < 0)
      {
         ObjectCreate(0, arrLbl, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, arrLbl, OBJPROP_CORNER, CORNER_LEFT_LOWER);
         ObjectSetInteger(0, arrLbl, OBJPROP_XDISTANCE, dotX[i] + 5);
         ObjectSetInteger(0, arrLbl, OBJPROP_YDISTANCE, dotY - 22);
         ObjectSetString(0, arrLbl, OBJPROP_TEXT, CharToString(159));
         ObjectSetString(0, arrLbl, OBJPROP_FONT, "Wingdings");
         ObjectSetInteger(0, arrLbl, OBJPROP_FONTSIZE, 12);
         ObjectSetInteger(0, arrLbl, OBJPROP_COLOR, C'100,100,115');
         ObjectSetInteger(0, arrLbl, OBJPROP_BACK, false);
         ObjectSetInteger(0, arrLbl, OBJPROP_SELECTABLE, false);
      }
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

   // === A. MTF Alignment (max 35pt) ===
   if(t0 == dir) score += 10.0;
   if(t1 == dir) score += 12.0;
   if(t2 == dir) score += 13.0;
   if(t0 == dir && t1 == dir && t2 == dir) score += 8.0;
   if(score > 35.0) score = 35.0;

   // === B. EMA Structure (max 25pt) ===
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
      if(perfOrder) score += 12.0;

      // Ribbon squeeze expansion
      double curWidth = MathAbs(g_ed0[idx] - g_ed7[idx]);
      double minW = curWidth;
      int sqLook = MathMin(10, idx);
      for(int j = idx - sqLook; j < idx; j++)
         minW = MathMin(minW, MathAbs(g_ed0[j] - g_ed7[j]));
      if(curWidth > 0 && minW < curWidth * 0.5) score += 8.0;

      // EMA slope acceleration
      if(idx >= 5)
      {
         double slope1 = g_ed0[idx] - g_ed0[idx - 3];
         int backIdx = (idx - 6 >= 0) ? idx - 6 : 0;
         double slope2 = g_ed0[idx - 3] - g_ed0[backIdx];
         bool accel = isBull ? (slope1 > slope2 && slope1 > 0) : (slope1 < slope2 && slope1 < 0);
         if(accel) score += 5.0;
      }
   }

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

   // === E. Key Level Breakout (max 10pt) ===
   if(idx >= 20 && idx < total)
   {
      double hh = high[idx], ll = low[idx];
      for(int j = idx - 20; j < idx; j++)
      {
         if(high[j] > hh) hh = high[j];
         if(low[j] < ll) ll = low[j];
      }
      if(isBull && close[idx] >= hh) score += 5.0;
      if(!isBull && close[idx] <= ll) score += 5.0;

      // No pullback (momentum sustained)
      if(idx >= 3)
      {
         bool sustained = true;
         for(int j = idx - 2; j <= idx; j++)
         {
            if(isBull && close[j] < open[j]) { sustained = false; break; }
            if(!isBull && close[j] > open[j]) { sustained = false; break; }
         }
         if(sustained) score += 5.0;
      }
   }

   int finalScore = (int)MathMin(100.0, MathMax(0.0, score));
   return(finalScore);
}

void UpdateMSSPanel(int trend0, int trend1, int trend2,
                    const double &close[], const double &open[], const double &high[],
                    const double &low[], const long &tickVol[], int idx, int total)
{
   int trends[3];
   trends[0] = trend0; trends[1] = trend1; trends[2] = trend2;

   // Update TF direction dots
   for(int i = 0; i < 3; i++)
   {
      string arrLbl = g_prefix + "MSSArr" + IntegerToString(i);
      if(ObjectFind(0, arrLbl) < 0) continue;
      ObjectSetString(0, arrLbl, OBJPROP_TEXT, CharToString(159));
      ObjectSetString(0, arrLbl, OBJPROP_FONT, "Wingdings");
      ObjectSetInteger(0, arrLbl, OBJPROP_FONTSIZE, 12);
      if(trends[i] == 1) ObjectSetInteger(0, arrLbl, OBJPROP_COLOR, C'0,230,130');
      else if(trends[i] == -1) ObjectSetInteger(0, arrLbl, OBJPROP_COLOR, C'255,65,65');
      else ObjectSetInteger(0, arrLbl, OBJPROP_COLOR, C'100,100,115');
   }

   // Calculate AI score
   int score = CalcMSSScore(trend0, trend1, trend2, close, open, high, low, tickVol, idx, total);

   // Determine direction
   int buCnt = 0, beCnt = 0;
   if(trend0==1) buCnt++; if(trend0==-1) beCnt++;
   if(trend1==1) buCnt++; if(trend1==-1) beCnt++;
   if(trend2==1) buCnt++; if(trend2==-1) beCnt++;
   bool isBull = (buCnt >= beCnt);
   bool allAligned = (buCnt == 3 || beCnt == 3);

   // Update score display
   string sv = g_prefix + "MSSScore";
   if(ObjectFind(0, sv) >= 0)
   {
      ObjectSetString(0, sv, OBJPROP_TEXT, IntegerToString(score));
      // Color gradient based on score
      color scoreClr;
      if(score >= 80) scoreClr = isBull ? C'0,255,140' : C'255,60,60';
      else if(score >= 60) scoreClr = C'255,210,50';
      else if(score >= 40) scoreClr = C'160,170,190';
      else scoreClr = C'100,100,115';
      ObjectSetInteger(0, sv, OBJPROP_COLOR, scoreClr);
   }

   // Update direction label
   string dl = g_prefix + "MSSDir";
   if(ObjectFind(0, dl) >= 0)
   {
      string dirTxt;
      color dirClr;
      if(allAligned && isBull) { dirTxt = ">> BULLISH"; dirClr = C'0,230,130'; }
      else if(allAligned && !isBull) { dirTxt = "<< BEARISH"; dirClr = C'255,65,65'; }
      else if(buCnt > beCnt) { dirTxt = "> BULL BIAS"; dirClr = C'80,190,120'; }
      else if(beCnt > buCnt) { dirTxt = "< BEAR BIAS"; dirClr = C'210,90,90'; }
      else { dirTxt = "- NEUTRAL"; dirClr = C'130,130,145'; }
      ObjectSetString(0, dl, OBJPROP_TEXT, dirTxt);
      ObjectSetString(0, dl, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, dl, OBJPROP_COLOR, dirClr);
   }

   // Highlight box
   string bg = g_prefix + "MSSBg";
   string tt = g_prefix + "MSSTitle";
   if(ObjectFind(0, bg) < 0) return;

   if(score >= 80 && isBull)
   {
      ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'12,50,28');
      ObjectSetInteger(0, bg, OBJPROP_BORDER_COLOR, C'0,200,110');
      if(ObjectFind(0, tt) >= 0) ObjectSetInteger(0, tt, OBJPROP_COLOR, C'0,240,130');
   }
   else if(score >= 80 && !isBull)
   {
      ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'50,12,18');
      ObjectSetInteger(0, bg, OBJPROP_BORDER_COLOR, C'230,50,50');
      if(ObjectFind(0, tt) >= 0) ObjectSetInteger(0, tt, OBJPROP_COLOR, C'255,80,80');
   }
   else
   {
      ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'20,22,38');
      ObjectSetInteger(0, bg, OBJPROP_BORDER_COLOR, C'50,65,110');
      if(ObjectFind(0, tt) >= 0) ObjectSetInteger(0, tt, OBJPROP_COLOR, C'160,170,200');
   }
}

//+------------------------------------------------------------------+
void CreateTrendPanel()
{
   int px = 10, py = 190, pw = 175, ph = 160;

   string bg = g_prefix + "TrendBg";
   if(ObjectFind(0, bg) < 0)
   {
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
      ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, px);
      ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, py);
      ObjectSetInteger(0, bg, OBJPROP_XSIZE, pw);
      ObjectSetInteger(0, bg, OBJPROP_YSIZE, ph);
      ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'20,22,38');
      ObjectSetInteger(0, bg, OBJPROP_BORDER_COLOR, C'50,65,110');
      ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bg, OBJPROP_BACK, false);
      ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
   }

   string tt = g_prefix + "TrendTitle";
   if(ObjectFind(0, tt) < 0)
   {
      ObjectCreate(0, tt, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, tt, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
      ObjectSetInteger(0, tt, OBJPROP_XDISTANCE, px + 22);
      ObjectSetInteger(0, tt, OBJPROP_YDISTANCE, py - 8);
      ObjectSetString(0, tt, OBJPROP_TEXT, "TREND STATUS");
      ObjectSetString(0, tt, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, tt, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, tt, OBJPROP_COLOR, C'160,170,200');
      ObjectSetInteger(0, tt, OBJPROP_BACK, false);
      ObjectSetInteger(0, tt, OBJPROP_SELECTABLE, false);
   }

   // 4 rows: TF name + status
   int rowY[4] = {py - 38, py - 68, py - 98, py - 128};
   for(int i = 0; i < 4; i++)
   {
      string tfLbl = g_prefix + "TrTF" + IntegerToString(i);
      if(ObjectFind(0, tfLbl) < 0)
      {
         ObjectCreate(0, tfLbl, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, tfLbl, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
         ObjectSetInteger(0, tfLbl, OBJPROP_XDISTANCE, px + pw - 20);
         ObjectSetInteger(0, tfLbl, OBJPROP_YDISTANCE, rowY[i]);
         ObjectSetString(0, tfLbl, OBJPROP_TEXT, g_trendTFName[i]);
         ObjectSetString(0, tfLbl, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, tfLbl, OBJPROP_FONTSIZE, 11);
         ObjectSetInteger(0, tfLbl, OBJPROP_COLOR, C'190,200,220');
         ObjectSetInteger(0, tfLbl, OBJPROP_BACK, false);
         ObjectSetInteger(0, tfLbl, OBJPROP_SELECTABLE, false);
      }

      string stLbl = g_prefix + "TrSt" + IntegerToString(i);
      if(ObjectFind(0, stLbl) < 0)
      {
         ObjectCreate(0, stLbl, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, stLbl, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
         ObjectSetInteger(0, stLbl, OBJPROP_XDISTANCE, px + 18);
         ObjectSetInteger(0, stLbl, OBJPROP_YDISTANCE, rowY[i]);
         ObjectSetString(0, stLbl, OBJPROP_TEXT, "---");
         ObjectSetString(0, stLbl, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, stLbl, OBJPROP_FONTSIZE, 11);
         ObjectSetInteger(0, stLbl, OBJPROP_COLOR, C'100,100,115');
         ObjectSetInteger(0, stLbl, OBJPROP_BACK, false);
         ObjectSetInteger(0, stLbl, OBJPROP_SELECTABLE, false);
      }
   }
}

void UpdateTrendPanel()
{
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
         statusTxt = "STRONG UP";
         statusClr = C'0,220,100';
      }
      else if(ema20Above && normSlope > 0.02)
      {
         statusTxt = "UP";
         statusClr = C'80,200,120';
      }
      else if(!ema20Above && priceBelowEMA20 && normSlope < -0.15)
      {
         statusTxt = "STRONG DN";
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
   Print("TDTV Alert: ", msg);
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

      // Determine trend
      if(lastSH > 0 && prevSH > 0 && lastSL > 0 && prevSL > 0)
      {
         if(lastSH > prevSH && lastSL > prevSL) trend = 1;
         else if(lastSH < prevSH && lastSL < prevSL) trend = -1;
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

      g_ema1[i]=e1;   g_ema2a[i]=e2;
      g_ema2b[i]=e2;  g_ema3a[i]=e3;
      g_ema3b[i]=e3;  g_ema4a[i]=e4;
      g_ema4b[i]=e4;  g_ema5a[i]=e5;
      g_ema5b[i]=e5;  g_ema6a[i]=e6;
      g_ema6b[i]=e6;  g_ema7a[i]=e7;
      g_ema7b[i]=e7;  g_ema8[i]=e8;

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
         // Re-create UI after ObjectsDeleteAll
         CreateUI();
         CreateWatermark();
         CreateMSSPanel();
         CreateTrendPanel();
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

      //=== Phase 3: BULL/BEAR signals with S/A/B ranking ===
      int prevMaster = 0;
      int startSig = InpEMA8 + 10;

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

         // --- Signal scoring (S/A/B rank) ---
         if((nT == 1 && prevMaster != 1) || (nT == -1 && prevMaster != -1))
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

            // Rank: S(3-4), A(2), B(0-1)
            if(isBull)
            {
               g_bullSignal[i] = low[i];
               if(score >= 3)
                  CreateSignalLabel("SigBull" + IntegerToString(i),
                     time[i], low[i], "BULL \x2605", C'0,255,140', false, 12);
               else if(score == 2)
                  CreateSignalLabel("SigBull" + IntegerToString(i),
                     time[i], low[i], "BULL", C'0,220,120', false);
               // B rank: dot only, no text label
            }
            else
            {
               g_bearSignal[i] = high[i];
               if(score >= 3)
                  CreateSignalLabel("SigBear" + IntegerToString(i),
                     time[i], high[i], "BEAR \x2605", C'255,50,50', true, 12);
               else if(score == 2)
                  CreateSignalLabel("SigBear" + IntegerToString(i),
                     time[i], high[i], "BEAR", C'255,70,70', true);
               // B rank: dot only, no text label
            }

            // Alert on latest bar
            if(i == rates_total - 1 && prev_calculated > 0 && time[i] > g_lastNotifyTime)
            {
               g_lastNotifyTime = time[i];
               string rank = (score >= 3) ? "S" : (score == 2) ? "A" : "B";
               SendSignalAlert(isBull ? "BULL " + rank : "BEAR " + rank, close[i]);
            }
         }

         prevMaster = nT;
      }
      g_masterTrend = prevMaster;

      // Update MSS Score Panel + Trend Status Panel
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
      return;
   }

   if(id != CHARTEVENT_OBJECT_CLICK) return;

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
