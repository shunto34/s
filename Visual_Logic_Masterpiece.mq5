//+------------------------------------------------------------------+
//| Visual_Logic_Masterpiece.mq5                                      |
//| v6.0 - スクリーンショット準拠UI + 大サークル + グリッドMTF          |
//+------------------------------------------------------------------+
#property copyright "Visual Logic Masterpiece v6.0"
#property link      ""
#property version   "6.00"
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

input group "===== サイン精度設定 ====="
input int    InpRSIPeriod     = 8;
input int    InpBBPeriod      = 20;
input double InpBBDeviation   = 2.0;
input int    InpADXPeriod     = 14;
input double InpADXThreshold  = 18.0;       // トレンド強度閾値（やや緩め）
input int    InpSwingLookback = 20;          // スイングHL検出期間
input int    InpHSLookback    = 30;          // 三尊/逆三尊検出期間
input double InpSweepATRMult  = 0.3;        // Liquidity Sweepの閾値(ATR倍率)

input group "===== 利確ターゲット設定 ====="
input double InpTPMultiplier  = 2.0;
input color  InpTPColor       = C'0,255,100';

input group "===== ダッシュボード設定 ====="
input color  InpBullColor     = C'0,200,220';     // シアン系
input color  InpBearColor     = C'220,50,80';      // ローズ系
input int    InpDashFontSize  = 10;

input group "===== Push通知設定 ====="
input bool   InpPushNotify    = false;       // プッシュ通知（MT5モバイル）
input ENUM_TIMEFRAMES InpNotifyTF = PERIOD_M5; // 通知対象の時間足
input bool   InpAlertSound    = true;        // サウンドアラート

//+------------------------------------------------------------------+
//| グローバル変数                                                      |
//+------------------------------------------------------------------+
double g_cloudUpper[], g_cloudLower[];
double g_glowUpper[],  g_glowLower[];
double g_buyArrow[],   g_sellArrow[];
double g_buyStar[],    g_sellStar[];
double g_buyTP[],      g_sellTP[];

int g_handleFastEMA, g_handleSlowEMA, g_handleATR;
int g_handleRSI, g_handleBBUpper, g_handleADX;

int g_handleMTF_FastEMA[3], g_handleMTF_SlowEMA[3];
int g_handleMTF_RSI[3], g_handleMTF_ADX[3];

ENUM_TIMEFRAMES g_mtfPeriods[3] = {PERIOD_M5, PERIOD_M15, PERIOD_H1};
string g_mtfLabels[3] = {"5m", "15m", "1h"};

