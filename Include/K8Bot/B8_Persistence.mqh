//====================================================================
// 文件作用：KTarget_FinderBot8 的全局变量持久化与运行状态恢复。
// 本文件原样承载主文件中的状态保存和加载逻辑。
//====================================================================

//#region MARK: 模块--参数的读取 复制 验证
//====================================================================
// 运行参数：从 input 捕获本次启动默认值
//====================================================================
void B8_LoadStartupSettings(B8_RUNTIME_SETTINGS &settings)
{
    settings.position_mode = Position_Mode;
    settings.fixed_lot = FixedLot;
    settings.risk_mode = Risk_Mode;
    settings.risk_value = Risk_Value;
    settings.equity_protect_enabled = Enable_Equity_Protect;
    settings.equity_target_percent = Equity_Target_Percent;
    settings.partial_close_percent = Partial_Close_Percent;
    settings.be_buffer_points = BE_Buffer_Points;
    // 账户级保护默认执行“减仓+保本”，不增加input参数。
    settings.equity_protection_action = B8_EQUITY_PARTIAL_BE;
}

void B8_LoadOrderStartupSettings(B8_ORDER_RUNTIME_SETTINGS &settings)
{
    settings.order_protection_enabled = Enable_Order_Protection_Default;
    settings.order_trigger_mode = Order_Trigger_Mode_Default;
    settings.order_trigger_points = Order_Trigger_Points_Default;
    settings.order_trigger_r = Order_Trigger_R_Default;
    settings.order_partial_close_percent = Order_Partial_Close_Percent_Default;
    settings.order_protection_mode = Order_Protection_Mode_Default;
    settings.order_be_buffer_points = Order_BE_Buffer_Points_Default;
}

void B8_LoadStartupPendingFibSettings()
{
    g_Pending_Fib_Selected[0] = Pending_Fib_0120;
    g_Pending_Fib_Selected[1] = Pending_Fib_0214;
    g_Pending_Fib_Selected[2] = Pending_Fib_0236;
    g_Pending_Fib_Selected[3] = Pending_Fib_0382;
    g_Pending_Fib_Selected[4] = Pending_Fib_0500;
    g_Pending_Fib_Selected[5] = Pending_Fib_0618;
    g_Pending_Fib_Selected[6] = Pending_Fib_0786;
    g_Pending_Fib_Selected[7] = Pending_Fib_0880;
    Enable_Fib_Risk_Allocation = true;
    Fib_Elimination_Policy = B8_KEEP_SHALLOW_FIB;
}

//====================================================================
// 运行参数：显式复制，便于后续扩展字段时统一维护
//====================================================================
void B8_CopySettings(const B8_RUNTIME_SETTINGS &source, B8_RUNTIME_SETTINGS &target)
{
    target.position_mode = source.position_mode;
    target.fixed_lot = source.fixed_lot;
    target.risk_mode = source.risk_mode;
    target.risk_value = source.risk_value;
    target.equity_protect_enabled = source.equity_protect_enabled;
    target.equity_target_percent = source.equity_target_percent;
    target.partial_close_percent = source.partial_close_percent;
    target.be_buffer_points = source.be_buffer_points;
    target.equity_protection_action = source.equity_protection_action;
}

void B8_CopyOrderSettings(const B8_ORDER_RUNTIME_SETTINGS &source,
                          B8_ORDER_RUNTIME_SETTINGS &target)
{
    target.order_protection_enabled = source.order_protection_enabled;
    target.order_trigger_mode = source.order_trigger_mode;
    target.order_trigger_points = source.order_trigger_points;
    target.order_trigger_r = source.order_trigger_r;
    target.order_partial_close_percent = source.order_partial_close_percent;
    target.order_protection_mode = source.order_protection_mode;
    target.order_be_buffer_points = source.order_be_buffer_points;
}

