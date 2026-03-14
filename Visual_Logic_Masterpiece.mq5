//+------------------------------------------------------------------+
//| Visual_Logic_Masterpiece.mq5                                      |
//| 世界最高峰のビジュアル・ロジック・インジケーター v2.0                  |
//| ネオンクラウド + 反転/継続サイン + 利確ターゲット + MTFダッシュボード  |
//+------------------------------------------------------------------+
#property copyright "Visual Logic Masterpiece v2.0"
#property link      ""
#property version   "2.00"
#property strict
#property indicator_chart_window

//--- 10個のインジケーターバッファ（8プロット）
//    0-1: クラウド本体（DRAW_FILLING）
//    2-3: クラウドグロー外側（DRAW_FILLING）
//    4: 買い矢印（トレンド継続）
//    5: 売り矢印（トレンド継続）
//    6: 買い星（反転サイン）
//    7: 売り星（反転サイン）
//    8: 買いTP到達マーカー
//    9: 売りTP到達マーカー
#property indicator_buffers 10
#property indicator_plots   8

//--- Plot 1: クラウド本体（DRAW_FILLING）
#property indicator_label1  "CloudUpper;CloudLower"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  C'255,210,50',C'40,140,255'
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: クラウドグロー（DRAW_FILLING、外側の発光レイヤー）
#property indicator_label2  "GlowUpper;GlowLower"
#property indicator_type2   DRAW_FILLING
#property indicator_color2  C'255,220,80',C'60,160,255'
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: 買い矢印（トレンド継続サイン）
#property indicator_label3  "BuyArrow"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  C'0,180,255'
#property indicator_style3  STYLE_SOLID
#property indicator_width3  3

//--- Plot 4: 売り矢印（トレンド継続サイン）
#property indicator_label4  "SellArrow"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  C'255,55,55'
#property indicator_style4  STYLE_SOLID
#property indicator_width4  3

//--- Plot 5: 買い星（反転サイン）
#property indicator_label5  "BuyStar"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  C'0,255,255'
#property indicator_style5  STYLE_SOLID
#property indicator_width5  4

//--- Plot 6: 売り星（反転サイン）
#property indicator_label6  "SellStar"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  C'255,50,255'
#property indicator_style6  STYLE_SOLID
#property indicator_width6  4

//--- Plot 7: 買いTP到達マーカー（◆ダイヤモンド）
#property indicator_label7  "BuyTP"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  C'0,255,100'
#property indicator_style7  STYLE_SOLID
#property indicator_width7  3

//--- Plot 8: 売りTP到達マーカー（◆ダイヤモンド）
#property indicator_label8  "SellTP"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  C'0,255,100'
#property indicator_style8  STYLE_SOLID
#property indicator_width8  3

//+------------------------------------------------------------------+
//| 入力パラメーター                                                    |
//+------------------------------------------------------------------+
input group "===== クラウド設定 ====="
input int    InpFastEMA       = 21;      // 高速EMA期間
input int    InpSlowEMA       = 55;      // 低速EMA期間
input int    InpATRPeriod     = 14;      // ATR期間（クラウド幅）
input double InpCloudWidth    = 0.2;     // クラウド幅係数
input double InpGlowWidth     = 0.35;    // グロー幅係数（クラウド外側の発光）

input group "===== 反転サイン（星）設定 ====="
input int    InpRSIPeriod     = 8;       // RSI期間（反転検出用）
input int    InpRSIBuyLevel   = 25;      // RSI買いレベル
input int    InpRSISellLevel  = 75;      // RSI売りレベル
input int    InpBBPeriod      = 20;      // ボリンジャーバンド期間
input double InpBBDeviation   = 2.5;     // ボリンジャーバンド偏差
input int    InpWPRPeriod     = 14;      // Williams %R期間
input double InpWPRBuyLevel   = -85.0;   // WPR買いレベル
input double InpWPRSellLevel  = -15.0;   // WPR売りレベル
input int    InpMinConditions = 3;       // 最小条件数（4条件中）

input group "===== 継続サイン（矢印）設定 ====="
input int    InpADXPeriod     = 14;      // ADX期間
input double InpADXThreshold  = 20.0;    // ADXしきい値
input double InpPullbackRatio = 0.5;     // 押し目/戻り判定比率

input group "===== 利確ターゲット設定 ====="
input double InpTPMultiplier  = 2.0;     // TP目標 ATR倍率（基本倍率）
input int    InpSwingLookback = 30;      // スイング参照期間（バー数）
input color  InpTPColor       = C'0,255,100'; // TP表示色（ネオングリーン）

input group "===== ダッシュボード設定 ====="
input color  InpBullColor     = C'0,170,255';  // 買いトレンド色
input color  InpBearColor     = C'255,60,60';  // 売りトレンド色
input int    InpDashFontSize  = 10;            // ダッシュボードフォントサイズ

