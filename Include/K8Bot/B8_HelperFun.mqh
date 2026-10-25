//+------------------------------------------------------------------+
//|                                                  B8_HelperFun.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//#region MARK: 模块--辅助函数模块01
//====================================================================
// 辅助函数: B8_GetSLTierByPoints
// 将止损距离(points)映射为分级档位
//====================================================================
ENUM_B8_SL_TIER B8_GetSLTierByPoints(double sl_points, int threshold_1, int threshold_2)
{
    if (sl_points < threshold_1) return B8_SL_TIER_SMALL;
    if (sl_points <= threshold_2) return B8_SL_TIER_MEDIUM;
    return B8_SL_TIER_LARGE;
}

//====================================================================
// 辅助函数: B8_SLTierToString
//====================================================================
string B8_SLTierToString(ENUM_B8_SL_TIER tier)
{
    if (tier == B8_SL_TIER_SMALL) return "SMALL";
    if (tier == B8_SL_TIER_MEDIUM) return "MEDIUM";
    return "LARGE";
}

string B8_RiskLevelText(double risk_percent)
{
    if (risk_percent < 1.0) return "低风险";
    if (risk_percent < 3.0) return "可接受";
    if (risk_percent < 5.0) return "注意";
    if (risk_percent < 10.0) return "高风险";
    return "极高风险";
}
//#endregion

//#region MARK: 模块--创建面板的控件辅助函数
// 根据行号生成订单列表按钮的唯一对象名称。
string B8_RuntimeOrderRowName(int row)
{
    return B8_RUNTIME_ORDER_ROW_PREFIX + IntegerToString(row);
}

// 将订单触发模式转换为面板显示文字。
string B8_RuntimeOrderModeText(ENUM_B8_ORDER_TRIGGER_MODE mode)
{
    return mode == B8_ORDER_TRIGGER_R ? "R倍数" : "固定点数";
}

// 将订单保护动作转换为面板显示文字。
string B8_RuntimeOrderActionText(ENUM_B8_ORDER_PROTECTION_MODE mode)
{
    if (mode == B8_ORDER_PARTIAL_ONLY) return "仅减仓";
    if (mode == B8_ORDER_BE_ONLY) return "仅保本";
    if (mode == B8_ORDER_CLOSE_ONLY) return "仅平仓";
    return "减仓后保本";
}
//#endregion

//#region MARK: 模块--辅助函数模块02
//====================================================================
// 参数面板：模式文本
//====================================================================
string B8_PositionModeText(ENUM_POS_SIZE_MODE mode)
{
    return (mode == POS_FIXED_LOT) ? "固定手数" : "以损定仓";
}

// 将入场方式转换为面板和日志使用的中文文本。
string B8_EntryModeText(ENUM_B8_ENTRY_MODE mode)
{
    if (mode == B8_ENTRY_PENDING) return "挂单";
    if (mode == B8_ENTRY_MARKET_AND_PENDING) return "市价+挂单";
    return "市价";
}

string B8_RiskModeText(ENUM_RISK_MODE mode)
{
    return (mode == RISK_FIXED_MONEY) ? "固定金额" : "余额百分比";
}

//====================================================================
// 参数面板/订单注释：周期文本
//====================================================================
string B8_TimeframeToText(int timeframe_minutes)
{
    if (timeframe_minutes == PERIOD_M1)   return "M1";
    if (timeframe_minutes == PERIOD_M2)   return "M2";
    if (timeframe_minutes == PERIOD_M3)   return "M3";
    if (timeframe_minutes == PERIOD_M4)   return "M4";
    if (timeframe_minutes == PERIOD_M5)   return "M5";
    if (timeframe_minutes == PERIOD_M6)   return "M6";
    if (timeframe_minutes == PERIOD_M10)  return "M10";
    if (timeframe_minutes == PERIOD_M12)  return "M12";
    if (timeframe_minutes == PERIOD_M15)  return "M15";
    if (timeframe_minutes == PERIOD_M20)  return "M20";
    if (timeframe_minutes == PERIOD_M30)  return "M30";
    if (timeframe_minutes == PERIOD_H1)   return "H1";
    if (timeframe_minutes == PERIOD_H2)   return "H2";
    if (timeframe_minutes == PERIOD_H3)   return "H3";
    if (timeframe_minutes == PERIOD_H4)   return "H4";
    if (timeframe_minutes == PERIOD_H6)   return "H6";
    if (timeframe_minutes == PERIOD_H8)   return "H8";
    if (timeframe_minutes == PERIOD_H12)  return "H12";
    if (timeframe_minutes == PERIOD_D1)   return "D1";
    if (timeframe_minutes == PERIOD_W1)   return "W1";
    if (timeframe_minutes == PERIOD_MN1)  return "MN1";

    return IntegerToString(timeframe_minutes) + "m";
}

//====================================================================
// 根据按钮对象名称返回对应的Fib数组下标。
// 返回值为0~7表示有效Fib位置，-1表示不是Fib位置按钮。
//====================================================================
int B8_PendingFibButtonIndex(const string object_name)
{
    if (object_name == B8_FIB_BTN_0120) return 0;
    if (object_name == B8_FIB_BTN_0214) return 1;
    if (object_name == B8_FIB_BTN_0236) return 2;
    if (object_name == B8_FIB_BTN_0382) return 3;
    if (object_name == B8_FIB_BTN_0500) return 4;
    if (object_name == B8_FIB_BTN_0618) return 5;
    if (object_name == B8_FIB_BTN_0786) return 6;
    if (object_name == B8_FIB_BTN_0880) return 7;
    return -1;
}
//#endregion

//#region MARK: 模块--辅助函数模块03
//====================================================================
// 辅助函数: B8_CountOpenPositions
// 统计当前品种本 EA（家族Magic）的未平仓订单数
//====================================================================
int B8_CountOpenPositions()
{
    int count = 0;
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if (B8_IsManagedOrder())
                count++;
        }
    }
    return count;
}
//#endregion