//====================================================================
// 运行参数：统一校验，任何一项非法都拒绝整组应用
//====================================================================
bool B8_ValidateSettings(const B8_RUNTIME_SETTINGS &settings, string &error_text)
{
    error_text = "";

    if (settings.position_mode != POS_FIXED_LOT && settings.position_mode != POS_RISK_BASED)
        error_text = "仓位模式无效";
    else if (settings.fixed_lot <= 0.0)
        error_text = "固定手数必须大于0";
    else if (settings.risk_mode != RISK_FIXED_MONEY && settings.risk_mode != RISK_PERCENTAGE)
        error_text = "风险模式无效";
    else if (settings.risk_value <= 0.0)
        error_text = "风险值必须大于0";
    else if (settings.risk_mode == RISK_PERCENTAGE &&
             (settings.risk_value < 0.1 || settings.risk_value > 10.0))
        error_text = "余额百分比风险值必须在0.1到10之间";
    else if (settings.risk_mode == RISK_FIXED_MONEY &&
             settings.risk_value > AccountBalance() * 0.25)
        error_text = "固定金额风险值不能超过账户余额的25%";
    else if (settings.equity_target_percent <= 0.0)
        error_text = "浮盈触发百分比必须大于0";
    else if (settings.partial_close_percent <= 0.0 || settings.partial_close_percent > 100.0)
        error_text = "减仓比例必须在0到100之间";
    else if (settings.be_buffer_points < 0)
        error_text = "保本缓冲点数不能小于0";
    else if (settings.equity_protection_action != B8_EQUITY_PARTIAL_BE &&
             settings.equity_protection_action != B8_EQUITY_CLOSE_ONLY)
        error_text = "账户保护动作无效";

    return (error_text == "");
}

bool B8_ValidateOrderSettings(const B8_ORDER_RUNTIME_SETTINGS &settings,
                              string &error_text)
{
    error_text = "";

    if (settings.order_trigger_mode != B8_ORDER_TRIGGER_POINTS &&
        settings.order_trigger_mode != B8_ORDER_TRIGGER_R)
        error_text = "订单触发模式无效";
    else if (settings.order_trigger_points <= 0.0)
        error_text = "订单触发点数必须大于0";
    else if (settings.order_trigger_r <= 0.0)
        error_text = "订单触发R必须大于0";
    else if (settings.order_partial_close_percent <= 0.0 ||
             settings.order_partial_close_percent >= 100.0)
        error_text = "单笔减仓比例必须大于0且小于100";
    else if (settings.order_protection_mode < B8_ORDER_PARTIAL_ONLY ||
             settings.order_protection_mode > B8_ORDER_CLOSE_ONLY)
        error_text = "订单协作模式无效";
    else if (settings.order_be_buffer_points < 0)
        error_text = "订单保本缓冲不能小于0";

    return (error_text == "");
}
//#endregion

//#region MARK: 模块--参数的应用设置
//====================================================================
// 运行参数：统一应用入口（输入框与预设按钮共用）
//====================================================================
bool B8_ApplyEditSettings(string source_name)
{
    string error_text = "";
    if (!B8_ValidateSettings(g_Edit_Settings, error_text))
    {
        Print("[Bot8][参数应用失败] 来源:", source_name, " 原因:", error_text);
        return false;
    }

    B8_CopySettings(g_Edit_Settings, g_Runtime_Settings);
    g_Settings_Dirty = false;
    B8_SaveRuntimeSettings();
    B8_UpdateEquityTargetVisual();

    Print("[Bot8][参数已应用] 来源:", source_name,
          " 仓位模式:", EnumToString(g_Runtime_Settings.position_mode),
          " 固定手数:", DoubleToString(g_Runtime_Settings.fixed_lot, 2),
          " 风险模式:", EnumToString(g_Runtime_Settings.risk_mode),
          " 风险值:", DoubleToString(g_Runtime_Settings.risk_value, 2),
          " 浮盈保护:", (g_Runtime_Settings.equity_protect_enabled ? "ON" : "OFF"),
          " 触发:", DoubleToString(g_Runtime_Settings.equity_target_percent, 2), "%",
          " 减仓:", DoubleToString(g_Runtime_Settings.partial_close_percent, 2), "%",
          " 保本缓冲:", IntegerToString(g_Runtime_Settings.be_buffer_points));
    return true;
}

bool B8_ApplyOrderEditSettings(string source_name)
{
    string error_text = "";
    if (!B8_ValidateOrderSettings(g_Order_Edit_Settings, error_text))
    {
        Print("[Bot8][订单级参数应用失败] 来源:", source_name, " 原因:", error_text);
        return false;
    }

    B8_CopyOrderSettings(g_Order_Edit_Settings, g_Order_Runtime_Settings);
    g_Order_Settings_Dirty = false;
    B8_SaveOrderRuntimeSettings();

    Print("[Bot8][订单级参数已应用] 来源:", source_name,
          " 订单保护:", (g_Order_Runtime_Settings.order_protection_enabled ? "ON" : "OFF"),
          " 触发:", (g_Order_Runtime_Settings.order_trigger_mode == B8_ORDER_TRIGGER_R
                     ? DoubleToString(g_Order_Runtime_Settings.order_trigger_r, 2) + "R"
                     : DoubleToString(g_Order_Runtime_Settings.order_trigger_points, 0) + "点"),
          " 单笔减仓:", DoubleToString(g_Order_Runtime_Settings.order_partial_close_percent, 1), "%");
    return true;
}
//#endregion

