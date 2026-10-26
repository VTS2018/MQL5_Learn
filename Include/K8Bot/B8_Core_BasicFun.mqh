//====================================================================
// 文件作用：KTarget_FinderBot8 的订单 Magic 家族、序号分配和订单归属判断。
// 本文件原样承载主文件中的 Magic 管理逻辑。
//====================================================================

//#region MARK: 模块--全局键名 持久化生效的核心
//====================================================================
// 状态持久化：构造全局变量键
//====================================================================
//string B8_BuildStateKey_OldV1(string item)
//{
//    return "B8STATE|"
//           + IntegerToString(AccountNumber()) + "|"
//           + _Symbol + "|"
//           + IntegerToString(MagicNumber) + "|"
//           + IntegerToString((int)ChartID()) + "|"
//           + item;
//}

// [旧代码保留] 精简版状态键构造函数：账号取后四位，品种取前三位，ChartID取模。
// string B8_BuildStateKey(string item)
// {
//     string account_text = IntegerToString(AccountNumber());
//     int account_length = StringLen(account_text);
//     int account_start = MathMax(0, account_length - 4);
//     string account_suffix = StringSubstr(account_text, account_start);
//     string symbol_prefix = StringSubstr(_Symbol, 0, 3);
//     int chart_id_mod = (int)(MathAbs(ChartID()) % 1000000);
//
//     return "B8S2|"
//            + account_suffix + "|"
//            + symbol_prefix + "|"
//            + IntegerToString(MagicNumber) + "|"
//            + IntegerToString(chart_id_mod) + "|"
//            + item;
// }

// [旧代码保留] 状态键使用完整品种名，并检查MQL4全局变量名称长度。
// string B8_BuildStateKey(string item)
// {
//     string account_text = IntegerToString(AccountNumber());
//     int account_length = StringLen(account_text);
//     int account_start = MathMax(0, account_length - 4);
//     string account_suffix = StringSubstr(account_text, account_start);
//     int chart_id_mod = (int)(MathAbs(ChartID()) % 1000000);
//
//     string state_key = "B8S2|"
//                        + account_suffix + "|"
//                        + _Symbol + "|"
//                        + IntegerToString(MagicNumber) + "|"
//                        + IntegerToString(chart_id_mod) + "|"
//                        + item;
//     int state_key_length = StringLen(state_key);
//
//     // Print("[Bot8][全局变量键长度] symbol=", _Symbol,
//     //       " item=", item,
//     //       " length=", state_key_length,
//     //       "/63 key=", state_key);
//     if (state_key_length > 63)
//         Print("[Bot8][全局变量键超长] symbol=", _Symbol,
//               " item=", item,
//               " length=", state_key_length,
//               ", MQL4限制=63");
//
//     return state_key;
// }

//#region MARK: 模块--新增代码集中说明
// 仅移除品种名末尾的 .cash，其他品种名保持原样。
string B8_GetStateKeySymbol()
{
    string state_symbol = _Symbol;
    string cash_suffix = ".cash";
    int suffix_length = StringLen(cash_suffix);
    int symbol_length = StringLen(state_symbol);

    if (symbol_length > suffix_length &&
        StringFind(state_symbol, cash_suffix, symbol_length - suffix_length) ==
            symbol_length - suffix_length)
    {
        state_symbol = StringSubstr(state_symbol, 0, symbol_length - suffix_length);
    }

    return state_symbol;
}

// [新增] 状态键使用去除末尾.cash后的品种名，并检查MQL4全局变量名称长度。
string B8_BuildStateKey(string item)
{
    string account_text = IntegerToString(AccountNumber());
    int account_length = StringLen(account_text);
    int account_start = MathMax(0, account_length - 4);
    string account_suffix = StringSubstr(account_text, account_start);
    string state_symbol = B8_GetStateKeySymbol();
    int chart_id_mod = (int)(MathAbs(ChartID()) % 1000000);

    string state_key = "B8S2|"
                       + account_suffix + "|"
                       + state_symbol + "|"
                       + IntegerToString(MagicNumber) + "|"
                       + IntegerToString(chart_id_mod) + "|"
                       + item;
    int state_key_length = StringLen(state_key);

    // Print("[Bot8][全局变量键长度] symbol=", state_symbol,
    //       " item=", item,
    //       " length=", state_key_length,
    //       "/63 key=", state_key);
    if (state_key_length > 63)
        Print("[Bot8][全局变量键超长] symbol=", state_symbol,
              " item=", item,
              " length=", state_key_length,
              ", MQL4限制=63");

    return state_key;
}
//#endregion

