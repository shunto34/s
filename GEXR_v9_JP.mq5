//+------------------------------------------------------------------+
//|                                                  GEXR_v9_JP.mq5  |
//|  GEXR v9.0 風 MT5 インジケーター (究極近似版・完全日本語化)        |
//|                                                                  |
//|  TradingView 有償インジ「GEXR v9.0」のスクリーンショット解析に    |
//|  基づく近似再現。GEX/PUT/CALL 等のオプション由来レベルは          |
//|  クラシカルピボット計算で代替。シグナルは ATR FLIP FTI            |
//|  (SuperTrend系) + 感度フィルター で構築。                          |
//+------------------------------------------------------------------+
#property copyright "GEXR v9.0 JP - 究極近似版"
#property link      ""
#property version   "9.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 18
#property indicator_plots   10

//--- Plot 0: ColorCandles (Paint Candles)
#property indicator_label1   "始値;高値;安値;終値"
#property indicator_type1    DRAW_COLOR_CANDLES
#property indicator_color1   C'80,80,80',C'0,200,80',C'220,50,80'
#property indicator_style1   STYLE_SOLID
#property indicator_width1   1

//--- Plot 1: EMA リボン外側フィル
#property indicator_label2   "リボン外側上;リボン外側下"
#property indicator_type2    DRAW_FILLING
#property indicator_color2   C'40,160,90',C'160,40,60'
#property indicator_style2   STYLE_SOLID
#property indicator_width2   1

//--- Plot 2: EMA リボン内側フィル
#property indicator_label3   "リボン内側上;リボン内側下"
#property indicator_type3    DRAW_FILLING
#property indicator_color3   C'80,220,140',C'220,80,100'
#property indicator_style3   STYLE_SOLID
#property indicator_width3   1

//--- Plot 3: フリップライン (SuperTrend trail)
#property indicator_label4   "フリップライン"
#property indicator_type4    DRAW_COLOR_LINE
#property indicator_color4   C'0,200,80',C'220,50,80'
#property indicator_style4   STYLE_SOLID
#property indicator_width4   2

//--- Plot 4: 50EMA
#property indicator_label5   "50EMA"
#property indicator_type5    DRAW_LINE
#property indicator_color5   C'255,200,100'
#property indicator_style5   STYLE_DOT
#property indicator_width5   1

//--- Plot 5: スコアリボン
#property indicator_label6   "スコアリボン上;スコアリボン下"
#property indicator_type6    DRAW_FILLING
#property indicator_color6   C'30,120,80',C'120,30,60'
#property indicator_style6   STYLE_SOLID
#property indicator_width6   1

//--- Plot 6: LONG 矢印
#property indicator_label7   "LONG"
#property indicator_type7    DRAW_ARROW
#property indicator_color7   C'0,230,120'
#property indicator_style7   STYLE_SOLID
#property indicator_width7   3

//--- Plot 7: SHORT 矢印
#property indicator_label8   "SHORT"
#property indicator_type8    DRAW_ARROW
#property indicator_color8   C'255,80,100'
#property indicator_style8   STYLE_SOLID
#property indicator_width8   3

//--- Plot 8: 継続LONG (小)
#property indicator_label9   "継続LONG"
#property indicator_type9    DRAW_ARROW
#property indicator_color9   C'80,220,180'
#property indicator_style9   STYLE_SOLID
#property indicator_width9   1

//--- Plot 9: 継続SHORT (小)
#property indicator_label10  "継続SHORT"
#property indicator_type10   DRAW_ARROW
#property indicator_color10  C'255,150,170'
#property indicator_style10  STYLE_SOLID
#property indicator_width10  1

// 朝のチェックポイントマーカーはオブジェクトで描画する (バッファ不要)

//+------------------------------------------------------------------+
//| 列挙型定義                                                          |
//+------------------------------------------------------------------+
enum ENUM_GEX_MODE
{
   MODE_AUTO      = 0,  // 自動
   MODE_SCALP     = 1,  // スキャルプ
   MODE_BALANCED  = 2,  // バランス
   MODE_SWING     = 3   // スイング
};

enum ENUM_SENSITIVITY
{
   SENS_LOOSE     = 0,  // 緩い
   SENS_BALANCED  = 1,  // 標準
   SENS_ELITE     = 2   // 精密
};

enum ENUM_CONFIRM
{
   CONFIRM_LOOSE     = 0, // 緩
   CONFIRM_BALANCED  = 1, // 標準
   CONFIRM_ELITE     = 2  // 精
};

enum ENUM_LABEL_SIZE
{
   LABEL_SMALL  = 8,    // 小
   LABEL_MEDIUM = 10,   // 中
   LABEL_LARGE  = 12    // 大
};