//#region MARK: 模块--参数的持久化
//====================================================================
// 运行参数：持久化当前生效值
//====================================================================
void B8_SaveRuntimeSettings()
{
    GlobalVariableSet(B8_BuildStateKey("settings_version"), 1.0);
    GlobalVariableSet(B8_BuildStateKey("position_mode"), (double)g_Runtime_Settings.position_mode);
    GlobalVariableSet(B8_BuildStateKey("fixed_lot"), g_Runtime_Settings.fixed_lot);
    GlobalVariableSet(B8_BuildStateKey("risk_mode"), (double)g_Runtime_Settings.risk_mode);
    GlobalVariableSet(B8_BuildStateKey("risk_value"), g_Runtime_Settings.risk_value);
    GlobalVariableSet(B8_BuildStateKey("equity_protect"), g_Runtime_Settings.equity_protect_enabled ? 1.0 : 0.0);
    GlobalVariableSet(B8_BuildStateKey("equity_target_pct"), g_Runtime_Settings.equity_target_percent);
    GlobalVariableSet(B8_BuildStateKey("partial_close_pct"), g_Runtime_Settings.partial_close_percent);
    GlobalVariableSet(B8_BuildStateKey("be_buffer_points"), (double)g_Runtime_Settings.be_buffer_points);
    GlobalVariableSet(B8_BuildStateKey("equity_protect_action"),
                      (double)g_Runtime_Settings.equity_protection_action);
}

void B8_SaveOrderRuntimeSettings()
{
    GlobalVariableSet(B8_BuildStateKey("order_protection"), g_Order_Runtime_Settings.order_protection_enabled ? 1.0 : 0.0);
    GlobalVariableSet(B8_BuildStateKey("order_trigger_mode"), (double)g_Order_Runtime_Settings.order_trigger_mode);
    GlobalVariableSet(B8_BuildStateKey("order_trigger_points"), g_Order_Runtime_Settings.order_trigger_points);
    GlobalVariableSet(B8_BuildStateKey("order_trigger_r"), g_Order_Runtime_Settings.order_trigger_r);
    GlobalVariableSet(B8_BuildStateKey("order_partial_close_pct"), g_Order_Runtime_Settings.order_partial_close_percent);
    GlobalVariableSet(B8_BuildStateKey("order_protection_mode"), (double)g_Order_Runtime_Settings.order_protection_mode);
    GlobalVariableSet(B8_BuildStateKey("order_be_buffer_points"), (double)g_Order_Runtime_Settings.order_be_buffer_points);
}

void B8_SavePendingFibSettings()
{
    GlobalVariableSet(B8_BuildStateKey("pending_fib_version"), 1.0);
    GlobalVariableSet(B8_BuildStateKey("pending_fib_0120"), g_Pending_Fib_Selected[0] ? 1.0 : 0.0);
    GlobalVariableSet(B8_BuildStateKey("pending_fib_0214"), g_Pending_Fib_Selected[1] ? 1.0 : 0.0);
    GlobalVariableSet(B8_BuildStateKey("pending_fib_0236"), g_Pending_Fib_Selected[2] ? 1.0 : 0.0);
    GlobalVariableSet(B8_BuildStateKey("pending_fib_0382"), g_Pending_Fib_Selected[3] ? 1.0 : 0.0);
    GlobalVariableSet(B8_BuildStateKey("pending_fib_0500"), g_Pending_Fib_Selected[4] ? 1.0 : 0.0);
    GlobalVariableSet(B8_BuildStateKey("pending_fib_0618"), g_Pending_Fib_Selected[5] ? 1.0 : 0.0);
    GlobalVariableSet(B8_BuildStateKey("pending_fib_0786"), g_Pending_Fib_Selected[6] ? 1.0 : 0.0);
    GlobalVariableSet(B8_BuildStateKey("pending_fib_0880"), g_Pending_Fib_Selected[7] ? 1.0 : 0.0);
}

