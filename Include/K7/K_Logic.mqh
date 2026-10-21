//+------------------------------------------------------------------+
//|                                                      K_Logic.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 25.11.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//#region MARK: 创建严格模式按钮
// 严格模式按钮在图表对象中的唯一名称，用于创建、查找和点击识别。
string Strict_Mode_Button_Name = "KTarget_StrictMode_Button";
// 严格+Honest模式按钮在图表对象中的唯一名称，用于创建、查找和点击识别。
string Strict_Honest_Mode_Button_Name = "KTarget_StrictHonestMode_Button";

// 清空目标与信号Buffer，供严格模式切换后重新计算并刷新图表显示。
void ClearSignalBuffersForRefresh()
{
    ArrayInitialize(BullishTargetBuffer, EMPTY_VALUE);
    ArrayInitialize(BearishTargetBuffer, EMPTY_VALUE);
    ArrayInitialize(BullishSignalBuffer, EMPTY_VALUE);
    ArrayInitialize(BearishSignalBuffer, EMPTY_VALUE);
}

// 根据当前快捷模式更新两个按钮的按下状态、背景颜色和显示文字。
void UpdateStrictModeButtonStates()
{
    if (Is_EA_Mode) return;

    if (ObjectFind(0, Strict_Mode_Button_Name) >= 0)
    {
        bool strict_on = (Current_Strict_Quick_Mode == STRICT_QUICK_STRICT);
        ObjectSetInteger(0, Strict_Mode_Button_Name, OBJPROP_STATE, strict_on);
        ObjectSetInteger(0, Strict_Mode_Button_Name, OBJPROP_BGCOLOR, strict_on ? clrSeaGreen : clrDimGray);
        ObjectSetString(0, Strict_Mode_Button_Name, OBJPROP_TEXT, strict_on ? "严格模式: ON" : "严格模式: OFF");
    }

    if (ObjectFind(0, Strict_Honest_Mode_Button_Name) >= 0)
    {
        bool strict_honest_on = (Current_Strict_Quick_Mode == STRICT_QUICK_STRICT_HONEST);
        ObjectSetInteger(0, Strict_Honest_Mode_Button_Name, OBJPROP_STATE, strict_honest_on);
        ObjectSetInteger(0, Strict_Honest_Mode_Button_Name, OBJPROP_BGCOLOR, strict_honest_on ? clrDodgerBlue : clrDimGray);
        ObjectSetString(0, Strict_Honest_Mode_Button_Name, OBJPROP_TEXT, strict_honest_on ? "严格+Honest: ON" : "严格+Honest: OFF");
    }
}

// 创建或更新单个严格模式快捷按钮，并设置位置、尺寸、颜色、字体和按钮文字。
void CreateStrictModeButton(string button_name, string button_text, int y_distance)
{
    if (ObjectFind(0, button_name) < 0)
    {
        ObjectCreate(0, button_name, OBJ_BUTTON, 0, 0, 0);
    }

    ObjectSetInteger(0, button_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, button_name, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, button_name, OBJPROP_YDISTANCE, y_distance);
    ObjectSetInteger(0, button_name, OBJPROP_XSIZE, 150);
    ObjectSetInteger(0, button_name, OBJPROP_YSIZE, 24);
    ObjectSetInteger(0, button_name, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, button_name, OBJPROP_BGCOLOR, clrDimGray);
    ObjectSetInteger(0, button_name, OBJPROP_BORDER_COLOR, clrSilver);
    ObjectSetInteger(0, button_name, OBJPROP_FONTSIZE, 9);
    ObjectSetInteger(0, button_name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, button_name, OBJPROP_HIDDEN, false);
    ObjectSetString(0, button_name, OBJPROP_FONT, "Microsoft YaHei");
    ObjectSetString(0, button_name, OBJPROP_TEXT, button_text);
    ObjectSetInteger(0, button_name, OBJPROP_HIDDEN, true); // 不在对象列表中显示按钮
}

// 在主图表上创建严格模式和严格+Honest模式两个快捷切换按钮。
void CreateStrictModeButtons()
{
    if (Is_EA_Mode) return;

    CreateStrictModeButton(Strict_Mode_Button_Name, "严格模式: OFF", 50);
    CreateStrictModeButton(Strict_Honest_Mode_Button_Name, "严格+Honest: OFF", 78);
    UpdateStrictModeButtonStates();
}

// 删除严格模式和严格+Honest模式两个快捷按钮，通常在指标卸载时调用。
void DeleteStrictModeButtons()
{
    ObjectDelete(0, Strict_Mode_Button_Name);
    ObjectDelete(0, Strict_Honest_Mode_Button_Name);
}

// 按目标快捷模式写入对应参数；标准模式恢复默认值，严格类模式启用严格查找配置。
void ApplyStrictQuickModeParams(StrictQuickMode target_mode)
{
    if (target_mode == STRICT_QUICK_STANDARD)
    {
        Find_Target_Model = DEFAULT_Find_Target_Model;
        Enable_Honest_Filter = DEFAULT_Enable_Honest_Filter;
        Use_Enhanced_P2_Search = DEFAULT_Use_Enhanced_P2_Search;
        Use_Strict_PLevel_Search = DEFAULT_Use_Strict_PLevel_Search;
        Strict_PLevel_Min_Bars_Between = DEFAULT_Strict_PLevel_Min_Bars_Between;
        return;
    }

    Find_Target_Model = 2;
    Use_Enhanced_P2_Search = true;
    Use_Strict_PLevel_Search = true;
    Strict_PLevel_Min_Bars_Between = 2;
    Enable_Honest_Filter = (target_mode == STRICT_QUICK_STRICT_HONEST);
}

// 严格模式参数切换后，清理旧对象和Buffer，重新执行查找绘制并刷新配置面板。
void RefreshStrictModeCalculation()
{
    g_Stats.Reset();
    DeInit_DelObject();
    ClearSignalBuffersForRefresh();
    ExecuteFindAndDraw(iBars(NULL, 0));
    DeleteConfigInfoDisplay();
    CreateConfigInfoDisplay();
    UpdateStrictModeButtonStates();
    ChartRedraw(0);
}

// 处理严格模式按钮点击事件；识别按钮名称、切换快捷模式、应用参数并触发刷新。
bool HandleStrictModeButtonClick(string object_name)
{
    StrictQuickMode target_mode = Current_Strict_Quick_Mode;

    if (object_name == Strict_Mode_Button_Name)
    {
        target_mode = (Current_Strict_Quick_Mode == STRICT_QUICK_STRICT) ? STRICT_QUICK_STANDARD : STRICT_QUICK_STRICT;
    }
    else if (object_name == Strict_Honest_Mode_Button_Name)
    {
        target_mode = (Current_Strict_Quick_Mode == STRICT_QUICK_STRICT_HONEST) ? STRICT_QUICK_STANDARD : STRICT_QUICK_STRICT_HONEST;
    }
    else
    {
        return false;
    }

    Current_Strict_Quick_Mode = target_mode;
    ApplyStrictQuickModeParams(target_mode);
    RefreshStrictModeCalculation();
    return true;
}
//#endregion

//#region MARK: 关于锚点的查找算法
// 判断指定K线是否为底部K目标；根据锚点查找模式选择标准算法或严格算法。
bool IsKTargetBottom(int i, int total_bars)
{
    if (Find_Target_Model == 2)
    {
        return CheckKTargetBottomCondition(i, total_bars, Lookahead_Bottom, Lookback_Bottom);
    }

    return CheckKTargetBottom_Default(i, total_bars, Lookahead_Bottom, Lookback_Bottom);
}

// 判断指定K线是否为顶部K目标；根据锚点查找模式选择标准算法或严格算法。
bool IsKTargetTop(int i, int total_bars)
{
    if (Find_Target_Model == 2)
    {
        return CheckKTargetTopCondition(i, total_bars, Lookahead_Top, Lookback_Top);
    }

    return CheckKTargetTop_Default(i, total_bars, Lookahead_Top, Lookback_Top);
}

//========================================================================
// CheckKTargetBottom_Default: 检查目标反转阴线 (K-Target Bottom) (无变化)
//========================================================================
/*
   条件: 阴线，且收盘价是左右两侧周期内的最低收盘价。
*/
bool CheckKTargetBottom_Default(int i, int total_bars, int lookahead, int lookback)
{
    // 1. 必须是阴线 (Bearish Candle)
    if (Close[i] >= Open[i]) return false;
    
    // --- 检查右侧 (未来/较新的K线) ---
    for (int k = 1; k <= lookahead; k++)
    {
        int future_index = i - k; 
        // 函数内部的“右侧 20 根检查”允许提前结束，发现右侧索引不足时使用 break；这是牺牲确定性，增加及时性
        // 一切从这里出发，锚点是此指标计算的起点，是核心点，先找到锚点才有后面的开始，锚点是牵一发而动全身，虽然当下不完美
        // 本代码表达的含义是：在当前已经存在的右侧 K 线中，没有发现比锚点更低的收盘价，就暂时认为它是底部
        // 而不是 等待右侧完整走出 20 根 K 线，并确认这 20 根都没有更低收盘价
        // 及时性提高 确定性降低 本质上是提前确认：用当前可见数据推断尚未完成的 20 根窗口。
        // 当前实现选择了“尽可能及时确认”，代价是初期确认结果的不完整和不稳定；它不是等待 20 根后的确定性确认，而是基于当前已有右侧数据的阶段性确认。
        // 另外，future_index=0 还会把当前正在形成的 K 线纳入判断，因此最近的候选锚点甚至会受到未收盘价格影响，及时性更高，但确定性进一步降低
        if (future_index < 0) break; 
        // 必须是最低收盘价
        if (Close[future_index] < Close[i]) return false;
    }
    
    // --- 检查左侧 (历史/较旧的K线) ---
    for (int k = 1; k <= lookback; k++)
    {
        int past_index = i + k; 
        if (past_index >= total_bars) break; 
        // 必须是最低收盘价
        if (Close[past_index] < Close[i]) return false;
    }
    
    return true;
}

//========================================================================
// CheckKTargetTop_Default: 检查目标反转阳线 (K-Target Top) (无变化)
//========================================================================
/*
   条件: 阳线，且收盘价是左右两侧周期内的最高收盘价。
*/
bool CheckKTargetTop_Default(int i, int total_bars, int lookahead, int lookback)
{
    // 1. 必须是阳线 (Bullish Candle)
    if (Close[i] <= Open[i]) return false;
    
    // --- 检查右侧 (未来/较新的K线) ---
    for (int k = 1; k <= lookahead; k++)
    {
        int future_index = i - k; 
        if (future_index < 0) break; 
        // 必须是最高收盘价
        if (Close[future_index] > Close[i]) return false;
    }
    
    // --- 检查左侧 (历史/较旧的K线) ---
    for (int k = 1; k <= lookback; k++)
    {
        int past_index = i + k; 
        if (past_index >= total_bars) break; 
        // 必须是最高收盘价
        if (Close[past_index] > Close[i]) return false;
    }
    
    return true;
}

//========================================================================
// [V2 Upgrade] CheckKTargetBottomCondition
// 功能：查找看涨锚点 (底部被动买单区)
// 核心哲学：必须是阴线(主动卖盘撞击)，且引线创出区域最低点(流动性极限)
// 锚点查找的算法 在一分钟周期和五分钟期开启比较好 属于严格版本
//========================================================================
bool CheckKTargetBottomCondition(int i, int total_bars, int lookahead, int lookback)
{
    // 1. 身份验证 (Identity Check)
    // 必须是阴线。
    // 含义：价格下跌，但这根K线所在的位置是被动买单(Limit Buys)的密集区。
    // 如果是阳线(Hammer)，说明当根K线买方已经反攻，不再是纯粹的"锚点"定义。
    if (Close[i] >= Open[i]) return false;

    // 2. 地位验证 (Geometry Check - V2 Upgrade)
    // 使用 Low (引线) 进行比较，而不是 Close。
    // 含义：我们要找的是被动买单防守的"极限位置"。
    double anchor_low = Low[i];

    // --- 检查右侧 (未来/较新的K线) ---
    for (int k = 1; k <= lookahead; k++)
    {
        int future_index = i - k;
        if (future_index < 0) break;
        
        // 如果右边有K线的 Low 更低(或相等)，说明当前位置不是最低防守点
        if (Low[future_index] <= anchor_low) return false; 
    }
    
    // --- 检查左侧 (历史/较旧的K线) ---
    for (int k = 1; k <= lookback; k++)
    {
        int past_index = i + k;
        if (past_index >= total_bars) break; 
        
        // 如果左边有K线的 Low 更低(或相等)，说明当前位置不是新结构低点
        if (Low[past_index] <= anchor_low) return false;
    }
    
    return true;
}

//========================================================================
// [V2 Upgrade] CheckKTargetTopCondition
// 功能：查找看跌锚点 (顶部被动卖单区)
// 核心哲学：必须是阳线(主动买盘撞击)，且引线创出区域最高点(流动性极限)
//========================================================================
bool CheckKTargetTopCondition(int i, int total_bars, int lookahead, int lookback)
{
    // 1. 身份验证 (Identity Check)
    // 必须是阳线。
    // 含义：价格上涨，撞击上方的被动卖单(Limit Sells)。
    if (Close[i] <= Open[i]) return false;

    // 2. 地位验证 (Geometry Check - V2 Upgrade)
    // 使用 High (引线) 进行比较。
    double anchor_high = High[i];

    // --- 检查右侧 (未来/较新的K线) ---
    for (int k = 1; k <= lookahead; k++)
    {
        int future_index = i - k;
        if (future_index < 0) break; 
        
        // 如果右边有更高的 High，说明这里没挡住，不是有效锚点
        if (High[future_index] >= anchor_high) return false;
    }
    
    // --- 检查左侧 (历史/较旧的K线) ---
    for (int k = 1; k <= lookback; k++)
    {
        int past_index = i + k;
        if (past_index >= total_bars) break; 
        
        // 如果左边有更高的 High，说明这里不是新结构高点
        if (High[past_index] >= anchor_high) return false;
    }
    
    return true;
}
//#endregion

//#region MARK: 关于P1 P2 P3 4 5的查找算法和止损点的查找算法
/**
 * 根据看涨K-target阴线锚点 寻找出收复P1的第一根K线的索引
 * @param target_index: 看涨K-target阴线锚点
 * @param is_bullish: 阳线还是阴线
 * @return ( int ) P1的K线索引。注意P1和P2 可能是同一根K线
 */
int FindFirstP1BreakoutIndex(int target_index, bool is_bullish)
{
    double P1_price = Open[target_index];
    //Print(">[KTarget_Finder4_FromGemini.mq4:771]: P1_price: ", P1_price);

    //向右边寻找 初始索引减去1 然后到最大前瞻
    for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
    {
        if (j < 0) break;

        if (is_bullish)
        {
            // 看涨突破 P1: Close > P1_price
            if (Close[j] > P1_price) return j;
        }
        else
        {
            // 看跌突破 P1: Close < P1_price
            if (Close[j] < P1_price) return j;
        }
    }
    return -1; // 未找到 P1 突破
}

//========================================================================
// FindSecondBaseline: 查找第二基准价格线 (P2)
//========================================================================
/**
   查找 P2 价格：从 K-Target 锚点向左回溯，直到找到第一根符合条件的 K 线。
   看涨 (Bullish): 锚点左侧第一根阳线 (Close > Open) 的收盘价。
   看跌 (Bearish): 锚点左侧第一根阴线 (Close < Open) 的收盘价。
   约束条件 [V1.23 NEW]: P2 价格必须在 P1 价格之外 (看涨 P2 > P1, 看跌 P2 < P1)。

 * 根据看涨K-target阴线锚点，寻找到反向P2的索引，同时P2的价格一定要大于P1的价格（看涨），反之P2<P1(看跌)
 * @param target_index: 看涨K-target阴线锚点
 * @param is_bullish: 看涨或者看跌
 * @return ( int ) P2 反向K线的索引
 */
int FindP2Index(int target_index, bool is_bullish)
{
    double P1_price = Open[target_index];

    // P2 价格 (初始为 0.0)
    double P2_price = 0.0;

    int P2_index = -1;

    // 从锚点 K 线的左侧 (历史 K 线，索引 i+k) 开始回溯
    // 使用外部参数 Scan_Range 作为回溯上限
    for (int k = 1; k <= Scan_Range; k++)
    {
        int past_index = target_index + k;
        
        if (past_index >= Bars) break; // 边界检查
        
        bool condition_met = false;
        double candidate_P2 = 0.0;
        
        if (is_bullish)
        {
            // 看涨 P2: 锚点左侧第一根阳线 (Close > Open) 的收盘价
            if (Close[past_index] > Open[past_index])
            {
                candidate_P2 = Close[past_index];
                // 2. [新增约束] P2 价格必须高于 P1 价格
                if (candidate_P2 > P1_price)
                {
                    P2_price = candidate_P2;
                    P2_index = past_index;
                    condition_met = true;
                }
            }
        }
        else // is_bearish
        {
            // 看跌 P2: 锚点左侧第一根阴线 (Close < Open) 的收盘价
            if (Close[past_index] < Open[past_index])
            {
                candidate_P2 = Close[past_index];
                // 2. [新增约束] P2 价格必须低于 P1 价格
                if (candidate_P2 < P1_price)
                {
                    P2_price = candidate_P2;
                    P2_index = past_index;
                    condition_met = true;
                }
            }
        }

        if (condition_met) 
        {
            break; // 找到即退出
        }
    }

    // 3. 打印差值信息到日志 [V1.25 FIX]：仅在首次调试运行时打印
    // if (Debug_Print_Info_Once && !initial_debug_prints_done)
    // {
    //     Print("FindP2Index Info: P2_price = ", DoubleToString(P2_price, Digits), " points.", " P2_index = ", IntegerToString(P2_index));
    // }
    
    return P2_index; 
}

//========================================================================
// FindSecondBaseline: 查找第二基准价格线 (P2)
// ❌ 此函数暂时没有调用了 缺点是 锚点波幅的 50% 有些死板
//========================================================================
/**
   查找 P2 价格：从 K-Target 锚点向左回溯，直到找到第一根符合条件的 K 线。
   看涨 (Bullish): 锚点左侧第一根阳线 (Close > Open) 的收盘价。
   看跌 (Bearish): 锚点左侧第一根阴线 (Close < Open) 的收盘价。
   约束条件 [V1.23 NEW]: P2 价格必须在 P1 价格之外 (看涨 P2 > P1, 看跌 P2 < P1)。

 * 根据看涨K-target阴线锚点，寻找到反向P2的索引，同时P2的价格一定要大于P1的价格（看涨），反之P2<P1(看跌)
 * @param target_index: 看涨K-target阴线锚点
 * @param is_bullish: 看涨或者看跌
 * @return ( int ) P2 反向K线的索引
 */
