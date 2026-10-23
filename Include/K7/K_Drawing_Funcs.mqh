//+------------------------------------------------------------------+
//|                                              K_Drawing_Funcs.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 25.11.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//#region MARK: 模块--核心绘制函数
//========================================================================
// DrawTargetBottom: 绘图函数，用向上箭头标记 K-Target Bottom (无变化)
// BullishTargetBuffer[] 函数如果存储最低价格以后 本质上这两个函数就没用了
//========================================================================
void DrawTargetBottom(int target_index)
{
    if (Is_EA_Mode) return;
    // 将箭头标记在 K-Target 的最低价之下
    BullishTargetBuffer[target_index] = Low[target_index] - 10 * _Point;

    /*
    // 2.0 修复看跌阴线锚点丢失的 问题 需要将锚点标注代码 放在这里
    // --- DrawTargetBottom 的真正逻辑 其实转到了这里
    if (Is_EA_Mode)
    {
        // 目标： 在 {EA}模式下，停止在锚点 {i} 处写入 {SL}价格，仅保留人工模式下的绘图价格赋值。
        // 🚨 修正：移除 EA 模式下的 BullishTargetBuffer[i] 赋值 🚨
        // 即EA模式下 不需要对看涨锚点和看跌锚点进行 缓冲区写入，只保留人工模式下的写入
        // BullishTargetBuffer[i] = Low[AbsLowIndex];
    }
    else
    {
        BullishTargetBuffer[i] = Low[i] - 10 * _Point;
    }
    // --- 结束 DrawTargetBottom
    */
}

//========================================================================
// DrawTargetTop: 绘图函数，用向下箭头标记 K-Target Top (无变化)
//========================================================================
void DrawTargetTop(int target_index)
{
    if (Is_EA_Mode) return;
    // 将箭头标记在 K-Target 的最高价之上
    BearishTargetBuffer[target_index] = High[target_index] + 10 * _Point;
    
    /*
    // 2.0 修复
    // --- DrawTargetTop 的真正逻辑 其实转到了这里
    if (Is_EA_Mode)
    {
        // BearishTargetBuffer[i] = High[AbsHighIndex];
    }
    else
    {
        BearishTargetBuffer[i] = High[i] + 10 * _Point;
    }
    // --- 结束DrawTargetTop
    */
}

//========================================================================
// DrawBreakoutTrendLine: 绘制突破趋势线 (P1)
//========================================================================
/**
   绘制一条从 K-Target.Open (P1) 开始，价格水平延伸到突破 K 线 
   时间 + 2 根 K 线的时间上。
   明确设置 OBJPROP_RAY = false，确保它是一条线段。

 * 根据看涨锚点的索引 和 P1 突破K线的索引  绘制趋势线，这是本程序绘制的第一条趋势线 非常关键
 * 绘制一条从 K-Target.Open (P1) 开始，价格水平延伸到突破 K 线
 * 时间 + 2 根 K 线的时间上。
 * 明确设置 OBJPROP_RAY = false，确保它是一条线段。
 * 
 * @param target_index: 看涨锚点的索引
 * @param breakout_index: P1 突破K线的索引
 * @param is_bullish: 阳线或者阴线
 * @param P2_price: 顺带着 展示出P2的价格 便于直观的对比
 */
void DrawP1Baseline(int target_index, int breakout_index, bool is_bullish, double P2_price)
{
    if (Is_EA_Mode) return;
    // K_Geo_Index 这个值在函数调用之前 需要检查 如果是-1 就不执行了，通过这个值确定是 DB 还是IB
    int breakout_candle_count = target_index - breakout_index;

    // Anchor 1 (起点): K-Target 锚点的 Open 价格和时间 (P1)
    datetime time1 = Time[target_index];
    double price1 = Open[target_index]; 
    
    // --- Anchor 2 (终点) 计算 ---
    
    // 终点 K 线索引: 使用突破 K 线索引，并向右 (现价方向) 延伸 2 根 K 线
    int end_bar_index = breakout_index - 2; 
    
    // 边界检查：确保索引不小于 1 (1 是最新的已收盘 K 线)
    if (end_bar_index < 1) 
    {
        end_bar_index = 1; // 防止数组越界
    }
    
    datetime time2 = Time[end_bar_index]; // 使用推移后的时间
    double price2 = price1;                 // 价格与起点价格保持一致 (实现水平线效果)
    
    // [V1.22 NEW] 突破类型分类
    string classification = breakout_candle_count < DB_Threshold_Candles ? "IB" : "DB";
    
    // 生成唯一的对象名称 
    string time_id_str = GetBarTimeID(target_index);
    string name = g_object_prefix + "IBDB_Line_" + classification + (is_bullish ? "B_" : "S_") + time_id_str;
    string comment;
    
    // 检查对象是否已存在，如果存在则直接返回
    if (ObjectFind(0, name) != -1) return; 
    
    // 创建趋势线对象 (OBJ_TREND)
    if (!ObjectCreate(0, name, OBJ_TREND, 0, time1, price1))
    {
        Print("无法创建 P1 趋势线对象: ", name, ", 错误: ", GetLastError());
        return;
    }
    
    // 设置趋势线的第二个锚点 (终点)
    ObjectSetInteger(0, name, OBJPROP_TIME, 1, time2);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price2);
    
    // ** 明确设置它不是射线 **
    ObjectSetInteger(0, name, OBJPROP_RAY, false); 
    
    // 设置线条属性
    ObjectSetInteger(0, name, OBJPROP_COLOR, is_bullish ? clrLimeGreen : clrDarkViolet); 
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2); 
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID); // 实线 (P1)
    ObjectSetInteger(0, name, OBJPROP_BACK, true); // 背景 (线在 K 线后面)
    
    // [V1.22 UPD] 设置注释/描述，包含 IB/DB 分类和 P2 价格
    comment = classification + " P1 @" + DoubleToString(price1, Digits) + " (P2:" + DoubleToString(P2_price, Digits) + ")";
    ObjectSetString(0, name, OBJPROP_TEXT, comment);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, comment);
    
    // 将趋势线设置为不可选中
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    
    // === 【NEW】控制对象列表可见性 ===
    if (Hide_Auxiliary_In_List)
    {
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    }
}

/**
 * DrawSecondBaseline: 绘制第二基准价格线 (P2)
 * 用P2 K线的索引来解耦这个函数,P2 K线的开盘价, 突破P2的索引+2，终点是 P2 突破K的索引 但是这个突破值是一个动态值
 * @param target_index: Argument 1
 * @param breakout_index: Argument 2
 * @param is_bullish: Argument 3
 */
void DrawP2Baseline(int target_index, int breakout_index, bool is_bullish)
{
    if (Is_EA_Mode) return;
    if (target_index == -1)
    {
        return;
    }

    double P2_price= Close[target_index];
    // 如果 P2 价格无效 (未找到)，则不绘制
    if (P2_price <= 0.0) return;
    
    // Anchor 1 (起点): P2 价格，K-Target 锚点时间
    datetime time1 = Time[target_index];
    
    // Anchor 2 (终点): P2 价格，延伸到突破 K 线 + 2
    int end_bar_index = breakout_index - 2; 
    if (end_bar_index < 1) end_bar_index = 1;
    datetime time2 = Time[end_bar_index];
    
    string time_id_str = GetBarTimeID(target_index);
    string name = g_object_prefix + "IBDB_P2_Line_" + (is_bullish ? "B_" : "S_") + time_id_str;
    string comment;

    // 检查对象是否已存在
    if (ObjectFind(0, name) != -1) return; 
    
    // 创建趋势线对象 (OBJ_TREND)
    if (!ObjectCreate(0, name, OBJ_TREND, 0, time1, P2_price))
    {
        Print("无法创建 P2 趋势线对象: ", name, ", 错误: ", GetLastError());
        return;
    }
    
    // 设置趋势线的第二个锚点 (终点)
    ObjectSetInteger(0, name, OBJPROP_TIME, 1, time2);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 1, P2_price);
    
    // ** 明确设置它不是射线 **
    ObjectSetInteger(0, name, OBJPROP_RAY, false); 
    
    // 设置线条属性: 虚线，较细，不同颜色
    ObjectSetInteger(0, name, OBJPROP_COLOR, is_bullish ? clrDarkBlue : clrDarkRed); // 深色作为P2
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1); 
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT); // 点线/虚线
    ObjectSetInteger(0, name, OBJPROP_BACK, true); // 背景
    
    comment = "P2 Baseline" + " (P2:" + DoubleToString(P2_price, Digits) + ")";
    ObjectSetString(0, name, OBJPROP_TEXT, comment);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, comment);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    
    // === 【NEW】控制对象列表可见性 ===
    if (Hide_Auxiliary_In_List)
    {
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    }
}

//========================================================================
// DrawPnBaseline: 绘制任意级别的价格线（P3/P4/P5 通用）[V2.0 NEW - Simplified]
//========================================================================
/**
 * 绘制多层价格线（P3、P4、P5 通用绘图函数）
 * 特点：使用不同颜色和线型区分不同级别
 * 
 * @param start_index 价格线起点索引（Pn 所在 K 线）
 * @param end_index 价格线终点索引（通常是锚点）
 * @param level 级别编号（3=P3, 4=P4, 5=P5）
 * @param price 价格
 * @param is_bullish 方向
 */
void DrawPnBaseline(int start_index, int end_index, int level, double price, bool is_bullish)
{
    if (Is_EA_Mode) return;
    if (start_index == -1 || price <= 0.0) return;
    
    // 根据级别选择样式
    color line_color;
    int line_style;
    int line_width;
    
    switch(level)
    {
        case 3:  // P3 - 橙色虚线
            line_color = is_bullish ? clrOrange : clrDarkOrange;
            line_style = STYLE_DASH;
            line_width = 1;
            break;
        case 4:  // P4 - 黄色点划线
            line_color = is_bullish ? clrYellow : clrGold;
            line_style = STYLE_DASHDOT;
            line_width = 1;
            break;
        case 5:  // P5 - 绿色细实线
            line_color = is_bullish ? clrLime : clrGreen;
            // 原P5样式：双点划线、较粗
            // line_style = STYLE_DASHDOTDOT;
            // line_width = 2;
            line_style = STYLE_SOLID;
            line_width = 1;
            break;
        default:
            line_color = clrGray;
            line_style = STYLE_DOT;
            line_width = 1;
    }
    
    // 创建趋势线对象
    string time_id = GetBarTimeID(start_index);
    string name = g_object_prefix + "P" + IntegerToString(level) + "_Line_" + 
                  (is_bullish ? "B_" : "S_") + time_id;
    
    // 检查对象是否已存在
    if (ObjectFind(0, name) != -1) return;
    
    datetime time1 = Time[start_index];
    datetime time2 = Time[end_index];
    
    if (!ObjectCreate(0, name, OBJ_TREND, 0, time1, price))
    {
        Print("无法创建 P", level, " 线: ", name, ", 错误: ", GetLastError());
        return;
    }
    
    // 设置趋势线的第二个锚点（终点）
    ObjectSetInteger(0, name, OBJPROP_TIME, 1, time2);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price);
    
    // 明确设置它不是射线
    ObjectSetInteger(0, name, OBJPROP_RAY, false);
    
    // 设置线条属性
    ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
    ObjectSetInteger(0, name, OBJPROP_STYLE, line_style);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, line_width);
    ObjectSetInteger(0, name, OBJPROP_BACK, true); // 背景层
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    
    string comment = "P" + IntegerToString(level) + " Level (" + DoubleToString(price, Digits) + ")";
    ObjectSetString(0, name, OBJPROP_TEXT, comment);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, comment);
    
    // 控制对象列表可见性
    if (Hide_Auxiliary_In_List)
    {
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    }
}

//========================================================================
// DrawAbsoluteSupportLine: 绘制绝对支撑/阻力水平线 (V1.35 NEW)
//========================================================================
/**
 * 在绝对低点/高点上绘制一条水平趋势线，并带文字说明。
 * @param abs_index: 具有绝对低/高价的 K 线索引。
 * @param is_bullish: 看涨 (支撑线) 还是看跌 (阻力线)。
 * @param extend_bars: 向右延伸的 K 线数量 (例如 15)。
 */
void DrawAbsoluteSupportLine(int abs_index, bool is_bullish, int extend_bars)
{
    if (Is_EA_Mode) return;
    if (abs_index < 0) return;

    // 确定线条的锚点价格
    double price = is_bullish ? Low[abs_index] : High[abs_index];
    //Print("===>[KTarget_Finder4_FromGemini.mq4:1048]: price: ", price);

    // 确定线条的起点和终点时间
    datetime time1 = Time[abs_index]; // 起点时间：绝对极值 K 线的时间

    // 终点 K 线索引：从 abs_index 向右（较新 K 线）移动 extend_bars
    int end_bar_index = abs_index - extend_bars;
    if (end_bar_index < 0)
        end_bar_index = 0; // 边界检查

    datetime time2 = Time[end_bar_index]; // 终点时间

    // --- 对象创建与设置 ---
    string time_id_str = GetBarTimeID(abs_index);
    string name = g_object_prefix + (is_bullish ? "AbsLow_" : "AbsHigh_") + time_id_str;

    // 检查对象是否已存在
    if (ObjectFind(0, name) != -1)
        return;

    // 创建趋势线对象 (OBJ_TREND)
    if (!ObjectCreate(0, name, OBJ_TREND, 0, time1, price, time2, price))
    {
        Print("无法创建 绝对最低价对象: ", name, ", 错误: ", GetLastError());
        return;
    }

    // 设置属性
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1); // 最细样式 (宽度 1)
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_BACK, true); // 背景
    ObjectSetInteger(0, name, OBJPROP_RAY, false); // 确保是线段

    // 设置文字说明 (可见文本)
    string comment = is_bullish ? "Absolute Low Support" : "Absolute High Resistance";
    ObjectSetString(0, name, OBJPROP_TEXT, comment);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, comment);

    // **确保文字可见性**：将文字附加在趋势线的一端，并调整其位置。
    // 在 MQL4 中，OBJ_TREND 的 OBJPROP_TEXT 默认是可见的，我们只需要确保它没有被其他东西遮挡。

    // 3. 更新位置
    ObjectSetInteger(0, name, OBJPROP_TIME, 0, time1);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
    ObjectSetInteger(0, name, OBJPROP_TIME, 1, time2);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    
    // === 【NEW】控制对象列表可见性 ===
    if (Hide_Auxiliary_In_List)
    {
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    }
}

