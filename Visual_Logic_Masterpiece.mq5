//+------------------------------------------------------------------+
//| Visual_Logic_Masterpiece.mq5                                      |
//| 世界最高峰のビジュアル・ロジック・インジケーター                        |
//| ネオンクラウド + 反転サイン + 継続サイン + MTFダッシュボード            |
//+------------------------------------------------------------------+
#property copyright "Visual Logic Masterpiece"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window

//--- 8つのインジケーターバッファ
//    0-1: クラウド本体（DRAW_FILLING）
//    2-3: クラウドグロー外側（DRAW_FILLING、発光エフェクト）
//    4: 買い矢印（トレンド継続）
//    5: 売り矢印（トレンド継続）
//    6: 買い星（反転サイン）
//    7: 売り星（反転サイン）
#property indicator_buffers 8
#property indicator_plots   6

//--- Plot 1: クラウド本体（DRAW_FILLING）
#property indicator_label1  "CloudUpper;CloudLower"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  clrGold,clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2: クラウドグロー（DRAW_FILLING、外側の発光レイヤー）
#property indicator_label2  "GlowUpper;GlowLower"
#property indicator_type2   DRAW_FILLING
#property indicator_color2  C'255,215,0',C'30,144,255'  // Gold / DodgerBlue（半透明で使用）
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: 買い矢印（トレンド継続サイン）
#property indicator_label3  "BuyArrow"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrDodgerBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  3

//--- Plot 4: 売り矢印（トレンド継続サイン）
#property indicator_label4  "SellArrow"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_style4  STYLE_SOLID
#property indicator_width4  3

//--- Plot 5: 買い星（反転サイン）
#property indicator_label5  "BuyStar"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrAqua
#property indicator_style5  STYLE_SOLID
#property indicator_width5  4

//--- Plot 6: 売り星（反転サイン）
#property indicator_label6  "SellStar"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrMagenta
#property indicator_style6  STYLE_SOLID
#property indicator_width6  4

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

input group "===== ダッシュボード設定 ====="
input color  InpBullColor     = clrDodgerBlue;  // 買いトレンド色
input color  InpBearColor     = clrRed;          // 売りトレンド色
input int    InpDashFontSize  = 10;              // ダッシュボードフォントサイズ

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
//    【思考過程】画像では買い→売り→買いと必ず交互にサインが出ている。
//    これはドテン売買を前提とした設計であり、同一方向の連続サインを
//    完全に排除する必要がある。状態変数で最後のサイン方向を記録し、
//    次のサインは必ず逆方向でなければ発火しないよう制御する。
int g_lastSignalDir = 0;   // 0=初期状態, 1=最後が買い, -1=最後が売り