/*
int FindP2Index_Limit_BarRange(int target_index, bool is_bullish)
{
    double P1_price = Open[target_index];

    // P2 价格 (初始为 0.0)
    double P2_price = 0.0;

    int P2_index = -1;

    // --- [新增约束 A] 计算锚点 K 线的波幅（用于价格距离约束）---
    double anchor_range = High[target_index] - Low[target_index];
    // P2 必须距离 P1 至少 "锚点波幅的 50%"（黄金比例可调整为 0.618）
    double min_price_distance = anchor_range * 0.5;

    // --- [新增约束 F] 最小 K 线数量约束（确保结构完整性）---
    // P2 必须距离锚点至少 3 根 K 线
    int min_bars_between = 2;

    // 从锚点 K 线的左侧 (历史 K 线，索引 i+k) 开始回溯
    // 🚨 修改起始点：从 k=min_bars_between 开始，而不是 k=1
    // 使用外部参数 Scan_Range 作为回溯上限
    for (int k = min_bars_between; k <= Scan_Range; k++)
    {
        int past_index = target_index + k;
        
        if (past_index >= Bars) break; // 边界检查
        
        bool condition_met = false;
        double candidate_P2 = 0.0;
        
        if (is_bullish)
        {
            // 看涨 P2: 锚点左侧第一根阳线 (Close > Open) 的收盘价
            if (Close[past_index] > Open[past_index])
            {
                candidate_P2 = Close[past_index];
                // 🚨 增强约束：P2 价格必须高于 P1 + 最小距离
                if (candidate_P2 > P1_price + min_price_distance)
                {
                    P2_price = candidate_P2;
                    P2_index = past_index;
                    condition_met = true;
                }
            }
        }
        else // is_bearish
        {
            // 看跌 P2: 锚点左侧第一根阴线 (Close < Open) 的收盘价
            if (Close[past_index] < Open[past_index])
            {
                candidate_P2 = Close[past_index];
                // 🚨 增强约束：P2 价格必须低于 P1 - 最小距离
                if (candidate_P2 < P1_price - min_price_distance)
                {
                    P2_price = candidate_P2;
                    P2_index = past_index;
                    condition_met = true;
                }
            }
        }

        if (condition_met) 
        {
            break; // 找到即退出
        }
    }

    // 3. 打印差值信息到日志 [V1.25 FIX]：仅在首次调试运行时打印
    // if (Debug_Print_Info_Once && !initial_debug_prints_done)
    // {
    //     Print("FindP2Index Info: P2_price = ", DoubleToString(P2_price, Digits), " points.", " P2_index = ", IntegerToString(P2_index));
    // }
    
    return P2_index; 
}
*/

//========================================================================
// FindP2Index_BodyFullySeparated: 查找实体完全与 P1 隔离的 P2 (V3 NEW)
//========================================================================
/**
 * 核心改进：去除 min_price_distance (波幅距离) 的刚性约束，
 * 改为要求 P2 候选K线的"实体"(Open 和 Close) 完全处于 P1 价格线的同一侧。
 *
 * 看涨场景：
 *   - P2 必须是阳线 (Close > Open)
 *   - P2 的 Open 和 Close 都必须 > P1
 *   - 这样确保 P2 实体完全在 P1 上方，与 P1 彻底隔离
 *
 * 看跌场景：
 *   - P2 必须是阴线 (Close < Open)  
 *   - P2 的 Open 和 Close 都必须 < P1
 *   - 这样确保 P2 实体完全在 P1 下方，与 P1 彻底隔离
 *
 * @param target_index: K-target 锚点索引
 * @param is_bullish: 看涨或看跌
 * @return P2 K线索引，未找到返回 -1
 */
int FindP2Index_BodyFullySeparated(int target_index, bool is_bullish)
{
    double P1_price = Open[target_index];
    int P2_index = -1;

    // 保留最小K线间隔约束 (避免过近的噪音K线)
    int min_bars_between = Enhanced_P2_Min_Bars_Between;

    // 从锚点左侧 (历史K线，索引 i+k) 开始回溯
    for (int k = min_bars_between; k <= Scan_Range; k++)
    {
        int past_index = target_index + k;
        if (past_index >= Bars) break; // 边界检查

        if (is_bullish)
        {
            // 看涨 P2：必须是阳线，且实体完全在 P1 上方
            if (Close[past_index] > Open[past_index])
            {
                // 🚨 核心约束：Open 和 Close 都必须大于 P1
                if (Open[past_index] > P1_price && Close[past_index] > P1_price)
                {
                    P2_index = past_index;
                    break; // 找到即退出
                }
            }
        }
        else // is_bearish
        {
            // 看跌 P2：必须是阴线，且实体完全在 P1 下方
            if (Close[past_index] < Open[past_index])
            {
                // 🚨 核心约束：Open 和 Close 都必须小于 P1
                if (Open[past_index] < P1_price && Close[past_index] < P1_price)
                {
                    P2_index = past_index;
                    break; // 找到即退出
                }
            }
        }
    }

    return P2_index;
}

//========================================================================
// FindP2Index_Wrapper: P2 索引查找统一接口 (根据开关选择算法)
//========================================================================
/**
 * 根据 Use_Enhanced_P2_Search 开关选择使用哪个 P2 查找算法
 * - false: 使用标准算法 (FindP2Index) - 只要求 P2 在 P1 之外
 * - true:  使用增强算法 (FindP2Index_Limit_BarRange) - 增加 K 线距离和价格距离约束
 * 
 * @param target_index: K-target 锚点索引
 * @param is_bullish: 看涨或看跌
 * @return P2 K线的索引，未找到返回 -1
 */
int FindP2Index_Wrapper(int target_index, bool is_bullish)
{
    if (Use_Enhanced_P2_Search)
    {
        return FindP2Index_BodyFullySeparated(target_index, is_bullish);
    }
    else
    {
        return FindP2Index(target_index, is_bullish);
    }
}

//========================================================================
// FindNextPLevel: 查找下一个价格级别（通用函数）[V2.0 NEW - Simplified]
//========================================================================
/**
 * 从上一级别继续向左查找下一个价格级别（P3/P4/P5）
 * 逻辑：从 prev_index 向左扫描，找到第一根符合条件的 K 线
 * 
 * @param prev_index 上一级别的索引（P2/P3/P4）
 * @param prev_price 上一级别的价格
 * @param is_bullish 方向（true=看涨，false=看跌）
 * @return 下一级别的索引，未找到返回 -1
 */
int FindNextPLevel(int prev_index, double prev_price, bool is_bullish)
{
    int scan_start = prev_index + 1;  // 从上一级别的下一根 K 线开始
    int scan_end = prev_index + Scan_Range;
    if (scan_end >= Bars) scan_end = Bars - 1;
    
    for (int k = scan_start; k <= scan_end; k++)
    {
        if (k >= Bars) break;
        
        if (is_bullish)
        {
            // 看涨：找阳线且收盘价高于上一级别
            if (Close[k] > Open[k])
            {
                if (Close[k] > prev_price)
                {
                    return k;
                }
            }
        }
        else
        {
            // 看跌：找阴线且收盘价低于上一级别
            if (Close[k] < Open[k])
            {
                if (Close[k] < prev_price)
                {
                    return k;
                }
            }
        }
    }
    
    return -1; // 未找到
}

//========================================================================
// FindNextPLevel_BodySeparated: 查找实体完全隔离的下一个价格级别 (V3 NEW - Strict Mode)
//========================================================================
/**
 * 严格版本：要求候选K线的"实体"(Open 和 Close) 完全处于上级价格的同一侧
 * 
 * 与标准版本的区别：
 * - 标准版本：只要求 Close > prev_price (看涨) 或 Close < prev_price (看跌)
 * - 严格版本：要求 Open 和 Close 都满足条件，实现"实体完全隔离"
 * 
 * 看涨场景：
 *   - 必须是阳线 (Close > Open)
 *   - Open 和 Close 都必须 > prev_price
 *   - 确保 K 线实体完全在上级价格之上
 * 
 * 看跌场景：
 *   - 必须是阴线 (Close < Open)
 *   - Open 和 Close 都必须 < prev_price
 *   - 确保 K 线实体完全在上级价格之下
 * 
 * @param prev_index 上一级别的索引（P2/P3/P4）
 * @param prev_price 上一级别的价格
 * @param is_bullish 方向（true=看涨，false=看跌）
 * @param min_bars_between 最小K线间隔（默认0=不限制，设置为2可过滤过近噪音）
 * @return 下一级别的索引，未找到返回 -1
 */
int FindNextPLevel_BodySeparated(int prev_index, double prev_price, bool is_bullish, int min_bars_between = 0)
{
    // 计算扫描范围：从上级后面的第 (min_bars_between + 1) 根开始
    int scan_start = prev_index + 1 + min_bars_between;
    int scan_end = prev_index + Scan_Range;
    if (scan_end >= Bars) scan_end = Bars - 1;
    
    for (int k = scan_start; k <= scan_end; k++)
    {
        if (k >= Bars) break;
        
        if (is_bullish)
        {
            // 看涨：必须是阳线，且实体完全在上级价格之上
            if (Close[k] > Open[k])
            {
                // 🚨 核心约束：Open 和 Close 都必须大于上级价格
                if (Open[k] > prev_price && Close[k] > prev_price)
                {
                    return k;
                }
            }
        }
        else
        {
            // 看跌：必须是阴线，且实体完全在上级价格之下
            if (Close[k] < Open[k])
            {
                // 🚨 核心约束：Open 和 Close 都必须小于上级价格
                if (Open[k] < prev_price && Close[k] < prev_price)
                {
                    return k;
                }
            }
        }
    }
    
    return -1; // 未找到
}

//========================================================================
// FindNextPLevel_Wrapper: P3/P4/P5 查找包装函数（根据开关选择算法）
//========================================================================
/**
 * 根据 Use_Strict_PLevel_Search 开关选择使用哪个 P-Level 查找算法
 * - false: 使用标准算法 (FindNextPLevel) - 只要求 Close 在上级价格之外
 * - true:  使用严格算法 (FindNextPLevel_BodySeparated) - 要求实体完全隔离
 * 
 * @param prev_index 上一级别的索引
 * @param prev_price 上一级别的价格
 * @param is_bullish 方向
 * @return 下一级别的索引，未找到返回 -1
 */
int FindNextPLevel_Wrapper(int prev_index, double prev_price, bool is_bullish)
{
    if (Use_Strict_PLevel_Search)
    {
        return FindNextPLevel_BodySeparated(prev_index, prev_price, is_bullish, Strict_PLevel_Min_Bars_Between);
    }
    else
    {
        return FindNextPLevel(prev_index, prev_price, is_bullish);
    }
}

//========================================================================
// FindAndDrawMultiplePLevels: 查找并绘制多层价格线（P3/P4/P5）[V2.0 NEW - Simplified]
//========================================================================
/**
 * 协调器函数：循环查找并绘制 P3、P4、P5 价格线
 * 特点：只绘制，不做突破检测和报警
 * 
 * @param anchor_index 锚点索引
 * @param P2_index P2 索引（已知）
 * @param P2_price P2 价格
 * @param is_bullish 方向
 */
void FindAndDrawMultiplePLevels(int anchor_index, int P2_index, double P2_price, bool is_bullish)
{
    if (Is_EA_Mode) return; // EA 模式不绘制
    
    double prev_price = P2_price;
    int prev_index = P2_index;
    
    // 循环查找 P3、P4、P5（最多 3 个级别）
    for (int level = 3; level <= 5; level++)
    {
        // 查找下一级别（根据开关自动选择标准版或严格版）
        int next_index = FindNextPLevel_Wrapper(prev_index, prev_price, is_bullish);
        
        if (next_index == -1) 
        {
            // 未找到更高/更低的级别，停止查找
            break;
        }
        
        double next_price = Close[next_index];
        
        // 绘制该级别的价格线
        DrawPnBaseline(next_index, anchor_index, level, next_price, is_bullish);
        
        // 更新为下一轮的基准
        prev_index = next_index;
        prev_price = next_price;
    }
}

//========================================================================
// FindAbsoluteLowIndex: 查找指定范围内的绝对最低价/最高价K线索引 (V1.35 NEW)
//========================================================================
/**
 * 查找以 target_index 为中心，左右两侧 K 线内的绝对最低价 K 线索引。
 * * @param target_index: K-Target 锚点索引。
 * @param lookback_range: 向左（历史）回溯的 K 线数量 (例如 20)。
 * @param lookahead_range: 向右（较新）前瞻的 K 线数量 (例如 20)。
 * @param is_bullish: 查找最低价 (true) 还是最高价 (false)。
 * @return ( int ) 具有绝对最低/最高价的 K 线索引。
 */
int FindAbsoluteLowIndex(int target_index, int lookback_range, int lookahead_range, bool is_bullish)
{
    // 初始化
    double extreme_price = is_bullish ? Low[target_index] : High[target_index]; // 初始值使用 K-Target 本身的价格
    //Print("-->[KTarget_Finder4_FromGemini.mq4:959]: extreme_price: ", extreme_price);//先测试看涨的是否能 找到最低价格
    int extreme_index = target_index;

    // 1. 向右 (较新 K 线, i-k) 查找
    for (int k = 1; k <= lookahead_range; k++)
    {
        int current_index = target_index - k;
        if (current_index < 0) break;

        if (is_bullish) // 查找绝对最低价 (Lowest Low)
        {
            if (Low[current_index] < extreme_price)
            {
                extreme_price = Low[current_index];
                extreme_index = current_index;
            }
        }
        else // 查找绝对最高价 (Highest High)
        {
            if (High[current_index] > extreme_price)
            {
                extreme_price = High[current_index];
                extreme_index = current_index;
            }
        }
    }

    // 2. 向左 (历史 K 线, i+k) 查找
    for (int k = 1; k <= lookback_range; k++)
    {
        int current_index = target_index + k;
        if (current_index >= Bars) break;

        if (is_bullish) // 查找绝对最低价 (Lowest Low)
        {
            if (Low[current_index] < extreme_price)
            {
                extreme_price = Low[current_index];
                extreme_index = current_index;
            }
        }
        else // 查找绝对最高价 (Highest High)
        {
            if (High[current_index] > extreme_price)
            {
                extreme_price = High[current_index];
                extreme_index = current_index;
            }
        }
    }

    return extreme_index;
}
//#endregion

//#region MARK: 注销未使用的代码模块
/**
 * ✅
 * 看涨阴线锚点的索引是开头，它一旦找到了 就可以找到 P1,接着就能找到P2,接着就能找到 最低价K线索引
 * @param target_index: 看涨阴线锚点的索引
 * @param P2_index: 突破P2的K线的索引
 * @param K_Geo_Index: 突破P1的K线的索引
 * @param N_Geo: 突破P1的K线的数量
 * @param abs_lowindex 最低价K线的索引  可能等于 target_index 锚点索引
 */

/**
void CheckBullishSignalConfirmation_Default(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_lowindex)
{
    // *** 关键修改：在处理新信号之前，清除该锚点上可能存在的任何旧矩形 ***
    // ClearSignalRectangle_v2(abs_lowindex, true);

    // K_Geo_Index 必须有效，否则协调者已经跳过了。
    // P2_price 必须有效，否则协调者已经跳过了。

    // P1 价格，用于判断 P2 是否高于 P1 (安全检查)
    double P1_price = Open[target_index];
    
    double P2_price = Close[P2_index];

    // --- 阶段 A: 信号箭头标记 (瀑布式查找) ---

    // 1. 最高优先级: 查找 P2 突破 (K_P2)
    // P2 价格必须高于 P1 价格，否则 P2 突破不成立
    if (P2_price > P1_price)
    {
        // 查找范围从锚点右侧到 Max_Signal_Lookforward 结束
        for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
        {
            if (j < 0) break;
            // 检查 P2 突破条件：收盘价高于 P2 价格
            if (Close[j] > P2_price) 
            {
                // **绘制 P2 辅助线** (职责：只有在 P2 突破时才绘制 P2 线)
                DrawP2Baseline(P2_index, j, true);

                if (abs_lowindex != -1)
                {
                    // 只有信号成立才绘制矩形
                    DrawP1P2Rectangle(abs_lowindex, j, true);

                    //DrawP1P2Fibonacci(abs_lowindex, j, true); 这里会绘制出所有的 斐波所以我设置了一个开关 所以这里取消就行了
                }

                // 找到 K_P2。绘制 P2 箭头 (高偏移)

                if (Is_EA_Mode)
                {
                    // 🚨 修正：Buffer 0 和 Buffer 2 赋值必须同步且在 j 索引上 🚨
                    if (abs_lowindex != -1)
                    {
                        // 1. 写入 SL 价格 (Buffer 0) 到确认 K 线索引 'j'
                        BullishTargetBuffer[j] = Low[abs_lowindex];
                    }
                    BullishSignalBuffer[j] = 3.0;
                }
                else
                {
                    BullishSignalBuffer[j] = Low[j] - 30 * Point();
                }

                return; // 找到最高级别信号，立即退出函数
            }
        }
    }
    
    // 2. 次优先级: 查找 P1-DB 突破 (K_DB) - 检查第一次 P1 突破是否满足 DB 延迟
    // 如果代码执行到这里，说明整个 N=5 范围内都没有 P2 突破。同时还说明 没有找到P2突破 但是一定有P1突破的索引 一定有P1突破
    
    // 检查第一次 P1 突破是否满足 DB 延迟 (N >= 3)
    if (N_Geo >= DB_Threshold_Candles)
    {
        //**绘制 P2 辅助线** (职责：在 P1-DB 确认时也绘制 P2 线)
        DrawP2Baseline(P2_index, K_Geo_Index, true);

        if (abs_lowindex != -1)
        {
            // 只有信号成立才绘制矩形
            DrawP1P2Rectangle(abs_lowindex, K_Geo_Index, true);
        }

        // 找到 K_DB。绘制 P1-DB 箭头 (标准偏移)
        // 箭头标记在 K_Geo_Index (即第一次 P1 突破的 K 线)
        if (Is_EA_Mode)
        {
            // 🚨 修正：Buffer 0 和 Buffer 2 赋值必须同步且在 K_Geo_Index 索引上 🚨
            if (abs_lowindex != -1)
            {
                // 1. 写入 SL 价格 (Buffer 0) 到确认 K 线索引 K_Geo_Index
                BullishTargetBuffer[K_Geo_Index] = Low[abs_lowindex];
            }
            BullishSignalBuffer[K_Geo_Index] = 2.0;
        }
        else
        {
            BullishSignalBuffer[K_Geo_Index] = Low[K_Geo_Index] - 20 * Point();
        }

        return; // 找到次高级别信号，立即退出函数
    }
    
    // 3. 最终退出: 仅 IB 突破发生 (线已绘制，无箭头) 或 循环耗尽。
    return;
}
*/