//+------------------------------------------------------------------+
//| グローバル変数                                                      |
//+------------------------------------------------------------------+

//--- インジケーターバッファ
double g_cloudUpper[];      // クラウド上限
double g_cloudLower[];      // クラウド下限
double g_glowUpper[];       // グロー上限
double g_glowLower[];       // グロー下限
double g_buyArrow[];        // 買い矢印
double g_sellArrow[];       // 売り矢印
double g_buyStar[];         // 買い星
double g_sellStar[];        // 売り星
double g_buyTP[];           // 買いTP到達マーカー
double g_sellTP[];          // 売りTP到達マーカー

//--- インジケーターハンドル
int g_handleFastEMA;
int g_handleSlowEMA;
int g_handleATR;
int g_handleRSI;
int g_handleBBUpper;       // ボリンジャーバンド
int g_handleWPR;           // Williams %R
int g_handleADX;           // ADX

//--- MTF用ハンドル（5m, 15m, 1h）
int g_handleMTF_FastEMA[3];
int g_handleMTF_SlowEMA[3];
int g_handleMTF_RSI[3];
int g_handleMTF_ADX[3];

//--- MTF時間軸定義
ENUM_TIMEFRAMES g_mtfPeriods[3] = {PERIOD_M5, PERIOD_M15, PERIOD_H1};
string g_mtfLabels[3] = {"5m", "15m", "1h"};

//--- バイナリ・フリップ状態管理
int g_lastSignalDir = 0;   // 0=初期状態, 1=最後が買い, -1=最後が売り

//--- 利確ターゲット状態管理
bool   g_tpActive  = false;  // TP目標がアクティブか
int    g_tpDir     = 0;      // 1=買いTP（上方向）, -1=売りTP（下方向）
double g_tpPrice   = 0;      // 現在のTP目標価格

//--- UI表示制御
bool g_indicatorON = true;  // ON/OFFボタン状態

//--- オブジェクト名プレフィックス
string g_prefix = "VLM_";

//--- 最後にダッシュボードを更新したバー番号
int g_lastDashUpdateBar = -1;