//========================================================================
// DrawP1P2Rectangle: 绘制 P1 K线低价到 P2 K线收盘价的矩形区域 (V1.33 NEW)
// 修正绘制 看涨K-target 绝对最低价K的最低点  到 突破P1 K线 或者P2 K线满足 CB 信号的矩形
//========================================================================
/**
 * 绘制从 P1 K线的低/高价 到 P2 K线的收盘价 的矩形区域。
 *
 * @param target_index: P1 K线索引 (K-Target 锚点)
 * @param P2_index: P2 K线索引 (反转 K 线)
 * @param is_bullish: 看涨或者看跌
 */
void DrawP1P2Rectangle(int target_index, int P2_index, bool is_bullish)
{
    if (Is_EA_Mode) return;
    // --- 确保 P1/P2 索引有效 ---
    if (target_index < 0 || P2_index < 0) return;

    // --- 确定矩形的四个角点 ---
    
    // 角点 A (K-Target 锚点侧)
    datetime time1 = Time[target_index];
    double price1;
    
    // 角点 B (P2 侧)
    datetime time2 = Time[P2_index];
    double price2 = Close[P2_index]; // P2 侧的价格锚定 P2 K 线的收盘价
    
    // 🚨 修复：检测并处理 time1 == time2 的情况（强制设置最小宽度）
    if (target_index == P2_index || time1 == time2)
    {
        // Print(" 警告: P1和P2时间相同! target_index=", target_index,
        //       ", P2_index=", P2_index, ", time1=", TimeToString(time1),
        //       " | 应用最小宽度修正...");
        
        // 强制给矩形设置最小宽度（向左延伸 3 根 K线）
        int min_width_bars = 3;
        
        // 确保不超出数组边界
        int adjusted_index = P2_index + min_width_bars;
        if (adjusted_index >= Bars - 1)
            adjusted_index = Bars - 1;
        
        time2 = Time[adjusted_index];
        
        // Print("    修正后: time2 调整为 ", TimeToString(time2), 
        //       " (索引: ", adjusted_index, ")");
    }

    // 1. 根据看涨/看跌确定 P1 侧的价格锚定点
    if (is_bullish)
    {
        // 看涨: 价格锚定 K-Target 的最低价 (Low)
        price1 = Low[target_index];
    }
    else // is_bearish
    {
        // 看跌: 价格锚定 K-Target 的最高价 (High)
        price1 = High[target_index];
    }

    // --- 对象创建与设置 ---
    // 名称使用唯一的对象名前缀
    // string time_id_str = GetBarTimeID(target_index);
    // string name = g_object_prefix + (is_bullish ? "Rect_B_" : "Rect_S_") + time_id_str;

    //---------2.0 升级矩形对象的名称 用来为 斐波绘制提供信息传送
    // --- 获取 P1 和 P2 K线时间的格式化字符串 ---
    // 例如: "2025_11_24_06_00_00"
    string P1_time_id_str = GetBarTimeID(target_index);
    string P2_time_id_str = GetBarTimeID(P2_index);
    // 🚨 V3.00 核心修正：命名格式包含 P1 和 P2 时间，用 # 分隔
    // 格式: [Prefix]_[Type]_[P1_TimeID]#[P2_TimeID]
    string name = g_object_prefix +
                  (is_bullish ? "Rect_B_" : "Rect_S_") +
                  P1_time_id_str +
                  "#" +
                  P2_time_id_str;
    //---------2.0 升级矩形对象的名称 用来为 斐波绘制提供信息传送

    // 检查对象是否已存在
    if (ObjectFind(0, name) != -1) return;

    // 创建对象 (使用矩形对象 OBJ_RECTANGLE)
    // 矩形需要四个点: (时间1, 价格1) 和 (时间2, 价格2)
    if (!ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2))
    {
        Print("无法创建 P1/P2 矩形对象: ", name, ", 错误: ", GetLastError());
        return;
    }
    
    // 2. 设置属性 (更新)
    // 确保矩形在 K 线后面 (背景)
    ObjectSetInteger(0, name, OBJPROP_BACK, true); 
    
    // 设置颜色和透明度
    color rect_color = is_bullish ? clrLightBlue : clrLightPink; // 浅蓝色/浅粉色
    
    ObjectSetInteger(0, name, OBJPROP_COLOR, rect_color);
    
    // 设置为半透明 (0-255, 0为完全透明, 255为不透明)
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrNONE); // 移除边框
    ObjectSetInteger(0, name, OBJPROP_FILL, 1); // 开启填充
    //ObjectSetInteger(0, name, OBJPROP_LEVEL, 120); // 透明度设置 (例如 120)
    
    ObjectSetString(0, name, OBJPROP_TEXT, "P1/P2 Area");
    ObjectSetString(0, name, OBJPROP_TOOLTIP, "P1/P2 Area");
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false); // 不可选中
    
    // 3. 更新矩形位置 (用于 OnCalculate 循环更新)
    ObjectSetInteger(0, name, OBJPROP_TIME, 0, time1);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price1);
    ObjectSetInteger(0, name, OBJPROP_TIME, 1, time2);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price2);
    
    // === 【NEW】控制对象列表可见性 ===
    if (Hide_Auxiliary_In_List)
    {
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    }
}

//========================================================================
// DrawP1P2Fibonacci: 绘制 P1/P2 区域的斐波那契回调线 (V1.34 NEW)
//========================================================================
/**
 * 绘制 P1 K线的低/高价 到 P2 K线的收盘价 的斐波那契回调线。
 *
 * @param target_index: P1 K线索引 (K-Target 锚点)
 * @param P2_index: P2 K线索引 (反转 K 线)
 * @param is_bullish: 看涨或者看跌
 */
void DrawP1P2Fibonacci(int target_index, int P2_index, bool is_bullish)
{
    if (Is_EA_Mode) return;
    if (!Is_DrawFibonacciLines) return;
    
    // --- V1.38 内部硬编码自定义设置 ---
    color FIBO_LINE_COLOR = clrBlack;

    // 自定义斐波那契级别的值 (例如，添加了 78.6%)
    double custom_values[] = {0.0, 1.0, 0.12, 0.214, 0.236, 0.382, 0.500, 0.618, 0.786, 0.880, 1.618, 1.786, 1.880, 2.618, 2.786, 2.880, 4.236, 4.786, 4.880, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14};
    int FIBO_CUSTOM_LEVELS_COUNT = ArraySize(custom_values);
    //Print("--->[KTarget_Finder4_FromGemini.mq4:1229]: FIBO_CUSTOM_LEVELS_COUNT: ", FIBO_CUSTOM_LEVELS_COUNT);

    // 自定义斐波那契级别的说明 (与上面的值一一对应)
    string custom_texts[] = {
        "Base %$",  // k=0 (0.0)
        "Setup %$", // k=1 (1.0)

        "0.12 %$", // k=2 (0.12)
        "0.214 %$", // k=3 (0.214)

        "0.236 Major %$", // k=4 (0.236)
        "0.382 Minor %$", // k=5 (0.382)
        "50 %$",          // k=6 (0.500)

        "0.618 PullBack %$", // k=7 (0.618)
        "0.786 PullBack %$", // k=8 (0.786)
        "0.880 PullBack %$", // k=9 (0.880)

        "TP1-1.618-%$",
        "1MAX-%$",
        "1MAX-%$",

        "TP2-2.618-%$",
        "2MAX-%$",
        "2MAX-%$",

        "TP3-4.236-%$",
        "3MAX-%$",
        "3MAX-%$",

        "1:1的位置-%$",
        "1:2的位置-%$",
        "1:3的位置-%$",
        "1:4的位置-%$",
        "1:5的位置-%$",
        "1:6的位置-%$",
        "1:7的位置-%$",
        "1:8的位置-%$",
        "1:9的位置-%$",
        "1:10的位置-%$",
        "1:11的位置-%$",
        "1:12的位置-%$",
        "1:13的位置-%$"};
    //int FIBO_CUSTOM_LEVELS_COUNT_TEXTS = ArraySize(custom_texts);
    //Print("-->[KTarget_Finder4_FromGemini.mq4:1272]: FIBO_CUSTOM_LEVELS_COUNT_TEXTS: ", FIBO_CUSTOM_LEVELS_COUNT_TEXTS);

    // --- 确保 P1/P2 索引有效 ---
    if (target_index < 0 || P2_index < 0) return;

    // --- 确定斐波那契的两个锚点 ---
    
    // 锚点 1 (Fib 0 位置 - P1 K-Target 锚点侧)
    datetime time1 = Time[target_index];
    double price1;
    
    // 锚点 2 (Fib 1 位置 - P2 K 线侧)
    datetime time2 = Time[P2_index];
    double price2 = Close[P2_index]; // P2 K 线的收盘价即为 Fib 1 的价格

    // 1. 根据看涨/看跌确定 P1 侧的价格 (Fib 0)
    if (is_bullish)
    {
        // 看涨: 价格锚定 K-Target 的最低价 (Low) 作为 0% (支撑)
        price1 = Low[target_index];
    }
    else // is_bearish
    {
        // 看跌: 价格锚定 K-Target 的最高价 (High) 作为 0% (阻力)
        price1 = High[target_index];
    }

    // --- 对象创建与设置 ---
    // 名称使用唯一的对象名前缀
    string time_id_str = GetBarTimeID(target_index);
    string name = g_object_prefix + (is_bullish ? "Fibo_B_" : "Fibo_S_") + time_id_str;
    //Print(">>> DrawP1P2Fibonacci: Drawing Fibo ", name);

    // 检查对象是否已存在
    if (ObjectFind(0, name) != -1) return;

    // 创建对象 (使用斐波那契回调线 OBJ_FIBO)
    if (!ObjectCreate(0, name, OBJ_FIBO, 0, time2, price2, time1, price1))
    {
        Print("无法创建 P1/P2 使用斐波那契回调线: ", name, ", 错误: ", GetLastError());
        return;
    }
    
    // 2. 设置属性 (更新)

    // 确保斐波那契线在 K 线后面 (背景)
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_RAY, false);
    // 不向未来延伸
    // ObjectSetInteger(0, name, OBJPROP_FIBO_EXTEND, false);
    // 确保斐波那契线不可选中
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);

    // 设置线条颜色和宽度
    color fibo_color = is_bullish ? clrGreen : clrMagenta;
    ObjectSetInteger(0, name, OBJPROP_COLOR, fibo_color);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    
    // 3. 更新位置
    ObjectSetInteger(0, name, OBJPROP_TIME, 0, time2);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price2);
    ObjectSetInteger(0, name, OBJPROP_TIME, 1, time1);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price1);
    
    string time_p = GetTimeframeName(_Period);
    ObjectSetString(0, name, OBJPROP_TEXT, "P1/P2 Fibo " + time_p + (is_bullish ? " 多 " : " 空 "));
    ObjectSetString(0, name, OBJPROP_TOOLTIP, "P1/P2 Fibo " + time_p + (is_bullish ? " 多 " : " 空 "));

    // 🚨 V1.48 关键修正: 显式设置斐波那契级别总数
    ObjectSetInteger(0, name, OBJPROP_LEVELS, FIBO_CUSTOM_LEVELS_COUNT);
    //Print(">>> DrawP1P2Fibonacci: Setting All 32 Levels for Fibo ", name);

    // 4. V1.38 核心：设置自定义斐波那契级别、文本和颜色

    // MT4 最多支持 32 个斐波那契级别 (索引 0 到 31)
    for (int k = 0; k < 32; k++)
    {
        // (1) 设置自定义级别 步骤 A: 设置我们定义的 32 个级别 (k=0 到 k=6)
        // if (k < FIBO_CUSTOM_LEVELS_COUNT)
        // {
            // 设置值 (百分比)
            ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, k, custom_values[k]);
            // 设置说明文本
            ObjectSetString(0, name, OBJPROP_LEVELTEXT, k, custom_texts[k]);
            
            // 🚨 强制设置级别颜色为硬编码的颜色 (解决了颜色被覆盖的问题)
            ObjectSetInteger(0, name, OBJPROP_LEVELCOLOR, k, FIBO_LINE_COLOR);
            
            // 确保级别线条样式和宽度与主线一致
            ObjectSetInteger(0, name, OBJPROP_LEVELSTYLE, k, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_LEVELWIDTH, k, 1);
        // }
        // // (2) 隐藏所有未使用的级别
        // else
        // {
        //     // 设置值为 0.0 或一个空文本可有效隐藏级别
        //     ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, k, 0.0);
        //     ObjectSetString(0, name, OBJPROP_LEVELTEXT, k, "");
        // }
    }

    // Print("--->[K_Drawing_Funcs.mqh:497]: _Period: ", _Period);
    // 1. 获取当前周期的正确位标志 (例如：传入 43200，返回 256)
    int current_tf_flag = GetTimeframeFlag(_Period);
    // Print("--->[K_Drawing_Funcs.mqh:498]: current_tf_flag: ", current_tf_flag);
    
    if (current_tf_flag != 0)
    {
        // 🚨 最终修正：使用转换后的正确的位标志 🚨
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, current_tf_flag);
    }
    
    // === 【NEW】控制对象列表可见性 ===
    if (Hide_Auxiliary_In_List)
    {
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    }
}


/**
 * 清理旧有的信号绘制的矩形对象
 * @param target_index: Argument 1
 * @param is_bullish: Argument 2
 */
/*
void ClearSignalRectangle(int target_index, bool is_bullish)
{
    // 构建可能存在的旧矩形名称
    string name_prefix = g_object_prefix + "Rect_" + (is_bullish ? "B_" : "S_");
    
    // 查找并删除唯一匹配该锚点时间戳的对象
    string target_name = name_prefix + GetBarTimeID(target_index);
    
    // 假设 ObjectDelete 函数已在 MQL4 环境中可用 (通常是 ObjectDelete(0, name))
    if (ObjectFind(0, target_name) != -1)
    {
        ObjectDelete(0, target_name);
        Print("DEBUG: Cleared old signal rectangle for target index: ", target_name);
    }
}
*/

/**
 * 清理旧有的信号绘制的矩形对象
 * @param target_index: 锚点K线的索引，不是锚点的索引 而是最低价和最高价K线的索引 这个函数先放到这里以后再解决
 * @param is_bullish: 是否为看涨信号 (true=看涨, false=看跌)
 */