/**
void CheckBearishSignalConfirmation_Default(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_hightindex)
{
    // *** 关键修改：在处理新信号之前，清除该锚点上可能存在的任何旧矩形 ***
    // ClearSignalRectangle_v2(abs_hightindex, false);

    double P1_price = Open[target_index];
    double P2_price = Close[P2_index];

    // --- 阶段 B: 信号箭头标记 (瀑布式查找) ---

    // 1. 最高优先级: 查找 P2 突破 (K_P2)
    if (P2_price < P1_price) // 看跌信号 P2 < P1
    {
        // 只需检查到 K_Geo_Index (第一次 P1 突破点) 为止
        for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
        {
            if (j < 0) break;
            if (Close[j] < P2_price) // 🚨 看跌：Close < P2
            {
                // 绘制P2线
                DrawP2Baseline(P2_index, j, false);
                if (abs_hightindex != -1)
                {
                    DrawP1P2Rectangle(abs_hightindex, j, false);
                }

                // 找到 K_P2。绘制 P2 箭头 (高偏移)
                if (Is_EA_Mode)
                {
                    if (abs_hightindex != -1)
                    {
                        BearishTargetBuffer[j] = High[abs_hightindex];
                    }

                    BearishSignalBuffer[j] = 3.0;
                }
                else
                {
                    BearishSignalBuffer[j] = High[j] + 30 * Point();
                }

                return; // 找到最高级别信号，立即退出函数
            }
        }
    }

    // 2. 次优先级: 查找 P1-DB 突破 (K_DB) - 检查第一次 P1 突破是否满足 DB 延迟
    // 如果代码执行到这里，说明整个 N=5 范围内都没有 P2 突破。
    
    // 检查第一次 P1 突破是否满足 DB 延迟 (N >= 3)
    if (N_Geo >= DB_Threshold_Candles)
    {
        // **绘制 P2 辅助线** (职责：在 P1-DB 确认时也绘制 P2 线)
        DrawP2Baseline(P2_index, K_Geo_Index, false);

        if (abs_hightindex != -1)
        {
            DrawP1P2Rectangle(abs_hightindex, K_Geo_Index, false);
        }

        // 找到 K_DB。绘制 P1-DB 箭头 (标准偏移)
        // 箭头标记在 K_Geo_Index (即第一次 P1 突破的 K 线)
        if (Is_EA_Mode)
        {
            if (abs_hightindex != -1)
            {
                BearishTargetBuffer[K_Geo_Index] = High[abs_hightindex];
            }
            BearishSignalBuffer[K_Geo_Index] = 2.0;
        }
        else
        {
            BearishSignalBuffer[K_Geo_Index] = High[K_Geo_Index] + 20 * Point();
        }
        
        return; // 找到次高级别信号，立即退出函数
    }

    // 3. 最终退出: 仅 IB 突破发生 (线已绘制，无箭头) 或 循环耗尽。
    return;
}
*/

/*
//+------------------------------------------------------------------+
//| CheckBullishSignalConfirmationV2 (高级增强版)
//| ------------------------------------------------------------------
//| 变更日志：
//| 1. 引入 Enable_V3_Logic 开关
//| 2. 在信号确认点植入 EvaluateSignal 评分系统
//| 3. 集成 SendRichAlert 和 DrawFiboZones
//+------------------------------------------------------------------+
void CheckBullishSignalConfirmationV2(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_lowindex)
{
    // *** 关键修改：在处理新信号之前，清除该锚点上可能存在的任何旧矩形 ***
    // ClearSignalRectangle_v2(abs_lowindex, true);
    // ***************************************************************

    // 数据准备 (为 V3 内核准备原材料)
    double P1_price = Open[target_index];
    double P2_price = Close[P2_index];
    
    // 安全检查：如果没有找到绝对低点，使用锚点最低价作为止损兜底
    double SL_price = (abs_lowindex != -1) ? Low[abs_lowindex] : Low[target_index]; 

    // --- 阶段 A: 信号箭头标记 (瀑布式查找) ---

    // 1. 最高优先级: 查找 P2 突破 (K_P2)
    if (P2_price > P1_price)
    {
        for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
        {
            if (j < 0) break;
            
            // [确认点] P2 突破
            if (Close[j] > P2_price) 
            {
                // 绘制基础线条 (原逻辑)
                DrawP2Baseline(P2_index, j, true);
                if (abs_lowindex != -1) DrawP1P2Rectangle(abs_lowindex, j, true);

                // =========================================================
                // 🔪 [手术切口 A] P2 强力突破 (CB) - V3 逻辑植入
                // =========================================================
                if (Enable_V3_Logic)
                {
                    // 1. 调用内核评分 (传入 j 作为突破索引)
                    SignalQuality sq = EvaluateSignal(Symbol(), Period(), target_index, j, P1_price, P2_price, SL_price, true);
                    
                    // 2. 执行高级动作 (仅处理非垃圾信号)
                    if (sq.grade >= GRADE_D)
                    {
                         // 打印 & 报警
                         if (sq.grade >= Min_Alert_Grade) 
                             SendRichAlert(Symbol(), Period(), "Bullish(P2-Break)", Close[j], SL_price, sq);
                         
                         // 斐波那契 (仅 Grade A/S)
                         if (sq.grade >= GRADE_A)
                             DrawFiboGradeZones(Symbol(), j, SL_price, Close[j], true, g_object_prefix);
                    }
                }
                // =========================================================

                // 设置 Buffer (原逻辑保持兼容)
                if (Is_EA_Mode)
                {
                    if (abs_lowindex != -1) BullishTargetBuffer[j] = Low[abs_lowindex];
                    BullishSignalBuffer[j] = 3.0; // 3.0 代表 P2 突破
                }
                else
                {
                    BullishSignalBuffer[j] = Low[j] - 30 * Point();
                }

                // 旧版报警 (互斥)
                if (!Enable_V3_Logic && Is_EA_Mode == false) 
                {
                    // 这里可以放原来的简单 Alert...
                }

                return; // 找到最高优信号，退出
            }
        }
    }
    
    // 2. 次优先级: 查找 P1-DB 突破 (K_DB)
    // 如果代码执行到这里，说明没有 P2 突破，但协调者确认有 P1 突破
    
    if (N_Geo >= DB_Threshold_Candles)
    {
        // 绘制基础线条 (原逻辑)
        DrawP2Baseline(P2_index, K_Geo_Index, true);
        if (abs_lowindex != -1) DrawP1P2Rectangle(abs_lowindex, K_Geo_Index, true);

        // =========================================================
        // 🔪 [手术切口 B] P1 结构突破 (DB) - V3 逻辑植入
        // =========================================================
        if (Enable_V3_Logic)
        {
            // 1. 调用内核评分 (传入 K_Geo_Index 作为突破索引)
            // 注意：虽然这里是 DB，但也要评估是否顺便过了 P2 (内核会自动判断)
            SignalQuality sq = EvaluateSignal(Symbol(), Period(), target_index, K_Geo_Index, P1_price, P2_price, SL_price, true);
            
            // 2. 执行高级动作
            if (sq.grade >= GRADE_D)
            {
                 if (sq.grade >= Min_Alert_Grade) 
                     SendRichAlert(Symbol(), Period(), "Bullish(DB-Break)", Close[K_Geo_Index], SL_price, sq);
                 
                 if (sq.grade >= GRADE_A)
                     DrawFiboGradeZones(Symbol(), K_Geo_Index, SL_price, Close[K_Geo_Index], true, g_object_prefix);
            }
        }
        // =========================================================

        // 设置 Buffer (原逻辑保持兼容)
        if (Is_EA_Mode)
        {
            if (abs_lowindex != -1) BullishTargetBuffer[K_Geo_Index] = Low[abs_lowindex];
            BullishSignalBuffer[K_Geo_Index] = 2.0; // 2.0 代表 DB 突破
        }
        else
        {
            BullishSignalBuffer[K_Geo_Index] = Low[K_Geo_Index] - 20 * Point();
        }

        return; // 找到次优信号，退出
    }
    
    return;
}

//+------------------------------------------------------------------+
//| CheckBearishSignalConfirmationV2 (做空方向高级增强版)
//| ------------------------------------------------------------------
//| 核心逻辑：镜像 Bullish 版本，处理 P2 向下突破和 DB 向下突破
//+------------------------------------------------------------------+
void CheckBearishSignalConfirmationV2(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_highindex)
{
    // *** 清除旧矩形 (如有) ***
    // ClearSignalRectangle_v2(abs_highindex, false);
    // ***************************************************************

    // 数据准备
    double P1_price = Open[target_index]; // 锚点开盘价
    double P2_price = Close[P2_index];    // 左侧支撑价 (注意：做空时 P2 是支撑)
    
    // 安全检查：如果没有找到绝对高点，使用锚点最高价作为止损
    double SL_price = (abs_highindex != -1) ? High[abs_highindex] : High[target_index]; 

    // --- 阶段 A: 信号箭头标记 ---

    // 1. 最高优先级: 查找 P2 向下突破 (K_P2)
    // 逻辑：P2(支撑) 必须低于 P1，否则结构不成立 (或者您保留原始逻辑不做此检查)
    // 这里的 if 取决于您原始代码是否要求 P2 < P1。通常做空要求 P2 在下方。
    if (P2_price < P1_price) 
    {
        for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
        {
            if (j < 0) break;
            
            // [确认点] P2 向下突破 (Close < P2)
            if (Close[j] < P2_price) 
            {
                // 绘制基础线条
                DrawP2Baseline(P2_index, j, false); // false 代表 Bearish
                if (abs_highindex != -1) DrawP1P2Rectangle(abs_highindex, j, false);

                // =========================================================
                // 🔪 [手术切口 A] P2 强力突破 (CB) - V3 逻辑植入
                // =========================================================
                if (Enable_V3_Logic)
                {
                    // 1. 调用内核评分 (注意最后参数 false 代表 Bearish)
                    SignalQuality sq = EvaluateSignal(Symbol(), Period(), target_index, j, P1_price, P2_price, SL_price, false);
                    
                    // 2. 执行高级动作
                    if (sq.grade >= GRADE_D)
                    {
                         if (sq.grade >= Min_Alert_Grade) 
                             SendRichAlert(Symbol(), Period(), "Bearish(P2-Break)", Close[j], SL_price, sq);
                         
                         if (sq.grade >= GRADE_A)
                             DrawFiboGradeZones(Symbol(), j, SL_price, Close[j], false, g_object_prefix);
                    }
                }
                // =========================================================

                // 设置 Buffer
                if (Is_EA_Mode)
                {
                    if (abs_highindex != -1) BearishTargetBuffer[j] = High[abs_highindex];
                    BearishSignalBuffer[j] = 3.0; 
                }
                else
                {
                    BearishSignalBuffer[j] = High[j] + 30 * Point(); // 箭头在K线上方
                }

                // 旧版报警 (互斥)
                if (!Enable_V3_Logic && Is_EA_Mode == false) 
                {
                    // Alert("Bearish P2 Break...");
                }

                return; 
            }
        }
    }
    
    // 2. 次优先级: 查找 P1-DB 向下突破 (K_DB)
    if (N_Geo >= DB_Threshold_Candles)
    {
        DrawP2Baseline(P2_index, K_Geo_Index, false);
        if (abs_highindex != -1) DrawP1P2Rectangle(abs_highindex, K_Geo_Index, false);

        // =========================================================
        // 🔪 [手术切口 B] P1 结构突破 (DB) - V3 逻辑植入
        // =========================================================
        if (Enable_V3_Logic)
        {
            // 调用内核评分 (is_bullish = false)
            SignalQuality sq = EvaluateSignal(Symbol(), Period(), target_index, K_Geo_Index, P1_price, P2_price, SL_price, false);
            
            if (sq.grade >= GRADE_D)
            {
                 if (sq.grade >= Min_Alert_Grade) 
                     SendRichAlert(Symbol(), Period(), "Bearish(DB-Break)", Close[K_Geo_Index], SL_price, sq);
                 
                 if (sq.grade >= GRADE_A)
                     DrawFiboGradeZones(Symbol(), K_Geo_Index, SL_price, Close[K_Geo_Index], false, g_object_prefix);
            }
        }
        // =========================================================

        if (Is_EA_Mode)
        {
            if (abs_highindex != -1) BearishTargetBuffer[K_Geo_Index] = High[abs_highindex];
            BearishSignalBuffer[K_Geo_Index] = 2.0; 
        }
        else
        {
            BearishSignalBuffer[K_Geo_Index] = High[K_Geo_Index] + 20 * Point();
        }

        return;
    }
    
    return;
}
*/

//#endregion

//#region MARK: 信号提醒的逻辑三层效果--逻辑上的优化 写好了没有使用
//+------------------------------------------------------------------+
//| 开始在此处写入 逻辑三层的效果
//| ------------------------------------------------------------------
//+------------------------------------------------------------------+
//| K_Logic_Add.mqh                                                  |
//| 报警策略方案二：由发送函数统一负责等级过滤                     |
//|                                                                  |
//| 使用说明：                                                       |
//| 1. 本文件是独立研究版本，不修改 K_Logic.mqh。                    |
//| 2. 当前函数使用 _Add / _Centralized 后缀，避免与旧函数重名。     |
//| 3. 验证无误后，可由用户手动重命名为正式函数名。                   |
//| 4. 本文件假设已在调用前包含 K_Data、Config、K_Drawing 等依赖。    |
//+------------------------------------------------------------------+

// ============================================================================
// 一、统一报警发送函数
// ============================================================================
//
// 三层职责：
// 1. 调用方只负责信号是否处于实时范围，以及是否已被时间锁处理。
// 2. 本函数统一负责 Min_Alert_Grade、EA 模式和富文本开关。
// 3. 本函数返回 true 后，调用方才允许更新时间锁。
//
// 因此，Min_Alert_Grade 不再与发送函数内部的另一个固定等级互相矛盾。
// 例如 Min_Alert_Grade = GRADE_D 时，D 级可以正常发送。
// ============================================================================

bool SendRichAlert_Centralized(
   string sym,
   int period,
   string type,
   double price,
   double sl,
   SignalQuality &sq
)
{
   // 第一层：发送环境过滤。
   if (Is_EA_Mode)
      return false;

   if (!Enable_Rich_Alert)
      return false;

   // 第二层：统一等级过滤。
   // Min_Alert_Grade 是唯一的最低报警等级入口。
   // 这里只拒绝无等级和结构无效信号，不再硬编码拒绝 GRADE_D。
   if (sq.grade < Min_Alert_Grade)
      return false;

   if (sq.grade < GRADE_D)
      return false;

   string per_str = GetTimeframeName(period);

   string msg = StringFormat(
      "%s %s [%s] | %s\n现价: %.5f | SL: %.5f\n因子: %.1f | R:R: %.1f\n",
      sym,
      per_str,
      type,
      sq.description,
      price,
      sl,
      sq.space_factor,
      sq.rr_ratio
   );

   if (sq.grade >= GRADE_A)
   {
      msg += StringFormat(
         ">> 目标: %.5f (Fib 1.618)",
         sq.target_fib_1618
      );
   }

   // Alert() 没有返回值；执行到这里表示本地提醒已提交。
   Alert(msg);

   // 手机推送是附加通道。即使推送失败，本地 Alert 仍然已经发送。
   bool notification_sent = SendNotification(msg);

   if (!notification_sent)
   {
      Print(
         "Rich alert local Alert sent, but SendNotification failed. ",
         "Type: ", type,
         " Grade: ", sq.description
      );
   }

   // 返回 true 表示本地 Alert 已执行，调用方可以更新时间锁。
   return true;
}

// ============================================================================
// 二、报警状态调试输出
// ============================================================================
// 该函数只负责观察，不负责过滤。
// 真正的等级过滤统一由 SendRichAlert_Centralized 完成。
// ============================================================================

void DebugAlertCheck_Add(
   string type,
   int signal_index,
   SignalQuality &sq
)
{
    // 默认关闭调试日志；需要排查报警条件时，恢复下面的调试代码即可。
    return;

    /*
   datetime signal_time = iTime(Symbol(), Period(), signal_index);
   bool is_live_signal = (signal_index <= 1);
   bool is_new_time = (signal_time > g_LastAlertTime);
   bool grade_pass = (sq.grade >= Min_Alert_Grade);

   Print(
      "AlertCheck type=", type,
      " grade=", sq.grade,
      " description=", sq.description,
      " min_grade=", Min_Alert_Grade,
      " grade_pass=", grade_pass,
      " is_live=", is_live_signal,
      " is_new_time=", is_new_time,
      " ea_mode=", Is_EA_Mode,
      " rich_alert=", Enable_Rich_Alert,
      " signal_time=", TimeToString(signal_time),
      " last_alert_time=", TimeToString(g_LastAlertTime)
   );
    */
}

// ============================================================================
// 三、统一的实时报警调用辅助函数
// ============================================================================
// 调用方只需完成：
// 1. 信号已经由 EvaluateSignal() 评分；
// 2. 当前信号是最新两根 K 线之一；
// 3. 信号时间大于全局时间锁。
//
// 等级过滤、发送和时间锁更新在这里形成完整闭环。
// ============================================================================

void TrySendRichAlert_Add(
   string type,
   int signal_index,
   double price,
   double sl,
   SignalQuality &sq
)
{
   datetime signal_time = iTime(Symbol(), Period(), signal_index);
   bool is_live_signal = (signal_index <= 1);
   bool is_new_time = (signal_time > g_LastAlertTime);

   DebugAlertCheck_Add(type, signal_index, sq);

   if (!is_live_signal || !is_new_time)
      return;

   bool alert_sent = SendRichAlert_Centralized(
      Symbol(),
      Period(),
      type,
      price,
      sl,
      sq
   );

   // 只有发送函数确认本地 Alert 已执行，才消耗这根信号的时间锁。
   if (alert_sent)
      g_LastAlertTime = signal_time;
}

// ============================================================================
// 四、做多确认函数重写版
// ============================================================================
// 函数名使用 _Add，避免与当前 K_Logic.mqh 中的正式函数冲突。
// 用户验证后可手动重命名为 CheckBullishSignalConfirmation。
// ============================================================================

