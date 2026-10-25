//+------------------------------------------------------------------+
//|                                                      K_Utils.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 25.11.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//========================================================================
// ShortenObjectName: 辅助函数，移除对象名中的指定字符串以缩短名称 (修正版)
//========================================================================
/**
 * 从对象名称中移除 "arget_Finder" 字符串以缩短名称。
 * @param original_name: 完整的对象名称字符串。
 * @return (string) 缩短后的新名称。
 */
string ShortenObjectName(string original_name)
{
    // 定义要移除的子字符串
    string substring_to_remove = "arget_Finder";
    
    // 1. 创建一个字符串副本，因为 StringReplace 会通过引用直接修改它的第一个参数。
    string new_name = original_name; 
    
    // 2. 🚨 关键修正：直接调用 StringReplace，它会修改 new_name 变量，
    //    并且我们忽略它的 INT 类型返回值。
    StringReplace(new_name, substring_to_remove, "");
    
    // 3. 返回修改后的字符串。
    return new_name;
}

string ShortenObjectNameBot(string original_name)
{
    // 定义要移除的子字符串
    string substring_to_remove = "arget_FinderBot";
    
    // 1. 创建一个字符串副本，因为 StringReplace 会通过引用直接修改它的第一个参数。
    string new_name = original_name; 
    
    // 2. 🚨 关键修正：直接调用 StringReplace，它会修改 new_name 变量，
    //    并且我们忽略它的 INT 类型返回值。
    StringReplace(new_name, substring_to_remove, "");
    
    // 3. 返回修改后的字符串。
    return new_name;
}

//========================================================================
// 16. GetBarTimeID: 获取 K 线时间戳作为唯一对象标识符 (V2.07)
//========================================================================
/**
 * 根据 K 线索引获取其开盘时间，并格式化为 "YYYY_MM_DD_HH_MM_SS" 格式的字符串。
 * 如果索引无效，则使用当前服务器时间。
 * * @param bar_index 要获取时间的 K 线索引 (0 为当前 K线)
 * @return (string) 格式化后的唯一时间标识符，例如 "2025_11_24_06_00_00"
 */
/*
string GetBarTimeID_v1(int bar_index)
{
    datetime target_time;
    
    // --- 1. 确定目标时间 ---
    
    // 检查索引是否有效。如果索引无效 (例如 < 0)，则使用当前服务器时间。
    if (bar_index < 0 || bar_index >= iBars(_Symbol, _Period))
    {
        target_time = TimeCurrent();
        // Print("DEBUG: GetBarTimeID used TimeCurrent() due to invalid index: ", bar_index);
    }
    else
    {
        // 索引有效，使用 K 线的开盘时间
        target_time = iTime(_Symbol, _Period, bar_index);
    }
    
    // --- 2. 将 datetime 转换为结构体，方便格式化 ---
    MqlDateTime dt;
    TimeToStruct(target_time, dt);

    // --- 3. 构造 "YYYY_MM_DD_HH_MM_SS" 格式的字符串 ---
    
    string time_id_str = 
        // 年份 (例如 2025)
        IntegerToString(dt.year) + "_" + 
        
        // 月份 (确保两位数，例如 01)
        IntegerToString(dt.mon, 2, '0') + "_" + 
        
        // 日期 (确保两位数)
        IntegerToString(dt.day, 2, '0') + "_" + 
        
        // 小时 (确保两位数)
        IntegerToString(dt.hour, 2, '0') + "_" + 
        
        // 分钟 (确保两位数)
        IntegerToString(dt.min, 2, '0') + "_" + 
        
        // 秒钟 (确保两位数)
        IntegerToString(dt.sec, 2, '0');
        
    return time_id_str;
}
*/

//========================================================================
// 18. ParseRectangleName: 解析矩形名称，提取 K 线时间 (V3.00)
//========================================================================
/**
 * 从对象名称中解析出 K 线时间戳和看涨/看跌类型。
 * @param rect_name 被点击的矩形对象的完整名称
 * @param info 引用传递的结构体，用于存储解析结果
 * @return (bool) 成功解析返回 true，否则返回 false
 */
