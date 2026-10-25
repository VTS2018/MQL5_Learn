//====================================================================
// 文件作用：KTarget_FinderBot8 的常量、宏、枚举和结构体定义。
// 本文件只提供公共类型与名称定义，不包含运行逻辑。
//====================================================================

#include <K8Bot/B8_Mql4Compat.mqh>

#define OP_NONE        -1

// 面板所有对象统一使用此前缀，方便 OnDeinit 一键删除
#define B8_PREFIX      "B8_"
#define B8_MAGIC_SLOT_SIZE 10000
#define B8_MAGIC_MAX_SEQ   9999

// 面板对象名称
#define B8_PANEL_BG      "B8_PanelBG"
#define B8_PANEL_TITLE   "B8_PanelTitle"
#define B8_BTN_ENABLE    "B8_BtnEnable"
#define B8_BTN_NORMAL    "B8_BtnNormal"
#define B8_BTN_BUY_ONLY  "B8_BtnBuyOnly"
#define B8_BTN_SELL_ONLY "B8_BtnSellOnly"
#define B8_BTN_ENTRY_MARKET "B8_BtnEntryMarket"
#define B8_BTN_ENTRY_PENDING "B8_BtnEntryPending"
#define B8_BTN_ENTRY_BOTH "B8_BtnEntryBoth"
#define B8_BTN_SETTINGS_VISIBILITY "B8_BtnSettingsVisibility"
#define B8_SETTINGS_BG    "B8_SettingsBG"
#define B8_SETTINGS_TITLE "B8_SettingsTitle"
#define B8_STATUS_LINE1   "B8_StatusLine1"
#define B8_STATUS_LINE2   "B8_StatusLine2"
#define B8_STATUS_LINE3   "B8_StatusLine3"
#define B8_STATUS_LINE4   "B8_StatusLine4"
#define B8_STATUS_LINE5   "B8_StatusLine5"
#define B8_STATUS_LINE6   "B8_StatusLine6"
#define B8_STATUS_EDIT    "B8_StatusEdit"
#define B8_EDIT_FIXED_LOT "B8_EditFixedLot"
#define B8_EDIT_RISK_VALUE "B8_EditRiskValue"
#define B8_EDIT_TARGET_PCT "B8_EditTargetPct"
#define B8_EDIT_CLOSE_PCT  "B8_EditClosePct"
#define B8_EDIT_BE_BUFFER  "B8_EditBEBuffer"
#define B8_BTN_POS_FIXED   "B8_BtnPosFixed"
#define B8_BTN_POS_RISK    "B8_BtnPosRisk"
#define B8_BTN_RISK_MONEY  "B8_BtnRiskMoney"
#define B8_BTN_RISK_PCT    "B8_BtnRiskPct"
#define B8_BTN_EP_TOGGLE   "B8_BtnEPToggle"
#define B8_BTN_EP_ACTION_PARTIAL_BE "B8_BtnEPActionPartialBE"
#define B8_BTN_EP_ACTION_CLOSE     "B8_BtnEPActionClose"
#define B8_BTN_APPLY       "B8_BtnApply"
#define B8_BTN_RESTORE     "B8_BtnRestore"
#define B8_BTN_DEFAULTS    "B8_BtnDefaults"
#define B8_BTN_PRESET_SAFE "B8_BtnPresetSafe"
#define B8_BTN_PRESET_STD  "B8_BtnPresetStd"
#define B8_BTN_PRESET_FAST "B8_BtnPresetFast"
#define B8_FIB_PANEL_BG "B8_FibPanelBG"
#define B8_FIB_PANEL_TITLE "B8_FibPanelTitle"
#define B8_FIB_STATUS "B8_FibStatus"
#define B8_FIB_RANGE_STATUS "B8_FibRangeStatus"
#define B8_FIB_BTN_0120 "B8_FibBtn0120"
#define B8_FIB_BTN_0214 "B8_FibBtn0214"
#define B8_FIB_BTN_0236 "B8_FibBtn0236"
#define B8_FIB_BTN_0382 "B8_FibBtn0382"
#define B8_FIB_BTN_0500 "B8_FibBtn0500"
#define B8_FIB_BTN_0618 "B8_FibBtn0618"
#define B8_FIB_BTN_0786 "B8_FibBtn0786"
#define B8_FIB_BTN_0880 "B8_FibBtn0880"
#define B8_FIB_BTN_ALL "B8_FibBtnAll"
#define B8_FIB_BTN_NONE "B8_FibBtnNone"
#define B8_FIB_BTN_PRESET_1 "B8_FibBtnPreset1"
#define B8_FIB_BTN_PRESET_2 "B8_FibBtnPreset2"
#define B8_FIB_BTN_PRESET_3 "B8_FibBtnPreset3"
#define B8_FIB_BTN_RISK_ON "B8_FibBtnRiskOn"
#define B8_FIB_BTN_RISK_OFF "B8_FibBtnRiskOff"
#define B8_FIB_BTN_KEEP_SHALLOW "B8_FibBtnKeepShallow"
#define B8_FIB_BTN_KEEP_DEEP "B8_FibBtnKeepDeep"
#define B8_FIB_HISTORY_TITLE "B8_FibHistoryTitle"
#define B8_FIB_HISTORY_STATUS "B8_FibHistoryStatus"
#define B8_FIB_HISTORY_SHIFT "B8_FibHistoryShift"
#define B8_FIB_HISTORY_SELECT "B8_FibHistorySelect"
#define B8_FIB_HISTORY_CANCEL "B8_FibHistoryCancel"
#define B8_FIB_HISTORY_EXECUTE "B8_FibHistoryExecute"
#define B8_FIB_HISTORY_DELETE "B8_FibHistoryDelete"
#define B8_HISTORY_PLAN_MARKER "|H"