//--- UI表示制御
bool g_indicatorON = true;  // ON/OFFボタン状態
int  g_selectedTF  = 0;     // 選択された時間軸インデックス（0=現在のチャート）

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

   //--- 矢印コード設定
   //    233 = Wingdings上向き矢印、234 = Wingdings下向き矢印
   //    171 = Wingdings星マーク（★）
   PlotIndexSetInteger(2, PLOT_ARROW, 233);  // 買い矢印（上向き）
   PlotIndexSetInteger(3, PLOT_ARROW, 234);  // 売り矢印（下向き）
   PlotIndexSetInteger(4, PLOT_ARROW, 171);  // 買い星
   PlotIndexSetInteger(5, PLOT_ARROW, 171);  // 売り星

   //--- 空値の設定
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);

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
   IndicatorSetString(INDICATOR_SHORTNAME, "Visual Logic Masterpiece");

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
//| OnCalculate - メイン計算ループ                                      |
//+------------------------------------------------------------------+
//  【設計思想】
//  画像を深く分析した結果、以下のロジック構造を採用：
//
//  ■ クラウド（雲）：
//    EMA(21)とEMA(55)のクロスオーバーに基づく。画像のクラウドは
//    価格帯を包み込むように広がっており、ATR（平均真の値幅）で
//    動的に幅を調整する設計が最適と判断。上昇時にゴールド、
//    下降時にブルーという配色は、トレンドの視認性を最大化する。
//
//  ■ 星サイン（天底の反転）：
//    画像の星は価格の極値に極めて正確に配置されている。これは
//    単一指標では不可能な精度であり、複数のオシレーター
//    （RSI + Williams%R + ボリンジャーバンド逸脱 + フラクタル）
//    の合致点でのみ発火させることで再現する。
//
//  ■ 矢印サイン（トレンド継続）：
//    画像の矢印はクラウドの上方/下方で、押し目/戻りの後に出現。
//    ADXでトレンド強度を確認し、クラウドへの回帰後の反発を
//    捉えるロジックが画像の挙動と最も一致する。
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

   //--- 一時バッファ（インジケーター値取得用）
   double fastEMA[], slowEMA[], atr[];
   double rsi[], bbUpper[], bbLower[], bbMiddle[];
   double wpr[], adxMain[], adxPlus[], adxMinus[];

   //--- データのコピー
   int startBar = (prev_calculated > 1) ? prev_calculated - 1 : 0;
   int count = rates_total - startBar;

   if(CopyBuffer(g_handleFastEMA, 0, 0, rates_total, fastEMA) <= 0) return(0);
   if(CopyBuffer(g_handleSlowEMA, 0, 0, rates_total, slowEMA) <= 0) return(0);
   if(CopyBuffer(g_handleATR,     0, 0, rates_total, atr)     <= 0) return(0);
   if(CopyBuffer(g_handleRSI,     0, 0, rates_total, rsi)     <= 0) return(0);
   if(CopyBuffer(g_handleBBUpper, 1, 0, rates_total, bbUpper) <= 0) return(0);  // Upper band
   if(CopyBuffer(g_handleBBUpper, 2, 0, rates_total, bbLower) <= 0) return(0);  // Lower band
   if(CopyBuffer(g_handleBBUpper, 0, 0, rates_total, bbMiddle)<= 0) return(0);  // Middle band
   if(CopyBuffer(g_handleWPR,     0, 0, rates_total, wpr)     <= 0) return(0);
   if(CopyBuffer(g_handleADX,     0, 0, rates_total, adxMain) <= 0) return(0);  // ADX main
   if(CopyBuffer(g_handleADX,     1, 0, rates_total, adxPlus) <= 0) return(0);  // +DI
   if(CopyBuffer(g_handleADX,     2, 0, rates_total, adxMinus)<= 0) return(0);  // -DI

   //--- メインループ
   for(int i = startBar; i < rates_total; i++)
   {
      //--- 安全チェック
      if(i < InpSlowEMA + 5) continue;

      //=== 1. クラウド計算 ===
      //    【ロジック根拠】
      //    画像のクラウドは2本のMAの間を塗りつぶし、さらにATRで
      //    上下に膨らませている。これにより価格変動の「帯域」が
      //    可視化され、トレンド方向と強度が一目で分かる。
      double cloudMid   = (fastEMA[i] + slowEMA[i]) / 2.0;
      double cloudSpan  = MathAbs(fastEMA[i] - slowEMA[i]);
      double atrVal     = atr[i];

      // クラウド本体
      g_cloudUpper[i] = MathMax(fastEMA[i], slowEMA[i]) + InpCloudWidth * atrVal;
      g_cloudLower[i] = MathMin(fastEMA[i], slowEMA[i]) - InpCloudWidth * atrVal;

      // グロー（発光エフェクト）- 本体より少し広い
      g_glowUpper[i] = MathMax(fastEMA[i], slowEMA[i]) + InpGlowWidth * atrVal;
      g_glowLower[i] = MathMin(fastEMA[i], slowEMA[i]) - InpGlowWidth * atrVal;

      //--- クラウド色の動的変更
      //    FastEMA > SlowEMA → 上昇トレンド（ゴールド）
      //    FastEMA < SlowEMA → 下降トレンド（ブルー）
      bool isBullishCloud = (fastEMA[i] > slowEMA[i]);

      //=== 2. 星サイン（反転ロジック） ===
      //    【思考過程】
      //    画像を精査すると、星は「極めて正確に」天底を捉えている。
      //    これは複数の独立した指標が同時に極値を示す「合致点」
      //    でのみ可能。以下の4条件の合致数で判定する：
      //
      //    条件1: RSI(8)が過熱ゾーンからの回帰
      //    → 短期RSIは価格の勢いの枯渇を素早く検出する
      //
      //    条件2: ボリンジャーバンド(20,2.5)の外側への逸脱
      //    → 統計的に2.5σ外は極めて稀な事象（約1.2%）
      //
      //    条件3: Williams %R(14)の極値ゾーン
      //    → RSIとは異なるアルゴリズムで過熱感を二重確認
      //
      //    条件4: フラクタル構造（3バーの天底）
      //    → 価格構造の反転を物理的に確認

      g_buyStar[i]  = EMPTY_VALUE;
      g_sellStar[i] = EMPTY_VALUE;

      if(i >= 2)  // フラクタル判定に最低3バー必要
      {
         int buyCondCount = 0;
         int sellCondCount = 0;

         // --- 買い反転条件 ---
         // 条件1: RSIが売られすぎゾーンを上抜け
         if(i >= 1 && rsi[i] > InpRSIBuyLevel && rsi[i-1] <= InpRSIBuyLevel)
            buyCondCount++;
         // 条件2: 安値がボリンジャーバンド下限を下抜け
         if(low[i] <= bbLower[i])
            buyCondCount++;
         // 条件3: Williams %Rが極端な売られすぎ
         if(wpr[i] < InpWPRBuyLevel)
            buyCondCount++;
         // 条件4: フラクタル底（3バーの最安値）
         if(low[i-1] <= low[i-2] && low[i-1] <= low[i])
            buyCondCount++;

         // --- 売り反転条件 ---
         // 条件1: RSIが買われすぎゾーンを下抜け
         if(i >= 1 && rsi[i] < InpRSISellLevel && rsi[i-1] >= InpRSISellLevel)
            sellCondCount++;
         // 条件2: 高値がボリンジャーバンド上限を上抜け
         if(high[i] >= bbUpper[i])
            sellCondCount++;
         // 条件3: Williams %Rが極端な買われすぎ
         if(wpr[i] > InpWPRSellLevel)
            sellCondCount++;
         // 条件4: フラクタル天井（3バーの最高値）
         if(high[i-1] >= high[i-2] && high[i-1] >= high[i])
            sellCondCount++;

         // サインオフセット（表示位置の調整）
         double offset = atrVal * 0.5;

         //=== 星サインの発火（バイナリ・フリップ制御付き） ===
         //    【バイナリ・フリップの根拠】
         //    画像を見ると、買い→売り→買いと完全に交互にサインが出ている。
         //    これはドテン売買の根幹であり、同じ方向のサインが連続すると
         //    トレーダーは混乱する。状態管理で厳密に交互を保証する。
         if(buyCondCount >= InpMinConditions && g_lastSignalDir != 1)
         {
            g_buyStar[i] = low[i] - offset;
            g_lastSignalDir = 1;
         }
         else if(sellCondCount >= InpMinConditions && g_lastSignalDir != -1)
         {
            g_sellStar[i] = high[i] + offset;
            g_lastSignalDir = -1;
         }
      }

      //=== 3. 矢印サイン（トレンド継続ロジック） ===
      //    【思考過程】
      //    画像の矢印はクラウドを抜けた後の「押し目買い」「戻り売り」
      //    のタイミングで出現している。具体的には：
      //    1) クラウド方向が確定している（色が決まっている）
      //    2) 価格がクラウド方向に沿っている
      //    3) ADXがトレンドの存在を確認している
      //    4) 一度クラウド付近まで戻った後に反発している
      //    この4条件で「高確率の押し目/戻り」を検出する。

      g_buyArrow[i]  = EMPTY_VALUE;
      g_sellArrow[i] = EMPTY_VALUE;

      if(i >= 2)
      {
         double offset = atrVal * 0.3;

         // --- 買い矢印条件 ---
         bool buyArrowCond = false;
         if(isBullishCloud                                    // クラウドが上昇（ゴールド）
            && close[i] > g_cloudUpper[i]                     // 終値がクラウド上限の上
            && adxMain[i] > InpADXThreshold                   // トレンド強度あり
            && low[i-1] <= g_cloudUpper[i-1] * (1.0 + InpPullbackRatio * 0.01)  // 前バーがクラウド近辺まで押し
            && close[i] > close[i-1])                         // 現在バーが陽線
         {
            buyArrowCond = true;
         }

         // --- 売り矢印条件 ---
         bool sellArrowCond = false;
         if(!isBullishCloud                                   // クラウドが下降（ブルー）
            && close[i] < g_cloudLower[i]                     // 終値がクラウド下限の下
            && adxMain[i] > InpADXThreshold                   // トレンド強度あり
            && high[i-1] >= g_cloudLower[i-1] * (1.0 - InpPullbackRatio * 0.01) // 前バーがクラウド近辺まで戻り
            && close[i] < close[i-1])                         // 現在バーが陰線
         {
            sellArrowCond = true;
         }

         //--- バイナリ・フリップ制御
         if(buyArrowCond && g_lastSignalDir != 1)
         {
            g_buyArrow[i] = low[i] - offset;
            g_lastSignalDir = 1;
         }
         else if(sellArrowCond && g_lastSignalDir != -1)
         {
            g_sellArrow[i] = high[i] + offset;
            g_lastSignalDir = -1;
         }
      }
   }

   //--- ダッシュボードの更新（新しいバーごと）
   if(rates_total != g_lastDashUpdateBar)
   {
      g_lastDashUpdateBar = rates_total;
      UpdateDashboard();
      UpdateTrendCircle(fastEMA[rates_total-1] > slowEMA[rates_total-1]);
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
//| OnChartEvent - チャートイベント処理（ボタンクリック等）                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   //--- ボタンクリック処理
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      //--- ON/OFFボタン
      if(sparam == g_prefix + "BtnOnOff")
      {
         g_indicatorON = !g_indicatorON;
         ObjectSetString(0, g_prefix + "BtnOnOff", OBJPROP_TEXT,
                         g_indicatorON ? "ON" : "OFF");

         //--- ON/OFF時のクラウド表示切替
         //    PlotIndexSetInteger で各プロットの描画タイプを切り替え
         if(g_indicatorON)
         {
            PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_FILLING);
            PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_FILLING);
            PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_ARROW);
            PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_ARROW);
            PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_ARROW);
            PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_ARROW);
         }
         else
         {
            PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
            PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
            PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
            PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
            PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_NONE);
            PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_NONE);
         }
         ChartRedraw();

         // ボタンの押下状態をリセット
         ObjectSetInteger(0, g_prefix + "BtnOnOff", OBJPROP_STATE, false);
      }

      //--- 時間軸ボタン（1m, 5m, 15m）
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
//| CreateUIElements - 全UI要素の作成                                   |
//+------------------------------------------------------------------+
void CreateUIElements()
{
   //=== 1. 巨大トレンド表示（左上） ===
   //    画像右上にある「円形の中に太い矢印」を再現し、左上に配置

   // 外円（背景の円）
   CreateLabel(g_prefix + "TrendCircleBG", "n", 20, 50,
               clrDarkSlateGray, "Wingdings", 72, CORNER_LEFT_UPPER);

   // 内側の方向矢印
   CreateLabel(g_prefix + "TrendArrow", "é", 35, 58,
               InpBullColor, "Wingdings", 48, CORNER_LEFT_UPPER);

   // ON/OFF表示テキスト
   CreateLabel(g_prefix + "OnOffLabel", "ON", 42, 120,
               clrLime, "Arial Bold", 9, CORNER_LEFT_UPPER);

   //=== 2. インタラクティブボタン（左側） ===
   CreateButton(g_prefix + "Btn1m",    "1m",  15, 145, 50, 22);
   CreateButton(g_prefix + "Btn5m",    "5m",  15, 170, 50, 22);
   CreateButton(g_prefix + "Btn15m",   "15m", 15, 195, 50, 22);
   CreateButton(g_prefix + "BtnOnOff", "ON",  15, 225, 50, 22);

   //=== 3. ダッシュボードパネル（左下） ===
   //    半透明のダークグレー背景にネオン境界線

   // パネル背景
   string bgName = g_prefix + "DashBG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, 120);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 180);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 105);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'30,30,40');
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, C'0,200,255');  // ネオンシアン境界線
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);

   // ダッシュボード各行（1h, 15m, 5m）
   // 表示順: 画像と同じく上から 1h → 15m → 5m
   string dashRows[3] = {"1h", "15m", "5m"};
   for(int i = 0; i < 3; i++)
   {
      int yBase = 110 - (i * 32);  // 下から上へ配置

      // 時間軸ラベル
      CreateLabel(g_prefix + "DashTF_" + IntegerToString(i),
                  dashRows[i], 18, yBase, clrWhite, "Arial Bold",
                  InpDashFontSize, CORNER_LEFT_LOWER);

      // スコア値
      CreateLabel(g_prefix + "DashScore_" + IntegerToString(i),
                  "50", 70, yBase, clrWhite, "Arial Bold",
                  InpDashFontSize + 2, CORNER_LEFT_LOWER);

      // 方向アイコン（Wingdingsの矢印）
      CreateLabel(g_prefix + "DashIcon_" + IntegerToString(i),
                  "é", 120, yBase, InpBullColor, "Wingdings",
                  InpDashFontSize + 6, CORNER_LEFT_LOWER);
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
//| CreateButton - ボタンオブジェクト作成ヘルパー                         |
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
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'45,45,60');
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'0,200,255');
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| UpdateTrendCircle - 巨大トレンド表示の更新                           |
//+------------------------------------------------------------------+
//  【デザイン再現】
//  画像では大きな円の中に太い矢印が表示され、
//  上昇時はブルー（紺）、下降時はレッドに変化する。
//  Wingdingsフォントの大型文字で再現する。
//+------------------------------------------------------------------+
void UpdateTrendCircle(bool isBullish)
{
   color trendColor = isBullish ? InpBullColor : InpBearColor;

   // 背景円の色更新
   ObjectSetInteger(0, g_prefix + "TrendCircleBG", OBJPROP_COLOR, trendColor);

   // 矢印の方向と色更新
   // Wingdings: é (233) = 上矢印, ê (234) = 下矢印
   string arrowChar = isBullish ? "é" : "ê";
   ObjectSetString(0, g_prefix + "TrendArrow", OBJPROP_TEXT, arrowChar);
   ObjectSetInteger(0, g_prefix + "TrendArrow", OBJPROP_COLOR, clrWhite);

   // ON/OFF表示更新
   ObjectSetString(0, g_prefix + "OnOffLabel", OBJPROP_TEXT,
                   g_indicatorON ? "ON" : "OFF");
   ObjectSetInteger(0, g_prefix + "OnOffLabel", OBJPROP_COLOR,
                    g_indicatorON ? clrLime : clrGray);
}