//+------------------------------------------------------------------+
//| OnInit - 初期化                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- バッファの設定
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

   //--- 矢印コード設定
   PlotIndexSetInteger(2, PLOT_ARROW, 233);  // 買い矢印（上向き）
   PlotIndexSetInteger(3, PLOT_ARROW, 234);  // 売り矢印（下向き）
   PlotIndexSetInteger(4, PLOT_ARROW, 171);  // 買い星（★）
   PlotIndexSetInteger(5, PLOT_ARROW, 171);  // 売り星（★）
   PlotIndexSetInteger(6, PLOT_ARROW, 174);  // 買いTP（◆ダイヤモンド）
   PlotIndexSetInteger(7, PLOT_ARROW, 174);  // 売りTP（◆ダイヤモンド）

   //--- 空値の設定
   for(int p = 2; p <= 7; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   //--- インジケーターハンドルの作成（現在の時間軸）
   g_handleFastEMA = iMA(_Symbol, PERIOD_CURRENT, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_handleSlowEMA = iMA(_Symbol, PERIOD_CURRENT, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_handleATR     = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   g_handleRSI     = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   g_handleBBUpper = iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   g_handleWPR     = iWPR(_Symbol, PERIOD_CURRENT, InpWPRPeriod);
   g_handleADX     = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);

   //--- ハンドルの検証
   if(g_handleFastEMA == INVALID_HANDLE || g_handleSlowEMA == INVALID_HANDLE ||
      g_handleATR == INVALID_HANDLE || g_handleRSI == INVALID_HANDLE ||
      g_handleBBUpper == INVALID_HANDLE || g_handleWPR == INVALID_HANDLE ||
      g_handleADX == INVALID_HANDLE)
   {
      Print("エラー: インジケーターハンドルの作成に失敗しました");
      return(INIT_FAILED);
   }

   //--- MTF用ハンドルの作成
   for(int i = 0; i < 3; i++)
   {
      g_handleMTF_FastEMA[i] = iMA(_Symbol, g_mtfPeriods[i], InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
      g_handleMTF_SlowEMA[i] = iMA(_Symbol, g_mtfPeriods[i], InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
      g_handleMTF_RSI[i]     = iRSI(_Symbol, g_mtfPeriods[i], 14, PRICE_CLOSE);
      g_handleMTF_ADX[i]     = iADX(_Symbol, g_mtfPeriods[i], InpADXPeriod);

      if(g_handleMTF_FastEMA[i] == INVALID_HANDLE || g_handleMTF_SlowEMA[i] == INVALID_HANDLE ||
         g_handleMTF_RSI[i] == INVALID_HANDLE || g_handleMTF_ADX[i] == INVALID_HANDLE)
      {
         Print("エラー: MTFハンドル作成失敗 (", g_mtfLabels[i], ")");
         return(INIT_FAILED);
      }
   }

   //--- UI要素の初期作成
   CreateUIElements();

   //--- タイマー設定（ダッシュボード更新用、1秒間隔）
   EventSetTimer(1);

   //--- インジケーター名
   IndicatorSetString(INDICATOR_SHORTNAME, "Visual Logic Masterpiece v2");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit - 終了処理                                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- 全UIオブジェクトの削除
   ObjectsDeleteAll(0, g_prefix);

   //--- インジケーターハンドルの解放
   IndicatorRelease(g_handleFastEMA);
   IndicatorRelease(g_handleSlowEMA);
   IndicatorRelease(g_handleATR);
   IndicatorRelease(g_handleRSI);
   IndicatorRelease(g_handleBBUpper);
   IndicatorRelease(g_handleWPR);
   IndicatorRelease(g_handleADX);

   for(int i = 0; i < 3; i++)
   {
      IndicatorRelease(g_handleMTF_FastEMA[i]);
      IndicatorRelease(g_handleMTF_SlowEMA[i]);
      IndicatorRelease(g_handleMTF_RSI[i]);
      IndicatorRelease(g_handleMTF_ADX[i]);
   }

   EventKillTimer();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| CalculateOptimalTP - 最適利確価格の算出                              |
//+------------------------------------------------------------------+
//  【利確ロジックの設計思想】
//  単一指標ではなく、3つの独立したターゲット算出法を融合し、
//  最も現実的な利確ポイントを導出する。
//
//  ■ Method 1: ATRベースターゲット
//    エントリー価格 ± ATR × 倍率。統計的な値動き幅に基づく。
//
//  ■ Method 2: 直近スイングレベル（抵抗/支持）
//    過去Nバーの最高値/最安値。市場参加者の記憶に残る
//    心理的な壁であり、反発しやすい価格帯。
//
//  ■ Method 3: ボリンジャーバンド反対側
//    統計的な偏差の端。価格がここに到達する確率は低く、
//    到達時は利確の好機。
//
//  これら3つを条件に応じて加重し、最終TPを決定する。
//+------------------------------------------------------------------+
double CalculateOptimalTP(bool isBuy, double entryPrice, double atrVal,
                          const double &high[], const double &low[],
                          double bbUpperVal, double bbLowerVal,
                          int currentBar, int lookback)
{
   double tp = 0;

   if(isBuy)
   {
      // Method 1: ATRベースターゲット
      double atrTarget = entryPrice + atrVal * InpTPMultiplier;

      // Method 2: 直近最高値（レジスタンス）
      double recentHigh = entryPrice;
      int startIdx = MathMax(0, currentBar - lookback);
      for(int j = startIdx; j < currentBar; j++)
      {
         if(j < ArraySize(high) && high[j] > recentHigh)
            recentHigh = high[j];
      }

      // Method 3: BB上限
      double bbTarget = bbUpperVal;

      // 融合ロジック:
      // スイングハイが明確な抵抗帯にある場合はそれを優先
      // そうでなければATRとBBの中間値を使用
      if(recentHigh > entryPrice + atrVal * 0.5 &&
         recentHigh <= entryPrice + atrVal * 3.0)
      {
         // 明確なレジスタンスあり → スイング高値を基準に
         tp = recentHigh;
      }
      else if(bbTarget > entryPrice + atrVal * 0.5)
      {
         // BBが有効なターゲット → ATRとBBの平均
         tp = (atrTarget + bbTarget) / 2.0;
      }
      else
      {
         tp = atrTarget;
      }

      // 下限: 最低ATR×1.0は確保（小さすぎるTPは手数料負け）
      tp = MathMax(tp, entryPrice + atrVal * 1.0);
      // 上限: ATR×3.0を超えない（到達困難なTPは機会損失）
      tp = MathMin(tp, entryPrice + atrVal * 3.0);
   }
   else // 売り
   {
      double atrTarget = entryPrice - atrVal * InpTPMultiplier;

      double recentLow = entryPrice;
      int startIdx = MathMax(0, currentBar - lookback);
      for(int j = startIdx; j < currentBar; j++)
      {
         if(j < ArraySize(low) && low[j] < recentLow)
            recentLow = low[j];
      }

      double bbTarget = bbLowerVal;

      if(recentLow < entryPrice - atrVal * 0.5 &&
         recentLow >= entryPrice - atrVal * 3.0)
      {
         tp = recentLow;
      }
      else if(bbTarget < entryPrice - atrVal * 0.5)
      {
         tp = (atrTarget + bbTarget) / 2.0;
      }
      else
      {
         tp = atrTarget;
      }

      tp = MathMin(tp, entryPrice - atrVal * 1.0);
      tp = MathMax(tp, entryPrice - atrVal * 3.0);
   }

   return tp;
}

//+------------------------------------------------------------------+
//| OnCalculate - メイン計算ループ                                      |
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
   //--- データ不足チェック
   if(rates_total < InpSlowEMA + 10)
      return(0);

   //--- 完全再計算時は状態リセット
   if(prev_calculated == 0)
   {
      g_lastSignalDir = 0;
      g_tpActive = false;
      g_tpPrice = 0;
      g_tpDir = 0;
   }

   //--- 一時バッファ（インジケーター値取得用）
   double fastEMA[], slowEMA[], atr[];
   double rsi[], bbUpper[], bbLower[], bbMiddle[];
   double wpr[], adxMain[], adxPlus[], adxMinus[];

   //--- データのコピー
   int startBar = (prev_calculated > 1) ? prev_calculated - 1 : 0;

   if(CopyBuffer(g_handleFastEMA, 0, 0, rates_total, fastEMA) <= 0) return(0);
   if(CopyBuffer(g_handleSlowEMA, 0, 0, rates_total, slowEMA) <= 0) return(0);
   if(CopyBuffer(g_handleATR,     0, 0, rates_total, atr)     <= 0) return(0);
   if(CopyBuffer(g_handleRSI,     0, 0, rates_total, rsi)     <= 0) return(0);
   if(CopyBuffer(g_handleBBUpper, 1, 0, rates_total, bbUpper) <= 0) return(0);
   if(CopyBuffer(g_handleBBUpper, 2, 0, rates_total, bbLower) <= 0) return(0);
   if(CopyBuffer(g_handleBBUpper, 0, 0, rates_total, bbMiddle)<= 0) return(0);
   if(CopyBuffer(g_handleWPR,     0, 0, rates_total, wpr)     <= 0) return(0);
   if(CopyBuffer(g_handleADX,     0, 0, rates_total, adxMain) <= 0) return(0);
   if(CopyBuffer(g_handleADX,     1, 0, rates_total, adxPlus) <= 0) return(0);
   if(CopyBuffer(g_handleADX,     2, 0, rates_total, adxMinus)<= 0) return(0);

   //--- メインループ
   for(int i = startBar; i < rates_total; i++)
   {
      //--- 安全チェック
      if(i < InpSlowEMA + 5) continue;

      //=== 1. クラウド計算 ===
      double atrVal = atr[i];

      g_cloudUpper[i] = MathMax(fastEMA[i], slowEMA[i]) + InpCloudWidth * atrVal;
      g_cloudLower[i] = MathMin(fastEMA[i], slowEMA[i]) - InpCloudWidth * atrVal;

      g_glowUpper[i] = MathMax(fastEMA[i], slowEMA[i]) + InpGlowWidth * atrVal;
      g_glowLower[i] = MathMin(fastEMA[i], slowEMA[i]) - InpGlowWidth * atrVal;

      bool isBullishCloud = (fastEMA[i] > slowEMA[i]);

      //=== 2. TPバッファ初期化 & TP到達チェック ===
      //    サイン検出より先にTP到達を確認する。
      //    TP到達 → ポジション決済 → 新サインで再エントリーの流れ。
      g_buyTP[i]  = EMPTY_VALUE;
      g_sellTP[i] = EMPTY_VALUE;

      if(g_tpActive)
      {
         if(g_tpDir == 1 && high[i] >= g_tpPrice)
         {
            // 買いTPに到達 → ダイヤモンドマーカーを表示
            g_buyTP[i] = g_tpPrice;
            g_tpActive = false;
         }
         else if(g_tpDir == -1 && low[i] <= g_tpPrice)
         {
            // 売りTPに到達 → ダイヤモンドマーカーを表示
            g_sellTP[i] = g_tpPrice;
            g_tpActive = false;
         }
      }

      //=== 3. 星サイン（反転ロジック） ===
      g_buyStar[i]  = EMPTY_VALUE;
      g_sellStar[i] = EMPTY_VALUE;

      if(i >= 2)
      {
         int buyCondCount = 0;
         int sellCondCount = 0;

         // --- 買い反転条件 ---
         if(i >= 1 && rsi[i] > InpRSIBuyLevel && rsi[i-1] <= InpRSIBuyLevel)
            buyCondCount++;
         if(low[i] <= bbLower[i])
            buyCondCount++;
         if(wpr[i] < InpWPRBuyLevel)
            buyCondCount++;
         if(low[i-1] <= low[i-2] && low[i-1] <= low[i])
            buyCondCount++;

         // --- 売り反転条件 ---
         if(i >= 1 && rsi[i] < InpRSISellLevel && rsi[i-1] >= InpRSISellLevel)
            sellCondCount++;
         if(high[i] >= bbUpper[i])
            sellCondCount++;
         if(wpr[i] > InpWPRSellLevel)
            sellCondCount++;
         if(high[i-1] >= high[i-2] && high[i-1] >= high[i])
            sellCondCount++;

         double starOffset = atrVal * 0.5;

         // 買い星発火
         if(buyCondCount >= InpMinConditions && g_lastSignalDir != 1)
         {
            g_buyStar[i] = low[i] - starOffset;
            g_lastSignalDir = 1;
            // 利確ターゲットを設定
            g_tpActive = true;
            g_tpDir = 1;
            g_tpPrice = CalculateOptimalTP(true, close[i], atrVal,
                        high, low, bbUpper[i], bbLower[i], i, InpSwingLookback);
         }
         else if(sellCondCount >= InpMinConditions && g_lastSignalDir != -1)
         {
            g_sellStar[i] = high[i] + starOffset;
            g_lastSignalDir = -1;
            g_tpActive = true;
            g_tpDir = -1;
            g_tpPrice = CalculateOptimalTP(false, close[i], atrVal,
                        high, low, bbUpper[i], bbLower[i], i, InpSwingLookback);
         }
      }

      //=== 4. 矢印サイン（トレンド継続ロジック） ===
      g_buyArrow[i]  = EMPTY_VALUE;
      g_sellArrow[i] = EMPTY_VALUE;

      if(i >= 2)
      {
         double arrowOffset = atrVal * 0.3;

         bool buyArrowCond = false;
         if(isBullishCloud
            && close[i] > g_cloudUpper[i]
            && adxMain[i] > InpADXThreshold
            && low[i-1] <= g_cloudUpper[i-1] * (1.0 + InpPullbackRatio * 0.01)
            && close[i] > close[i-1])
         {
            buyArrowCond = true;
         }

         bool sellArrowCond = false;
         if(!isBullishCloud
            && close[i] < g_cloudLower[i]
            && adxMain[i] > InpADXThreshold
            && high[i-1] >= g_cloudLower[i-1] * (1.0 - InpPullbackRatio * 0.01)
            && close[i] < close[i-1])
         {
            sellArrowCond = true;
         }

         if(buyArrowCond && g_lastSignalDir != 1)
         {
            g_buyArrow[i] = low[i] - arrowOffset;
            g_lastSignalDir = 1;
            g_tpActive = true;
            g_tpDir = 1;
            g_tpPrice = CalculateOptimalTP(true, close[i], atrVal,
                        high, low, bbUpper[i], bbLower[i], i, InpSwingLookback);
         }
         else if(sellArrowCond && g_lastSignalDir != -1)
         {
            g_sellArrow[i] = high[i] + arrowOffset;
            g_lastSignalDir = -1;
            g_tpActive = true;
            g_tpDir = -1;
            g_tpPrice = CalculateOptimalTP(false, close[i], atrVal,
                        high, low, bbUpper[i], bbLower[i], i, InpSwingLookback);
         }
      }
   }

   //=== TPライン（水平線）の管理 ===
   ManageTPLine();

   //--- TP情報ラベルの更新
   UpdateTPInfo();

   //--- ダッシュボードの更新（新しいバーごと）
   if(rates_total != g_lastDashUpdateBar)
   {
      g_lastDashUpdateBar = rates_total;
      UpdateDashboard();
      UpdateTrendBox(fastEMA[rates_total-1] > slowEMA[rates_total-1]);
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| OnTimer - タイマーイベント（ダッシュボード定期更新）                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| OnChartEvent - チャートイベント処理                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      //--- ON/OFFボタン
      if(sparam == g_prefix + "BtnOnOff")
      {
         g_indicatorON = !g_indicatorON;
         ObjectSetString(0, g_prefix + "BtnOnOff", OBJPROP_TEXT,
                         g_indicatorON ? "ON" : "OFF");

         if(g_indicatorON)
         {
            PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_FILLING);
            PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_FILLING);
            PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_ARROW);
            PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_ARROW);
            PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_ARROW);
            PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_ARROW);
            PlotIndexSetInteger(6, PLOT_DRAW_TYPE, DRAW_ARROW);
            PlotIndexSetInteger(7, PLOT_DRAW_TYPE, DRAW_ARROW);
         }
         else
         {
            for(int p = 0; p <= 7; p++)
               PlotIndexSetInteger(p, PLOT_DRAW_TYPE, DRAW_NONE);
            // TPライン非表示
            ObjectDelete(0, g_prefix + "TPLine");
         }
         ChartRedraw();
         ObjectSetInteger(0, g_prefix + "BtnOnOff", OBJPROP_STATE, false);
      }

      //--- 時間軸ボタン
      if(sparam == g_prefix + "Btn1m")
      {
         ChartSetSymbolPeriod(0, _Symbol, PERIOD_M1);
         ObjectSetInteger(0, g_prefix + "Btn1m", OBJPROP_STATE, false);
      }
      else if(sparam == g_prefix + "Btn5m")
      {
         ChartSetSymbolPeriod(0, _Symbol, PERIOD_M5);
         ObjectSetInteger(0, g_prefix + "Btn5m", OBJPROP_STATE, false);
      }
      else if(sparam == g_prefix + "Btn15m")
      {
         ChartSetSymbolPeriod(0, _Symbol, PERIOD_M15);
         ObjectSetInteger(0, g_prefix + "Btn15m", OBJPROP_STATE, false);
      }
   }
}