/*
bool ParseRectangleName_v1(const string rect_name, ParsedRectInfo &info)
{
    // 1. 检查类型并确定字符串起始位置
    int start_pos = -1;
    if (StringFind(rect_name, "Rect_B_", 0) != -1)
    {
        info.is_bullish = true;
        start_pos = StringFind(rect_name, "Rect_B_", 0) + StringLen("Rect_B_");
    }
    else if (StringFind(rect_name, "Rect_S_", 0) != -1)
    {
        info.is_bullish = false;
        start_pos = StringFind(rect_name, "Rect_S_", 0) + StringLen("Rect_S_");
    }
    else
    {
        // 无法识别的名称类型
        return false;
    }
    
    // 2. 提取 P1 和 P2 时间字符串
    string time_segment = StringSubstr(rect_name, start_pos);
    int separator_pos = StringFind(time_segment, "#", 0);
    
    if (separator_pos == -1) return false; // 缺少分隔符
    
    string P1_time_str = StringSubstr(time_segment, 0, separator_pos);
    string P2_time_str = StringSubstr(time_segment, separator_pos + 1);
    
    // 3. 将 "YYYY_MM_DD_HH_MM_SS" 格式转换成 MQL4 可识别的 "YYYY.MM.DD HH:MM:SS"
    string P1_standard_format = 
        StringSubstr(P1_time_str, 0, 4) + "." + // YYYY.
        StringSubstr(P1_time_str, 5, 2) + "." + // MM.
        StringSubstr(P1_time_str, 8, 2) + " " + // DD<space>
        StringSubstr(P1_time_str, 11, 2) + ":" + // HH:
        StringSubstr(P1_time_str, 14, 2) + ":" + // MM:
        StringSubstr(P1_time_str, 17, 2);       // SS
                                
    string P2_standard_format = 
        StringSubstr(P2_time_str, 0, 4) + "." + 
        StringSubstr(P2_time_str, 5, 2) + "." + 
        StringSubstr(P2_time_str, 8, 2) + " " + 
        StringSubstr(P2_time_str, 11, 2) + ":" + 
        StringSubstr(P2_time_str, 14, 2) + ":" + 
        StringSubstr(P2_time_str, 17, 2); 

    // 4. 执行转换
    info.P1_time = StringToTime(P1_standard_format);
    info.P2_time = StringToTime(P2_standard_format);
    
    if (info.P1_time == 0 || info.P2_time == 0) return false; // 转换失败
    
    return true;
}
*/

/*
//+------------------------------------------------------------------+
//| 辅助函数，将 _Period 的分钟数转换为 MT4 期望的位标志 9个默认周期
//+------------------------------------------------------------------+
int GetTimeframeFlag(int timeframe_period)
{
    // MQL4 中 _Period 返回的值是分钟数
    if (timeframe_period == 1)      return(1);       // M1
    if (timeframe_period == 5)      return(2);       // M5
    if (timeframe_period == 15)     return(4);       // M15
    if (timeframe_period == 30)     return(8);       // M30
    if (timeframe_period == 60)     return(16);      // H1
    if (timeframe_period == 240)    return(32);      // H4
    
    // 🚨 核心修正：避免使用 43200 这种数值作为位标志 🚨
    if (timeframe_period == 1440)   return(64);      // D1
    if (timeframe_period == 10080)  return(128);     // W1
    if (timeframe_period == 43200)  return(256);     // MN1 (月线)
    
    // 如果是自定义周期或其他未知周期，返回 0 (表示所有周期可见或不设置)
    return(0); 
}
*/

/**
 * 将 _Period 的分钟数值转换为对应的周期名称字符串 (例如 M1, H4, MN1)。
 * @param timeframe_period: _Period 的整数值 (例如 1, 60, 43200)。
 * @return 对应的周期名称字符串。
 */
/*
string GetTimeframeName(int timeframe_period)
{
    // MQL4 中 _Period 返回的值是分钟数
    if (timeframe_period == 1)      return("M1");
    if (timeframe_period == 5)      return("M5");
    if (timeframe_period == 15)     return("M15");
    if (timeframe_period == 30)     return("M30");
    if (timeframe_period == 60)     return("H1");
    if (timeframe_period == 240)    return("H4");
    
    // 日线、周线、月线 (使用它们的分钟数进行匹配)
    if (timeframe_period == 1440)   return("D1");
    if (timeframe_period == 10080)  return("W1");
    if (timeframe_period == 43200)  return("MN1"); // 月线
    
    // 如果是自定义周期或无法识别的周期
    return("Custom/Unknown"); 
}
*/