//+------------------------------------------------------------------+
//| 入力パラメーター                                                    |
//+------------------------------------------------------------------+
input group "===== モード設定 ====="
input ENUM_GEX_MODE     InpMode          = MODE_AUTO;       // モード
input ENUM_SENSITIVITY  InpSensitivity   = SENS_BALANCED;   // シグナル感度
input ENUM_CONFIRM      InpConfirmMode   = CONFIRM_BALANCED;// 確認モード

input group "===== シグナル表示 ====="
input bool   InpShowATRSignals    = true;   // ATR シグナル表示
input bool   InpShowATRShading    = false;  // ATR セッションシェード
input bool   InpPaintCandles      = true;   // ローソク色塗り
input bool   InpUse50EMABias      = false;  // 50EMA バイアス使用
input bool   InpUse100SMAFilter   = false;  // 100SMA フィルター使用
input bool   InpAllowContinuation = true;   // 継続シグナル許可
input bool   InpShow50EMA         = false;  // 50EMA ライン表示
input bool   InpShowFlipLine      = false;  // フリップライン表示
input bool   InpShowScoreRibbon   = true;   // スコアリボン表示
input bool   InpShowEMARibbon     = true;   // EMA リボン表示

input group "===== 意識価格帯 (ピボット代替) ====="
input bool             InpShowPivotLevels = true;        // 意識価格帯ライン表示
input bool             InpShowPivotLabels = true;        // ラベル文字表示
input ENUM_LABEL_SIZE  InpLabelSize       = LABEL_SMALL; // ラベルサイズ
input int              InpLabelShift      = 8;           // ラベル右端からの距離(バー)

input group "===== セッション ====="
input int    InpSessionOpenHour    = 9;       // セッション開始(時・NY)
input int    InpSessionOpenMinute  = 30;      // セッション開始(分)
input int    InpSessionCloseHour   = 16;      // セッション終了(時・NY)
input int    InpSessionCloseMinute = 0;       // セッション終了(分)
input int    InpMorningHour        = 10;      // 朝のチェック時刻(時)
input int    InpMorningMinute      = 30;      // 朝のチェック時刻(分)
input int    InpNYServerOffset     = -7;      // サーバー時刻 - NY時刻(時)

input group "===== カラー設定 ====="
input color  InpBullColor    = C'0,200,80';   // ブル色
input color  InpBearColor    = C'220,50,80';  // ベア色
input color  InpNeutralColor = C'80,80,80';   // 中立色

//+------------------------------------------------------------------+
//| バッファ                                                            |
//+------------------------------------------------------------------+
double g_candleO[], g_candleH[], g_candleL[], g_candleC[], g_candleCol[];
double g_ribOutUp[], g_ribOutDn[];
double g_ribInUp[],  g_ribInDn[];
double g_flipLine[], g_flipColor[];
double g_ema50Buf[];
double g_scoreUp[],  g_scoreDn[];
double g_longArr[],  g_shortArr[];
double g_contLongArr[], g_contShortArr[];

//+------------------------------------------------------------------+
//| インジケーターハンドル                                              |
//+------------------------------------------------------------------+
int g_hEMA[8];          // リボン用 8 本
int g_hEMA50;
int g_hSMA100;
int g_hATR;

int g_emaPeriods[8] = {12, 18, 24, 30, 38, 46, 55, 66};

//+------------------------------------------------------------------+
//| グローバル状態                                                      |
//+------------------------------------------------------------------+
string  g_prefix         = "GEXR_";
int     g_trendDir       = 0;        // +1=ブル, -1=ベア
double  g_curFlip        = 0;        // 現在のフリップライン値
int     g_lastFlipBar    = -1;
int     g_confirmCount   = 0;

datetime g_lastPivotDate = 0;

//+------------------------------------------------------------------+
//| ピボットレベル構造                                                  |
//+------------------------------------------------------------------+
struct PivotLevel
{
   string nameJP;
   double price;
   color  clr;
   ENUM_LINE_STYLE style;
   int    width;
};
PivotLevel g_pivots[14];
int g_pivotCount = 0;

