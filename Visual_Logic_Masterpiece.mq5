//+------------------------------------------------------------------+
//| Visual_Logic_Masterpiece.mq5                                      |
//| v3.0 - 高精度サイン + 利確TP + LINE/Email通知 + 洗練UI             |
//+------------------------------------------------------------------+
#property copyright "Visual Logic Masterpiece v3.0"
#property link      ""
#property version   "3.00"
#property strict
#property indicator_chart_window

#property indicator_buffers 10
#property indicator_plots   8

//--- Plot 1: クラウド本体
#property indicator_label1  "CloudUpper;CloudLower"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  C'255,210,50',C'40,140,255'
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: クラウドグロー
#property indicator_label2  "GlowUpper;GlowLower"
#property indicator_type2   DRAW_FILLING
#property indicator_color2  C'255,220,80',C'60,160,255'
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: 買い矢印
#property indicator_label3  "BuyArrow"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  C'0,180,255'
#property indicator_style3  STYLE_SOLID
#property indicator_width3  3

//--- Plot 4: 売り矢印
#property indicator_label4  "SellArrow"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  C'255,55,55'
#property indicator_style4  STYLE_SOLID
#property indicator_width4  3

//--- Plot 5: 買い星
#property indicator_label5  "BuyStar"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  C'0,255,255'
#property indicator_style5  STYLE_SOLID
#property indicator_width5  4

//--- Plot 6: 売り星
#property indicator_label6  "SellStar"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  C'255,50,255'
#property indicator_style6  STYLE_SOLID
#property indicator_width6  4

//--- Plot 7: 買いTP到達
#property indicator_label7  "BuyTP"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  C'0,255,100'
#property indicator_style7  STYLE_SOLID
#property indicator_width7  3

//--- Plot 8: 売りTP到達
#property indicator_label8  "SellTP"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  C'0,255,100'
#property indicator_style8  STYLE_SOLID
#property indicator_width8  3

//+------------------------------------------------------------------+
//| 入力パラメーター                                                    |
//+------------------------------------------------------------------+
input group "===== クラウド設定 ====="
input int    InpFastEMA       = 21;
input int    InpSlowEMA       = 55;
input int    InpATRPeriod     = 14;
input double InpCloudWidth    = 0.2;
input double InpGlowWidth     = 0.35;

input group "===== 反転サイン（星）設定 ====="
input int    InpRSIPeriod     = 8;
input int    InpRSIBuyLevel   = 25;
input int    InpRSISellLevel  = 75;
input int    InpBBPeriod      = 20;
input double InpBBDeviation   = 2.5;
input int    InpWPRPeriod     = 14;
input double InpWPRBuyLevel   = -85.0;
input double InpWPRSellLevel  = -15.0;
input int    InpMinConditions = 3;       // 最小条件数（4条件中）

input group "===== 継続サイン（矢印）設定 ====="
input int    InpADXPeriod     = 14;
input double InpADXThreshold  = 20.0;

input group "===== 利確ターゲット設定 ====="
input double InpTPMultiplier  = 2.0;
input int    InpSwingLookback = 30;
input color  InpTPColor       = C'0,255,100';

input group "===== ダッシュボード設定 ====="
input color  InpBullColor     = C'0,170,255';
input color  InpBearColor     = C'255,60,60';
input int    InpDashFontSize  = 9;

input group "===== 通知設定 ====="
input bool   InpPushNotify    = false;    // プッシュ通知（MT5モバイル）
input bool   InpEmailNotify   = false;    // メール通知
input bool   InpLineNotify    = false;    // LINE通知
input string InpLineToken     = "";       // LINE Notifyトークン
input bool   InpAlertSound    = true;     // サウンドアラート

//+------------------------------------------------------------------+
//| グローバル変数                                                      |
//+------------------------------------------------------------------+
double g_cloudUpper[], g_cloudLower[];
double g_glowUpper[],  g_glowLower[];
double g_buyArrow[],   g_sellArrow[];
double g_buyStar[],    g_sellStar[];
double g_buyTP[],      g_sellTP[];

int g_handleFastEMA, g_handleSlowEMA, g_handleATR;
int g_handleRSI, g_handleBBUpper, g_handleWPR, g_handleADX;

int g_handleMTF_FastEMA[3], g_handleMTF_SlowEMA[3];
int g_handleMTF_RSI[3], g_handleMTF_ADX[3];