//#region MARK: 模块--MQL5周期可见性标志转换
/**
 * 将 MQL5 的 ENUM_TIMEFRAMES 周期转换为对象可见性标志。
 * @param timeframe_period: MQL5 周期值，例如 PERIOD_H4。
 * @return 对应的 OBJ_PERIOD_* 标志；未知周期返回 0。
 */
int GetTimeframeFlag(int timeframe_period)
{
    switch((ENUM_TIMEFRAMES)timeframe_period)
    {
        case PERIOD_M1:  return(OBJ_PERIOD_M1);
        case PERIOD_M2:  return(OBJ_PERIOD_M2);
        case PERIOD_M3:  return(OBJ_PERIOD_M3);
        case PERIOD_M4:  return(OBJ_PERIOD_M4);
        case PERIOD_M5:  return(OBJ_PERIOD_M5);
        case PERIOD_M6:  return(OBJ_PERIOD_M6);
        case PERIOD_M10: return(OBJ_PERIOD_M10);
        case PERIOD_M12: return(OBJ_PERIOD_M12);
        case PERIOD_M15: return(OBJ_PERIOD_M15);
        case PERIOD_M20: return(OBJ_PERIOD_M20);
        case PERIOD_M30: return(OBJ_PERIOD_M30);
        case PERIOD_H1:  return(OBJ_PERIOD_H1);
        case PERIOD_H2:  return(OBJ_PERIOD_H2);
        case PERIOD_H3:  return(OBJ_PERIOD_H3);
        case PERIOD_H4:  return(OBJ_PERIOD_H4);
        case PERIOD_H6:  return(OBJ_PERIOD_H6);
        case PERIOD_H8:  return(OBJ_PERIOD_H8);
        case PERIOD_H12: return(OBJ_PERIOD_H12);
        case PERIOD_D1:  return(OBJ_PERIOD_D1);
        case PERIOD_W1:  return(OBJ_PERIOD_W1);
        case PERIOD_MN1: return(OBJ_PERIOD_MN1);
    }

    return(0);
}
//#endregion

//#region MARK: 模块--MQL5周期名称转换
/**
 * 将 MQL5 的 ENUM_TIMEFRAMES 周期转换为周期名称。
 * @param timeframe_period: MQL5 周期值，例如 PERIOD_H4。
 * @return 对应的周期名称字符串。
 */
string GetTimeframeName(int timeframe_period)
{
    switch((ENUM_TIMEFRAMES)timeframe_period)
    {
        case PERIOD_M1:  return("M1");
        case PERIOD_M2:  return("M2");
        case PERIOD_M3:  return("M3");
        case PERIOD_M4:  return("M4");
        case PERIOD_M5:  return("M5");
        case PERIOD_M6:  return("M6");
        case PERIOD_M10: return("M10");
        case PERIOD_M12: return("M12");
        case PERIOD_M15: return("M15");
        case PERIOD_M20: return("M20");
        case PERIOD_M30: return("M30");
        case PERIOD_H1:  return("H1");
        case PERIOD_H2:  return("H2");
        case PERIOD_H3:  return("H3");
        case PERIOD_H4:  return("H4");
        case PERIOD_H6:  return("H6");
        case PERIOD_H8:  return("H8");
        case PERIOD_H12: return("H12");
        case PERIOD_D1:  return("D1");
        case PERIOD_W1:  return("W1");
        case PERIOD_MN1: return("MN1");
    }

    return("Custom/Unknown");
}
//#endregion

/**
 * 辅助函数：计算斐波那契水平线的价格
 * @param P1_price: 斐波那契起始价格 (Open[target_index])
 * @param P2_price: 斐波那契结束价格 (Close[P2_index])
 * @param level: 斐波那契级别 (例如 1.618)
 * @return 对应的价格水平
 */