//+------------------------------------------------------------------+
//| OnInit                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   // バッファ割当 (Plot 0: ColorCandles は INDICATOR_DATA × 4 + INDICATOR_COLOR_INDEX)
   SetIndexBuffer(0,  g_candleO,    INDICATOR_DATA);
   SetIndexBuffer(1,  g_candleH,    INDICATOR_DATA);
   SetIndexBuffer(2,  g_candleL,    INDICATOR_DATA);
   SetIndexBuffer(3,  g_candleC,    INDICATOR_DATA);
   SetIndexBuffer(4,  g_candleCol,  INDICATOR_COLOR_INDEX);

   SetIndexBuffer(5,  g_ribOutUp,   INDICATOR_DATA);
   SetIndexBuffer(6,  g_ribOutDn,   INDICATOR_DATA);
   SetIndexBuffer(7,  g_ribInUp,    INDICATOR_DATA);
   SetIndexBuffer(8,  g_ribInDn,    INDICATOR_DATA);

   SetIndexBuffer(9,  g_flipLine,   INDICATOR_DATA);
   SetIndexBuffer(10, g_flipColor,  INDICATOR_COLOR_INDEX);

   SetIndexBuffer(11, g_ema50Buf,   INDICATOR_DATA);

   SetIndexBuffer(12, g_scoreUp,    INDICATOR_DATA);
   SetIndexBuffer(13, g_scoreDn,    INDICATOR_DATA);

   SetIndexBuffer(14, g_longArr,    INDICATOR_DATA);
   SetIndexBuffer(15, g_shortArr,   INDICATOR_DATA);
   SetIndexBuffer(16, g_contLongArr,INDICATOR_DATA);
   SetIndexBuffer(17, g_contShortArr,INDICATOR_DATA);

   // ArraySetAsSeries (昇順アクセスで OnCalculate と整合)
   ArraySetAsSeries(g_candleO,    false);
   ArraySetAsSeries(g_candleH,    false);
   ArraySetAsSeries(g_candleL,    false);
   ArraySetAsSeries(g_candleC,    false);
   ArraySetAsSeries(g_candleCol,  false);
   ArraySetAsSeries(g_ribOutUp,   false);
   ArraySetAsSeries(g_ribOutDn,   false);
   ArraySetAsSeries(g_ribInUp,    false);
   ArraySetAsSeries(g_ribInDn,    false);
   ArraySetAsSeries(g_flipLine,   false);
   ArraySetAsSeries(g_flipColor,  false);
   ArraySetAsSeries(g_ema50Buf,   false);
   ArraySetAsSeries(g_scoreUp,    false);
   ArraySetAsSeries(g_scoreDn,    false);
   ArraySetAsSeries(g_longArr,    false);
   ArraySetAsSeries(g_shortArr,   false);
   ArraySetAsSeries(g_contLongArr,false);
   ArraySetAsSeries(g_contShortArr,false);

   // 矢印コード
   PlotIndexSetInteger(6, PLOT_ARROW, 233);  // LONG (▲)
   PlotIndexSetInteger(7, PLOT_ARROW, 234);  // SHORT (▼)
   PlotIndexSetInteger(8, PLOT_ARROW, 225);  // 継続LONG (·)
   PlotIndexSetInteger(9, PLOT_ARROW, 226);  // 継続SHORT (·)

   // 空値設定
   for(int p = 0; p < 10; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // ColorCandles の色配列 (3 色)
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 3);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpNeutralColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpBullColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpBearColor);

   // フリップラインの色配列 (2 色)
   PlotIndexSetInteger(3, PLOT_COLOR_INDEXES, 2);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, 0, InpBullColor);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, 1, InpBearColor);

   // EMA ハンドル取得
   for(int i = 0; i < 8; i++)
   {
      g_hEMA[i] = iMA(_Symbol, PERIOD_CURRENT, g_emaPeriods[i], 0, MODE_EMA, PRICE_CLOSE);
      if(g_hEMA[i] == INVALID_HANDLE)
      {
         Print("エラー: EMA(", g_emaPeriods[i], ") ハンドル作成失敗");
         return(INIT_FAILED);
      }
   }
   g_hEMA50  = iMA(_Symbol, PERIOD_CURRENT, 50,  0, MODE_EMA, PRICE_CLOSE);
   g_hSMA100 = iMA(_Symbol, PERIOD_CURRENT, 100, 0, MODE_SMA, PRICE_CLOSE);
   int atrPer = GetATRPeriod();
   g_hATR    = iATR(_Symbol, PERIOD_CURRENT, atrPer);

   if(g_hEMA50 == INVALID_HANDLE || g_hSMA100 == INVALID_HANDLE ||
      g_hATR  == INVALID_HANDLE)
   {
      Print("エラー: 補助インジケーターハンドル作成失敗");
      return(INIT_FAILED);
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "GEXR v9.0 JP");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   // 初期状態
   g_trendDir = 0;
   g_curFlip  = 0;
   g_lastFlipBar = -1;
   g_confirmCount = 0;
   g_lastPivotDate = 0;

   EventSetTimer(2);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, g_prefix);
   for(int i = 0; i < 8; i++)
      if(g_hEMA[i] != INVALID_HANDLE) IndicatorRelease(g_hEMA[i]);
   if(g_hEMA50  != INVALID_HANDLE) IndicatorRelease(g_hEMA50);
   if(g_hSMA100 != INVALID_HANDLE) IndicatorRelease(g_hSMA100);
   if(g_hATR    != INVALID_HANDLE) IndicatorRelease(g_hATR);
   EventKillTimer();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| GetATRPeriod / GetATRMult - モード別パラメータ取得                  |