void CheckBullishSignalConfirmation_Add(
   int target_index,
   int P2_index,
   int K_Geo_Index,
   int N_Geo,
   int abs_lowindex
)
{
   double P1_price = Open[target_index];
   double P2_price = Close[P2_index];
   double SL_price = (abs_lowindex != -1)
                     ? Low[abs_lowindex]
                     : Low[target_index];

   // -------------------------------------------------------------------------
   // 1. 最高优先级：P2 向上突破，属于 CB 信号
   // -------------------------------------------------------------------------
   if (P2_price > P1_price)
   {
      for (int j = target_index - 1;
           j >= target_index - Max_Signal_Lookforward;
           j--)
      {
         if (j < 0)
            break;

         // 只使用已收盘 K 线；实时报警层仍保留 0/1 判断，历史信号只绘图。
         if (j == 0)
            continue;

         if (Close[j] > P2_price)
         {
            SignalQuality sq;
            sq.grade = GRADE_NONE;

            DrawP2Baseline(P2_index, j, true);

            if (abs_lowindex != -1)
            {
               DrawP1P2Rectangle(abs_lowindex, j, true);
               DrawSignalInfoText(
                  abs_lowindex,
                  j,
                  "CB",
                  SL_price,
                  Close[j],
                  true
               );
            }

            if (Enable_V3_Logic)
            {
               sq = EvaluateSignal(
                  Symbol(),
                  Period(),
                  N_Geo,
                  j,
                  P1_price,
                  P2_price,
                  SL_price,
                  true
               );

               g_Stats.Add(sq.grade);

               if (Test_Print_Detail)
               {
                  Print(
                     "Pass: [BUY] Time:",
                     TimeToString(Time[j]),
                     " Grade:",
                     sq.description
                  );
               }

               if (sq.grade >= GRADE_D)
               {
                  TrySendRichAlert_Add(
                     "Bullish(P2-Break)",
                     j,
                     Close[j],
                     SL_price,
                     sq
                  );

                  bool is_active = CheckSignalStatus(j, SL_price, true);
                  if (sq.grade >= GRADE_A && is_active)
                  {
                     DrawFiboGradeZones(
                        Symbol(),
                        j,
                        SL_price,
                        Close[j],
                        true,
                        g_object_prefix
                     );
                  }
               }
            }

            if (Is_EA_Mode)
            {
               if (abs_lowindex != -1)
                  BullishTargetBuffer[j] = Low[abs_lowindex];

               BullishSignalBuffer[j] = 3.0 + GetGradeWeight(sq.grade);
            }
            else
            {
               BullishSignalBuffer[j] = Low[j] - 30 * Point();
            }

            return;
         }
      }
   }

   // -------------------------------------------------------------------------
   // 2. 次优先级：P1-DB 结构突破
   // -------------------------------------------------------------------------
   if (N_Geo >= DB_Threshold_Candles)
   {
      SignalQuality sq;
      sq.grade = GRADE_NONE;

      DrawP2Baseline(P2_index, K_Geo_Index, true);

      if (abs_lowindex != -1)
      {
         DrawP1P2Rectangle(abs_lowindex, K_Geo_Index, true);
         DrawSignalInfoText(
            abs_lowindex,
            K_Geo_Index,
            "DB",
            SL_price,
            Close[K_Geo_Index],
            true
         );
      }

      if (Enable_V3_Logic)
      {
         sq = EvaluateSignal(
            Symbol(),
            Period(),
            N_Geo,
            K_Geo_Index,
            P1_price,
            P2_price,
            SL_price,
            true
         );

         g_Stats.Add(sq.grade);

         if (Test_Print_Detail)
         {
            Print(
               "Pass: [BUY] Time:",
               TimeToString(Time[K_Geo_Index]),
               " Grade:",
               sq.description
            );
         }

         if (sq.grade >= GRADE_D)
         {
            TrySendRichAlert_Add(
               "Bullish(DB-Break)",
               K_Geo_Index,
               Close[K_Geo_Index],
               SL_price,
               sq
            );

            bool is_active = CheckSignalStatus(K_Geo_Index, SL_price, true);
            if (sq.grade >= GRADE_A && is_active)
            {
               DrawFiboGradeZones(
                  Symbol(),
                  K_Geo_Index,
                  SL_price,
                  Close[K_Geo_Index],
                  true,
                  g_object_prefix
               );
            }
         }
      }

      if (Is_EA_Mode)
      {
         if (abs_lowindex != -1)
            BullishTargetBuffer[K_Geo_Index] = Low[abs_lowindex];

         BullishSignalBuffer[K_Geo_Index] = 2.0 + GetGradeWeight(sq.grade);
      }
      else
      {
         BullishSignalBuffer[K_Geo_Index] = Low[K_Geo_Index] - 20 * Point();
      }

      return;
   }

   // -------------------------------------------------------------------------
   // 3. 最低优先级：IB 独立标记
   // -------------------------------------------------------------------------
   if (Enable_IB_Signal_Marking)
   {
      SignalQuality sq;
      sq.grade = GRADE_NONE;

      double ib_base = (N_Geo == 1) ? 1.0 : 1.5;
      string ib_type = (N_Geo == 1) ? "IB1" : "IB2";

      DrawP2Baseline(P2_index, K_Geo_Index, true);

      if (abs_lowindex != -1)
      {
         DrawP1P2Rectangle(abs_lowindex, K_Geo_Index, true);
         DrawSignalInfoText(
            abs_lowindex,
            K_Geo_Index,
            ib_type,
            SL_price,
            Close[K_Geo_Index],
            true
         );
      }

      if (Enable_V3_Logic)
      {
         sq = EvaluateSignal(
            Symbol(),
            Period(),
            N_Geo,
            K_Geo_Index,
            P1_price,
            P2_price,
            SL_price,
            true
         );

         g_Stats.Add(sq.grade);

         if (Test_Print_Detail)
         {
            Print(
               "Pass: [BUY-",
               ib_type,
               "] Time:",
               TimeToString(Time[K_Geo_Index]),
               " Grade:",
               sq.description
            );
         }

         if (sq.grade >= GRADE_D)
         {
            TrySendRichAlert_Add(
               "Bullish(" + ib_type + ")",
               K_Geo_Index,
               Close[K_Geo_Index],
               SL_price,
               sq
            );

            bool is_active = CheckSignalStatus(K_Geo_Index, SL_price, true);
            if (sq.grade >= GRADE_A && is_active)
            {
               DrawFiboGradeZones(
                  Symbol(),
                  K_Geo_Index,
                  SL_price,
                  Close[K_Geo_Index],
                  true,
                  g_object_prefix
               );
            }
         }
      }

      if (Is_EA_Mode)
      {
         if (abs_lowindex != -1)
            BullishTargetBuffer[K_Geo_Index] = Low[abs_lowindex];

         BullishSignalBuffer[K_Geo_Index] = ib_base + GetGradeWeight(sq.grade);
      }
      else
      {
         BullishSignalBuffer[K_Geo_Index] = Low[K_Geo_Index] - 10 * Point();
      }

      return;
   }
}

// ============================================================================
// 五、做空确认函数重写版
// ============================================================================
// 用户验证后可手动重命名为 CheckBearishSignalConfirmation。
// ============================================================================

void CheckBearishSignalConfirmation_Add(
   int target_index,
   int P2_index,
   int K_Geo_Index,
   int N_Geo,
   int abs_highindex
)
{
   double P1_price = Open[target_index];
   double P2_price = Close[P2_index];
   double SL_price = (abs_highindex != -1)
                     ? High[abs_highindex]
                     : High[target_index];

   // -------------------------------------------------------------------------
   // 1. 最高优先级：P2 向下突破，属于 CB 信号
   // -------------------------------------------------------------------------
   if (P2_price < P1_price)
   {
      for (int j = target_index - 1;
           j >= target_index - Max_Signal_Lookforward;
           j--)
      {
         if (j < 0)
            break;

         if (j == 0)
            continue;

         if (Close[j] < P2_price)
         {
            SignalQuality sq;
            sq.grade = GRADE_NONE;

            DrawP2Baseline(P2_index, j, false);

            if (abs_highindex != -1)
            {
               DrawP1P2Rectangle(abs_highindex, j, false);
               DrawSignalInfoText(
                  abs_highindex,
                  j,
                  "CB",
                  SL_price,
                  Close[j],
                  false
               );
            }

            if (Enable_V3_Logic)
            {
               sq = EvaluateSignal(
                  Symbol(),
                  Period(),
                  N_Geo,
                  j,
                  P1_price,
                  P2_price,
                  SL_price,
                  false
               );

               g_Stats.Add(sq.grade);

               if (Test_Print_Detail)
               {
                  Print(
                     "Pass: [SELL] Time:",
                     TimeToString(Time[j]),
                     " Grade:",
                     sq.description
                  );
               }

               if (sq.grade >= GRADE_D)
               {
                  TrySendRichAlert_Add(
                     "Bearish(P2-Break)",
                     j,
                     Close[j],
                     SL_price,
                     sq
                  );

                  bool is_active = CheckSignalStatus(j, SL_price, false);
                  if (sq.grade >= GRADE_A && is_active)
                  {
                     DrawFiboGradeZones(
                        Symbol(),
                        j,
                        SL_price,
                        Close[j],
                        false,
                        g_object_prefix
                     );
                  }
               }
            }

            if (Is_EA_Mode)
            {
               if (abs_highindex != -1)
                  BearishTargetBuffer[j] = High[abs_highindex];

               BearishSignalBuffer[j] = 3.0 + GetGradeWeight(sq.grade);
            }
            else
            {
               BearishSignalBuffer[j] = High[j] + 30 * Point();
            }

            return;
         }
      }
   }

   // -------------------------------------------------------------------------
   // 2. 次优先级：P1-DB 结构突破
   // -------------------------------------------------------------------------
   if (N_Geo >= DB_Threshold_Candles)
   {
      SignalQuality sq;
      sq.grade = GRADE_NONE;

      DrawP2Baseline(P2_index, K_Geo_Index, false);

      if (abs_highindex != -1)
      {
         DrawP1P2Rectangle(abs_highindex, K_Geo_Index, false);
         DrawSignalInfoText(
            abs_highindex,
            K_Geo_Index,
            "DB",
            SL_price,
            Close[K_Geo_Index],
            false
         );
      }

      if (Enable_V3_Logic)
      {
         sq = EvaluateSignal(
            Symbol(),
            Period(),
            N_Geo,
            K_Geo_Index,
            P1_price,
            P2_price,
            SL_price,
            false
         );

         g_Stats.Add(sq.grade);

         if (Test_Print_Detail)
         {
            Print(
               "Pass: [SELL] Time:",
               TimeToString(Time[K_Geo_Index]),
               " Grade:",
               sq.description
            );
         }

         if (sq.grade >= GRADE_D)
         {
            TrySendRichAlert_Add(
               "Bearish(DB-Break)",
               K_Geo_Index,
               Close[K_Geo_Index],
               SL_price,
               sq
            );

            bool is_active = CheckSignalStatus(K_Geo_Index, SL_price, false);
            if (sq.grade >= GRADE_A && is_active)
            {
               DrawFiboGradeZones(
                  Symbol(),
                  K_Geo_Index,
                  SL_price,
                  Close[K_Geo_Index],
                  false,
                  g_object_prefix
               );
            }
         }
      }

      if (Is_EA_Mode)
      {
         if (abs_highindex != -1)
            BearishTargetBuffer[K_Geo_Index] = High[abs_highindex];

         BearishSignalBuffer[K_Geo_Index] = 2.0 + GetGradeWeight(sq.grade);
      }
      else
      {
         BearishSignalBuffer[K_Geo_Index] = High[K_Geo_Index] + 20 * Point();
      }

      return;
   }

   // -------------------------------------------------------------------------
   // 3. 最低优先级：IB 独立标记
   // -------------------------------------------------------------------------
   if (Enable_IB_Signal_Marking)
   {
      SignalQuality sq;
      sq.grade = GRADE_NONE;

      double ib_base = (N_Geo == 1) ? 1.0 : 1.5;
      string ib_type = (N_Geo == 1) ? "IB1" : "IB2";

      DrawP2Baseline(P2_index, K_Geo_Index, false);

      if (abs_highindex != -1)
      {
         DrawP1P2Rectangle(abs_highindex, K_Geo_Index, false);
         DrawSignalInfoText(
            abs_highindex,
            K_Geo_Index,
            ib_type,
            SL_price,
            Close[K_Geo_Index],
            false
         );
      }

      if (Enable_V3_Logic)
      {
         sq = EvaluateSignal(
            Symbol(),
            Period(),
            N_Geo,
            K_Geo_Index,
            P1_price,
            P2_price,
            SL_price,
            false
         );

         g_Stats.Add(sq.grade);

         if (Test_Print_Detail)
         {
            Print(
               "Pass: [SELL-",
               ib_type,
               "] Time:",
               TimeToString(Time[K_Geo_Index]),
               " Grade:",
               sq.description
            );
         }

         if (sq.grade >= GRADE_D)
         {
            TrySendRichAlert_Add(
               "Bearish(" + ib_type + ")",
               K_Geo_Index,
               Close[K_Geo_Index],
               SL_price,
               sq
            );

            bool is_active = CheckSignalStatus(K_Geo_Index, SL_price, false);
            if (sq.grade >= GRADE_A && is_active)
            {
               DrawFiboGradeZones(
                  Symbol(),
                  K_Geo_Index,
                  SL_price,
                  Close[K_Geo_Index],
                  false,
                  g_object_prefix
               );
            }
         }
      }

      if (Is_EA_Mode)
      {
         if (abs_highindex != -1)
            BearishTargetBuffer[K_Geo_Index] = High[abs_highindex];

         BearishSignalBuffer[K_Geo_Index] = ib_base + GetGradeWeight(sq.grade);
      }
      else
      {
         BearishSignalBuffer[K_Geo_Index] = High[K_Geo_Index] + 10 * Point();
      }

      return;
   }
}

//+------------------------------------------------------------------+
//| CheckBullishSignalConfirmation_Add /                             |
//| CheckBearishSignalConfirmation_Add 逻辑对照说明                 |
//|                                                                  |
//| 本文件严格只包含中文注释，不包含可执行代码。                     |
//| 用途：记录新旧确认函数的逻辑等价性、差异和替换前检查事项。        |
//+------------------------------------------------------------------+

/*
一、结论先行

CheckBullishSignalConfirmation_Add 与原来的
CheckBullishSignalConfirmation：

CheckBearishSignalConfirmation_Add 与原来的
CheckBearishSignalConfirmation：

不能简单表述为“逐行完全一样”。更准确的结论是：

1. 信号识别主体逻辑基本等价。
2. 做多和做空的信号优先级保持一致。
3. 评分、绘图和 Buffer 处理保持一致。
4. 报警部分按照方案二进行了有意重构，因此调用层的代码形态不同。
5. 新版本把等级过滤集中到 SendRichAlert_Centralized()，把实时性和时间锁集中到
   TrySendRichAlert_Add()，这是职责调整，不是信号识别规则改变。

======================================================================
二、做多函数的逻辑对照
======================================================================

原函数和新增函数都遵循下面的优先级：

第一优先级：P2 向上突破，识别为 CB
--------------------------------------------------
原函数条件：

    P2_price > P1_price

随后从：

    target_index - 1

向更旧的 K 线搜索，遇到：

    Close[j] > P2_price

即确认 P2 向上突破。

新增函数仍然使用同样的条件和同样的搜索区间，并且保留：

    if (j == 0) continue;

因此，当前正在形成的 0 号 K 线不会被当作已确认突破使用。这一点与当前原函数一致。

确认后，两者都执行：

1. DrawP2Baseline(P2_index, j, true)
2. 在存在绝对低点时绘制 DrawP1P2Rectangle()
3. 绘制 CB 类型的 DrawSignalInfoText()
4. Enable_V3_Logic 开启时调用 EvaluateSignal()
5. 调用 g_Stats.Add(sq.grade)
6. Grade A 以上且信号仍有效时绘制 DrawFiboGradeZones()
7. 设置 BullishTargetBuffer 和 BullishSignalBuffer
8. 找到最高优先级信号后 return

因此，CB 做多信号的识别和后续可视化主流程是等价的。

第二优先级：P1-DB 结构突破
--------------------------------------------------
原函数和新增函数都使用：

    N_Geo >= DB_Threshold_Candles

两者都以 K_Geo_Index 作为确认索引，并执行：

1. 绘制 P2 基线
2. 绘制 P1-P2 矩形
3. 绘制 DB 信息文本
4. Enable_V3_Logic 开启时调用 EvaluateSignal()
5. 更新 g_Stats
6. Grade A 以上且有效时绘制斐波那契区域
7. 设置 DB 对应的 Buffer
8. return

因此，DB 做多信号的识别逻辑和绘图、Buffer 逻辑也是等价的。

第三优先级：IB 独立标记
--------------------------------------------------
两者都受：

    Enable_IB_Signal_Marking

控制，并且都使用：

    N_Geo == 1 ? "IB1" : "IB2"

两者都执行：

1. 绘制 P2 基线
2. 绘制 P1-P2 矩形
3. 绘制 IB1/IB2 信息文本
4. 调用 EvaluateSignal()
5. 更新 g_Stats
6. Grade A 以上且有效时绘制斐波那契区域
7. 使用 ib_base 设置 IB Buffer
8. return

因此，IB 做多信号的识别逻辑保持一致。

======================================================================
三、做空函数的逻辑对照
======================================================================

做空函数是做多函数的镜像版本。

第一优先级：P2 向下突破，识别为 CB
--------------------------------------------------
两者都使用：

    P2_price < P1_price

并从：

    target_index - 1

开始搜索，确认条件为：

    Close[j] < P2_price

两者都跳过 0 号 K 线，并且都执行：

1. DrawP2Baseline(P2_index, j, false)
2. 绘制做空方向的 P1-P2 矩形
3. 绘制 CB 信息文本
4. 调用 EvaluateSignal(..., false)
5. 更新做空统计
6. Grade A 以上且有效时绘制做空斐波那契区域
7. 设置 BearishTargetBuffer 和 BearishSignalBuffer
8. return

第二优先级：P1-DB 向下突破
--------------------------------------------------
两者都使用：

    N_Geo >= DB_Threshold_Candles

并使用 K_Geo_Index 作为 DB 确认索引。绘图、评分、统计、斐波那契和 Buffer 处理方向一致。

第三优先级：IB1/IB2 做空标记
--------------------------------------------------
两者都受：

    Enable_IB_Signal_Marking

控制，并根据 N_Geo 选择 IB1 或 IB2。做空方向的绘图、评分、统计、斐波那契和 Buffer 处理一致。

======================================================================
四、真正发生变化的部分：报警责任划分
======================================================================

原函数的报警流程大致是：

    if (sq.grade >= GRADE_D)
    {
        bool is_live_signal = ...;
        bool is_new_time = ...;

        if (sq.grade >= Min_Alert_Grade &&
            is_live_signal &&
            is_new_time)
        {
            SendRichAlert(...);
            g_LastAlertTime = signal_time;
        }
    }

新增函数的报警流程是：

    if (sq.grade >= GRADE_D)
    {
        TrySendRichAlert_Add(...);
    }

然后由 TrySendRichAlert_Add() 负责：

1. 判断 signal_index <= 1。
2. 判断 signal_time > g_LastAlertTime。
3. 调用 SendRichAlert_Centralized()。
4. 只有返回 true 才更新 g_LastAlertTime。

SendRichAlert_Centralized() 负责：

1. Is_EA_Mode 过滤。
2. Enable_Rich_Alert 过滤。
3. Min_Alert_Grade 过滤。
4. GRADE_D、GRADE_NONE、GRADE_F 的最终有效性过滤。
5. 生成消息。
6. 执行 Alert() 和 SendNotification()。
7. 返回 bool。

这部分不是逐行等价，而是方案二要求的架构变化。

======================================================================
五、报警行为何时与原逻辑等价
======================================================================

在下面条件下，新旧报警结果应当等价：

1. 原函数调用的是当前允许 D 级的 SendRichAlert 版本。
2. Min_Alert_Grade 的值相同。
3. Enable_Rich_Alert 的值相同。
4. Is_EA_Mode 的值相同。
5. g_LastAlertTime 的初始值和更新时间一致。
6. signal_index、sq.grade 和 sq.description 相同。

此时：

    原函数在调用方过滤等级

新增函数在 SendRichAlert_Centralized() 内过滤等级

两者对于“是否具备报警资格”的判断结果应一致。

======================================================================
六、报警行为何时会不同
======================================================================

以下情况属于有意变化：

1. Min_Alert_Grade 低于 GRADE_D 时，新函数仍然拒绝无效等级。
   这是为了避免 GRADE_NONE 或 GRADE_F 进入报警。

2. SendRichAlert_Centralized() 返回 false 时，不更新时间锁。
   原有部分代码曾经存在“函数没有真正发送，但时间锁已经更新”的风险。

3. SendNotification() 失败时，SendRichAlert_Centralized() 仍返回 true，
   因为本地 Alert() 已经执行。此时更新时间锁是合理的，避免同一信号反复弹窗。

4. 新版本通过 TrySendRichAlert_Add() 统一实时性和时间锁，
   因而不再由六个多空调用点分别维护同一套判断代码。

======================================================================
七、替换前必须核对的项目
======================================================================

用户将函数重命名并替换旧函数前，建议检查以下项目：

1. K_Logic_Add.mqh 是否已经被主指标包含。
2. 新函数所依赖的 SignalQuality、枚举和全局变量是否已经定义。
3. EvaluateSignal() 是否只保留一个有效定义。
4. SendRichAlert_Centralized() 重命名为 SendRichAlert 后，
   是否会与旧 SendRichAlert() 形成重复定义。
5. CheckBullishSignalConfirmation_Add() 重命名后，
   是否会与旧 CheckBullishSignalConfirmation() 形成重复定义。
6. CheckBearishSignalConfirmation_Add() 重命名后，
   是否会与旧 CheckBearishSignalConfirmation() 形成重复定义。
7. 主调用方是否已经改为使用新的确认函数，或者是否采用正式函数名替换。
8. 当前循环中的 j == 0 跳过规则是否仍符合实盘需求。
9. 如果需要允许 0 号 K 线报警，应单独修改实时确认策略，不能只改函数名。

======================================================================
八、最终判断
======================================================================

可以认为：

    CheckBullishSignalConfirmation_Add
    CheckBearishSignalConfirmation_Add

与原确认函数的“信号识别主逻辑”一致，包括：

    P2/CB -> DB -> IB 的优先级
    多空方向判断
    K 线搜索范围
    EvaluateSignal() 参数
    绘图对象
    统计更新
    Buffer 编码

但不能说它们的“全部运行行为”完全一致，因为新版本刻意改变了报警架构：

    等级过滤集中到发送函数
    实时性和时间锁集中到辅助函数
    发送结果决定是否更新时间锁

因此，准确表述应为：

    信号识别逻辑基本等价；报警责任和失败处理逻辑经过重构。

这正是方案二希望达到的结果：

    每一层职责清楚，
    Min_Alert_Grade 只有一个等级过滤入口，
    发送失败不会错误消耗时间锁，
    多空、P2、DB、IB 使用同一套报警规则。
*/