double CalculateFiboPrice(double P1_price, double P2_price, double level)
{
    // 1.0
    // 斐波那契价格公式: P_level = P1 + level * (P2 - P1)
    // return P1_price + level * (P2_price - P1_price);

    // 2.0
    // 1. 计算原始斐波那契价格
    double price_diff = P2_price - P1_price;
    double raw_fibo_price = P1_price + price_diff * level;
    
    // 2. 🚨 优化细节：根据当前品种的精度进行四舍五入和修正 🚨
    // _Digits 变量自动返回当前图表品种的实际小数位数
    return NormalizeDouble(raw_fibo_price, _Digits);
}

//+------------------------------------------------------------------+
//| GetBarTimeID 再用
//+------------------------------------------------------------------+
string GetBarTimeID(int bar_index)
{
    datetime target_time;
    
    // --- 1. 确定目标时间 ---
    
    // 检查索引是否有效。如果索引无效 (例如 < 0)，则使用当前服务器时间。
    if (bar_index < 0 || bar_index >= iBars(_Symbol, _Period))
    {
        target_time = TimeCurrent();
        // Print("DEBUG: GetBarTimeID used TimeCurrent() due to invalid index: ", bar_index);
    }
    else
    {
        // 索引有效，使用 K 线的开盘时间
        target_time = iTime(_Symbol, _Period, bar_index);
    }
    
    // --- 2. 将 datetime 转换为结构体，方便格式化 ---
    MqlDateTime dt;
    TimeToStruct(target_time, dt);

    // --- 3. 🚨 修正：构造 "YYMMDD_HHMM" 格式的短字符串 ID 🚨
    
    // 使用 StringFormat 进行格式化，%02d 保证两位数并用 0 填充。
    // 去除了世纪年份、秒，以及所有的下划线，只保留一个分隔符。
    string time_id_str = 
        StringFormat("%02d%02d%02d_%02d%02d",
            dt.year % 100,      // 年份后两位 (YY)
            dt.mon,             // 月份 (MM)
            dt.day,             // 日期 (DD)
            dt.hour,            // 小时 (HH)
            dt.min);            // 分钟 (MM)
            
    // 示例返回: "251120_0400"
    return time_id_str;
}

//+------------------------------------------------------------------+
//| ParseRectangleName 再用
//+------------------------------------------------------------------+
bool ParseRectangleName(const string rect_name, ParsedRectInfo &info)
{
    // 1. 检查类型并确定字符串起始位置
    int start_pos = -1;
    // 注意：假设此函数仅用于解析 Rect_B_ / Rect_S_ 类型的矩形
    if (StringFind(rect_name, "Rect_B_", 0) != -1)
    {
        info.is_bullish = true;
        start_pos = StringFind(rect_name, "Rect_B_", 0) + StringLen("Rect_B_");
    }
    else if (StringFind(rect_name, "Rect_S_", 0) != -1)
    {
        info.is_bullish = false;
        start_pos = StringFind(rect_name, "Rect_S_", 0) + StringLen("Rect_S_");
    }
    else
    {
        // 无法识别的名称类型
        return false;
    }
    
    // 2. 提取 P1 和 P2 时间字符串
    string time_segment = StringSubstr(rect_name, start_pos);
    int separator_pos = StringFind(time_segment, "#", 0);
    
    if (separator_pos == -1) return false; // 缺少分隔符
    
    // P1_time_str = "251120_0400" (新的短格式)
    string P1_time_str = StringSubstr(time_segment, 0, separator_pos);
    // P2_time_str = "251120_0600" (新的短格式)
    string P2_time_str = StringSubstr(time_segment, separator_pos + 1);
    
    // -----------------------------------------------------------------
    // 🚨 修正 3：将 "YYMMDD_HHMM" 格式转换成 MQL4 可识别的 "YYYY.MM.DD HH:MM:SS" 格式 🚨
    // -----------------------------------------------------------------
    
    // 确保 P1 时间字符串长度符合预期 (11: YYMMDD_HHMM)
    if (StringLen(P1_time_str) != 11)
    {
        return false; 
    }
    
    // P1 Time String 转换：转换为 "20YY.MM.DD HH:MM:00"
    string P1_standard_format = 
        "20" + StringSubstr(P1_time_str, 0, 2) + "." +   // 20YY.
        StringSubstr(P1_time_str, 2, 2) + "." +          // MM.
        StringSubstr(P1_time_str, 4, 2) + " " +          // DD<space>
        StringSubstr(P1_time_str, 7, 2) + ":" +          // HH:
        StringSubstr(P1_time_str, 9, 2) + ":00";         // MM:00 (补充秒数)
        
    // P2 Time String 转换
    string P2_standard_format = "";
    if (StringLen(P2_time_str) == 11) // 检查 P2 是否也是新的短时间 ID 格式
    {
        P2_standard_format = 
            "20" + StringSubstr(P2_time_str, 0, 2) + "." + 
            StringSubstr(P2_time_str, 2, 2) + "." + 
            StringSubstr(P2_time_str, 4, 2) + " " + 
            StringSubstr(P2_time_str, 7, 2) + ":" + 
            StringSubstr(P2_time_str, 9, 2) + ":00";
    }
    
    // 4. 执行转换
    info.P1_time = StringToTime(P1_standard_format);
    
    if (StringLen(P2_standard_format) > 0)
    {
        info.P2_time = StringToTime(P2_standard_format);
    }
    else
    {
        // P2 不是时间格式 (例如可能是 Fibo Level)
        info.P2_time = 0; 
    }
    
    if (info.P1_time == 0) return false; // P1 转换失败则返回
    
    return true;
}

