//+------------------------------------------------------------------+
//| TimeDilationTrendVisualizer.mq5                                  |
//| Pine Script - Time Dilation Trend Visualizer [EZPZ]              |
//| Components: EMA Ribbon, MTF Structure (BOS/MSS),                 |
//|             BULL/BEAR Signals, Key Levels, Candle Coloring       |
//+------------------------------------------------------------------+
#property copyright "Time Dilation Trend Visualizer [EZPZ]"
#property link      ""
#property version   "1.00"
#property indicator_chart_window

#property indicator_buffers 21
#property indicator_plots   10

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

#property indicator_label8  "BULL"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  C'0,230,118'
#property indicator_style8  STYLE_SOLID
#property indicator_width8  4

#property indicator_label9  "BEAR"
#property indicator_type9   DRAW_ARROW
#property indicator_color9  C'255,23,68'
#property indicator_style9  STYLE_SOLID
#property indicator_width9  4

#property indicator_label10 "ColorCandle"
#property indicator_type10  DRAW_COLOR_CANDLES
#property indicator_color10 C'0,230,118',C'255,82,82',C'96,96,96'
#property indicator_style10 STYLE_SOLID
#property indicator_width10 1

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "===== MA Ribbon Settings ====="
input int    InpEMA1  = 5;
input int    InpEMA2  = 8;
input int    InpEMA3  = 13;
input int    InpEMA4  = 21;
input int    InpEMA5  = 34;
input int    InpEMA6  = 55;
input int    InpEMA7  = 89;
input int    InpEMA8  = 144;

input group "===== Structure Detection ====="
input int    InpSwingLookback = 10;
input bool   InpShow5min      = true;
input bool   InpShow15min     = true;
input bool   InpShow1H        = true;

input group "===== BULL/BEAR Signal ====="
input int    InpTrendConfirm  = 2;

input group "===== Key Level ====="
input bool   InpShowLevels    = true;
input int    InpMaxLevels     = 3;
input int    InpLevelExtend   = 50;

//+------------------------------------------------------------------+
//| Global Variables                                                   |
//+------------------------------------------------------------------+
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

double g_bullSignal[];
double g_bearSignal[];

double g_candleOpen[];
double g_candleHigh[];
double g_candleLow[];
double g_candleClose[];
double g_candleColor[];

int g_hEMA[8];

double g_emaD0[];
double g_emaD1[];
double g_emaD2[];
double g_emaD3[];
double g_emaD4[];
double g_emaD5[];
double g_emaD6[];
double g_emaD7[];

ENUM_TIMEFRAMES g_mtfPeriods[3];
string g_mtfLabels[3];

struct StructureState
{
   double prevSH;
   double prevSL;
   double lastSH;
   double lastSL;
   int    trend;
};

StructureState g_structState[3];
int g_masterTrend;

string g_prefix;
int    g_highLevelCount;
int    g_lowLevelCount;
string g_highLevelNames[];
string g_lowLevelNames[];

