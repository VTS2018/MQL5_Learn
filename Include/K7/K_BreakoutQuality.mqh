//+------------------------------------------------------------------+
//| K_BreakoutQuality.mqh                                           |
//| 缺陷 1/2/6：突破质量旁路评估模块                                 |
//|                                                                  |
//| 设计原则：                                                       |
//| 1. 不修改原有 SignalQuality、EvaluateSignal 和确认函数。         |
//| 2. 不改变原有 grade、Buffer、报警和 K8Bot 执行逻辑。              |
//| 3. 默认只计算并返回质量指标，不打印调试日志。                     |
//| 4. 需要使用时，在原 EvaluateSignal() 之后单独调用本模块。          |
//+------------------------------------------------------------------+

#ifndef __K_BREAKOUT_QUALITY_MQH__
#define __K_BREAKOUT_QUALITY_MQH__

//#region MARK: 模块--突破质量数据结构

struct BreakoutQualityMetrics
{
   // 评估结果是否有效；ATR 或价格数据不可用时为 false。
   // 示例：valid=true 表示本次质量数据可以参与统计。
   bool valid;

   // 收盘价是否有效突破 P1；看涨为 Close(P1突破K线)>P1，看跌相反。
   // 示例：看涨收盘价高于 P1 0.0008 时，is_p1_break=true。
   bool is_p1_break;

   // 收盘价是否有效突破 P2/CB；看涨为 Close(确认K线)>P2，看跌相反。
   // 示例：看跌收盘价低于 P2 0.0012 时，is_cb_break=true。
   bool is_cb_break;

   // 从结构锚点到 P1 首次突破之间的 K 线数量，对应 N_Geo。
   // 示例：structure_bars=3 表示经过 3 根 K 线后突破 P1。
   int structure_bars;

   // P1 突破质量
   // P1首次突破K线收盘价越过 P1 的绝对价格距离，单位为价格。
   // 示例：P1=1.1000、突破收盘=1.1008 时，p1_break_distance=0.0008。
   double p1_break_distance;
   // P1突破距离除以 P1突破K线 ATR，表示突破达到多少个 ATR。
   // 示例：距离=0.0008、ATR=0.0010 时，p1_break_strength=0.80。
   double p1_break_strength;
   // P1突破质量，按 P1突破强度归一化到 0.0 到 1.0。
   // 示例：p1_break_strength=0.80 时，p1_quality=0.80。
   double p1_quality;

   // P2/CB 突破质量
   // 最终确认K线收盘价越过 P2 的绝对价格距离，单位为价格。
   // 示例：P2=1.1050、确认收盘=1.1062 时，cb_break_distance=0.0012。
   double cb_break_distance;
   // CB突破距离除以最终确认K线 ATR，表示突破达到多少个 ATR。
   // 示例：距离=0.0012、ATR=0.0010 时，cb_break_strength=1.20。
   double cb_break_strength;
   // CB突破质量，按 CB 突破强度归一化到 0.0 到 1.0。
   // 示例：cb_break_strength=1.20 时，cb_quality=1.00（封顶）。
   double cb_quality;

   // 突破 K 线形态质量
   // 最终确认K线的最高价与最低价之差，单位为价格。
   // 示例：最高价=1.1070、最低价=1.1040 时，candle_range=0.0030。
   double candle_range;
   // 最终确认K线开盘价与收盘价的绝对差值，单位为价格。
   // 示例：开盘=1.1045、收盘=1.1065 时，candle_body=0.0020。
   double candle_body;
   // K线实体占整根K线范围的比例，通常为 0.0 到 1.0。
   // 示例：实体=0.0020、范围=0.0030 时，candle_body_ratio=0.667。
   double candle_body_ratio;
   // 收盘价位于突破方向一侧的相对位置，范围为 0.0 到 1.0。
   // 示例：看涨K线收盘接近最高价时，candle_close_location 接近 1.0。
   double candle_close_location;
   // 由实体比例、收盘位置和方向一致性合成的 K 线质量，范围为 0.0 到 1.0。
   // 示例：大实体且收盘靠近方向极值时，candle_quality 接近 1.0。
   double candle_quality;

