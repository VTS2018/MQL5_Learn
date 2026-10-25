//====================================================================
// 文件作用：Bot8 独立自动开启模块。
// 只负责监控触发条件和独立面板，不直接执行交易。
//====================================================================

//#region MARK: 模块--EA自动开启独立模块

enum ENUM_B8_AUTO_TRIGGER_TYPE
{
    B8_AUTO_TRIGGER_PRICE       = 0, // 实时Bid价格
    B8_AUTO_TRIGGER_CURRENT_BAR = 1, // 当前周期已收盘K[1]
    B8_AUTO_TRIGGER_SOURCE_BAR  = 2  // 指定周期已收盘K[1]
};

enum ENUM_B8_AUTO_COMPARE
{
    B8_AUTO_COMPARE_LESS        = 0, // 小于
    B8_AUTO_COMPARE_LESS_EQUAL  = 1, // 小于等于
    B8_AUTO_COMPARE_GREATER     = 2, // 大于
    B8_AUTO_COMPARE_GREATER_EQUAL = 3 // 大于等于
};

// 自动开启模块的启动参数。模块默认开启监控，但EA本身仍默认关闭。
string __AUTO_ACTIVATION__ = "--- EA自动开启模块（独立面板） ---";
bool   B8_AutoActivation_DefaultEnabled = false;   // 是否启动自动监控
ENUM_B8_AUTO_TRIGGER_TYPE B8_AutoActivation_TriggerType = B8_AUTO_TRIGGER_PRICE; // 自动触发条件类型：实时价格、当前周期K[1]或指定周期K[1]
ENUM_TIMEFRAMES B8_AutoActivation_SourceTimeframe = PERIOD_H1; // 指定周期K[1]触发模式使用的检测周期
double B8_AutoActivation_TriggerPrice = 4154.0; // 自动触发比较使用的目标价格
ENUM_B8_AUTO_COMPARE B8_AutoActivation_Compare = B8_AUTO_COMPARE_LESS_EQUAL; // 价格或K[1]收盘价的比较方式
ENUM_B8_TRADE_MODE B8_AutoActivation_TradeMode = B8_MODE_BUY_ONLY; // 自动触发后EA采用的交易模式
bool   B8_AutoActivation_ForceEAClosedOnInit = false; // 自动监控启动时强制EA先保持关闭

//#region MARK: 模块--
#define B8_AUTO_PANEL_BG       "B8_AutoActivation_BG"
#define B8_AUTO_PANEL_TITLE    "B8_AutoActivation_Title"
#define B8_AUTO_PANEL_STATUS   "B8_AutoActivation_Status"
#define B8_AUTO_PANEL_DETAIL1  "B8_AutoActivation_Detail1"
#define B8_AUTO_PANEL_DETAIL2  "B8_AutoActivation_Detail2"
#define B8_AUTO_PANEL_DETAIL3  "B8_AutoActivation_Detail3"
#define B8_AUTO_PANEL_ENABLE   "B8_AutoActivation_Enable"
#define B8_AUTO_PANEL_COLLAPSE "B8_AutoActivation_Collapse"
#define B8_AUTO_PANEL_TRIGGER_PRICE  "B8_AutoActivation_TriggerPrice"
#define B8_AUTO_PANEL_TRIGGER_REALTIME "B8_AutoActivation_TriggerRealtime"
#define B8_AUTO_PANEL_TRIGGER_CURRENT "B8_AutoActivation_TriggerCurrent"
#define B8_AUTO_PANEL_TRIGGER_SOURCE  "B8_AutoActivation_TriggerSource"
#define B8_AUTO_PANEL_TIMEFRAME       "B8_AutoActivation_Timeframe"
#define B8_AUTO_PANEL_COMPARE_LESS    "B8_AutoActivation_CompareLess"
#define B8_AUTO_PANEL_COMPARE_LESS_EQUAL "B8_AutoActivation_CompareLessEqual"
#define B8_AUTO_PANEL_COMPARE_GREATER "B8_AutoActivation_CompareGreater"
#define B8_AUTO_PANEL_COMPARE_GREATER_EQUAL "B8_AutoActivation_CompareGreaterEqual"
#define B8_AUTO_PANEL_MODE_NORMAL     "B8_AutoActivation_ModeNormal"
#define B8_AUTO_PANEL_MODE_BUY_ONLY   "B8_AutoActivation_ModeBuyOnly"
#define B8_AUTO_PANEL_MODE_SELL_ONLY  "B8_AutoActivation_ModeSellOnly"
#define B8_AUTO_PANEL_APPLY           "B8_AutoActivation_Apply"
#define B8_AUTO_PANEL_RESTORE         "B8_AutoActivation_Restore"
#define B8_AUTO_PANEL_RESET           "B8_AutoActivation_Reset"
#define B8_AUTO_PANEL_MESSAGE         "B8_AutoActivation_Message"
#define B8_AUTO_PANEL_TRIGGER_LABEL   "B8_AutoActivation_TriggerLabel"
#define B8_AUTO_PANEL_TIMEFRAME_LABEL "B8_AutoActivation_TimeframeLabel"
#define B8_AUTO_PANEL_COMPARE_LABEL   "B8_AutoActivation_CompareLabel"
#define B8_AUTO_PANEL_PRICE_LABEL     "B8_AutoActivation_PriceLabel"
#define B8_AUTO_PANEL_MODE_LABEL      "B8_AutoActivation_ModeLabel"
//#endregion

//#region MARK: 模块--
bool     g_B8_AutoActivation_Enabled = false; // 自动监控开关：true时OnTick持续检查触发条件
bool     g_B8_AutoActivation_Triggered = false; // 是否已经完成一次自动触发，防止重复开启
bool     g_B8_AutoActivation_Collapsed = false; // 自动开启面板是否处于折叠状态
datetime g_B8_AutoActivation_LastCheckedBar = 0; // 最近一次检查的K[1]时间，用于按已收盘K线去重
string   g_B8_AutoActivation_Status = "等待配置"; // 面板显示的模块运行状态
string   g_B8_AutoActivation_TriggerReason = ""; // 记录触发时的价格、周期和比较条件
bool     g_B8_AutoActivation_SettingsDirty = false; // 面板编辑值是否尚未点击“应用设置”
bool     g_B8_AutoActivation_EditFocused = false; // 触发价格输入框是否正在编辑，避免刷新覆盖输入
string   g_B8_AutoActivation_SettingsMessage = "设置已同步"; // 面板显示的设置操作提示
ENUM_B8_AUTO_TRIGGER_TYPE g_B8_AutoActivation_EditTriggerType = B8_AUTO_TRIGGER_PRICE; // 面板待编辑的触发类型
ENUM_TIMEFRAMES g_B8_AutoActivation_EditSourceTimeframe = PERIOD_H1; // 面板待编辑的指定检测周期
double   g_B8_AutoActivation_EditTriggerPrice = 4154.0; // 面板待编辑的触发价格
ENUM_B8_AUTO_COMPARE g_B8_AutoActivation_EditCompare = B8_AUTO_COMPARE_LESS_EQUAL; // 面板待编辑的比较方式
ENUM_B8_TRADE_MODE g_B8_AutoActivation_EditTradeMode = B8_MODE_BUY_ONLY; // 面板待编辑的触发后交易模式
//#endregion