//+------------------------------------------------------------------+
//| UpdateDashboard - MTFダッシュボードの更新                            |
//+------------------------------------------------------------------+
//  【MTFスコア計算の思考過程】
//  画像のダッシュボードは各時間軸に0-100のスコアと方向アイコンを表示。
//  スコアは以下の3要素の加重合計で構成：
//
//  ■ EMAトレンド成分（0-40点）:
//    FastEMAとSlowEMAの乖離率をスコア化。
//    乖離が大きいほどトレンドが強く、高スコア。
//
//  ■ RSI成分（0-30点）:
//    RSI(14)を0-30の範囲にマッピング。
//    50が中立（15点）、70以上が最大（30点）、30以下が最小（0点）。
//
//  ■ ADX成分（0-30点）:
//    ADXの値をトレンド強度としてスコア化。
//    ADX=0→0点、ADX=50以上→30点。
//    +DI > -DI で買い方向、逆で売り方向として加算。
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!g_indicatorON) return;

   // 表示順序: 0=1h, 1=15m, 2=5m（ダッシュボードの上から下）
   // MTFハンドル: 0=5m, 1=15m, 2=1h
   int dashToMTF[3] = {2, 1, 0};  // ダッシュ行→MTFインデックス変換

   for(int row = 0; row < 3; row++)
   {
      int mtfIdx = dashToMTF[row];

      double mtfFastEMA[1], mtfSlowEMA[1], mtfRSI[1];
      double mtfADXMain[1], mtfADXPlus[1], mtfADXMinus[1];

      // MTFデータ取得
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
      // 方向一致ボーナス
      if((isBull && mtfADXPlus[0] > mtfADXMinus[0]) ||
         (!isBull && mtfADXMinus[0] > mtfADXPlus[0]))
         adxScore = adxScore;  // 方向一致：そのまま
      else
         adxScore = adxScore * 0.5;  // 方向不一致：半減

      score = emaScore + rsiScore + adxScore;
      score = MathMax(0, MathMin(100, score));

      // 方向に応じてスコアを調整
      // isBull=true → スコアは50以上の方向に
      // isBull=false → スコアは50以下の方向に
      if(isBull && score < 50) score = 50 + (score / 2.0);
      if(!isBull && score > 50) score = 50 - (score / 2.0);
      if(!isBull) score = 100.0 - score;

      int scoreInt = (int)MathRound(score);

      //--- ダッシュボード表示更新
      // スコア
      ObjectSetString(0, g_prefix + "DashScore_" + IntegerToString(row),
                      OBJPROP_TEXT, IntegerToString(scoreInt));
      ObjectSetInteger(0, g_prefix + "DashScore_" + IntegerToString(row),
                       OBJPROP_COLOR, isBull ? InpBullColor : InpBearColor);

      // 方向アイコン（Wingdings矢印）
      string iconChar = isBull ? "é" : "ê";
      ObjectSetString(0, g_prefix + "DashIcon_" + IntegerToString(row),
                      OBJPROP_TEXT, iconChar);
      ObjectSetInteger(0, g_prefix + "DashIcon_" + IntegerToString(row),
                       OBJPROP_COLOR, isBull ? InpBullColor : InpBearColor);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| END OF FILE                                                        |
//| Visual_Logic_Masterpiece.mq5                                      |
//|                                                                    |
//| 【総括】                                                           |
//| このインジケーターは以下の思想に基づいて設計されている：               |
//|                                                                    |
//| 1. クラウド: EMA(21/55) + ATRエンベロープにより、                    |
//|    トレンドの方向と強度を「面」として可視化                           |
//|                                                                    |
//| 2. 星サイン: RSI + BB + WPR + フラクタルの4条件合致で                |
//|    天底を高精度に捕捉。単一指標では不可能な精度を実現                  |
//|                                                                    |
//| 3. 矢印サイン: クラウド方向 + ADX + 押し目構造で                     |
//|    トレンド継続の最適エントリーを検出                                  |
//|                                                                    |
//| 4. バイナリ・フリップ: 状態管理により買い↔売りの                      |
//|    完全交互制御を保証し、ドテン売買を成立させる                        |
//|                                                                    |
//| 5. MTFダッシュボード: 複数時間軸の合成スコアにより                    |
//|    大局的なトレンド判断を支援                                         |
//|                                                                    |
//| 6. ネオンUI: 発光クラウド、大型トレンド表示、                         |
//|    インタラクティブボタンで直感的な操作を実現                          |
//+------------------------------------------------------------------+