//+------------------------------------------------------------------+
int GetATRPeriod()
{
   ENUM_GEX_MODE m = ResolveMode();
   switch(m)
   {
      case MODE_SCALP:    return 7;
      case MODE_BALANCED: return 10;
      case MODE_SWING:    return 14;
      default:            return 10;
   }
}

double GetATRMult()
{
   ENUM_GEX_MODE m = ResolveMode();
   double base = 3.0;
   switch(m)
   {
      case MODE_SCALP:    base = 1.8; break;
      case MODE_BALANCED: base = 3.0; break;
      case MODE_SWING:    base = 4.0; break;
   }
   switch(InpSensitivity)
   {
      case SENS_LOOSE:    base *= 0.85; break;
      case SENS_BALANCED: base *= 1.00; break;
      case SENS_ELITE:    base *= 1.20; break;
   }
   return base;
}

int GetConfirmBars()
{
   switch(InpConfirmMode)
   {
      case CONFIRM_LOOSE:    return 0;
      case CONFIRM_BALANCED: return 1;
      case CONFIRM_ELITE:    return 2;
   }
   return 1;
}

ENUM_GEX_MODE ResolveMode()
{
   if(InpMode != MODE_AUTO) return InpMode;
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)Period();
   if(tf <= PERIOD_M5)  return MODE_SCALP;
   if(tf <= PERIOD_H1)  return MODE_BALANCED;
   return MODE_SWING;
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
                const int &spread[])
{
   if(rates_total < 110) return(0);

   int atrPer = GetATRPeriod();
   double atrMult = GetATRMult();
   int confirmBars = GetConfirmBars();

   // バッファ取得 (MQL5 では動的 2D 配列をハンドルに渡せないため個別宣言)
   static double ema0[], ema1[], ema2[], ema3[], ema4[], ema5[], ema6[], ema7[];
   ArraySetAsSeries(ema0, false); ArraySetAsSeries(ema1, false);
   ArraySetAsSeries(ema2, false); ArraySetAsSeries(ema3, false);
   ArraySetAsSeries(ema4, false); ArraySetAsSeries(ema5, false);
   ArraySetAsSeries(ema6, false); ArraySetAsSeries(ema7, false);
   if(CopyBuffer(g_hEMA[0], 0, 0, rates_total, ema0) <= 0) return(0);
   if(CopyBuffer(g_hEMA[1], 0, 0, rates_total, ema1) <= 0) return(0);
   if(CopyBuffer(g_hEMA[2], 0, 0, rates_total, ema2) <= 0) return(0);
   if(CopyBuffer(g_hEMA[3], 0, 0, rates_total, ema3) <= 0) return(0);
   if(CopyBuffer(g_hEMA[4], 0, 0, rates_total, ema4) <= 0) return(0);
   if(CopyBuffer(g_hEMA[5], 0, 0, rates_total, ema5) <= 0) return(0);
   if(CopyBuffer(g_hEMA[6], 0, 0, rates_total, ema6) <= 0) return(0);
   if(CopyBuffer(g_hEMA[7], 0, 0, rates_total, ema7) <= 0) return(0);

   double ema50[], sma100[], atr[];
   ArraySetAsSeries(ema50, false);
   ArraySetAsSeries(sma100, false);
   ArraySetAsSeries(atr, false);
   if(CopyBuffer(g_hEMA50,  0, 0, rates_total, ema50)  <= 0) return(0);
   if(CopyBuffer(g_hSMA100, 0, 0, rates_total, sma100) <= 0) return(0);
   if(CopyBuffer(g_hATR,    0, 0, rates_total, atr)    <= 0) return(0);

   int startBar = (prev_calculated > 1) ? prev_calculated - 1 : 100;

   // 初回計算時はトレンド状態と全バッファをリセット
   if(prev_calculated == 0)
   {
      g_trendDir = 0;
      g_curFlip = 0;
      g_confirmCount = 0;
      ArrayInitialize(g_candleO,    EMPTY_VALUE);
      ArrayInitialize(g_candleH,    EMPTY_VALUE);
      ArrayInitialize(g_candleL,    EMPTY_VALUE);
      ArrayInitialize(g_candleC,    EMPTY_VALUE);
      ArrayInitialize(g_candleCol,  0);
      ArrayInitialize(g_ribOutUp,   EMPTY_VALUE);
      ArrayInitialize(g_ribOutDn,   EMPTY_VALUE);
      ArrayInitialize(g_ribInUp,    EMPTY_VALUE);
      ArrayInitialize(g_ribInDn,    EMPTY_VALUE);
      ArrayInitialize(g_flipLine,   EMPTY_VALUE);
      ArrayInitialize(g_flipColor,  0);
      ArrayInitialize(g_ema50Buf,   EMPTY_VALUE);
      ArrayInitialize(g_scoreUp,    EMPTY_VALUE);
      ArrayInitialize(g_scoreDn,    EMPTY_VALUE);
      ArrayInitialize(g_longArr,    EMPTY_VALUE);
      ArrayInitialize(g_shortArr,   EMPTY_VALUE);
      ArrayInitialize(g_contLongArr,EMPTY_VALUE);
      ArrayInitialize(g_contShortArr,EMPTY_VALUE);
   }

   for(int i = startBar; i < rates_total; i++)
   {
      if(i < 100) continue;
      double atrVal = atr[i];
      if(atrVal <= 0) continue;

      //=== EMA リボン (異期間 EMA の最大/最小帯) ===
      double emaVals[8];
      emaVals[0] = ema0[i]; emaVals[1] = ema1[i]; emaVals[2] = ema2[i]; emaVals[3] = ema3[i];
      emaVals[4] = ema4[i]; emaVals[5] = ema5[i]; emaVals[6] = ema6[i]; emaVals[7] = ema7[i];
      double maxE = emaVals[0], minE = emaVals[0];
      for(int k = 1; k < 8; k++)
      {
         if(emaVals[k] > maxE) maxE = emaVals[k];
         if(emaVals[k] < minE) minE = emaVals[k];
      }

      if(InpShowEMARibbon)
      {
         g_ribOutUp[i] = maxE + atrVal * 0.15;
         g_ribOutDn[i] = minE - atrVal * 0.15;
         g_ribInUp[i]  = maxE;
         g_ribInDn[i]  = minE;
      }
      else
      {
         g_ribOutUp[i] = EMPTY_VALUE;
         g_ribOutDn[i] = EMPTY_VALUE;
         g_ribInUp[i]  = EMPTY_VALUE;
         g_ribInDn[i]  = EMPTY_VALUE;
      }

      //=== 50EMA 表示 ===
      g_ema50Buf[i] = InpShow50EMA ? ema50[i] : EMPTY_VALUE;

      //=== SuperTrend フリップロジック ===
      double hl2 = (high[i] + low[i]) * 0.5;
      double upBand  = hl2 + atrMult * atrVal;
      double lowBand = hl2 - atrMult * atrVal;

      // 初期トレンド設定
      if(g_trendDir == 0)
      {
         g_trendDir = (close[i] > ema50[i]) ? 1 : -1;
         g_curFlip  = (g_trendDir == 1) ? lowBand : upBand;
      }

      int prevDir = g_trendDir;  // フリップ判定用に保存

      // トレンド継続中のフリップライン更新 (トレイル)
      double newFlip = g_curFlip;
      if(g_trendDir == 1)
      {
         // ブル: lowBand を切上げのみ
         if(lowBand > g_curFlip || close[i-1] < g_curFlip)
            newFlip = lowBand;
         if(newFlip < g_curFlip) newFlip = g_curFlip;
         // 反転判定
         if(close[i] < newFlip)
         {
            g_confirmCount++;
            if(g_confirmCount > confirmBars)
            {
               g_trendDir = -1;
               g_curFlip  = upBand;
               g_confirmCount = 0;
            }
         }
         else
         {
            g_confirmCount = 0;
            g_curFlip = newFlip;
         }
      }
      else
      {
         // ベア: upBand を切下げのみ
         if(upBand < g_curFlip || close[i-1] > g_curFlip)
            newFlip = upBand;
         if(newFlip > g_curFlip) newFlip = g_curFlip;
         if(close[i] > newFlip)
         {
            g_confirmCount++;
            if(g_confirmCount > confirmBars)
            {
               g_trendDir = 1;
               g_curFlip  = lowBand;
               g_confirmCount = 0;
            }
         }
         else
         {
            g_confirmCount = 0;
            g_curFlip = newFlip;
         }
      }

      //=== フリップライン描画 ===
      if(InpShowFlipLine)
      {
         g_flipLine[i]  = g_curFlip;
         g_flipColor[i] = (g_trendDir == 1) ? 0 : 1;
      }
      else
      {
         g_flipLine[i]  = EMPTY_VALUE;
         g_flipColor[i] = 0;
      }

      //=== スコアリボン (トレンド強度に応じた帯) ===
      if(InpShowScoreRibbon)
      {
         double thick = atrVal * 0.08;
         double center = (maxE + minE) * 0.5;
         g_scoreUp[i] = center + thick;
         g_scoreDn[i] = center - thick;
      }
      else
      {
         g_scoreUp[i] = EMPTY_VALUE;
         g_scoreDn[i] = EMPTY_VALUE;
      }

      //=== Paint Candles ===
      if(InpPaintCandles)
      {
         g_candleO[i] = open[i];
         g_candleH[i] = high[i];
         g_candleL[i] = low[i];
         g_candleC[i] = close[i];
         g_candleCol[i] = (g_trendDir == 1) ? 1 : (g_trendDir == -1) ? 2 : 0;
      }
      else
      {
         g_candleO[i] = EMPTY_VALUE;
         g_candleH[i] = EMPTY_VALUE;
         g_candleL[i] = EMPTY_VALUE;
         g_candleC[i] = EMPTY_VALUE;
         g_candleCol[i] = 0;
      }

      //=== 矢印初期化 ===
      g_longArr[i]      = EMPTY_VALUE;
      g_shortArr[i]     = EMPTY_VALUE;
      g_contLongArr[i]  = EMPTY_VALUE;
      g_contShortArr[i] = EMPTY_VALUE;

      if(!InpShowATRSignals) continue;

      //=== トレンド転換シグナル ===
      // prevDir (保存済み) と g_trendDir (更新後) を比較
      bool isLongFlip  = (g_trendDir == 1  && prevDir == -1);
      bool isShortFlip = (g_trendDir == -1 && prevDir == 1);

      // フィルター
      bool emaBiasOK = true;
      if(InpUse50EMABias)
      {
         if(g_trendDir == 1  && close[i] < ema50[i]) emaBiasOK = false;
         if(g_trendDir == -1 && close[i] > ema50[i]) emaBiasOK = false;
      }
      bool smaFiltOK = true;
      if(InpUse100SMAFilter)
      {
         if(g_trendDir == 1  && close[i] < sma100[i]) smaFiltOK = false;
         if(g_trendDir == -1 && close[i] > sma100[i]) smaFiltOK = false;
      }

      double arrowOff = atrVal * 0.35;

      if(isLongFlip && emaBiasOK && smaFiltOK)
      {
         g_longArr[i] = low[i] - arrowOff;
         g_lastFlipBar = i;
      }
      else if(isShortFlip && emaBiasOK && smaFiltOK)
      {
         g_shortArr[i] = high[i] + arrowOff;
         g_lastFlipBar = i;
      }

      //=== 継続シグナル (押し目/戻り) ===
      if(InpAllowContinuation && g_longArr[i] == EMPTY_VALUE && g_shortArr[i] == EMPTY_VALUE)
      {
         // 50EMA タッチ + 反発
         double touchTol = atrVal * 0.2;
         if(g_trendDir == 1
            && low[i] <= ema50[i] + touchTol
            && close[i] > ema50[i]
            && close[i] > open[i])
         {
            // 直近 5 本以内に既存矢印が無い
            bool recent = false;
            for(int j = MathMax(0, i-5); j < i; j++)
               if(g_longArr[j] != EMPTY_VALUE || g_contLongArr[j] != EMPTY_VALUE)
               { recent = true; break; }
            if(!recent)
               g_contLongArr[i] = low[i] - atrVal * 0.2;
         }
         else if(g_trendDir == -1
            && high[i] >= ema50[i] - touchTol
            && close[i] < ema50[i]
            && close[i] < open[i])
         {
            bool recent = false;
            for(int j = MathMax(0, i-5); j < i; j++)
               if(g_shortArr[j] != EMPTY_VALUE || g_contShortArr[j] != EMPTY_VALUE)
               { recent = true; break; }
            if(!recent)
               g_contShortArr[i] = high[i] + atrVal * 0.2;
         }
      }
   }

   //=== ピボット & セッション オブジェクト更新 ===
   UpdatePivotLevels();
   UpdateSessionShade(time, high, low, rates_total);
   UpdateMorningMarker(time, high, low, rates_total);

   return(rates_total);
}