//#region MARK: 模块--
string B8_AutoActivation_TriggerTypeText()
{
    if (B8_AutoActivation_TriggerType == B8_AUTO_TRIGGER_PRICE)
        return "实时价格";
    if (B8_AutoActivation_TriggerType == B8_AUTO_TRIGGER_CURRENT_BAR)
        return "当前周期K[1]收盘";
    return "指定周期K[1]收盘";
}

string B8_AutoActivation_CompareText()
{
    if (B8_AutoActivation_Compare == B8_AUTO_COMPARE_LESS)
        return "<";
    if (B8_AutoActivation_Compare == B8_AUTO_COMPARE_GREATER)
        return ">";
    if (B8_AutoActivation_Compare == B8_AUTO_COMPARE_GREATER_EQUAL)
        return ">=";
    return "<=";
}

string B8_AutoActivation_ModeText()
{
    if (B8_AutoActivation_TradeMode == B8_MODE_BUY_ONLY)
        return "只多";
    if (B8_AutoActivation_TradeMode == B8_MODE_SELL_ONLY)
        return "只空";
    return "普通";
}

int B8_AutoActivation_GetSourceTimeframe()
{
    if (B8_AutoActivation_TriggerType == B8_AUTO_TRIGGER_CURRENT_BAR)
        return Period();
    return (int)B8_AutoActivation_SourceTimeframe;
}

string B8_AutoActivation_TimeframeText(int timeframe)
{
    if (timeframe == PERIOD_CURRENT || timeframe == Period())
        return "当前周期";
    if (timeframe == PERIOD_M1)  return "M1";
    if (timeframe == PERIOD_M5)  return "M5";
    if (timeframe == PERIOD_M15) return "M15";
    if (timeframe == PERIOD_M30) return "M30";
    if (timeframe == PERIOD_H1)  return "H1";
    if (timeframe == PERIOD_H4)  return "H4";
    if (timeframe == PERIOD_D1)  return "D1";
    if (timeframe == PERIOD_W1)  return "W1";
    if (timeframe == PERIOD_MN1) return "MN1";
    return IntegerToString(timeframe);
}

bool B8_AutoActivation_CompareValue(double value)
{
    if (B8_AutoActivation_Compare == B8_AUTO_COMPARE_LESS)
        return value < B8_AutoActivation_TriggerPrice;
    if (B8_AutoActivation_Compare == B8_AUTO_COMPARE_GREATER)
        return value > B8_AutoActivation_TriggerPrice;
    if (B8_AutoActivation_Compare == B8_AUTO_COMPARE_GREATER_EQUAL)
        return value >= B8_AutoActivation_TriggerPrice;
    return value <= B8_AutoActivation_TriggerPrice;
}

string B8_AutoActivation_ConditionText()
{
    string condition = B8_AutoActivation_CompareText() + " " +
                       DoubleToString(B8_AutoActivation_TriggerPrice, _Digits);
    if (B8_AutoActivation_TriggerType == B8_AUTO_TRIGGER_PRICE)
        return "Bid " + condition;
    return B8_AutoActivation_TimeframeText(B8_AutoActivation_GetSourceTimeframe()) +
           " K[1]收盘 " + condition;
}
//#endregion

void B8_AutoActivation_Activate(double observed_value, string observed_text)
{
    g_B8_AutoActivation_Triggered = true;
    g_B8_AutoActivation_Status = "已触发";
    g_B8_AutoActivation_TriggerReason = observed_text + " " +
                                         B8_AutoActivation_CompareText() + " " +
                                         DoubleToString(B8_AutoActivation_TriggerPrice, _Digits);

    // [新增] 自动触发只开启EA和切换交易模式，不直接下单、不补检当前旧信号。
    g_Trade_Mode = B8_AutoActivation_TradeMode;
    g_EA_Enabled = true;
    g_manual_recheck_pending = false;
    g_manual_recheck_bar_time = Time[0];
    g_last_bar_time = Time[0];

    g_B8_AutoActivation_Enabled = false;
    B8_AutoActivation_UpdatePanel();
    B8_UpdatePanel();
    B8_UpdateSettingsPanel();
    ChartRedraw();

    Print("[Bot8][自动开启] 已触发。", g_B8_AutoActivation_TriggerReason,
          "，EA已开启，模式=", B8_AutoActivation_ModeText());
}

void B8_AutoActivation_OnTick()
{
    if (!g_B8_AutoActivation_Enabled || g_B8_AutoActivation_Triggered)
    {
        B8_AutoActivation_UpdatePanel();
        return;
    }

    // EA已经由用户手动开启时，自动模块只显示状态，不再改写交易模式。
    if (g_EA_Enabled)
    {
        g_B8_AutoActivation_Status = "EA已开启";
        B8_AutoActivation_UpdatePanel();
        return;
    }

    if (B8_AutoActivation_TriggerType == B8_AUTO_TRIGGER_PRICE)
    {
        RefreshRates();
        if (B8_AutoActivation_CompareValue(Bid))
            B8_AutoActivation_Activate(Bid, "Bid " + DoubleToString(Bid, _Digits));
        else
            B8_AutoActivation_UpdatePanel();
        return;
    }

    int source_timeframe = B8_AutoActivation_GetSourceTimeframe();
    if (iBars(_Symbol, (ENUM_TIMEFRAMES)source_timeframe) < 2)
    {
        g_B8_AutoActivation_Status = "等待K线数据";
        B8_AutoActivation_UpdatePanel();
        return;
    }

    datetime closed_bar_time = iTime(_Symbol, (ENUM_TIMEFRAMES)source_timeframe, 1);
    if (closed_bar_time <= 0 || closed_bar_time == g_B8_AutoActivation_LastCheckedBar)
    {
        B8_AutoActivation_UpdatePanel();
        return;
    }

    g_B8_AutoActivation_LastCheckedBar = closed_bar_time;
    double closed_price = iClose(_Symbol, (ENUM_TIMEFRAMES)source_timeframe, 1);
    if (B8_AutoActivation_CompareValue(closed_price))
    {
        B8_AutoActivation_Activate(
            closed_price,
            B8_AutoActivation_TimeframeText(source_timeframe) + " K[1]收盘 " +
            DoubleToString(closed_price, _Digits));
    }
    else
    {
        g_B8_AutoActivation_Status = "等待中";
        B8_AutoActivation_UpdatePanel();
    }
}