//#region MARK: 模块--自定义价格补挂面板新增控件
#define B8_CUSTOM_FIB_TITLE "B8_CustomFibTitle"
#define B8_CUSTOM_FIB_ENTRY_LABEL "B8_CustomFibEntryLabel"
#define B8_CUSTOM_FIB_ENTRY_EDIT "B8_CustomFibEntryEdit"
#define B8_CUSTOM_FIB_STOP_LABEL "B8_CustomFibStopLabel"
#define B8_CUSTOM_FIB_STOP_EDIT "B8_CustomFibStopEdit"
#define B8_CUSTOM_FIB_ORDER_AUTO "B8_CustomFibOrderAuto"
#define B8_CUSTOM_FIB_ORDER_BUY_LIMIT "B8_CustomFibOrderBuyLimit"
#define B8_CUSTOM_FIB_ORDER_BUY_STOP "B8_CustomFibOrderBuyStop"
#define B8_CUSTOM_FIB_ORDER_SELL_LIMIT "B8_CustomFibOrderSellLimit"
#define B8_CUSTOM_FIB_ORDER_SELL_STOP "B8_CustomFibOrderSellStop"
#define B8_CUSTOM_FIB_RISK_SHARED "B8_CustomFibRiskShared"
#define B8_CUSTOM_FIB_RISK_INDEPENDENT "B8_CustomFibRiskIndependent"
#define B8_CUSTOM_FIB_EXECUTE "B8_CustomFibExecute"
#define B8_CUSTOM_FIB_STATUS "B8_CustomFibStatus"
#define B8_CUSTOM_FIB_PICK_ENTRY "B8_CustomFibPickEntry"
#define B8_CUSTOM_FIB_PICK_STOP "B8_CustomFibPickStop"
#define B8_CUSTOM_FIB_PICK_VLINE "B8_CustomFibPickVLine"
#define B8_CUSTOM_FIB_PICK_HLINE "B8_CustomFibPickHLine"
#define B8_CUSTOM_FIB_PICK_LABEL "B8_CustomFibPickLabel"
#define B8_CUSTOM_FIB_PLAN_MARKER "|C"
//#endregion

//#region MARK: 模块--自定义价格图表取价模式
enum ENUM_B8_PRICE_PICK_MODE
{
    B8_PRICE_PICK_NONE = 0,
    B8_PRICE_PICK_ENTRY,
    B8_PRICE_PICK_STOP
};
//#endregion