//+------------------------------------------------------------------+
//| 结束在此处写入 逻辑三层的效果
//| ------------------------------------------------------------------
//#endregion

//#region MARK: 信号确认和提醒模块
//+------------------------------------------------------------------+
//| CheckBullishSignalConfirmationV3 (做多方向最终完整版)
//| ------------------------------------------------------------------
//| 包含功能：
//| 1. v3 评分系统 (EvaluateSignal)
//| 2. 斐波那契自动绘图 (DrawFiboGradeZones)
//| 3. 智能战报 (SendRichAlert)
//| 4. [新增] 历史信号过滤 (j <= 1)
//| 5. [新增] 防重复报警时间锁 (g_LastAlertTime)
//+------------------------------------------------------------------+
void CheckBullishSignalConfirmation(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_lowindex)
{
    // *** 数据准备 ***
    double P1_price = Open[target_index];
    double P2_price = Close[P2_index];
    
    // 安全检查：如果没有找到绝对低点，使用锚点最低价作为止损兜底
    double SL_price = (abs_lowindex != -1) ? Low[abs_lowindex] : Low[target_index]; 

    // --- 阶段 A: 信号箭头标记 (瀑布式查找) ---

    // 1. 最高优先级: 查找 P2 突破 (K_P2)
    if (P2_price > P1_price)
    {
        for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
        {
            if (j < 0) break;
            // >>>>>>>>> 【新增补丁】 <<<<<<<<<
            // 强制跳过当前正在跳动的 K 线 (Index 0)，只看已收盘的 (Index >= 1)
            if (j == 0) continue;
            // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

            // [确认点] P2 突破
            if (Close[j] > P2_price)
            {
                // [修复 1] 在 if (Enable_V3_Logic) 之前声明变量，提升作用域
                SignalQuality sq;
                sq.grade = GRADE_NONE; // 默认初始化

                // 绘制基础线条
                DrawP2Baseline(P2_index, j, true);

                if (abs_lowindex != -1)
                {
                    DrawP1P2Rectangle(abs_lowindex, j, true);
                    // 参数: 锚点索引, 信号索引, 类型字符串, 止损价, 确认收盘价, 方向
                    DrawSignalInfoText(abs_lowindex, j, "CB", SL_price, Close[j], true);
                }

                // =========================================================
                // 🔪 [手术切口 A] P2 强力突破 (CB) - V3 逻辑植入
                // =========================================================
                if (Enable_V3_Logic)
                {
                    // 1. 调用内核评分
                    sq = EvaluateSignal(Symbol(), Period(), N_Geo, j, P1_price, P2_price, SL_price, true);
                    g_Stats.Add(sq.grade);
                    // [日志] 做多详情
                    if (Test_Print_Detail)
                    {
                        Print("Pass: [BUY] Time:", TimeToString(Time[j]), " Grade:", sq.description);
                    }

                    // 2. 执行高级动作
                    if (sq.grade >= GRADE_D)
                    {
                         // -----------------------------------------------------------
                         // 🛡️ [报警过滤器] 核心风控逻辑
                         // -----------------------------------------------------------
                         // 规则1：只在最新K线(0)或刚收盘K线(1)触发，过滤历史
                         bool is_live_signal = (j <= 1); 
                         // 规则2：时间戳必须大于上一次报警时间，防止单根K线重复报
                         bool is_new_time    = (iTime(Symbol(), Period(), j) > g_LastAlertTime);

                         DebugAlertCheck("Bullish(P2-Break)", j, sq);
                         
                         if (sq.grade >= Min_Alert_Grade && is_live_signal && is_new_time) 
                         {
                             // 发送战报
                             bool alert_sent = SendRichAlert(Symbol(), Period(), "Bullish(P2-Break)", Close[j], SL_price, sq);

                             // 仅在提醒函数实际执行发送后更新时间锁
                             if (alert_sent)
                                 g_LastAlertTime = iTime(Symbol(), Period(), j);
                         }

                         // ---------------------------------------------------
                         // 🎨 [绘图控制] 智能斐波那契
                         // ---------------------------------------------------
                         // 1. 检查信号生存状态
                         bool is_active = CheckSignalStatus(j, SL_price, true); // true=做多

                         // 斐波那契绘图 (无需过滤历史，历史也要画)
                         // 传入 true (做多) 和 全局前缀
                         if (sq.grade >= GRADE_A && is_active)
                         {
                             DrawFiboGradeZones(Symbol(), j, SL_price, Close[j], true, g_object_prefix);
                         }
                    }
                }
                // =========================================================

                // 设置 Buffer
                if (Is_EA_Mode)
                {
                    if (abs_lowindex != -1) BullishTargetBuffer[j] = Low[abs_lowindex];
                    // BullishSignalBuffer[j] = 3.0; // 3.0 = P2 Break
                    // 核心修改：计算编码值
                    double grade_val = GetGradeWeight(sq.grade);
                    BullishSignalBuffer[j] = 3.0 + grade_val; // 例如 3.4
                }
                else
                {
                    BullishSignalBuffer[j] = Low[j] - 30 * Point();
                }

                // 旧版报警 (互斥)
                // if (!Enable_V3_Logic && Is_EA_Mode == false) 
                // {
                //     // Alert("Old Signal...");
                // }

                return; 
            }
        }
    }
    
    // 2. 次优先级: 查找 P1-DB 突破 (K_DB)
    if (N_Geo >= DB_Threshold_Candles)
    {
        SignalQuality sq;
        sq.grade = GRADE_NONE;

        DrawP2Baseline(P2_index, K_Geo_Index, true);

        if (abs_lowindex != -1)
        {
            DrawP1P2Rectangle(abs_lowindex, K_Geo_Index, true);
            DrawSignalInfoText(abs_lowindex, K_Geo_Index, "DB", SL_price, Close[K_Geo_Index], true);
        }

        // =========================================================
        // 🔪 [手术切口 B] P1 结构突破 (DB) - V3 逻辑植入
        // =========================================================
        if (Enable_V3_Logic)
        {
            // 1. 调用内核评分 (传入 K_Geo_Index)
            sq = EvaluateSignal(Symbol(), Period(), N_Geo, K_Geo_Index, P1_price, P2_price, SL_price, true);
            g_Stats.Add(sq.grade);
            // [日志] 做多详情
            if (Test_Print_Detail)
            {
                Print("Pass: [BUY] Time:", TimeToString(Time[K_Geo_Index]), " Grade:", sq.description);
            }

            // 2. 执行高级动作
            if (sq.grade >= GRADE_D)
            {
                 // 🛡️ [报警过滤器]
                 bool is_live_signal = (K_Geo_Index <= 1); 
                 bool is_new_time    = (iTime(Symbol(), Period(), K_Geo_Index) > g_LastAlertTime);

                 DebugAlertCheck("Bullish(DB-Break)", K_Geo_Index, sq);

                 if (sq.grade >= Min_Alert_Grade && is_live_signal && is_new_time) 
                 {
                     bool alert_sent = SendRichAlert(Symbol(), Period(), "Bullish(DB-Break)", Close[K_Geo_Index], SL_price, sq);
                     if (alert_sent)
                         g_LastAlertTime = iTime(Symbol(), Period(), K_Geo_Index);
                 }

                 bool is_active = CheckSignalStatus(K_Geo_Index, SL_price, true); // true=做多
                 // 斐波那契绘图
                 if (sq.grade >= GRADE_A && is_active)
                 {
                     DrawFiboGradeZones(Symbol(), K_Geo_Index, SL_price, Close[K_Geo_Index], true, g_object_prefix);
                 }
            }
        }
        // =========================================================

        if (Is_EA_Mode)
        {
            if (abs_lowindex != -1) BullishTargetBuffer[K_Geo_Index] = Low[abs_lowindex];
            // BullishSignalBuffer[K_Geo_Index] = 2.0; // 2.0 = DB Break
            double grade_val = GetGradeWeight(sq.grade);
            BullishSignalBuffer[K_Geo_Index] = 2.0 + grade_val;
        }
        else
        {
            BullishSignalBuffer[K_Geo_Index] = Low[K_Geo_Index] - 20 * Point();
        }

        return;
    }

    // 3. 最低优先级: IB 独立信号标记 (仅突破P1，未达DB延迟，未过P2)
    if (Enable_IB_Signal_Marking)
    {
        SignalQuality sq;
        sq.grade = GRADE_NONE;

        // N_Geo>=2 一律并入 1.5 档，不区分具体根数
        double ib_base = (N_Geo == 1) ? 1.0 : 1.5;
        string ib_type = (N_Geo == 1) ? "IB1" : "IB2";

        DrawP2Baseline(P2_index, K_Geo_Index, true);

        if (abs_lowindex != -1)
        {
            DrawP1P2Rectangle(abs_lowindex, K_Geo_Index, true);
            DrawSignalInfoText(abs_lowindex, K_Geo_Index, ib_type, SL_price, Close[K_Geo_Index], true);
        }

        if (Enable_V3_Logic)
        {
            sq = EvaluateSignal(Symbol(), Period(), N_Geo, K_Geo_Index, P1_price, P2_price, SL_price, true);
            g_Stats.Add(sq.grade);
            if (Test_Print_Detail)
            {
                Print("Pass: [BUY-", ib_type, "] Time:", TimeToString(Time[K_Geo_Index]), " Grade:", sq.description);
            }

            // 与 DB/CB 完全相同的判断代码；grade 上限为 GRADE_C，故默认 Min_Alert_Grade/GRADE_A 门槛下不会触发
            // 若测试后需要IB专属报警门槛，可在此处引入独立阈值参数替换 Min_Alert_Grade
            if (sq.grade >= GRADE_D)
            {
                 bool is_live_signal = (K_Geo_Index <= 1);
                 bool is_new_time    = (iTime(Symbol(), Period(), K_Geo_Index) > g_LastAlertTime);

                 DebugAlertCheck("Bullish(" + ib_type + ")", K_Geo_Index, sq);

                 if (sq.grade >= Min_Alert_Grade && is_live_signal && is_new_time)
                 {
                     bool alert_sent = SendRichAlert(Symbol(), Period(), "Bullish(" + ib_type + ")", Close[K_Geo_Index], SL_price, sq);
                     if (alert_sent)
                         g_LastAlertTime = iTime(Symbol(), Period(), K_Geo_Index);
                 }

                 bool is_active = CheckSignalStatus(K_Geo_Index, SL_price, true);
                 if (sq.grade >= GRADE_A && is_active)
                 {
                     DrawFiboGradeZones(Symbol(), K_Geo_Index, SL_price, Close[K_Geo_Index], true, g_object_prefix);
                 }
            }
        }

        if (Is_EA_Mode)
        {
            if (abs_lowindex != -1) BullishTargetBuffer[K_Geo_Index] = Low[abs_lowindex];
            double grade_val = GetGradeWeight(sq.grade);
            BullishSignalBuffer[K_Geo_Index] = ib_base + grade_val;
        }
        else
        {
            BullishSignalBuffer[K_Geo_Index] = Low[K_Geo_Index] - 10 * Point();
        }

        return;
    }
    
    return;
}

