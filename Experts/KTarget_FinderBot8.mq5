//+------------------------------------------------------------------+
//|                                          KTarget_FinderBot8.mq4  |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//
//  功能说明：
//    - 接收 KTarget_Finder_MT7 指标发出的最新 K[1] 信号并执行交易
//    - 只关注最新一根已收盘 K 线 (shift=1)，历史信号全部忽略
//    - 右下角交互面板，支持运行开关与多/空/普通三种交易模式
//
//  面板操作：
//    [开启/关闭]  - 控制 EA 是否接收信号并执行交易
//    [普通模式]   - 多空信号均执行（同时出现则不交易，记日志）
//    [只多模式]   - 仅执行看涨信号，忽略看跌信号
//    [只空模式]   - 仅执行看跌信号，忽略看涨信号
//
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//====================================================================
// 常量 / 宏定义
//====================================================================
#include <K8Bot/B8_Definitions.mqh>

//====================================================================
// Include 文件
//====================================================================
#include <K5/K_Data.mqh>                    // KBarSignal 结构体
#include <K5/K_Utils.mqh>                   // ShortenObjectNameBot 等工具函数
#include <ConfigBot7/Config_Indicator.mqh>  // 指标 iCustom 调用参数
#include <FunBot6/Lib_CalcPosition.mqh>     // NormalizeLots / GetPositionSize_V1

//====================================================================
// 输入参数
//====================================================================

// ---- EA 核心设置 ----
input string  __CORE__          = "--- EA 核心设置 ---";
input string  EA_Version_Tag    = "B8";       // 版本标签 (写入订单注释)
input int     MagicNumber       = 8888;       // 4位家族Magic，实单Magic=家族Magic*10000+订单序号

//#region MARK: 模块--资金管理 止盈 持仓 止损分级管理
// ---- 资金管理设置 ----
input string             __MONEY_MGMT__ = "--- 资金管理设置 ---";
input ENUM_POS_SIZE_MODE Position_Mode  = POS_FIXED_LOT;    // 仓位计算模式
input double             FixedLot       = 0.03;             // 固定手数 (POS_FIXED_LOT 模式有效)
input int                Slippage       = 3;                // 允许滑点 (点)
input ENUM_RISK_MODE     Risk_Mode      = RISK_FIXED_MONEY; // 风险计算方式
input double             Risk_Value     = 30.0;             // 风险值 ($金额 或 %比例)

// ---- 止盈设置 ----
input string  __TP_SETTINGS__   = "--- 止盈设置 ---";
input double  TP_Fixed_Pips     = 0.0;   // 固定止盈 Pips (0 = 不设置止盈)

// ---- 持仓限制 ----
input string  __LIMITS__        = "--- 持仓限制 ---";
input int     Max_Open_Orders   = 2;     // 最大同时持仓数 (同品种同 MagicNumber)

// ---- 止损分级路由（points） ----
input string  __SL_TIER_ROUTING__         = "--- 止损分级路由(points) ---";
input bool    Enable_SL_Tier_Routing      = true;   // 是否启用止损分级路由
input int     SL_Tier_Threshold_1_Points  = 1000;   // 阈值1: 例如XAUUSD中1000 points≈10美金价差
input int     SL_Tier_Threshold_2_Points  = 1500;   // 阈值2: 例如1500 points≈15美金价差
input int     SL_Max_Allowed_Points       = 2000;   // 最大允许止损距离: 例如2000 points≈20美金价差
input double  Risk_Value_LargeSL          = 35.0;   // 预留参数：当前版本不参与风险计算
// 当前版本所有以损定仓路径均使用面板 Risk_Value；此参数仅为未来独立大止损风险方案预留。
input ENUM_B8_OVERSIZE_ACTION Oversize_Signal_Action = B8_OVERSIZE_SKIP; // 超限信号处理策略
//#endregion

//#region MARK: 模块--Fibo挂单
// ---- V1 信号区间挂单 ----
input string __PENDING_V1__ = "--- V1 信号区间挂单 ---";
input ENUM_B8_ENTRY_MODE Entry_Mode = B8_ENTRY_MARKET; // 入场方式
input ENUM_B8_PENDING_GROUP_ACTION Pending_Group_Action = B8_PENDING_KEEP_ALL; // 挂单组处理
input bool Pending_Fib_0120 = false;
input bool Pending_Fib_0214 = false;
input bool Pending_Fib_0236 = false;
input bool Pending_Fib_0382 = false;
input bool Pending_Fib_0500 = false;
input bool Pending_Fib_0618 = false;
input bool Pending_Fib_0786 = false;
input bool Pending_Fib_0880 = false;
//#endregion

//#region MARK: 共享风险与仓位分配算法
// 当前 Fib_Pending_Algorithm 没有界面配置，也没有持久化逻辑
enum ENUM_B8_FIB_PENDING_ALGORITHM
{
    B8_FIB_ALGO_V2 = 0, // 宽松模式：允许部分Fib因最小手数不足而不下单
    B8_FIB_ALGO_V3 = 1  // 严格模式：预先验证分配风险能否形成有效手数
};
ENUM_B8_FIB_PENDING_ALGORITHM Fib_Pending_Algorithm = B8_FIB_ALGO_V2;

// Enable_Fib_Risk_Allocation 和 Fib_Elimination_Policy 已经做了持久化的配置 并且 Fib_Elimination_Policy 只会在 B8_FIB_ALGO_V3下有用
bool Enable_Fib_Risk_Allocation = true; // Fib挂单是否共享Risk_Value并按反向金字塔分配

enum ENUM_B8_FIB_ELIMINATION_POLICY
{
    B8_KEEP_SHALLOW_FIB = 0, // 优先保留浅层：靠近当前价格
    B8_KEEP_DEEP_FIB    = 1  // 优先保留深层：靠近止损
};
ENUM_B8_FIB_ELIMINATION_POLICY Fib_Elimination_Policy = B8_KEEP_SHALLOW_FIB;
//#endregion

//#region MARK: 模块--止损过滤 点差容错 浮盈保护 减仓保本
// ---- 止损最小距离过滤（points，独立于分级路由，任何模式下都生效） ----
input string  __SL_MIN_FILTER__          = "--- 止损最小距离过滤 ---"; // ----
input bool    Enable_SL_Min_Filter       = true; // 是否启用止损过近拒绝开仓
input int     SL_Min_Allowed_Points      = 200;  // 最小允许止损距离: 例如XAUUSD中200points≈2美金

// ---- 止损点差容错（方案A：只影响最终挂单止损价，不影响风控/仓位计算） ----
input string  __SL_BUFFER__                = "--- 止损点差容错 ---"; // ----
input bool    Enable_SL_Buffer             = true; // 是否启用止损点差容错
input int     SL_Buffer_Points             = 30;   // 容错点数(points)。例如XAUUSD中30points≈0.3美金

// ---- 账户浮盈保护（减仓 + 保本） ----
input string  __EQUITY_PROTECT__          = "--- 账户浮盈保护 ---";
input bool    Enable_Equity_Protect       = true;    // 是否启用账户浮盈保护
input double  Equity_Base_Amount          = 10000.0; // 基准资金(例如10000)
input double  Equity_Target_Percent       = 5.0;     // 触发百分比(例如5%)
input double  Partial_Close_Percent       = 80.0;    // 减仓比例(例如80%)
input bool    Move_SL_To_BE               = true;    // 减仓后是否移到保本
input int     BE_Buffer_Points            = 30;      // 保本缓冲(点)
input bool    Protect_Once_Per_Cycle      = false;   // 是否每轮持仓只触发一次（实战多次触发）
input bool    Enable_Dynamic_Equity_Base  = true;    // 是否启用动态基准资金
input ENUM_B8_DYNAMIC_BASE_DIRECTION Dynamic_Base_Direction = B8_BASE_UP_ONLY; // 动态基准方向
input double  Dynamic_Base_Min_Amount     = 0.0;     // 动态基准下限(0=不限制)

// ---- 订单级自动减仓/保本默认值（实盘建议通过独立子面板修改） ----
input string  __ORDER_PROTECTION__       = "--- 订单级自动减仓/保本默认值 ---";
input bool    Enable_Order_Protection_Default = true; // 订单级保护默认开关
input ENUM_B8_ORDER_TRIGGER_MODE Order_Trigger_Mode_Default = B8_ORDER_TRIGGER_R; // 订单保护触发模式：固定点数或风险R倍数
input double  Order_Trigger_Points_Default = 200.0;   // 固定点数模式触发值
input double  Order_Trigger_R_Default      = 1.0;     // R模式触发值
input double  Order_Partial_Close_Percent_Default = 50.0; // 订单达到保护条件后默认减仓比例(%)
input ENUM_B8_ORDER_PROTECTION_MODE Order_Protection_Mode_Default = B8_ORDER_PARTIAL_BE; // 订单保护动作：减仓、保本、减仓后保本或仅平仓
input int     Order_BE_Buffer_Points_Default = 10; // 移动止损到保本价时使用的缓冲点数
//#endregion