#define B8_ORDER_PANEL_BG "B8_OrderPanelBG"
#define B8_ORDER_PANEL_TITLE "B8_OrderPanelTitle"
#define B8_ORDER_STATUS_LINE1 "B8_OrderStatusLine1"
#define B8_ORDER_STATUS_LINE2 "B8_OrderStatusLine2"
#define B8_ORDER_STATUS_LINE3 "B8_OrderStatusLine3"
#define B8_ORDER_STATUS_MESSAGE "B8_OrderStatusMessage"
#define B8_ORDER_EDIT_TRIGGER_POINTS "B8_OrderEditTriggerPoints"
#define B8_ORDER_EDIT_TRIGGER_R "B8_OrderEditTriggerR"
#define B8_ORDER_EDIT_CLOSE_PCT "B8_OrderEditClosePct"
#define B8_ORDER_EDIT_BE_BUFFER "B8_OrderEditBEBuffer"
#define B8_BTN_ORDER_ENABLED "B8_BtnOrderEnabled"
#define B8_BTN_ORDER_TRIGGER_POINTS "B8_BtnOrderTriggerPoints"
#define B8_BTN_ORDER_TRIGGER_R "B8_BtnOrderTriggerR"
#define B8_BTN_ORDER_MODE_PARTIAL "B8_BtnOrderModePartial"
#define B8_BTN_ORDER_MODE_BE "B8_BtnOrderModeBE"
#define B8_BTN_ORDER_MODE_PARTIAL_BE "B8_BtnOrderModePartialBE"
#define B8_BTN_ORDER_MODE_CLOSE "B8_BtnOrderModeClose"
#define B8_BTN_ORDER_APPLY "B8_BtnOrderApply"
#define B8_BTN_ORDER_RESTORE "B8_BtnOrderRestore"
#define B8_BTN_ORDER_PRESET_SAFE "B8_BtnOrderPresetSafe"
#define B8_BTN_ORDER_PRESET_STD "B8_BtnOrderPresetStd"
#define B8_BTN_ORDER_PRESET_FAST "B8_BtnOrderPresetFast"
#define B8_EQ_TARGET_LINE  "B8_EquityTargetLine"
#define B8_EQ_TARGET_LABEL "B8_EquityTargetLabel"
#define B8_EQ_TARGET_STATUS "B8_EquityTargetStatus"
#define B8_RISK_PANEL_BG   "B8_RiskPanelBG"
#define B8_RISK_PANEL_TITLE "B8_RiskPanelTitle"
#define B8_RISK_LINE1      "B8_RiskLine1"
#define B8_RISK_LINE2      "B8_RiskLine2"
#define B8_RISK_LINE3      "B8_RiskLine3"
#define B8_RISK_LINE4      "B8_RiskLine4"
#define B8_RISK_LINE5      "B8_RiskLine5"
#define B8_RISK_LINE6      "B8_RiskLine6"
#define B8_RISK_LINE7      "B8_RiskLine7"
#define B8_RUNTIME_ORDER_PANEL_BG "B8_RuntimeOrderPanelBG"
#define B8_RUNTIME_ORDER_TITLE "B8_RuntimeOrderTitle"
#define B8_RUNTIME_ORDER_COLLAPSE "B8_RuntimeOrderCollapse"
#define B8_RUNTIME_ORDER_STATUS "B8_RuntimeOrderStatus"
#define B8_RUNTIME_QUICK_STATUS "B8_RuntimeQuickStatus"
#define B8_RUNTIME_ORDER_DETAIL1 "B8_RuntimeOrderDetail1"
#define B8_RUNTIME_ORDER_DETAIL2 "B8_RuntimeOrderDetail2"
#define B8_RUNTIME_ORDER_DETAIL3 "B8_RuntimeOrderDetail3"
#define B8_RUNTIME_ORDER_DETAIL4 "B8_RuntimeOrderDetail4"
#define B8_RUNTIME_ORDER_EDIT_R "B8_RuntimeOrderEditR"
#define B8_RUNTIME_ORDER_EDIT_CLOSE "B8_RuntimeOrderEditClose"
#define B8_RUNTIME_ORDER_EDIT_BE "B8_RuntimeOrderEditBE"
#define B8_RUNTIME_ORDER_APPLY "B8_RuntimeOrderApply"
#define B8_RUNTIME_ORDER_DEFAULT "B8_RuntimeOrderDefault"
#define B8_RUNTIME_ORDER_DISABLE "B8_RuntimeOrderDisable"
#define B8_RUNTIME_ORDER_APPLY_SCOPE "B8_RuntimeOrderApplyScope"
#define B8_RUNTIME_ORDER_BREAKEVEN "B8_RuntimeOrderBreakeven"
#define B8_RUNTIME_ORDER_TAKEOVER "B8_RuntimeOrderTakeover"
#define B8_RUNTIME_ORDER_CLOSE_DIVIDER "B8_RuntimeOrderCloseDivider"
#define B8_RUNTIME_QUICK_THIS_ALL "B8_RuntimeQuickThisAll"
#define B8_RUNTIME_QUICK_THIS_LOSS "B8_RuntimeQuickThisLoss"
#define B8_RUNTIME_QUICK_THIS_PROFIT "B8_RuntimeQuickThisProfit"
#define B8_RUNTIME_QUICK_THIS_SELL "B8_RuntimeQuickThisSell"
#define B8_RUNTIME_QUICK_THIS_BUY "B8_RuntimeQuickThisBuy"
#define B8_RUNTIME_QUICK_ALL_LOSS "B8_RuntimeQuickAllLoss"
#define B8_RUNTIME_QUICK_ALL_PROFIT "B8_RuntimeQuickAllProfit"
#define B8_RUNTIME_QUICK_ALL_SELL "B8_RuntimeQuickAllSell"
#define B8_RUNTIME_QUICK_ALL_BUY "B8_RuntimeQuickAllBuy"
#define B8_RUNTIME_QUICK_CLEAR_ALL "B8_RuntimeQuickClearAll"
#define B8_RUNTIME_QUICK_DELETE_PENDING "B8_RuntimeQuickDeletePending"
#define B8_RUNTIME_QUICK_DELETE_MANAGED "B8_RuntimeQuickDeleteManaged"
#define B8_RUNTIME_ORDER_MODE_R "B8_RuntimeOrderModeR"
#define B8_RUNTIME_ORDER_MODE_POINTS "B8_RuntimeOrderModePoints"
#define B8_RUNTIME_ORDER_ACTION_PARTIAL "B8_RuntimeOrderActionPartial"
#define B8_RUNTIME_ORDER_ACTION_BE "B8_RuntimeOrderActionBE"
#define B8_RUNTIME_ORDER_ACTION_PARTIAL_BE "B8_RuntimeOrderActionPartialBE"
#define B8_RUNTIME_ORDER_ACTION_CLOSE "B8_RuntimeOrderActionClose"
#define B8_RUNTIME_ORDER_ROW_PREFIX "B8_RuntimeOrderRow"
#define B8_RUNTIME_ORDER_MAX 64
#define B8_ORDER_PROTECTION_STATE_MAX 128
#define B8_RUNTIME_TAKEOVER_STATE_MAX 128