//+------------------------------------------------------------------+
//| CheckBearishSignalConfirmationV3 (做空方向高级增强版)
//| ------------------------------------------------------------------
//| 核心逻辑：镜像 Bullish 版本，处理 P2 向下突破和 DB 向下突破
//| 集成了 v3 评分系统、斐波那契投影、以及历史报警过滤器
//+------------------------------------------------------------------+
void CheckBearishSignalConfirmation(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_highindex)
{
    // *** 1. 数据准备 (Data Prep) ***
    double P1_price = Open[target_index]; // 锚点开盘价
    double P2_price = Close[P2_index];    // 左侧支撑价 (做空时 P2 应为支撑)
    
    // 安全检查：如果没有找到绝对高点，使用锚点最高价作为止损兜底
    double SL_price = (abs_highindex != -1) ? High[abs_highindex] : High[target_index]; 

    // --- 阶段 A: 信号箭头标记 (瀑布式查找) ---

    // 1. 最高优先级: 查找 P2 向下突破 (K_P2)
    // 逻辑：P2(支撑) 通常应低于 P1，结构才顺畅 (此处保留原逻辑的结构判断)
    if (P2_price < P1_price) 
    {
        for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
        {
            if (j < 0) break;
            if (j == 0) continue;
            
            // [确认点] P2 向下突破 (Close < P2)
            if (Close[j] < P2_price) 
            {
                SignalQuality sq;
                sq.grade = GRADE_NONE; // 默认初始化

                // 绘制基础线条 (原逻辑: false 代表 Bearish)
                DrawP2Baseline(P2_index, j, false);

                if (abs_highindex != -1)
                {
                    DrawP1P2Rectangle(abs_highindex, j, false);
                    DrawSignalInfoText(abs_highindex, j, "CB", SL_price, Close[j], false);
                }

                // =========================================================
                // 🔪 [手术切口 A] P2 强力突破 (CB) - V3 逻辑植入
                // =========================================================
                if (Enable_V3_Logic)
                {
                    // 1. 调用内核评分 (注意最后参数 false 代表 Bearish)
                    sq = EvaluateSignal(Symbol(), Period(), N_Geo, j, P1_price, P2_price, SL_price, false);
                    g_Stats.Add(sq.grade);
                    if (Test_Print_Detail)
                    {
                        Print("Pass: [SELL] Time:", TimeToString(Time[j]), " Grade:", sq.description);
                    }

                    // 2. 执行高级动作 (仅处理非垃圾信号)
                    if (sq.grade >= GRADE_D)
                    {
                         // -----------------------------------------------------------
                         // 🛡️ [报警过滤器] 只报实盘新信号 (Index 0或1)，且不重复
                         // -----------------------------------------------------------
                         bool is_live_signal = (j <= 1); 
                         bool is_new_time    = (iTime(Symbol(), Period(), j) > g_LastAlertTime);

                         DebugAlertCheck("Bearish(P2-Break)", j, sq);

                         if (sq.grade >= Min_Alert_Grade && is_live_signal && is_new_time) 
                         {
                             // 发送做空战报
                             bool alert_sent = SendRichAlert(Symbol(), Period(), "Bearish(P2-Break)", Close[j], SL_price, sq);
                             if (alert_sent)
                                 g_LastAlertTime = iTime(Symbol(), Period(), j);
                         }

                         // ---------------------------------------------------
                         // 🎨 [绘图控制] 智能斐波那契
                         // ---------------------------------------------------
                         // 1. 检查信号生存状态 (注意：is_bullish = false)
                         bool is_active = CheckSignalStatus(j, SL_price, false);

                         // 斐波那契绘图 (无需过滤历史，历史也要画)
                         // 传入 false (做空) 和 全局前缀
                         if (sq.grade >= GRADE_A && is_active)
                         {
                             DrawFiboGradeZones(Symbol(), j, SL_price, Close[j], false, g_object_prefix);
                         }
                    }
                }
                // =========================================================

                // 设置 Buffer (原 EA 逻辑保持兼容)
                if (Is_EA_Mode)
                {
                    if (abs_highindex != -1) BearishTargetBuffer[j] = High[abs_highindex];
                    // BearishSignalBuffer[j] = 3.0; // 3.0 = P2 Break
                    double grade_val = GetGradeWeight(sq.grade);
                    BearishSignalBuffer[j] = 3.0 + grade_val; 
                }
                else
                {
                    BearishSignalBuffer[j] = High[j] + 30 * Point(); // 箭头在K线上方
                }

                // 旧版报警 (互斥处理)
                // if (!Enable_V3_Logic && Is_EA_Mode == false) 
                // {
                //     // Alert("Old Bearish Signal...");
                // }

                return; // 找到最高优信号，退出
            }
        }
    }
    
    // 2. 次优先级: 查找 P1-DB 向下突破 (K_DB)
    // 如果代码执行到这里，说明没有 P2 突破，但协调者确认有 P1 突破 (K_Geo_Index)
    
    if (N_Geo >= DB_Threshold_Candles)
    {
        SignalQuality sq;
        sq.grade = GRADE_NONE;

        // 绘制基础线条
        DrawP2Baseline(P2_index, K_Geo_Index, false);
        if (abs_highindex != -1)
        {
            DrawP1P2Rectangle(abs_highindex, K_Geo_Index, false);
            DrawSignalInfoText(abs_highindex, K_Geo_Index, "DB", SL_price, Close[K_Geo_Index], false);
        }

        // =========================================================
        // 🔪 [手术切口 B] P1 结构突破 (DB) - V3 逻辑植入
        // =========================================================
        if (Enable_V3_Logic)
        {
            // 1. 调用内核评分 (传入 K_Geo_Index)
            sq = EvaluateSignal(Symbol(), Period(), N_Geo, K_Geo_Index, P1_price, P2_price, SL_price, false);
            g_Stats.Add(sq.grade);
            if (Test_Print_Detail)
            {
                Print("Pass: [SELL] Time:", TimeToString(Time[K_Geo_Index]), " Grade:", sq.description);
            }

            // 2. 执行高级动作
            if (sq.grade >= GRADE_D)
            {
                 // 🛡️ [报警过滤器]
                 bool is_live_signal = (K_Geo_Index <= 1); 
                 bool is_new_time    = (iTime(Symbol(), Period(), K_Geo_Index) > g_LastAlertTime);

                 DebugAlertCheck("Bearish(DB-Break)", K_Geo_Index, sq);

                 if (sq.grade >= Min_Alert_Grade && is_live_signal && is_new_time) 
                 {
                     bool alert_sent = SendRichAlert(Symbol(), Period(), "Bearish(DB-Break)", Close[K_Geo_Index], SL_price, sq);
                     if (alert_sent)
                         g_LastAlertTime = iTime(Symbol(), Period(), K_Geo_Index);
                 }

                 bool is_active = CheckSignalStatus(K_Geo_Index, SL_price, false);
                 // 斐波那契绘图
                 if (sq.grade >= GRADE_A && is_active)
                 {
                     DrawFiboGradeZones(Symbol(), K_Geo_Index, SL_price, Close[K_Geo_Index], false, g_object_prefix);
                 }
            }
        }
        // =========================================================

        if (Is_EA_Mode)
        {
            if (abs_highindex != -1) BearishTargetBuffer[K_Geo_Index] = High[abs_highindex];
            // BearishSignalBuffer[K_Geo_Index] = 2.0; // 2.0 = DB Break
            double grade_val = GetGradeWeight(sq.grade);
            BearishSignalBuffer[K_Geo_Index] = 2.0 + grade_val;
        }
        else
        {
            BearishSignalBuffer[K_Geo_Index] = High[K_Geo_Index] + 20 * Point();
        }

        return;
    }

    // 3. 最低优先级: IB 独立信号标记 (仅突破P1，未达DB延迟，未过P2)
    if (Enable_IB_Signal_Marking)
    {
        SignalQuality sq;
        sq.grade = GRADE_NONE;

        // N_Geo>=2 一律并入 1.5 档，不区分具体根数
        double ib_base = (N_Geo == 1) ? 1.0 : 1.5;
        string ib_type = (N_Geo == 1) ? "IB1" : "IB2";

        DrawP2Baseline(P2_index, K_Geo_Index, false);

        if (abs_highindex != -1)
        {
            DrawP1P2Rectangle(abs_highindex, K_Geo_Index, false);
            DrawSignalInfoText(abs_highindex, K_Geo_Index, ib_type, SL_price, Close[K_Geo_Index], false);
        }

        if (Enable_V3_Logic)
        {
            sq = EvaluateSignal(Symbol(), Period(), N_Geo, K_Geo_Index, P1_price, P2_price, SL_price, false);
            g_Stats.Add(sq.grade);
            if (Test_Print_Detail)
            {
                Print("Pass: [SELL-", ib_type, "] Time:", TimeToString(Time[K_Geo_Index]), " Grade:", sq.description);
            }

            // 与 DB/CB 完全相同的判断代码；grade 上限为 GRADE_C，故默认 Min_Alert_Grade/GRADE_A 门槛下不会触发
            // 若测试后需要IB专属报警门槛，可在此处引入独立阈值参数替换 Min_Alert_Grade
            if (sq.grade >= GRADE_D)
            {
                 bool is_live_signal = (K_Geo_Index <= 1);
                 bool is_new_time    = (iTime(Symbol(), Period(), K_Geo_Index) > g_LastAlertTime);

                 DebugAlertCheck("Bearish(" + ib_type + ")", K_Geo_Index, sq);

                 if (sq.grade >= Min_Alert_Grade && is_live_signal && is_new_time)
                 {
                     bool alert_sent = SendRichAlert(Symbol(), Period(), "Bearish(" + ib_type + ")", Close[K_Geo_Index], SL_price, sq);
                     if (alert_sent)
                         g_LastAlertTime = iTime(Symbol(), Period(), K_Geo_Index);
                 }

                 bool is_active = CheckSignalStatus(K_Geo_Index, SL_price, false);
                 if (sq.grade >= GRADE_A && is_active)
                 {
                     DrawFiboGradeZones(Symbol(), K_Geo_Index, SL_price, Close[K_Geo_Index], false, g_object_prefix);
                 }
            }
        }

        if (Is_EA_Mode)
        {
            if (abs_highindex != -1) BearishTargetBuffer[K_Geo_Index] = High[abs_highindex];
            double grade_val = GetGradeWeight(sq.grade);
            BearishSignalBuffer[K_Geo_Index] = ib_base + grade_val;
        }
        else
        {
            BearishSignalBuffer[K_Geo_Index] = High[K_Geo_Index] + 10 * Point();
        }

        return;
    }
    
    return;
}

/*
//+------------------------------------------------------------------+
//| CheckSignalStatus
//| 功能: 检查历史信号是否依然有效 (Active)
//| 返回: true=有效(应绘制), false=无效(已止损或已止盈，应隐藏)
//+------------------------------------------------------------------+
bool CheckSignalStatus_V1(int signal_index, double sl_price, bool is_bullish)
{
    // 1. 如果是当前最新信号 (0 或 1)，永远视为有效
    if (signal_index <= 1) return true;

    // 2. 如果用户不想看任何历史信号，直接返回 false
    if (!Show_History_Fibo) return false;

    // 3. 如果用户选择显示历史，但不隐藏失效的，那就都显示
    if (!Hide_Invalid_Fibo) return true;

    // 4. --- 智能判断逻辑 (Trader's Eye) ---
    // 遍历从信号发生后(signal_index - 1) 到 当前(0) 的所有K线
    // 注意：MT4索引越小越新
    
    // 设定“完美止盈”的标准：斐波那契 4.236 (动能耗尽点)
    // 估算 range
    double entry_price = (is_bullish ? High[signal_index] : Low[signal_index]); // 估算
    double range = MathAbs(entry_price - sl_price);
    
    for (int k = signal_index - 1; k >= 0; k--)
    {
        if (is_bullish)
        {
            // A. 检查止损 (失效)
            if (Low[k] <= sl_price) return false; // 价格跌破 SL，信号死亡

            // B. 检查止盈 (完成) -> 斐波 4.236
            double tp_final = sl_price + range * 4.236;
            if (High[k] >= tp_final) return false; // 价格到达终点，信号使命结束
        }
        else // 做空
        {
            // A. 检查止损
            if (High[k] >= sl_price) return false; // 价格涨破 SL

            // B. 检查止盈
            double tp_final = sl_price - range * 4.236;
            if (Low[k] <= tp_final) return false;
        }
    }

    // 如果没死也没毕业，那就是“依然在战斗中” (Active)
    return true;
}
*/

//+------------------------------------------------------------------+
//| CheckSignalStatus (最终版)
//|
//| 功能: 检查历史信号是否依然有效 (Active)
//| 核心逻辑: 
//|   1. 止损标准 (IB失效): 价格实体收盘价 击穿 P1 (锚点开盘价) 即死。
//|   2. 止盈标准 (完结): 价格触及 4.236 扩展位 即完成使命。
//|
//| 参数:
//|   signal_index : 信号确认K线的索引 (P2突破或DB突破的那根K线)
//|   sl_price     : 必须传入 P1 (锚点开盘价) 作为止损基准
//|   is_bullish   : 多空方向
//+------------------------------------------------------------------+
bool CheckSignalStatus(int signal_index, double sl_price, bool is_bullish)
{
    // ---------------------------------------------------
    // 1. 基础可见性过滤
    // ---------------------------------------------------
    
    // 规则 A: 永远保留最新的正在进行的信号 (索引 0 或 1)
    // 这样保证实盘时信号不会突然闪烁消失
    if (signal_index <= 1) return true;

    // 规则 B: 如果用户彻底关闭历史显示，则所有旧信号都不画
    if (!Show_History_Fibo) return false;

    // 规则 C: 如果用户想看历史，且允许看失效的信号(复盘用)，则全部保留
    // Hide_Invalid_Fibo = true (默认) -> 隐藏死掉的，只留活的
    // Hide_Invalid_Fibo = false      -> 显示所有历史尸体
    if (!Hide_Invalid_Fibo) return true;


    // ---------------------------------------------------
    // 2. 智能生存状态检查 (从信号产生那一刻一直查到现在)
    // ---------------------------------------------------
    
    // 计算逻辑上的 "IB 区间动能幅度" (用于测算 TP)
    // 注意：这里使用信号K线的收盘价 vs P1 来计算幅度，与斐波那契绘制保持一致
    double entry_price = Close[signal_index]; 
    double range = MathAbs(entry_price - sl_price);

    // 遍历：从信号后一根K线 (signal_index - 1) 开始，一直查到当前K线 (0)
    for (int k = signal_index - 1; k >= 0; k--)
    {
        if (is_bullish) // [做多信号检查]
        {
            // A. 检查止损 (IB失效标准)
            // 逻辑：如果 K 线实体收盘价跌破 P1 (sl_price)，视为结构崩塌
            if (Close[k] < sl_price) 
            {
                return false; // 信号已死 (Invalid)
            }
            
            // (可选：如果您想要更严格的"引线触碰即死"，请解开下面这行)
            // if (Low[k] <= sl_price) return false;

            // B. 检查止盈 (完美毕业)
            // 逻辑：如果最高价触及 4.236 目标位
            double tp_final = sl_price + (range * 4.236);
            if (High[k] >= tp_final) 
            {
                return false; // 信号已完成使命 (Completed)
            }
        }
        else // [做空信号检查]
        {
            // A. 检查止损 (IB失效标准)
            // 逻辑：如果 K 线实体收盘价涨破 P1 (sl_price)
            if (Close[k] > sl_price) 
            {
                return false; // 信号已死 (Invalid)
            }

            // B. 检查止盈
            double tp_final = sl_price - (range * 4.236);
            if (Low[k] <= tp_final) 
            {
                return false; // 信号已完成使命 (Completed)
            }
        }
    }

    // 经历了九九八十一难（所有K线检查）都没死也没毕业，
    // 说明这个信号依然 "Active" (活着且未达终点)。
    return true;
}

//+------------------------------------------------------------------+
//| IsSignalPriceInvalidated (清理专用，与 CheckSignalStatus 职责分离)
//|
//| 与 CheckSignalStatus 的区别：
//|   1. CheckSignalStatus 服务于"是否绘制历史斐波投影"这一 UI 显示偏好，
//|      默认 Show_History_Fibo=false 时对 signal_index>1 恒定返回 false，
//|      不适合用来判断信号本体（矩形/标注/辅助线）是否该被清理。
//|   2. 本函数只回答一个客观问题：价格收盘是否已经击穿止损，与任何显示
//|      开关无关，永远可达。
//|   3. 触及止盈(4.236)不算失效——已完成的信号保留在图表上作为历史记录，
//|      只有真正被止损击穿的信号才视为失效。
//|
//| 参数:
//|   signal_index : 信号确认K线索引 (P2突破或DB突破的那根K线)
//|   sl_price     : 真实止损价 (看涨传 Low[abs_lowindex]，看跌传 High[abs_highindex])
//|   is_bullish   : 多空方向
//+------------------------------------------------------------------+
bool IsSignalPriceInvalidated(int signal_index, double sl_price, bool is_bullish)
{
    if (signal_index <= 0) return false; // 无历史K线可供检查

    for (int k = signal_index - 1; k >= 0; k--)
    {
        if (is_bullish)
        {
            if (Close[k] < sl_price) return true; // 收盘跌破止损，结构破坏
        }
        else
        {
            if (Close[k] > sl_price) return true; // 收盘涨破止损，结构破坏
        }
    }

    return false; // 未被击穿，信号依然有效
}

// ==========================================================================
// 2. 核心计算引擎 (Calculation Engine)
// ==========================================================================

// 计算空间因子 (ATR Helper)
double Calculate_Space_Factor(string sym, int period, double p1, double p2, int shift) {
    double atr = KT_GetATR(sym, (ENUM_TIMEFRAMES)period, 14, shift);
   if(atr <= 0) return 0;
   return MathAbs(p2 - p1) / atr;
}

/*
// 综合评分系统 (The Brain)
SignalQuality EvaluateSignal_Bug(
   string sym, int period, 
   int anchor_idx, int breakout_idx, 
   double p1, double p2, double sl, 
   bool is_bullish
) {
   SignalQuality sq;
   sq.grade = GRADE_NONE;
   
   // --- A. 基础计算 ---
    double atr = KT_GetATR(sym, (ENUM_TIMEFRAMES)period, 14, breakout_idx);
    if(atr==0) atr = _Point;
   
   double close_price = iClose(sym, period, breakout_idx);
   int n_geo = MathAbs(anchor_idx - breakout_idx);
   
   sq.is_IB = (n_geo <= 2);
   sq.is_DB = (n_geo > 2);
   
   // --- B. 结构与CB判定 ---
   if (is_bullish) {
      if (p2 < p1) { sq.grade = GRADE_F; sq.description = "结构破坏(P2<P1)"; return sq; }
      sq.is_CB = (close_price > p2);
   } else {
      if (p2 > p1) { sq.grade = GRADE_F; sq.description = "结构破坏(P2>P1)"; return sq; }
      sq.is_CB = (close_price < p2);
   }

   // --- C. 空间与盈亏比 ---
   sq.space_factor = Calculate_Space_Factor(sym, period, p1, p2, breakout_idx);
   double risk = MathAbs(p1 - sl);
   double reward = MathAbs(p2 - p1);
   sq.rr_ratio = (risk > 0) ? (reward / risk) : 0;
   
   // --- D. 斐波那契目标计算 (针对 Grade A/S) ---
   double range = MathAbs(close_price - sl);
   if (is_bullish) sq.target_fib_1618 = sl + range * 1.618;
   else            sq.target_fib_1618 = sl - range * 1.618;

   // --- E. 最终定级逻辑 ---
   if (sq.is_CB) {
      // 突破了P2，且空间不是极其微小
      if (sq.is_DB) { sq.grade = GRADE_S; sq.description = "S级:主导突破(DB+CB)"; }
      else          { sq.grade = GRADE_A; sq.description = "A级:爆发突破(IB+CB)"; }
   } 
   else {
      // 没过P2，看空间
      if (sq.space_factor > 1.5) {
         if (sq.is_DB) { sq.grade = GRADE_B; sq.description = "B级:区间主导(DB)"; }
         else          { sq.grade = GRADE_C; sq.description = "C级:区间激进(IB)"; }
      } else {
         sq.grade = GRADE_D; sq.description = "D级:空间不足";
      }
   }
   
   return sq;
}
*/