//====================================================================
// 全局状态变量
//====================================================================
#include <K8Bot/B8_State.mqh>

//#region MARK: 所有的函数声明
//====================================================================
// 函数前置声明
//====================================================================
// [新增] MT7 Bot8 参数快照的最小读取结构；暂不替换现有 iCustom 参数。
struct B8_INDICATOR_SNAPSHOT
{
    bool valid;
    int source_period;
    int scan_range;
    int lookahead_bottom;
    int lookback_bottom;
    int lookahead_top;
    int lookback_top;
    int max_signal_lookforward;
    int db_threshold_candles;
    int llhh_candles;
    bool enable_ib_signal_marking;
    int find_target_model;
    bool enable_honest_filter;
    bool use_enhanced_p2_search;
    int enhanced_p2_min_bars_between;
    bool use_strict_plevel_search;
    int strict_plevel_min_bars_between;
};

B8_INDICATOR_SNAPSHOT g_B8_Indicator_Snapshot;
bool g_B8_Mt7_Ready = false;
bool B8_ReadIndicatorSnapshot(B8_INDICATOR_SNAPSHOT &snapshot);
double B8_ReadIndicatorBufferFromSnapshot(int buffer, int shift);
bool B8_CreateMt7Handle();
void B8_ReleaseMt7Handle();

KBarSignal B8_ReadSignalK1(void);
KBarSignal B8_ReadHistoricalSignal(int shift);
void       B8_ExecuteTrade(const KBarSignal &signal, int type);
void       B8_ExecutePendingTrade(const KBarSignal &signal, int type,
                                  double entry_price, string plan_tag,
                                  double allocated_risk_value,
                                  double override_stop_price = 0.0,
                                  int override_pending_type = OP_NONE);
void       B8_CreatePendingPlans(const KBarSignal &signal, int type);
bool       B8_CreateHistoricalPendingPlans(const KBarSignal &signal, int shift);
void       B8_CreatePendingPlansV2(const KBarSignal &signal, int type);
bool       B8_CreateHistoricalPendingPlansV2(const KBarSignal &signal, int shift);
void       B8_CreatePendingPlansV3(const KBarSignal &signal, int type);
bool       B8_CreateHistoricalPendingPlansV3(const KBarSignal &signal, int shift);
bool       B8_DeleteHistoricalPendingPlans(int shift);
void       B8_ManagePendingGroups();
bool       B8_IsPendingOrderType(int order_type);
string     B8_PendingGroupKey(const KBarSignal &signal, int type);
bool       B8_IsPendingFibSelected(double fib_level);
bool       B8_IsPendingPlanDuplicate(string plan_tag);
string     B8_PendingPlanPositionText(string plan_tag);
bool       B8_IsFibRiskEligible(const KBarSignal &signal, int type,
                                double entry_price, string plan_tag);
bool       B8_CanFormPendingRiskLot(const KBarSignal &signal, int type,
                                    double entry_price, double risk_value);
int        B8_GetFibRiskCheckIndex(int check_order);
double     B8_GetFibAllocatedRisk(int fib_order_index, int effective_count);
void       B8_TryCancelPendingGroup(const string group_key);
int        B8_CountOpenPositions();
ENUM_B8_SL_TIER B8_GetSLTierByPoints(double sl_points, int threshold_1, int threshold_2);
string     B8_SLTierToString(ENUM_B8_SL_TIER tier);
double     B8_GetManagedFloatingProfit();
double     B8_GetManagedClosedProfit();
double     B8_GetEffectiveEquityBase();
double     B8_GetManagedProfitSlopePerPrice();
bool       B8_TryCalcEquityTargetPrice(double &target_price,
                                        double &current_profit,
                                        double &target_profit,
                                        double &profit_gap,
                                        double &slope_per_price);
void       B8_UpdateEquityTargetVisual();
void       B8_ClearEquityTargetVisual();
bool       B8_ApplyDraggedEquityTargetPrice(double dragged_price);
void       B8_ManageEquityProtection();
void       B8_ManageEquityProtectionV2();
void       B8_ManageOrderProtection();
int        B8_FindOrderProtectionState(int logical_magic);
int        B8_GetOrCreateOrderProtectionState(int logical_magic,
                                               double open_price,
                                               double current_sl);
void       B8_CleanupOrderProtectionStates();
// bool       B8_GetOrderInitialRisk(double open_price, double current_sl, double &risk_price);
bool       B8_IsOrderBreakevenDone(int type, double open_price, double current_sl);
bool       B8_HasOrderPartialCloseHistory(int order_magic, int type);
bool       B8_IsPartialCloseBlocked(int logical_magic);
void       B8_MarkPartialCloseBlocked(int logical_magic);
//#region MARK: 模块--全部接管运行期状态新增声明
int        B8_FindRuntimeTakeoverState(int logical_magic);
bool       B8_IsRuntimeTakeoverActive(int logical_magic);
bool       B8_IsRuntimeTakeoverPartialCloseDone(int logical_magic);
void       B8_MarkRuntimeTakeoverPartialCloseDone(int logical_magic);
void       B8_ClearPartialCloseBlocked(int logical_magic);
int        B8_ResetAllManagedOrdersToOrderLevel();
void       B8_CleanupRuntimeTakeoverStates();
//#endregion
bool       B8_MoveOrderToBreakeven(int ticket, int type, double open_price);
bool       B8_CloseOrderPartially(int ticket, int logical_magic, int type, double close_percent);
bool       B8_CloseOrderFully(int ticket, int type);
//#region MARK: 模块--运行时订单一键保本新增声明
int        B8_ManualMoveRuntimeOrderToBreakeven(int ticket, int be_buffer_points);
bool       B8_ExecuteRuntimeBreakevenAllManaged(int &moved_count,
                                                int &already_count,
                                                int &failed_count);
//#endregion
void       B8_CreatePanel();
void       B8_InitializePanels();
void       B8_UpdatePanel();
void       B8_CreateRiskPanel();
void       B8_UpdateRiskPanel();
string     B8_RiskLevelText(double risk_percent);
void       B8_CreateSettingsPanel();
void       B8_CreateFibPanel();
void       B8_CreateOrderPanel();
void       B8_SetFibPanelVisible(bool visible);
void       B8_SetOrderPanelVisible(bool visible);
void       B8_SetSettingsPanelVisible(bool visible);
void       B8_SetCorePanelsVisible(bool visible);
void       B8_SyncSettingsBeforeHide();
void       B8_SyncOrderSettingsBeforeHide();
void       B8_UpdateSettingsPanel();
void       B8_UpdateFibPanel();
void       B8_UpdateHistoricalFibPanel();
void       B8_EnterHistoricalSelectMode();
void       B8_CancelHistoricalSelectMode();
void       B8_HandleHistoricalChartClick(const long &lparam, const double &dparam);
void       B8_RefreshHistoricalSignalPreview();
void       B8_UpdateOrderPanel();
//#region MARK: 模块--自定义价格补挂新增声明
void       B8_UpdateCustomFibPanel();
bool       B8_HandleCustomFibPanelEvent(const string object_name);
bool       B8_CreateCustomPendingPlans(int shift);
//#endregion
int        B8_PendingFibButtonIndex(const string object_name);
int        B8_CountSelectedPendingFib();
void       B8_SetAllPendingFib(bool selected);
void       B8_ApplyPendingFibPreset(int preset_index);
void       B8_WriteEditFields();
bool       B8_ReadEditFields(string &error_text);
void       B8_WriteOrderEditFields();
bool       B8_ReadOrderEditFields(string &error_text);
// bool       B8_IsSettingsEditObject(string object_name);
bool       B8_IsMainSettingsEditObject(string object_name);
bool       B8_IsOrderSettingsEditObject(string object_name);
void       B8_MarkSettingsDirty();
void       B8_MarkOrderSettingsDirty();
void       B8_ApplyPreset(int preset_index);
void       B8_ApplyOrderPreset(int preset_index);
void       B8_LoadOrderStartupSettings(B8_ORDER_RUNTIME_SETTINGS &settings);
void       B8_CopyOrderSettings(const B8_ORDER_RUNTIME_SETTINGS &source,
                                B8_ORDER_RUNTIME_SETTINGS &target);
bool       B8_ValidateOrderSettings(const B8_ORDER_RUNTIME_SETTINGS &settings,
                                    string &error_text);