ENUM_TIMEFRAMES g_mtfPeriods[3] = {PERIOD_M5, PERIOD_M15, PERIOD_H1};
string g_mtfLabels[3] = {"5m", "15m", "1h"};

int    g_lastSignalDir = 0;
bool   g_tpActive      = false;
int    g_tpDir         = 0;
double g_tpPrice       = 0;
bool   g_indicatorON   = true;
string g_prefix        = "VLM_";
int    g_lastDashBar   = -1;
datetime g_lastNotifyTime = 0;

//+------------------------------------------------------------------+
//| OnInit                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, g_cloudUpper, INDICATOR_DATA);
   SetIndexBuffer(1, g_cloudLower, INDICATOR_DATA);
   SetIndexBuffer(2, g_glowUpper,  INDICATOR_DATA);
   SetIndexBuffer(3, g_glowLower,  INDICATOR_DATA);
   SetIndexBuffer(4, g_buyArrow,   INDICATOR_DATA);
   SetIndexBuffer(5, g_sellArrow,  INDICATOR_DATA);
   SetIndexBuffer(6, g_buyStar,    INDICATOR_DATA);
   SetIndexBuffer(7, g_sellStar,   INDICATOR_DATA);
   SetIndexBuffer(8, g_buyTP,      INDICATOR_DATA);
   SetIndexBuffer(9, g_sellTP,     INDICATOR_DATA);

   PlotIndexSetInteger(2, PLOT_ARROW, 233);
   PlotIndexSetInteger(3, PLOT_ARROW, 234);
   PlotIndexSetInteger(4, PLOT_ARROW, 171);
   PlotIndexSetInteger(5, PLOT_ARROW, 171);
   PlotIndexSetInteger(6, PLOT_ARROW, 174);
   PlotIndexSetInteger(7, PLOT_ARROW, 174);

   for(int p = 2; p <= 7; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   g_handleFastEMA = iMA(_Symbol, PERIOD_CURRENT, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_handleSlowEMA = iMA(_Symbol, PERIOD_CURRENT, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_handleATR     = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   g_handleRSI     = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   g_handleBBUpper = iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   g_handleWPR     = iWPR(_Symbol, PERIOD_CURRENT, InpWPRPeriod);
   g_handleADX     = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);

   if(g_handleFastEMA==INVALID_HANDLE || g_handleSlowEMA==INVALID_HANDLE ||
      g_handleATR==INVALID_HANDLE || g_handleRSI==INVALID_HANDLE ||
      g_handleBBUpper==INVALID_HANDLE || g_handleWPR==INVALID_HANDLE ||
      g_handleADX==INVALID_HANDLE)
   {
      Print("エラー: ハンドル作成失敗");
      return(INIT_FAILED);
   }

   for(int i=0; i<3; i++)
   {
      g_handleMTF_FastEMA[i] = iMA(_Symbol, g_mtfPeriods[i], InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
      g_handleMTF_SlowEMA[i] = iMA(_Symbol, g_mtfPeriods[i], InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
      g_handleMTF_RSI[i]     = iRSI(_Symbol, g_mtfPeriods[i], 14, PRICE_CLOSE);
      g_handleMTF_ADX[i]     = iADX(_Symbol, g_mtfPeriods[i], InpADXPeriod);
      if(g_handleMTF_FastEMA[i]==INVALID_HANDLE || g_handleMTF_SlowEMA[i]==INVALID_HANDLE ||
         g_handleMTF_RSI[i]==INVALID_HANDLE || g_handleMTF_ADX[i]==INVALID_HANDLE)
      { Print("MTFハンドル作成失敗: ",g_mtfLabels[i]); return(INIT_FAILED); }
   }

   CreateUIElements();
   EventSetTimer(1);
   IndicatorSetString(INDICATOR_SHORTNAME, "VLM v3");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, g_prefix);
   IndicatorRelease(g_handleFastEMA); IndicatorRelease(g_handleSlowEMA);
   IndicatorRelease(g_handleATR);     IndicatorRelease(g_handleRSI);
   IndicatorRelease(g_handleBBUpper); IndicatorRelease(g_handleWPR);
   IndicatorRelease(g_handleADX);
   for(int i=0;i<3;i++)
   {
      IndicatorRelease(g_handleMTF_FastEMA[i]); IndicatorRelease(g_handleMTF_SlowEMA[i]);
      IndicatorRelease(g_handleMTF_RSI[i]);     IndicatorRelease(g_handleMTF_ADX[i]);
   }
   EventKillTimer();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| IsMTFAligned - MTF方向整合性チェック（v3新機能）                      |
//+------------------------------------------------------------------+
bool IsMTFAligned(bool isBuy)
{
   int alignCount = 0;
   for(int tf=0; tf<3; tf++)
   {
      double fast[1], slow[1];
      if(CopyBuffer(g_handleMTF_FastEMA[tf], 0, 0, 1, fast) <= 0) continue;
      if(CopyBuffer(g_handleMTF_SlowEMA[tf], 0, 0, 1, slow) <= 0) continue;
      if(isBuy  && fast[0] > slow[0]) alignCount++;
      if(!isBuy && fast[0] < slow[0]) alignCount++;
   }
   return (alignCount >= 2);
}

//+------------------------------------------------------------------+
//| CalculateOptimalTP - 最適利確価格の算出                              |
//+------------------------------------------------------------------+
double CalculateOptimalTP(bool isBuy, double entryPrice, double atrVal,
                          const double &high[], const double &low[],
                          double bbUp, double bbLow, int bar, int lookback)
{
   double tp = 0;
   if(isBuy)
   {
      double atrT = entryPrice + atrVal * InpTPMultiplier;
      double rHigh = entryPrice;
      for(int j=MathMax(0,bar-lookback); j<bar; j++)
         if(j<ArraySize(high) && high[j]>rHigh) rHigh=high[j];
      if(rHigh > entryPrice+atrVal*0.5 && rHigh <= entryPrice+atrVal*3.0)
         tp = rHigh;
      else if(bbUp > entryPrice+atrVal*0.5)
         tp = (atrT + bbUp) / 2.0;
      else
         tp = atrT;
      tp = MathMax(tp, entryPrice + atrVal*1.0);
      tp = MathMin(tp, entryPrice + atrVal*3.0);
   }
   else
   {
      double atrT = entryPrice - atrVal * InpTPMultiplier;
      double rLow = entryPrice;
      for(int j=MathMax(0,bar-lookback); j<bar; j++)
         if(j<ArraySize(low) && low[j]<rLow) rLow=low[j];
      if(rLow < entryPrice-atrVal*0.5 && rLow >= entryPrice-atrVal*3.0)
         tp = rLow;
      else if(bbLow < entryPrice-atrVal*0.5)
         tp = (atrT + bbLow) / 2.0;
      else
         tp = atrT;
      tp = MathMin(tp, entryPrice - atrVal*1.0);
      tp = MathMax(tp, entryPrice - atrVal*3.0);
   }
   return tp;
}

//+------------------------------------------------------------------+
//| SendSignalAlert - 全チャネル通知送信（v3新機能）                      |
//+------------------------------------------------------------------+
void SendSignalAlert(string signalType, string direction, double price, double tpPrice)
{
   string tf = EnumToString(Period());
   StringReplace(tf, "PERIOD_", "");
   string msg = StringFormat("[%s] %s %s @ %s | TP: %s | %s %s",
                _Symbol, direction, signalType,
                DoubleToString(price, _Digits),
                DoubleToString(tpPrice, _Digits),
                tf, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));

   // スクリーンショット保存
   string fname = "VLM_" + _Symbol + "_" + tf + "_" +
                  TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + ".png";
   StringReplace(fname, ":", "-");
   StringReplace(fname, " ", "_");
   StringReplace(fname, ".", "_");
   fname = fname + ".png";
   ChartScreenShot(0, fname, 1920, 1080);

   // サウンド
   if(InpAlertSound)
      PlaySound("alert.wav");

   // MT5ポップアップ
   Alert(msg);

   // プッシュ通知
   if(InpPushNotify)
      SendNotification(msg);

   // メール
   if(InpEmailNotify)
      SendMail("VLM Signal: " + direction + " " + _Symbol, msg);

   // LINE Notify
   if(InpLineNotify && InpLineToken != "")
      SendLineNotify(msg);

   Print("Signal Alert: ", msg);
}

//+------------------------------------------------------------------+
//| SendLineNotify - LINE通知送信                                       |
//+------------------------------------------------------------------+
bool SendLineNotify(string message)
{
   string url = "https://notify-api.line.me/api/notify";
   string headers = "Authorization: Bearer " + InpLineToken + "\r\n"
                  + "Content-Type: application/x-www-form-urlencoded\r\n";

   char post[], result[];
   string resultHeaders;
   string data = "message=" + message;

   int len = StringToCharArray(data, post, 0, WHOLE_ARRAY, CP_UTF8);
   if(len > 0) ArrayResize(post, len - 1);

   ResetLastError();
   int res = WebRequest("POST", url, headers, 5000, post, result, resultHeaders);

   if(res == -1)
   {
      int err = GetLastError();
      if(err == 4014)
         Print("LINE通知: WebRequest未許可。ツール→オプション→EA で https://notify-api.line.me を追加してください");
      else
         Print("LINE通知エラー: ", err);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| OnCalculate - メインループ（v3: 高精度フィルター付き）                 |
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
   if(rates_total < InpSlowEMA + 10) return(0);

   if(prev_calculated == 0)
   {
      g_lastSignalDir = 0;
      g_tpActive = false;
      g_tpPrice = 0;
      g_tpDir = 0;
   }

   double fastEMA[], slowEMA[], atr[];
   double rsi[], bbUpper[], bbLower[], bbMiddle[];
   double wpr[], adxMain[], adxPlus[], adxMinus[];

   int startBar = (prev_calculated > 1) ? prev_calculated - 1 : 0;

   if(CopyBuffer(g_handleFastEMA,0,0,rates_total,fastEMA)<=0) return(0);
   if(CopyBuffer(g_handleSlowEMA,0,0,rates_total,slowEMA)<=0) return(0);
   if(CopyBuffer(g_handleATR,    0,0,rates_total,atr)    <=0) return(0);
   if(CopyBuffer(g_handleRSI,    0,0,rates_total,rsi)    <=0) return(0);
   if(CopyBuffer(g_handleBBUpper,1,0,rates_total,bbUpper)<=0) return(0);
   if(CopyBuffer(g_handleBBUpper,2,0,rates_total,bbLower)<=0) return(0);
   if(CopyBuffer(g_handleBBUpper,0,0,rates_total,bbMiddle)<=0)return(0);
   if(CopyBuffer(g_handleWPR,    0,0,rates_total,wpr)    <=0) return(0);
   if(CopyBuffer(g_handleADX,    0,0,rates_total,adxMain)<=0) return(0);
   if(CopyBuffer(g_handleADX,    1,0,rates_total,adxPlus)<=0) return(0);
   if(CopyBuffer(g_handleADX,    2,0,rates_total,adxMinus)<=0)return(0);

   for(int i = startBar; i < rates_total; i++)
   {
      if(i < InpSlowEMA + 5) continue;

      double atrVal = atr[i];
      bool isBull = (fastEMA[i] > slowEMA[i]);

      //=== クラウド ===
      g_cloudUpper[i] = MathMax(fastEMA[i],slowEMA[i]) + InpCloudWidth * atrVal;
      g_cloudLower[i] = MathMin(fastEMA[i],slowEMA[i]) - InpCloudWidth * atrVal;
      g_glowUpper[i]  = MathMax(fastEMA[i],slowEMA[i]) + InpGlowWidth * atrVal;
      g_glowLower[i]  = MathMin(fastEMA[i],slowEMA[i]) - InpGlowWidth * atrVal;

      //=== TP到達チェック ===
      g_buyTP[i] = EMPTY_VALUE;
      g_sellTP[i] = EMPTY_VALUE;
      if(g_tpActive)
      {
         if(g_tpDir==1 && high[i]>=g_tpPrice)
         { g_buyTP[i]=g_tpPrice; g_tpActive=false; }
         else if(g_tpDir==-1 && low[i]<=g_tpPrice)
         { g_sellTP[i]=g_tpPrice; g_tpActive=false; }
      }

      //=== 星サイン（反転） v3: ローソク足確認+事前トレンド追加 ===
      g_buyStar[i] = EMPTY_VALUE;
      g_sellStar[i] = EMPTY_VALUE;

      if(i >= 5)
      {
         int buyCnt=0, sellCnt=0;

         if(rsi[i]>InpRSIBuyLevel && rsi[i-1]<=InpRSIBuyLevel) buyCnt++;
         if(low[i]<=bbLower[i]) buyCnt++;
         if(wpr[i]<InpWPRBuyLevel) buyCnt++;
         if(low[i-1]<=low[i-2] && low[i-1]<=low[i]) buyCnt++;

         if(rsi[i]<InpRSISellLevel && rsi[i-1]>=InpRSISellLevel) sellCnt++;
         if(high[i]>=bbUpper[i]) sellCnt++;
         if(wpr[i]>InpWPRSellLevel) sellCnt++;
         if(high[i-1]>=high[i-2] && high[i-1]>=high[i]) sellCnt++;

         double starOff = atrVal * 0.5;

         // v3: 買い星 - 陽線確認 + 事前下落確認
         if(buyCnt >= InpMinConditions && g_lastSignalDir != 1)
         {
            bool candleOK = (close[i] > open[i]);        // 陽線
            bool priorDown = (close[i] < close[i-5]);    // 直近5本で下落
            if(candleOK && priorDown)
            {
               g_buyStar[i] = low[i] - starOff;
               g_lastSignalDir = 1;
               g_tpActive=true; g_tpDir=1;
               g_tpPrice = CalculateOptimalTP(true,close[i],atrVal,high,low,bbUpper[i],bbLower[i],i,InpSwingLookback);
               if(i==rates_total-1 && prev_calculated>0 && time[i]>g_lastNotifyTime)
               { g_lastNotifyTime=time[i]; SendSignalAlert("Star","BUY",close[i],g_tpPrice); }
            }
         }
         // v3: 売り星 - 陰線確認 + 事前上昇確認
         else if(sellCnt >= InpMinConditions && g_lastSignalDir != -1)
         {
            bool candleOK = (close[i] < open[i]);        // 陰線
            bool priorUp = (close[i] > close[i-5]);      // 直近5本で上昇
            if(candleOK && priorUp)
            {
               g_sellStar[i] = high[i] + starOff;
               g_lastSignalDir = -1;
               g_tpActive=true; g_tpDir=-1;
               g_tpPrice = CalculateOptimalTP(false,close[i],atrVal,high,low,bbUpper[i],bbLower[i],i,InpSwingLookback);
               if(i==rates_total-1 && prev_calculated>0 && time[i]>g_lastNotifyTime)
               { g_lastNotifyTime=time[i]; SendSignalAlert("Star","SELL",close[i],g_tpPrice); }
            }
         }
      }

      //=== 矢印サイン（継続） v3: DI方向+MTF整合+厳格プルバック ===
      g_buyArrow[i] = EMPTY_VALUE;
      g_sellArrow[i] = EMPTY_VALUE;

      if(i >= 2)
      {
         double arrowOff = atrVal * 0.3;

         // v3 買い矢印: 全条件がANDで結合
         bool buyOK = isBull
            && close[i] > g_cloudUpper[i]               // クラウド上にブレイク
            && adxMain[i] > InpADXThreshold              // トレンド強度
            && adxPlus[i] > adxMinus[i]                  // v3: +DI > -DI（方向一致）
            && low[i-1] <= g_cloudUpper[i-1]             // v3: クラウドに実際タッチ
            && close[i] > close[i-1]                     // 陽線
            && IsMTFAligned(true);                       // v3: MTF2/3以上一致

         bool sellOK = !isBull
            && close[i] < g_cloudLower[i]
            && adxMain[i] > InpADXThreshold
            && adxMinus[i] > adxPlus[i]                  // v3: -DI > +DI
            && high[i-1] >= g_cloudLower[i-1]            // v3: クラウドに実際タッチ
            && close[i] < close[i-1]
            && IsMTFAligned(false);                      // v3: MTF整合

         if(buyOK && g_lastSignalDir != 1)
         {
            g_buyArrow[i] = low[i] - arrowOff;
            g_lastSignalDir = 1;
            g_tpActive=true; g_tpDir=1;
            g_tpPrice = CalculateOptimalTP(true,close[i],atrVal,high,low,bbUpper[i],bbLower[i],i,InpSwingLookback);
            if(i==rates_total-1 && prev_calculated>0 && time[i]>g_lastNotifyTime)
            { g_lastNotifyTime=time[i]; SendSignalAlert("Arrow","BUY",close[i],g_tpPrice); }
         }
         else if(sellOK && g_lastSignalDir != -1)
         {
            g_sellArrow[i] = high[i] + arrowOff;
            g_lastSignalDir = -1;
            g_tpActive=true; g_tpDir=-1;
            g_tpPrice = CalculateOptimalTP(false,close[i],atrVal,high,low,bbUpper[i],bbLower[i],i,InpSwingLookback);
            if(i==rates_total-1 && prev_calculated>0 && time[i]>g_lastNotifyTime)
            { g_lastNotifyTime=time[i]; SendSignalAlert("Arrow","SELL",close[i],g_tpPrice); }
         }
      }
   }

   ManageTPLine();
   UpdateTPInfo();

   if(rates_total != g_lastDashBar)
   {
      g_lastDashBar = rates_total;
      UpdateDashboard();
      UpdateTrendBox(fastEMA[rates_total-1] > slowEMA[rates_total-1]);
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| OnTimer                                                            |
//+------------------------------------------------------------------+
void OnTimer() { UpdateDashboard(); }

//+------------------------------------------------------------------+
//| OnChartEvent                                                       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   if(sparam == g_prefix+"BtnOnOff")
   {
      g_indicatorON = !g_indicatorON;
      ObjectSetString(0,g_prefix+"BtnOnOff",OBJPROP_TEXT, g_indicatorON?"ON":"OFF");
      if(g_indicatorON)
      {
         PlotIndexSetInteger(0,PLOT_DRAW_TYPE,DRAW_FILLING);
         PlotIndexSetInteger(1,PLOT_DRAW_TYPE,DRAW_FILLING);
         for(int p=2;p<=7;p++) PlotIndexSetInteger(p,PLOT_DRAW_TYPE,DRAW_ARROW);
      }
      else
      {
         for(int p=0;p<=7;p++) PlotIndexSetInteger(p,PLOT_DRAW_TYPE,DRAW_NONE);
         ObjectDelete(0,g_prefix+"TPLine");
      }
      ChartRedraw();
      ObjectSetInteger(0,g_prefix+"BtnOnOff",OBJPROP_STATE,false);
   }
   else if(sparam==g_prefix+"Btn1m")
   { ChartSetSymbolPeriod(0,_Symbol,PERIOD_M1); ObjectSetInteger(0,sparam,OBJPROP_STATE,false); }
   else if(sparam==g_prefix+"Btn5m")
   { ChartSetSymbolPeriod(0,_Symbol,PERIOD_M5); ObjectSetInteger(0,sparam,OBJPROP_STATE,false); }
   else if(sparam==g_prefix+"Btn15m")
   { ChartSetSymbolPeriod(0,_Symbol,PERIOD_M15); ObjectSetInteger(0,sparam,OBJPROP_STATE,false); }
}

//+------------------------------------------------------------------+
//| ManageTPLine                                                       |
//+------------------------------------------------------------------+
void ManageTPLine()
{
   string ln = g_prefix+"TPLine";
   if(g_tpActive && g_indicatorON)
   {
      if(ObjectFind(0,ln)<0) ObjectCreate(0,ln,OBJ_HLINE,0,0,g_tpPrice);
      else ObjectSetDouble(0,ln,OBJPROP_PRICE,g_tpPrice);
      ObjectSetInteger(0,ln,OBJPROP_COLOR,InpTPColor);
      ObjectSetInteger(0,ln,OBJPROP_STYLE,STYLE_DASH);
      ObjectSetInteger(0,ln,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,ln,OBJPROP_BACK,true);
      ObjectSetInteger(0,ln,OBJPROP_SELECTABLE,false);
   }
   else ObjectDelete(0,ln);
}

//+------------------------------------------------------------------+
//| UpdateTPInfo                                                       |
//+------------------------------------------------------------------+
void UpdateTPInfo()
{
   string n = g_prefix+"TPInfo";
   if(g_tpActive)
   {
      ObjectSetString(0,n,OBJPROP_TEXT,"TP:"+DoubleToString(g_tpPrice,_Digits));
      ObjectSetInteger(0,n,OBJPROP_COLOR,InpTPColor);
   }
   else
   {
      ObjectSetString(0,n,OBJPROP_TEXT,"TP: ---");
      ObjectSetInteger(0,n,OBJPROP_COLOR,C'80,80,80');
   }
}

//+------------------------------------------------------------------+
//| CreateUIElements - v3: コンパクト&洗練デザイン                       |
//+------------------------------------------------------------------+
void CreateUIElements()
{
   int x0 = 10;  // 左端基準

   //=== トレンドボックス ===
   string box = g_prefix+"TrendBox";
   ObjectCreate(0,box,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,box,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,box,OBJPROP_XDISTANCE,x0);
   ObjectSetInteger(0,box,OBJPROP_YDISTANCE,20);
   ObjectSetInteger(0,box,OBJPROP_XSIZE,48);
   ObjectSetInteger(0,box,OBJPROP_YSIZE,40);
   ObjectSetInteger(0,box,OBJPROP_BGCOLOR,C'15,17,28');
   ObjectSetInteger(0,box,OBJPROP_COLOR,InpBullColor);
   ObjectSetInteger(0,box,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,box,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,box,OBJPROP_BACK,false);

   // 矢印（18pt でボックス内に確実に収まる）
   MakeLabel(g_prefix+"TrendArrow","é",x0+16,28,clrWhite,"Wingdings",18,CORNER_LEFT_UPPER);
   // ON表示
   MakeLabel(g_prefix+"OnOffLabel","ON",x0+34,47,C'0,255,100',"Arial Bold",7,CORNER_LEFT_UPPER);

   //=== ボタン（48px幅、18px高、ボックスと同幅） ===
   int by = 64;
   MakeButton(g_prefix+"Btn1m",   "1m", x0, by,      48, 18);
   MakeButton(g_prefix+"Btn5m",   "5m", x0, by+20,   48, 18);
   MakeButton(g_prefix+"Btn15m",  "15m",x0, by+40,   48, 18);
   MakeButton(g_prefix+"BtnOnOff","ON", x0, by+63,   48, 18);

   //=== TP情報 ===
   MakeLabel(g_prefix+"TPInfo","TP: ---",x0+2,by+85,C'80,80,80',"Arial",7,CORNER_LEFT_UPPER);

   //=== ダッシュボード（左下） ===
   string bg = g_prefix+"DashBG";
   ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,8);
   ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,115);
   ObjectSetInteger(0,bg,OBJPROP_XSIZE,175);
   ObjectSetInteger(0,bg,OBJPROP_YSIZE,100);
   ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,C'15,17,28');
   ObjectSetInteger(0,bg,OBJPROP_COLOR,C'40,100,180');
   ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,bg,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,bg,OBJPROP_BACK,false);

   MakeLabel(g_prefix+"DashTitle","MTF Dashboard",16,112,C'100,140,200',"Arial",7,CORNER_LEFT_LOWER);

   string rows[3]={"1h","15m","5m"};
   for(int i=0;i<3;i++)
   {
      int yB = 98 - i*28;
      MakeLabel(g_prefix+"DashTF_"+IntegerToString(i),    rows[i],16,yB,C'170,180,210',"Arial Bold",InpDashFontSize,CORNER_LEFT_LOWER);
      MakeLabel(g_prefix+"DashScore_"+IntegerToString(i), "50",   60,yB,clrWhite,"Arial Bold",InpDashFontSize+1,CORNER_LEFT_LOWER);
      MakeLabel(g_prefix+"DashIcon_"+IntegerToString(i),  "é",   105,yB,InpBullColor,"Wingdings",InpDashFontSize+3,CORNER_LEFT_LOWER);

      // スコアバー背景
      string bbg = g_prefix+"DashBarBG_"+IntegerToString(i);
      ObjectCreate(0,bbg,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,bbg,OBJPROP_CORNER,CORNER_LEFT_LOWER);
      ObjectSetInteger(0,bbg,OBJPROP_XDISTANCE,128);
      ObjectSetInteger(0,bbg,OBJPROP_YDISTANCE,yB-2);
      ObjectSetInteger(0,bbg,OBJPROP_XSIZE,40);
      ObjectSetInteger(0,bbg,OBJPROP_YSIZE,8);
      ObjectSetInteger(0,bbg,OBJPROP_BGCOLOR,C'35,37,50');
      ObjectSetInteger(0,bbg,OBJPROP_COLOR,C'35,37,50');
      ObjectSetInteger(0,bbg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,bbg,OBJPROP_WIDTH,0);
      ObjectSetInteger(0,bbg,OBJPROP_BACK,false);

      string bar = g_prefix+"DashBar_"+IntegerToString(i);
      ObjectCreate(0,bar,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,bar,OBJPROP_CORNER,CORNER_LEFT_LOWER);
      ObjectSetInteger(0,bar,OBJPROP_XDISTANCE,128);
      ObjectSetInteger(0,bar,OBJPROP_YDISTANCE,yB-2);
      ObjectSetInteger(0,bar,OBJPROP_XSIZE,20);
      ObjectSetInteger(0,bar,OBJPROP_YSIZE,8);
      ObjectSetInteger(0,bar,OBJPROP_BGCOLOR,InpBullColor);
      ObjectSetInteger(0,bar,OBJPROP_COLOR,InpBullColor);
      ObjectSetInteger(0,bar,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,bar,OBJPROP_WIDTH,0);
      ObjectSetInteger(0,bar,OBJPROP_BACK,false);
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| MakeLabel                                                          |
//+------------------------------------------------------------------+
void MakeLabel(string name,string text,int x,int y,color clr,
               string font,int sz,ENUM_BASE_CORNER corner)
{
   ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,font);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,sz);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

//+------------------------------------------------------------------+
//| MakeButton                                                         |
//+------------------------------------------------------------------+
void MakeButton(string name,string text,int x,int y,int w,int h)
{
   ObjectCreate(0,name,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name,OBJPROP_COLOR,C'190,200,220');
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,C'25,27,40');
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,C'45,90,160');
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_STATE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