//#region MARK: 模块--运行时订单策略应用范围
enum ENUM_B8_RUNTIME_APPLY_SCOPE
{
    B8_RUNTIME_APPLY_CURRENT = 0,
    B8_RUNTIME_APPLY_SELECTED = 1,
    B8_RUNTIME_APPLY_ALL_MANAGED = 2
};
//#endregion

#define B8_FIB_TEMPLATE_PANEL_BG "B8_FibTemplatePanelBG"
#define B8_FIB_TEMPLATE_TITLE "B8_FibTemplateTitle"
#define B8_FIB_TEMPLATE_COLLAPSE "B8_FibTemplateCollapse"
#define B8_FIB_TEMPLATE_STATUS "B8_FibTemplateStatus"
#define B8_FIB_TEMPLATE_ROW_PREFIX "B8_FibTemplateRow"
#define B8_FIB_TEMPLATE_EDIT_VALUE "B8_FibTemplateEditValue"
#define B8_FIB_TEMPLATE_EDIT_CLOSE "B8_FibTemplateEditClose"
#define B8_FIB_TEMPLATE_EDIT_BE "B8_FibTemplateEditBE"
#define B8_FIB_TEMPLATE_MODE_R "B8_FibTemplateModeR"
#define B8_FIB_TEMPLATE_MODE_POINTS "B8_FibTemplateModePoints"
#define B8_FIB_TEMPLATE_ACTION_PARTIAL "B8_FibTemplateActionPartial"
#define B8_FIB_TEMPLATE_ACTION_BE "B8_FibTemplateActionBE"
#define B8_FIB_TEMPLATE_ACTION_PARTIAL_BE "B8_FibTemplateActionPartialBE"
#define B8_FIB_TEMPLATE_ACTION_CLOSE "B8_FibTemplateActionClose"
#define B8_FIB_TEMPLATE_APPLY "B8_FibTemplateApply"
#define B8_FIB_TEMPLATE_RESET "B8_FibTemplateReset"
#define B8_FIB_TEMPLATE_PRESET_SAFE "B8_FibTemplatePresetSafe"
#define B8_FIB_TEMPLATE_PRESET_STD  "B8_FibTemplatePresetStd"
#define B8_FIB_TEMPLATE_PRESET_FAST "B8_FibTemplatePresetFast"