bool       B8_ApplyOrderEditSettings(string source_name);
void       B8_MakeRectLabel(string name, int xdist, int ydist, int w, int h, color bg, color border);
void       B8_MakeButton(string name, int xdist, int ydist, int w, int h, string text, color bg, color txt);
void       B8_MakeLabel(string name, int xdist, int ydist, string text, color txt, int fontsize);
void       B8_MakeEdit(string name, int xdist, int ydist, int w, int h, string text);
void       B8_StartCustomFibPricePick(ENUM_B8_PRICE_PICK_MODE mode);
void       B8_CancelCustomFibPricePick();
bool       B8_HandleCustomFibPricePickEvent(const int id, const long &lparam,
                                            const double &dparam);
string     B8_PositionModeText(ENUM_POS_SIZE_MODE mode);
string     B8_RiskModeText(ENUM_RISK_MODE mode);
string     B8_TimeframeToText(int timeframe_minutes);
void       B8_LoadStartupSettings(B8_RUNTIME_SETTINGS &settings);
void       B8_CopySettings(const B8_RUNTIME_SETTINGS &source, B8_RUNTIME_SETTINGS &target);
bool       B8_ValidateSettings(const B8_RUNTIME_SETTINGS &settings, string &error_text);
bool       B8_ApplyEditSettings(string source_name);
void       B8_SaveRuntimeSettings();
void       B8_LoadPersistedRuntimeSettings();
string     B8_EntryModeText(ENUM_B8_ENTRY_MODE mode);
void       B8_SaveOrderRuntimeSettings();
void       B8_LoadPersistedOrderSettings();
void       B8_LoadStartupPendingFibSettings();
void       B8_SavePendingFibSettings();
void       B8_LoadPersistedPendingFibSettings();
void       B8_SaveFibRuntimeSettings();
void       B8_LoadPersistedFibRuntimeSettings();
string     B8_BuildStateKey(string item);
int        B8_GetMagicFamily();
int        B8_BuildOrderMagicBySeq(int order_seq);
int        B8_GetOrderMagicSeq(int order_magic);
bool       B8_IsManagedOrderMagic(int order_magic);
bool       B8_IsManagedOrder();
bool       B8_IsOrderMagicUsed(int order_magic);
bool       B8_AllocateOrderMagic(int &order_magic);
void       B8_SaveRuntimeState();
void       B8_LoadRuntimeState();
void       B8_CreateRuntimeOrderPanel();
void       B8_UpdateRuntimeOrderPanel();
bool       B8_HandleRuntimeOrderPanelEvent(const string object_name);
void       B8_SetRuntimeOrderPanelCollapsed(bool collapsed);
bool       B8_InitializeRuntimeOrderPanelObjects();
void       B8_SetRuntimeOrderPanelCollapsedFast(bool collapsed);
bool       B8_HasRuntimeOrderOverride(int logical_magic);
bool       B8_ManageRuntimeOrderProtection(int ticket, int type);
void       B8_CreateFibTemplatePanel();
void       B8_UpdateFibTemplatePanel();
bool       B8_HandleFibTemplatePanelEvent(const string object_name);
bool       B8_HandleFibPanelEvent(const string object_name);
void       B8_SetFibTemplatePanelCollapsed(bool collapsed);
bool       B8_InitializeFibTemplatePanelObjects();
void       B8_SetFibTemplatePanelCollapsedFast(bool collapsed);
void       B8_InitializeFibOrderTemplates();
int        B8_FibTemplateIndexFromCode(string fib_code);
bool       B8_ApplyFibTemplate();
void       B8_ApplyFibTemplatePreset(int preset_index);
void       B8_CopyFibTemplateToOverride(int logical_magic, int template_index,
                                        double open_price, double initial_sl);
string     B8_FibTemplateCode(int index);
string     B8_FibTemplateRowName(int index);
bool       B8_IsFibTemplatePanelObject(string object_name);
bool       B8_IsFibTemplateEditObject(string object_name);
void       B8_SyncFibTemplateInputs();
int        B8_FindRuntimeOrderOverride(int logical_magic);
string     B8_RuntimeOrderRowName(int row);
string     B8_RuntimeOrderFibCode(string comment);
bool       B8_SelectRuntimeOrderByTicket(int ticket);
bool       B8_RuntimeOrderIsOpen(int ticket);
bool       B8_RuntimeOrderSelectTicket(int ticket);
double     B8_RuntimeOrderCurrentR(int ticket);
bool       B8_TryGetCurrentOrderStopRisk(double &risk_money);
bool       B8_ApplyRuntimeOrderOverride();
//#region MARK: 模块--运行时订单策略多选应用新增声明
bool       B8_RuntimeOrderTicketIsSelected(int ticket);
void       B8_RuntimeOrderToggleSelectedTicket(int ticket);
void       B8_RuntimeOrderPruneSelectedTickets();
void       B8_RuntimeOrderCycleApplyScope();
void       B8_RuntimeOrderUpdateApplyScopeControl();
bool       B8_ApplyRuntimeOrderOverrideToTicket(int ticket,
                                                double trigger_value,
                                                double close_percent,
                                                int be_buffer);
bool       B8_ApplyRuntimeOrderOverrideByScope(int &success_count,
                                               int &failure_count);
void       B8_LogRuntimeOrderFilterMismatch(int position,
                                            int ticket,
                                            string reason);
//#endregion
void       B8_ClearRuntimeOrderOverride(int logical_magic);
// void       B8_CopyDefaultToRuntimeOverride(B8_RUNTIME_ORDER_OVERRIDE &item);
bool       B8_IsRuntimeOrderPanelObject(string object_name);
bool       B8_IsRuntimeOrderEditObject(string object_name);
void       B8_RuntimeOrderMakeLabel(string name, int x, int y, string text, color txt, int size);
void       B8_RuntimeOrderMakeButton(string name, int x, int y, int w, int h, string text, color bg);
void       B8_RuntimeOrderMakeEdit(string name, int x, int y, int w, int h, string text);
string     B8_RuntimeOrderModeText(ENUM_B8_ORDER_TRIGGER_MODE mode);
string     B8_RuntimeOrderActionText(ENUM_B8_ORDER_PROTECTION_MODE mode);
bool       B8_HandleQuickThisAll();
bool       B8_HandleQuickThisLoss();
bool       B8_HandleQuickThisProfit();
bool       B8_HandleQuickThisSell();
bool       B8_HandleQuickThisBuy();
bool       B8_HandleQuickAllLoss();
bool       B8_HandleQuickAllProfit();
bool       B8_HandleQuickAllSell();
bool       B8_HandleQuickAllBuy();
bool       B8_HandleQuickClearAll();
bool       B8_HandleQuickDeletePending();
bool       B8_HandleQuickDeleteManaged();
void       B8_SetRuntimeCloseStatus(string text, bool success);
bool       B8_ExecuteRuntimeClosePercent(double percent);
bool       B8_ExecuteRuntimeCloseLots(double lots);
double     B8_NormalizeManualCloseLots(double lots);
bool       B8_CloseManualOrderLots(int ticket, double requested_lots, color close_color);
bool       B8_CloseSelectedManualLots(double lots);
bool       B8_CloseSelectedManualPercent(double percent);
bool       B8_CloseManagedManualLots(double lots);
bool       B8_CloseManagedManualPercent(double percent);
//#endregion