//+------------------------------------------------------------------+
//| OnTimer - ピボット更新                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdatePivotLevels();
}

//+------------------------------------------------------------------+
//| UpdatePivotLevels - クラシカルピボット計算 + 日本語ラベル表示       |
//+------------------------------------------------------------------+
void UpdatePivotLevels()
{
   if(!InpShowPivotLevels)
   {
      // 既存オブジェクト削除
      ObjectsDeleteAll(0, g_prefix + "PV_");
      return;
   }

   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today == g_lastPivotDate) return;  // 日付変化無し

   double prevH = iHigh(_Symbol, PERIOD_D1, 1);
   double prevL = iLow(_Symbol, PERIOD_D1, 1);
   double prevC = iClose(_Symbol, PERIOD_D1, 1);
   if(prevH <= 0 || prevL <= 0 || prevC <= 0) return;

   double range = prevH - prevL;
   double pp   = (prevH + prevL + prevC) / 3.0;
   double r1   = 2*pp - prevL;
   double s1   = 2*pp - prevH;
   double r2   = pp + range;
   double s2   = pp - range;
   double r3   = prevH + 2*(pp - prevL);
   double s3   = prevL - 2*(prevH - pp);
   double r05  = (pp + r1) / 2.0;
   double s05  = (pp + s1) / 2.0;
   double r15  = (r1 + r2) / 2.0;
   double r25  = (r2 + r3) / 2.0;
   double s25  = (s2 + s3) / 2.0;
   double pdM  = (prevH + prevL) / 2.0;
   double vu   = r3 + range * 0.3;
   double vd   = s3 - range * 0.3;

   // 配列に詰め直し (価格降順)
   g_pivotCount = 0;
   AddPivot("上限変動",   vu,    C'255,140,80',  STYLE_SOLID, 1);
   AddPivot("上極ゾーン", r25,   C'200,200,80',  STYLE_DASH,  1);
   AddPivot("コール壁",   r2,    C'255,80,80',   STYLE_SOLID, 2);
   AddPivot("上抵抗帯",   r05,   C'100,200,140', STYLE_SOLID, 1);
   AddPivot("基準軸",     pp,    C'255,220,80',  STYLE_SOLID, 2);
   AddPivot("前日高値",   prevH, C'180,180,200', STYLE_DOT,   1);
   AddPivot("前日中値",   pdM,   C'150,150,170', STYLE_DOT,   1);
   AddPivot("前日安値",   prevL, C'180,180,200', STYLE_DOT,   1);
   AddPivot("上方需要線", r15,   C'200,200,80',  STYLE_DASH,  1);
   AddPivot("ガンマ軸",   r1,    C'80,220,120',  STYLE_SOLID, 2);
   AddPivot("下抵抗帯",   s05,   C'200,200,80',  STYLE_SOLID, 1);
   AddPivot("プット壁",   s2,    C'255,80,80',   STYLE_SOLID, 2);
   AddPivot("下極ゾーン", s25,   C'200,200,80',  STYLE_DASH,  1);
   AddPivot("下限変動",   vd,    C'255,140,80',  STYLE_SOLID, 1);

   // 既存ライン削除
   ObjectsDeleteAll(0, g_prefix + "PV_");

   // 新規描画
   for(int i = 0; i < g_pivotCount; i++)
      DrawPivotLine(g_pivots[i], i);

   g_lastPivotDate = today;
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| AddPivot                                                           |
//+------------------------------------------------------------------+
void AddPivot(string name, double price, color clr, ENUM_LINE_STYLE st, int w)
{
   if(g_pivotCount >= 14) return;
   g_pivots[g_pivotCount].nameJP = name;
   g_pivots[g_pivotCount].price  = price;
   g_pivots[g_pivotCount].clr    = clr;
   g_pivots[g_pivotCount].style  = st;
   g_pivots[g_pivotCount].width  = w;
   g_pivotCount++;
}