/*
void ClearSignalRectangle_v2(int target_index, bool is_bullish)
{
    // 1. 构建要查找的矩形名称的唯一标识 (即 '#' 符号之前的所有部分)
    string name_prefix = g_object_prefix + "Rect_" + (is_bullish ? "B_" : "S_");
    
    // target_unique_id 示例：KT5_..._Rect_B_2025_11_26_04_31_00
    // 这是您保证唯一的、不带 '#' 的部分。
    string target_unique_id = name_prefix + GetBarTimeID(target_index); 
    
    // 2. 遍历图表对象并查找名称中包含该唯一标识的对象
    int total_objects = ObjectsTotal();
    string obj_name;

    for (int i = total_objects - 1; i >= 0; i--)
    {
        // 🚨 使用 MQL4 的 ObjectName(index) 获取名称 🚨
        obj_name = ObjectName(i);

        // 检查对象名称是否包含我们构建的 target_unique_id
        // 如果 StringFind 返回非 -1 的值，说明找到了包含该唯一标识的对象
        if (StringFind(obj_name, target_unique_id) != -1) 
        {
            // 找到了，执行删除。这个 obj_name 必然是完整的名称，例如 KT5_...#2025_...
            // ObjectDelete(0, obj_name);
            Print("--->DEBUG: Cleared signal rectangle 559: ", obj_name);
            
            // 找到即可退出，因为每个锚点只应有一个矩形需要清除
            // return;
        }
    }
}
*/

void DrawFiboHighlightRectangles(int target_index, int P2_index, bool is_bullish)
{
    // 根据信号类型，将对应的全局数组传递给核心函数
    // MQL4 会自动处理引用传递，没有复杂的语法
    
    if (is_bullish)
    {
        ExecuteDrawFiboRects(target_index, P2_index, is_bullish, BULLISH_HIGHLIGHT_ZONES);
    }
    else
    {
        ExecuteDrawFiboRects(target_index, P2_index, is_bullish, BEARISH_HIGHLIGHT_ZONES);
    }
}

/**
 * 绘制斐波那契扩展区域的高亮矩形
 * @param target_index: P1 (锚点K线) 索引
 * @param P2_index: P2 K线索引
 * @param is_bullish: 是否为看涨斐波那契
 */
void ExecuteDrawFiboRects(int target_index, int P2_index, bool is_bullish, const FiboZone &zones[])
{
    if (Is_EA_Mode) return;
    // 获取 P1 和 P2 的价格和时间
    double P1_price; // 假设 P1 价格是锚点的 Open

    // 1. 根据看涨/看跌确定 P1 侧的价格锚定点
    if (is_bullish)
    {
        // 看涨: 价格锚定 K-Target 的最低价 (Low)
        P1_price = Low[target_index];
    }
    else // is_bearish
    {
        // 看跌: 价格锚定 K-Target 的最高价 (High)
        P1_price = High[target_index];
    }

    double P2_price = Close[P2_index]; // 假设 P2 价格是 P2 K线的 Close

    // 确定矩形在时间上的跨度 (从 P1 锚点开始，到当前最新 K线)
    datetime time1 = Time[target_index];

    // 矩形应一直延伸到最新 K线
    datetime time2 = Time[0];

    //--------------------------------------------
    // 先调试价格
    // Print("-->[K_Drawing_Funcs.mqh:600]: P1_price: ", P1_price);
    // Print("-->[K_Drawing_Funcs.mqh:601]: P2_price: ", P2_price);
    // Print("-->[K_Drawing_Funcs.mqh:602]: time1: ", time1);
    // Print("-->[K_Drawing_Funcs.mqh:603]: time2: ", time2);
    //return; 价格全部对应得上 测试通过
    //--------------------------------------------

    // 确定要遍历的区域数组
    //const FiboZone& zones[] = is_bullish ? BULLISH_HIGHLIGHT_ZONES : BEARISH_HIGHLIGHT_ZONES;
    int zones_count = ArraySize(zones);
    
    // 确定颜色
    color rect_color = GetHighlightColorByPeriod(is_bullish);

    //-----
    // 1. 获取周期名称 (例如 "H4", "D1")
    string tf_name = GetTimeframeName(_Period);

    // 2. 确定区域类型描述
    string area_type = is_bullish ? "看涨斐波反转-做空-区域" : "看跌斐波反转-做多-区域";

    // 3. 组合最终的说明文本
    // 示例: "H4 看跌斐波反转区域"
    string description_text = tf_name + " " + area_type;
    //-----

    // 获取周期可见性标志
    // int tf_flag = GetTimeframeFlag(_Period);
    // Print("--->[K_Drawing_Funcs.mqh:643]: tf_flag: ", tf_flag);


    // 遍历所有高亮区域并绘制矩形
    for (int i = 0; i < zones_count; i++)
    {
        double level1 = zones[i].level1;
        double level2 = zones[i].level2;
        
        // 1. 计算价格坐标
        double price_start = CalculateFiboPrice(P1_price, P2_price, level1);
        // Print("===>[K_Drawing_Funcs.mqh:622]: price_start: ", price_start," level1: ",level1);

        double price_end   = CalculateFiboPrice(P1_price, P2_price, level2);
        // Print("===>[K_Drawing_Funcs.mqh:624]: price_end: ", price_end," level2: ",level2);


        // 🚨 修正2.0：确定文本的锚点 🚨
        // 时间锚点：使用 time2 (Time[0])，即矩形的右侧，实现右侧定位
        datetime time_anchor = Time[0];

        // 价格锚点：根据方向确定是矩形的高点还是低点
        double text_anchor_price;
        if (is_bullish)
        {
            // 看涨斐波 (文本在右下角): 锚定价格为矩形价格的较低点
            text_anchor_price = MathMin(price_start, price_end);
        }
        else
        {
            // 看跌斐波 (文本在右上角): 锚定价格为矩形价格的较高点
            text_anchor_price = MathMax(price_start, price_end);
        }

        // 1.0 注销
        // 矩形的顶部价格 (作为文本锚定点)
        // double price_top = price_end;

        // 2. 命名对象，使用特殊标记 "_FiboHL_" 满足周期切换不删除需求
        string name = g_object_prefix + "Rect_FiboHL_" + (is_bullish ? "B_" : "S_") + GetBarTimeID(target_index) + "#" + DoubleToString(level1, 3) + "_" + DoubleToString(level2, 3);
        // Print("===>[K_Drawing_Funcs.mqh:624]: name: ", name);

        string text_name = name + "_TXT";

        /*
        // 3. 创建/更新矩形
        if (ObjectFind(0, name) != -1)
        {
            ObjectDelete(0, name); // 如果已存在，先删除，再重新绘制
        }
        
        if (ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price_start, time2, price_end))
        {
            // 设置属性
            ObjectSetInteger(0, name, OBJPROP_COLOR, rect_color);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            
            // 🚨 设置填充和背景 (FILL and BACK)
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true); // 矩形在 K 线后面
            
            // 🚨 设置透明度 (MQL4/MT4 颜色函数)
            ObjectSetInteger(0, name, OBJPROP_COLOR, (int)rect_color | (HIGHLIGHT_ALPHA << 24)); // ARGB格式
            
            // 将对象设置为不可选中
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            
            // ** 关键设置：仅在当前周期可见 **
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, GetTimeframeFlag(_Period)); 
        }
        */

        if (ObjectFind(0, name) != -1) ObjectDelete(0, name);
        if (ObjectFind(0, text_name) != -1) ObjectDelete(0, text_name); // 确保旧文本对象被删除

        if (ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price_start, time2, price_end))
        {
            ObjectSetInteger(0, name, OBJPROP_COLOR, (int)rect_color | (HIGHLIGHT_ALPHA << 24));
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

            // 设置周期可见性
            int tf_flag = GetTimeframeFlag(_Period);
            if (tf_flag != 0)
                ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, tf_flag);
            else
                ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

            // ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            // 🚨 核心修正：设置对象说明及鼠标悬停提示 🚨
            ObjectSetString(0, name, OBJPROP_TEXT, description_text);
            ObjectSetString(0, name, OBJPROP_TOOLTIP, description_text);

            string description_text_level = description_text + " " + DoubleToString(level1, 3);

            // 3. 🚨 调用新函数绘制图表文本 🚨 1.0
            // DrawFiboHighlightText(text_name, description_text_level, time1, price_top, tf_flag);

            // 3. 🚨 修正调用新函数绘制图表文本 🚨 2.0
            // 使用 time_anchor 和 text_anchor_price，并传入 is_bullish
            DrawFiboHighlightText(text_name, description_text_level, time_anchor, text_anchor_price, tf_flag, is_bullish);
        }
        else
        {
            Print("无法创建 高亮 矩形对象: ", name, ", 错误: ", GetLastError());
            return;
        }
    }
}

/**
 * 绘制斐波那契高亮区域的文本说明 (OBJ_TEXT)
 * @param text_name: 文本对象的唯一名称 (应包含父矩形名称)
 * @param text_content: 要显示的文本内容 (例如 "H4 看跌斐波反转区域")
 * @param anchor_time: 文本的锚定时间 (矩形左侧时间)
 * @param anchor_price: 文本的锚定价格 (矩形顶部价格)
 * @param tf_flag: 文本对象的周期可见性位标志
 */
void DrawFiboHighlightText(string text_name, string text_content, datetime anchor_time, double anchor_price, int tf_flag, bool is_bullish)
{
    if (Is_EA_Mode) return;
    // 确保旧文本对象被删除
    if (ObjectFind(0, text_name) != -1) ObjectDelete(0, text_name);

    // 创建 OBJ_TEXT 对象
    if (ObjectCreate(0, text_name, OBJ_TEXT, 0, anchor_time, anchor_price))
    {
        ObjectSetString(0, text_name, OBJPROP_TEXT, text_content);
        
        // 设置颜色：确保与高亮背景色形成强烈对比 (使用黑色)
        ObjectSetInteger(0, text_name, OBJPROP_COLOR, clrBlack); 
        
        // 设置字体和大小 (可根据需求调整)
        ObjectSetString(0, text_name, OBJPROP_FONT, "Arial"); 
        ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 8); 
        
        // 默认1.0的设置
        // 设置锚点：左上角
        // ObjectSetInteger(0, text_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        // ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);

        // 🚨 修正2.0：根据看涨/看跌设置文本锚点 🚨
        if (is_bullish)
        {
            // 看涨斐波 (文本在 右下角)
            // 时间/价格锚点: CORNER_LEFT_UPPER (不变)
            ObjectSetInteger(0, text_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            // 文本内部定位: 锚定在 文本自身的右下角
            ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
        }
        else
        {
            // 看跌斐波 (文本在 右上角)
            // 时间/价格锚点: CORNER_LEFT_UPPER (不变)
            ObjectSetInteger(0, text_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            // 文本内部定位: 锚定在 文本自身的右上角
            ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
        }
        
        // 关键优化：设置文本位置微调，稍微远离边角，以避免与边框重叠
        ObjectSetInteger(0, text_name, OBJPROP_XDISTANCE, 5); // 稍微右移 5 像素
        ObjectSetInteger(0, text_name, OBJPROP_YDISTANCE, 5); // 稍微下移 5 像素
        
        // 设置周期可见性
        if (tf_flag != 0) ObjectSetInteger(0, text_name, OBJPROP_TIMEFRAMES, tf_flag);
        else ObjectSetInteger(0, text_name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        
        // 确保文本对象不可选中
        ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, true);
        ObjectSetInteger(0, text_name, OBJPROP_HIDDEN, true);
    }
}

/*
// 绘制斐波那契矩形 (仅供 Grade A/S 使用)
void DrawFiboGradeZones(string sym, int idx, double sl, double close, bool bullish) {
   string name = "KT_Fib_" + IntegerToString(idx);
   double range = MathAbs(close - sl);
   datetime t1 = iTime(sym, 0, idx);
   datetime t2 = t1 + PeriodSeconds(0) * 30; // 延伸30根
   
   double level1, level2;
   if (bullish) {
      level1 = sl + range * 1.618;
      level2 = sl + range * 1.88;
   } else {
      level1 = sl - range * 1.618;
      level2 = sl - range * 1.88;
   }
   
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, level1, t2, level2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, (bullish ? clrLightGreen : clrLightPink));
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}
*/

//+------------------------------------------------------------------+
//| DrawFiboGradeZones (最终完整版)
//| ------------------------------------------------------------------
//| 改进点：
//| 1. 接收外部 prefix，统一对象管理
//| 2. 使用 iTime 时间戳替代 K线索引，防止对象随行情漂移
//| 3. 具备存在性检查 (ObjectFind)
//+------------------------------------------------------------------+
void DrawFiboGradeZones(string sym, int idx, double sl, double close, bool bullish, string prefix)
{
   if (Is_EA_Mode)
   {
      return;
   }
   
   // 1. 基础计算
   double range = MathAbs(close - sl);
   
   // [关键改进] 获取该 K 线的精确时间作为唯一身份 ID
   // 使用 long 类型转换确保时间戳数字的完整性
   datetime bar_time = iTime(sym, 0, idx);
   string time_str = IntegerToString((long)bar_time);

   // 计算矩形的时间宽度 (默认向右延伸 30 根 K 线)
   datetime t2 = bar_time + PeriodSeconds(0) * 30; 
   
   // 定义斐波那契倍数 (TP1, TP2, TP3)
   double fib_levels[] = {1.618, 1.88,  2.618, 2.88,  4.236, 4.88};
   color  zone_colors[] = {clrLightGreen, clrSkyBlue, clrGold};
   
   // 如果是做空，调整颜色
   if (!bullish) {
       zone_colors[0] = clrLightPink; 
       zone_colors[1] = clrLightCoral; 
       zone_colors[2] = clrOrangeRed; 
   }

   // 循环绘制 3 个目标区域
   for(int k=0; k<3; k++)
   {
       // --- A. 构建基于时间的唯一对象名 ---
       // 格式: [前缀]Fib_[时间戳]_TP[k]
       // 例如: KTarget_v3_A1_Fib_167889200_TP1
       string obj_name = prefix + "Fib_" + time_str + "_TP" + IntegerToString(k+1);
       
       // --- B. 存在性检查与创建 ---
       if(ObjectFind(0, obj_name) < 0) 
       {
           ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, 0, 0, 0, 0);
           // 静态属性仅设置一次
           ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);     // 脚本列表中隐藏
           ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);// 不可选中
           ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);       // 背景显示
           ObjectSetInteger(0, obj_name, OBJPROP_FILL, true);       // 开启填充
       }

       // --- C. 动态属性更新 (坐标/颜色) ---
       double level_start, level_end;
       if (bullish) {
           level_start = sl + range * fib_levels[k*2];
           level_end   = sl + range * fib_levels[k*2+1];
       } else {
           level_start = sl - range * fib_levels[k*2];
           level_end   = sl - range * fib_levels[k*2+1];
       }

       // 即使对象已存在，也更新坐标 (防止参数调整后位置不对)
    ObjectSetInteger(0, obj_name, OBJPROP_TIME, 0, bar_time);
    ObjectSetDouble (0, obj_name, OBJPROP_PRICE, 0, level_start);
    ObjectSetInteger(0, obj_name, OBJPROP_TIME, 1, t2);
    ObjectSetDouble (0, obj_name, OBJPROP_PRICE, 1, level_end);
       ObjectSetInteger(0, obj_name, OBJPROP_COLOR, zone_colors[k]);
   }
}

