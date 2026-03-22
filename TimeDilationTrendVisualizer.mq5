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

//--- Inputs
input int    InpEMA1  = 5;      // EMA 1 Length
input int    InpEMA2  = 8;      // EMA 2 Length
input int    InpEMA3  = 13;     // EMA 3 Length
input int    InpEMA4  = 21;     // EMA 4 Length
input int    InpEMA5  = 34;     // EMA 5 Length
input int    InpEMA6  = 55;     // EMA 6 Length
input int    InpEMA7  = 89;     // EMA 7 Length
input int    InpEMA8  = 144;    // EMA 8 Length
input int    InpSwingLookback = 10;  // Swing Lookback
input bool   InpShow5min  = true;    // Show 5min Structure
input bool   InpShow15min = true;    // Show 15min Structure
input bool   InpShow1H    = true;    // Show 1H Structure
input int    InpTrendConfirm = 2;    // Min TF Alignment (1-3)
input bool   InpShowLevels   = true; // Show Key Levels
input int    InpMaxLevels    = 3;    // Max Levels Per Side
input int    InpLevelExtend  = 50;   // Level Extend (bars)

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
//--- Candle color buffers (4 data + 1 color)
double g_candleO[];
double g_candleH[];
double g_candleL[];
double g_candleC[];
double g_candleClr[];
//--- EMA work arrays
double g_ed0[];
double g_ed1[];
double g_ed2[];
double g_ed3[];
double g_ed4[];
double g_ed5[];
double g_ed6[];
double g_ed7[];
//--- EMA handles
int g_hEMA[8];
//--- MTF
ENUM_TIMEFRAMES g_mtfTF[3];
string g_mtfName[3];
//--- Structure state (parallel arrays instead of struct)
double g_prevSH[3];
double g_prevSL[3];
double g_lastSH[3];
double g_lastSL[3];
int    g_trend[3];
//--- Master trend
int g_masterTrend;
//--- Key level management
string g_prefix;
int    g_hiLvlCnt;
int    g_loLvlCnt;
string g_hiNames[];
string g_loNames[];
//--- Duplicate prevention
int g_lBOSBu[3];
int g_lBOSBe[3];
int g_lMSSBu[3];
int g_lMSSBe[3];

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

   g_hEMA[0] = iMA(_Symbol, PERIOD_CURRENT, InpEMA1, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA[1] = iMA(_Symbol, PERIOD_CURRENT, InpEMA2, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA[2] = iMA(_Symbol, PERIOD_CURRENT, InpEMA3, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA[3] = iMA(_Symbol, PERIOD_CURRENT, InpEMA4, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA[4] = iMA(_Symbol, PERIOD_CURRENT, InpEMA5, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA[5] = iMA(_Symbol, PERIOD_CURRENT, InpEMA6, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA[6] = iMA(_Symbol, PERIOD_CURRENT, InpEMA7, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA[7] = iMA(_Symbol, PERIOD_CURRENT, InpEMA8, 0, MODE_EMA, PRICE_CLOSE);

   for(int i = 0; i < 8; i++)
   {
      if(g_hEMA[i] == INVALID_HANDLE)
         return(INIT_FAILED);
   }

   for(int i = 0; i < 3; i++)
   {
      g_prevSH[i] = 0.0;
      g_prevSL[i] = 0.0;
      g_lastSH[i] = 0.0;
      g_lastSL[i] = 0.0;
      g_trend[i]  = 0;
      g_lBOSBu[i] = -1;
      g_lBOSBe[i] = -1;
      g_lMSSBu[i] = -1;
      g_lMSSBe[i] = -1;
   }

   g_masterTrend = 0;
   g_hiLvlCnt = 0;
   g_loLvlCnt = 0;
   ArrayResize(g_hiNames, 0);
   ArrayResize(g_loNames, 0);

   IndicatorSetString(INDICATOR_SHORTNAME, "TDTV [EZPZ]");
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
void GetMTFPivots(ENUM_TIMEFRAMES tf, int lb,
                  double &oPH, double &oPL, double &oCls)
{
   oPH = 0.0; oPL = 0.0; oCls = 0.0;
   int need = lb * 2 + 5;
   double hi[], lo[], cl[];
   ArraySetAsSeries(hi, false);
   ArraySetAsSeries(lo, false);
   ArraySetAsSeries(cl, false);
   int cH = CopyHigh(_Symbol, tf, 0, need, hi);
   int cL = CopyLow(_Symbol, tf, 0, need, lo);
   int cC = CopyClose(_Symbol, tf, 0, need, cl);
   if(cH < need || cL < need || cC < need) return;
   oCls = cl[cC - 1];
   int chk = cH - 1 - lb;
   if(chk < lb) return;
   oPH = FindPivotHigh(hi, chk, lb, lb, cH);
   oPL = FindPivotLow(lo, chk, lb, lb, cL);
}

//+------------------------------------------------------------------+
void DoStructure(int idx, double ph, double pl, double cls,
                 bool &bBu, bool &bBe, bool &mBu, bool &mBe)
{
   bBu = false; bBe = false; mBu = false; mBe = false;
   if(ph > 0.0) { g_prevSH[idx] = g_lastSH[idx]; g_lastSH[idx] = ph; }
   if(pl > 0.0) { g_prevSL[idx] = g_lastSL[idx]; g_lastSL[idx] = pl; }
   double lh = g_lastSH[idx]; double ll = g_lastSL[idx];
   double ps = g_prevSH[idx]; double pl2 = g_prevSL[idx];
   if(lh > 0.0 && ps > 0.0 && ll > 0.0 && pl2 > 0.0)
   {
      if(lh > ps && ll > pl2) g_trend[idx] = 1;
      else if(lh < ps && ll < pl2) g_trend[idx] = -1;
   }
   int tr = g_trend[idx];
   if(tr == 1 && lh > 0.0 && cls > lh) bBu = true;
   if(tr == -1 && ll > 0.0 && cls < ll) bBe = true;
   if(tr == -1 && lh > 0.0 && cls > lh) mBu = true;
   if(tr == 1 && ll > 0.0 && cls < ll) mBe = true;
   if(mBu) g_trend[idx] = 1;
   if(mBe) g_trend[idx] = -1;
}

//+------------------------------------------------------------------+
void MakeBOSLabel(string tag, datetime dt, double pr,
                  string txt, color c, bool above)
{
   string nm = g_prefix + tag;
   if(ObjectFind(0, nm) >= 0) ObjectDelete(0, nm);
   ObjectCreate(0, nm, OBJ_TEXT, 0, dt, pr);
   ObjectSetString(0, nm, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, nm, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR, above ? ANCHOR_LOWER : ANCHOR_UPPER);
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
      c = C'0,229,255';
      int s = ArraySize(g_hiNames);
      ArrayResize(g_hiNames, s + 1);
      g_hiNames[s] = nm;
      while(ArraySize(g_hiNames) > InpMaxLevels)
      {
         ObjectDelete(0, g_hiNames[0]);
         int n = ArraySize(g_hiNames);
         for(int i = 0; i < n - 1; i++) g_hiNames[i] = g_hiNames[i+1];
         ArrayResize(g_hiNames, n - 1);
      }
   }
   else
   {
      g_loLvlCnt++;
      nm = g_prefix + "LL" + IntegerToString(g_loLvlCnt);
      c = C'255,64,129';
      int s = ArraySize(g_loNames);
      ArrayResize(g_loNames, s + 1);
      g_loNames[s] = nm;
      while(ArraySize(g_loNames) > InpMaxLevels)
      {
         ObjectDelete(0, g_loNames[0]);
         int n = ArraySize(g_loNames);
         for(int i = 0; i < n - 1; i++) g_loNames[i] = g_loNames[i+1];
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
//| NOTE: spread is const int& (NOT const long&) per MQL5 spec       |
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

   ArraySetAsSeries(g_ed0, false);
   ArraySetAsSeries(g_ed1, false);
   ArraySetAsSeries(g_ed2, false);
   ArraySetAsSeries(g_ed3, false);
   ArraySetAsSeries(g_ed4, false);
   ArraySetAsSeries(g_ed5, false);
   ArraySetAsSeries(g_ed6, false);
   ArraySetAsSeries(g_ed7, false);

   if(CopyBuffer(g_hEMA[0],0,0,rates_total,g_ed0)<rates_total) return(0);
   if(CopyBuffer(g_hEMA[1],0,0,rates_total,g_ed1)<rates_total) return(0);
   if(CopyBuffer(g_hEMA[2],0,0,rates_total,g_ed2)<rates_total) return(0);
   if(CopyBuffer(g_hEMA[3],0,0,rates_total,g_ed3)<rates_total) return(0);
   if(CopyBuffer(g_hEMA[4],0,0,rates_total,g_ed4)<rates_total) return(0);
   if(CopyBuffer(g_hEMA[5],0,0,rates_total,g_ed5)<rates_total) return(0);
   if(CopyBuffer(g_hEMA[6],0,0,rates_total,g_ed6)<rates_total) return(0);
   if(CopyBuffer(g_hEMA[7],0,0,rates_total,g_ed7)<rates_total) return(0);

   for(int i = start; i < rates_total; i++)
   {
      double e1=g_ed0[i]; double e2=g_ed1[i]; double e3=g_ed2[i]; double e4=g_ed3[i];
      double e5=g_ed4[i]; double e6=g_ed5[i]; double e7=g_ed6[i]; double e8=g_ed7[i];

      g_ema1[i]=e1;  g_ema2a[i]=e2;
      g_ema2b[i]=e2; g_ema3a[i]=e3;
      g_ema3b[i]=e3; g_ema4a[i]=e4;
      g_ema4b[i]=e4; g_ema5a[i]=e5;
      g_ema5b[i]=e5; g_ema6a[i]=e6;
      g_ema6b[i]=e6; g_ema7a[i]=e7;
      g_ema7b[i]=e7; g_ema8[i]=e8;

      g_candleO[i]=open[i];
      g_candleH[i]=high[i];
      g_candleL[i]=low[i];
      g_candleC[i]=close[i];
      if(e1>e8)      g_candleClr[i]=0.0;
      else if(e1<e8) g_candleClr[i]=1.0;
      else           g_candleClr[i]=2.0;

      g_bullSignal[i]=EMPTY_VALUE;
      g_bearSignal[i]=EMPTY_VALUE;
   }

   int lastBar = rates_total - 1;

   for(int tf=0; tf<3; tf++)
   {
      if(tf==0 && !InpShow5min)  continue;
      if(tf==1 && !InpShow15min) continue;
      if(tf==2 && !InpShow1H)    continue;

      double ph=0.0, pl=0.0, cls=0.0;
      GetMTFPivots(g_mtfTF[tf], InpSwingLookback, ph, pl, cls);

      bool bBu=false, bBe=false, mBu=false, mBe=false;
      DoStructure(tf, ph, pl, cls, bBu, bBe, mBu, mBe);

      if(bBu && g_lBOSBu[tf]!=lastBar)
      {
         g_lBOSBu[tf]=lastBar;
         MakeBOSLabel("BBu"+g_mtfName[tf]+IntegerToString(lastBar),
                      time[lastBar],low[lastBar],"BOS "+g_mtfName[tf],C'0,230,118',false);
      }
      if(bBe && g_lBOSBe[tf]!=lastBar)
      {
         g_lBOSBe[tf]=lastBar;
         MakeBOSLabel("BBe"+g_mtfName[tf]+IntegerToString(lastBar),
                      time[lastBar],high[lastBar],"BOS "+g_mtfName[tf],C'255,82,82',true);
      }
      if(mBu && g_lMSSBu[tf]!=lastBar)
      {
         g_lMSSBu[tf]=lastBar;
         MakeBOSLabel("MBu"+g_mtfName[tf]+IntegerToString(lastBar),
                      time[lastBar],low[lastBar],"MSS "+g_mtfName[tf],C'0,191,165',false);
      }
      if(mBe && g_lMSSBe[tf]!=lastBar)
      {
         g_lMSSBe[tf]=lastBar;
         MakeBOSLabel("MBe"+g_mtfName[tf]+IntegerToString(lastBar),
                      time[lastBar],high[lastBar],"MSS "+g_mtfName[tf],C'255,64,129',true);
      }
   }

   int buCnt=0, beCnt=0;
   for(int tf=0; tf<3; tf++)
   {
      if(g_trend[tf]==1)  buCnt++;
      if(g_trend[tf]==-1) beCnt++;
   }
   bool rBull = (g_ed0[lastBar] > g_ed7[lastBar]);
   bool aBull = (buCnt>=InpTrendConfirm) && rBull;
   bool aBear = (beCnt>=InpTrendConfirm) && !rBull;
   int nT;
   if(aBull) nT=1;
   else if(aBear) nT=-1;
   else nT=g_masterTrend;
   if(nT==1 && g_masterTrend!=1) g_bullSignal[lastBar]=low[lastBar];
   if(nT==-1 && g_masterTrend!=-1) g_bearSignal[lastBar]=high[lastBar];
   g_masterTrend=nT;

   if(InpShowLevels)
   {
      int pb=lastBar-InpSwingLookback;
      if(pb>=InpSwingLookback)
      {
         double cPH=FindPivotHigh(high,pb,InpSwingLookback,InpSwingLookback,rates_total);
         double cPL=FindPivotLow(low,pb,InpSwingLookback,InpSwingLookback,rates_total);
         if(cPH>0.0)
         {
            datetime s1=time[pb];
            int ei=pb+InpLevelExtend;
            datetime e1t;
            if(ei<=lastBar) e1t=time[ei];
            else e1t=time[lastBar]+(datetime)((ei-lastBar)*PeriodSeconds());
            MakeKeyLevel(true,cPH,s1,e1t);
         }
         if(cPL>0.0)
         {
            datetime s2=time[pb];
            int ei2=pb+InpLevelExtend;
            datetime e2t;
            if(ei2<=lastBar) e2t=time[ei2];
            else e2t=time[lastBar]+(datetime)((ei2-lastBar)*PeriodSeconds());
            MakeKeyLevel(false,cPL,s2,e2t);
         }
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