int g_lastBOS_Bull[3];
int g_lastBOS_Bear[3];
int g_lastMSS_Bull[3];
int g_lastMSS_Bear[3];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   g_prefix = "TDTV_";
   g_mtfPeriods[0] = PERIOD_M5;
   g_mtfPeriods[1] = PERIOD_M15;
   g_mtfPeriods[2] = PERIOD_H1;
   g_mtfLabels[0] = "5Min";
   g_mtfLabels[1] = "15Min";
   g_mtfLabels[2] = "1H";

   SetIndexBuffer(0,  g_ema1,        INDICATOR_DATA);
   SetIndexBuffer(1,  g_ema2a,       INDICATOR_DATA);
   SetIndexBuffer(2,  g_ema2b,       INDICATOR_DATA);
   SetIndexBuffer(3,  g_ema3a,       INDICATOR_DATA);
   SetIndexBuffer(4,  g_ema3b,       INDICATOR_DATA);
   SetIndexBuffer(5,  g_ema4a,       INDICATOR_DATA);
   SetIndexBuffer(6,  g_ema4b,       INDICATOR_DATA);
   SetIndexBuffer(7,  g_ema5a,       INDICATOR_DATA);
   SetIndexBuffer(8,  g_ema5b,       INDICATOR_DATA);
   SetIndexBuffer(9,  g_ema6a,       INDICATOR_DATA);
   SetIndexBuffer(10, g_ema6b,       INDICATOR_DATA);
   SetIndexBuffer(11, g_ema7a,       INDICATOR_DATA);
   SetIndexBuffer(12, g_ema7b,       INDICATOR_DATA);
   SetIndexBuffer(13, g_ema8,        INDICATOR_DATA);
   SetIndexBuffer(14, g_bullSignal,  INDICATOR_DATA);
   SetIndexBuffer(15, g_bearSignal,  INDICATOR_DATA);
   SetIndexBuffer(16, g_candleOpen,  INDICATOR_DATA);
   SetIndexBuffer(17, g_candleHigh,  INDICATOR_DATA);
   SetIndexBuffer(18, g_candleLow,   INDICATOR_DATA);
   SetIndexBuffer(19, g_candleClose, INDICATOR_DATA);
   SetIndexBuffer(20, g_candleColor, INDICATOR_COLOR_INDEX);

   PlotIndexSetInteger(7, PLOT_ARROW, 159);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(8, PLOT_ARROW, 159);
   PlotIndexSetDouble(8, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   int lengths[8];
   lengths[0] = InpEMA1;
   lengths[1] = InpEMA2;
   lengths[2] = InpEMA3;
   lengths[3] = InpEMA4;
   lengths[4] = InpEMA5;
   lengths[5] = InpEMA6;
   lengths[6] = InpEMA7;
   lengths[7] = InpEMA8;

   for(int i = 0; i < 8; i++)
   {
      g_hEMA[i] = iMA(_Symbol, PERIOD_CURRENT, lengths[i], 0, MODE_EMA, PRICE_CLOSE);
      if(g_hEMA[i] == INVALID_HANDLE)
      {
         Print("EMA handle creation failed: ", lengths[i]);
         return(INIT_FAILED);
      }
   }

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
//| Custom indicator deinitialization function                         |
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
//| PivotHigh                                                          |
//+------------------------------------------------------------------+
double PivotHigh(const double &arr[], int bar, int left, int right, int total)
{
   if(bar - left < 0 || bar + right >= total)
      return(0.0);
   double val = arr[bar];
   for(int i = 1; i <= left; i++)
      if(arr[bar - i] >= val) return(0.0);
   for(int i = 1; i <= right; i++)
      if(arr[bar + i] >= val) return(0.0);
   return(val);
}

//+------------------------------------------------------------------+
//| PivotLow                                                           |
//+------------------------------------------------------------------+
double PivotLow(const double &arr[], int bar, int left, int right, int total)
{
   if(bar - left < 0 || bar + right >= total)
      return(0.0);
   double val = arr[bar];
   for(int i = 1; i <= left; i++)
      if(arr[bar - i] <= val) return(0.0);
   for(int i = 1; i <= right; i++)
      if(arr[bar + i] <= val) return(0.0);
   return(val);
}

//+------------------------------------------------------------------+
//| GetMTFPivots                                                       |
//+------------------------------------------------------------------+
void GetMTFPivots(ENUM_TIMEFRAMES tf, int lookback,
                  double &outPH, double &outPL, double &outClose)
{
   outPH    = 0.0;
   outPL    = 0.0;
   outClose = 0.0;

   int need = lookback * 2 + 5;
   double highs[];
   double lows[];
   double closes[];
   ArraySetAsSeries(highs, false);
   ArraySetAsSeries(lows, false);
   ArraySetAsSeries(closes, false);

   int cH = CopyHigh(_Symbol, tf, 0, need, highs);
   int cL = CopyLow(_Symbol, tf, 0, need, lows);
   int cC = CopyClose(_Symbol, tf, 0, need, closes);

   if(cH < need || cL < need || cC < need)
      return;

   outClose = closes[cC - 1];

   int chk = cH - 1 - lookback;
   if(chk < lookback) return;

   outPH = PivotHigh(highs, chk, lookback, lookback, cH);
   outPL = PivotLow(lows, chk, lookback, lookback, cL);
}

//+------------------------------------------------------------------+
//| UpdateStructure                                                    |
//+------------------------------------------------------------------+
void UpdateStructure(int idx, double ph, double pl, double cls,
                     bool &bosBull, bool &bosBear,
                     bool &mssBull, bool &mssBear)
{
   bosBull = false;
   bosBear = false;
   mssBull = false;
   mssBear = false;

   if(ph > 0.0)
   {
      g_structState[idx].prevSH = g_structState[idx].lastSH;
      g_structState[idx].lastSH = ph;
   }
   if(pl > 0.0)
   {
      g_structState[idx].prevSL = g_structState[idx].lastSL;
      g_structState[idx].lastSL = pl;
   }

   double lSH = g_structState[idx].lastSH;
   double lSL = g_structState[idx].lastSL;
   double pSH = g_structState[idx].prevSH;
   double pSL = g_structState[idx].prevSL;

   if(lSH > 0.0 && pSH > 0.0 && lSL > 0.0 && pSL > 0.0)
   {
      if(lSH > pSH && lSL > pSL)
         g_structState[idx].trend = 1;
      else if(lSH < pSH && lSL < pSL)
         g_structState[idx].trend = -1;
   }

   int trend = g_structState[idx].trend;

   if(trend == 1  && lSH > 0.0 && cls > lSH) bosBull = true;
   if(trend == -1 && lSL > 0.0 && cls < lSL) bosBear = true;
   if(trend == -1 && lSH > 0.0 && cls > lSH) mssBull = true;
   if(trend == 1  && lSL > 0.0 && cls < lSL) mssBear = true;

   if(mssBull) g_structState[idx].trend = 1;
   if(mssBear) g_structState[idx].trend = -1;
}

//+------------------------------------------------------------------+
//| CreateBOSLabel                                                     |
//+------------------------------------------------------------------+
void CreateBOSLabel(string tag, datetime dt, double price,
                    string text, color clr, bool isAbove)
{
   string name = g_prefix + tag;
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_TEXT, 0, dt, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,
                    isAbove ? ANCHOR_LOWER : ANCHOR_UPPER);
}