//#region MARK: 模块--EA自动开启独立模块声明
void       B8_AutoActivation_Initialize();
void       B8_AutoActivation_Deinitialize();
void       B8_AutoActivation_OnTick();
bool       B8_AutoActivation_HandleChartEvent(const int id, const string object_name);
void       B8_AutoActivation_SetExpanded_New(bool expanded);
//#endregion

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
// [新增] 读取并解析 MT7 快照；当前仅验证和打印，不改变旧 iCustom 路径。
bool B8_ReadIndicatorSnapshot(B8_INDICATOR_SNAPSHOT &snapshot)
{
    snapshot.valid = false;

    string object_name = "KTarget_Param_Store_Bot8";
    if (ObjectFind(0, object_name) < 0)
    {
        Print("[Bot8][MT7参数] 未找到对象: ", object_name);
        return false;
    }

    string param_text = ObjectGetString(0, object_name, OBJPROP_TEXT);
    if (StringLen(param_text) <= 0)
    {
        Print("[Bot8][MT7参数] 对象内容为空");
        return false;
    }

    string fields[];
    int field_count = StringSplit(param_text, StringGetCharacter("|", 0), fields);
    if (field_count != 19)
    {
        Print("[Bot8][MT7参数] 字段数量错误，实际=", field_count,
              "，期望=19，内容=", param_text);
        return false;
    }

    if (fields[0] != "K8" || StringToInteger(fields[1]) != 3)
    {
        Print("[Bot8][MT7参数] 协议不支持，内容=", param_text);
        return false;
    }

    // 快照中的 0 表示参数已经是最终值，Bot8 不再执行 Smart Tuning。
    if (StringToInteger(fields[2]) != 0)
    {
        Print("[Bot8][MT7参数] 快照要求再次 Smart Tuning，拒绝使用");
        return false;
    }

    snapshot.source_period                 = (int)StringToInteger(fields[3]);
    if (snapshot.source_period != _Period)
    {
        Print("[Bot8][MT7参数] 周期不匹配，快照=", snapshot.source_period,
              "，当前=", _Period);
        return false;
    }

    snapshot.scan_range                    = (int)StringToInteger(fields[4]);
    snapshot.lookahead_bottom              = (int)StringToInteger(fields[5]);
    snapshot.lookback_bottom               = (int)StringToInteger(fields[6]);
    snapshot.lookahead_top                 = (int)StringToInteger(fields[7]);
    snapshot.lookback_top                  = (int)StringToInteger(fields[8]);
    snapshot.max_signal_lookforward        = (int)StringToInteger(fields[9]);
    snapshot.db_threshold_candles          = (int)StringToInteger(fields[10]);
    snapshot.llhh_candles                  = (int)StringToInteger(fields[11]);
    snapshot.enable_ib_signal_marking      = (StringToInteger(fields[12]) != 0);
    snapshot.find_target_model              = (int)StringToInteger(fields[13]);
    snapshot.enable_honest_filter           = (StringToInteger(fields[14]) != 0);
    snapshot.use_enhanced_p2_search         = (StringToInteger(fields[15]) != 0);
    snapshot.enhanced_p2_min_bars_between   = (int)StringToInteger(fields[16]);
    snapshot.use_strict_plevel_search       = (StringToInteger(fields[17]) != 0);
    snapshot.strict_plevel_min_bars_between = (int)StringToInteger(fields[18]);

    if (snapshot.scan_range <= 0 ||
        snapshot.lookahead_bottom < 0 || snapshot.lookback_bottom < 0 ||
        snapshot.lookahead_top < 0 || snapshot.lookback_top < 0 ||
        snapshot.max_signal_lookforward < 0 ||
        snapshot.db_threshold_candles <= 0 || snapshot.llhh_candles <= 0 ||
        snapshot.find_target_model < 1 || snapshot.find_target_model > 2 ||
        snapshot.enhanced_p2_min_bars_between < 0 ||
        snapshot.strict_plevel_min_bars_between < 0)
    {
        Print("[Bot8][MT7参数] 参数值超出合法范围，内容=", param_text);
        return false;
    }

    snapshot.valid = true;
    Print("[Bot8][MT7参数] 读取成功: ", param_text);
    return true;
}

int OnInit()
{
    // [新增] MT7 尚未完成初始化时进入等待状态，不阻塞 EA 初始化。
    g_B8_Mt7_Ready = B8_ReadIndicatorSnapshot(g_B8_Indicator_Snapshot);
    if (g_B8_Mt7_Ready)
    {
        g_B8_Mt7_Ready = B8_CreateMt7Handle();
    }
    if (g_B8_Mt7_Ready)
    {
        ResetLastError();
        double snapshot_check = B8_ReadIndicatorBufferFromSnapshot(2, 0);
        int snapshot_error = GetLastError();
        if (snapshot_error == 4802)
        {
            g_B8_Mt7_Ready = false;
            g_B8_Indicator_Snapshot.valid = false;
            Print("[Bot8][MT7参数] 指标尚未可用，等待 MT7 初始化: ", IndicatorName);
        }
        ResetLastError();
    }

    if (!g_B8_Mt7_Ready)
    {
        EventSetTimer(1);
        Print("[Bot8][MT7参数] 等待 MT7 快照就绪，当前禁止交易。");
    }

    /*
    // [旧代码保留] 旧版本读取失败时直接终止初始化的实现。
    if (!B8_ReadIndicatorSnapshot(g_B8_Indicator_Snapshot))
    {
        Alert("[Bot8] 严重错误：无法读取 KTarget_Finder_MT7 参数快照！",
              "请确认 MT7 已挂载在同一张图表并完成初始化。");
        return INIT_FAILED;
    }

    ResetLastError();
    double snapshot_check = B8_ReadIndicatorBufferFromSnapshot(2, 0);
    int snapshot_error = GetLastError();
    if (snapshot_error == 4802)
    {
        Alert("[Bot8] 严重错误：无法加载指标 '", IndicatorName,
              "'！请确认 Indicators 目录中存在该文件。");
        return INIT_FAILED;
    }
    ResetLastError();
    */

    /*
    // [旧代码保留] 使用 Bot8 input 参数检测指标是否可加载。
    double check = iCustom(_Symbol, _Period, IndicatorName,
                           Indi_Is_EA_Mode,
                           Indi_Smart_Tuning, Indi_Scan_Range,
                           Indi_Lookahead_Bottom, Indi_Lookback_Bottom,
                           Indi_Lookahead_Top,    Indi_Lookback_Top,
                           Indi_Max_Signal_Look,  Indi_DB_Threshold, Indi_LLHH_Candles,
                           Indi_Enable_IB_Signal_Marking,
                           Indi_Anchor_Honest_Filter_Settings,
                           Indi_Find_Target_Model, Indi_Enable_Honest_Filter,
                           Indi_Use_Enhanced_P2_Search, Indi_Enhanced_P2_Min_Bars_Between,
                           Indi_Use_Strict_PLevel_Search, Indi_Strict_PLevel_Min_Bars_Between,
                           Indi_Anchor_Honest_Filter_Settings__End,
                           2, 0);

    if (GetLastError() == 4802)
    {
        Alert("[Bot8] 严重错误：无法加载指标 '", IndicatorName,
              "'！请确认 Indicators 目录中存在该文件。");
        return INIT_FAILED;
    }
    ResetLastError();
    */

    if (MagicNumber < 1 || MagicNumber > B8_MAGIC_MAX_SEQ)
    {
        Alert("[Bot8] MagicNumber 现在作为4位家族Magic使用，必须在 1~9999 之间。当前值:",
              MagicNumber);
        return INIT_FAILED;
    }

    // 构造唯一对象前缀 (EA名 + ChartID尾6位)
    int short_cid  = (int)(MathAbs(ChartID()) % 1000000);
    g_object_prefix = ShortenObjectNameBot(MQLInfoString(MQL_PROGRAM_NAME))
                      + StringFormat("_%d_", short_cid);

    // 构造并加载运行状态持久化键（按账号/品种/Magic/图表隔离）
    g_state_key_enabled = B8_BuildStateKey("enabled");
    g_state_key_mode    = B8_BuildStateKey("mode");

    // 三层参数状态：input启动值 -> 当前运行值 -> 面板编辑值
    B8_LoadStartupSettings(g_Startup_Settings);
    B8_CopySettings(g_Startup_Settings, g_Runtime_Settings);
    // 入场方式独立于资金参数，但同样使用运行时状态和持久化机制。
    g_Runtime_Entry_Mode = Entry_Mode;
    B8_LoadOrderStartupSettings(g_Order_Startup_Settings);
    B8_CopyOrderSettings(g_Order_Startup_Settings, g_Order_Runtime_Settings);
    B8_LoadStartupPendingFibSettings();
    B8_LoadPersistedRuntimeSettings();
    B8_LoadPersistedOrderSettings();
    B8_LoadPersistedPendingFibSettings();
    B8_LoadPersistedFibRuntimeSettings();
    B8_InitializeFibOrderTemplates();

    string settings_error = "";
    if (!B8_ValidateSettings(g_Runtime_Settings, settings_error))
    {
        Print("[Bot8][参数恢复] 持久化参数无效，已回退本次input启动值。原因:", settings_error);
        B8_CopySettings(g_Startup_Settings, g_Runtime_Settings);
        B8_SaveRuntimeSettings();
        g_Settings_Message = "持久化异常，已恢复启动值";
    }

    string order_settings_error = "";
    if (!B8_ValidateOrderSettings(g_Order_Runtime_Settings, order_settings_error))
    {
        Print("[Bot8][订单级参数恢复] 持久化参数无效，已回退本次input启动值。原因:", order_settings_error);
        B8_CopyOrderSettings(g_Order_Startup_Settings, g_Order_Runtime_Settings);
        B8_SaveOrderRuntimeSettings();
        g_Order_Settings_Message = "订单级持久化异常，已恢复启动值";
    }

    B8_CopySettings(g_Runtime_Settings, g_Edit_Settings);
    B8_CopyOrderSettings(g_Order_Runtime_Settings, g_Order_Edit_Settings);
    g_Settings_Dirty = false;
    g_Order_Settings_Dirty = false;

    B8_LoadRuntimeState();

    // 止损最小距离过滤与分级路由阈值存在重叠风险时仅提醒，不阻止启动
    if (Enable_SL_Min_Filter && Enable_SL_Tier_Routing && SL_Min_Allowed_Points >= SL_Tier_Threshold_1_Points)
    {
        Print("[Bot8][参数提醒] SL_Min_Allowed_Points(", SL_Min_Allowed_Points,
              ") >= SL_Tier_Threshold_1_Points(", SL_Tier_Threshold_1_Points,
              ")，建议将最小距离设置得更小，避免与分级路由阈值语义重叠。");
    }

    // 创建右下角交互面板
    // B8_CreatePanel(); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
    B8_InitializePanels();
    B8_CreateRuntimeOrderPanel();
    B8_UpdateRuntimeOrderPanel();
    // B8_SetRuntimeOrderPanelCollapsed(true); // 旧版运行时查询、删除路径保留供回溯
    if (B8_InitializeRuntimeOrderPanelObjects())
        B8_SetRuntimeOrderPanelCollapsedFast(true);
    B8_CreateFibTemplatePanel();
    B8_UpdateFibTemplatePanel();
    // B8_SetFibTemplatePanelCollapsed(true); // 旧版运行时查询路径保留供回溯
    if (B8_InitializeFibTemplatePanelObjects())
        B8_SetFibTemplatePanelCollapsedFast(true);

    //#region MARK: 模块--EA自动开启独立模块接入
    B8_AutoActivation_Initialize();
    //#endregion

    Print("[KTarget_FinderBot8] 初始化成功。请点击面板 [开启] 按钮以激活交易。");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    B8_ReleaseMt7Handle();

    //#region MARK: 模块--EA自动开启独立模块退出
    B8_AutoActivation_Deinitialize();
    //#endregion

    // 退出时保存当前运行状态，便于周期切换后恢复
    B8_SaveRuntimeState();

    // 删除所有面板对象
    ObjectsDeleteAll(0, B8_PREFIX);
    ChartRedraw();
}