// 手动平仓模块新增控件名称，使用宏保证可作为编译期常量参与数组初始化。
#define B8_RUNTIME_CLOSE_SCOPE_ONE    "B8_RuntimeCloseScopeOne"
#define B8_RUNTIME_CLOSE_SCOPE_ALL    "B8_RuntimeCloseScopeAll"
#define B8_RUNTIME_CLOSE_PERCENT_50   "B8_RuntimeClosePercent50"
#define B8_RUNTIME_CLOSE_PERCENT_80   "B8_RuntimeClosePercent80"
#define B8_RUNTIME_CLOSE_PERCENT_100  "B8_RuntimeClosePercent100"
#define B8_RUNTIME_CLOSE_PERCENT_EDIT "B8_RuntimeClosePercentEdit"
#define B8_RUNTIME_CLOSE_PERCENT_GO   "B8_RuntimeClosePercentGo"
#define B8_RUNTIME_CLOSE_LOTS_1       "B8_RuntimeCloseLots1"
#define B8_RUNTIME_CLOSE_LOTS_01      "B8_RuntimeCloseLots01"
#define B8_RUNTIME_CLOSE_LOTS_001     "B8_RuntimeCloseLots001"
#define B8_RUNTIME_CLOSE_LOTS_EDIT    "B8_RuntimeCloseLotsEdit"
#define B8_RUNTIME_CLOSE_LOTS_GO      "B8_RuntimeCloseLotsGo"

//====================================================================
// 枚举定义
//====================================================================

// 交易模式
enum ENUM_B8_TRADE_MODE
{
    B8_MODE_NORMAL    = 0, // 普通模式 (多空信号均执行)
    B8_MODE_BUY_ONLY  = 1, // 只多模式 (仅执行看涨信号)
    B8_MODE_SELL_ONLY = 2  // 只空模式 (仅执行看跌信号)
};

// 仓位计算模式 (与 ConfigBot6/Config_CalcPosition.mqh 保持一致，此处独立声明)
enum ENUM_POS_SIZE_MODE
{
    POS_FIXED_LOT  = 0, // 模式A: 固定手数
    POS_RISK_BASED = 1  // 模式B: 以损定仓 (根据止损距离计算)
};

// 风险计算模式 (与 ConfigBot6/Config_CalcPosition.mqh 保持一致，此处独立声明)
enum ENUM_RISK_MODE
{
    RISK_FIXED_MONEY = 0, // 单笔固定止损金额 (如 $100)
    RISK_PERCENTAGE  = 1  // 单笔账户余额百分比 (如 3%)
};

// 止损分级档位（按 points 分类）
enum ENUM_B8_SL_TIER
{
    B8_SL_TIER_SMALL = 0,   // < Threshold_1
    B8_SL_TIER_MEDIUM = 1,  // Threshold_1 ~ Threshold_2
    B8_SL_TIER_LARGE = 2    // > Threshold_2
};