void B8_SaveFibRuntimeSettings()
{
    GlobalVariableSet(B8_BuildStateKey("fib_risk_allocation"),
                      Enable_Fib_Risk_Allocation ? 1.0 : 0.0);
    GlobalVariableSet(B8_BuildStateKey("fib_elimination_policy"),
                      (double)Fib_Elimination_Policy);
}

//====================================================================
// 运行参数：存在持久化状态时覆盖 input 启动值
//====================================================================
void B8_LoadPersistedRuntimeSettings()
{
    string version_key = B8_BuildStateKey("settings_version");
    if (!GlobalVariableCheck(version_key)) return;

    string key = B8_BuildStateKey("position_mode");
    if (GlobalVariableCheck(key))
        g_Runtime_Settings.position_mode = (ENUM_POS_SIZE_MODE)(int)MathRound(GlobalVariableGet(key));

    key = B8_BuildStateKey("fixed_lot");
    if (GlobalVariableCheck(key))
        g_Runtime_Settings.fixed_lot = GlobalVariableGet(key);

    key = B8_BuildStateKey("risk_mode");
    if (GlobalVariableCheck(key))
        g_Runtime_Settings.risk_mode = (ENUM_RISK_MODE)(int)MathRound(GlobalVariableGet(key));

    key = B8_BuildStateKey("risk_value");
    if (GlobalVariableCheck(key))
        g_Runtime_Settings.risk_value = GlobalVariableGet(key);

    key = B8_BuildStateKey("equity_protect");
    if (GlobalVariableCheck(key))
        g_Runtime_Settings.equity_protect_enabled = (GlobalVariableGet(key) > 0.5);

    key = B8_BuildStateKey("equity_target_pct");
    if (GlobalVariableCheck(key))
        g_Runtime_Settings.equity_target_percent = GlobalVariableGet(key);

    key = B8_BuildStateKey("partial_close_pct");
    if (GlobalVariableCheck(key))
        g_Runtime_Settings.partial_close_percent = GlobalVariableGet(key);

    key = B8_BuildStateKey("be_buffer_points");
    if (GlobalVariableCheck(key))
        g_Runtime_Settings.be_buffer_points = (int)MathRound(GlobalVariableGet(key));

    key = B8_BuildStateKey("equity_protect_action");
    if (GlobalVariableCheck(key))
        g_Runtime_Settings.equity_protection_action =
            (ENUM_B8_EQUITY_PROTECTION_ACTION)(int)MathRound(GlobalVariableGet(key));

    key = B8_BuildStateKey("entry_mode");
    if (GlobalVariableCheck(key))
    {
        int entry_mode = (int)MathRound(GlobalVariableGet(key));
        if (entry_mode >= B8_ENTRY_MARKET && entry_mode <= B8_ENTRY_MARKET_AND_PENDING)
            g_Runtime_Entry_Mode = (ENUM_B8_ENTRY_MODE)entry_mode;
    }

}

void B8_LoadPersistedOrderSettings()
{
    string key = B8_BuildStateKey("order_protection");
    if (GlobalVariableCheck(key))
        g_Order_Runtime_Settings.order_protection_enabled = (GlobalVariableGet(key) > 0.5);

    key = B8_BuildStateKey("order_trigger_mode");
    if (GlobalVariableCheck(key))
        g_Order_Runtime_Settings.order_trigger_mode = (ENUM_B8_ORDER_TRIGGER_MODE)(int)MathRound(GlobalVariableGet(key));

    key = B8_BuildStateKey("order_trigger_points");
    if (GlobalVariableCheck(key))
        g_Order_Runtime_Settings.order_trigger_points = GlobalVariableGet(key);

    key = B8_BuildStateKey("order_trigger_r");
    if (GlobalVariableCheck(key))
        g_Order_Runtime_Settings.order_trigger_r = GlobalVariableGet(key);

    key = B8_BuildStateKey("order_partial_close_pct");
    if (GlobalVariableCheck(key))
        g_Order_Runtime_Settings.order_partial_close_percent = GlobalVariableGet(key);

    key = B8_BuildStateKey("order_protection_mode");
    if (GlobalVariableCheck(key))
        g_Order_Runtime_Settings.order_protection_mode = (ENUM_B8_ORDER_PROTECTION_MODE)(int)MathRound(GlobalVariableGet(key));

    key = B8_BuildStateKey("order_be_buffer_points");
    if (GlobalVariableCheck(key))
        g_Order_Runtime_Settings.order_be_buffer_points = (int)MathRound(GlobalVariableGet(key));
}