//+------------------------------------------------------------------+
//| ManageTPLine - TPターゲット水平線の作成/更新/削除                     |
//+------------------------------------------------------------------+
void ManageTPLine()
{
   string lineName  = g_prefix + "TPLine";
   string labelName = g_prefix + "TPLabel";

   if(g_tpActive && g_indicatorON)
   {
      // TPライン作成/更新
      if(ObjectFind(0, lineName) < 0)
         ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, g_tpPrice);
      else
         ObjectSetDouble(0, lineName, OBJPROP_PRICE, g_tpPrice);

      ObjectSetInteger(0, lineName, OBJPROP_COLOR, InpTPColor);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, lineName, OBJPROP_TOOLTIP,
                      "TP Target: " + DoubleToString(g_tpPrice, _Digits));
   }
   else
   {
      // TPライン削除
      ObjectDelete(0, lineName);
      ObjectDelete(0, labelName);
   }
}

//+------------------------------------------------------------------+
//| UpdateTPInfo - TP情報ラベルの更新                                    |
//+------------------------------------------------------------------+
void UpdateTPInfo()
{
   string name = g_prefix + "TPInfo";
   if(g_tpActive)
   {
      string dir = (g_tpDir == 1) ? "BUY" : "SELL";
      string text = "TP: " + DoubleToString(g_tpPrice, _Digits);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, InpTPColor);
   }
   else
   {
      ObjectSetString(0, name, OBJPROP_TEXT, "TP: ---");
      ObjectSetInteger(0, name, OBJPROP_COLOR, C'100,100,100');
   }
}