//========================================================================
// DrawSignalInfoText: 在信号矩形下方/上方绘制描述文本 (涨+CB+点数+止损金额)
//========================================================================
void DrawSignalInfoText(int target_index, int signal_index, string type_str, double sl_price, double confirm_price, bool is_bullish)
{
    if (Is_EA_Mode) return;

    // 1. 计算点数 (Points)
    // 涨: 收盘 - 止损; 跌: 止损 - 收盘
    double diff = is_bullish ? (confirm_price - sl_price) : (sl_price - confirm_price);
    double tick_size = MarketInfo(Symbol(), MODE_TICKSIZE);
    int points = (int)(diff / tick_size); 

    // 2. 计算标准手止损金额（美元）
    // 公式: 止损金额 = 点数 × 每点价值
    double tick_value = MarketInfo(Symbol(), MODE_TICKVALUE);  // 获取每点价值
    double loss_amount = points * tick_value;
    
    // 四舍五入到整数美元
    int loss_usd = (int)MathRound(loss_amount);

    // 3. 构建文本内容
    // 格式: 涨CB(150)-200$ 或 跌DB(80)-150$
    string dir_str = is_bullish ? "涨" : "跌";
    string text_content = dir_str + type_str + "(" + IntegerToString(points) + ")-" + IntegerToString(loss_usd) + "$";

    // 4. 构建对象名称 (必须唯一，关联到锚点)
    string time_id = GetBarTimeID(target_index); // 使用锚点时间作为唯一标识
    string name = g_object_prefix + "SigTxt_" + (is_bullish ? "B_" : "S_") + time_id;

    // 5. 确定绘制坐标
    datetime time = Time[signal_index]; // X轴：画在信号确认的那根K线上
    
    // Y轴：在止损价格线附近，但需要偏移避免与价格线重叠
    // 计算偏移量（约为字体高度的距离，使用 tick_size 的倍数）
    double price_offset = tick_size * 5; // 向外偏移5个tick，避免文本与价格线重叠
    double price;
    
    if (is_bullish)
    {
        // 看涨：矩形在上方，文字在下方 -> 价格向下偏移（减）
        price = sl_price - price_offset;
    }
    else
    {
        // 看跌：矩形在下方，文字在上方 -> 价格向上偏移（加）
        price = sl_price + price_offset;
    }

    // 6. 创建或更新对象
    if (ObjectFind(0, name) != -1) ObjectDelete(0, name);

    if (ObjectCreate(0, name, OBJ_TEXT, 0, time, price))
    {
        ObjectSetString(0, name, OBJPROP_TEXT, text_content);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9); // 字号
        ObjectSetString(0, name, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, name, OBJPROP_COLOR, is_bullish ? clrGreen : clrRed); // 涨绿跌红
        
        // 7. 设置锚点 (关键：让字刚好在矩形外面)
        if (is_bullish)
        {
            // 看涨矩形在上方，字画在底下 -> 文本的"Top"锚定在偏移后的价格，文本向下延伸
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_TOP); 
        }
        else
        {
            // 看跌矩形在下方，字画在顶上 -> 文本的"Top"锚定在偏移后的价格（已向上偏移），文本向下延伸
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_TOP);
        }

        // 设置周期可见性 (同矩形)
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, GetTimeframeFlag(_Period));
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        
        // ✅ 修复：设置为背景层，防止穿透EA面板
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
    }
}
//#endregion

//#region MARK: 模块--删除旧信号对应的整组对象 没有开发成功
//========================================================================
// CleanupInvalidSignalDrawings
// 只回收“已经被价格击穿止损”的信号对象，不影响仍然有效或已止盈完成的信号。
//
// 设计原理（与 Show_History_Fibo/Hide_Invalid_Fibo 完全解耦）：
// 1. 先扫描图表对象，只处理本指标前缀下的信号矩形 Rect_B_/Rect_S_。
// 2. 从矩形名称中解析出 P1(abs_lowindex/abs_highindex)/P2(信号确认K线) 时间戳，
//    再把时间映射回当前图表索引。
// 3. 用 IsSignalPriceInvalidated() 做纯客观判断：收盘价是否击穿真实止损
//    (Low[abs_lowindex] 看涨 / High[abs_highindex] 看跌)，与任何 UI 显示
//    偏好无关，止盈完成不算失效。
// 4. 如果确认已破位失效，则把该信号对应的“矩形 + 文字 + 辅助线 + 斐波高亮区”
//    一起删除；止盈完成的信号原样保留在图表上。
//
// 触发时机：
// - 指标完成一次历史全量重算后。
// - 指标收到新 K 线后重新扫描全图时。
//
// 独立开关 Enable_Auto_Cleanup_Invalid_Signals（默认开启）控制本功能整体
// 开/关，不再借用 Show_History_Fibo/Hide_Invalid_Fibo（那两个只管 Fibo
// 历史投影的显示偏好，默认关闭，之前误把清理逻辑也一起关掉了）。
//========================================================================
void CleanupInvalidSignalDrawings()
{
    if (!Enable_Auto_Cleanup_Invalid_Signals)
        return;

    int total_objects = ObjectsTotal(0, 0);

    for (int i = total_objects - 1; i >= 0; i--)
    {
        string obj_name = ObjectName(0, i);
        if (StringLen(obj_name) <= 0) continue;

        // 只处理本指标绘制的信号矩形；Fibo 高亮矩形、趋势线和 UI 对象全部跳过。
        bool is_bull_rect = (StringFind(obj_name, g_object_prefix + "Rect_B_", 0) != -1);
        bool is_bear_rect = (StringFind(obj_name, g_object_prefix + "Rect_S_", 0) != -1);
        if (!is_bull_rect && !is_bear_rect)
            continue;

        ParsedRectInfo info;
        if (!ParseRectangleName(obj_name, info))
            continue;

        string rect_prefix = g_object_prefix + (info.is_bullish ? "Rect_B_" : "Rect_S_");
        int start_pos = StringFind(obj_name, rect_prefix, 0);
        if (start_pos == -1)
            continue;

        start_pos += StringLen(rect_prefix);
        string time_segment = StringSubstr(obj_name, start_pos);
        int separator_pos = StringFind(time_segment, "#", 0);
        if (separator_pos == -1)
            continue;

        string p1_time_id = StringSubstr(time_segment, 0, separator_pos);

        // 将矩形中的时间戳映射回当前图表索引，确认这组信号在当前图表里还能不能被解释。
        int signal_index = iBarShift(NULL, 0, info.P2_time, false);
        int anchor_index = iBarShift(NULL, 0, info.P1_time, false);

        bool should_delete = false;
        string delete_reason = "";

        if (signal_index < 0 || anchor_index < 0)
        {
            should_delete = true;
            delete_reason = "无法映射到当前图表索引";
        }
        else
        {
            // 矩形名的 P1 槽位实际存的是 abs_lowindex/abs_highindex（见 DrawP1P2Rectangle
            // 调用处），真实止损用的是该K线的 Low(看涨)/High(看跌)，不是 Open。
            double sl_price = info.is_bullish ? Low[anchor_index] : High[anchor_index];
            if (IsSignalPriceInvalidated(signal_index, sl_price, info.is_bullish))
            {
                should_delete = true;
                delete_reason = "信号已被价格击穿止损";
            }
        }

        if (!should_delete)
            continue;

        string dir_tag = info.is_bullish ? "B_" : "S_";
        string text_name = g_object_prefix + "SigTxt_" + dir_tag + p1_time_id;
        string p1_line_name = g_object_prefix + "IBDB_Line_" + (info.is_bullish ? "B_" : "S_") + p1_time_id;
        string p2_line_name = g_object_prefix + "IBDB_P2_Line_" + (info.is_bullish ? "B_" : "S_") + p1_time_id;

        // 斐波高亮区也属于同一信号生命周期：一旦信号失效，必须一起回收。
        // DrawFiboGradeZones() 使用 [prefix]Fib_[时间戳]_TP1/TP2/TP3 命名，所以这里按同一
        // P1 时间戳把三个目标区全部删掉，避免出现“信号死了，但斐波区还挂着”的残留。
        string fib_prefix = g_object_prefix + "Fib_" + p1_time_id + "_TP";

        if (ObjectFind(0, obj_name) != -1)
            ObjectDelete(0, obj_name);
        if (ObjectFind(0, text_name) != -1)
            ObjectDelete(0, text_name);
        if (ObjectFind(0, p1_line_name) != -1)
            ObjectDelete(0, p1_line_name);
        if (ObjectFind(0, p2_line_name) != -1)
            ObjectDelete(0, p2_line_name);
        for (int fib_i = 1; fib_i <= 3; fib_i++)
        {
            string fib_name = fib_prefix + IntegerToString(fib_i);
            if (ObjectFind(0, fib_name) != -1)
                ObjectDelete(0, fib_name);
        }

        Print("[CleanupInvalidSignalDrawings] 已清理失效信号对象: ", obj_name,
              " | 原因: ", delete_reason,
              " | 触发时机: 新K线/历史重算后自动扫描",
              " | 已同步删除对应斐波高亮区");
    }
}

//========================================================================
// IsSignalReplacedByCloseInLookbackWindow
// 新版“替换判定”函数：只看后续窗口里是否出现更低/更高的收盘价新锚点。
//
// 规则：
// - 看涨：后续 Lookback_Bottom 根K线内，只要出现一个有效的新看涨锚点，且
//   该锚点的 Close 低于当前信号锚点 Close，就视为旧信号被替换。
// - 看跌：后续 Lookback_Top 根K线内，只要出现一个有效的新看跌锚点，且
//   该锚点的 Close 高于当前信号锚点 Close，就视为旧信号被替换。
//
// 注意：这里不做任何对象删除，只返回是否“应该被替换”。
//========================================================================
bool IsSignalReplacedByCloseInLookbackWindow(int anchor_index, int total_bars, bool is_bullish, int lookback_window)
{
    if (anchor_index < 1 || total_bars <= 0 || lookback_window < 1)
        return false;

    if (anchor_index >= total_bars)
        return false;

    double anchor_close = Close[anchor_index];
    int min_candidate_index = anchor_index - lookback_window;
    if (min_candidate_index < 1)
        min_candidate_index = 1;

    for (int candidate_index = anchor_index - 1; candidate_index >= min_candidate_index; candidate_index--)
    {
        if (is_bullish)
        {
            if (Close[candidate_index] < anchor_close && IsKTargetBottom(candidate_index, total_bars))
                return true;
        }
        else
        {
            if (Close[candidate_index] > anchor_close && IsKTargetTop(candidate_index, total_bars))
                return true;
        }
    }

    return false;
}

//========================================================================
// CleanupReplacedSignalDrawings_ByLookbackWindow
// 新版“结构替换清理”函数：当后续窗口里出现更低/更高 Close 的新锚点时，
// 删除旧信号对应的整组对象（矩形 + 文本 + P1/P2 线 + Fibo 高亮区）。
//
// 这个版本与 CleanupInvalidSignalDrawings 完全并行，便于对比两套策略。
// 它不依赖 Show_History_Fibo/Hide_Invalid_Fibo，也不依赖止损失效判定。
//========================================================================
void CleanupReplacedSignalDrawings_ByLookbackWindow()
{
    int total_objects = ObjectsTotal(0, 0);

    for (int i = total_objects - 1; i >= 0; i--)
    {
        string obj_name = ObjectName(0, i);
        if (StringLen(obj_name) <= 0)
            continue;

        bool is_bull_rect = (StringFind(obj_name, g_object_prefix + "Rect_B_", 0) != -1);
        bool is_bear_rect = (StringFind(obj_name, g_object_prefix + "Rect_S_", 0) != -1);
        if (!is_bull_rect && !is_bear_rect)
            continue;

        ParsedRectInfo info;
        if (!ParseRectangleName(obj_name, info))
            continue;

        int anchor_index = iBarShift(NULL, 0, info.P1_time, false);
        int signal_index = iBarShift(NULL, 0, info.P2_time, false);
        if (anchor_index < 0 || signal_index < 0)
            continue;

        int lookback_window = info.is_bullish ? Lookback_Bottom : Lookback_Top;
        if (!IsSignalReplacedByCloseInLookbackWindow(anchor_index, Bars, info.is_bullish, lookback_window))
            continue;

        string rect_prefix = g_object_prefix + (info.is_bullish ? "Rect_B_" : "Rect_S_");
        int start_pos = StringFind(obj_name, rect_prefix, 0);
        if (start_pos == -1)
            continue;

        start_pos += StringLen(rect_prefix);
        string time_segment = StringSubstr(obj_name, start_pos);
        int separator_pos = StringFind(time_segment, "#", 0);
        if (separator_pos == -1)
            continue;

        string p1_time_id = StringSubstr(time_segment, 0, separator_pos);
        string signal_time_id = GetBarTimeID(signal_index);
        string dir_tag = info.is_bullish ? "B_" : "S_";
        string text_name = g_object_prefix + "SigTxt_" + dir_tag + p1_time_id;
        string p1_line_name = g_object_prefix + "IBDB_Line_" + (info.is_bullish ? "B_" : "S_") + p1_time_id;
        string p2_line_name = g_object_prefix + "IBDB_P2_Line_" + (info.is_bullish ? "B_" : "S_") + p1_time_id;
        string fib_prefix = g_object_prefix + "Fib_" + signal_time_id + "_TP";

        if (ObjectFind(0, obj_name) != -1)
            ObjectDelete(0, obj_name);
        if (ObjectFind(0, text_name) != -1)
            ObjectDelete(0, text_name);
        if (ObjectFind(0, p1_line_name) != -1)
            ObjectDelete(0, p1_line_name);
        if (ObjectFind(0, p2_line_name) != -1)
            ObjectDelete(0, p2_line_name);

        for (int fib_i = 1; fib_i <= 3; fib_i++)
        {
            string fib_name = fib_prefix + IntegerToString(fib_i);
            if (ObjectFind(0, fib_name) != -1)
                ObjectDelete(0, fib_name);
        }

          Print("[CleanupReplacedSignalDrawings_ByLookbackWindow] 已清理被新锚点替换的信号对象: ", obj_name,
              " | anchor_index=", anchor_index,
              " | signal_index=", signal_index,
              " | lookback_window=", lookback_window,
              " | fib_time_id=", signal_time_id,
              " | 触发规则: 后续窗口出现更低/更高 Close 的有效新锚点");
    }
}
//#endregion

