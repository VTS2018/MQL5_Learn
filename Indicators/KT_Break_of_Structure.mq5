//+------------------------------------------------------------------+
//|                                                          BOS.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property indicator_chart_window    // 在主图表窗口显示
#property indicator_plots 0          // 不使用绘图缓冲区（使用对象绘制）

// from https://www.mql5.com/en/articles/15017
// 原始文件 Break_of_Structure_jBoSc_EA.mq5
// Modified: Added historical BOS detection on initialization

// 输入参数
input int    InpLength = 20;          // 摆动点验证长度
input int    InpScanLimit = 20;       // 实时扫描位置
input int    InpHistoryBars = 1000;   // 历史回溯K线数
input bool   InpShowHistory = true;   // 显示历史BOS标记
input int    InpBreakScanLimit = 0;   // 突破扫描范围(0=扫描到最新K线)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 清理旧的图表对象（包括箭头、箭头线和文本）
   ObjectsDeleteAll(0, "BOS_", 0, OBJ_ARROW);
   ObjectsDeleteAll(0, "BOS_", 0, OBJ_TEXT);         // 清理摆动点文本对象
   ObjectsDeleteAll(0, "BREAK_", 0, OBJ_ARROWED_LINE);
   ObjectsDeleteAll(0, "BREAK_", 0, OBJ_TEXT);       // 清理突破线文本对象
   
   if(InpShowHistory)
   {
      Print("开始扫描历史BOS... 扫描范围: ", InpHistoryBars, " 根K线");
      ScanHistoricalBOS();
      Print("历史BOS扫描完成!");
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 扫描历史BOS                                                       |
//+------------------------------------------------------------------+
void ScanHistoricalBOS()
{
   int totalBars = iBars(_Symbol, _Period);
   int startBar = MathMin(InpHistoryBars, totalBars - InpLength - 1);
   
   // 计算历史扫描的终止位置：确保不与实时扫描位置重叠
   // 历史扫描应停止在 InpScanLimit + 1 之前，避免重复检测
   int endBar = MathMax(InpLength + 1, InpScanLimit + 1);
   
   // 从旧到新扫描（避免最近的K线数据不完整）
   for(int curr_bar = startBar; curr_bar >= endBar; curr_bar--)
   {
      bool isSwingHigh = true;
      bool isSwingLow = true;
      
      // 验证左右各length根K线
      for(int j = 1; j <= InpLength; j++)
      {
         int right_index = curr_bar - j;  // 左侧K线（更早）
         int left_index = curr_bar + j;   // 右侧K线（更近）
         
         // 摆动高点验证
         if((high(curr_bar) <= high(right_index)) || (high(curr_bar) < high(left_index)))
         {
            isSwingHigh = false;
         }
         
         // 摆动低点验证
         if((low(curr_bar) >= low(right_index)) || (low(curr_bar) > low(left_index)))
         {
            isSwingLow = false;
         }
      }
      
      // 记录摆动高点
      if(isSwingHigh)
      {
         string objName = "BOS_H_" + TimeToString(time(curr_bar), TIME_DATE|TIME_SECONDS);
         drawSwingPoint(objName, time(curr_bar), high(curr_bar), 77, clrBlue, -1);
         
         // 检测突破（向后扫描）
         CheckHistoricalBreak(curr_bar, high(curr_bar), true);
      }
      
      // 记录摆动低点
      if(isSwingLow)
      {
         string objName = "BOS_L_" + TimeToString(time(curr_bar), TIME_DATE|TIME_SECONDS);
         drawSwingPoint(objName, time(curr_bar), low(curr_bar), 77, clrRed, 1);
         
         // 检测突破（向后扫描）
         CheckHistoricalBreak(curr_bar, low(curr_bar), false);
      }
   }
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| 检测历史突破                                                      |
//+------------------------------------------------------------------+
void CheckHistoricalBreak(int swing_bar, double swing_price, bool isHigh)
{
   // 计算扫描终点：0=扫描到bar[1]（最新收盘K线），>0=限制扫描范围
   int endBar = (InpBreakScanLimit <= 0) ? 1 : MathMax(1, swing_bar - InpBreakScanLimit);
   
   // 从摆动点后一根K线扫描到最新收盘K线
   // for(int i = swing_bar - 1; i >= MathMax(0, swing_bar - 200); i--) //原始代码：向后扫描200根K线查找突破
   for(int i = swing_bar - 1; i >= endBar; i--)
   {
      if(isHigh)
      {
         // 向上突破检测
         if(close(i) > swing_price && low(i) < swing_price)
         {
            string objName = "BREAK_H_" + TimeToString(time(swing_bar), TIME_DATE|TIME_SECONDS);
            drawBreakLevel(objName, time(swing_bar), swing_price, 
                          time(i), swing_price, clrBlue, -1);
            break;  // 找到第一个突破即停止
         }
      }
      else
      {
         // 向下突破检测
         if(close(i) < swing_price && high(i) > swing_price)
         {
            string objName = "BREAK_L_" + TimeToString(time(swing_bar), TIME_DATE|TIME_SECONDS);
            drawBreakLevel(objName, time(swing_bar), swing_price, 
                          time(i), swing_price, clrRed, 1);
            break;  // 找到第一个突破即停止
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // 移除EA时清理所有对象，切换周期时不清理
   if(reason == REASON_REMOVE)
   {
      ObjectsDeleteAll(0, "BOS_", 0, OBJ_ARROW);
      ObjectsDeleteAll(0, "BOS_", 0, OBJ_TEXT);
      ObjectsDeleteAll(0, "BREAK_", 0, OBJ_ARROWED_LINE);
      ObjectsDeleteAll(0, "BREAK_", 0, OBJ_TEXT);
      Print("已清理所有BOS标记对象");
   }
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   // 检测新K线
   static int prev_bars = 0;
   int curr_bars = rates_total;
   
   if(prev_bars == curr_bars)
   {
      return(rates_total);  // 不是新K线，直接返回
   }
   prev_bars = curr_bars;
   
   // 实时摆动点检测变量
   static double swing_H = -1.0, swing_L = -1.0;
   static int swing_H_bar = -1, swing_L_bar = -1;
   int curr_bar = InpScanLimit;
   
   // 摆动点检测逻辑
   bool isSwingHigh = true, isSwingLow = true;
   
   for(int j = 1; j <= InpLength; j++)
   {
      int right_index = curr_bar - j;
      int left_index = curr_bar + j;
      
      if((iHigh(_Symbol, _Period, curr_bar) <= iHigh(_Symbol, _Period, right_index)) || 
         (iHigh(_Symbol, _Period, curr_bar) < iHigh(_Symbol, _Period, left_index)))
      {
         isSwingHigh = false;
      }
      if((iLow(_Symbol, _Period, curr_bar) >= iLow(_Symbol, _Period, right_index)) || 
         (iLow(_Symbol, _Period, curr_bar) > iLow(_Symbol, _Period, left_index)))
      {
         isSwingLow = false;
      }
   }
   
   // 摆动高点处理
   if(isSwingHigh)
   {
      swing_H = iHigh(_Symbol, _Period, curr_bar);
      swing_H_bar = curr_bar;
      string objName = "BOS_H_" + TimeToString(iTime(_Symbol, _Period, curr_bar), TIME_DATE|TIME_SECONDS);
      
      if(ObjectFind(0, objName) < 0)
      {
         Print("实时摆动高点 @ BAR ", curr_bar, " Price: ", swing_H);
         drawSwingPoint(objName, iTime(_Symbol, _Period, curr_bar), swing_H, 77, clrBlue, -1);
      }
   }
   
   // 摆动低点处理
   if(isSwingLow)
   {
      swing_L = iLow(_Symbol, _Period, curr_bar);
      swing_L_bar = curr_bar;
      string objName = "BOS_L_" + TimeToString(iTime(_Symbol, _Period, curr_bar), TIME_DATE|TIME_SECONDS);
      
      if(ObjectFind(0, objName) < 0)
      {
         Print("实时摆动低点 @ BAR ", curr_bar, " Price: ", swing_L);
         drawSwingPoint(objName, iTime(_Symbol, _Period, curr_bar), swing_L, 77, clrRed, 1);
      }
   }
   
   // 突破检测（使用close[1]而非实时价格）
   if(swing_H > 0 && iClose(_Symbol, _Period, 1) > swing_H)
   {
      Print("实时向上突破 @ ", TimeToString(iTime(_Symbol, _Period, 0)));
      string objName = "BREAK_H_" + TimeToString(iTime(_Symbol, _Period, swing_H_bar), TIME_DATE|TIME_SECONDS);
      drawBreakLevel(objName, iTime(_Symbol, _Period, swing_H_bar), swing_H, 
                    iTime(_Symbol, _Period, 1), swing_H, clrBlue, -1);
      swing_H = -1.0;
   }
   
   if(swing_L > 0 && iClose(_Symbol, _Period, 1) < swing_L)
   {
      Print("实时向下突破 @ ", TimeToString(iTime(_Symbol, _Period, 0)));
      string objName = "BREAK_L_" + TimeToString(iTime(_Symbol, _Period, swing_L_bar), TIME_DATE|TIME_SECONDS);
      drawBreakLevel(objName, iTime(_Symbol, _Period, swing_L_bar), swing_L, 
                    iTime(_Symbol, _Period, 1), swing_L, clrRed, 1);
      swing_L = -1.0;
   }
   
   return(rates_total);
}

/*
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   static bool isNewBar = false;
   int currBars = iBars(_Symbol, _Period);
   static int prevBars = currBars;
   
   if(prevBars == currBars)
   {
      isNewBar = false;
   }
   else if(prevBars != currBars)
   {
      isNewBar = true;
      prevBars = currBars;
   }
   
   static double swing_H = -1.0, swing_L = -1.0;
   static int swing_H_bar = -1, swing_L_bar = -1;
   int curr_bar = InpScanLimit;
   
   if(isNewBar)
   {
      bool isSwingHigh = true, isSwingLow = true;
      
      for(int j = 1; j <= InpLength; j++)
      {
         int right_index = curr_bar - j;
         int left_index = curr_bar + j;
         
         if((high(curr_bar) <= high(right_index)) || (high(curr_bar) < high(left_index)))
         {
            isSwingHigh = false;
         }
         if((low(curr_bar) >= low(right_index)) || (low(curr_bar) > low(left_index)))
         {
            isSwingLow = false;
         }
      }
      
      if(isSwingHigh)
      {
         swing_H = high(curr_bar);
         swing_H_bar = curr_bar;
         string objName = "BOS_H_" + TimeToString(time(curr_bar), TIME_DATE|TIME_SECONDS);
         
         // 检查是否已存在（避免历史扫描和实时扫描重复标记）
         if(ObjectFind(0, objName) < 0)
         {
            Print("实时摆动高点 @ BAR ", curr_bar, " Price: ", high(curr_bar));
            drawSwingPoint(objName, time(curr_bar), high(curr_bar), 77, clrBlue, -1);
         }
      }
      if(isSwingLow)
      {
         swing_L = low(curr_bar);
         swing_L_bar = curr_bar;
         string objName = "BOS_L_" + TimeToString(time(curr_bar), TIME_DATE|TIME_SECONDS);
         
         // 检查是否已存在（避免历史扫描和实时扫描重复标记）
         if(ObjectFind(0, objName) < 0)
         {
            Print("实时摆动低点 @ BAR ", curr_bar, " Price: ", low(curr_bar));
            drawSwingPoint(objName, time(curr_bar), low(curr_bar), 77, clrRed, 1);
         }
      }
   }
   
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   
   // 向上突破检测
   if(swing_H > 0 && Bid > swing_H && close(1) > swing_H)
   {
      Print("实时向上突破 @ ", TimeToString(time(0)));
      string objName = "BREAK_H_" + TimeToString(time(swing_H_bar), TIME_DATE|TIME_SECONDS);
      drawBreakLevel(objName, time(swing_H_bar), swing_H, 
                    time(0+1), swing_H, clrBlue, -1);
      swing_H = -1.0;
      return;
   }
   
   // 向下突破检测
   if(swing_L > 0 && Ask < swing_L && close(1) < swing_L)
   {
      Print("实时向下突破 @ ", TimeToString(time(0)));
      string objName = "BREAK_L_" + TimeToString(time(swing_L_bar), TIME_DATE|TIME_SECONDS);
      drawBreakLevel(objName, time(swing_L_bar), swing_L, 
                    time(0+1), swing_L, clrRed, 1);
      swing_L = -1.0;
      return;
   }
}
*/

//+------------------------------------------------------------------+
// 辅助函数
//+------------------------------------------------------------------+
double high(int index) { return iHigh(_Symbol, _Period, index); }
double low(int index) { return iLow(_Symbol, _Period, index); }
double close(int index) { return iClose(_Symbol, _Period, index); }
datetime time(int index) { return iTime(_Symbol, _Period, index); }

void drawSwingPoint(string objName, datetime time, double price, int arrCode,
                   color clr, int direction)
{
   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrCode);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
      if(direction > 0) ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);
      if(direction < 0) ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      
      string txt = " BoS";
      string objNameDescr = objName + txt;
      ObjectCreate(0, objNameDescr, OBJ_TEXT, 0, time, price);
      ObjectSetInteger(0, objNameDescr, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objNameDescr, OBJPROP_FONTSIZE, 10);
      if(direction > 0)
      {
         ObjectSetInteger(0, objNameDescr, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
         ObjectSetString(0, objNameDescr, OBJPROP_TEXT, " " + txt);
      }
      if(direction < 0)
      {
         ObjectSetInteger(0, objNameDescr, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
         ObjectSetString(0, objNameDescr, OBJPROP_TEXT, " " + txt);
      }
   }
}

void drawBreakLevel(string objName, datetime time1, double price1,
                   datetime time2, double price2, color clr, int direction)
{
   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_ARROWED_LINE, 0, time1, price1, time2, price2);
      ObjectSetInteger(0, objName, OBJPROP_TIME, 0, time1);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, 0, price1);
      ObjectSetInteger(0, objName, OBJPROP_TIME, 1, time2);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price2);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
      
      string txt = " Break   ";
      string objNameDescr = objName + txt;
      ObjectCreate(0, objNameDescr, OBJ_TEXT, 0, time2, price2);
      ObjectSetInteger(0, objNameDescr, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objNameDescr, OBJPROP_FONTSIZE, 10);
      if(direction > 0)
      {
         ObjectSetInteger(0, objNameDescr, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
         ObjectSetString(0, objNameDescr, OBJPROP_TEXT, " " + txt);
      }
      if(direction < 0)
      {
         ObjectSetInteger(0, objNameDescr, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
         ObjectSetString(0, objNameDescr, OBJPROP_TEXT, " " + txt);
      }
   }
}
//+------------------------------------------------------------------+