//#endregion

//#region MARK: 模块--订单身份唯一Magic模块
// 获取当前EA使用的基础家族Magic。
int B8_GetMagicFamily()
{
    return MagicNumber;
}

// 根据订单序号生成该订单专用的唯一Magic。
int B8_BuildOrderMagicBySeq(int order_seq)
{
    return B8_GetMagicFamily() * B8_MAGIC_SLOT_SIZE + order_seq;
}

// 从订单专用Magic中提取订单序号部分。
int B8_GetOrderMagicSeq(int order_magic)
{
    return MathAbs(order_magic) % B8_MAGIC_SLOT_SIZE;
}

// 判断指定Magic是否属于当前EA家族且序号有效。
bool B8_IsManagedOrderMagic(int order_magic)
{
    if (order_magic <= 0) return false;
    int seq = B8_GetOrderMagicSeq(order_magic);
    return (order_magic / B8_MAGIC_SLOT_SIZE == B8_GetMagicFamily() &&
            seq >= 1 && seq <= B8_MAGIC_MAX_SEQ);
}

// 判断当前选中的订单是否属于本品种和当前EA管理的订单。
bool B8_IsManagedOrder()
{
    return (OrderSymbol() == _Symbol && B8_IsManagedOrderMagic(OrderMagicNumber()));
}

// 检查指定订单Magic是否已经存在于持仓或历史订单中。
bool B8_IsOrderMagicUsed(int order_magic)
{
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (OrderSymbol() == _Symbol && OrderMagicNumber() == order_magic)
            return true;
    }

    for (int j = 0; j < OrdersHistoryTotal(); j++)
    {
        if (!OrderSelect(j, SELECT_BY_POS, MODE_HISTORY)) continue;
        if (OrderSymbol() == _Symbol && OrderMagicNumber() == order_magic)
            return true;
    }

    return false;
}

// 分配下一个尚未使用的订单序号，并生成对应的订单专用Magic。
bool B8_AllocateOrderMagic(int &order_magic)
{
    order_magic = 0;
    string key = B8_BuildStateKey("order_seq_next");
    int seq = 1;

    if (GlobalVariableCheck(key))
        seq = (int)MathRound(GlobalVariableGet(key));
    if (seq < 1) seq = 1;

    for (; seq <= B8_MAGIC_MAX_SEQ; seq++)
    {
        int candidate_magic = B8_BuildOrderMagicBySeq(seq);
        GlobalVariableSet(key, seq + 1);

        if (!B8_IsOrderMagicUsed(candidate_magic))
        {
            order_magic = candidate_magic;
            return true;
        }
    }

    Print("[Bot8][Magic分配] 订单序号已用尽，无法创建新的唯一订单Magic。 家族Magic:",
          B8_GetMagicFamily());
    return false;
}
//#endregion

//#region MARK: 模块--信号读取模块 指标和EA通信的核心
int g_B8_Mt7_Handle = INVALID_HANDLE;

void B8_ReleaseMt7Handle()
{
    if (g_B8_Mt7_Handle != INVALID_HANDLE)
    {
        IndicatorRelease(g_B8_Mt7_Handle);
        g_B8_Mt7_Handle = INVALID_HANDLE;
    }
}

bool B8_CreateMt7Handle()
{
    B8_ReleaseMt7Handle();

    if (!g_B8_Indicator_Snapshot.valid)
        return false;

    ResetLastError();
    g_B8_Mt7_Handle = iCustom(
        _Symbol,
        _Period,
        IndicatorName,
        true,
        false,
        g_B8_Indicator_Snapshot.scan_range,
        g_B8_Indicator_Snapshot.lookahead_bottom,
        g_B8_Indicator_Snapshot.lookback_bottom,
        g_B8_Indicator_Snapshot.lookahead_top,
        g_B8_Indicator_Snapshot.lookback_top,
        g_B8_Indicator_Snapshot.max_signal_lookforward,
        g_B8_Indicator_Snapshot.db_threshold_candles,
        g_B8_Indicator_Snapshot.llhh_candles,
        g_B8_Indicator_Snapshot.enable_ib_signal_marking,
        Indi_Anchor_Honest_Filter_Settings,
        g_B8_Indicator_Snapshot.find_target_model,
        g_B8_Indicator_Snapshot.enable_honest_filter,
        g_B8_Indicator_Snapshot.use_enhanced_p2_search,
        g_B8_Indicator_Snapshot.enhanced_p2_min_bars_between,
        g_B8_Indicator_Snapshot.use_strict_plevel_search,
        g_B8_Indicator_Snapshot.strict_plevel_min_bars_between,
        Indi_Anchor_Honest_Filter_Settings__End);

    if (g_B8_Mt7_Handle == INVALID_HANDLE)
    {
        Print("[Bot8][MT7] 无法创建 MQL5 指标句柄: ", IndicatorName,
              ", error=", GetLastError());
        return false;
    }

    return true;
}