// 超限信号处理策略（预留扩展）
enum ENUM_B8_OVERSIZE_ACTION
{
    B8_OVERSIZE_SKIP = 0,            // 当前行为：直接跳过
    B8_OVERSIZE_DEFER_PENDING = 1    // 预留行为：后续可扩展为挂单回撤
};

// V1 入场方式：挂单价格使用信号区间 Fib 位置。
enum ENUM_B8_ENTRY_MODE
{
    B8_ENTRY_MARKET = 0,             // 仅市价
    B8_ENTRY_PENDING = 1,             // 仅挂单
    B8_ENTRY_MARKET_AND_PENDING = 2  // 市价 + 挂单
};

//#region MARK: 模块--自定义价格补挂订单类型
enum ENUM_B8_CUSTOM_PENDING_TYPE
{
    B8_CUSTOM_PENDING_AUTO = 0,
    B8_CUSTOM_PENDING_BUY_LIMIT = 1,
    B8_CUSTOM_PENDING_BUY_STOP = 2,
    B8_CUSTOM_PENDING_SELL_LIMIT = 3,
    B8_CUSTOM_PENDING_SELL_STOP = 4
};
//#endregion

// 同一信号的多个挂单，任一成交后的组处理方式。
enum ENUM_B8_PENDING_GROUP_ACTION
{
    B8_PENDING_KEEP_ALL = 0,          // 全部保留，允许多个位置全部成交
    B8_PENDING_CANCEL_REST = 1        // 任一挂单成交后取消同组其余挂单
};

// 动态基准方向
enum ENUM_B8_DYNAMIC_BASE_DIRECTION
{
    B8_BASE_BOTH = 0,    // 盈利上调，亏损下调
    B8_BASE_UP_ONLY = 1  // 仅盈利上调，亏损不下调
};

// 账户级浮盈保护动作，与订单级保护动作独立。
enum ENUM_B8_EQUITY_PROTECTION_ACTION
{
    B8_EQUITY_PARTIAL_BE = 0, // 账户减仓 + 保本
    B8_EQUITY_CLOSE_ONLY = 1  // 账户级全部平仓
};

// 订单级保护触发方式
enum ENUM_B8_ORDER_TRIGGER_MODE
{
    B8_ORDER_TRIGGER_POINTS = 0, // 固定 points
    B8_ORDER_TRIGGER_R      = 1   // 按初始风险 R
};

// 订单级减仓与保本协作方式
enum ENUM_B8_ORDER_PROTECTION_MODE
{
    B8_ORDER_PARTIAL_ONLY  = 0, // 仅自动减仓
    B8_ORDER_BE_ONLY       = 1, // 仅自动保本
    B8_ORDER_PARTIAL_BE    = 2, // 减仓后保本
    B8_ORDER_CLOSE_ONLY    = 3  // 仅全部平仓
};

// 可运行时修改的参数集合
struct B8_RUNTIME_SETTINGS
{
    // 仓位计算方式：固定手数或按风险计算手数。
    ENUM_POS_SIZE_MODE position_mode;
    // 固定手数模式下每笔订单使用的手数。
    double             fixed_lot;
    // 风险计算方式：固定金额或账户余额百分比。
    ENUM_RISK_MODE     risk_mode;
    // 风险值：固定金额模式为金额，百分比模式为账户余额比例。
    double             risk_value;
    // 是否启用账户浮盈保护。
    bool               equity_protect_enabled;
    // 账户浮盈保护的目标收益比例。
    double             equity_target_percent;
    // 账户浮盈保护触发后计划减仓的百分比。
    double             partial_close_percent;
    // 账户浮盈保护或保本动作使用的价格缓冲点数。
    int                be_buffer_points;
    // 账户浮盈达标后的独立动作，默认由代码初始化为减仓+保本。
    ENUM_B8_EQUITY_PROTECTION_ACTION equity_protection_action;
};