/*
void B8_AutoActivation_CreatePanel_Old()
{
    // Fibo面板BG_X=767、BG_W=252；本面板放在其左侧并保持右下角同一锚点。
    const int BG_X = 1029;
    const int BG_Y = 709;
    const int BG_W = 240;
    const int BG_H = 300;
    const int LABEL_X = BG_X - 11;

    B8_MakeRectLabel(B8_AUTO_PANEL_BG, BG_X, BG_Y, BG_W, BG_H,
                     C'24,31,42', C'75,105,135');
    B8_MakeLabel(B8_AUTO_PANEL_TITLE, LABEL_X, BG_Y - 15,
                 "EA自动开启", clrWhite, 10);
    B8_MakeLabel(B8_AUTO_PANEL_STATUS, LABEL_X, BG_Y - 42,
                 "", C'150,220,255', 9);
    B8_MakeLabel(B8_AUTO_PANEL_DETAIL1, LABEL_X, BG_Y - 65,
                 "", C'205,215,225', 8);
    B8_MakeLabel(B8_AUTO_PANEL_DETAIL2, LABEL_X, BG_Y - 85,
                 "", C'205,215,225', 8);
    B8_MakeLabel(B8_AUTO_PANEL_DETAIL3, LABEL_X, BG_Y - 105,
                 "", C'170,195,210', 8);
    B8_MakeButton(B8_AUTO_PANEL_ENABLE, LABEL_X, BG_Y - 135,
                  218, 24, "自动监控", clrForestGreen, clrWhite);
    B8_MakeButton(B8_AUTO_PANEL_COLLAPSE, LABEL_X, BG_Y - 166,
                  218, 22, "折叠面板", clrSlateGray, clrWhite);
}

void B8_AutoActivation_SetPanelVisible(bool visible)
{
    long value = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    string names[8];
    names[0] = B8_AUTO_PANEL_BG;
    names[1] = B8_AUTO_PANEL_TITLE;
    names[2] = B8_AUTO_PANEL_STATUS;
    names[3] = B8_AUTO_PANEL_DETAIL1;
    names[4] = B8_AUTO_PANEL_DETAIL2;
    names[5] = B8_AUTO_PANEL_DETAIL3;
    names[6] = B8_AUTO_PANEL_ENABLE;
    names[7] = B8_AUTO_PANEL_COLLAPSE;
    for (int i = 0; i < 8; i++)
        ObjectSetInteger(0, names[i], OBJPROP_TIMEFRAMES, value);
}

void B8_AutoActivation_SetExpanded_Old(bool expanded)
{
    g_B8_AutoActivation_Collapsed = !expanded;
    string names[6];
    names[0] = B8_AUTO_PANEL_STATUS;
    names[1] = B8_AUTO_PANEL_DETAIL1;
    names[2] = B8_AUTO_PANEL_DETAIL2;
    names[3] = B8_AUTO_PANEL_DETAIL3;
    names[4] = B8_AUTO_PANEL_ENABLE;
    names[5] = B8_AUTO_PANEL_COLLAPSE;
    long value = expanded ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    for (int i = 0; i < 6; i++)
        ObjectSetInteger(0, names[i], OBJPROP_TIMEFRAMES, value);

    ObjectSetString(0, B8_AUTO_PANEL_COLLAPSE, OBJPROP_TEXT,
                    expanded ? "折叠面板" : "展开面板");
    ObjectSetInteger(0, B8_AUTO_PANEL_BG, OBJPROP_YSIZE, expanded ? 300 : 36);
}

void B8_AutoActivation_UpdatePanel_Old()
{
    if (ObjectFind(0, B8_AUTO_PANEL_BG) < 0)
        return;

    string status = "模块：" + g_B8_AutoActivation_Status;
    if (!g_B8_AutoActivation_Enabled && !g_B8_AutoActivation_Triggered)
        status = "模块：已禁用";

    string detail1 = "条件：" + B8_AutoActivation_ConditionText();
    string detail2 = "触发后：" + B8_AutoActivation_ModeText() + "，仅开启EA";
    string detail3 = g_B8_AutoActivation_TriggerReason;
    if (detail3 == "")
        detail3 = "当前Bid：" + DoubleToString(Bid, _Digits);

    ObjectSetString(0, B8_AUTO_PANEL_STATUS, OBJPROP_TEXT, status);
    ObjectSetString(0, B8_AUTO_PANEL_DETAIL1, OBJPROP_TEXT, detail1);
    ObjectSetString(0, B8_AUTO_PANEL_DETAIL2, OBJPROP_TEXT, detail2);
    ObjectSetString(0, B8_AUTO_PANEL_DETAIL3, OBJPROP_TEXT, detail3);
    ObjectSetString(0, B8_AUTO_PANEL_ENABLE, OBJPROP_TEXT,
                    g_B8_AutoActivation_Enabled ? "停止自动监控" : "启动自动监控");
    ObjectSetInteger(0, B8_AUTO_PANEL_ENABLE, OBJPROP_BGCOLOR,
                     g_B8_AutoActivation_Enabled ? clrForestGreen : clrDimGray);
}

void B8_AutoActivation_Initialize_Old()
{
    g_B8_AutoActivation_Enabled = B8_AutoActivation_DefaultEnabled;
    g_B8_AutoActivation_Triggered = false;
    g_B8_AutoActivation_Collapsed = false;
    g_B8_AutoActivation_LastCheckedBar = 0;
    g_B8_AutoActivation_Status = g_B8_AutoActivation_Enabled ? "等待中" : "已禁用";
    g_B8_AutoActivation_TriggerReason = "";

    // [新增] 自动监控启动时，EA默认保持关闭；不改写旧的交易逻辑。
    if (g_B8_AutoActivation_Enabled && B8_AutoActivation_ForceEAClosedOnInit)
    {
        g_EA_Enabled = false;
        g_manual_recheck_pending = false;
    }

    B8_AutoActivation_CreatePanel_Old();
    B8_AutoActivation_SetExpanded_Old(true);
    B8_AutoActivation_UpdatePanel_Old();
}

void B8_AutoActivation_Deinitialize_Old()
{
    ObjectDelete(0, B8_AUTO_PANEL_BG);
    ObjectDelete(0, B8_AUTO_PANEL_TITLE);
    ObjectDelete(0, B8_AUTO_PANEL_STATUS);
    ObjectDelete(0, B8_AUTO_PANEL_DETAIL1);
    ObjectDelete(0, B8_AUTO_PANEL_DETAIL2);
    ObjectDelete(0, B8_AUTO_PANEL_DETAIL3);
    ObjectDelete(0, B8_AUTO_PANEL_ENABLE);
    ObjectDelete(0, B8_AUTO_PANEL_COLLAPSE);
}

bool B8_AutoActivation_HandleChartEvent_Old(const int id, const string object_name)
{
    if (id != CHARTEVENT_OBJECT_CLICK)
        return false;

    if (object_name == B8_AUTO_PANEL_ENABLE)
    {
        g_B8_AutoActivation_Enabled = !g_B8_AutoActivation_Enabled;
        if (g_B8_AutoActivation_Enabled && !g_B8_AutoActivation_Triggered)
            g_B8_AutoActivation_Status = "等待中";
        B8_AutoActivation_UpdatePanel_Old();
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        ChartRedraw();
        Print("[Bot8][自动开启] 模块 → ",
              (g_B8_AutoActivation_Enabled ? "开启" : "关闭"));
        return true;
    }

    if (object_name == B8_AUTO_PANEL_COLLAPSE)
    {
        B8_AutoActivation_SetExpanded_Old(g_B8_AutoActivation_Collapsed);
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        ChartRedraw();
        return true;
    }

    return false;
}
*/
//#endregion