double B8_ReadMt7Buffer(int buffer, int shift)
{
    if (g_B8_Mt7_Handle == INVALID_HANDLE || buffer < 0 || buffer > 3 || shift < 0)
        return (double)EMPTY_VALUE;

    double values[1];
    ResetLastError();
    int copied = CopyBuffer(g_B8_Mt7_Handle, buffer, shift, 1, values);
    if (copied != 1)
    {
        Print("[Bot8][MT7] CopyBuffer失败: buffer=", buffer,
              ", shift=", shift, ", copied=", copied,
              ", error=", GetLastError());
        return (double)EMPTY_VALUE;
    }

    return values[0];
}

//====================================================================
// 核心函数: B8_ReadSignalK1
// 读取 KTarget_Finder_MT7 指标在 K[1] 上的四个缓冲区数据
// Buffer 0: 看涨止损价 (BullishStopLossPrice)
// Buffer 1: 看跌止损价 (BearishStopLossPrice)
// Buffer 2: 看涨信号标志 (BullishReferencePrice, EMPTY_VALUE=无信号)
// Buffer 3: 看跌信号标志 (BearishReferencePrice, EMPTY_VALUE=无信号)
//====================================================================
// 使用 MT7 发布的最终参数读取 MQL5 指标句柄缓冲区；Smart Tuning 固定关闭。
double B8_ReadIndicatorBufferFromSnapshot(int buffer, int shift)
{
    return B8_ReadMt7Buffer(buffer, shift);
}

KBarSignal B8_ReadSignalK1(void)
{
    KBarSignal r;
    r.OpenTime              = iTime(_Symbol, _Period, 1);
    r.BullishStopLossPrice  = (double)EMPTY_VALUE;
    r.BearishStopLossPrice  = (double)EMPTY_VALUE;
    r.BullishReferencePrice = (double)EMPTY_VALUE;
    r.BearishReferencePrice = (double)EMPTY_VALUE;

    // 快照有效时优先使用 MT7 最终参数；下面的旧 iCustom 代码完整保留。
    if (g_B8_Indicator_Snapshot.valid)
    {
        r.BullishStopLossPrice  = B8_ReadIndicatorBufferFromSnapshot(0, 1);
        r.BearishStopLossPrice  = B8_ReadIndicatorBufferFromSnapshot(1, 1);
        r.BullishReferencePrice = B8_ReadIndicatorBufferFromSnapshot(2, 1);
        r.BearishReferencePrice = B8_ReadIndicatorBufferFromSnapshot(3, 1);
        return r;
    }

    return r;
}

// 独立读取指定历史K线的信号，不修改实时K[1]读取函数。
KBarSignal B8_ReadHistoricalSignal(int shift)
{
    KBarSignal r;
    r.OpenTime              = 0;
    r.BullishStopLossPrice  = (double)EMPTY_VALUE;
    r.BearishStopLossPrice  = (double)EMPTY_VALUE;
    r.BullishReferencePrice = (double)EMPTY_VALUE;
    r.BearishReferencePrice = (double)EMPTY_VALUE;

    if (shift < 1 || shift >= iBars(_Symbol, _Period))
        return r;

    r.OpenTime = iTime(_Symbol, _Period, shift);

    // 快照有效时使用 MT7 最终参数读取历史信号；下面的旧代码完整保留。
    if (g_B8_Indicator_Snapshot.valid)
    {
        r.BullishStopLossPrice  = B8_ReadIndicatorBufferFromSnapshot(0, shift);
        r.BearishStopLossPrice  = B8_ReadIndicatorBufferFromSnapshot(1, shift);
        r.BullishReferencePrice = B8_ReadIndicatorBufferFromSnapshot(2, shift);
        r.BearishReferencePrice = B8_ReadIndicatorBufferFromSnapshot(3, shift);
        return r;
    }

    return r;
}
//#endregion