// [新增] 周期切换或 MT7 延迟初始化时，等待新的参数快照出现。
void OnTimer()
{
    if (g_B8_Mt7_Ready)
    {
        EventKillTimer();
        return;
    }

    if (!B8_ReadIndicatorSnapshot(g_B8_Indicator_Snapshot))
        return;

    if (!B8_CreateMt7Handle())
        return;

    ResetLastError();
    double snapshot_check = B8_ReadIndicatorBufferFromSnapshot(2, 0);
    int snapshot_error = GetLastError();
    if (snapshot_error == 4802)
    {
        g_B8_Indicator_Snapshot.valid = false;
        Print("[Bot8][MT7参数] 快照已出现，但指标仍未可用，继续等待: ", IndicatorName);
        ResetLastError();
        return;
    }

    g_B8_Mt7_Ready = true;
    EventKillTimer();
    ResetLastError();
    Print("[Bot8][MT7参数] MT7 快照已就绪，恢复交易。");
}

//+------------------------------------------------------------------+
//| OnTick  —— 核心逻辑循环                                          |
//+------------------------------------------------------------------+
void OnTick()
{
    // 0. 浮盈目标价可视化（与交易开关解耦，只要EA挂载即持续刷新）
    // 目标线被鼠标选中/拖动时暂停价格回写，避免与用户拖动抢写位置。
    bool equity_target_line_selected = false;
    if (ObjectFind(0, B8_EQ_TARGET_LINE) >= 0)
    {
        equity_target_line_selected =
            (ObjectGetInteger(0, B8_EQ_TARGET_LINE, OBJPROP_SELECTED) != 0);
    }
    if (!equity_target_line_selected)
        B8_UpdateEquityTargetVisual();

    // 1. 账户浮盈保护（独立于开仓逻辑，EA关闭时仍可执行）
    B8_ManageEquityProtectionV2();

    // 1.1 订单级减仓/保本（独立于账户级保护，EA关闭时仍可执行）
    B8_ManageOrderProtection();

    // 只有启用挂单入口时才运行挂单组维护；纯市价模式不进入挂单模块。
    if (g_Runtime_Entry_Mode != B8_ENTRY_MARKET)
        B8_ManagePendingGroups();

    // 实时风险统计独立于EA交易开关，始终反映当前已成交持仓。
    B8_UpdateRiskPanel();
    B8_UpdateRuntimeOrderPanel();
    B8_UpdateFibTemplatePanel();

    //#region MARK: 模块--EA自动开启独立模块Tick监控
    B8_AutoActivation_OnTick();
    //#endregion

    // MT7 参数快照未就绪时，禁止进入任何新信号交易流程。
    if (!g_B8_Mt7_Ready) return;

    // 2. EA 未启用 → 仅停止新开仓逻辑
    if (!g_EA_Enabled) return;

    // 3. 交易信号检查入口
    // 正常入口仍然完全依赖 g_last_bar_time：EA 提前开启时，每根当前 K 线只检查一次。
    // 手动补检入口则只在用户刚刚点击“开启”后生效一次，用于读取当前最新的 K[1]；
    // 它不修改 g_last_bar_time，因此不会破坏正常的新 K 线去重行为。
    bool is_manual_recheck = g_manual_recheck_pending;
    if (is_manual_recheck)
    {
        // 请求只消费一次。即使没有信号或订单被风控拒绝，也不在后续 Tick 重复尝试。
        g_manual_recheck_pending = false;
        // [旧代码保留] g_manual_recheck_bar_time = Time[0];
        g_manual_recheck_bar_time = B8_GetCurrentBarTime();
    }
    else
    {
        // 正常路径：每根当前 K 线只处理一次。
        // 如果本根 K 线刚刚完成过手动补检，则不再由正常入口重复处理。
        // [旧代码保留] if (Time[0] == g_manual_recheck_bar_time) return;
        if (B8_GetCurrentBarTime() == g_manual_recheck_bar_time) return;
        // [旧代码保留] if (Time[0] == g_last_bar_time) return;
        if (B8_GetCurrentBarTime() == g_last_bar_time) return;
        // [旧代码保留] g_last_bar_time = Time[0];
        g_last_bar_time = B8_GetCurrentBarTime();
    }

    // 仅记录本次信号检查的入口来源，便于实盘区分正常扫描和手动补检。
    // 日志放在入口分流之后，不参与任何交易判断，也不改变后续执行顺序。
    Print("[Bot8][信号检查入口] 类型:",
          (is_manual_recheck ? "手动开启后的补检" : "正常新K线扫描"),
          // [旧代码保留] " K[0]:", TimeToString(Time[0], TIME_DATE | TIME_MINUTES),
          " K[0]:", TimeToString(B8_GetCurrentBarTime(), TIME_DATE | TIME_MINUTES),
          // [旧代码保留] " K[1]:", TimeToString(Time[1], TIME_DATE | TIME_MINUTES));
          " K[1]:", TimeToString(B8_GetClosedBarTime(), TIME_DATE | TIME_MINUTES));

    // 纯市价模式保留原有前置持仓上限检查；挂单模式不在此处阻断信号。
    if (g_Runtime_Entry_Mode == B8_ENTRY_MARKET &&
        B8_CountOpenPositions() >= Max_Open_Orders) return;

    // 5. 读取指标在 K[1] 上的信号数据
    KBarSignal signal = B8_ReadSignalK1();

    // 6. 判断是否存在有效信号
    bool has_bull = (signal.BullishReferencePrice != (double)EMPTY_VALUE &&
                     signal.BullishReferencePrice != 0.0 &&
                     signal.BullishStopLossPrice  != (double)EMPTY_VALUE &&
                     signal.BullishStopLossPrice  != 0.0);

    bool has_bear = (signal.BearishReferencePrice != (double)EMPTY_VALUE &&
                     signal.BearishReferencePrice != 0.0 &&
                     signal.BearishStopLossPrice  != (double)EMPTY_VALUE &&
                     signal.BearishStopLossPrice  != 0.0);

    // 7. 无信号 → 退出
    if (!has_bull && !has_bear) return;

    // 8. 普通模式下，多空信号同时出现 → 记录日志，不执行交易
    if (g_Trade_Mode == B8_MODE_NORMAL && has_bull && has_bear)
    {
        Print("[Bot8][普通模式] K[1] 多空信号同时出现，本轮不交易。"
              // [旧代码保留] "时间: ", TimeToString(Time[1]),
              "时间: ", TimeToString(B8_GetClosedBarTime()),
              " 看涨SL=", DoubleToString(signal.BullishStopLossPrice, _Digits),
              " 看跌SL=", DoubleToString(signal.BearishStopLossPrice, _Digits));
        return;
    }

    // 9. 根据当前交易模式执行信号
    switch (g_Trade_Mode)
    {
        // ── 普通模式：到此步骤多空必有且仅有一个信号 ──
        case B8_MODE_NORMAL:
            if (has_bull)
            {
                // [旧代码保留] Print("[Bot8][普通模式] 看涨信号 K[1]=", TimeToString(Time[1]),
                Print("[Bot8][普通模式] 看涨信号 K[1]=", TimeToString(B8_GetClosedBarTime()),
                      " SL=", DoubleToString(signal.BullishStopLossPrice, _Digits));
                if (g_Runtime_Entry_Mode != B8_ENTRY_PENDING)
                    B8_ExecuteTrade(signal, OP_BUY);
                if (g_Runtime_Entry_Mode != B8_ENTRY_MARKET)
                    B8_CreatePendingPlans(signal, OP_BUY);
            }
            else if (has_bear)
            {
                // [旧代码保留] Print("[Bot8][普通模式] 看跌信号 K[1]=", TimeToString(Time[1]),
                Print("[Bot8][普通模式] 看跌信号 K[1]=", TimeToString(B8_GetClosedBarTime()),
                      " SL=", DoubleToString(signal.BearishStopLossPrice, _Digits));
                if (g_Runtime_Entry_Mode != B8_ENTRY_PENDING)
                    B8_ExecuteTrade(signal, OP_SELL);
                if (g_Runtime_Entry_Mode != B8_ENTRY_MARKET)
                    B8_CreatePendingPlans(signal, OP_SELL);
            }
            break;

        // ── 只多模式：仅接受看涨信号 ──
        case B8_MODE_BUY_ONLY:
            if (has_bull)
            {
                // [旧代码保留] Print("[Bot8][只多模式] 看涨信号 K[1]=", TimeToString(Time[1]),
                Print("[Bot8][只多模式] 看涨信号 K[1]=", TimeToString(B8_GetClosedBarTime()),
                      " SL=", DoubleToString(signal.BullishStopLossPrice, _Digits));
                if (g_Runtime_Entry_Mode != B8_ENTRY_PENDING)
                    B8_ExecuteTrade(signal, OP_BUY);
                if (g_Runtime_Entry_Mode != B8_ENTRY_MARKET)
                    B8_CreatePendingPlans(signal, OP_BUY);
            }
            else
            {
                Print("[Bot8][只多模式] K[1] 为看跌信号，已被过滤，不执行。"
                      // [旧代码保留] "时间: ", TimeToString(Time[1]));
                      "时间: ", TimeToString(B8_GetClosedBarTime()));
            }
            break;

        // ── 只空模式：仅接受看跌信号 ──
        case B8_MODE_SELL_ONLY:
            if (has_bear)
            {
                // [旧代码保留] Print("[Bot8][只空模式] 看跌信号 K[1]=", TimeToString(Time[1]),
                Print("[Bot8][只空模式] 看跌信号 K[1]=", TimeToString(B8_GetClosedBarTime()),
                      " SL=", DoubleToString(signal.BearishStopLossPrice, _Digits));
                if (g_Runtime_Entry_Mode != B8_ENTRY_PENDING)
                    B8_ExecuteTrade(signal, OP_SELL);
                if (g_Runtime_Entry_Mode != B8_ENTRY_MARKET)
                    B8_CreatePendingPlans(signal, OP_SELL);
            }
            else
            {
                Print("[Bot8][只空模式] K[1] 为看涨信号，已被过滤，不执行。"
                      // [旧代码保留] "时间: ", TimeToString(Time[1]));
                      "时间: ", TimeToString(B8_GetClosedBarTime()));
            }
            break;

        default:
            break;
    }
    // 在“EA一直关闭，信号出现于K1，用户在K0未收线前开启”的场景下：当前代码通常会开仓。这个不稳定，后面实现了补仓机制 还没有测试
}