//+------------------------------------------------------------------+
//| CreateKeyLevel                                                     |
//+------------------------------------------------------------------+
void CreateKeyLevel(bool isHigh, double price, datetime t1, datetime t2)
{
   string name;
   color  clr;

   if(isHigh)
   {
      g_highLevelCount++;
      name = g_prefix + "HL_" + IntegerToString(g_highLevelCount);
      clr  = C'0,229,255';
      int sz = ArraySize(g_highLevelNames);
      ArrayResize(g_highLevelNames, sz + 1);
      g_highLevelNames[sz] = name;
      while(ArraySize(g_highLevelNames) > InpMaxLevels)
      {
         ObjectDelete(0, g_highLevelNames[0]);
         int n = ArraySize(g_highLevelNames);
         for(int i = 0; i < n - 1; i++)
            g_highLevelNames[i] = g_highLevelNames[i + 1];
         ArrayResize(g_highLevelNames, n - 1);
      }
   }
   else
   {
      g_lowLevelCount++;
      name = g_prefix + "LL_" + IntegerToString(g_lowLevelCount);
      clr  = C'255,64,129';
      int sz = ArraySize(g_lowLevelNames);
      ArrayResize(g_lowLevelNames, sz + 1);
      g_lowLevelNames[sz] = name;
      while(ArraySize(g_lowLevelNames) > InpMaxLevels)
      {
         ObjectDelete(0, g_lowLevelNames[0]);
         int n = ArraySize(g_lowLevelNames);
         for(int i = 0; i < n - 1; i++)
            g_lowLevelNames[i] = g_lowLevelNames[i + 1];
         ArrayResize(g_lowLevelNames, n - 1);
      }
   }

   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                                |
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
   if(rates_total < InpEMA8 + 10)
      return(0);

   int start;
   if(prev_calculated == 0)
      start = 0;
   else
      start = prev_calculated - 1;

   //--- EMA data copy
   ArraySetAsSeries(g_emaD0, false);
   ArraySetAsSeries(g_emaD1, false);
   ArraySetAsSeries(g_emaD2, false);
   ArraySetAsSeries(g_emaD3, false);
   ArraySetAsSeries(g_emaD4, false);
   ArraySetAsSeries(g_emaD5, false);
   ArraySetAsSeries(g_emaD6, false);
   ArraySetAsSeries(g_emaD7, false);

   if(CopyBuffer(g_hEMA[0], 0, 0, rates_total, g_emaD0) < rates_total) return(0);
   if(CopyBuffer(g_hEMA[1], 0, 0, rates_total, g_emaD1) < rates_total) return(0);
   if(CopyBuffer(g_hEMA[2], 0, 0, rates_total, g_emaD2) < rates_total) return(0);
   if(CopyBuffer(g_hEMA[3], 0, 0, rates_total, g_emaD3) < rates_total) return(0);
   if(CopyBuffer(g_hEMA[4], 0, 0, rates_total, g_emaD4) < rates_total) return(0);
   if(CopyBuffer(g_hEMA[5], 0, 0, rates_total, g_emaD5) < rates_total) return(0);
   if(CopyBuffer(g_hEMA[6], 0, 0, rates_total, g_emaD6) < rates_total) return(0);
   if(CopyBuffer(g_hEMA[7], 0, 0, rates_total, g_emaD7) < rates_total) return(0);

   //--- COMPONENT A: EMA RIBBON + CANDLE COLORING
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

      g_ema1[i]  = e1;  g_ema2a[i] = e2;
      g_ema2b[i] = e2;  g_ema3a[i] = e3;
      g_ema3b[i] = e3;  g_ema4a[i] = e4;
      g_ema4b[i] = e4;  g_ema5a[i] = e5;
      g_ema5b[i] = e5;  g_ema6a[i] = e6;
      g_ema6b[i] = e6;  g_ema7a[i] = e7;
      g_ema7b[i] = e7;  g_ema8[i]  = e8;

      g_candleOpen[i]  = open[i];
      g_candleHigh[i]  = high[i];
      g_candleLow[i]   = low[i];
      g_candleClose[i] = close[i];

      if(e1 > e8)
         g_candleColor[i] = 0.0;
      else if(e1 < e8)
         g_candleColor[i] = 1.0;
      else
         g_candleColor[i] = 2.0;

      g_bullSignal[i] = EMPTY_VALUE;
      g_bearSignal[i] = EMPTY_VALUE;
   }

   //--- COMPONENT B: MTF STRUCTURE DETECTION
   int lastBar = rates_total - 1;

   for(int tf = 0; tf < 3; tf++)
   {
      if(tf == 0 && !InpShow5min)  continue;
      if(tf == 1 && !InpShow15min) continue;
      if(tf == 2 && !InpShow1H)    continue;

      double ph2 = 0.0;
      double pl2 = 0.0;
      double cls2 = 0.0;
      GetMTFPivots(g_mtfPeriods[tf], InpSwingLookback, ph2, pl2, cls2);

      bool bB = false;
      bool bBr = false;
      bool mB = false;
      bool mBr = false;
      UpdateStructure(tf, ph2, pl2, cls2, bB, bBr, mB, mBr);

      if(bB && g_lastBOS_Bull[tf] != lastBar)
      {
         g_lastBOS_Bull[tf] = lastBar;
         string tag = "BOS_Bu_" + g_mtfLabels[tf] + "_" + IntegerToString(lastBar);
         CreateBOSLabel(tag, time[lastBar], low[lastBar],
                       "BOS " + g_mtfLabels[tf], C'0,230,118', false);
      }
      if(bBr && g_lastBOS_Bear[tf] != lastBar)
      {
         g_lastBOS_Bear[tf] = lastBar;
         string tag = "BOS_Be_" + g_mtfLabels[tf] + "_" + IntegerToString(lastBar);
         CreateBOSLabel(tag, time[lastBar], high[lastBar],
                       "BOS " + g_mtfLabels[tf], C'255,82,82', true);
      }
      if(mB && g_lastMSS_Bull[tf] != lastBar)
      {
         g_lastMSS_Bull[tf] = lastBar;
         string tag = "MSS_Bu_" + g_mtfLabels[tf] + "_" + IntegerToString(lastBar);
         CreateBOSLabel(tag, time[lastBar], low[lastBar],
                       "MSS " + g_mtfLabels[tf], C'0,191,165', false);
      }
      if(mBr && g_lastMSS_Bear[tf] != lastBar)
      {
         g_lastMSS_Bear[tf] = lastBar;
         string tag = "MSS_Be_" + g_mtfLabels[tf] + "_" + IntegerToString(lastBar);
         CreateBOSLabel(tag, time[lastBar], high[lastBar],
                       "MSS " + g_mtfLabels[tf], C'255,64,129', true);
      }
   }

   //--- COMPONENT C: BULL / BEAR TREND CHANGE SIGNALS
   int bullCount = 0;
   int bearCount = 0;
   for(int tf = 0; tf < 3; tf++)
   {
      if(g_structState[tf].trend == 1)  bullCount++;
      if(g_structState[tf].trend == -1) bearCount++;
   }

   double ema1Last = g_emaD0[lastBar];
   double ema8Last = g_emaD7[lastBar];
   bool ribbonBull = (ema1Last > ema8Last);

   bool allBull = (bullCount >= InpTrendConfirm) && ribbonBull;
   bool allBear = (bearCount >= InpTrendConfirm) && !ribbonBull;

   int newTrend;
   if(allBull)
      newTrend = 1;
   else if(allBear)
      newTrend = -1;
   else
      newTrend = g_masterTrend;

   bool sigBull = (newTrend == 1 && g_masterTrend != 1);
   bool sigBear = (newTrend == -1 && g_masterTrend != -1);

   g_masterTrend = newTrend;

   if(sigBull)
      g_bullSignal[lastBar] = low[lastBar];
   if(sigBear)
      g_bearSignal[lastBar] = high[lastBar];

   //--- COMPONENT D: HORIZONTAL KEY LEVELS
   if(InpShowLevels)
   {
      int pivotBar = lastBar - InpSwingLookback;
      if(pivotBar >= InpSwingLookback)
      {
         double curPH = PivotHigh(high, pivotBar, InpSwingLookback, InpSwingLookback, rates_total);
         double curPL = PivotLow(low, pivotBar, InpSwingLookback, InpSwingLookback, rates_total);

         if(curPH > 0.0)
         {
            datetime st = time[pivotBar];
            int ei = pivotBar + InpLevelExtend;
            datetime et;
            if(ei <= lastBar)
               et = time[ei];
            else
               et = time[lastBar] + (datetime)((ei - lastBar) * PeriodSeconds());
            CreateKeyLevel(true, curPH, st, et);
         }
         if(curPL > 0.0)
         {
            datetime st = time[pivotBar];
            int ei = pivotBar + InpLevelExtend;
            datetime et;
            if(ei <= lastBar)
               et = time[ei];
            else
               et = time[lastBar] + (datetime)((ei - lastBar) * PeriodSeconds());
            CreateKeyLevel(false, curPL, st, et);
         }
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