//#region MARK: 模块--会话显示模块
//+------------------------------------------------------------------+
//| ParseHourFromTimeString: 将 "HH:MM" 格式的时间字符串转换为小时数
//| ------------------------------------------------------------------
//| 例如: "09:00" -> 9, "13:30" -> 13
//+------------------------------------------------------------------+
int ParseHourFromTimeString(string time_str)
{
    // 查找冒号位置
    int colon_pos = StringFind(time_str, ":");
    
    if (colon_pos == -1)
    {
        // 如果没有找到冒号，尝试直接转换为整数
        return (int)StringToInteger(time_str);
    }
    
    // 提取小时部分（冒号之前的字符）
    string hour_str = StringSubstr(time_str, 0, colon_pos);
    
    // 转换为整数并返回
    return (int)StringToInteger(hour_str);
}

//+------------------------------------------------------------------+
//| 🌍 DrawMarketSessions: 绘制全球四大市场时段矩形
//| ------------------------------------------------------------------
//| 逻辑: 基于标准 GMT 时间定义时段，然后加上 Server_Offset 进行平移
//+------------------------------------------------------------------+
void DrawMarketSessions(int lookback_days, int gmt_offset)
{
   if (Is_EA_Mode) return;

   // --- 1. 从配置文件读取并转换时间 (原硬编码方式已废弃) ---
   // 原硬编码值（仅供参考）:
   // 东京: 00:00 - 09:00 GMT (亚盘核心)
   // 伦敦: 08:00 - 17:00 GMT (欧盘核心)
   // 纽约: 13:00 - 22:00 GMT (美盘核心)
   
   // 从配置文件读取时间并转换为整数小时
   int Sess_Tok_Start = ParseHourFromTimeString(Session1_Start);
   int Sess_Tok_End   = ParseHourFromTimeString(Session1_End);
   int Sess_Lon_Start = ParseHourFromTimeString(Session2_Start);
   int Sess_Lon_End   = ParseHourFromTimeString(Session2_End);
   int Sess_NY_Start  = ParseHourFromTimeString(Session3_Start);
   int Sess_NY_End    = ParseHourFromTimeString(Session3_End);

   // 获取当前服务器时间的日初 (00:00)
   datetime time_current = TimeCurrent();
   datetime day_start = iTime(Symbol(), PERIOD_D1, 0); 

   // 循环处理过去 N 天
   for(int i = 0; i <= lookback_days; i++)
   {
      // 计算当天的基准时间 (从今天往回推 i 天)
      datetime current_day_base = day_start - (i * PeriodSeconds(PERIOD_D1));
      
      // 绘制四大时段
      // DrawSingleSession(current_day_base, "Sydney",  Sess_Syd_Start, Sess_Syd_End, gmt_offset, Color_Sydney);
      DrawSingleSession(current_day_base, Session1_Name, Sess_Tok_Start, Sess_Tok_End, gmt_offset, Session1_Color);
      DrawSingleSession(current_day_base, Session2_Name, Sess_Lon_Start, Sess_Lon_End, gmt_offset, Session2_Color);
      DrawSingleSession(current_day_base, Session3_Name, Sess_NY_Start,  Sess_NY_End,  gmt_offset, Session3_Color);
   }
}

/*
// 辅助函数：绘制单个时段的矩形
void DrawSingleSession_V1(datetime day_base, string name, int start_h_gmt, int end_h_gmt, int offset, color bg_color)
{
   if(bg_color == clrNONE) return; // 如果颜色未设置，不绘制

   // 1. 计算服务器时间的开始小时
   int server_start_h = start_h_gmt + offset;
   int server_end_h   = end_h_gmt + offset;
   
   // 2. 处理跨日情况 (例如加了时区后超过24点，或者悉尼本身跨日)
   // 这里做一个简化的处理：计算具体的时间戳
   
   datetime t1 = day_base + server_start_h * 3600;
   datetime t2 = day_base + server_end_h * 3600;
   
   // 如果原始定义是跨日的 (比如 21:00 到 06:00)，手动修正 t2 到第二天
   if (start_h_gmt > end_h_gmt)
   {
       t2 += 24 * 3600;
   }

   // 3. 构建对象名称 (按天唯一)
   string day_str = TimeToString(day_base, TIME_DATE);
   string obj_name = g_object_prefix + "Sess_" + name + "_" + day_str;

   // 4. 获取该时间段内的最高价和最低价 (用于确定矩形高度)
   // 使用 iBarShift 找到对应的K线索引
   int idx_start = iBarShift(NULL, 0, t1);
   int idx_end   = iBarShift(NULL, 0, t2);
   
   if (idx_start == -1 || idx_end == -1) return; // 数据不存在
   
   // 查找范围内的高低点
   int highest_idx = iHighest(NULL, 0, MODE_HIGH, idx_start - idx_end + 1, idx_end);
   int lowest_idx  = iLowest(NULL, 0, MODE_LOW,  idx_start - idx_end + 1, idx_end);
   
   if (highest_idx == -1 || lowest_idx == -1) return;

   double high_price = High[highest_idx];
   double low_price  = Low[lowest_idx];
   
   // 稍微向外扩一点点，让图表不压抑
    double padding = 20 * _Point;

   // 5. 绘制矩形
   if(ObjectFind(0, obj_name) != -1) ObjectDelete(0, obj_name);
   
   ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, t1, high_price + padding, t2, low_price - padding);

   // ObjectSetInteger(0, obj_name, OBJPROP_COLOR, bg_color);
   // ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
   // ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
   // ObjectSetInteger(0, obj_name, OBJPROP_BACK, true); // 背景显示，不遮挡K线
   // ObjectSetInteger(0, obj_name, OBJPROP_FILL, true); // 开启填充
   // ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false); // 不可选中

   ObjectSetInteger(0, obj_name, OBJPROP_COLOR, bg_color);
   ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_DASH); // ✅ 修改为：虚线 (STYLE_DASH 或 STYLE_DOT)
   ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, obj_name, OBJPROP_BACK, true); 
   ObjectSetInteger(0, obj_name, OBJPROP_FILL, false); // ✅ 修改为：关闭填充 (透明背景，只显示框)
   ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);

   // 6. 添加文字标签 (可选，放在矩形左上角)
   string txt_name = obj_name + "_TXT";
   if(ObjectFind(0, txt_name) != -1) ObjectDelete(0, txt_name);
   
   ObjectCreate(0, txt_name, OBJ_TEXT, 0, t1, high_price + padding);
   ObjectSetString(0, txt_name, OBJPROP_TEXT, " " + name);
   ObjectSetInteger(0, txt_name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, txt_name, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, txt_name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, txt_name, OBJPROP_BACK, true);
}
*/

/*
// 辅助函数：绘制单个时段的虚线框 (强制无填充版)
void DrawSingleSession_V2(datetime day_base, string name, int start_h_gmt, int end_h_gmt, int offset, color border_color)
{
   if(border_color == clrNONE) return; // 如果颜色未设置，不绘制

   // 1. 计算服务器时间的开始小时
   int server_start_h = start_h_gmt + offset;
   int server_end_h   = end_h_gmt + offset;
   
   // 2. 处理跨日情况
   datetime t1 = day_base + server_start_h * 3600;
   datetime t2 = day_base + server_end_h * 3600;
   
   if (start_h_gmt > end_h_gmt)
   {
       t2 += 24 * 3600;
   }

   // 3. 构建对象名称 
   // ⚠️ 注意：我们在名称中加入了 "_Line" 后缀，强制创建一个新对象，
   // 这样可以避免旧的“有背景色”的矩形属性残留。
   string day_str = TimeToString(day_base, TIME_DATE);
   string obj_name = g_object_prefix + "Sess_" + name + "_" + day_str + "_Line";

   // 4. 获取高低点
   int idx_start = iBarShift(NULL, 0, t1);
   int idx_end   = iBarShift(NULL, 0, t2);
   
   if (idx_start == -1 || idx_end == -1) return;
   
   int highest_idx = iHighest(NULL, 0, MODE_HIGH, idx_start - idx_end + 1, idx_end);
   int lowest_idx  = iLowest(NULL, 0, MODE_LOW,  idx_start - idx_end + 1, idx_end);
   
   if (highest_idx == -1 || lowest_idx == -1) return;

   double high_price = High[highest_idx];
   double low_price  = Low[lowest_idx];
   double padding = 20 * _Point;

   // 5. 绘制矩形 (强制属性重设)
   if(ObjectFind(0, obj_name) != -1) ObjectDelete(0, obj_name);
   
   if(ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, t1, high_price + padding, t2, low_price - padding))
   {
       // --- 关键属性设置 ---
       ObjectSetInteger(0, obj_name, OBJPROP_COLOR, border_color);   // 设置边框颜色
       ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_DASH);     // 设置为虚线
       ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);              // ⚠️ 宽度必须为 1，否则虚线不显示
       
       ObjectSetInteger(0, obj_name, OBJPROP_FILL, false);           // ⚠️ 关键：强制关闭背景填充 (False=0)
       ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);            // 放在背景层 (不遮挡K线)
       ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);     // 不可选中
   }
   
   // 6. 添加文字标签 (保持不变)
   string txt_name = obj_name + "_TXT";
   if(ObjectFind(0, txt_name) != -1) ObjectDelete(0, txt_name);
   
   ObjectCreate(0, txt_name, OBJ_TEXT, 0, t1, high_price + padding);
   ObjectSetString(0, txt_name, OBJPROP_TEXT, " " + name);
   ObjectSetInteger(0, txt_name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, txt_name, OBJPROP_COLOR, border_color); // 文字颜色与边框一致
   ObjectSetInteger(0, txt_name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, txt_name, OBJPROP_BACK, true);
}
*/

//+------------------------------------------------------------------+
//| 辅助函数：绘制单个时段的虚线框 (客户验证修正版)
//| 修复方案: OBJPROP_FILL = false 且 OBJPROP_BACK = false
//+------------------------------------------------------------------+
void DrawSingleSession(datetime day_base, string name, int start_h_gmt, int end_h_gmt, int offset, color border_color)
{
   if(border_color == clrNONE) return; 

   // 1. 计算服务器时间
   int server_start_h = start_h_gmt + offset;
   int server_end_h   = end_h_gmt + offset;
   
   datetime t1 = day_base + server_start_h * 3600;
   datetime t2 = day_base + server_end_h * 3600;
   
   // 跨日处理
   if (start_h_gmt > end_h_gmt)
   {
       t2 += 24 * 3600;
   }

   // 2. 构建对象名称 (保留 _Line 后缀以防缓存冲突，或者改回原名也可以)
   string day_str = TimeToString(day_base, TIME_DATE);
   string obj_name = g_object_prefix + "Sess_" + name + "_" + day_str + "_Box"; 

   // 3. 获取高低点
   int idx_start = iBarShift(NULL, 0, t1);
   int idx_end   = iBarShift(NULL, 0, t2);
   
   if (idx_start == -1 || idx_end == -1) return;
   
   int highest_idx = iHighest(NULL, 0, MODE_HIGH, idx_start - idx_end + 1, idx_end);
   int lowest_idx  = iLowest(NULL, 0, MODE_LOW,  idx_start - idx_end + 1, idx_end);
   
   if (highest_idx == -1 || lowest_idx == -1) return;

   double high_price = High[highest_idx];
   double low_price  = Low[lowest_idx];
   double padding = 20 * _Point;

   // 4. 绘制矩形
   if(ObjectFind(0, obj_name) != -1) ObjectDelete(0, obj_name);
   
   if(ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, t1, high_price + padding, t2, low_price - padding))
   {
       // --- 核心样式设置 ---
       ObjectSetInteger(0, obj_name, OBJPROP_COLOR, border_color);   // 边框颜色
       ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_DASH);     // 虚线样式
       ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);              // 宽度必须为1才显示虚线
       
       // --- 您的关键修复 ---
       ObjectSetInteger(0, obj_name, OBJPROP_FILL, false);           // 必须为 false (无填充)
       ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);           // 必须为 false (前景显示，确保虚线清晰)
       
       ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);     // 不可选中
   }
   
   // 5. 添加文字标签 (可选)
   string txt_name = obj_name + "_TXT";
   if(ObjectFind(0, txt_name) != -1) ObjectDelete(0, txt_name);
   
   if(ObjectCreate(0, txt_name, OBJ_TEXT, 0, t1, high_price + padding))
   {
       ObjectSetString(0, txt_name, OBJPROP_TEXT, " " + name);
       ObjectSetInteger(0, txt_name, OBJPROP_FONTSIZE, 8);
       ObjectSetInteger(0, txt_name, OBJPROP_COLOR, border_color); 
       ObjectSetInteger(0, txt_name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
       // 文字可以设为 Back = true 以免遮挡 K 线，或者设为 false 保持清晰，看您喜好
       ObjectSetInteger(0, txt_name, OBJPROP_BACK, false); 
       ObjectSetInteger(0, txt_name, OBJPROP_SELECTABLE, false);
   }
}
//#endregion

//#region MARK: 模块--信息面板展示
//+------------------------------------------------------------------+
//| ATR 显示快照数据结构（用于函数间传递）                           |
//+------------------------------------------------------------------+
/*
struct AtrDisplaySnapshot
{
    string base_name;
    int atr_period;
    double atr_mult;
    double current_price;
    double atr_value;
    double sl_distance;
    double buy_sl_price;
    double sell_sl_price;
    double yesterday_close;
    double today_open;
    double today_high;
    double today_low;
    int spread;
    int range_points;
    int change_points;
    string change_str;
    int digits;
};
*/