// 综合评分系统 (The Brain)
SignalQuality EvaluateSignal(
   string sym, int period, 
   int n_geo_input, int breakout_idx, 
   double p1, double p2, double sl, 
   bool is_bullish
) {
   SignalQuality sq;
   sq.grade = GRADE_NONE;
   
   // --- A. 基础计算 ---
    double atr = KT_GetATR(sym, (ENUM_TIMEFRAMES)period, 14, breakout_idx);
    if(atr==0) atr = _Point;
   //上面虽然计算出来了atr 但是好像没有用到

    double close_price = iClose(sym, (ENUM_TIMEFRAMES)period, breakout_idx);
   int n_geo = n_geo_input;

   // ✅ 修复：使用全局参数 DB_Threshold_Candles 进行动态判断
   // 只有跨度达到或超过阈值 (例如 >= 3) 才算是 DB
   sq.is_DB = (n_geo >= DB_Threshold_Candles);

   // 否则就是 IB (快速爆发)
   sq.is_IB = (n_geo < DB_Threshold_Candles);
   
   // --- B. 结构与CB判定 ---
   if (is_bullish) {
      if (p2 < p1) { sq.grade = GRADE_F; sq.description = "结构破坏(P2<P1)"; return sq; }
      sq.is_CB = (close_price > p2);
   } else {
      if (p2 > p1) { sq.grade = GRADE_F; sq.description = "结构破坏(P2>P1)"; return sq; }
      sq.is_CB = (close_price < p2);
   }
   //代码运行到这里 已经完全识别出 信号是ib db 还是cb？ 那么出现质量问题应该是下面的代码了

   // --- C. 结构空间与盈亏比 ---
   // space_factor 的新认知：它不是方向判断，也不是信号触发条件，
   // 而是“结构裕度/结构舒展度”指标。
   //
   // 计算方式：
   //   space_factor = abs(P2 - P1) / ATR(14)
   //
   // 含义：把 P1 到 P2 的价格距离，除以当前市场通常一根K线的波动范围。
   // 因此它衡量的不是绝对价格距离，而是“这个结构空间相对于当前噪音有多宽”：
   //   - 数值较小：P1/P2 挤得较近，结构空间容易被正常波动吞没，裕度不足；
   //   - 数值较大：P1/P2 间距相对 ATR 更宽，结构更舒展，尚未突破 P2 时仍有保留价值。
   //
   // space_factor 不负责回答“信号是否成立”。IB/DB 由 n_geo 与 DB 阈值决定，
   // CB 由价格是否突破 P2 决定；space_factor 只在“没有 CB”时，辅助判断该结构
   // 是可继续观察的区间结构，还是空间过窄、接近噪音的 D 级结构。
   // 当前 1.5 是“结构跨度约为 1.5 个 ATR”的经验分界，不应理解为市场的自然常数。
   // 后续若优化，应优先将它视为可验证、可配置的结构裕度门槛，而不是继续把它
   // 当作一个隐藏的评分魔法数字。
   sq.space_factor = Calculate_Space_Factor(sym, period, p1, p2, breakout_idx);
   double risk = MathAbs(p1 - sl);
   double reward = MathAbs(p2 - p1);
   sq.rr_ratio = (risk > 0) ? (reward / risk) : 0;
   
   // --- D. 斐波那契目标计算 (针对 Grade A/S) ---
   double range = MathAbs(close_price - sl);
   if (is_bullish) sq.target_fib_1618 = sl + range * 1.618;
   else            sq.target_fib_1618 = sl - range * 1.618;

   /*
   // --- E. 最终定级逻辑 ---
   if (sq.is_CB) {
      // 突破了P2，且空间不是极其微小
      if (sq.is_DB) { sq.grade = GRADE_S; sq.description = "S级:主导突破(DB+CB)"; }
      else          { sq.grade = GRADE_A; sq.description = "A级:爆发突破(IB+CB)"; }
   } 
   else {
      // 没过P2，看空间
      if (sq.space_factor > 1.5) {
         if (sq.is_DB) { sq.grade = GRADE_B; sq.description = "B级:区间主导(DB)"; }
         else          { sq.grade = GRADE_C; sq.description = "C级:区间激进(IB)"; }
      } else {
         sq.grade = GRADE_D; sq.description = "D级:空间不足";
      }
   }
   */

   // =================================================================
   // --- E. 最终定级逻辑 (Refactored Logic) ---
   // 核心思想：结构决定潜力，动作决定触发
   // =================================================================
   
   // 🟢 分支一：如果是 DB 结构 (深幅酝酿)
   if (sq.is_DB) 
   {
       // 既然结构已经满足 DB，我们看它发生了什么动作。
       // 注意：若已经 CB，突破动作本身已经提供了足够的确认，space_factor
       // 不再参与 S 级判断；它只服务于“DB 但尚未 CB”的保留/过滤决策。
       if (sq.is_CB) 
       {
           // 动作：强势突破 P2
           // 结论：结构深 + 动能足 = 完美 S 级
           sq.grade = GRADE_S; 
           sq.description = "S级:主导突破(DB+CB)"; 
       }
       else 
       {
           // 动作：未突破 P2 (但结构是 DB)
           // 检查：空间够不够挂单？
           // 未突破 P2 时，space_factor 作为结构裕度过滤器：
           // 大于 1.5 表示 P1-P2 间距相对 ATR 足够宽，保留为 B 级观察结构；
           // 不大于 1.5 表示空间偏窄，降为 D 级，不代表方向一定错误，
           // 只是当前结构的可操作裕度不足。
           if (sq.space_factor > 1.5) 
           {
               sq.grade = GRADE_B; 
               sq.description = "B级:区间主导(DB)"; 
           }
           else 
           {
               sq.grade = GRADE_D; 
               sq.description = "D级:空间不足"; 
           }
       }
   }
   // 🔵 分支二：如果是 IB 结构 (快速爆发)
   else // is_IB
   {
       // 结构较短，看看动作。
       // 对 IB 而言，若直接 CB，动能动作优先于空间判断，直接进入 A 级；
       // 只有 IB 尚未 CB 时，才使用 space_factor 区分 C 级和 D 级。
       if (sq.is_CB) 
       {
           // 动作：强势突破 P2
           // 结论：虽然时间短，但动能极强 = 优秀 A 级
           sq.grade = GRADE_A; 
           sq.description = "A级:爆发突破(IB+CB)"; 
       }
       else 
       {
           // 动作：未突破 P2 且结构短。
           // space_factor 大于 1.5 时，虽然结构短且尚未突破 P2，但空间仍足够，
           // 作为 C 级激进观察结构；不大于 1.5 时，空间和结构长度都不足，给 D 级。
           if (sq.space_factor > 1.5) 
           {
               sq.grade = GRADE_C; 
               sq.description = "C级:区间激进(IB)"; 
           }
           else 
           {
               sq.grade = GRADE_D; 
               sq.description = "D级:空间不足"; 
           }
       }
   }
   // 关键一点：虽然这里做了质量的评分 但是其实只是给用户展示用的 并不影响信号的执行 这里的信号筛选只是主观意义的评级判定
   // 只要有信号 就会发给K8Bot去执行的。

   // 关于D级的含义说明：结构已经被识别，但尚未突破 P2，而且 P1 到 P2 的空间相对于 ATR 太小。
   // 也就是说，D 级不是结构完全错误，而是“结构裕度不足”
   return sq;
}

// ==========================================================================
// 3. 可视化与提醒 (Visuals & Alerts)
// ==========================================================================

// 报警条件调试输出：用于定位等级、实时性、时间锁和提醒开关的拦截原因。
void DebugAlertCheck(string type, int signal_index, SignalQuality &sq)
{
    // 默认关闭调试日志；需要排查报警条件时，恢复下面的调试代码即可。
    return;

    /*
   datetime signal_time = iTime(Symbol(), Period(), signal_index);
   bool is_live_signal = (signal_index <= 1);
   bool is_new_time = (signal_time > g_LastAlertTime);

   Print("AlertCheck type=", type,
       " grade=", sq.grade,
       " description=", sq.description,
       " min_grade=", Min_Alert_Grade,
       " grade_pass=", (sq.grade >= Min_Alert_Grade),
       " is_live=", is_live_signal,
       " is_new_time=", is_new_time,
       " ea_mode=", Is_EA_Mode,
       " rich_alert=", Enable_Rich_Alert,
       " signal_time=", TimeToString(signal_time),
       " last_alert_time=", TimeToString(g_LastAlertTime));
   */
}

/**
// 发送富文本提醒
void SendRichAlert_Old_1(string sym, int period, string type, double price, double sl, SignalQuality &sq) {
   if (Is_EA_Mode)
   {
      return;
   }

   if (!Enable_Rich_Alert) return; // 多窗口同周期重复提醒时可关闭
   
   if (sq.grade <= GRADE_D) return; // 过滤低质量
   
   string per_str = GetTimeframeName(period);

   // 把 M%d 修改为 %s
   string msg = StringFormat(
      "%s %s [%s] | %s\n现价: %.5f | SL: %.5f\n因子: %.1f | R:R: %.1f\n",
      sym, per_str, type, sq.description, price, sl, sq.space_factor, sq.rr_ratio
   );
   
   if(sq.grade >= GRADE_A) msg += StringFormat(">> 目标: %.5f (Fib 1.618)", sq.target_fib_1618);
   
   Alert(msg);
   SendNotification(msg);
}
*/

/**
// 发送富文本提醒 V2
// 与旧版本保持相同的调用参数；D 级是否报警由调用方的 Min_Alert_Grade 决定。
void SendRichAlert_Old_2(string sym, int period, string type, double price, double sl, SignalQuality &sq) {
    if (Is_EA_Mode)
    {
        return;
    }

    if (!Enable_Rich_Alert) return; // 多窗口同周期重复提醒时可关闭

    // 仅过滤无效等级和无等级信号；GRADE_D 允许进入提醒流程。
    if (sq.grade < GRADE_D) return;

    string per_str = GetTimeframeName(period);

    string msg = StringFormat(
        "%s %s [%s] | %s\n现价: %.5f | SL: %.5f\n因子: %.1f | R:R: %.1f\n",
        sym, per_str, type, sq.description, price, sl, sq.space_factor, sq.rr_ratio
    );

    if(sq.grade >= GRADE_A) msg += StringFormat(">> 目标: %.5f (Fib 1.618)", sq.target_fib_1618);

    Alert(msg);
    SendNotification(msg);
}
*/

// 发送富文本提醒 V3
// 返回 true 表示已执行本地 Alert；返回 false 表示提醒被前置条件拦截。
// D 级是否允许提醒由调用方的 Min_Alert_Grade 决定。
bool SendRichAlert(string sym, int period, string type, double price, double sl, SignalQuality &sq) {
    if (Is_EA_Mode)
    {
        return false;
    }

    if (!Enable_Rich_Alert) return false; // 多窗口同周期重复提醒时可关闭

    // D 级是否允许发送，由 Min_Alert_Grade 控制。仅过滤无效等级和无等级信号；GRADE_D 允许进入提醒流程。
    if (sq.grade < GRADE_D) return false;

    string per_str = GetTimeframeName(period);
    double stop_distance = MathAbs(price - sl);
    double stop_points = (Point() > 0) ? stop_distance / Point() : 0;

    string msg = StringFormat(
        "%s %s [%s] | %s\n现价: %.5f | SL: %.5f | 点数: %.0f points\n价格差: %.2f$\n因子: %.1f | R:R: %.1f\n",
        sym, per_str, type, sq.description, price, sl, stop_points, stop_distance, sq.space_factor, sq.rr_ratio
    );

    if(sq.grade >= GRADE_A) msg += StringFormat(">> 目标: %.5f (Fib 1.618)", sq.target_fib_1618);

    // Alert() 本身没有可用于判断的返回值。
    // 执行到这里，可视为本地弹窗已提交。
    Alert(msg);
    // SendNotification(msg);

    // 手机推送是附加通道，不应决定本地 Alert 是否成功。
    bool notification_sent = SendNotification(msg);

    if (!notification_sent)
    {
        Print(
            "Rich alert local Alert sent, "
            "but SendNotification failed. Type: ",
            type,
            " Grade: ",
            sq.description
        );
    }

    return true;
}

// 将枚举等级转换为协议小数
double GetGradeWeight(ENUM_SIGNAL_GRADE grade)
{
   switch(grade)
   {
      case GRADE_S: return 0.5;
      case GRADE_A: return 0.4;
      case GRADE_B: return 0.3;
      case GRADE_C: return 0.2;
      case GRADE_D: return 0.1;
      default:      return 0.0;
   }
}
//#endregion

//#region MARK: 前台要调用的模块
//+------------------------------------------------------------------+
//| 🛡️ 参数同步模块：将当前参数保存到隐藏对象，供脚本读取
//+------------------------------------------------------------------+
void SaveParamsToChart_V1()
{
   if(Is_EA_Mode) return; // EA后台模式不需要保存

   string obj_name = "KTarget_Param_Store"; // 固定名称
   
   // 1. 如果对象不存在，创建它 (使用 OBJ_LABEL 作为数据容器)
   if(ObjectFind(0, obj_name) == -1) {
      ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
      // ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true); // 隐藏，不干扰视线
      // ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, -100); // 移出屏幕外
      // ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }

   // --- 核心修改：调整位置属性 (顶部居中) ---

   // 2. 设置锚点为顶部中心 (关键：这会让文字以 X 坐标为中心向两边分布)
   ObjectSetInteger(0, obj_name, OBJPROP_ANCHOR, ANCHOR_TOP);

   // 3. 设置角部为左上角 (作为坐标计算的基准)
   ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);

   // 4. 动态计算 X 坐标：获取图表当前像素宽度，除以 2 得到中心点
   int chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, chart_width / 2);

   // 5. 设置 Y 坐标：距离图表最顶部 20 像素，避免紧贴边缘
   ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, 10);

   // 6. 取消隐藏 (原代码设置为 true 且移出屏幕，现在改为可见)
   ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, false);

   // 2. 拼接核心参数 (顺序必须与 Config_Core.mqh 一致!)
   // 格式: Smart_Tuning|Scan_Range|La_B|Lb_B|La_T|Lb_T|Max_Look|DB_Thres|LLHH|Model
   string param_str = 
      (string)Smart_Tuning_Enabled + "|" +
      (string)Scan_Range + "|" +
      (string)Lookahead_Bottom + "|" +
      (string)Lookback_Bottom + "|" +
      (string)Lookahead_Top + "|" +
      (string)Lookback_Top + "|" +
      (string)Max_Signal_Lookforward + "|" +
      (string)DB_Threshold_Candles + "|" +
      (string)Look_LLHH_Candles + "|" +
      (string)Find_Target_Model;

   // 3. 写入对象描述
   ObjectSetString(0, obj_name, OBJPROP_TEXT, param_str);
   ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);

   // 打印日志方便确认
   Print("---->参数已同步至图表: ", param_str);
}

//+------------------------------------------------------------------+
//| 🛡️ 参数同步模块：将当前参数保存到隐藏对象，供脚本读取
//+------------------------------------------------------------------+
void SaveParamsToChart()
{
   if(Is_EA_Mode) return; // EA后台模式不需要保存

   string obj_name = "KTarget_Param_Store"; // 固定名称
   
   // 1. 如果对象不存在，创建它 (使用 OBJ_LABEL 作为数据容器)
   if(ObjectFind(0, obj_name) == -1) {
      ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
   }

   // --- 关键设置：让对象不可见但可读取 ---
   
   // 方法1: 设置对象在所有时间周期都不显示 (推荐)
   ObjectSetInteger(0, obj_name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   
   // 方法2: 将对象移出屏幕外 (备用方案)
   ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, -10000); // 移到屏幕左侧很远的位置
   ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, -10000); // 移到屏幕上方很远的位置

   // 2. 拼接核心参数 (顺序必须与 Config_Core.mqh 一致!)
   // 格式: Smart_Tuning|Scan_Range|La_B|Lb_B|La_T|Lb_T|Max_Look|DB_Thres|LLHH|Model
   string param_str = 
      (string)Smart_Tuning_Enabled + "|" +
      (string)Scan_Range + "|" +
      (string)Lookahead_Bottom + "|" +
      (string)Lookback_Bottom + "|" +
      (string)Lookahead_Top + "|" +
      (string)Lookback_Top + "|" +
      (string)Max_Signal_Lookforward + "|" +
      (string)DB_Threshold_Candles + "|" +
      (string)Look_LLHH_Candles + "|" +
      (string)Find_Target_Model;

   // 3. 写入对象描述
   ObjectSetString(0, obj_name, OBJPROP_TEXT, param_str);
   ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);

   // 打印日志方便确认
   Print("---->参数已同步至图表: ", param_str);
}

void SaveParamsToChartForBot8()
{
    if(Is_EA_Mode) return;

    string obj_name = "KTarget_Param_Store_Bot8";
    if(ObjectFind(0, obj_name) == -1)
        ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);

    ObjectSetInteger(0, obj_name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, -10000);
    ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, -10000);
    ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);

    string param_str =
        "K8|3|0|" + (string)_Period + "|" +
        (string)Scan_Range + "|" +
        (string)Lookahead_Bottom + "|" +
        (string)Lookback_Bottom + "|" +
        (string)Lookahead_Top + "|" +
        (string)Lookback_Top + "|" +
        (string)Max_Signal_Lookforward + "|" +
        (string)DB_Threshold_Candles + "|" +
        (string)Look_LLHH_Candles + "|" +
        IntegerToString(Enable_IB_Signal_Marking ? 1 : 0) + "|" +
        (string)Find_Target_Model + "|" +
        IntegerToString(Enable_Honest_Filter ? 1 : 0) + "|" +
        IntegerToString(Use_Enhanced_P2_Search ? 1 : 0) + "|" +
        (string)Enhanced_P2_Min_Bars_Between + "|" +
        IntegerToString(Use_Strict_PLevel_Search ? 1 : 0) + "|" +
        (string)Strict_PLevel_Min_Bars_Between;

    ObjectSetString(0, obj_name, OBJPROP_TEXT, param_str);
}

void Init_Smart_Tuning()
{
    //+------------------------------------------------------------------+
    // 🚨 检查是否启用智能调优 🚨
    if (Smart_Tuning_Enabled)
    {
        // 1. 获取周期调优后的参数集
        TuningParameters tuned_params = GetTunedParameters_K7();

        // 2. 将全局外部变量的值覆盖为调优后的值
        // 这样，主逻辑中所有对这些变量的引用都将自动使用新值。
        Scan_Range = tuned_params.Scan_Range;
        Lookahead_Bottom = tuned_params.Lookahead_Bottom;
        Lookback_Bottom = tuned_params.Lookback_Bottom;
        Lookahead_Top = tuned_params.Lookahead_Top;
        Lookback_Top = tuned_params.Lookback_Top;
        Max_Signal_Lookforward = tuned_params.Max_Signal_Lookforward;
        Look_LLHH_Candles = tuned_params.Look_LLHH_Candles;

        // 可选：打印日志确认
        // Print("INFO: Smart Tuning Enabled. Parameters adjusted for Period ", GetTimeframeName(_Period));
    }
    //+------------------------------------------------------------------+
}

void Init_Object_prefix()
{
    // long cid = ChartID();
    // Print("-->[KTarget_Finder5.mq4:152]: cid: ", cid);

    // 1. 获取 ChartID 的绝对值 (long 类型)
    long full_chart_id = MathAbs(ChartID());
    // Print("-->[KTarget_Finder5.mq4:156]: full_chart_id: ", full_chart_id);

    // 2. 强制截断 ChartID 到 32 位 int。
    // 仅保留 ID 的低位部分，使其长度大幅缩短，但仍具有高度唯一性。
    // int short_chart_id = (int)full_chart_id;
    int short_chart_id = (int)(full_chart_id % 1000000);
    // Print("-->[KTarget_Finder5.mq4:161]: short_chart_id: ", MathAbs(short_chart_id));

    // [V1.32 NEW] 生成唯一的对象名前缀
    g_object_prefix = ShortenObjectName(MQLInfoString(MQL_PROGRAM_NAME)) + StringFormat("_%d_", MathAbs(short_chart_id));
    // Print("-->[KTarget_Finder5.mq4:165]: g_object_prefix: ", g_object_prefix);
}

void Init_Buffer()
{
    //+------------------------------------------------------------------+
    // 缓冲区映射设置 (无变化)
    // MQL4 的 SetIndexStyle/SetIndexArrow 已由 MQL5 PlotIndexSet* 替代。
    SetIndexBuffer(0, BullishTargetBuffer, INDICATOR_DATA);
    PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_ARROW);
    PlotIndexSetInteger(0, PLOT_ARROW, ARROW_CODE_UP);
    PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrBlue);

    SetIndexBuffer(1, BearishTargetBuffer, INDICATOR_DATA);
    PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_ARROW);
    PlotIndexSetInteger(1, PLOT_ARROW, ARROW_CODE_DOWN);
    PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrRed);

    SetIndexBuffer(2, BullishSignalBuffer, INDICATOR_DATA);
    PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_ARROW);
    PlotIndexSetInteger(2, PLOT_ARROW, ARROW_CODE_SIGNAL_UP);
    PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrLimeGreen);

    SetIndexBuffer(3, BearishSignalBuffer, INDICATOR_DATA);
    PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_ARROW);
    PlotIndexSetInteger(3, PLOT_ARROW, ARROW_CODE_SIGNAL_DOWN);
    PlotIndexSetInteger(3, PLOT_LINE_COLOR, clrDarkViolet);

    // 初始化所有缓冲区数据为 0.0
    ArrayInitialize(BullishTargetBuffer, EMPTY_VALUE);
    ArrayInitialize(BearishTargetBuffer, EMPTY_VALUE);
    ArrayInitialize(BullishSignalBuffer, EMPTY_VALUE);
    ArrayInitialize(BearishSignalBuffer, EMPTY_VALUE);
}