//#region MARK: 模块--EA自动开启新交互面板

// 判断指定周期是否属于自动开启模块支持的标准周期。
bool B8_AutoActivation_IsValidTimeframe(ENUM_TIMEFRAMES timeframe)
{
    return timeframe == PERIOD_M1 || timeframe == PERIOD_M5 ||
           timeframe == PERIOD_M15 || timeframe == PERIOD_M30 ||
           timeframe == PERIOD_H1 || timeframe == PERIOD_H4 ||
           timeframe == PERIOD_D1 || timeframe == PERIOD_W1 ||
           timeframe == PERIOD_MN1;
}

// 按预设顺序切换到下一个支持的周期，超过月线后回到1分钟。
ENUM_TIMEFRAMES B8_AutoActivation_NextTimeframe(ENUM_TIMEFRAMES timeframe)
{
    if (timeframe == PERIOD_M1)  return PERIOD_M5;
    if (timeframe == PERIOD_M5)  return PERIOD_M15;
    if (timeframe == PERIOD_M15) return PERIOD_M30;
    if (timeframe == PERIOD_M30) return PERIOD_H1;
    if (timeframe == PERIOD_H1)  return PERIOD_H4;
    if (timeframe == PERIOD_H4)  return PERIOD_D1;
    if (timeframe == PERIOD_D1)  return PERIOD_W1;
    if (timeframe == PERIOD_W1)  return PERIOD_MN1;
    return PERIOD_M1;
}