void B8_LoadPersistedPendingFibSettings()
{
    string version_key = B8_BuildStateKey("pending_fib_version");
    if (!GlobalVariableCheck(version_key)) return;

    string key = B8_BuildStateKey("pending_fib_0120");
    if (GlobalVariableCheck(key)) g_Pending_Fib_Selected[0] = (GlobalVariableGet(key) > 0.5);
    key = B8_BuildStateKey("pending_fib_0214");
    if (GlobalVariableCheck(key)) g_Pending_Fib_Selected[1] = (GlobalVariableGet(key) > 0.5);
    key = B8_BuildStateKey("pending_fib_0236");
    if (GlobalVariableCheck(key)) g_Pending_Fib_Selected[2] = (GlobalVariableGet(key) > 0.5);
    key = B8_BuildStateKey("pending_fib_0382");
    if (GlobalVariableCheck(key)) g_Pending_Fib_Selected[3] = (GlobalVariableGet(key) > 0.5);
    key = B8_BuildStateKey("pending_fib_0500");
    if (GlobalVariableCheck(key)) g_Pending_Fib_Selected[4] = (GlobalVariableGet(key) > 0.5);
    key = B8_BuildStateKey("pending_fib_0618");
    if (GlobalVariableCheck(key)) g_Pending_Fib_Selected[5] = (GlobalVariableGet(key) > 0.5);
    key = B8_BuildStateKey("pending_fib_0786");
    if (GlobalVariableCheck(key)) g_Pending_Fib_Selected[6] = (GlobalVariableGet(key) > 0.5);
    key = B8_BuildStateKey("pending_fib_0880");
    if (GlobalVariableCheck(key)) g_Pending_Fib_Selected[7] = (GlobalVariableGet(key) > 0.5);
}

void B8_LoadPersistedFibRuntimeSettings()
{
    string key = B8_BuildStateKey("fib_risk_allocation");
    if (GlobalVariableCheck(key))
        Enable_Fib_Risk_Allocation = (GlobalVariableGet(key) > 0.5);

    key = B8_BuildStateKey("fib_elimination_policy");
    if (GlobalVariableCheck(key))
    {
        int policy = (int)MathRound(GlobalVariableGet(key));
        if (policy == B8_KEEP_SHALLOW_FIB || policy == B8_KEEP_DEEP_FIB)
            Fib_Elimination_Policy = (ENUM_B8_FIB_ELIMINATION_POLICY)policy;
    }
}
//#endregion

//#region MARK: 模块--保存与加载状态
//====================================================================
// 状态持久化：保存当前运行状态
//====================================================================
void B8_SaveRuntimeState()
{
    if (g_state_key_enabled == "" || g_state_key_mode == "") return;

    GlobalVariableSet(g_state_key_enabled, g_EA_Enabled ? 1.0 : 0.0);
    GlobalVariableSet(g_state_key_mode, (double)g_Trade_Mode);
    GlobalVariableSet(B8_BuildStateKey("settings_panel_visible"),
                      g_SettingsPanelVisible ? 1.0 : 0.0);
    // 保存快速切换后的入场方式，重启EA后恢复上次选择。
    GlobalVariableSet(B8_BuildStateKey("entry_mode"), (double)g_Runtime_Entry_Mode);
    B8_SaveRuntimeSettings();
    B8_SaveOrderRuntimeSettings();
    B8_SaveFibRuntimeSettings();
}

//====================================================================
// 状态持久化：加载运行状态（存在即恢复）
//====================================================================
void B8_LoadRuntimeState()
{
    if (g_state_key_enabled == "" || g_state_key_mode == "") return;

    if (GlobalVariableCheck(g_state_key_enabled))
    {
        double v = GlobalVariableGet(g_state_key_enabled);
        g_EA_Enabled = (v > 0.5);
    }

    if (GlobalVariableCheck(g_state_key_mode))
    {
        int m = (int)MathRound(GlobalVariableGet(g_state_key_mode));
        if (m < B8_MODE_NORMAL || m > B8_MODE_SELL_ONLY)
            m = B8_MODE_NORMAL;
        g_Trade_Mode = (ENUM_B8_TRADE_MODE)m;
    }

    // 参数面板首次默认显示；存在持久化状态时恢复上次选择。
    string panel_visible_key = B8_BuildStateKey("settings_panel_visible");
    if (GlobalVariableCheck(panel_visible_key))
        g_SettingsPanelVisible = (GlobalVariableGet(panel_visible_key) > 0.5);
}
//#endregion