//+------------------------------------------------------------------+
//| 探测服务器时区函数 (GMT格式) - 优化版
//+------------------------------------------------------------------+
void DetectServerTimeZone()
{
    // 1. 获取服务器时间和GMT时间（尽量减少调用间隔）
    datetime server_time = TimeCurrent();  // 服务器当前时间
    datetime gmt_time = TimeGMT();         // 标准GMT时间
    
    // 2. 计算时区偏移（秒）
    int offset_seconds = (int)(server_time - gmt_time);
    
    // 3. 四舍五入到最近的整小时（处理59分钟这种情况）
    int offset_hours_raw = offset_seconds / 3600;
    int remainder_seconds = offset_seconds % 3600;
    
    // 如果余数超过30分钟（1800秒），则向上取整
    int offset_hours_rounded;
    if (MathAbs(remainder_seconds) >= 1800) // 30分钟
    {
        offset_hours_rounded = (offset_seconds > 0) ? (offset_hours_raw + 1) : (offset_hours_raw - 1);
    }
    else
    {
        offset_hours_rounded = offset_hours_raw;
    }
    
    // 4. 计算实际的小时和分钟（用于调试）
    int offset_hours = offset_seconds / 3600;
    int offset_minutes = (MathAbs(offset_seconds) % 3600) / 60;
    int offset_secs = MathAbs(offset_seconds) % 60;
    
    // 5. 构建GMT格式字符串（使用四舍五入后的值）
    string gmt_format;
    if (offset_hours_rounded == 0)
    {
        gmt_format = "GMT+0 (格林威治标准时间)";
    }
    else if (offset_hours_rounded > 0)
    {
        gmt_format = "GMT+" + IntegerToString(offset_hours_rounded);
    }
    else
    {
        gmt_format = "GMT" + IntegerToString(offset_hours_rounded);
    }
    
    // 6. 输出详细诊断信息
    Print("========================================");
    Print(">>> 服务器时区探测结果 <<<");
    Print("========================================");
    Print("服务器时间: ", TimeToString(server_time, TIME_DATE|TIME_SECONDS));
    Print("GMT 时间:   ", TimeToString(gmt_time, TIME_DATE|TIME_SECONDS));
    Print("原始偏移:   ", offset_seconds, " 秒 (", offset_hours, "h ", offset_minutes, "m ", offset_secs, "s)");
    Print("四舍五入:   ", offset_hours_rounded, " 小时");
    Print("GMT 格式:   ", gmt_format);
    
    // 7. 警告信息（如果偏移不是整小时）
    if (MathAbs(remainder_seconds) > 300) // 超过5分钟误差
    {
        Print("   警告: 服务器时区不是标准整点偏移！");
        Print("   可能原因: 1) 服务器时钟不准确  2) 函数调用时间差  3) 特殊时区");
        Print("   建议: 手动验证服务器时区设置，或联系券商确认。");
    }
    Print("========================================");
    
    // 8. 在图表上显示（可选，注释掉避免干扰）
    // Comment("服务器时区: ", gmt_format);
}