//+------------------------------------------------------------------+
//| OnChartEvent  —— 面板按钮事件处理                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long   &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // 处理历史K线选择模式下的主图点击事件。
    if (id == CHARTEVENT_CLICK && g_History_Select_Mode)
    {
        // 过滤按钮点击穿透或连续点击，避免一次操作被重复处理。
        if (GetTickCount() - g_History_Last_Button_Click < 400)
            return;

        B8_HandleHistoricalChartClick(lparam, dparam);
        return;
    }

    if (g_Custom_Fib_Pick_Mode != B8_PRICE_PICK_NONE)
    {
        // 参考历史K线选择模式，过滤取价按钮点击产生的图表点击穿透。
        if (id == CHARTEVENT_CLICK &&
            GetTickCount() - g_Custom_Fib_Last_Button_Click < 400)
            return;

        if (B8_HandleCustomFibPricePickEvent(id, lparam, dparam))
            return;
    }

    //#region MARK: 模块--EA自动开启独立面板事件
    if (B8_AutoActivation_HandleChartEvent(id, sparam))
        return;
    //#endregion

    // 拖动账户浮盈目标线后，立即反算并应用新的账户触发百分比。
    if (id == CHARTEVENT_OBJECT_DRAG && sparam == B8_EQ_TARGET_LINE)
    {
        double dragged_price = ObjectGetDouble(0, B8_EQ_TARGET_LINE,
                                               OBJPROP_PRICE);
        B8_ApplyDraggedEquityTargetPrice(dragged_price);
        // 反算完成后解除选中状态，恢复下一 tick 的自动目标线刷新。
        ObjectSetInteger(0, B8_EQ_TARGET_LINE, OBJPROP_SELECTED, false);
        ChartRedraw();
        return;
    }

    // 处理主参数编辑框结束编辑事件，标记参数存在尚未应用的修改。
    if (id == CHARTEVENT_OBJECT_ENDEDIT && B8_IsMainSettingsEditObject(sparam))
    {
        B8_MarkSettingsDirty();
        return;
    }

    if (id == CHARTEVENT_OBJECT_ENDEDIT && B8_IsOrderSettingsEditObject(sparam))
    {
        B8_MarkOrderSettingsDirty();
        return;
    }

    //#region MARK: 模块--自定义价格输入同步
    if (id == CHARTEVENT_OBJECT_ENDEDIT &&
        (sparam == B8_CUSTOM_FIB_ENTRY_EDIT ||
         sparam == B8_CUSTOM_FIB_STOP_EDIT))
    {
        if (sparam == B8_CUSTOM_FIB_ENTRY_EDIT)
            g_Custom_Fib_Entry_Price = StringToDouble(
                ObjectGetString(0, sparam, OBJPROP_TEXT));
        else
            g_Custom_Fib_Stop_Price = StringToDouble(
                ObjectGetString(0, sparam, OBJPROP_TEXT));
        g_Custom_Fib_Status_Message = "自定义价格已更新";
        B8_UpdateCustomFibPanel();
        return;
    }
    //#endregion

    if (id == CHARTEVENT_OBJECT_CLICK && B8_IsRuntimeOrderEditObject(sparam))
    {
        g_Runtime_Order_Inputs_Editing = true;
        return;
    }

    if (id == CHARTEVENT_OBJECT_ENDEDIT && B8_IsRuntimeOrderEditObject(sparam))
    {
        g_Runtime_Order_Inputs_Editing = true;
        return;
    }

    // 模板输入框编辑期间，禁止 OnTick 回填旧模板值；应用按钮会重新同步显示。
    if (id == CHARTEVENT_OBJECT_CLICK && B8_IsFibTemplateEditObject(sparam))
    {
        g_Fib_Template_Inputs_Editing = true;
        return;
    }

    if (id == CHARTEVENT_OBJECT_ENDEDIT && B8_IsFibTemplateEditObject(sparam))
    {
        g_Fib_Template_Inputs_Editing = true;
        return;
    }

    if (id == CHARTEVENT_OBJECT_CLICK && B8_HandleRuntimeOrderPanelEvent(sparam))
        return;

    if (id == CHARTEVENT_OBJECT_CLICK && B8_HandleFibTemplatePanelEvent(sparam))
        return;

    if (id == CHARTEVENT_OBJECT_CLICK && B8_HandleFibPanelEvent(sparam))
        return;

    //#region MARK: 模块--自定义价格补挂面板事件
    if (id == CHARTEVENT_OBJECT_CLICK && B8_HandleCustomFibPanelEvent(sparam))
        return;
    //#endregion

    if (id == CHARTEVENT_OBJECT_CLICK &&
        (sparam == B8_CUSTOM_FIB_PICK_ENTRY ||
         sparam == B8_CUSTOM_FIB_PICK_STOP))
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_StartCustomFibPricePick(
            sparam == B8_CUSTOM_FIB_PICK_ENTRY
            ? B8_PRICE_PICK_ENTRY : B8_PRICE_PICK_STOP);
        return;
    }

    // 处理历史K线shift输入框结束编辑事件，刷新历史信号预览。
    if (id == CHARTEVENT_OBJECT_ENDEDIT && sparam == B8_FIB_HISTORY_SHIFT)
    {
        B8_RefreshHistoricalSignalPreview();
        return;
    }

    // 后续分支只处理面板对象点击事件，其他图表事件直接忽略。
    if (id != CHARTEVENT_OBJECT_CLICK) return;

    // 进入历史K线选择模式，等待用户点击主图中的目标K线。
    if (sparam == B8_FIB_HISTORY_SELECT)
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_EnterHistoricalSelectMode();
        return;
    }

    // 取消历史K线选择模式，放弃当前选择操作。
    if (sparam == B8_FIB_HISTORY_CANCEL)
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_CancelHistoricalSelectMode();
        return;
    }

    // 执行当前历史K线的Fib挂单计划创建。
    if (sparam == B8_FIB_HISTORY_EXECUTE)
    {
        Print("[Bot8][历史补挂调试] 收到执行按钮点击。对象:", sparam,
              " 当前shift:", g_History_Selected_Shift,
              " 预览有效标记(刷新前):", (g_History_Preview_Valid ? "true" : "false"));
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_RefreshHistoricalSignalPreview();
        Print("[Bot8][历史补挂调试] 预览刷新完成。shift:", g_History_Selected_Shift,
              " 预览有效标记(刷新后):", (g_History_Preview_Valid ? "true" : "false"),
              " 状态:", g_History_Status_Message);
        // 仅在历史信号预览有效时，才允许创建历史挂单计划。
        if (g_History_Preview_Valid)
            B8_CreateHistoricalPendingPlans(g_History_Preview_Signal,
                                            g_History_Selected_Shift);
        else
            Print("[Bot8][历史补挂调试] 预览无效，未调用历史补挂计划函数。");
        return;
    }

    // 删除当前选中历史K线创建的、仍未成交的历史Fib挂单。
    if (sparam == B8_FIB_HISTORY_DELETE)
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_DeleteHistoricalPendingPlans(g_History_Selected_Shift);
        return;
    }

    // 处理单个Fib位置按钮，切换该位置是否参与挂单并保存选择状态。
    int fib_index = B8_PendingFibButtonIndex(sparam);
    if (fib_index >= 0)
    {
        g_Pending_Fib_Selected[fib_index] = !g_Pending_Fib_Selected[fib_index];
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_SavePendingFibSettings();
        B8_UpdateFibPanel();
        ChartRedraw();
        return;
    }

    // 处理Fib位置“全选”或“全不选”按钮。
    if (sparam == B8_FIB_BTN_ALL || sparam == B8_FIB_BTN_NONE)
    {
        B8_SetAllPendingFib(sparam == B8_FIB_BTN_ALL);
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        ChartRedraw();
        return;
    }

    // 处理Fib挂单预设按钮，应用对应的预设位置组合。
    if (sparam == B8_FIB_BTN_PRESET_1 ||
        sparam == B8_FIB_BTN_PRESET_2 ||
        sparam == B8_FIB_BTN_PRESET_3)
    {
        int preset_index = (sparam == B8_FIB_BTN_PRESET_1) ? 0
                           : ((sparam == B8_FIB_BTN_PRESET_2) ? 1 : 2);
        B8_ApplyPendingFibPreset(preset_index);
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        ChartRedraw();
        return;
    }

    // ── [参数/隐藏] 按钮：只切换参数面板可见性，不应用或放弃编辑值 ──
    // 切换主参数面板的显示状态，同时保留当前编辑内容。
    if (sparam == B8_BTN_SETTINGS_VISIBILITY)
    {
        g_SettingsPanelVisible = !g_SettingsPanelVisible;
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_SetCorePanelsVisible(g_SettingsPanelVisible);
        B8_AutoActivation_SetExpanded_New(g_SettingsPanelVisible);
        B8_SaveRuntimeState();
        ChartRedraw();
        return;
    }

    // ── [开启/关闭] 按钮 ──
    // 切换EA交易开关，并管理开启后的K[1]信号补检状态。
    if (sparam == B8_BTN_ENABLE)
    {
        bool was_enabled = g_EA_Enabled;
        g_EA_Enabled = !g_EA_Enabled;

        // 仅在“关闭 -> 开启”的瞬间安排一次补检。
        // 不清零 g_last_bar_time：正常的新 K 线捕获机制必须保持原有语义。
        // 关闭后清除尚未执行的手动补检请求，避免重新开启时误触发旧请求。
        // [旧代码保留] if (!was_enabled && g_EA_Enabled && g_manual_recheck_bar_time != Time[0])
        if (!was_enabled && g_EA_Enabled &&
            g_manual_recheck_bar_time != B8_GetCurrentBarTime())
            g_manual_recheck_pending = true;
        // 仅处理“已开启 -> 已关闭”的状态切换。
        else if (was_enabled && !g_EA_Enabled)
            g_manual_recheck_pending = false;

        B8_SaveRuntimeState();
        ObjectSetInteger(0, B8_BTN_ENABLE, OBJPROP_STATE, false); // 弹起
        B8_UpdatePanel();
        B8_UpdateSettingsPanel();
        ChartRedraw();
        Print("[Bot8] EA 状态 → ", (g_EA_Enabled ? "【开启】" : "【关闭】"));
        return;
    }

    // ── 入场方式快速切换 ──
    // 只影响后续新信号，不修改已经存在的持仓或挂单。
    if (sparam == B8_BTN_ENTRY_MARKET ||
        sparam == B8_BTN_ENTRY_PENDING ||
        sparam == B8_BTN_ENTRY_BOTH)
    {
        if (sparam == B8_BTN_ENTRY_MARKET)
            g_Runtime_Entry_Mode = B8_ENTRY_MARKET;
        else if (sparam == B8_BTN_ENTRY_PENDING)
            g_Runtime_Entry_Mode = B8_ENTRY_PENDING;
        else
            g_Runtime_Entry_Mode = B8_ENTRY_MARKET_AND_PENDING;

        B8_SaveRuntimeState();
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_UpdatePanel();
        B8_UpdateSettingsPanel();
        ChartRedraw();
        Print("[Bot8] 入场方式 → ", B8_EntryModeText(g_Runtime_Entry_Mode));
        return;
    }

    // ── [普通模式] 按钮 ──
    // 设置为普通交易模式，允许根据策略处理多空信号。
    if (sparam == B8_BTN_NORMAL)
    {
        g_Trade_Mode = B8_MODE_NORMAL;
        B8_SaveRuntimeState();
        ObjectSetInteger(0, B8_BTN_NORMAL, OBJPROP_STATE, false);
        B8_UpdatePanel();
        B8_UpdateSettingsPanel();
        ChartRedraw();
        Print("[Bot8] 交易模式 → 【普通模式】");
        return;
    }

    // ── [只多模式] 按钮 ──
    // 设置为只多交易模式，仅接受看涨信号。
    if (sparam == B8_BTN_BUY_ONLY)
    {
        g_Trade_Mode = B8_MODE_BUY_ONLY;
        B8_SaveRuntimeState();
        ObjectSetInteger(0, B8_BTN_BUY_ONLY, OBJPROP_STATE, false);
        B8_UpdatePanel();
        B8_UpdateSettingsPanel();
        ChartRedraw();
        Print("[Bot8] 交易模式 → 【只多模式】");
        return;
    }

    // ── [只空模式] 按钮 ──
    // 设置为只空交易模式，仅接受看跌信号。
    if (sparam == B8_BTN_SELL_ONLY)
    {
        g_Trade_Mode = B8_MODE_SELL_ONLY;
        B8_SaveRuntimeState();
        ObjectSetInteger(0, B8_BTN_SELL_ONLY, OBJPROP_STATE, false);
        B8_UpdatePanel();
        B8_UpdateSettingsPanel();
        ChartRedraw();
        Print("[Bot8] 交易模式 → 【只空模式】");
        return;
    }

    // ── 参数编辑区：仓位模式互斥按钮 ──
    // 切换固定手数与风险仓位两种仓位计算模式。
    if (sparam == B8_BTN_POS_FIXED || sparam == B8_BTN_POS_RISK)
    {
        // 根据被点击的按钮选择对应的仓位计算模式。
        g_Edit_Settings.position_mode = (sparam == B8_BTN_POS_FIXED)
                        ? POS_FIXED_LOT
                        : POS_RISK_BASED;
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_MarkSettingsDirty();
        return;
    }

    // ── 参数编辑区：风险模式互斥按钮 ──
    // 切换固定金额风险与余额百分比风险两种风险计算模式。
    if (sparam == B8_BTN_RISK_MONEY || sparam == B8_BTN_RISK_PCT)
    {
        // 根据被点击的按钮选择对应的风险计算模式。
        g_Edit_Settings.risk_mode = (sparam == B8_BTN_RISK_MONEY)
                        ? RISK_FIXED_MONEY
                        : RISK_PERCENTAGE;
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_MarkSettingsDirty();
        return;
    }

    // ── 参数编辑区：浮盈保护开关（编辑态，应用后生效） ──
    // 切换账户浮盈保护的编辑状态，点击应用后才写入运行参数。
    if (sparam == B8_BTN_EP_TOGGLE)
    {
        g_Edit_Settings.equity_protect_enabled = !g_Edit_Settings.equity_protect_enabled;
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_MarkSettingsDirty();
        return;
    }

    // ── 参数编辑区：账户级浮盈保护动作 ──
    // 该动作只影响账户级浮盈保护，不复用订单级“仅平仓”模式。
    if (sparam == B8_BTN_EP_ACTION_PARTIAL_BE ||
        sparam == B8_BTN_EP_ACTION_CLOSE)
    {
        g_Edit_Settings.equity_protection_action =
            (sparam == B8_BTN_EP_ACTION_CLOSE)
            ? B8_EQUITY_CLOSE_ONLY
            : B8_EQUITY_PARTIAL_BE;
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_MarkSettingsDirty();
        return;
    }

    // ── 参数编辑区：应用输入框与按钮选择 ──
    // 读取、校验并应用主参数面板中的编辑内容。
    if (sparam == B8_BTN_APPLY)
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        string error_text = "";
        bool main_fields_ok = B8_ReadEditFields(error_text);
        // 输入框内容不合法时，保留编辑状态并显示错误信息。
        if (!main_fields_ok)
        {
            g_Settings_Message = "输入错误: " + error_text;
            g_Settings_Dirty = true;
        }
        // 输入合法且整组参数应用成功时，刷新风险提示和输入框显示。
        else if (B8_ApplyEditSettings("面板输入"))
        {
            g_Settings_Message = "参数已应用";
            // 风险仓位+百分比模式下，补充显示按当前余额换算后的风险金额。
            if (g_Runtime_Settings.position_mode == POS_RISK_BASED &&
                g_Runtime_Settings.risk_mode == RISK_PERCENTAGE)
            {
                double balance_risk_money = AccountBalance() *
                                            (g_Runtime_Settings.risk_value / 100.0);
                g_Settings_Message = "已应用，余额风险: " +
                                     DoubleToString(balance_risk_money, 2);
            }
            B8_WriteEditFields();
        }
        else
        {
            g_Settings_Message = "参数校验失败";
            g_Settings_Dirty = true;
        }
        B8_UpdateSettingsPanel();
        ChartRedraw();
        return;
    }

    // ── 恢复当前运行值：放弃未应用修改 ──
    // 放弃编辑区的未应用修改，恢复为当前正在运行的参数。
    if (sparam == B8_BTN_RESTORE)
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_CopySettings(g_Runtime_Settings, g_Edit_Settings);
        g_Settings_Dirty = false;
        g_Settings_Message = "已恢复当前值";
        B8_WriteEditFields();
        B8_UpdateSettingsPanel();
        ChartRedraw();
        return;
    }

    // ── 恢复启动值：写入编辑区，仍需点击应用 ──
    // 将本次启动时的默认参数写回编辑区，但不立即应用到交易逻辑。
    if (sparam == B8_BTN_DEFAULTS)
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_CopySettings(g_Startup_Settings, g_Edit_Settings);
        g_Settings_Dirty = true;
        g_Settings_Message = "启动值待应用";
        B8_WriteEditFields();
        B8_UpdateSettingsPanel();
        ChartRedraw();
        return;
    }

    // 切换订单级保护功能的编辑状态。
    if (sparam == B8_BTN_ORDER_ENABLED)
    {
        g_Order_Edit_Settings.order_protection_enabled = !g_Order_Edit_Settings.order_protection_enabled;
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_MarkOrderSettingsDirty();
        return;
    }

    // 切换订单级保护的触发方式：固定点数或风险R倍数。
    if (sparam == B8_BTN_ORDER_TRIGGER_POINTS || sparam == B8_BTN_ORDER_TRIGGER_R)
    {
        // 根据被点击的按钮记录对应的触发模式。
        g_Order_Edit_Settings.order_trigger_mode = (sparam == B8_BTN_ORDER_TRIGGER_R)
                                                   ? B8_ORDER_TRIGGER_R
                                                   : B8_ORDER_TRIGGER_POINTS;
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_MarkOrderSettingsDirty();
        return;
    }

    // 切换订单级保护动作：仅减仓、仅保本或减仓加保本。
    if (sparam == B8_BTN_ORDER_MODE_PARTIAL ||
        sparam == B8_BTN_ORDER_MODE_BE ||
        sparam == B8_BTN_ORDER_MODE_PARTIAL_BE ||
        sparam == B8_BTN_ORDER_MODE_CLOSE)
    {
        // 根据具体按钮设置订单级保护动作模式。
        if (sparam == B8_BTN_ORDER_MODE_PARTIAL)
            g_Order_Edit_Settings.order_protection_mode = B8_ORDER_PARTIAL_ONLY;
        // 选择仅保本模式。
        else if (sparam == B8_BTN_ORDER_MODE_BE)
            g_Order_Edit_Settings.order_protection_mode = B8_ORDER_BE_ONLY;
        else if (sparam == B8_BTN_ORDER_MODE_PARTIAL_BE)
            g_Order_Edit_Settings.order_protection_mode = B8_ORDER_PARTIAL_BE;
        // 仅平仓模式达到触发条件后直接关闭该订单的全部手数。
        else
            g_Order_Edit_Settings.order_protection_mode = B8_ORDER_CLOSE_ONLY;

        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_MarkOrderSettingsDirty();
        return;
    }

    // 读取、校验并应用订单级保护面板中的编辑内容。
    if (sparam == B8_BTN_ORDER_APPLY)
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        string order_error = "";
        // 订单级输入框内容不合法时，保留编辑状态并显示错误信息。
        if (!B8_ReadOrderEditFields(order_error))
        {
            g_Order_Settings_Message = "订单管理输入错误: " + order_error;
            g_Order_Settings_Dirty = true;
        }
        // 订单级参数合法且应用成功时，刷新面板输入框显示。
        else if (B8_ApplyOrderEditSettings("订单管理面板"))
        {
            g_Order_Settings_Message = "订单管理参数已应用";
            B8_WriteOrderEditFields();
            B8_UpdateOrderPanel();
        }
        else
        {
            g_Order_Settings_Message = "订单管理参数校验失败";
            g_Order_Settings_Dirty = true;
        }
        ChartRedraw();
        return;
    }

    // 放弃订单级编辑区的未应用修改，恢复为当前运行参数。
    if (sparam == B8_BTN_ORDER_RESTORE)
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        B8_CopyOrderSettings(g_Order_Runtime_Settings, g_Order_Edit_Settings);
        g_Order_Settings_Message = "订单管理已恢复当前值";
        B8_WriteOrderEditFields();
        B8_UpdateOrderPanel();
        g_Order_Settings_Dirty = false;
        ChartRedraw();
        return;
    }

    // 处理订单级保护预设按钮，应用对应的订单保护参数组合。
    if (sparam == B8_BTN_ORDER_PRESET_SAFE ||
        sparam == B8_BTN_ORDER_PRESET_STD ||
        sparam == B8_BTN_ORDER_PRESET_FAST)
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        int order_preset_index = (sparam == B8_BTN_ORDER_PRESET_SAFE) ? 0
                                : ((sparam == B8_BTN_ORDER_PRESET_STD) ? 1 : 2);
        B8_ApplyOrderPreset(order_preset_index);
        return;
    }

    // ── 预设组：写入编辑区并立即应用 ──
    // 处理主参数预设按钮，写入并立即应用对应的主参数组合。
    if (sparam == B8_BTN_PRESET_SAFE ||
        sparam == B8_BTN_PRESET_STD ||
        sparam == B8_BTN_PRESET_FAST)
    {
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        int preset_index = (sparam == B8_BTN_PRESET_SAFE) ? 0
                           : ((sparam == B8_BTN_PRESET_STD) ? 1 : 2);
        B8_ApplyPreset(preset_index);
        return;
    }
}

#include <K8Bot/B8_Core_BasicFun.mqh>

#include <K8Bot/B8_Persistence.mqh>

#include <K8Bot/B8_HelperFun.mqh>

#include <K8Bot/B8_MainLogic.mqh>

#include <K8Bot/B8_UI.mqh>

//#region MARK: 模块--EA自动开启独立模块实现
#include <K8Bot/B8_AutoActivation.mqh>
//#endregion

//+------------------------------------------------------------------+
// END OF FILE
//+------------------------------------------------------------------+