   // 当前只用于旁路观察，不映射回原 grade
   // P1质量、CB质量和K线质量的加权总分，范围为 0.0 到 1.0。
   // 示例：p1=0.80、cb=1.00、candle=0.90 时，total_quality=0.905。
   double total_quality;
};

//#endregion

//#region MARK: 模块--通用计算函数

double ClampBreakoutQuality(double value)
{
   if (value < 0.0)
      return 0.0;

   if (value > 1.0)
      return 1.0;

   return value;
}

double GetBreakoutATR(
   string sym,
   int period,
   int breakout_idx
)
{
   double atr = iATR(sym, period, 14, breakout_idx);

   if (atr <= 0.0)
      return 0.0;

   return atr;
}

//#endregion

//#region MARK: 模块--突破K线形态质量

// 评估突破 K 线的实体、收盘位置和方向一致性。
// 返回值范围：0.0 到 1.0。
double CalculateCandleQuality(
   string sym,
   int period,
   int breakout_idx,
   bool is_bullish
)
{
   double open_price = iOpen(sym, period, breakout_idx);
   double high_price = iHigh(sym, period, breakout_idx);
   double low_price = iLow(sym, period, breakout_idx);
   double close_price = iClose(sym, period, breakout_idx);

   double candle_range = high_price - low_price;

   if (candle_range <= 0.0)
      return 0.0;

   double body_ratio =
      MathAbs(close_price - open_price) / candle_range;

   double close_location;

   if (is_bullish)
      close_location = (close_price - low_price) / candle_range;
   else
      close_location = (high_price - close_price) / candle_range;

   close_location = ClampBreakoutQuality(close_location);

   bool direction_match;

   if (is_bullish)
      direction_match = (close_price >= open_price);
   else
      direction_match = (close_price <= open_price);

   double direction_quality = direction_match ? 1.0 : 0.0;

   double candle_quality =
      ClampBreakoutQuality(body_ratio) * 0.40
      + close_location * 0.40
      + direction_quality * 0.20;

   return ClampBreakoutQuality(candle_quality);
}

//#endregion

//#region MARK: 模块--P1和CB突破质量

// 计算实体收盘价越过关键位的 ATR 标准化质量。
double CalculateBreakDistanceQuality(
   double break_distance,
   double atr
)
{
   if (break_distance <= 0.0 || atr <= 0.0)
      return 0.0;

   // 以 1 ATR 突破距离作为满分参考。
   return ClampBreakoutQuality(break_distance / atr);
}

//#endregion

//#region MARK: 模块--统一旁路评估入口