//+------------------------------------------------------------------+
//| UpdateTrendBox                                                     |
//+------------------------------------------------------------------+
void UpdateTrendBox(bool isBullish)
{
   color c = isBullish ? InpBullColor : InpBearColor;
   ObjectSetInteger(0,g_prefix+"TrendBox",OBJPROP_COLOR,c);
   ObjectSetString(0,g_prefix+"TrendArrow",OBJPROP_TEXT,isBullish?"é":"ê");
   ObjectSetInteger(0,g_prefix+"TrendArrow",OBJPROP_COLOR,clrWhite);
   ObjectSetString(0,g_prefix+"OnOffLabel",OBJPROP_TEXT,g_indicatorON?"ON":"OFF");
   ObjectSetInteger(0,g_prefix+"OnOffLabel",OBJPROP_COLOR,g_indicatorON?C'0,255,100':C'80,80,80');
}

//+------------------------------------------------------------------+
//| UpdateDashboard                                                    |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!g_indicatorON) return;
   int map[3]={2,1,0};
   for(int row=0;row<3;row++)
   {
      int mi=map[row];
      double f[1],s[1],r[1],am[1],ap[1],an[1];
      if(CopyBuffer(g_handleMTF_FastEMA[mi],0,0,1,f)<=0) continue;
      if(CopyBuffer(g_handleMTF_SlowEMA[mi],0,0,1,s)<=0) continue;
      if(CopyBuffer(g_handleMTF_RSI[mi],    0,0,1,r)<=0) continue;
      if(CopyBuffer(g_handleMTF_ADX[mi],    0,0,1,am)<=0)continue;
      if(CopyBuffer(g_handleMTF_ADX[mi],    1,0,1,ap)<=0)continue;
      if(CopyBuffer(g_handleMTF_ADX[mi],    2,0,1,an)<=0)continue;

      bool bull=(f[0]>s[0]);
      double emaSc=0;
      if(s[0]!=0) emaSc=MathMin(MathAbs(f[0]-s[0])/s[0]*10000.0,40.0);
      double rsiSc=bull? MathMax(0,MathMin(30,(r[0]-40)/30*30)) : MathMax(0,MathMin(30,(60-r[0])/30*30));
      double adxSc=MathMin(am[0]/50*30,30);
      if(!((bull&&ap[0]>an[0])||(!bull&&an[0]>ap[0]))) adxSc*=0.5;
      double sc=MathMax(0,MathMin(100,emaSc+rsiSc+adxSc));
      if(bull&&sc<50) sc=50+(sc/2);
      if(!bull&&sc>50) sc=50-(sc/2);
      if(!bull) sc=100-sc;
      int si=(int)MathRound(sc);
      color cc=bull?InpBullColor:InpBearColor;
      string rs=IntegerToString(row);

      ObjectSetString(0,g_prefix+"DashScore_"+rs,OBJPROP_TEXT,IntegerToString(si));
      ObjectSetInteger(0,g_prefix+"DashScore_"+rs,OBJPROP_COLOR,cc);
      ObjectSetString(0,g_prefix+"DashIcon_"+rs,OBJPROP_TEXT,bull?"é":"ê");
      ObjectSetInteger(0,g_prefix+"DashIcon_"+rs,OBJPROP_COLOR,cc);
      int bw=MathMax(1,(int)MathRound(40.0*si/100));
      ObjectSetInteger(0,g_prefix+"DashBar_"+rs,OBJPROP_XSIZE,bw);
      ObjectSetInteger(0,g_prefix+"DashBar_"+rs,OBJPROP_BGCOLOR,cc);
      ObjectSetInteger(0,g_prefix+"DashBar_"+rs,OBJPROP_COLOR,cc);
   }
   ChartRedraw();
}
//+------------------------------------------------------------------+