// 订单级保护运行参数，与主面板参数独立维护。
struct B8_ORDER_RUNTIME_SETTINGS
{
    // 是否启用订单级自动保护。
    bool               order_protection_enabled;
    // 订单保护的触发方式：固定点数或按初始风险 R 倍数。
    ENUM_B8_ORDER_TRIGGER_MODE order_trigger_mode;
    // 固定点数触发阈值，仅在按点数模式下生效。
    double             order_trigger_points;
    // 初始风险 R 倍数触发阈值，仅在按 R 模式下生效。
    double             order_trigger_r;
    // 达到保护条件时计划减仓的百分比。
    double             order_partial_close_percent;
    // 触发后的保护动作：减仓、保本、减仓后保本或全部平仓。
    ENUM_B8_ORDER_PROTECTION_MODE order_protection_mode;
    // 移动止损到保本价时使用的价格缓冲点数。
    int                order_be_buffer_points;
};

// 普通订单级保护的运行时状态，仅存在 EA 当前运行内存中。
struct B8_ORDER_PROTECTION_STATE
{
    int logical_magic;
    double initial_open_price;
    double initial_sl;
    double initial_risk_price;
    bool initial_risk_valid;
    bool breakeven_done;
    bool partial_close_done;
    double partial_closed_lots;
    int partial_close_count;
};

// 全部接管后的运行期状态，仅在当前 EA 运行期间有效。
// 该状态优先于历史减仓记录，但不修改订单历史和实际剩余手数。
struct B8_RUNTIME_TAKEOVER_STATE
{
    int logical_magic;
    double takeover_lots;
    bool partial_close_done;
};

// 已成交订单的运行时覆盖。只存在当前EA运行内存中，不写入外部配置文件。
struct B8_RUNTIME_ORDER_OVERRIDE
{
    // 当前结构体一共13个参数
    // 逻辑订单的唯一 Magic，用于跨 Ticket 追踪同一笔订单。
    int logical_magic;
    // 关联的 Fib 编号；非 Fib 手动策略通常使用 "--"。
    string fib_code;
    // 该运行时覆盖记录是否处于有效状态。
    bool active;

    // 是否允许该订单执行保护动作。
    bool protection_enabled;
    // 保护动作的触发方式：固定点数或按初始风险 R。
    ENUM_B8_ORDER_TRIGGER_MODE trigger_mode;
    // 固定点数触发阈值，仅在按点数模式下使用。
    double trigger_points;
    // 初始风险 R 倍数触发阈值，仅在按 R 模式下使用。
    double trigger_r;
    // 达到触发条件时计划减仓的百分比。
    double partial_close_percent;
    // 触发后的保护动作类型。
    ENUM_B8_ORDER_PROTECTION_MODE protection_mode;
    // 移动止损到保本价时使用的价格缓冲点数。
    int be_buffer_points;

    //下面是新增的参数 有特殊作用 上面的六个参数 其实和 Fibo模板成交前策略模板相同
    // 逻辑订单首次接管时的开仓价格。
    double initial_open_price;
    // 逻辑订单首次接管时的止损价格。
    double initial_sl;
    // 根据初始开仓价和初始止损保存的风险距离。
    double initial_risk_price;
    // 是否已经完成保本动作。
    bool breakeven_done;
    // 运行期间累计已经减仓的手数。
    double partial_closed_lots;
    // 运行期间已经成功部分平仓的次数。
    int partial_close_count;
};

// 成交前按 Fib 位置配置的运行时策略模板。
struct B8_FIB_ORDER_TEMPLATE
{
    // 该 Fib 策略模板是否已由用户配置并启用。
    bool configured;
    // Fib 策略的保护触发方式：固定点数或按初始风险 R。
    ENUM_B8_ORDER_TRIGGER_MODE trigger_mode;
    // 固定点数触发阈值，仅在按点数模式下使用。
    double trigger_points;
    // 初始风险 R 倍数触发阈值，仅在按 R 模式下使用。
    double trigger_r;
    // 对一笔订单产生作用的其实是六个息息相关的参数
    // 达到触发条件时计划减仓的百分比。
    double partial_close_percent;
    // 触发后的保护动作类型。
    ENUM_B8_ORDER_PROTECTION_MODE protection_mode;
    // 移动止损到保本价时使用的价格缓冲点数。
    int be_buffer_points;
};