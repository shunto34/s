//+------------------------------------------------------------------+
//| TimeDilationTrendVisualizer.mq5                                  |
//| Pine Script - Time Dilation Trend Visualizer [EZPZ]              |
//| Components: EMA Ribbon, MTF Structure (BOS/MSS),                 |
//|             BULL/BEAR Signals, Key Levels, Candle Coloring        |
//+------------------------------------------------------------------+
#property copyright "Time Dilation Trend Visualizer [EZPZ]"
#property link      ""
#property version   "3.10"
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
#property indicator_width8  5

#property indicator_label9  "BEAR"
#property indicator_type9   DRAW_ARROW
#property indicator_color9  C'255,70,70'
#property indicator_style9  STYLE_SOLID
#property indicator_width9  5

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

   CreateUI();
   CreateWatermark();

   IndicatorSetString(INDICATOR_SHORTNAME, "TDTV [FAD]");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, g_prefix);
   for(int i = 0; i < 8; i++)
      if(g_hEMA[i] != INVALID_HANDLE)
         IndicatorRelease(g_hEMA[i]);
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
   int x = 10, y = 20, w = 42, h = 24, gap = 2;
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
   ObjectSetString(0, nm, OBJPROP_TEXT, _Symbol + " " + tf + " | TDTV [FAD]");
   ObjectSetString(0, nm, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 22);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, C'50,50,60');
   ObjectSetInteger(0, nm, OBJPROP_BACK, true);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
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
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 7);
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
// Process one HTF timeframe: detect BOS/MSS, store trend per HTF bar
// Returns trend array mapped to chart bars
//+------------------------------------------------------------------+
void ProcessHTF(int tfIdx, int lb,
                const datetime &chartTime[], const double &chartHigh[],
                const double &chartLow[], int chartTotal,
                bool fullRecalc, double &barTrend[])
{
   ENUM_TIMEFRAMES period = g_mtfTF[tfIdx];
   int need = 3000;

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

   // Arrays for HTF bar trend
   double htfTrend[];
   ArrayResize(htfTrend, cnt);
   ArrayInitialize(htfTrend, 0.0);

   // Structure state
   double prevSH = 0, prevSL = 0, lastSH = 0, lastSL = 0;
   double lastSH_prev = 0, lastSL_prev = 0;
   int trend = 0;

   // Process all HTF bars chronologically
   for(int j = 0; j < cnt; j++)
   {
      // Check for confirmed pivot (pivot at j-lb, confirmed at j)
      double ph = 0, pl = 0;
      if(j >= 2 * lb)
      {
         ph = FindPivotHigh(htfH, j - lb, lb, lb, cnt);
         pl = FindPivotLow(htfL, j - lb, lb, lb, cnt);
      }

      // Update swing levels
      if(ph > 0) { prevSH = lastSH; lastSH = ph; }
      if(pl > 0) { prevSL = lastSL; lastSL = pl; }

      // Determine trend
      if(lastSH > 0 && prevSH > 0 && lastSL > 0 && prevSL > 0)
      {
         if(lastSH > prevSH && lastSL > prevSL) trend = 1;
         else if(lastSH < prevSH && lastSL < prevSL) trend = -1;
      }

      // Crossover detection (ta.crossover / ta.crossunder equivalent)
      bool bBu = false, bBe = false, mBu = false, mBe = false;

      if(j > 0)
      {
         double cls = htfC[j];
         double prevCls = htfC[j - 1];

         // crossover(close, lastSH): close > lastSH AND prevClose <= lastSH_prev
         bool crossOverSH = (lastSH > 0 && lastSH_prev > 0
                             && cls > lastSH && prevCls <= lastSH_prev);
         // crossunder(close, lastSL): close < lastSL AND prevClose >= lastSL_prev
         bool crossUnderSL = (lastSL > 0 && lastSL_prev > 0
                              && cls < lastSL && prevCls >= lastSL_prev);

         if(trend == 1 && crossOverSH)  bBu = true;
         if(trend == -1 && crossUnderSL) bBe = true;
         if(trend == -1 && crossOverSH) mBu = true;
         if(trend == 1 && crossUnderSL) mBe = true;
      }

      // Update trend on MSS
      if(mBu) trend = 1;
      if(mBe) trend = -1;

      htfTrend[j] = (double)trend;

      // Store for next iteration's crossover check
      lastSH_prev = lastSH;
      lastSL_prev = lastSL;

      // Create BOS/MSS labels (limit to recent bars)
      if(fullRecalc && j > cnt - 500)
      {
         // Find chart bar for this HTF bar time
         int cb = FindChartBar(chartTime, chartTotal, htfT[j]);
         string timeSuffix = IntegerToString((long)htfT[j]);
         string tfName = g_mtfName[tfIdx];

         if(bBu)
            CreateBOSLabel("BBu" + tfName + timeSuffix,
               chartTime[cb], chartLow[cb],
               "B", C'0,220,120', false);
         if(bBe)
            CreateBOSLabel("BBe" + tfName + timeSuffix,
               chartTime[cb], chartHigh[cb],
               "B", C'230,85,85', true);
         if(mBu)
            CreateBOSLabel("MBu" + tfName + timeSuffix,
               chartTime[cb], chartLow[cb],
               "M", C'0,185,150', false);
         if(mBe)
            CreateBOSLabel("MBe" + tfName + timeSuffix,
               chartTime[cb], chartHigh[cb],
               "M", C'220,90,130', true);
      }
      else if(!fullRecalc && j >= cnt - 3)
      {
         // Incremental: only check latest HTF bars
         int cb = FindChartBar(chartTime, chartTotal, htfT[j]);
         string timeSuffix = IntegerToString((long)htfT[j]);
         string tfName = g_mtfName[tfIdx];

         if(bBu)
            CreateBOSLabel("BBu" + tfName + timeSuffix,
               chartTime[cb], chartLow[cb],
               "B", C'0,220,120', false);
         if(bBe)
            CreateBOSLabel("BBe" + tfName + timeSuffix,
               chartTime[cb], chartHigh[cb],
               "B", C'230,85,85', true);
         if(mBu)
            CreateBOSLabel("MBu" + tfName + timeSuffix,
               chartTime[cb], chartLow[cb],
               "M", C'0,185,150', false);
         if(mBe)
            CreateBOSLabel("MBe" + tfName + timeSuffix,
               chartTime[cb], chartHigh[cb],
               "M", C'220,90,130', true);
      }
   }

   // Map HTF trend to chart bars using pointer advancement
   int htfPtr = 0;
   for(int i = 0; i < chartTotal; i++)
   {
      while(htfPtr + 1 < cnt && htfT[htfPtr + 1] <= chartTime[i])
         htfPtr++;
      barTrend[i] = htfTrend[htfPtr];
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

      //=== Phase 3: BULL/BEAR signals (historical) ===
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

         if(nT == 1 && prevMaster != 1)
         {
            g_bullSignal[i] = low[i];
            if(i == rates_total - 1 && prev_calculated > 0 && time[i] > g_lastNotifyTime)
            {
               g_lastNotifyTime = time[i];
               SendSignalAlert("BULL", close[i]);
            }
         }
         if(nT == -1 && prevMaster != -1)
         {
            g_bearSignal[i] = high[i];
            if(i == rates_total - 1 && prev_calculated > 0 && time[i] > g_lastNotifyTime)
            {
               g_lastNotifyTime = time[i];
               SendSignalAlert("BEAR", close[i]);
            }
         }

         prevMaster = nT;
      }
      g_masterTrend = prevMaster;

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