//+------------------------------------------------------------------+
//| 采集 ATR 显示所需的数据快照（不节流）                            |
//+------------------------------------------------------------------+
bool CollectAtrDisplaySnapshot(AtrDisplaySnapshot &snap)
{
    if(Is_EA_Mode) return false;

    snap.base_name = g_object_prefix + "ATR_Dashboard";
    snap.atr_period = GetAdaptiveATRPeriod(_Period);
    snap.atr_mult = GetAdaptiveATRMultiplier(_Period);

    snap.current_price = Close[0];
    snap.atr_value = KT_GetATR(_Symbol, _Period, snap.atr_period, 0);

    // ATR 数据尚未就绪时保留上一轮图形，避免用零距离覆盖止损价格。
    if(snap.atr_value <= 0.0)
        return false;

    snap.sl_distance = snap.atr_value * snap.atr_mult;

    snap.buy_sl_price = snap.current_price - snap.sl_distance;
    snap.sell_sl_price = snap.current_price + snap.sl_distance;

    // [临时调试] 每秒记录一次 ATR 和买卖止损计算结果，定位 ATR 为 0 或价格相同的问题。
    // 暂时注销，保留代码供以后排查 ATR 问题时恢复。
    // static datetime last_atr_debug_time = 0;
    // datetime current_debug_time = TimeCurrent();
    // if(current_debug_time != last_atr_debug_time)
    // {
    //     last_atr_debug_time = current_debug_time;
    //     PrintFormat("[ATR DEBUG] symbol=%s period=%d atr_period=%d atr_mult=%.4f current=%.10f atr=%.10f distance=%.10f buy_sl=%.10f sell_sl=%.10f same=%s error=%d",
    //                 _Symbol,
    //                 (int)_Period,
    //                 snap.atr_period,
    //                 snap.atr_mult,
    //                 snap.current_price,
    //                 snap.atr_value,
    //                 snap.sl_distance,
    //                 snap.buy_sl_price,
    //                 snap.sell_sl_price,
    //                 (snap.buy_sl_price == snap.sell_sl_price) ? "true" : "false",
    //                 GetLastError());
    // }

    snap.yesterday_close = iClose(_Symbol, PERIOD_D1, 1);
    snap.today_open = iOpen(_Symbol, PERIOD_D1, 0);
    snap.today_high = iHigh(_Symbol, PERIOD_D1, 0);
    snap.today_low = iLow(_Symbol, PERIOD_D1, 0);

    snap.spread = (int)MarketInfo(_Symbol, MODE_SPREAD);
    double range_price = snap.today_high - snap.today_low;
    snap.range_points = (int)(range_price / _Point);

    double change_price = snap.current_price - snap.yesterday_close;
    snap.change_points = (int)(change_price / _Point);
    if(snap.change_points > 0)
        snap.change_str = "+" + IntegerToString(snap.change_points);
    else if(snap.change_points < 0)
        snap.change_str = IntegerToString(snap.change_points);
    else
        snap.change_str = "0";

    snap.digits = (int)MarketInfo(_Symbol, MODE_DIGITS);
    return true;
}

//+------------------------------------------------------------------+
//| 慢速刷新：12行 ATR 信息面板（1秒节流）                           |
//+------------------------------------------------------------------+
void UpdateAtrDashboardLines_Throttled(const AtrDisplaySnapshot &snap)
{
    if(Is_EA_Mode) return;

    static datetime last_update_time = 0;
    if(TimeCurrent() == last_update_time) return;
    last_update_time = TimeCurrent();

    string lines[];
    ArrayResize(lines, 12);

    lines[0] = StringFormat("ATR(%d): %s  |  Mult: %.1fx", snap.atr_period, DoubleToString(snap.atr_value, snap.digits), snap.atr_mult);
    lines[1] = StringFormat("SL Space: %d pts", (int)(snap.sl_distance / _Point));
    lines[2] = "------------------";
    lines[3] = StringFormat("Buy SL: %s", DoubleToString(snap.buy_sl_price, snap.digits));
    lines[4] = StringFormat("Sell SL: %s", DoubleToString(snap.sell_sl_price, snap.digits));
    lines[5] = "==================";
    lines[6] = StringFormat("昨收: %s", DoubleToString(snap.yesterday_close, snap.digits));
    lines[7] = StringFormat("今开: %s", DoubleToString(snap.today_open, snap.digits));
    lines[8] = StringFormat("今高: %s", DoubleToString(snap.today_high, snap.digits));
    lines[9] = StringFormat("今低: %s", DoubleToString(snap.today_low, snap.digits));
    lines[10] = StringFormat("点差: %d pts  |  波幅: %d pts", snap.spread, snap.range_points);
    lines[11] = StringFormat("涨跌: %s pts", snap.change_str);

    int line_height = 15;
    int start_y = 55;
    int start_x = 20;

    for(int i = 0; i < ArraySize(lines); i++)
    {
        string obj_name = snap.base_name + "_Line" + IntegerToString(i);

        if(ObjectFind(0, obj_name) == -1)
        {
            ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
            ObjectSetInteger(0, obj_name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
            ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrBlack);
            ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, 9);
            ObjectSetString(0, obj_name, OBJPROP_FONT, "Consolas");
            ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
            ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
        }

        ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, start_x);
        ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, start_y + (i * line_height));
        ObjectSetString(0, obj_name, OBJPROP_TEXT, lines[i]);
    }
}

//+------------------------------------------------------------------+
//| 慢速刷新：Buy/Sell 止损箭头（1秒节流）                           |
//+------------------------------------------------------------------+
void UpdateAtrSlArrows_Throttled(const AtrDisplaySnapshot &snap)
{
    if(Is_EA_Mode) return;

    static datetime last_update_time = 0;
    if(TimeCurrent() == last_update_time) return;
    last_update_time = TimeCurrent();

    datetime current_time = Time[0];

    string buy_sl_name = snap.base_name + "_BuySL_Label";
    if(ObjectFind(0, buy_sl_name) == -1)
    {
        ObjectCreate(0, buy_sl_name, OBJ_ARROW_RIGHT_PRICE, 0, current_time, snap.buy_sl_price);
        ObjectSetInteger(0, buy_sl_name, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, buy_sl_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, buy_sl_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, buy_sl_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, buy_sl_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, buy_sl_name, OBJPROP_HIDDEN, true);
    }
    else
    {
        ObjectSetInteger(0, buy_sl_name, OBJPROP_TIME, 0, current_time);
        ObjectSetDouble(0, buy_sl_name, OBJPROP_PRICE, 0, snap.buy_sl_price);
    }

    string sell_sl_name = snap.base_name + "_SellSL_Label";
    if(ObjectFind(0, sell_sl_name) == -1)
    {
        ObjectCreate(0, sell_sl_name, OBJ_ARROW_RIGHT_PRICE, 0, current_time, snap.sell_sl_price);
        ObjectSetInteger(0, sell_sl_name, OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(0, sell_sl_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, sell_sl_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, sell_sl_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, sell_sl_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, sell_sl_name, OBJPROP_HIDDEN, true);
    }
    else
    {
        ObjectSetInteger(0, sell_sl_name, OBJPROP_TIME, 0, current_time);
        ObjectSetDouble(0, sell_sl_name, OBJPROP_PRICE, 0, snap.sell_sl_price);
    }
}

//+------------------------------------------------------------------+
//| 快速刷新：大字体当前价格（不节流）                               |
//+------------------------------------------------------------------+
void UpdateAtrCurrentPriceBigLabel_Fast(const AtrDisplaySnapshot &snap)
{
    if(Is_EA_Mode) return;

    int start_x = 20;
    int line_height = 15;
    int start_y = 50;
    int price_label_y = start_y + (11 * line_height) + 20;

    string price_label_name = snap.base_name + "_CurrentPrice_BigLabel";

    color price_color;
    if(snap.change_points > 0)
        price_color = C'0,130,0';
    else if(snap.change_points < 0)
        price_color = C'253,0,2';
    else
        price_color = clrYellow;

    string price_text = DoubleToString(snap.current_price, snap.digits);

    if(ObjectFind(0, price_label_name) == -1)
    {
        ObjectCreate(0, price_label_name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, price_label_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, price_label_name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
        ObjectSetInteger(0, price_label_name, OBJPROP_FONTSIZE, 32);
        ObjectSetString(0, price_label_name, OBJPROP_FONT, "Arial Black");
        ObjectSetInteger(0, price_label_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, price_label_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, price_label_name, OBJPROP_HIDDEN, true);
    }

    ObjectSetInteger(0, price_label_name, OBJPROP_XDISTANCE, start_x);
    ObjectSetInteger(0, price_label_name, OBJPROP_YDISTANCE, price_label_y);
    ObjectSetInteger(0, price_label_name, OBJPROP_COLOR, price_color);
    ObjectSetString(0, price_label_name, OBJPROP_TEXT, price_text);
}

//+------------------------------------------------------------------+
//| 快速刷新：涨跌点数标签（不节流）                                 |
//+------------------------------------------------------------------+
void UpdateAtrPriceChangeLabel_Fast(const AtrDisplaySnapshot &snap)
{
    if(Is_EA_Mode) return;

    int start_x = 20;
    int line_height = 15;
    int start_y = 50;
    int price_label_y = start_y + (11 * line_height) + 20;
    int change_label_y = price_label_y + 60;

    string change_label_name = snap.base_name + "_PriceChange_Label";

    color price_color;
    if(snap.change_points > 0)
        price_color = C'0,130,0';
    else if(snap.change_points < 0)
        price_color = C'253,0,2';
    else
        price_color = clrYellow;

    string change_display = StringFormat("%s pts", snap.change_str);

    if(ObjectFind(0, change_label_name) == -1)
    {
        ObjectCreate(0, change_label_name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, change_label_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, change_label_name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
        ObjectSetInteger(0, change_label_name, OBJPROP_FONTSIZE, 12);
        ObjectSetString(0, change_label_name, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, change_label_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, change_label_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, change_label_name, OBJPROP_HIDDEN, true);
    }

    ObjectSetInteger(0, change_label_name, OBJPROP_XDISTANCE, start_x);
    ObjectSetInteger(0, change_label_name, OBJPROP_YDISTANCE, change_label_y);
    ObjectSetInteger(0, change_label_name, OBJPROP_COLOR, price_color);
    ObjectSetString(0, change_label_name, OBJPROP_TEXT, change_display);
}

//+------------------------------------------------------------------+
//| 在主图表显示当前 ATR 面板 (包含倍数与止损位) - 修正多行显示
//+------------------------------------------------------------------+
void UpdateATRDisplay()
{
   if(Is_EA_Mode) return; // EA 模式不显示

   // === 节流：每秒最多执行一次，避免每个 tick 重绘 ===
   static datetime last_update_time = 0;
   if(TimeCurrent() == last_update_time) return;
   last_update_time = TimeCurrent();
   // === 节流结束 ===

   string base_name = g_object_prefix + "ATR_Dashboard";
   
   // 1. 获取自适应参数
   int atr_period = GetAdaptiveATRPeriod(_Period);      // 获取周期
   double atr_mult = GetAdaptiveATRMultiplier(_Period); // 获取倍数
   
   // 2. 计算数值
   double current_price = Close[0]; 
    double atr_value = KT_GetATR(_Symbol, _Period, atr_period, 0);
   
   // 计算止损距离 (ATR * 倍数)
   double sl_distance = atr_value * atr_mult;
   
   // 计算具体的止损价格
   double buy_sl_price = current_price - sl_distance;  // 做多止损在下方
   double sell_sl_price = current_price + sl_distance; // 做空止损在上方
   
   // [新增] 获取日线数据（跨周期访问）
   double yesterday_close = iClose(_Symbol, PERIOD_D1, 1);  // 昨天收盘
   double today_open = iOpen(_Symbol, PERIOD_D1, 0);        // 今天开盘
   double today_high = iHigh(_Symbol, PERIOD_D1, 0);        // 今天最高
   double today_low = iLow(_Symbol, PERIOD_D1, 0);          // 今天最低
   
   // [新增] 计算市场数据
   int spread = (int)MarketInfo(_Symbol, MODE_SPREAD);                         // 点差（点）
   double range_price = today_high - today_low;                                // 波幅（价格）
    int range_points = (int)(range_price / _Point);                              // 波幅（点）
   double change_price = current_price - yesterday_close;                      // 涨跌（价格）
    int change_points = (int)(change_price / _Point);                            // 涨跌（点）
   
   // [新增] 格式化涨跌字符串（正数加"+"）
   string change_str;
   if(change_points > 0)
      change_str = "+" + IntegerToString(change_points);
   else if(change_points < 0)
      change_str = IntegerToString(change_points);
   else
      change_str = "0";
   
   // 获取当前品种的小数位数
   int digits = (int)MarketInfo(_Symbol, MODE_DIGITS);

   // 3. 构建多行文本数组（每行独立）- 扩展到12行
   string lines[];
   ArrayResize(lines, 12);
   
   lines[0] = StringFormat("ATR(%d): %s  |  Mult: %.1fx", atr_period, DoubleToString(atr_value, digits), atr_mult);
    lines[1] = StringFormat("SL Space: %d pts", (int)(sl_distance / _Point));
   lines[2] = "------------------";
   lines[3] = StringFormat("Buy SL: %s", DoubleToString(buy_sl_price, digits));
   lines[4] = StringFormat("Sell SL: %s", DoubleToString(sell_sl_price, digits));
   lines[5] = "==================";
   lines[6] = StringFormat("昨收: %s", DoubleToString(yesterday_close, digits));
   lines[7] = StringFormat("今开: %s", DoubleToString(today_open, digits));
   lines[8] = StringFormat("今高: %s", DoubleToString(today_high, digits));
   lines[9] = StringFormat("今低: %s", DoubleToString(today_low, digits));
   lines[10] = StringFormat("点差: %d pts  |  波幅: %d pts", spread, range_points);
   lines[11] = StringFormat("涨跌: %s pts", change_str);

   // 4. 创建或更新多个 Label 对象（每行一个）
   int line_height = 15; // 每行间距（像素）
   int start_y = 50;     // 起始Y坐标
   int start_x = 20;     // 距离右侧距离
   
   for(int i = 0; i < ArraySize(lines); i++)
   {
      string obj_name = base_name + "_Line" + IntegerToString(i);
      
      // 创建对象（如果不存在）
      if(ObjectFind(0, obj_name) == -1)
      {
         ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(0, obj_name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrBlack);
         ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, 9);
         ObjectSetString(0, obj_name, OBJPROP_FONT, "Consolas"); // 等宽字体
         ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
         ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
      }
      
      // 更新位置和文本
      ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, start_x);
      ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, start_y + (i * line_height));
      ObjectSetString(0, obj_name, OBJPROP_TEXT, lines[i]);
   }
   
   // 5. 在当前K线上方和下方显示 Buy SL 和 Sell SL 价格标签
   datetime current_time = Time[0]; // 当前K线的时间
   
   // 创建或更新 Buy SL 价格标签（做多止损，红色，显示在下方）
   string buy_sl_name = base_name + "_BuySL_Label";
   if(ObjectFind(0, buy_sl_name) == -1)
   {
      ObjectCreate(0, buy_sl_name, OBJ_ARROW_RIGHT_PRICE, 0, current_time, buy_sl_price);
      ObjectSetInteger(0, buy_sl_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, buy_sl_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, buy_sl_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, buy_sl_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, buy_sl_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, buy_sl_name, OBJPROP_HIDDEN, true);
   }
   else
   {
      // 更新时间和价格
      ObjectSetInteger(0, buy_sl_name, OBJPROP_TIME, 0, current_time);
      ObjectSetDouble(0, buy_sl_name, OBJPROP_PRICE, 0, buy_sl_price);
   }
   
   // 创建或更新 Sell SL 价格标签（做空止损，蓝色，显示在上方）
   string sell_sl_name = base_name + "_SellSL_Label";
   if(ObjectFind(0, sell_sl_name) == -1)
   {
      ObjectCreate(0, sell_sl_name, OBJ_ARROW_RIGHT_PRICE, 0, current_time, sell_sl_price);
      ObjectSetInteger(0, sell_sl_name, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, sell_sl_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, sell_sl_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, sell_sl_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, sell_sl_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, sell_sl_name, OBJPROP_HIDDEN, true);
   }
   else
   {
      // 更新时间和价格
      ObjectSetInteger(0, sell_sl_name, OBJPROP_TIME, 0, current_time);
      ObjectSetDouble(0, sell_sl_name, OBJPROP_PRICE, 0, sell_sl_price);
   }
   
   // ====================================================================
   // === 新增功能：动态显示当前价格大字体标签（醒目） ===
   // ====================================================================
   
   string price_label_name = base_name + "_CurrentPrice_BigLabel";
   
   // 判断价格涨跌，决定颜色
   color price_color;
   if(change_points > 0)
      price_color = C'0,130,0';           // 上涨：亮绿色
   else if(change_points < 0)
      price_color = C'253,0,2';            // 下跌：红色
   else
      price_color = clrYellow;         // 持平：黄色
   
   // 格式化当前价格文本
   string price_text = DoubleToString(current_price, digits);
   
   // 计算价格标签的Y坐标（在第11行下方）
   // 第11行Y坐标 = start_y + (11 * line_height) = 50 + 165 = 215
   // 价格标签Y = 215 + 20（额外间距）= 235
   int price_label_y = start_y + (11 * line_height) + 20;
   
   // 创建或更新大字体价格标签
   if(ObjectFind(0, price_label_name) == -1)
   {
      ObjectCreate(0, price_label_name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, price_label_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);   // 右上角定位
      ObjectSetInteger(0, price_label_name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);   // 右对齐
      ObjectSetInteger(0, price_label_name, OBJPROP_FONTSIZE, 32);                 // 大字体32号
      ObjectSetString(0, price_label_name, OBJPROP_FONT, "Arial Black");           // 粗体字体
      ObjectSetInteger(0, price_label_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, price_label_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, price_label_name, OBJPROP_HIDDEN, true);
   }
   
   // 更新位置、颜色和文本
   ObjectSetInteger(0, price_label_name, OBJPROP_XDISTANCE, start_x);      // 与Dashboard对齐
   ObjectSetInteger(0, price_label_name, OBJPROP_YDISTANCE, price_label_y); // 第11行下方
   ObjectSetInteger(0, price_label_name, OBJPROP_COLOR, price_color);      // 动态颜色
   ObjectSetString(0, price_label_name, OBJPROP_TEXT, price_text);         // 当前价格
   
   // === 新增：在价格标签下方显示涨跌信息（小字体） ===
   string change_label_name = base_name + "_PriceChange_Label";
   
   // 涨跌文本（带符号）
   string change_display = StringFormat("%s pts", change_str);
   
   // 计算涨跌标签的Y坐标（在价格标签下方）
   int change_label_y = price_label_y + 60;
   
   // 创建或更新涨跌标签
   if(ObjectFind(0, change_label_name) == -1)
   {
      ObjectCreate(0, change_label_name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, change_label_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);  // 右上角定位
      ObjectSetInteger(0, change_label_name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);  // 右对齐
      ObjectSetInteger(0, change_label_name, OBJPROP_FONTSIZE, 12);                // 小字体
      ObjectSetString(0, change_label_name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, change_label_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, change_label_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, change_label_name, OBJPROP_HIDDEN, true);
   }
   
   // 更新位置、颜色和文本
   ObjectSetInteger(0, change_label_name, OBJPROP_XDISTANCE, start_x);      // 与Dashboard对齐
   ObjectSetInteger(0, change_label_name, OBJPROP_YDISTANCE, change_label_y); // 价格标签下方
   ObjectSetInteger(0, change_label_name, OBJPROP_COLOR, price_color);      // 与价格颜色一致
   ObjectSetString(0, change_label_name, OBJPROP_TEXT, change_display);     // 涨跌点数
}
//#endregion