// 设置自动开启面板对象在所有图表周期中的可见性。
void B8_AutoActivation_SetObjectVisible(string object_name, bool visible)
{
    ObjectSetInteger(0, object_name, OBJPROP_TIMEFRAMES,
                     visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
}

// 根据当前选项设置按钮颜色，并清除按钮的按下状态。
void B8_AutoActivation_SetButtonActive(string object_name, bool active)
{
    ObjectSetInteger(0, object_name, OBJPROP_BGCOLOR,
                     active ? clrDeepSkyBlue : clrDimGray);
    ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
}

// 将当前编辑中的触发条件和交易模式同步显示到面板控件。
void B8_AutoActivation_WriteEditControls()
{
    ObjectSetString(0, B8_AUTO_PANEL_TRIGGER_PRICE, OBJPROP_TEXT,
                    DoubleToString(g_B8_AutoActivation_EditTriggerPrice, _Digits));
    ObjectSetString(0, B8_AUTO_PANEL_TIMEFRAME, OBJPROP_TEXT,
                    "周期: " + B8_AutoActivation_TimeframeText(
                        (int)g_B8_AutoActivation_EditSourceTimeframe));

    B8_AutoActivation_SetButtonActive(
        B8_AUTO_PANEL_TRIGGER_REALTIME,
        g_B8_AutoActivation_EditTriggerType == B8_AUTO_TRIGGER_PRICE);
    B8_AutoActivation_SetButtonActive(
        B8_AUTO_PANEL_TRIGGER_CURRENT,
        g_B8_AutoActivation_EditTriggerType == B8_AUTO_TRIGGER_CURRENT_BAR);
    B8_AutoActivation_SetButtonActive(
        B8_AUTO_PANEL_TRIGGER_SOURCE,
        g_B8_AutoActivation_EditTriggerType == B8_AUTO_TRIGGER_SOURCE_BAR);

    B8_AutoActivation_SetButtonActive(
        B8_AUTO_PANEL_COMPARE_LESS,
        g_B8_AutoActivation_EditCompare == B8_AUTO_COMPARE_LESS);
    B8_AutoActivation_SetButtonActive(
        B8_AUTO_PANEL_COMPARE_LESS_EQUAL,
        g_B8_AutoActivation_EditCompare == B8_AUTO_COMPARE_LESS_EQUAL);
    B8_AutoActivation_SetButtonActive(
        B8_AUTO_PANEL_COMPARE_GREATER,
        g_B8_AutoActivation_EditCompare == B8_AUTO_COMPARE_GREATER);
    B8_AutoActivation_SetButtonActive(
        B8_AUTO_PANEL_COMPARE_GREATER_EQUAL,
        g_B8_AutoActivation_EditCompare == B8_AUTO_COMPARE_GREATER_EQUAL);

    B8_AutoActivation_SetButtonActive(
        B8_AUTO_PANEL_MODE_NORMAL,
        g_B8_AutoActivation_EditTradeMode == B8_MODE_NORMAL);
    B8_AutoActivation_SetButtonActive(
        B8_AUTO_PANEL_MODE_BUY_ONLY,
        g_B8_AutoActivation_EditTradeMode == B8_MODE_BUY_ONLY);
    B8_AutoActivation_SetButtonActive(
        B8_AUTO_PANEL_MODE_SELL_ONLY,
        g_B8_AutoActivation_EditTradeMode == B8_MODE_SELL_ONLY);
}

// 标记面板设置存在尚未应用的修改，并刷新提示信息。
void B8_AutoActivation_MarkSettingsDirty(string message)
{
    g_B8_AutoActivation_SettingsDirty = true;
    g_B8_AutoActivation_SettingsMessage = message;
    B8_AutoActivation_WriteEditControls();
    B8_AutoActivation_UpdatePanel();
}

// 校验并应用面板中的编辑设置到自动开启模块正式参数。
bool B8_AutoActivation_ApplyEditSettings()
{
    string price_text = ObjectGetString(0, B8_AUTO_PANEL_TRIGGER_PRICE,
                                         OBJPROP_TEXT);
    double trigger_price = StringToDouble(price_text);
    if (trigger_price <= 0.0)
    {
        g_B8_AutoActivation_SettingsMessage = "触发价格必须大于0";
        g_B8_AutoActivation_SettingsDirty = true;
        B8_AutoActivation_UpdatePanel();
        return false;
    }

    if (!B8_AutoActivation_IsValidTimeframe(
            g_B8_AutoActivation_EditSourceTimeframe))
    {
        g_B8_AutoActivation_SettingsMessage = "触发周期无效";
        g_B8_AutoActivation_SettingsDirty = true;
        B8_AutoActivation_UpdatePanel();
        return false;
    }

    g_B8_AutoActivation_EditTriggerPrice = NormalizeDouble(trigger_price, _Digits);
    B8_AutoActivation_TriggerType = g_B8_AutoActivation_EditTriggerType;
    B8_AutoActivation_SourceTimeframe = g_B8_AutoActivation_EditSourceTimeframe;
    B8_AutoActivation_TriggerPrice = g_B8_AutoActivation_EditTriggerPrice;
    B8_AutoActivation_Compare = g_B8_AutoActivation_EditCompare;
    B8_AutoActivation_TradeMode = g_B8_AutoActivation_EditTradeMode;

    g_B8_AutoActivation_LastCheckedBar = 0;
    g_B8_AutoActivation_SettingsDirty = false;
    g_B8_AutoActivation_SettingsMessage = "设置已应用";
    B8_AutoActivation_WriteEditControls();
    B8_AutoActivation_UpdatePanel();
    Print("[Bot8][自动开启] 面板设置已应用：",
          B8_AutoActivation_ConditionText(),
          "，触发后模式=", B8_AutoActivation_ModeText());
    return true;
}

// 放弃面板中的未应用修改，恢复为当前已生效的正式设置。
void B8_AutoActivation_RestoreEditSettings()
{
    g_B8_AutoActivation_EditTriggerType = B8_AutoActivation_TriggerType;
    g_B8_AutoActivation_EditSourceTimeframe = B8_AutoActivation_SourceTimeframe;
    g_B8_AutoActivation_EditTriggerPrice = B8_AutoActivation_TriggerPrice;
    g_B8_AutoActivation_EditCompare = B8_AutoActivation_Compare;
    g_B8_AutoActivation_EditTradeMode = B8_AutoActivation_TradeMode;
    g_B8_AutoActivation_SettingsDirty = false;
    g_B8_AutoActivation_SettingsMessage = "已恢复当前设置";
    B8_AutoActivation_WriteEditControls();
    B8_AutoActivation_UpdatePanel();
}

// 清除已触发状态，关闭EA并重新进入自动等待状态。
void B8_AutoActivation_ResetTrigger()
{
    g_B8_AutoActivation_Triggered = false;
    g_B8_AutoActivation_LastCheckedBar = 0;
    g_B8_AutoActivation_TriggerReason = "";
    g_B8_AutoActivation_Status = "等待中";
    g_B8_AutoActivation_Enabled = true;

    // 重新等待是明确的人工操作：关闭EA后重新等待新的触发条件。
    g_EA_Enabled = false;
    g_manual_recheck_pending = false;
    B8_AutoActivation_UpdatePanel();
    B8_UpdatePanel();
    B8_UpdateSettingsPanel();
    ChartRedraw();
    Print("[Bot8][自动开启] 已重置为等待状态，EA保持关闭。");
}

// 展开或折叠自动开启面板，并同步调整控件可见性和面板位置。
void B8_AutoActivation_SetExpanded_New(bool expanded)
{
    g_B8_AutoActivation_Collapsed = !expanded;

    string content_names[18];
    content_names[0]  = B8_AUTO_PANEL_DETAIL1;
    content_names[1]  = B8_AUTO_PANEL_DETAIL2;
    content_names[2]  = B8_AUTO_PANEL_DETAIL3;
    content_names[3]  = B8_AUTO_PANEL_TRIGGER_LABEL;
    content_names[4]  = B8_AUTO_PANEL_TRIGGER_REALTIME;
    content_names[5]  = B8_AUTO_PANEL_TRIGGER_CURRENT;
    content_names[6]  = B8_AUTO_PANEL_TRIGGER_SOURCE;
    content_names[7]  = B8_AUTO_PANEL_TIMEFRAME_LABEL;
    content_names[8]  = B8_AUTO_PANEL_TIMEFRAME;
    content_names[9]  = B8_AUTO_PANEL_COMPARE_LABEL;
    content_names[10] = B8_AUTO_PANEL_COMPARE_LESS;
    content_names[11] = B8_AUTO_PANEL_COMPARE_LESS_EQUAL;
    content_names[12] = B8_AUTO_PANEL_COMPARE_GREATER;
    content_names[13] = B8_AUTO_PANEL_COMPARE_GREATER_EQUAL;
    content_names[14] = B8_AUTO_PANEL_PRICE_LABEL;
    content_names[15] = B8_AUTO_PANEL_TRIGGER_PRICE;
    content_names[16] = B8_AUTO_PANEL_MODE_LABEL;
    content_names[17] = B8_AUTO_PANEL_MODE_NORMAL;

    for (int i = 0; i < 18; i++)
        B8_AutoActivation_SetObjectVisible(content_names[i], expanded);

    bool source_mode = g_B8_AutoActivation_EditTriggerType == B8_AUTO_TRIGGER_SOURCE_BAR;
    B8_AutoActivation_SetObjectVisible(B8_AUTO_PANEL_TIMEFRAME_LABEL,
                                       source_mode && expanded);
    B8_AutoActivation_SetObjectVisible(B8_AUTO_PANEL_TIMEFRAME,
                                       source_mode && expanded);

    string extra_names[9];
    extra_names[0] = B8_AUTO_PANEL_MODE_BUY_ONLY;
    extra_names[1] = B8_AUTO_PANEL_MODE_SELL_ONLY;
    extra_names[2] = B8_AUTO_PANEL_APPLY;
    extra_names[3] = B8_AUTO_PANEL_RESTORE;
    extra_names[4] = B8_AUTO_PANEL_RESET;
    extra_names[5] = B8_AUTO_PANEL_MESSAGE;
    extra_names[6] = B8_AUTO_PANEL_ENABLE;
    extra_names[7] = B8_AUTO_PANEL_PRICE_LABEL;
    extra_names[8] = B8_AUTO_PANEL_STATUS;
    for (int j = 0; j < 9; j++)
        B8_AutoActivation_SetObjectVisible(extra_names[j], expanded);

    ObjectSetString(0, B8_AUTO_PANEL_COLLAPSE, OBJPROP_TEXT,
                    expanded ? "折叠" : "展开");
    const int expanded_panel_y = 709;
    const int collapsed_panel_y = 40;
    const int panel_y = expanded ? expanded_panel_y : collapsed_panel_y;
    ObjectSetInteger(0, B8_AUTO_PANEL_BG, OBJPROP_YSIZE,
                     expanded ? 470 : 35);
    ObjectSetInteger(0, B8_AUTO_PANEL_BG, OBJPROP_YDISTANCE, panel_y);
    ObjectSetInteger(0, B8_AUTO_PANEL_TITLE, OBJPROP_YDISTANCE,
                     panel_y - 15);
    ObjectSetInteger(0, B8_AUTO_PANEL_COLLAPSE, OBJPROP_YDISTANCE,
                     panel_y - 5);
    B8_AutoActivation_SetObjectVisible(B8_AUTO_PANEL_TITLE, true);
    // B8_AutoActivation_SetObjectVisible(B8_AUTO_PANEL_STATUS, true);
    B8_AutoActivation_SetObjectVisible(B8_AUTO_PANEL_COLLAPSE, true);
}

// 创建自动开启面板的背景、标签、按钮和编辑框等图表对象。
void B8_AutoActivation_CreatePanel_New()
{
    const int BG_X = 1029;
    const int BG_Y = 709;
    const int BG_W = 240;
    const int BG_H = 470;
    const int LABEL_X = BG_X - 11;
    const int CONTROL_X = BG_X - 11;

    B8_MakeRectLabel(B8_AUTO_PANEL_BG, BG_X, BG_Y, BG_W, BG_H,
                     C'24,31,42', C'75,105,135');
    B8_MakeLabel(B8_AUTO_PANEL_TITLE, LABEL_X, BG_Y - 15,
                 "EA自动开启", clrWhite, 10);
    B8_MakeButton(B8_AUTO_PANEL_COLLAPSE, CONTROL_X - 146, BG_Y - 5,
                  70, 20, "折叠", clrSlateGray, clrWhite);
    B8_MakeLabel(B8_AUTO_PANEL_STATUS, LABEL_X, BG_Y - 43,
                 "", C'150,220,255', 9);
    B8_MakeLabel(B8_AUTO_PANEL_DETAIL1, LABEL_X, BG_Y - 64,
                 "", C'205,215,225', 8);
    B8_MakeLabel(B8_AUTO_PANEL_DETAIL2, LABEL_X, BG_Y - 82,
                 "", C'205,215,225', 8);
    B8_MakeLabel(B8_AUTO_PANEL_DETAIL3, LABEL_X, BG_Y - 100,
                 "", C'170,195,210', 8);

    B8_MakeLabel(B8_AUTO_PANEL_TRIGGER_LABEL, LABEL_X, BG_Y - 126,
                 "触发方式", C'190,205,220', 8);
    B8_MakeButton(B8_AUTO_PANEL_TRIGGER_REALTIME, CONTROL_X, BG_Y - 143,
                  68, 22, "实时价格", clrDimGray, clrWhite);
    B8_MakeButton(B8_AUTO_PANEL_TRIGGER_CURRENT, CONTROL_X - 73, BG_Y - 143,
                  68, 22, "当前K线", clrDimGray, clrWhite);
    B8_MakeButton(B8_AUTO_PANEL_TRIGGER_SOURCE, CONTROL_X - 146, BG_Y - 143,
                  68, 22, "指定K线", clrDimGray, clrWhite);

    B8_MakeLabel(B8_AUTO_PANEL_TIMEFRAME_LABEL, LABEL_X, BG_Y - 177,
                 "触发周期", C'190,205,220', 8);
    B8_MakeButton(B8_AUTO_PANEL_TIMEFRAME, CONTROL_X, BG_Y - 194,
                  218, 22, "周期: H1", clrDimGray, clrWhite);
    bool source_mode = g_B8_AutoActivation_EditTriggerType == B8_AUTO_TRIGGER_SOURCE_BAR;
    B8_AutoActivation_SetObjectVisible(B8_AUTO_PANEL_TIMEFRAME_LABEL,
                                       source_mode);
    B8_AutoActivation_SetObjectVisible(B8_AUTO_PANEL_TIMEFRAME,
                                       source_mode);

    B8_MakeLabel(B8_AUTO_PANEL_COMPARE_LABEL, LABEL_X, BG_Y - 228,
                 "比较条件", C'190,205,220', 8);
    B8_MakeButton(B8_AUTO_PANEL_COMPARE_LESS, CONTROL_X, BG_Y - 245,
                  50, 22, "<", clrDimGray, clrWhite);
    B8_MakeButton(B8_AUTO_PANEL_COMPARE_LESS_EQUAL, CONTROL_X - 53, BG_Y - 245,
                  50, 22, "<=", clrDimGray, clrWhite);
    B8_MakeButton(B8_AUTO_PANEL_COMPARE_GREATER, CONTROL_X - 106, BG_Y - 245,
                  50, 22, ">", clrDimGray, clrWhite);
    B8_MakeButton(B8_AUTO_PANEL_COMPARE_GREATER_EQUAL, CONTROL_X - 159, BG_Y - 245,
                  50, 22, ">=", clrDimGray, clrWhite);

    B8_MakeLabel(B8_AUTO_PANEL_PRICE_LABEL, LABEL_X, BG_Y - 279,
                 "触发价格", C'190,205,220', 8);
    B8_MakeEdit(B8_AUTO_PANEL_TRIGGER_PRICE, CONTROL_X, BG_Y - 296,
                218, 22, DoubleToString(g_B8_AutoActivation_EditTriggerPrice, _Digits));

    B8_MakeLabel(B8_AUTO_PANEL_MODE_LABEL, LABEL_X, BG_Y - 328,
                 "触发后模式", C'190,205,220', 8);
    B8_MakeButton(B8_AUTO_PANEL_MODE_NORMAL, CONTROL_X, BG_Y - 345,
                  68, 22, "普通", clrDimGray, clrWhite);
    B8_MakeButton(B8_AUTO_PANEL_MODE_BUY_ONLY, CONTROL_X - 73, BG_Y - 345,
                  68, 22, "只多", clrDimGray, clrWhite);
    B8_MakeButton(B8_AUTO_PANEL_MODE_SELL_ONLY, CONTROL_X - 146, BG_Y - 345,
                  68, 22, "只空", clrDimGray, clrWhite);

    B8_MakeLabel(B8_AUTO_PANEL_MESSAGE, LABEL_X, BG_Y - 375,
                 "设置已同步", C'170,195,210', 8);
    B8_MakeButton(B8_AUTO_PANEL_APPLY, CONTROL_X, BG_Y - 393,
                  68, 22, "应用设置", clrForestGreen, clrWhite);
    B8_MakeButton(B8_AUTO_PANEL_RESTORE, CONTROL_X - 73, BG_Y - 393,
                  68, 22, "恢复当前", clrSlateGray, clrWhite);
    B8_MakeButton(B8_AUTO_PANEL_RESET, CONTROL_X - 146, BG_Y - 393,
                  68, 22, "重新等待", clrDarkOrange, clrWhite);
    B8_MakeButton(B8_AUTO_PANEL_ENABLE, CONTROL_X, BG_Y - 420,
                  218, 22, "自动监控", clrForestGreen, clrWhite);
}

// 根据模块运行状态和编辑设置刷新自动开启面板显示内容。
void B8_AutoActivation_UpdatePanel_New()
{
    if (ObjectFind(0, B8_AUTO_PANEL_BG) < 0)
        return;

    string status = "模块：" + g_B8_AutoActivation_Status;
    if (!g_B8_AutoActivation_Enabled && !g_B8_AutoActivation_Triggered)
        status = "模块：已禁用";

    string detail1 = "已应用：" + B8_AutoActivation_ConditionText();
    string detail2 = "触发后：" + B8_AutoActivation_ModeText() + "，仅开启EA";
    string detail3 = g_B8_AutoActivation_TriggerReason;
    if (detail3 == "")
        detail3 = "当前Bid：" + DoubleToString(Bid, _Digits);

    ObjectSetString(0, B8_AUTO_PANEL_STATUS, OBJPROP_TEXT, status);
    ObjectSetString(0, B8_AUTO_PANEL_DETAIL1, OBJPROP_TEXT, detail1);
    ObjectSetString(0, B8_AUTO_PANEL_DETAIL2, OBJPROP_TEXT, detail2);
    ObjectSetString(0, B8_AUTO_PANEL_DETAIL3, OBJPROP_TEXT, detail3);
    ObjectSetString(0, B8_AUTO_PANEL_MESSAGE, OBJPROP_TEXT,
                    g_B8_AutoActivation_SettingsDirty
                    ? "有未应用修改: " + g_B8_AutoActivation_SettingsMessage
                    : g_B8_AutoActivation_SettingsMessage);
    ObjectSetString(0, B8_AUTO_PANEL_ENABLE, OBJPROP_TEXT,
                    g_B8_AutoActivation_Enabled ? "停止自动监控" : "启动自动监控");
    ObjectSetInteger(0, B8_AUTO_PANEL_ENABLE, OBJPROP_BGCOLOR,
                     g_B8_AutoActivation_Enabled ? clrForestGreen : clrDimGray);

    bool source_mode = g_B8_AutoActivation_EditTriggerType == B8_AUTO_TRIGGER_SOURCE_BAR;
    B8_AutoActivation_SetObjectVisible(B8_AUTO_PANEL_TIMEFRAME_LABEL,
                                       source_mode && !g_B8_AutoActivation_Collapsed);
    B8_AutoActivation_SetObjectVisible(B8_AUTO_PANEL_TIMEFRAME,
                                       source_mode && !g_B8_AutoActivation_Collapsed);

    if (!g_B8_AutoActivation_EditFocused)
        B8_AutoActivation_WriteEditControls();
}

// 自动开启面板更新的统一入口，转发到当前面板实现。
void B8_AutoActivation_UpdatePanel()
{
    B8_AutoActivation_UpdatePanel_New();
}

// 初始化自动开启模块状态，并创建、折叠和刷新自动开启面板。
void B8_AutoActivation_Initialize()
{
    g_B8_AutoActivation_Enabled = B8_AutoActivation_DefaultEnabled;
    g_B8_AutoActivation_Triggered = false;
    g_B8_AutoActivation_Collapsed = false;
    g_B8_AutoActivation_LastCheckedBar = 0;
    g_B8_AutoActivation_Status = g_B8_AutoActivation_Enabled ? "等待中" : "已禁用";
    g_B8_AutoActivation_TriggerReason = "";
    g_B8_AutoActivation_SettingsDirty = false;
    g_B8_AutoActivation_EditFocused = false;
    g_B8_AutoActivation_SettingsMessage = "设置已同步";

    g_B8_AutoActivation_EditTriggerType = B8_AutoActivation_TriggerType;
    g_B8_AutoActivation_EditSourceTimeframe = B8_AutoActivation_SourceTimeframe;
    g_B8_AutoActivation_EditTriggerPrice = B8_AutoActivation_TriggerPrice;
    g_B8_AutoActivation_EditCompare = B8_AutoActivation_Compare;
    g_B8_AutoActivation_EditTradeMode = B8_AutoActivation_TradeMode;

    if (g_B8_AutoActivation_Enabled && B8_AutoActivation_ForceEAClosedOnInit)
    {
        g_EA_Enabled = false;
        g_manual_recheck_pending = false;
    }

    B8_AutoActivation_CreatePanel_New();
    B8_AutoActivation_SetExpanded_New(false);
    B8_AutoActivation_WriteEditControls();
    B8_AutoActivation_UpdatePanel_New();
}

// 释放自动开启模块创建的全部图表对象。
void B8_AutoActivation_Deinitialize()
{
    string names[25];
    names[0] = B8_AUTO_PANEL_BG;
    names[1] = B8_AUTO_PANEL_TITLE;
    names[2] = B8_AUTO_PANEL_STATUS;
    names[3] = B8_AUTO_PANEL_DETAIL1;
    names[4] = B8_AUTO_PANEL_DETAIL2;
    names[5] = B8_AUTO_PANEL_DETAIL3;
    names[6] = B8_AUTO_PANEL_ENABLE;
    names[7] = B8_AUTO_PANEL_COLLAPSE;
    names[8] = B8_AUTO_PANEL_TRIGGER_PRICE;
    names[9] = B8_AUTO_PANEL_TRIGGER_REALTIME;
    names[10] = B8_AUTO_PANEL_TRIGGER_CURRENT;
    names[11] = B8_AUTO_PANEL_TRIGGER_SOURCE;
    names[12] = B8_AUTO_PANEL_TIMEFRAME;
    names[13] = B8_AUTO_PANEL_COMPARE_LESS;
    names[14] = B8_AUTO_PANEL_COMPARE_LESS_EQUAL;
    names[15] = B8_AUTO_PANEL_COMPARE_GREATER;
    names[16] = B8_AUTO_PANEL_COMPARE_GREATER_EQUAL;
    names[17] = B8_AUTO_PANEL_MODE_NORMAL;
    names[18] = B8_AUTO_PANEL_MODE_BUY_ONLY;
    names[19] = B8_AUTO_PANEL_MODE_SELL_ONLY;
    names[20] = B8_AUTO_PANEL_APPLY;
    names[21] = B8_AUTO_PANEL_RESTORE;
    names[22] = B8_AUTO_PANEL_RESET;
    names[23] = B8_AUTO_PANEL_MESSAGE;
    names[24] = B8_AUTO_PANEL_TRIGGER_LABEL;
    for (int i = 0; i < 25; i++)
        ObjectDelete(0, names[i]);
    ObjectDelete(0, B8_AUTO_PANEL_TIMEFRAME_LABEL);
    ObjectDelete(0, B8_AUTO_PANEL_COMPARE_LABEL);
    ObjectDelete(0, B8_AUTO_PANEL_PRICE_LABEL);
    ObjectDelete(0, B8_AUTO_PANEL_MODE_LABEL);
}

// 处理自动开启面板的点击、编辑结束和控件切换等图表事件。
bool B8_AutoActivation_HandleChartEvent(const int id, const string object_name)
{
    if (id == CHARTEVENT_OBJECT_CLICK &&
        object_name == B8_AUTO_PANEL_TRIGGER_PRICE)
    {
        g_B8_AutoActivation_EditFocused = true;
        return false;
    }

    if (id == CHARTEVENT_OBJECT_ENDEDIT &&
        object_name == B8_AUTO_PANEL_TRIGGER_PRICE)
    {
        string price_text = ObjectGetString(0, B8_AUTO_PANEL_TRIGGER_PRICE,
                                            OBJPROP_TEXT);
        double edited_price = StringToDouble(price_text);
        g_B8_AutoActivation_EditFocused = false;
        if (edited_price > 0.0)
        {
            g_B8_AutoActivation_EditTriggerPrice =
                NormalizeDouble(edited_price, _Digits);
            B8_AutoActivation_MarkSettingsDirty("价格待应用");
        }
        else
        {
            g_B8_AutoActivation_SettingsDirty = true;
            g_B8_AutoActivation_SettingsMessage = "触发价格必须大于0";
            B8_AutoActivation_UpdatePanel();
        }
        return true;
    }

    if (id != CHARTEVENT_OBJECT_CLICK)
        return false;

    if (object_name == B8_AUTO_PANEL_ENABLE)
    {
        g_B8_AutoActivation_Enabled = !g_B8_AutoActivation_Enabled;
        if (g_B8_AutoActivation_Enabled && !g_B8_AutoActivation_Triggered)
            g_B8_AutoActivation_Status = "等待中";
        B8_AutoActivation_UpdatePanel_New();
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        ChartRedraw();
        Print("[Bot8][自动开启] 模块 → ",
              (g_B8_AutoActivation_Enabled ? "开启" : "关闭"));
        return true;
    }

    if (object_name == B8_AUTO_PANEL_COLLAPSE)
    {
        B8_AutoActivation_SetExpanded_New(g_B8_AutoActivation_Collapsed);
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        ChartRedraw();
        return true;
    }

    if (object_name == B8_AUTO_PANEL_TRIGGER_PRICE ||
        object_name == B8_AUTO_PANEL_TRIGGER_REALTIME ||
        object_name == B8_AUTO_PANEL_TRIGGER_CURRENT ||
        object_name == B8_AUTO_PANEL_TRIGGER_SOURCE)
    {
        if (object_name == B8_AUTO_PANEL_TRIGGER_REALTIME)
            g_B8_AutoActivation_EditTriggerType = B8_AUTO_TRIGGER_PRICE;
        else if (object_name == B8_AUTO_PANEL_TRIGGER_CURRENT)
            g_B8_AutoActivation_EditTriggerType = B8_AUTO_TRIGGER_CURRENT_BAR;
        else
            g_B8_AutoActivation_EditTriggerType = B8_AUTO_TRIGGER_SOURCE_BAR;
        B8_AutoActivation_MarkSettingsDirty("触发方式待应用");
        return true;
    }

    if (object_name == B8_AUTO_PANEL_TIMEFRAME)
    {
        g_B8_AutoActivation_EditSourceTimeframe =
            B8_AutoActivation_NextTimeframe(
                g_B8_AutoActivation_EditSourceTimeframe);
        B8_AutoActivation_MarkSettingsDirty("触发周期待应用");
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        return true;
    }

    if (object_name == B8_AUTO_PANEL_COMPARE_LESS ||
        object_name == B8_AUTO_PANEL_COMPARE_LESS_EQUAL ||
        object_name == B8_AUTO_PANEL_COMPARE_GREATER ||
        object_name == B8_AUTO_PANEL_COMPARE_GREATER_EQUAL)
    {
        if (object_name == B8_AUTO_PANEL_COMPARE_LESS)
            g_B8_AutoActivation_EditCompare = B8_AUTO_COMPARE_LESS;
        else if (object_name == B8_AUTO_PANEL_COMPARE_LESS_EQUAL)
            g_B8_AutoActivation_EditCompare = B8_AUTO_COMPARE_LESS_EQUAL;
        else if (object_name == B8_AUTO_PANEL_COMPARE_GREATER)
            g_B8_AutoActivation_EditCompare = B8_AUTO_COMPARE_GREATER;
        else
            g_B8_AutoActivation_EditCompare = B8_AUTO_COMPARE_GREATER_EQUAL;
        B8_AutoActivation_MarkSettingsDirty("比较条件待应用");
        return true;
    }

    if (object_name == B8_AUTO_PANEL_MODE_NORMAL ||
        object_name == B8_AUTO_PANEL_MODE_BUY_ONLY ||
        object_name == B8_AUTO_PANEL_MODE_SELL_ONLY)
    {
        if (object_name == B8_AUTO_PANEL_MODE_NORMAL)
            g_B8_AutoActivation_EditTradeMode = B8_MODE_NORMAL;
        else if (object_name == B8_AUTO_PANEL_MODE_BUY_ONLY)
            g_B8_AutoActivation_EditTradeMode = B8_MODE_BUY_ONLY;
        else
            g_B8_AutoActivation_EditTradeMode = B8_MODE_SELL_ONLY;
        B8_AutoActivation_MarkSettingsDirty("触发后模式待应用");
        return true;
    }

    if (object_name == B8_AUTO_PANEL_APPLY)
    {
        g_B8_AutoActivation_EditFocused = false;
        B8_AutoActivation_ApplyEditSettings();
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        ChartRedraw();
        return true;
    }

    if (object_name == B8_AUTO_PANEL_RESTORE)
    {
        g_B8_AutoActivation_EditFocused = false;
        B8_AutoActivation_RestoreEditSettings();
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        ChartRedraw();
        return true;
    }

    if (object_name == B8_AUTO_PANEL_RESET)
    {
        B8_AutoActivation_ResetTrigger();
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        ChartRedraw();
        return true;
    }

    return false;
}
//#endregion