//+------------------------------------------------------------------+
//| DrawPivotLine - 横線 + 右端ラベル                                   |
//+------------------------------------------------------------------+
void DrawPivotLine(PivotLevel &pv, int idx)
{
   string lineName = g_prefix + "PV_LINE_" + IntegerToString(idx);
   string lblName  = g_prefix + "PV_LBL_"  + IntegerToString(idx);

   if(ObjectFind(0, lineName) < 0)
      ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, pv.price);
   ObjectSetDouble (0, lineName, OBJPROP_PRICE, pv.price);
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, pv.clr);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, pv.style);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, pv.width);
   ObjectSetInteger(0, lineName, OBJPROP_BACK,  true);
   ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, true);

   if(InpShowPivotLabels)
   {
      // 最新バーから未来方向に InpLabelShift 本ぶん投影
      datetime curTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(curTime > 0)
      {
         datetime lblTime = curTime + (datetime)(PeriodSeconds() * InpLabelShift);

         string lblText = pv.nameJP + " " + DoubleToString(pv.price, _Digits);
         if(ObjectFind(0, lblName) < 0)
            ObjectCreate(0, lblName, OBJ_TEXT, 0, lblTime, pv.price);
         ObjectSetInteger(0, lblName, OBJPROP_TIME,  lblTime);
         ObjectSetDouble (0, lblName, OBJPROP_PRICE, pv.price);
         ObjectSetString (0, lblName, OBJPROP_TEXT,  lblText);
         ObjectSetInteger(0, lblName, OBJPROP_COLOR, pv.clr);
         ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, (int)InpLabelSize);
         ObjectSetString (0, lblName, OBJPROP_FONT, "MS Gothic");
         ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_LEFT);
         ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lblName, OBJPROP_BACK, false);
         ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
      }
   }
   else
   {
      ObjectDelete(0, lblName);
   }
}