void DeInit_DelObject()
{
    // ------------------- 1.0 清理对象的迭代代码 -------------------
    // 清理所有以 "IBDB_Line_" 为前缀的趋势线对象 (P1基准线)
    // ObjectsDeleteAll(0, "IBDB_Line_");
    // [V1.22 NEW] 清理所有以 "IBDB_P2_Line_" 为前缀的趋势线对象 (P2基准线)
    // ObjectsDeleteAll(0, "IBDB_P2_Line_");

    if (!Is_EA_Mode)
    {
        /* 1.0
        // 使用唯一的 g_object_prefix 进行清理
        for (int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
        {
            string object_name = ObjectName(i);
            // 检查对象名称是否包含我们独有的前缀
            if (StringFind(object_name, g_object_prefix) != -1)
            {
                ObjectDelete(0, object_name);
            }
        }
        */

        // 2.0 遍历图表上的所有对象，从后向前扫描
        for (int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
        {
            string obj_name = ObjectName(0, i);

            // 1. 第一层筛选：必须是本指标创建的对象 (匹配前缀)
            if (StringFind(obj_name, g_object_prefix) != -1)
            {
                // 2. 第二层筛选：检查是否为【斐波那契相关对象】(白名单)
                // 根据名称特征：包含 "_Fibo_" 或 "_FiboHL_" 的都属于斐波组件
                bool is_fibo_line = (StringFind(obj_name, "_Fibo_") != -1);
                bool is_fibo_zone = (StringFind(obj_name, "_FiboHL_") != -1);

                // 3. 核心保护逻辑：如果是斐波对象，【跳过删除】，直接进入下一次循环
                if (is_fibo_line || is_fibo_zone)
                {
                    continue; // 🚨 关键语句：保留对象，不执行下面的删除
                }

                // 4. 只有非斐波对象 (如信号箭头、临时连线等) 才会被删除
                ObjectDelete(0, obj_name);
            }
        }

        // ------------------- 0.0 下面的代码保持不变 -------------------
        ChartRedraw();
        Print("---->[KTarget_Finder_MT7.mq4:1067]: OnDeinit 指标卸载 ");
    }
}

void HandleObjectClick(string sparam)
{
    // sparam 包含了被点击对象的名称。
    string object_name = sparam;
    ParsedRectInfo info;

    if (HandleStrictModeButtonClick(object_name))
    {
        return;
    }

    // 这是您的目标：用户点击了图表对象
    // Print("    *** 侦测到对象点击事件 (CHARTEVENT_OBJECT_CLICK) ***");
    // Print("    被点击对象名称 (sparam): ", sparam);

    // 检查是否点击了我们创建的趋势线
    // if (sparam == g_trendline_name)
    // {
    //     Print("    >>> 成功点击了我们的可交互趋势线！ <<<");
    //     // 此时您可以执行 DrawP1P2Fibonacci() 等自定义操作
    // }

    // --- 3. 模拟双击检查 ---
    /* 这种方式没有通过
    datetime current_time = TimeCurrent();
    Print("-->[KTarget_Finder5.mq4:308]: current_time: ", current_time);

    Print("-->[KTarget_Finder5.mq4:313]: LastClickTime: ", LastClickTime);

    long time_diff_ms = (current_time - LastClickTime) * 1000; // 转换为毫秒
    Print("-->[KTarget_Finder5.mq4:311]: time_diff_ms: ", time_diff_ms);
    */

    // --- 2. 检查是否点击了我们的矩形对象 ---
    // 矩形对象的名称应该以我们定义的 "Rect_B_" 或 "Rect_S_" 开头
    if (StringFind(object_name, "Rect_B_", 0) != -1 || StringFind(object_name, "Rect_S_", 0) != -1)
    {
        // 1. 获取当前系统启动以来的毫秒数
        ulong current_time_ms = GetTickCount();
        // Print("===>[KTarget_Finder5.mq4:320]: current_time_ms: ", current_time_ms);
        // Print("===>[KTarget_Finder5.mq4:321]: LastClickTime_ms: ", LastClickTime_ms);

        // 2. 计算毫秒差（直接相减就是毫秒数）
        // 注意：GetTickCount() 返回值可能循环，但对于 500ms 的短期差值是可靠的。
        ulong time_diff_ms = current_time_ms - LastClickTime_ms;
        // Print("===>[KTarget_Finder5.mq4:326]: time_diff_ms: ", time_diff_ms);

        if (time_diff_ms > 0 && time_diff_ms < DOUBLE_CLICK_TIMEOUT_MS)
        {
            Print(">>> DEBUG: Detected Double Click on Rectangle: ", sparam);

            // 1. 检查是否点击了我们的矩形，并解析名称
            if (ParseRectangleName(object_name, info))
            {
                // 2. 🚨 核心步骤：将绝对时间转换为当前 K 线索引 🚨

                // iBarShift 查找给定时间对应的 K 线索引。
                // false 参数表示精确匹配 K 线开盘时间。
                int current_P1_index = iBarShift(NULL, 0, info.P1_time, false);
                int current_P2_index = iBarShift(NULL, 0, info.P2_time, false);

                // 检查索引是否有效 (通常 >= 0)
                if (current_P1_index >= 0 && current_P2_index >= 0)
                {
                    Print("成功解析并转换时间到索引：P1索引=", current_P1_index, ", P2索引=", current_P2_index);

                    // 3. 调用 DrawP1P2Fibonacci 函数绘制斐波那契线
                    DrawP1P2Fibonacci(current_P1_index, current_P2_index, info.is_bullish);

                    // 绘制斐波高亮的反转区域
                    DrawFiboHighlightRectangles(current_P1_index, current_P2_index, info.is_bullish);

                    // 确保 Fibo 立即显示
                    // ChartRedraw(0);
                }
                else
                {
                    Print("错误: 无法找到匹配的 K 线索引，数据可能已过期或被移除。");
                }
            }

            // 强制重绘，以确保 Fibo 立即显示
            // ChartRedraw(0);

            // 重置 LastClickTime，避免三次点击被识别为双击 -- 第一次编写的时候 使用 LastClickTime 没有成功 所以注销了
            // LastClickTime = 0;

            LastClickTime_ms = 0;
        }
        else
        {
            // 记录第一次点击时间
            // LastClickTime = current_time;

            // 记录第一次点击时间 (必须大于 0，避免系统启动时记录 0)
            LastClickTime_ms = current_time_ms;
        }
    }
}

void HandleObjectDelete(string sparam)
{
    string deleted_name = sparam;
    // Print("--->[KTarget_Finder5.mq4:595]: deleted_name: ", deleted_name);

    // 1. 过滤：检查被删除的对象是否为我们指标绘制的 '主' 斐波那契线
    // 条件：a) 必须包含指标前缀 g_object_prefix
    //       b) 必须包含 "_Fibo_" (斐波那契主线的标记)
    //       c) 必须不包含 "_FiboHL_" (排除高亮矩形本身)
    if (StringFind(deleted_name, g_object_prefix) != -1 &&
        StringFind(deleted_name, "_Fibo_") != -1 &&
        StringFind(deleted_name, "_FiboHL_") == -1)
    {
        // 2. 提取唯一的锚点 ID 部分: [B/S]_[LongTimeID]

        // 查找 "_Fibo_" 在名称中的起始位置
        int start_pos = StringFind(deleted_name, "_Fibo_");

        if (start_pos != -1)
        {
            // 查找 "_Fibo_" 后面的下划线的位置，即 Fibo_ 后面的下划线
            int id_start = StringFind(deleted_name, "_", start_pos + 5);

            if (id_start != -1)
            {
                // 提取唯一的锚点 ID，例如 "B_2025_11_20_04_00_00"
                // 从下划线后一位开始截取到字符串末尾
                string unique_anchor_id = StringSubstr(deleted_name, id_start + 1);
                // Print("--->[KTarget_Finder5.mq4:627]: unique_anchor_id: ", unique_anchor_id);

                // 3. 遍历图表对象并删除所有包含此 ID 的关联子对象
                int total_objects = ObjectsTotal(0, 0);
                string obj_name;

                for (int i = total_objects - 1; i >= 0; i--)
                {
                    obj_name = ObjectName(0, i);
                    // Print("--->[KTarget_Finder5.mq4:636]: obj_name: ", obj_name);

                    // 检查条件：
                    // a) 必须是 FiboHL 相关的对象 (Rect_FiboHL_...)
                    // b) 必须包含被删除主线对象的唯一锚点 ID (unique_anchor_id)

                    if (StringFind(obj_name, "_FiboHL_") != -1 &&
                        StringFind(obj_name, unique_anchor_id) != -1)
                    {
                        // Print("--->[KTarget_Finder5.mq4:646]: obj_name: ", obj_name);
                        // 找到了关联的矩形或文本 (因为文本名称是矩形名称 + _TXT)
                        ObjectDelete(0, obj_name);
                    }
                }

                Print("INFO: Fibo主线手动删除，自动清理相关对象: ", deleted_name);
            }
        }
    }
}

void HandleProfit_Calc(string sparam, double dparam, long lparam)
{
   // 仅处理鼠标移动事件
   // if(id == CHARTEVENT_MOUSE_MOVE)
   // {
      // 🚨 核心修正：正确解析鼠标状态和修饰键 🚨
      // sparam 在 CHARTEVENT_MOUSE_MOVE 中是一个字符串，需要转换为整数
      // 位标志含义：
      // 1 = 左键按下
      // 2 = 右键按下
      // 4 = Shift 键按下
      // 8 = Ctrl 键按下
      // 16 = 中键按下
      
      int mouse_state = (int)StringToInteger(sparam);
      int curr_x = (int)lparam;
      int curr_y = (int)dparam;
      
      // 检测是否同时按下 Ctrl 键 + 鼠标左键
      bool ctrl_pressed = (mouse_state & 8) != 0;   // Ctrl 键
      bool left_pressed = (mouse_state & 1) != 0;   // 左键
      
      // 🚨 新增限制：必须同时按下 Ctrl + 左键才能启动计算功能 🚨
      // 这样可以避免误触发，用户需要主动按 Ctrl 键才能使用
      
      // 状态 1: Ctrl + 鼠标左键同时按下 (开始或正在拖拽)
      if(ctrl_pressed && left_pressed)
      {
         // 获取当前鼠标位置对应的价格和时间
         double curr_price;
         datetime curr_time;
         int sub_window;
         
         if(ChartXYToTimePrice(0, curr_x, curr_y, sub_window, curr_time, curr_price))
         {
            // 如果之前没有在拖拽，说明是刚按下的第一刻 (记录起点)
            if(!IsDragging)
            {
               IsDragging = true;
               Start_X = curr_x;
               Start_Y = curr_y;
               Start_Price = curr_price;
               Start_Time = curr_time;
               
               // 创建测距线对象
               CreateLineObject();
               // 创建显示文本对象
               CreateLabelObjects();
               ChartRedraw(0);
            }
            else
            {
               // 正在拖拽中，更新终点和数据
               UpdateCalculation(curr_time, curr_price, curr_x, curr_y);
            }
         }
      }
      // 状态 0: Ctrl 键或左键松开
      else
      {
         // 如果之前在拖拽，现在松开了，清理现场
         if(IsDragging)
         {
            IsDragging = false;
            DeleteProfit_CalcObjects();
            ChartRedraw(0);
         }
      }
   // }
}
//#endregion

//#region MARK: 公共/辅助的函数模块
/**
 * 根据当前图表周期和信号类型，返回高亮矩形应使用的颜色。
 * 颜色选择注重与黑色字体的高对比度。
 * @param is_bullish: 是否为看涨信号 (true=看涨, false=看跌)。
 * @return 最终确定的颜色常量。
 */
color GetHighlightColorByPeriod(bool is_bullish)
{
    color rect_color;
    int current_period = _Period; // 获取当前周期 (分钟数)
    
    // 1. 默认颜色
    rect_color = is_bullish ? HIGHLIGHT_COLOR_B : HIGHLIGHT_COLOR_S;

    // 2. 周期特定颜色覆盖
    if (current_period == PERIOD_D1) // 日周期
    {
        rect_color = is_bullish ? HIGHLIGHT_COLOR_D1_B : HIGHLIGHT_COLOR_D1_S;
    }
    else if (current_period == PERIOD_H4) // 4H 周期
    {
        rect_color = is_bullish ? HIGHLIGHT_COLOR_H4_B : HIGHLIGHT_COLOR_H4_S;
    }
    else if (current_period == PERIOD_H1) // 1H 周期
    {
        rect_color = is_bullish ? HIGHLIGHT_COLOR_H1_B : HIGHLIGHT_COLOR_H1_S;
    }
    // 3. 未来扩展区域 (例如 W1, MN1)
    else if (current_period == PERIOD_W1) // 周周期
    {
        rect_color = is_bullish ? HIGHLIGHT_COLOR_W1_B : HIGHLIGHT_COLOR_W1_S;
    }
    else if (current_period == PERIOD_MN1) // 月周期
    {
        rect_color = is_bullish ? HIGHLIGHT_COLOR_MN1_B : HIGHLIGHT_COLOR_MN1_S;
    }
    
    return rect_color;
}

/**
 * 根据当前图表周期 (_Period) 返回一组优化的参数。
 * 调优逻辑：在短周期增加K线数，在长周期减少K线数，以使时间范围更合理。
 */
TuningParameters GetTunedParameters_K7()
{
    TuningParameters p;
    
    // 设置默认值 (如果周期不匹配，则使用 M15/H1 附近的基准值)
    p.Scan_Range             = 500;
    p.Lookahead_Bottom       = 20;
    p.Lookback_Bottom        = 20;
    p.Lookahead_Top          = 20;
    p.Lookback_Top           = 20;
    p.Max_Signal_Lookforward = 20;
    p.Look_LLHH_Candles      = 3;
    
    // 根据周期动态调整参数
    switch (_Period)
    {
        case PERIOD_M1: // M1：波动极快，需要更多的K线来定义结构
            p.Scan_Range = 1440;
            p.Lookahead_Bottom = p.Lookback_Bottom = 30;
            p.Lookahead_Top = p.Lookback_Top = 30;

            p.Max_Signal_Lookforward = 30;
            p.Look_LLHH_Candles = 3;
            break;
            
        case PERIOD_M5: // M5：比 M1 稳定，但仍需比默认值大一些
            p.Scan_Range = 1440;
            p.Lookahead_Bottom = p.Lookback_Bottom = 25;
            p.Lookahead_Top = p.Lookback_Top = 25;

            p.Max_Signal_Lookforward = 25;
            p.Look_LLHH_Candles = 3;
            break;
            
        case PERIOD_M15: // M15：基准周期，略低于默认值，专注于近期结构
            p.Scan_Range = 1440;
            p.Lookahead_Bottom = p.Lookback_Bottom = 18;
            p.Lookahead_Top = p.Lookback_Top = 18;

            p.Max_Signal_Lookforward = 18;
            p.Look_LLHH_Candles = 3;
            break;
            
        case PERIOD_M30: // M30：更稳定，可进一步减少
            p.Scan_Range = 1440;
            p.Lookahead_Bottom = p.Lookback_Bottom = 15;
            p.Lookahead_Top = p.Lookback_Top = 15;

            p.Max_Signal_Lookforward = 15;
            p.Look_LLHH_Candles = 3;
            break;

        case PERIOD_H1: // H1：稳定的中周期
            p.Scan_Range = 500;
            p.Lookahead_Bottom = p.Lookback_Bottom = 12;
            p.Lookahead_Top = p.Lookback_Top = 12;

            p.Max_Signal_Lookforward = 24;
            p.Look_LLHH_Candles = 3;
            break;
            
        case PERIOD_H4: // H4：长周期开始，K线代表的市场意义大增
            // 扫描范围覆盖约 2-3 周
            p.Scan_Range = 500; 
            p.Lookahead_Bottom = p.Lookback_Bottom = 8;
            p.Lookahead_Top = p.Lookback_Top = 8;

            // 也就是说 前瞻扫描的范围可以大一些 没关系 这个地方 会影响锚点的标注 如果过小会导致一些锚点 无法识别出来
            // 按说 不应该影响锚点的 标注，这里代码可能还有一些问题
            // 按理论上讲 锚点标注的逻辑 不应该收到前瞻 信号扫描的 范围影响的
            // 是不是由于 低开K线的影响导致的标注呢？
            p.Max_Signal_Lookforward = 15;
            p.Look_LLHH_Candles = 3;
            break;
            
        // 开始调整 日周期 确认K前瞻 是5根 5天    
        case PERIOD_D1: // D1：日周期，遵循您的思路 (约 1-1.5 周)
            // 扫描范围覆盖约 1 个月
            p.Scan_Range = 500; 
            p.Lookahead_Bottom = p.Lookback_Bottom = 2;
            p.Lookahead_Top = p.Lookback_Top = 2;

            p.Max_Signal_Lookforward = 5;
            //周期越大 数值可以设置的越小 如果是2 至少保证 5日内的最高价和最低价
            p.Look_LLHH_Candles = 2;
            break;
            
        case PERIOD_W1: // W1：周周期，只需要关注最近几周或几个月的结构
            // 扫描范围覆盖约 3 个月
            p.Scan_Range = 500; 
            p.Lookahead_Bottom = p.Lookback_Bottom = 3;
            p.Lookahead_Top = p.Lookback_Top = 3;

            p.Max_Signal_Lookforward = 3;
            p.Look_LLHH_Candles = 3;
            break;
            
        // 月线调整为2    
        case PERIOD_MN1: // MN1：月周期，只需关注最近半年
            // 扫描范围覆盖约 6 个月
            p.Scan_Range = 300; 
            p.Lookahead_Bottom = p.Lookback_Bottom = 2;
            p.Lookahead_Top = p.Lookback_Top = 2;

            p.Max_Signal_Lookforward = 3;
            p.Look_LLHH_Candles = 2;
            break;
    }
    
    return p;
}

//+------------------------------------------------------------------+
//| 根据图表周期获取自适应 ATR 计算周期
//+------------------------------------------------------------------+
int GetAdaptiveATRPeriod(int period)
{
   switch(period)
   {
      case PERIOD_M1:  return 24; // M1 噪音大，使用更长周期平滑
      case PERIOD_M5:  return 20;
      case PERIOD_M15: return 14; // 标准周期
      case PERIOD_M30: return 14;
      case PERIOD_H1:  return 14;
      case PERIOD_H4:  return 20; // H4 波动较大，稍微平滑
      case PERIOD_D1:  return 20;
      case PERIOD_W1:  return 10; // 周线反应需灵敏
      default:         return 14;
   }
}

//+------------------------------------------------------------------+
//| 根据图表周期获取自适应 ATR 止损倍数 (Multiplier)
//+------------------------------------------------------------------+
double GetAdaptiveATRMultiplier(int period)
{
   switch(period)
   {
      case PERIOD_M1:  return 3.0; // M1 噪音极大，且点差影响大，给予宽倍数
      case PERIOD_M5:  return 2.5; // M5 仍属于高噪区
      case PERIOD_M15: return 2.0; // 短线标准
      case PERIOD_M30: return 1.8;
      case PERIOD_H1:  return 1.5; // H1 是非常标准的趋势周期，1.5倍较常用
      case PERIOD_H4:  return 1.2; // H4 波动值大，缩小倍数以优化盈亏比
      case PERIOD_D1:  return 1.0; // 日线一倍ATR通常已足够涵盖噪音
      case PERIOD_W1:  return 1.0;
      default:         return 1.5;
   }
}
//#endregion