//
// 调用示例：
//
// SignalQuality sq = EvaluateSignal(...);
// BreakoutQualityMetrics quality = EvaluateBreakoutQuality(
//    Symbol(), Period(), p1_breakout_idx, breakout_idx,
//    P1_price, P2_price, N_Geo, true
// );
//
// 该调用不会修改 sq，也不会改变原业务结果。
//
BreakoutQualityMetrics EvaluateBreakoutQuality(
   string sym,
   int period,
   int p1_breakout_idx,
   int breakout_idx,
   double p1,
   double p2,
   int n_geo,
   bool is_bullish
)
{
   BreakoutQualityMetrics metrics;

   metrics.valid = false;
   metrics.is_p1_break = false;
   metrics.is_cb_break = false;
   metrics.structure_bars = n_geo;

   metrics.p1_break_distance = 0.0;
   metrics.p1_break_strength = 0.0;
   metrics.p1_quality = 0.0;

   metrics.cb_break_distance = 0.0;
   metrics.cb_break_strength = 0.0;
   metrics.cb_quality = 0.0;

   metrics.candle_range = 0.0;
   metrics.candle_body = 0.0;
   metrics.candle_body_ratio = 0.0;
   metrics.candle_close_location = 0.0;
   metrics.candle_quality = 0.0;
   metrics.total_quality = 0.0;

   double p1_atr = GetBreakoutATR(
      sym,
      period,
      p1_breakout_idx
   );

   double breakout_atr = GetBreakoutATR(
      sym,
      period,
      breakout_idx
   );

   if (p1_atr <= 0.0 || breakout_atr <= 0.0)
      return metrics;

   double open_price = iOpen(sym, period, breakout_idx);
   double high_price = iHigh(sym, period, breakout_idx);
   double low_price = iLow(sym, period, breakout_idx);
   double close_price = iClose(sym, period, breakout_idx);

   metrics.candle_range = high_price - low_price;
   metrics.candle_body = MathAbs(close_price - open_price);

   if (metrics.candle_range > 0.0)
   {
      metrics.candle_body_ratio =
         metrics.candle_body / metrics.candle_range;

      if (is_bullish)
      {
         metrics.candle_close_location =
            (close_price - low_price) / metrics.candle_range;
      }
      else
      {
         metrics.candle_close_location =
            (high_price - close_price) / metrics.candle_range;
      }

      metrics.candle_close_location =
         ClampBreakoutQuality(metrics.candle_close_location);
   }

   metrics.candle_quality = CalculateCandleQuality(
      sym,
      period,
      breakout_idx,
      is_bullish
   );

   double p1_breakout_close = iClose(
      sym,
      period,
      p1_breakout_idx
   );

   double p1_distance;
   double cb_distance;

   if (is_bullish)
   {
      p1_distance = p1_breakout_close - p1;
      cb_distance = close_price - p2;
   }
   else
   {
      p1_distance = p1 - p1_breakout_close;
      cb_distance = p2 - close_price;
   }

   metrics.is_p1_break = (p1_distance > 0.0);
   metrics.is_cb_break = (cb_distance > 0.0);

   metrics.p1_break_distance = MathMax(0.0, p1_distance);
   metrics.cb_break_distance = MathMax(0.0, cb_distance);

   metrics.p1_break_strength =
      metrics.p1_break_distance / p1_atr;

   metrics.cb_break_strength =
      metrics.cb_break_distance / breakout_atr;

   metrics.p1_quality = CalculateBreakDistanceQuality(
      metrics.p1_break_distance,
      p1_atr
   );

   metrics.cb_quality = CalculateBreakDistanceQuality(
      metrics.cb_break_distance,
      breakout_atr
   );

   // 三项质量仅作为旁路观察数据，不改变原有 grade。
   metrics.total_quality =
        metrics.p1_quality * 0.30
      + metrics.cb_quality * 0.35
      + metrics.candle_quality * 0.35;

   metrics.total_quality =
      ClampBreakoutQuality(metrics.total_quality);

   metrics.valid = true;

   return metrics;
}

//#endregion

//#region MARK: 模块--可选观察输出

// 默认不打印，避免改变正式运行日志。
// 需要研究时，可在已有 Test_Print_Detail 条件内部手动调用。
void PrintBreakoutQuality(
   string type,
   BreakoutQualityMetrics &metrics
)
{
   Print(
      "BreakoutQuality type=", type,
      " P1=", DoubleToString(metrics.p1_quality, 3),
      " CB=", DoubleToString(metrics.cb_quality, 3),
      " Candle=", DoubleToString(metrics.candle_quality, 3),
      " Total=", DoubleToString(metrics.total_quality, 3),
      " P1Distance=", DoubleToString(metrics.p1_break_distance, Digits),
      " CBDistance=", DoubleToString(metrics.cb_break_distance, Digits)
   );
}

//#endregion

#endif // __K_BREAKOUT_QUALITY_MQH__