int    g_lastSignalDir = 0;    // 0=なし, 1=買い, -1=売り
int    g_lastStarBar   = 0;   // 星シグナルのクールダウン用
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

   PlotIndexSetInteger(2, PLOT_ARROW, 233);  // 買い矢印
   PlotIndexSetInteger(3, PLOT_ARROW, 234);  // 売り矢印
   PlotIndexSetInteger(4, PLOT_ARROW, 171);  // 買い星
   PlotIndexSetInteger(5, PLOT_ARROW, 171);  // 売り星
   PlotIndexSetInteger(6, PLOT_ARROW, 174);  // 買いTP
   PlotIndexSetInteger(7, PLOT_ARROW, 174);  // 売りTP

   for(int p = 2; p <= 7; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   g_handleFastEMA = iMA(_Symbol, PERIOD_CURRENT, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_handleSlowEMA = iMA(_Symbol, PERIOD_CURRENT, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_handleATR     = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   g_handleRSI     = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   g_handleBBUpper = iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   g_handleADX     = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);

   if(g_handleFastEMA==INVALID_HANDLE || g_handleSlowEMA==INVALID_HANDLE ||
      g_handleATR==INVALID_HANDLE || g_handleRSI==INVALID_HANDLE ||
      g_handleBBUpper==INVALID_HANDLE || g_handleADX==INVALID_HANDLE)
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
   IndicatorSetString(INDICATOR_SHORTNAME, "VLM v5");
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
   IndicatorRelease(g_handleBBUpper); IndicatorRelease(g_handleADX);
   for(int i=0;i<3;i++)
   {
      IndicatorRelease(g_handleMTF_FastEMA[i]); IndicatorRelease(g_handleMTF_SlowEMA[i]);
      IndicatorRelease(g_handleMTF_RSI[i]);     IndicatorRelease(g_handleMTF_ADX[i]);
   }
   EventKillTimer();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| IsMTFAligned - MTF方向整合性チェック                                |
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
//| DetectLiquiditySweep - 流動性スイープ検出                           |
//| 直近のスイングHL超え → 即座にリジェクト（ヒゲで戻る）                 |
//+------------------------------------------------------------------+
bool DetectLiquiditySweepBuy(const double &high[], const double &low[],
                              const double &close[], const double &open[],
                              double atrVal, int bar)
{
   if(bar < InpSwingLookback + 2) return false;

   // 直近スイング安値を見つける
   double swingLow = low[bar-1];
   for(int j = bar - InpSwingLookback; j < bar - 1; j++)
   {
      if(j < 0) continue;
      if(low[j] < swingLow) swingLow = low[j];
   }

   // 現在の足が直近安値を下抜け（sweep）してから戻った
   double sweepThreshold = atrVal * InpSweepATRMult;
   bool sweptBelow = (low[bar] < swingLow - sweepThreshold * 0.3);
   bool closedAbove = (close[bar] > swingLow);
   bool bullishClose = (close[bar] > open[bar]);  // 陽線で戻り

   return (sweptBelow && closedAbove && bullishClose);
}

bool DetectLiquiditySweepSell(const double &high[], const double &low[],
                               const double &close[], const double &open[],
                               double atrVal, int bar)
{
   if(bar < InpSwingLookback + 2) return false;

   double swingHigh = high[bar-1];
   for(int j = bar - InpSwingLookback; j < bar - 1; j++)
   {
      if(j < 0) continue;
      if(high[j] > swingHigh) swingHigh = high[j];
   }

   double sweepThreshold = atrVal * InpSweepATRMult;
   bool sweptAbove = (high[bar] > swingHigh + sweepThreshold * 0.3);
   bool closedBelow = (close[bar] < swingHigh);
   bool bearishClose = (close[bar] < open[bar]);

   return (sweptAbove && closedBelow && bearishClose);
}

//+------------------------------------------------------------------+
//| DetectInverseHS - 逆三尊（Inverse Head & Shoulders）検出            |
//| 買いシグナル: 安値3点で左肩 > 頭 < 右肩 のパターン                    |
//+------------------------------------------------------------------+
bool DetectInverseHS(const double &high[], const double &low[],
                     const double &close[], int bar)
{
   if(bar < InpHSLookback + 5) return false;

   int startBar = bar - InpHSLookback;
   if(startBar < 0) startBar = 0;

   // 検出範囲内の安値ピボット(3つ)を探す
   double pivotLow[3];
   int    pivotIdx[3];
   int    pivotCount = 0;

   for(int i = startBar + 2; i < bar - 1 && pivotCount < 3; i++)
   {
      if(i < 2) continue;
      // 安値ピボット: 前2本と後2本より安い
      bool isPivot = (low[i] < low[i-1] && low[i] < low[i-2]);
      if(i + 2 < bar)
         isPivot = isPivot && (low[i] < low[i+1] && low[i] < low[i+2]);
      else if(i + 1 < bar)
         isPivot = isPivot && (low[i] < low[i+1]);

      if(isPivot)
      {
         pivotLow[pivotCount] = low[i];
         pivotIdx[pivotCount] = i;
         pivotCount++;
      }
   }

   if(pivotCount < 3) return false;

   // 最後の3ピボットで判定
   double leftShoulder  = pivotLow[pivotCount-3];
   double head          = pivotLow[pivotCount-2];
   double rightShoulder = pivotLow[pivotCount-1];

   // 逆三尊: 頭が最も安い、両肩は頭より高い
   bool headIsLowest = (head < leftShoulder && head < rightShoulder);
   // 両肩の高さがおおよそ同じ（差がスイング幅の40%以内）
   double range = leftShoulder - head;
   if(range <= 0) return false;
   bool shouldersLevel = MathAbs(leftShoulder - rightShoulder) < range * 0.5;
   // 右肩の後、価格が上に向かっている
   bool breakingUp = (close[bar] > close[bar-1]) && (close[bar] > rightShoulder);

   return (headIsLowest && shouldersLevel && breakingUp);
}

//+------------------------------------------------------------------+
//| DetectHS - 三尊（Head & Shoulders）検出                             |
//| 売りシグナル: 高値3点で左肩 < 頭 > 右肩 のパターン                    |
//+------------------------------------------------------------------+
bool DetectHS(const double &high[], const double &low[],
              const double &close[], int bar)
{
   if(bar < InpHSLookback + 5) return false;

   int startBar = bar - InpHSLookback;
   if(startBar < 0) startBar = 0;

   double pivotHigh[3];
   int    pivotIdx[3];
   int    pivotCount = 0;

   for(int i = startBar + 2; i < bar - 1 && pivotCount < 3; i++)
   {
      if(i < 2) continue;
      bool isPivot = (high[i] > high[i-1] && high[i] > high[i-2]);
      if(i + 2 < bar)
         isPivot = isPivot && (high[i] > high[i+1] && high[i] > high[i+2]);
      else if(i + 1 < bar)
         isPivot = isPivot && (high[i] > high[i+1]);

      if(isPivot)
      {
         pivotHigh[pivotCount] = high[i];
         pivotIdx[pivotCount] = i;
         pivotCount++;
      }
   }

   if(pivotCount < 3) return false;

   double leftShoulder  = pivotHigh[pivotCount-3];
   double head          = pivotHigh[pivotCount-2];
   double rightShoulder = pivotHigh[pivotCount-1];

   bool headIsHighest = (head > leftShoulder && head > rightShoulder);
   double range = head - leftShoulder;
   if(range <= 0) return false;
   bool shouldersLevel = MathAbs(leftShoulder - rightShoulder) < range * 0.5;
   bool breakingDown = (close[bar] < close[bar-1]) && (close[bar] < rightShoulder);

   return (headIsHighest && shouldersLevel && breakingDown);
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
//| SendSignalAlert - Push通知送信（v4: Push専用）                      |
//+------------------------------------------------------------------+
void SendSignalAlert(string signalType, string direction, double price, double tpPrice)
{
   // 通知対象の時間足チェック
   if(Period() != InpNotifyTF) return;

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

   Print("Signal Alert: ", msg);
}

//+------------------------------------------------------------------+
//| OnCalculate - メインループ（v4: Liquidity Sweep + 三尊/逆三尊）      |
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
   double adxMain[], adxPlus[], adxMinus[];

   int startBar = (prev_calculated > 1) ? prev_calculated - 1 : 0;

   if(CopyBuffer(g_handleFastEMA,0,0,rates_total,fastEMA)<=0) return(0);
   if(CopyBuffer(g_handleSlowEMA,0,0,rates_total,slowEMA)<=0) return(0);
   if(CopyBuffer(g_handleATR,    0,0,rates_total,atr)    <=0) return(0);
   if(CopyBuffer(g_handleRSI,    0,0,rates_total,rsi)    <=0) return(0);
   if(CopyBuffer(g_handleBBUpper,1,0,rates_total,bbUpper)<=0) return(0);
   if(CopyBuffer(g_handleBBUpper,2,0,rates_total,bbLower)<=0) return(0);
   if(CopyBuffer(g_handleBBUpper,0,0,rates_total,bbMiddle)<=0)return(0);
   if(CopyBuffer(g_handleADX,    0,0,rates_total,adxMain)<=0) return(0);
   if(CopyBuffer(g_handleADX,    1,0,rates_total,adxPlus)<=0) return(0);
   if(CopyBuffer(g_handleADX,    2,0,rates_total,adxMinus)<=0)return(0);

   for(int i = startBar; i < rates_total; i++)
   {
      if(i < InpSlowEMA + 5) continue;

      double atrVal = atr[i];
      if(atrVal <= 0) continue;
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

      //=== 初期化 ===
      g_buyStar[i]  = EMPTY_VALUE;
      g_sellStar[i] = EMPTY_VALUE;
      g_buyArrow[i]  = EMPTY_VALUE;
      g_sellArrow[i] = EMPTY_VALUE;

      if(i < InpHSLookback + 5) continue;

      //=== Liquidity Sweep検出 ===
      bool sweepBuy  = DetectLiquiditySweepBuy(high, low, close, open, atrVal, i);
      bool sweepSell = DetectLiquiditySweepSell(high, low, close, open, atrVal, i);

      //=== 三尊/逆三尊検出 ===
      bool invHS = DetectInverseHS(high, low, close, i);  // 買いパターン
      bool hs    = DetectHS(high, low, close, i);          // 売りパターン

      //=== RSIダイバージェンス補助 ===
      bool rsiBuyZone  = (rsi[i] < 45);  // 売られ過ぎ寄り
      bool rsiSellZone = (rsi[i] > 55);  // 買われ過ぎ寄り
      // RSIが反転し始めている
      bool rsiTurningUp   = (i >= 2 && rsi[i] > rsi[i-1] && rsi[i-1] <= rsi[i-2]);
      bool rsiTurningDown = (i >= 2 && rsi[i] < rsi[i-1] && rsi[i-1] >= rsi[i-2]);

      //=== ADX+DI方向 ===
      bool adxActive = (adxMain[i] > InpADXThreshold);
      bool diLong    = (adxPlus[i] > adxMinus[i]);
      bool diShort   = (adxMinus[i] > adxPlus[i]);

      // ================================================================
      // 星サイン（反転）: Liquidity Sweep + 三尊/逆三尊 + RSI確認
      //   最強シグナル: sweep AND パターン
      //   通常シグナル: sweep OR パターン（+ RSIターン確認）
      // ================================================================

      double starOff = atrVal * 0.5;

      // --- 買い星（反転買い）---
      bool starCooldownOK = (i - g_lastStarBar >= 5);
      if(starCooldownOK)
      {
         bool candleOK = (close[i] > open[i]);  // 陽線
         bool atExtreme = (low[i] <= bbLower[i] || close[i] < g_cloudLower[i]);

         // ボーナス: Sweep/逆三尊検出時はRSI条件を緩和
         bool hasBonus = (sweepBuy || invHS);
         bool rsiOK = hasBonus ? (rsi[i] < 50) : (rsi[i] < 40);

         // Tier判定（表示サイズ用）
         int buyStarTier = 0;
         if(sweepBuy && invHS && candleOK) buyStarTier = 1;           // Tier1: 最強
         else if(rsiOK && rsiTurningUp && candleOK && atExtreme) buyStarTier = 2;  // Tier2: 標準

         if(buyStarTier > 0)
         {
            double tierOff = (buyStarTier == 1) ? starOff * 1.5 : starOff;
            g_buyStar[i] = low[i] - tierOff;
            g_lastSignalDir = 1;
            g_lastStarBar = i;
            g_tpActive = true; g_tpDir = 1;
            g_tpPrice = CalculateOptimalTP(true, close[i], atrVal, high, low,
                                            bbUpper[i], bbLower[i], i, InpSwingLookback);
            if(i == rates_total-1 && prev_calculated > 0 && time[i] > g_lastNotifyTime)
            { g_lastNotifyTime = time[i]; SendSignalAlert("Star","BUY",close[i],g_tpPrice); }
         }
      }

      // --- 売り星（反転売り）---
      if(starCooldownOK && g_buyStar[i] == EMPTY_VALUE)
      {
         bool candleOK = (close[i] < open[i]);  // 陰線
         bool atExtreme = (high[i] >= bbUpper[i] || close[i] > g_cloudUpper[i]);

         bool hasBonus = (sweepSell || hs);
         bool rsiOK = hasBonus ? (rsi[i] > 50) : (rsi[i] > 60);

         int sellStarTier = 0;
         if(sweepSell && hs && candleOK) sellStarTier = 1;
         else if(rsiOK && rsiTurningDown && candleOK && atExtreme) sellStarTier = 2;

         if(sellStarTier > 0)
         {
            double tierOff = (sellStarTier == 1) ? starOff * 1.5 : starOff;
            g_sellStar[i] = high[i] + tierOff;
            g_lastSignalDir = -1;
            g_lastStarBar = i;
            g_tpActive = true; g_tpDir = -1;
            g_tpPrice = CalculateOptimalTP(false, close[i], atrVal, high, low,
                                            bbUpper[i], bbLower[i], i, InpSwingLookback);
            if(i == rates_total-1 && prev_calculated > 0 && time[i] > g_lastNotifyTime)
            { g_lastNotifyTime = time[i]; SendSignalAlert("Star","SELL",close[i],g_tpPrice); }
         }
      }

      // ================================================================
      // 矢印サイン（トレンド継続）: EMA方向 + ADX + DI
      //   描画のみ（TP更新・通知なし）
      // ================================================================

      if(i >= 2)
      {
         double arrowOff = atrVal * 0.3;

         // 買い矢印: EMA方向 + slowEMAの上 + ADX + DI
         bool buyOK = isBull
            && close[i] > slowEMA[i]              // 遅いEMAの上（クラウド内でもOK）
            && adxActive                          // トレンド存在
            && diLong;                            // +DI方向一致

         // 売り矢印: EMA方向 + slowEMAの下 + ADX + DI
         bool sellOK = !isBull
            && close[i] < slowEMA[i]              // 遅いEMAの下
            && adxActive
            && diShort;

         if(buyOK)
         {
            g_buyArrow[i] = low[i] - arrowOff;
         }
         else if(sellOK)
         {
            g_sellArrow[i] = high[i] + arrowOff;
         }
      }
   }

   ManageTPLine();
   UpdateTPInfo();

   if(rates_total != g_lastDashBar)
   {
      g_lastDashBar = rates_total;
      UpdateDashboard();
      UpdateTrendPanel(fastEMA[rates_total-1] > slowEMA[rates_total-1]);
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
//| MakeRect - 矩形ラベル作成ヘルパー                                   |
//+------------------------------------------------------------------+
void MakeRect(string name, int x, int y, int w, int h,
              color bgClr, color borderClr, int borderW, ENUM_BASE_CORNER corner)
{
   ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bgClr);
   ObjectSetInteger(0,name,OBJPROP_COLOR,borderClr);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,borderW);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

//+------------------------------------------------------------------+
//| MakeButtonCorner - 任意コーナーボタン作成                           |
//+------------------------------------------------------------------+
void MakeButtonCorner(string name,string text,int x,int y,int w,int h,
                      ENUM_BASE_CORNER corner)
{
   ObjectCreate(0,name,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,name,OBJPROP_COLOR,C'190,200,220');
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,C'25,27,40');
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,C'50,70,120');
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_STATE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

//+------------------------------------------------------------------+
//| CreateUIElements - v6: スクリーンショット準拠UI                     |
//| 大きな方向サークル + グリッドテーブル + 円形矢印アイコン              |
//+------------------------------------------------------------------+
void CreateUIElements()
{
   //================================================================
   // 1. 大きなトレンドサークル（右上 130x130）
   //================================================================
   MakeRect(g_prefix+"TrendBG", 15, 15, 130, 130,
            C'18,20,32', InpBullColor, 3, CORNER_RIGHT_UPPER);
   MakeRect(g_prefix+"TrendBGInner", 20, 20, 120, 120,
            C'25,28,42', C'25,28,42', 0, CORNER_RIGHT_UPPER);
   // 大きなWingdings矢印（中央）
   MakeLabel(g_prefix+"TrendIcon", "\xE9",
             78, 35, InpBullColor, "Wingdings", 60, CORNER_RIGHT_UPPER);

   //================================================================
   // 2. ボタン（右側・サークルの下に配置）
   //================================================================
   int btnX = 50;
   int btnY = 155;
   MakeButtonCorner(g_prefix+"Btn1m",    "1m",  btnX, btnY,       60, 24, CORNER_RIGHT_UPPER);
   MakeButtonCorner(g_prefix+"Btn5m",    "5m",  btnX, btnY+26,    60, 24, CORNER_RIGHT_UPPER);
   MakeButtonCorner(g_prefix+"Btn15m",   "15m", btnX, btnY+52,    60, 24, CORNER_RIGHT_UPPER);
   MakeButtonCorner(g_prefix+"BtnOnOff", "ON",  btnX, btnY+82,    60, 24, CORNER_RIGHT_UPPER);

   //================================================================
   // 3. TP情報
   //================================================================
   MakeLabel(g_prefix+"TPInfo", "TP: ---",
             80, btnY+112, C'80,80,80', "Arial", 9, CORNER_RIGHT_UPPER);

   //================================================================
   // 4. MTFダッシュボード（右下グリッドテーブル）
   //    レイアウト: | TF名 | スコア | 丸矢印 |
   //    3行: 1h, 15m, 5m
   //================================================================
   int rowH  = 46;                     // 行の高さ
   int tblH  = rowH * 3;              // 138
   int tblW  = 250;                    // テーブル幅
   int tblX  = 15;                     // 右端からの距離
   int tblTopY = tblH + 15;           // テーブル上端Y（下端から153px）

   // テーブル外枠背景
   MakeRect(g_prefix+"DashBG", tblX, tblTopY, tblW, tblH,
            C'18,20,32', C'50,60,80', 2, CORNER_RIGHT_LOWER);

   // 列幅定義
   int colArrW  = 58;   // 矢印列（右端）
   int colScW   = 65;   // スコア列（中央）
   int colTFW   = tblW - colArrW - colScW;  // TF列（左端）= 127

   string tfNames[3] = {"1h", "15m", "5m"};
   for(int i = 0; i < 3; i++)
   {
      string si = IntegerToString(i);
      // 行のY位置（上端, 下端からの距離）
      int rowTopY = tblTopY - rowH * i;

      // --- TFセル背景 ---
      MakeRect(g_prefix+"CellTF_"+si,
               tblX + colArrW + colScW + 2, rowTopY, colTFW - 4, rowH,
               C'25,28,40', C'40,50,65', 1, CORNER_RIGHT_LOWER);

      // --- スコアセル背景 ---
      MakeRect(g_prefix+"CellSc_"+si,
               tblX + colArrW + 1, rowTopY, colScW - 2, rowH,
               C'25,28,40', C'40,50,65', 1, CORNER_RIGHT_LOWER);

      // --- 矢印セル背景 ---
      MakeRect(g_prefix+"CellArr_"+si,
               tblX, rowTopY, colArrW - 1, rowH,
               C'25,28,40', C'40,50,65', 1, CORNER_RIGHT_LOWER);

      // テキストY（行の中央付近）
      int textY = rowTopY - 14;

      // --- TF名テキスト ---
      MakeLabel(g_prefix+"DashTF_"+si, tfNames[i],
                tblX + colArrW + colScW + colTFW/2 + 15, textY,
                C'200,210,230', "Arial Bold", 16, CORNER_RIGHT_LOWER);

      // --- スコア数値テキスト ---
      MakeLabel(g_prefix+"DashScore_"+si, "50",
                tblX + colArrW + colScW/2 + 12, textY,
                clrWhite, "Arial Bold", 20, CORNER_RIGHT_LOWER);

      // --- 丸い矢印アイコン ---
      // 円背景（色付き四角で代替）
      int circSz = 36;
      int circX  = tblX + (colArrW - circSz) / 2;
      int circY  = rowTopY - (rowH - circSz) / 2;
      MakeRect(g_prefix+"DashCircle_"+si,
               circX, circY, circSz, circSz,
               InpBearColor, C'15,18,28', 2, CORNER_RIGHT_LOWER);

      // 矢印（白色Wingdings）
      MakeLabel(g_prefix+"DashDir_"+si, "\xEA",
                tblX + colArrW/2 + 4, textY + 1,
                clrWhite, "Wingdings", 22, CORNER_RIGHT_LOWER);
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
//| UpdateTrendPanel - v6: 大サークル + Wingdings矢印                  |
//+------------------------------------------------------------------+
void UpdateTrendPanel(bool isBullish)
{
   color c = isBullish ? InpBullColor : InpBearColor;
   // パネル枠色
   ObjectSetInteger(0,g_prefix+"TrendBG",OBJPROP_COLOR,c);
   // 内側背景（方向で微妙に色変え）
   ObjectSetInteger(0,g_prefix+"TrendBGInner",OBJPROP_BGCOLOR,
                    isBullish ? C'20,30,45' : C'35,20,25');
   // 大きな方向アイコン
   ObjectSetString(0,g_prefix+"TrendIcon",OBJPROP_TEXT,isBullish?"\xE9":"\xEA");
   ObjectSetInteger(0,g_prefix+"TrendIcon",OBJPROP_COLOR,c);
}

//+------------------------------------------------------------------+
//| UpdateDashboard - v6: グリッドテーブル + 丸矢印アイコン             |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!g_indicatorON) return;
   int map[3]={2,1,0};  // row0=1h(idx2), row1=15m(idx1), row2=5m(idx0)
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

      // スコア数値
      ObjectSetString(0,g_prefix+"DashScore_"+rs,OBJPROP_TEXT,IntegerToString(si));
      ObjectSetInteger(0,g_prefix+"DashScore_"+rs,OBJPROP_COLOR,clrWhite);

      // 丸い矢印アイコン（背景色 + Wingdings矢印）
      ObjectSetInteger(0,g_prefix+"DashCircle_"+rs,OBJPROP_BGCOLOR,cc);
      ObjectSetString(0,g_prefix+"DashDir_"+rs,OBJPROP_TEXT,bull?"\xE9":"\xEA");
   }
   ChartRedraw();
}
//+------------------------------------------------------------------+