//#region MARK: 模块--非重要附加模块
//+------------------------------------------------------------------+
//| 核心逻辑：更新计算和显示 Indicators\KT_Quick_Profit_Calc.mq4 移植过来
//+------------------------------------------------------------------+
void UpdateCalculation(datetime end_time, double end_price, int x, int y)
{
   // 1. 更新线条位置
   ObjectSetInteger(0, LineObjName, OBJPROP_TIME, 1, end_time); // 正确：时间要用 SetInteger
   ObjectSetDouble(0, LineObjName, OBJPROP_PRICE, 1, end_price);
   
   // 2. 计算数据
   double distance_price = MathAbs(end_price - Start_Price);
    double points = distance_price / _Point; // 距离点数
   
   // 获取当前品种 1手跳动1个Point的价值 (这是核心，自动适配所有品种)
   double tick_value = MarketInfo(Symbol(), MODE_TICKVALUE);
   if (tick_value <= 0)
   {
      // 备用方案：使用合约大小和最小变动来计算
      double contract_size = MarketInfo(Symbol(), MODE_LOTSIZE);      // 合约大小 (标准手)
      double tick_size = MarketInfo(Symbol(), MODE_TICKSIZE);         // 最小价格变动

      if(contract_size > 0 && tick_size > 0)
      {
         // tick_value = 合约大小 × (Point / TickSize)
         // 这适用于大多数品种（外汇、黄金、原油等）
         tick_value = contract_size * (_Point / tick_size);
      }
      else
      {
         // 如果仍然无法获取，使用保底值 1.0（至少显示点数关系）
         tick_value = 1.0;
      }
   }
   // 盈亏金额 = 点数 * 单点价值 * 手数
   double profit_money = points * tick_value * InpDefaultLots;
   
   // 3. 格式化显示文本
   string text = "";
   text += "手数: " + DoubleToString(InpDefaultLots, 2) + "  ";
   text += "点数: " + DoubleToString(points, 0) + " pts  ";
    text += "盈亏: " + DoubleToString(profit_money, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY);
   
   // 4. 更新文本标签位置 (跟随鼠标)
   // 我们稍微偏移一点坐标，避免挡住鼠标指针
   int offset_x = 15;
   int offset_y = 15;
   
   // 更新背景框位置
   ObjectSetInteger(0, RectObjName, OBJPROP_XDISTANCE, x + offset_x);
   ObjectSetInteger(0, RectObjName, OBJPROP_YDISTANCE, y + offset_y);
   
   // 更新文字位置
   ObjectSetString(0, TextObjName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, TextObjName, OBJPROP_XDISTANCE, x + offset_x + 5);
   ObjectSetInteger(0, TextObjName, OBJPROP_YDISTANCE, y + offset_y + 5);
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| 辅助函数：创建线条                                               |
//+------------------------------------------------------------------+
void CreateLineObject()
{
   if(ObjectFind(0, LineObjName) < 0)
   {
      ObjectCreate(0, LineObjName, OBJ_TREND, 0, Start_Time, Start_Price, Start_Time, Start_Price);
      ObjectSetInteger(0, LineObjName, OBJPROP_COLOR, InpLineColor);
      ObjectSetInteger(0, LineObjName, OBJPROP_WIDTH, InpLineWidth);
      ObjectSetInteger(0, LineObjName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, LineObjName, OBJPROP_RAY, false); // 不射线
      ObjectSetInteger(0, LineObjName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, LineObjName, OBJPROP_HIDDEN, true); // 脚本列表中隐藏
   }
}

//+------------------------------------------------------------------+
//| 辅助函数：创建文本标签                                           |
//+------------------------------------------------------------------+
void CreateLabelObjects()
{
   // 创建背景框 (使用 Label 或 RectangleLabel)
   if(ObjectFind(0, RectObjName) < 0)
   {
      ObjectCreate(0, RectObjName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, RectObjName, OBJPROP_XSIZE, 300); // 宽
      ObjectSetInteger(0, RectObjName, OBJPROP_YSIZE, 60);  // 高
      ObjectSetInteger(0, RectObjName, OBJPROP_BGCOLOR, InpBgColor);
      ObjectSetInteger(0, RectObjName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, RectObjName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, RectObjName, OBJPROP_BACK, false);
      ObjectSetInteger(0, RectObjName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, RectObjName, OBJPROP_HIDDEN, true);
   }
   
   // 创建文字
   if(ObjectFind(0, TextObjName) < 0)
   {
      ObjectCreate(0, TextObjName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, TextObjName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, TextObjName, OBJPROP_COLOR, InpTextColor);
      ObjectSetInteger(0, TextObjName, OBJPROP_FONTSIZE, InpFontSize);
      ObjectSetInteger(0, TextObjName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, TextObjName, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| 辅助函数：清理对象                                               |
//+------------------------------------------------------------------+
void DeleteProfit_CalcObjects()
{
   ObjectDelete(0, LineObjName);
   ObjectDelete(0, RectObjName);
   ObjectDelete(0, TextObjName);
}

//+------------------------------------------------------------------+
//| 交易纪律提醒功能 (Trading Rules Reminder Display)
//+------------------------------------------------------------------+

/*
// 对象名称前缀
string Rules_Prefix = "TradingRules_";

// 交易纪律文本内容（9条规则）
string Trading_Rules[] = {
   "1.单单带止损,永远不抗单,先入场后止损.",
   "2.赚钱是对规矩的遵守;钱是你对遵守规矩的奖赏",
   "3.先保本后盈利",
   "4.每一单都一样,没有神单",
   "5.每一个看到的位置都是不确定的.比如5355;5339.",
   "6.就是用被损后的倍仓,也远远大于不止损",
   "7.交易是一项体育运动.",
   "8.每一天你不是要赚钱,而是每一单你是不是都是按步骤操作的.",
   "9.止损不可怕;连损也不可怕;可怕的是 不止损;"
};
*/

//+------------------------------------------------------------------+
//| 创建交易纪律提醒显示（使用容器方案）
//+------------------------------------------------------------------+
void CreateTradingRulesDisplay()
{
   // 如果未启用或处于EA模式，直接返回
   if (!Show_Trading_Rules || Is_EA_Mode) return;
   
   // 📐 容器尺寸计算
   int line_height = Rules_Font_Size + 4;        // 行高 = 字体大小 + 行间距
   int rules_count = ArraySize(Trading_Rules);   // 规则数量
   int total_lines = rules_count + 3;             // 总行数 = 规则 + 标题 + 2条分隔线
   
   int container_width = 400;                     // 容器宽度（足够容纳最长文本）
   int container_height = total_lines * line_height + 20;  // 容器高度（总行高 + 上下边距）
   int text_padding = 10;                         // 文本距容器边缘的内边距
   
   // 🎨 步骤1：创建背景容器（矩形框）
   string container_name = Rules_Prefix + "Container";
   if (ObjectFind(0, container_name) < 0)
   {
      ObjectCreate(0, container_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   }
   
   // 🔧 关键修正：RECTANGLE_LABEL的锚点永远是矩形的左上角！
   // 使用CORNER_RIGHT_LOWER时，坐标从右下角计算，但定位的是矩形左上角
   // 所以XDISTANCE需要 = 容器宽度 + 右边距，让矩形向左延伸到可见区域
   // YDISTANCE需要 = 容器高度 + 底边距，让矩形向上延伸到可见区域
   int container_x = Rules_X_Distance + container_width;      // 矩形左上角距右边缘的距离
   int container_y = Rules_Y_Distance + container_height;     // 矩形左上角距底边缘的距离
   
   ObjectSetInteger(0, container_name, OBJPROP_CORNER, CORNER_RIGHT_LOWER);       // 右下角坐标系
   ObjectSetInteger(0, container_name, OBJPROP_XDISTANCE, container_x);           // 矩形左上角X坐标
   ObjectSetInteger(0, container_name, OBJPROP_YDISTANCE, container_y);           // 矩形左上角Y坐标
   ObjectSetInteger(0, container_name, OBJPROP_XSIZE, container_width);           // 容器宽度
   ObjectSetInteger(0, container_name, OBJPROP_YSIZE, container_height);          // 容器高度
   ObjectSetInteger(0, container_name, OBJPROP_BGCOLOR, clrBlack);                // 背景颜色：黑色
   ObjectSetInteger(0, container_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);         // 边框类型
   ObjectSetInteger(0, container_name, OBJPROP_COLOR, clrOrangeRed);              // 边框颜色（醒目）
   ObjectSetInteger(0, container_name, OBJPROP_WIDTH, 2);                         // 边框宽度
   ObjectSetInteger(0, container_name, OBJPROP_BACK, false);                      // 不在背景层
   ObjectSetInteger(0, container_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, container_name, OBJPROP_HIDDEN, true);
   
   // 📝 步骤2：在容器内绘制文本（从底部向上）
   // 🔧 文本坐标计算（左对齐）：
   // - 容器左边缘距屏幕右边缘 = Rules_X_Distance + container_width
   // - 文本左边缘应该距容器左边缘内侧 text_padding
   // - 所以：text_x = Rules_X_Distance + container_width - text_padding
   // 
   // - 容器底边缘距屏幕底边缘 = Rules_Y_Distance  
   // - 文本第一行应该距容器底边缘内侧 10px
   // - 所以：text_y_start = Rules_Y_Distance + 10
   int text_x = Rules_X_Distance + container_width - text_padding;  // 文本左边缘位置
   int text_y = Rules_Y_Distance + 10;  // 从容器底部向上10像素开始
   
   // 1. 底部分隔线（最底部，Y最小）
   string bottom_separator = Rules_Prefix + "BottomSeparator";
   if (ObjectFind(0, bottom_separator) < 0)
   {
      ObjectCreate(0, bottom_separator, OBJ_LABEL, 0, 0, 0);
   }
   
   ObjectSetInteger(0, bottom_separator, OBJPROP_CORNER, CORNER_RIGHT_LOWER);     // 使用右下角锚点
   ObjectSetInteger(0, bottom_separator, OBJPROP_ANCHOR, ANCHOR_LEFT);            // 🔧 文本左对齐（从左向右延伸）
   ObjectSetInteger(0, bottom_separator, OBJPROP_XDISTANCE, text_x);              // 文本左边缘位置
   ObjectSetInteger(0, bottom_separator, OBJPROP_YDISTANCE, text_y);
   ObjectSetInteger(0, bottom_separator, OBJPROP_COLOR, Rules_Title_Color);
   ObjectSetInteger(0, bottom_separator, OBJPROP_FONTSIZE, Rules_Font_Size);
   ObjectSetString(0, bottom_separator, OBJPROP_FONT, Rules_Font_Name);
   ObjectSetString(0, bottom_separator, OBJPROP_TEXT, "========================");
   ObjectSetInteger(0, bottom_separator, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bottom_separator, OBJPROP_HIDDEN, true);
   
   text_y += line_height;
   
   // 2. 规则内容（从第9条到第1条，反向遍历数组）
   for (int i = rules_count - 1; i >= 0; i--)  // 🔧 反向循环：从9到1
   {
      string rule_name = Rules_Prefix + "Line_" + IntegerToString(i + 1);
      
      if (ObjectFind(0, rule_name) < 0)
      {
         ObjectCreate(0, rule_name, OBJ_LABEL, 0, 0, 0);
      }
      
      ObjectSetInteger(0, rule_name, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
      ObjectSetInteger(0, rule_name, OBJPROP_ANCHOR, ANCHOR_LEFT);               // 🔧 文本左对齐（从左向右延伸）
      ObjectSetInteger(0, rule_name, OBJPROP_XDISTANCE, text_x);                  // 文本左边缘位置
      ObjectSetInteger(0, rule_name, OBJPROP_YDISTANCE, text_y);
      ObjectSetInteger(0, rule_name, OBJPROP_COLOR, Rules_Text_Color);
      ObjectSetInteger(0, rule_name, OBJPROP_FONTSIZE, Rules_Font_Size);
      ObjectSetString(0, rule_name, OBJPROP_FONT, Rules_Font_Name);
      ObjectSetString(0, rule_name, OBJPROP_TEXT, Trading_Rules[i]);
      ObjectSetInteger(0, rule_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, rule_name, OBJPROP_HIDDEN, true);
      
      text_y += line_height;
   }
   
   // 3. 顶部分隔线
   string separator_name = Rules_Prefix + "Separator";
   if (ObjectFind(0, separator_name) < 0)
   {
      ObjectCreate(0, separator_name, OBJ_LABEL, 0, 0, 0);
   }
   
   ObjectSetInteger(0, separator_name, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, separator_name, OBJPROP_ANCHOR, ANCHOR_LEFT);              // 🔧 文本左对齐（从左向右延伸）
   ObjectSetInteger(0, separator_name, OBJPROP_XDISTANCE, text_x);                // 文本左边缘位置
   ObjectSetInteger(0, separator_name, OBJPROP_YDISTANCE, text_y);
   ObjectSetInteger(0, separator_name, OBJPROP_COLOR, Rules_Title_Color);
   ObjectSetInteger(0, separator_name, OBJPROP_FONTSIZE, Rules_Font_Size);
   ObjectSetString(0, separator_name, OBJPROP_FONT, Rules_Font_Name);
   ObjectSetString(0, separator_name, OBJPROP_TEXT, "========================");
   ObjectSetInteger(0, separator_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, separator_name, OBJPROP_HIDDEN, true);
   
   text_y += line_height + 2;  // 标题前多留2像素间距
   
   // 4. 标题（最顶部，Y最大）
   string title_name = Rules_Prefix + "Title";
   if (ObjectFind(0, title_name) < 0)
   {
      ObjectCreate(0, title_name, OBJ_LABEL, 0, 0, 0);
   }
   
   ObjectSetInteger(0, title_name, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, title_name, OBJPROP_ANCHOR, ANCHOR_LEFT);                  // 🔧 文本左对齐（从左向右延伸）
   ObjectSetInteger(0, title_name, OBJPROP_XDISTANCE, text_x);                    // 文本左边缘位置
   ObjectSetInteger(0, title_name, OBJPROP_YDISTANCE, text_y);
   ObjectSetInteger(0, title_name, OBJPROP_COLOR, Rules_Title_Color);
   ObjectSetInteger(0, title_name, OBJPROP_FONTSIZE, Rules_Font_Size + 2);        // 标题字号稍大
   ObjectSetString(0, title_name, OBJPROP_FONT, Rules_Font_Name);
   ObjectSetString(0, title_name, OBJPROP_TEXT, "【交易纪律提醒】");
   ObjectSetInteger(0, title_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, title_name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| 删除交易纪律提醒显示
//+------------------------------------------------------------------+
void DeleteTradingRulesDisplay()
{
   // 删除背景容器
   ObjectDelete(0, Rules_Prefix + "Container");
   
   // 删除标题
   ObjectDelete(0, Rules_Prefix + "Title");
   
   // 删除分隔线
   ObjectDelete(0, Rules_Prefix + "Separator");
   ObjectDelete(0, Rules_Prefix + "BottomSeparator");
   
   // 删除所有规则行
   int rules_count = ArraySize(Trading_Rules);
   for (int i = 0; i < rules_count; i++)
   {
      ObjectDelete(0, Rules_Prefix + "Line_" + IntegerToString(i + 1));
   }
}

//+------------------------------------------------------------------+
//| 创建配置信息显示板 (右下角显示当前指标配置)
//+------------------------------------------------------------------+
void CreateConfigInfoDisplay()
{
   // EA模式或未启用时直接返回
   if (Is_EA_Mode || !Show_Config_Info) return;
   
   string prefix = "ConfigInfo_";
   
   // 1. 准备显示文本 - 读取五个关键配置
   string anchor_mode = (Find_Target_Model == 1) ? "Standard (1)" : "Strict (2)";
   string honest_filter = Enable_Honest_Filter ? " ON" : " OFF";
   string p2_search = Use_Enhanced_P2_Search ? " Enhanced" : " Standard";
   string strict_plevel = Use_Strict_PLevel_Search ? " Strict" : " Standard";
   string min_bars = IntegerToString(Strict_PLevel_Min_Bars_Between);
   
   string lines[7];
   lines[0] = "【指标配置信息】";
   lines[1] = "────────────────────";
   lines[2] = "1. 锚点模式: " + anchor_mode;
   lines[3] = "2. Honest过滤: " + honest_filter;
   lines[4] = "3. P2严格查找: " + p2_search;
   lines[5] = "4. P3-P5严格查找: " + strict_plevel;
   lines[6] = "5. P等级最小间隔: " + min_bars + " bars";
   
   // 2. 计算尺寸
   int line_height = Config_Info_Font_Size + 4;
   int container_width = 260;
   int container_height = ArraySize(lines) * line_height + 20;
   
   // 3. 创建背景容器
   string container_name = prefix + "Container";
   if (ObjectFind(0, container_name) < 0)
      ObjectCreate(0, container_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, container_name, OBJPROP_CORNER, Config_Info_Corner);
   ObjectSetInteger(0, container_name, OBJPROP_XDISTANCE, Config_Info_X_Distance + container_width);
   ObjectSetInteger(0, container_name, OBJPROP_YDISTANCE, Config_Info_Y_Distance + container_height);
   ObjectSetInteger(0, container_name, OBJPROP_XSIZE, container_width);
   ObjectSetInteger(0, container_name, OBJPROP_YSIZE, container_height);
   ObjectSetInteger(0, container_name, OBJPROP_BGCOLOR, Config_Info_BG_Color);
   ObjectSetInteger(0, container_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, container_name, OBJPROP_COLOR, Config_Info_Text_Color);
   ObjectSetInteger(0, container_name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, container_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, container_name, OBJPROP_HIDDEN, true);
   
   // 4. 创建文本标签（从底部向上）
   int text_x = Config_Info_X_Distance + container_width - 10;
   int text_y = Config_Info_Y_Distance + 10;
   
   for (int i = ArraySize(lines) - 1; i >= 0; i--)
   {
      string label_name = prefix + "Line_" + IntegerToString(i);
      if (ObjectFind(0, label_name) < 0)
         ObjectCreate(0, label_name, OBJ_LABEL, 0, 0, 0);
      
      ObjectSetInteger(0, label_name, OBJPROP_CORNER, Config_Info_Corner);
      ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, label_name, OBJPROP_XDISTANCE, text_x);
      ObjectSetInteger(0, label_name, OBJPROP_YDISTANCE, text_y);
      ObjectSetInteger(0, label_name, OBJPROP_COLOR, (i == 0) ? clrYellow : Config_Info_Text_Color);
      ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, (i == 0) ? Config_Info_Font_Size + 0 : Config_Info_Font_Size);
      ObjectSetString(0, label_name, OBJPROP_FONT, "Microsoft YaHei");
      ObjectSetString(0, label_name, OBJPROP_TEXT, lines[i]);
      ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, true);
      
      text_y += line_height;
   }
}

//+------------------------------------------------------------------+
//| 删除配置信息显示
//+------------------------------------------------------------------+
void DeleteConfigInfoDisplay()
{
   string prefix = "ConfigInfo_";
   ObjectDelete(0, prefix + "Container");
   
   // 删除所有文本行（最多10行）
   for (int i = 0; i < 10; i++)
   {
      ObjectDelete(0, prefix + "Line_" + IntegerToString(i));
   }
}

//+------------------------------------------------------------------+
//| 🛠️ 辅助工具函数：计算 OBJ_RECTANGLE_LABEL 在不同 CORNER 模式下的正确坐标
//+------------------------------------------------------------------+
/*
功能说明：
   由于 OBJ_RECTANGLE_LABEL 的锚点永远是矩形的左上角，在使用不同的 CORNER
   (坐标系原点) 时，需要根据矩形的宽度和高度调整坐标，才能让矩形显示在期望位置。
   
   本函数封装了这个计算逻辑，简化代码并避免手动计算错误。

核心原理：
   - CORNER 决定坐标系原点在屏幕哪个角落
   - RECTANGLE_LABEL 锚点固定为左上角
   - 矩形从左上角向右下延伸
   - 要让矩形"靠近"某个角落，需要反向计算左上角的位置

参数说明：
   @param corner      - 坐标系原点位置 (CORNER_LEFT_UPPER/RIGHT_UPPER/LEFT_LOWER/RIGHT_LOWER)
   @param margin_x    - 期望的矩形边缘距屏幕边缘的水平距离（像素）
   @param margin_y    - 期望的矩形边缘距屏幕边缘的垂直距离（像素）
   @param width       - 矩形宽度（像素）
   @param height      - 矩形高度（像素）
   @param out_x       - [输出] 计算后的矩形左上角 X 坐标（用于 OBJPROP_XDISTANCE）
   @param out_y       - [输出] 计算后的矩形左上角 Y 坐标（用于 OBJPROP_YDISTANCE）

返回值：
   无（通过引用参数返回计算结果）

计算逻辑：
   1. 右侧 CORNER (RIGHT_*):   out_x = margin_x + width   (需要加上矩形宽度)
      左侧 CORNER (LEFT_*):     out_x = margin_x           (直接使用边距)
   
   2. 底部 CORNER (*_LOWER):    out_y = margin_y + height  (需要加上矩形高度)
      顶部 CORNER (*_UPPER):    out_y = margin_y           (直接使用边距)

使用示例：
   
   // 示例1：右下角定位一个 400x150 的矩形，距右边缘10px，距底边缘20px
   int rect_x, rect_y;
   CalculateRectPosition(
       CORNER_RIGHT_LOWER,  // 右下角坐标系
       10,                  // 距右边缘10px
       20,                  // 距底边缘20px
       400,                 // 宽度
       150,                 // 高度
       rect_x,              // 输出X坐标
       rect_y               // 输出Y坐标
   );
   // 结果: rect_x = 410, rect_y = 170
   
   // 使用计算结果创建矩形
   ObjectCreate(0, "MyRect", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "MyRect", OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, "MyRect", OBJPROP_XDISTANCE, rect_x);
   ObjectSetInteger(0, "MyRect", OBJPROP_YDISTANCE, rect_y);
   ObjectSetInteger(0, "MyRect", OBJPROP_XSIZE, 400);
   ObjectSetInteger(0, "MyRect", OBJPROP_YSIZE, 150);
   
   // 示例2：左上角定位一个 300x100 的矩形，距左边缘15px，距顶边缘25px
   int rect_x2, rect_y2;
   CalculateRectPosition(
       CORNER_LEFT_UPPER,   // 左上角坐标系
       15,                  // 距左边缘15px
       25,                  // 距顶边缘25px
       300,                 // 宽度
       100,                 // 高度
       rect_x2,             // 输出X坐标
       rect_y2              // 输出Y坐标
   );
   // 结果: rect_x2 = 15, rect_y2 = 25 (左上角模式下直接使用边距值)

注意事项：
   1. 本函数只适用于 OBJ_RECTANGLE_LABEL 对象
   2. 确保 width 和 height 为正数
   3. margin_x 和 margin_y 一般为正数（表示距离边缘的像素）
   4. 输出坐标直接用于 OBJPROP_XDISTANCE 和 OBJPROP_YDISTANCE
*/
//+------------------------------------------------------------------+
void CalculateRectPosition(
    ENUM_BASE_CORNER corner,    // 坐标系原点位置
    int margin_x,               // 期望的边缘距离 X
    int margin_y,               // 期望的边缘距离 Y
    int width,                  // 矩形宽度
    int height,                 // 矩形高度
    int &out_x,                 // [输出] 计算后的 X 坐标
    int &out_y                  // [输出] 计算后的 Y 坐标
)
{
    // 步骤1：计算 X 坐标
    // 判断坐标系原点是否在右侧 (RIGHT_UPPER 或 RIGHT_LOWER)
    if (corner == CORNER_RIGHT_LOWER || corner == CORNER_RIGHT_UPPER)
    {
        // 右侧坐标系：X坐标从右向左增长
        // 矩形左上角需要在 (margin_x + width) 的位置
        // 这样矩形向右延伸 width 后，右边缘刚好距屏幕右边缘 margin_x
        out_x = margin_x + width;
    }
    else  // CORNER_LEFT_LOWER 或 CORNER_LEFT_UPPER
    {
        // 左侧坐标系：X坐标从左向右增长
        // 矩形左上角直接使用 margin_x 即可
        out_x = margin_x;
    }
    
    // 步骤2：计算 Y 坐标
    // 判断坐标系原点是否在底部 (LEFT_LOWER 或 RIGHT_LOWER)
    if (corner == CORNER_LEFT_LOWER || corner == CORNER_RIGHT_LOWER)
    {
        // 底部坐标系：Y坐标从下向上增长
        // 矩形左上角需要在 (margin_y + height) 的位置
        // 这样矩形向下延伸 height 后，底边缘刚好距屏幕底边缘 margin_y
        out_y = margin_y + height;
    }
    else  // CORNER_LEFT_UPPER 或 CORNER_RIGHT_UPPER
    {
        // 顶部坐标系：Y坐标从上向下增长
        // 矩形左上角直接使用 margin_y 即可
        out_y = margin_y;
    }
}
//+------------------------------------------------------------------+
//#endregion