//+------------------------------------------------------------------+
//| UpdateSessionShade - RTH セッション背景                              |
//+------------------------------------------------------------------+
void UpdateSessionShade(const datetime &time[], const double &high[],
                         const double &low[], int rates_total)
{
   if(!InpShowATRShading)
   {
      ObjectsDeleteAll(0, g_prefix + "SHADE_");
      return;
   }

   // 直近 3 日分のセッション帯を描画
   for(int dayOffset = 0; dayOffset < 3; dayOffset++)
   {
      datetime dayStart = iTime(_Symbol, PERIOD_D1, dayOffset);
      if(dayStart <= 0) continue;

      // セッション開始/終了 (NY → サーバー時刻換算)
      MqlDateTime dt;
      TimeToStruct(dayStart, dt);
      dt.hour = InpSessionOpenHour + InpNYServerOffset;
      dt.min  = InpSessionOpenMinute;
      dt.sec  = 0;
      datetime sStart = StructToTime(dt);

      dt.hour = InpSessionCloseHour + InpNYServerOffset;
      dt.min  = InpSessionCloseMinute;
      datetime sEnd = StructToTime(dt);

      double hi = -DBL_MAX, lo = DBL_MAX;
      for(int b = 0; b < rates_total; b++)
      {
         if(time[b] >= sStart && time[b] <= sEnd)
         {
            if(high[b] > hi) hi = high[b];
            if(low[b]  < lo) lo = low[b];
         }
      }
      if(hi == -DBL_MAX || lo == DBL_MAX) continue;

      string n = g_prefix + "SHADE_" + IntegerToString(dayOffset);
      if(ObjectFind(0, n) < 0)
         ObjectCreate(0, n, OBJ_RECTANGLE, 0, sStart, hi, sEnd, lo);
      ObjectSetInteger(0, n, OBJPROP_TIME,  0, sStart);
      ObjectSetDouble (0, n, OBJPROP_PRICE, 0, hi);
      ObjectSetInteger(0, n, OBJPROP_TIME,  1, sEnd);
      ObjectSetDouble (0, n, OBJPROP_PRICE, 1, lo);
      ObjectSetInteger(0, n, OBJPROP_COLOR, C'60,80,120');
      ObjectSetInteger(0, n, OBJPROP_FILL,  true);
      ObjectSetInteger(0, n, OBJPROP_BACK,  true);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| UpdateMorningMarker - 朝のチェックポイント (NY 10:30) マーカー       |
//+------------------------------------------------------------------+
void UpdateMorningMarker(const datetime &time[], const double &high[],
                          const double &low[], int rates_total)
{
   // 直近 5 日分の 10:30 バーをマーク
   for(int dayOffset = 0; dayOffset < 5; dayOffset++)
   {
      datetime dayStart = iTime(_Symbol, PERIOD_D1, dayOffset);
      if(dayStart <= 0) continue;
      MqlDateTime dt;
      TimeToStruct(dayStart, dt);
      dt.hour = InpMorningHour + InpNYServerOffset;
      dt.min  = InpMorningMinute;
      dt.sec  = 0;
      datetime target = StructToTime(dt);

      // 該当バーを探索
      int barIdx = -1;
      for(int b = rates_total - 1; b >= 0; b--)
      {
         if(time[b] <= target)
         { barIdx = b; break; }
      }
      if(barIdx < 0) continue;

      string n = g_prefix + "MORN_" + IntegerToString(dayOffset);
      if(ObjectFind(0, n) < 0)
         ObjectCreate(0, n, OBJ_ARROW, 0, time[barIdx], high[barIdx]);
      ObjectSetInteger(0, n, OBJPROP_TIME,  time[barIdx]);
      ObjectSetDouble (0, n, OBJPROP_PRICE, high[barIdx]);
      ObjectSetInteger(0, n, OBJPROP_ARROWCODE, 159);  // ◆
      ObjectSetInteger(0, n, OBJPROP_COLOR, C'255,220,80');
      ObjectSetInteger(0, n, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, n, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