//+------------------------------------------------------------------+
//| CreateUIElements - 全UI要素の作成（v2: サイズ最適化済み）             |
//+------------------------------------------------------------------+
void CreateUIElements()
{
   //=== 1. トレンド表示ボックス（左上） ===
   //    v2: OBJ_RECTANGLE_LABELで適切なサイズのボックスを作成し、
   //    内部に矢印を収める。はみ出し問題を完全解消。

   // ボックス背景
   string boxName = g_prefix + "TrendBox";
   ObjectCreate(0, boxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, boxName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, boxName, OBJPROP_XDISTANCE, 12);
   ObjectSetInteger(0, boxName, OBJPROP_YDISTANCE, 18);
   ObjectSetInteger(0, boxName, OBJPROP_XSIZE, 56);
   ObjectSetInteger(0, boxName, OBJPROP_YSIZE, 56);
   ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, C'20,22,35');
   ObjectSetInteger(0, boxName, OBJPROP_COLOR, InpBullColor);
   ObjectSetInteger(0, boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, false);

   // 方向矢印（ボックス内に収まるサイズ）
   CreateLabel(g_prefix + "TrendArrow", "é", 24, 26,
               clrWhite, "Wingdings", 28, CORNER_LEFT_UPPER);

   // ON/OFF表示テキスト（ボックス下）
   CreateLabel(g_prefix + "OnOffLabel", "ON", 28, 78,
               C'0,255,100', "Arial Bold", 8, CORNER_LEFT_UPPER);

   //=== 2. 時間軸ボタン + ON/OFFボタン（左側、ボックス下） ===
   //    v2: ボックスと同幅に統一し、縦に整列配置
   int btnX = 12;
   int btnW = 56;
   int btnH = 22;
   int btnGap = 3;
   int btnStartY = 93;

   CreateButton(g_prefix + "Btn1m",    "1m",  btnX, btnStartY,                    btnW, btnH);
   CreateButton(g_prefix + "Btn5m",    "5m",  btnX, btnStartY + (btnH + btnGap),  btnW, btnH);
   CreateButton(g_prefix + "Btn15m",   "15m", btnX, btnStartY + (btnH + btnGap)*2, btnW, btnH);
   CreateButton(g_prefix + "BtnOnOff", "ON",  btnX, btnStartY + (btnH + btnGap)*3 + 4, btnW, btnH);

   //=== 3. TP情報ラベル（ボタン下） ===
   CreateLabel(g_prefix + "TPInfo", "TP: ---", btnX + 2,
               btnStartY + (btnH + btnGap)*4 + 8,
               C'100,100,100', "Arial", 8, CORNER_LEFT_UPPER);

   //=== 4. ダッシュボードパネル（左下） ===
   string bgName = g_prefix + "DashBG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, 125);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 185);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 110);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'18,20,32');
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, C'40,120,200');
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);

   // ダッシュボードタイトル
   CreateLabel(g_prefix + "DashTitle", "MTF Dashboard", 18, 122,
               C'120,160,220', "Arial", 7, CORNER_LEFT_LOWER);

   // ダッシュボード各行（1h, 15m, 5m）
   string dashRows[3] = {"1h", "15m", "5m"};
   for(int i = 0; i < 3; i++)
   {
      int yBase = 105 - (i * 30);

      // 時間軸ラベル
      CreateLabel(g_prefix + "DashTF_" + IntegerToString(i),
                  dashRows[i], 18, yBase, C'180,190,220', "Arial Bold",
                  InpDashFontSize, CORNER_LEFT_LOWER);

      // スコア値
      CreateLabel(g_prefix + "DashScore_" + IntegerToString(i),
                  "50", 68, yBase, clrWhite, "Arial Bold",
                  InpDashFontSize + 2, CORNER_LEFT_LOWER);

      // 方向アイコン（Wingdings矢印）
      CreateLabel(g_prefix + "DashIcon_" + IntegerToString(i),
                  "é", 115, yBase, InpBullColor, "Wingdings",
                  InpDashFontSize + 4, CORNER_LEFT_LOWER);

      // スコアバー背景
      string barBgName = g_prefix + "DashBarBG_" + IntegerToString(i);
      ObjectCreate(0, barBgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, barBgName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, barBgName, OBJPROP_XDISTANCE, 138);
      ObjectSetInteger(0, barBgName, OBJPROP_YDISTANCE, yBase - 2);
      ObjectSetInteger(0, barBgName, OBJPROP_XSIZE, 42);
      ObjectSetInteger(0, barBgName, OBJPROP_YSIZE, 8);
      ObjectSetInteger(0, barBgName, OBJPROP_BGCOLOR, C'40,42,55');
      ObjectSetInteger(0, barBgName, OBJPROP_COLOR, C'40,42,55');
      ObjectSetInteger(0, barBgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, barBgName, OBJPROP_WIDTH, 0);
      ObjectSetInteger(0, barBgName, OBJPROP_BACK, false);

      // スコアバー実体
      string barName = g_prefix + "DashBar_" + IntegerToString(i);
      ObjectCreate(0, barName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, barName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, barName, OBJPROP_XDISTANCE, 138);
      ObjectSetInteger(0, barName, OBJPROP_YDISTANCE, yBase - 2);
      ObjectSetInteger(0, barName, OBJPROP_XSIZE, 21);
      ObjectSetInteger(0, barName, OBJPROP_YSIZE, 8);
      ObjectSetInteger(0, barName, OBJPROP_BGCOLOR, InpBullColor);
      ObjectSetInteger(0, barName, OBJPROP_COLOR, InpBullColor);
      ObjectSetInteger(0, barName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, barName, OBJPROP_WIDTH, 0);
      ObjectSetInteger(0, barName, OBJPROP_BACK, false);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| CreateLabel - ラベルオブジェクト作成ヘルパー                          |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y,
                 color clr, string font, int fontSize,
                 ENUM_BASE_CORNER corner)
{
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

//+------------------------------------------------------------------+
//| CreateButton - ボタンオブジェクト作成ヘルパー（v2: 洗練デザイン）      |
//+------------------------------------------------------------------+
void CreateButton(string name, string text, int x, int y,
                  int width, int height)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, name, OBJPROP_COLOR, C'200,210,230');
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'28,30,45');
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'50,100,180');
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| UpdateTrendBox - トレンド表示ボックスの更新                          |
//+------------------------------------------------------------------+
void UpdateTrendBox(bool isBullish)
{
   color trendColor = isBullish ? InpBullColor : InpBearColor;

   // ボックス枠線の色更新
   ObjectSetInteger(0, g_prefix + "TrendBox", OBJPROP_COLOR, trendColor);

   // 矢印の方向と色更新
   string arrowChar = isBullish ? "é" : "ê";
   ObjectSetString(0, g_prefix + "TrendArrow", OBJPROP_TEXT, arrowChar);
   ObjectSetInteger(0, g_prefix + "TrendArrow", OBJPROP_COLOR, clrWhite);

   // ON/OFF表示更新
   ObjectSetString(0, g_prefix + "OnOffLabel", OBJPROP_TEXT,
                   g_indicatorON ? "ON" : "OFF");
   ObjectSetInteger(0, g_prefix + "OnOffLabel", OBJPROP_COLOR,
                    g_indicatorON ? C'0,255,100' : C'100,100,100');
}

//+------------------------------------------------------------------+
//| UpdateDashboard - MTFダッシュボードの更新                            |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!g_indicatorON) return;

   int dashToMTF[3] = {2, 1, 0};

   for(int row = 0; row < 3; row++)
   {
      int mtfIdx = dashToMTF[row];

      double mtfFastEMA[1], mtfSlowEMA[1], mtfRSI[1];
      double mtfADXMain[1], mtfADXPlus[1], mtfADXMinus[1];

      if(CopyBuffer(g_handleMTF_FastEMA[mtfIdx], 0, 0, 1, mtfFastEMA) <= 0) continue;
      if(CopyBuffer(g_handleMTF_SlowEMA[mtfIdx], 0, 0, 1, mtfSlowEMA) <= 0) continue;
      if(CopyBuffer(g_handleMTF_RSI[mtfIdx],     0, 0, 1, mtfRSI)     <= 0) continue;
      if(CopyBuffer(g_handleMTF_ADX[mtfIdx],     0, 0, 1, mtfADXMain) <= 0) continue;
      if(CopyBuffer(g_handleMTF_ADX[mtfIdx],     1, 0, 1, mtfADXPlus) <= 0) continue;
      if(CopyBuffer(g_handleMTF_ADX[mtfIdx],     2, 0, 1, mtfADXMinus)<= 0) continue;

      //--- スコア計算
      double score = 0.0;
      bool isBull = (mtfFastEMA[0] > mtfSlowEMA[0]);

      // EMAトレンド成分（0-40）
      double emaSpread = 0;
      if(mtfSlowEMA[0] != 0)
         emaSpread = MathAbs(mtfFastEMA[0] - mtfSlowEMA[0]) / mtfSlowEMA[0] * 10000.0;
      double emaScore = MathMin(emaSpread, 40.0);

      // RSI成分（0-30）
      double rsiScore;
      if(isBull)
         rsiScore = MathMax(0, MathMin(30, (mtfRSI[0] - 40.0) / 30.0 * 30.0));
      else
         rsiScore = MathMax(0, MathMin(30, (60.0 - mtfRSI[0]) / 30.0 * 30.0));

      // ADX成分（0-30）
      double adxScore = MathMin(mtfADXMain[0] / 50.0 * 30.0, 30.0);
      if(!((isBull && mtfADXPlus[0] > mtfADXMinus[0]) ||
           (!isBull && mtfADXMinus[0] > mtfADXPlus[0])))
         adxScore = adxScore * 0.5;

      score = emaScore + rsiScore + adxScore;
      score = MathMax(0, MathMin(100, score));

      if(isBull && score < 50) score = 50 + (score / 2.0);
      if(!isBull && score > 50) score = 50 - (score / 2.0);
      if(!isBull) score = 100.0 - score;

      int scoreInt = (int)MathRound(score);
      color scoreColor = isBull ? InpBullColor : InpBearColor;

      //--- スコア表示更新
      ObjectSetString(0, g_prefix + "DashScore_" + IntegerToString(row),
                      OBJPROP_TEXT, IntegerToString(scoreInt));
      ObjectSetInteger(0, g_prefix + "DashScore_" + IntegerToString(row),
                       OBJPROP_COLOR, scoreColor);

      // 方向アイコン
      string iconChar = isBull ? "é" : "ê";
      ObjectSetString(0, g_prefix + "DashIcon_" + IntegerToString(row),
                      OBJPROP_TEXT, iconChar);
      ObjectSetInteger(0, g_prefix + "DashIcon_" + IntegerToString(row),
                       OBJPROP_COLOR, scoreColor);

      // スコアバーの更新（スコアに応じてバー幅を変更）
      int barWidth = (int)MathRound(42.0 * scoreInt / 100.0);
      barWidth = MathMax(1, barWidth);
      ObjectSetInteger(0, g_prefix + "DashBar_" + IntegerToString(row),
                       OBJPROP_XSIZE, barWidth);
      ObjectSetInteger(0, g_prefix + "DashBar_" + IntegerToString(row),
                       OBJPROP_BGCOLOR, scoreColor);
      ObjectSetInteger(0, g_prefix + "DashBar_" + IntegerToString(row),
                       OBJPROP_COLOR, scoreColor);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| END OF FILE                                                        |
//| Visual_Logic_Masterpiece.mq5 v2.0                                 |
//|                                                                    |
//| 【v2.0 変更点】                                                    |
//| 1. 利確ターゲット（TP）システムの追加                                |
//|    - ATR + スイング高値/安値 + BB の3要素融合                       |
//|    - TPダイヤモンドマーカー（緑◆）で到達点を可視化                   |
//|    - TP水平ダッシュラインで目標価格を常時表示                        |
//|    - TP情報ラベルで現在のTP価格を数値表示                            |
//|                                                                    |
//| 2. UI サイズ修正                                                    |
//|    - トレンドボックスをOBJ_RECTANGLE_LABELに変更                    |
//|    - 矢印サイズを28ptに縮小し、ボックス内に完全収容                  |
//|    - ボタンをボックスと同幅に統一、均等配置                           |
//|                                                                    |
//| 3. ビジュアル品質向上                                                |
//|    - 全体的な配色をダークネオンテーマに統一                           |
//|    - ダッシュボードにスコアバーを追加                                 |
//|    - クラウド色の彩度を微調整                                        |
//|    - ボタン/パネルの背景色・枠線色を洗練                             |
//+------------------------------------------------------------------+
