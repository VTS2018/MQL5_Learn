//+------------------------------------------------------------------+
//|                          K-Target 突破信号识别指标 (XBreaking Signal)
//+------------------------------------------------------------------+
/*
   功能描述:
   本指标基于价格行为分析中的 K-Target (目标 K 线) 和 IB/DB (内部突破/外部突破) 概念设计。
   它旨在自动识别图表上的关键水平，并在价格首次有效突破这些水平时发出信号，并绘制辅助趋势线。

   核心逻辑:
   1. K-Target 锚点识别: 
      - 识别出一段时间周期内 (由 Lookback/Lookahead 参数控制) 具有最低收盘价的阴线 (看涨锚点)，或最高收盘价的阳线 (看跌锚点)。
      - 这些锚点通常代表市场反转的起点或关键支撑/阻力位。
   2. 突破确认 (IB/DB): 
      - **第一基准价格线 (P1):** K-Target 锚点的开盘价。
      - **第二基准价格线 (P2):** 锚点左侧第一根反转 K 线的收盘价。
      - 突破发生在 P1 之上，并且根据 K 线数量 (N) 分类为 IB (N<=2) 或 DB (N>=3)。
   3. 信号绘制: 
      - 在突破发生的 K 线上方/下方绘制最终信号箭头。
      - 绘制两条水平趋势线：一条是 P1 (实线)，一条是 P2 (虚线)。

   趋势线属性:
   - 始点: K-Target 锚点 K 线的 Open 价格和时间。
   - 终点: 突破 K 线的时间 + 2 根 K 线 (保证长度适中，非射线)。
*/

//+------------------------------------------------------------------+
//|                          版本迭代日志 (Changelog)
//+------------------------------------------------------------------+
/*
   日期           | 版本    | 描述
   ------------------------------------------------------------------
   2025.10.28     | v1.17   | 初始版本。集成 K-Target 锚点识别 (Bottom/Top) 和 IB/DB 突破确认逻辑。
   2025.11.05     | v1.18   | 修复 `OnDeinit` 函数签名，以消除 MQL4 编译器警告。添加图表对象清理机制。
   2025.11.12     | v1.19   | 优化趋势线终点设置逻辑。终点从突破 K 线时间开始，向右延伸 2 根 K 线，避免线条过长。
   2025.11.18     | v1.20   | 明确设置趋势线为非射线 (`OBJPROP_RAY = false`)，确保其为固定长度的线段。
   2025.11.18     | v1.21   | 修正了 `#property` 绘图属性中的重复设置：将 Plot 2 的 `indicator_width1` 修正为 `indicator_width2`。
   2025.11.18     | v1.22   | **[当前版本]** 增加 IB/DB 突破分类和第二基准价格线 (P2) 查找逻辑，并在图表上绘制 P2 辅助线。
   ------------------------------------------------------------------
*/
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MQL Developer"
#property link      "https://www.mql5.com"
#property version   "1.5" 
#property description "正版授权、续期及技术支持请联系作者微信：wglove921"
#property strict
#property indicator_chart_window // 绘制在主图表窗口
#property indicator_buffers 4 // 两个锚点 + 两个最终信号
#property indicator_plots   4 // 对应四个绘图

// MQL5 does not expose the MQL4 global OHLC series arrays to included
// functions. The conversion keeps the existing index-based strategy code
// intact by binding it to arrays synchronized from OnCalculate below.
#define Open   g_ktFinderOpen
#define High   g_ktFinderHigh
#define Low    g_ktFinderLow
#define Close  g_ktFinderClose
#define Time   g_ktFinderTime
#define Bars   g_ktFinderBars
#define Bid    SymbolInfoDouble(_Symbol, SYMBOL_BID)
#define Ask    SymbolInfoDouble(_Symbol, SYMBOL_ASK)
#define Digits _Digits

double   g_ktFinderOpen[];
double   g_ktFinderHigh[];
double   g_ktFinderLow[];
double   g_ktFinderClose[];
datetime g_ktFinderTime[];
int      g_ktFinderBars = 0;

#define MODE_TICKSIZE  1
#define MODE_TICKVALUE 2
#define MODE_SPREAD    3
#define MODE_DIGITS    4
#define MODE_LOTSIZE   5
double MarketInfo(const string symbol, const int mode)
{
    switch(mode)
    {
        case MODE_TICKSIZE:  return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        case MODE_TICKVALUE: return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        case MODE_SPREAD:    return (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
        case MODE_DIGITS:    return (double)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        case MODE_LOTSIZE:   return SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    }
    return 0.0;
}

double KT_GetATR(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period, const int shift)
{
    int handle = iATR(symbol, timeframe, period);
    if(handle == INVALID_HANDLE) return 0.0;
    double values[1];
    double result = 0.0;
    if(CopyBuffer(handle, 0, shift, 1, values) == 1)
        result = values[0];
    IndicatorRelease(handle);
    return result;
}

#include <KTLicense/Products/KTarget_Finder_MT7.mqh>
#include <K5/K_Data.mqh>

// 缓冲区 数据定义 核心配置 非核心配置 附属配置 会话配置 测试配置 计算利润 全局变量
// 除了K_Data之外 还应该增加一个独属于本指标自己使用的数据文件；数据定义一定要在函数声明之前，否则函数引用就会失效;Define_data
#include <Config7/Define_buffers.mqh>
#include <Config7/Define_data.mqh>
#include <Config7/Config_Core.mqh>
#include <Config7/Config_Non_Core.mqh>
#include <Config7/Config_Add.mqh>
// 会话和测试是各自独立的
#include <Config7/Config_Sessions.mqh>
#include <Config7/Config_Test.mqh>
#include <Config7/Config_Quick_Profit_Calc.mqh>
#include <Config7/Config_Global_var.mqh>

//+------------------------------------------------------------------+
//| 函数原型 应该提取单独的函数原型定义区域
//+------------------------------------------------------------------+
// #include <Config7/Config_Prototypes.mqh>
void FindAndDrawTargetCandles(int total_bars);

//#region MARK: 业务逻辑的函数声明
void ClearSignalBuffersForRefresh();
void UpdateStrictModeButtonStates();
void CreateStrictModeButton(string button_name, string button_text, int y_distance);
void CreateStrictModeButtons();
void DeleteStrictModeButtons();
void ApplyStrictQuickModeParams(StrictQuickMode target_mode);
void RefreshStrictModeCalculation();
bool HandleStrictModeButtonClick(string object_name);

bool IsKTargetBottom(int i, int total_bars);
bool IsKTargetTop(int i, int total_bars);
bool CheckKTargetBottom_Default(int i, int total_bars, int lookahead, int lookback);
bool CheckKTargetTop_Default(int i, int total_bars, int lookahead, int lookback);
bool CheckKTargetBottomCondition(int i, int total_bars, int lookahead, int lookback);
bool CheckKTargetTopCondition(int i, int total_bars, int lookahead, int lookback);

int FindFirstP1BreakoutIndex(int target_index, bool is_bullish);
int FindP2Index(int target_index, bool is_bullish);
int FindP2Index_BodyFullySeparated(int target_index, bool is_bullish);
int FindP2Index_Wrapper(int target_index, bool is_bullish);

int FindNextPLevel(int prev_index, double prev_price, bool is_bullish);
int FindNextPLevel_BodySeparated(int prev_index, double prev_price, bool is_bullish, int min_bars_between = 0);
int FindNextPLevel_Wrapper(int prev_index, double prev_price, bool is_bullish);

void FindAndDrawMultiplePLevels(int anchor_index, int P2_index, double P2_price, bool is_bullish);
int FindAbsoluteLowIndex(int target_index, int lookback_range, int lookahead_range, bool is_bullish);

void CheckBullishSignalConfirmation_Default(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_lowindex);
void CheckBearishSignalConfirmation_Default(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_hightindex);
void CheckBullishSignalConfirmationV2(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_lowindex);
void CheckBearishSignalConfirmationV2(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_highindex);

void CheckBullishSignalConfirmation(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_lowindex);
void CheckBearishSignalConfirmation(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_highindex);

bool CheckSignalStatus(int signal_index, double sl_price, bool is_bullish);
bool IsSignalPriceInvalidated(int signal_index, double sl_price, bool is_bullish);

double Calculate_Space_Factor(string sym, int period, double p1, double p2, int shift);
SignalQuality EvaluateSignal(
    string sym,
    int period,
    int n_geo_input,
    int breakout_idx,
    double p1,
    double p2,
    double sl,
    bool is_bullish
);

void DebugAlertCheck(string type, int signal_index, SignalQuality &sq);
bool SendRichAlert(string sym, int period, string type, double price, double sl, SignalQuality &sq);
double GetGradeWeight(ENUM_SIGNAL_GRADE grade);

void SaveParamsToChart_V1();
void SaveParamsToChart();
void Init_Smart_Tuning();
void Init_Object_prefix();
void Init_Buffer();
void DeInit_DelObject();

void HandleObjectClick(string sparam);
void HandleObjectDelete(string sparam);
void HandleProfit_Calc(string sparam, double dparam, long lparam);

color GetHighlightColorByPeriod(bool is_bullish);
int GetAdaptiveATRPeriod(int period);
double GetAdaptiveATRMultiplier(int period);
//#endregion

//#region MARK: 绘图的函数声明
void DrawTargetBottom(int target_index);
void DrawTargetTop(int target_index);

void DrawP1Baseline(
    int target_index,
    int breakout_index,
    bool is_bullish,
    double P2_price
);

void DrawP2Baseline(
    int target_index,
    int breakout_index,
    bool is_bullish
);

void DrawPnBaseline(
    int start_index,
    int end_index,
    int level,
    double price,
    bool is_bullish
);

void DrawAbsoluteSupportLine(
    int abs_index,
    bool is_bullish,
    int extend_bars
);

void DrawP1P2Rectangle(
    int target_index,
    int P2_index,
    bool is_bullish
);

void DrawP1P2Fibonacci(
    int target_index,
    int P2_index,
    bool is_bullish
);

void DrawFiboHighlightRectangles(
    int target_index,
    int P2_index,
    bool is_bullish
);

void ExecuteDrawFiboRects(
    int target_index,
    int P2_index,
    bool is_bullish,
    const FiboZone &zones[]
);

void DrawFiboHighlightText(
    string text_name,
    string text_content,
    datetime anchor_time,
    double anchor_price,
    int tf_flag,
    bool is_bullish
);

void DrawFiboGradeZones(
    string sym,
    int idx,
    double sl,
    double close,
    bool bullish,
    string prefix
);

void DrawSignalInfoText(
    int target_index,
    int signal_index,
    string type_str,
    double sl_price,
    double confirm_price,
    bool is_bullish
);

void CleanupInvalidSignalDrawings();

bool IsSignalReplacedByCloseInLookbackWindow(
    int anchor_index,
    int total_bars,
    bool is_bullish,
    int lookback_window
);

void CleanupReplacedSignalDrawings_ByLookbackWindow();

int ParseHourFromTimeString(string time_str);

void DrawMarketSessions(
    int lookback_days,
    int gmt_offset
);

void DrawSingleSession(
    datetime day_base,
    string name,
    int start_h_gmt,
    int end_h_gmt,
    int offset,
    color border_color
);

bool CollectAtrDisplaySnapshot(
    AtrDisplaySnapshot &snap
);

void UpdateAtrDashboardLines_Throttled(
    const AtrDisplaySnapshot &snap
);

void UpdateAtrSlArrows_Throttled(
    const AtrDisplaySnapshot &snap
);

void UpdateAtrCurrentPriceBigLabel_Fast(
    const AtrDisplaySnapshot &snap
);

void UpdateAtrPriceChangeLabel_Fast(
    const AtrDisplaySnapshot &snap
);

void UpdateATRDisplay();

void UpdateCalculation(
    datetime end_time,
    double end_price,
    int x,
    int y
);

void CreateLineObject();
void CreateLabelObjects();
void DeleteProfit_CalcObjects();

void CreateTradingRulesDisplay();
void DeleteTradingRulesDisplay();

void CreateConfigInfoDisplay();
void DeleteConfigInfoDisplay();
//#endregion

//+------------------------------------------------------------------+
//| ✅ 配置 数据 工具函数
//+------------------------------------------------------------------+
#include <K5/K_Utils.mqh>
#include <K7/K_Logic.mqh>
#include <K7/K_Drawing_Funcs.mqh>
#include <K7/K_Test.mqh>

// Copy the event arrays into a shared series cache before any included
// strategy or drawing function reads an MQL4-style indexed price series.
void KT_FinderSyncPriceSeries(const int rates_total,
                              const datetime &time[],
                              const double &open[],
                              const double &high[],
                              const double &low[],
                              const double &close[])
{
    g_ktFinderBars = rates_total;
    ArrayResize(g_ktFinderTime, rates_total);
    ArrayResize(g_ktFinderOpen, rates_total);
    ArrayResize(g_ktFinderHigh, rates_total);
    ArrayResize(g_ktFinderLow, rates_total);
    ArrayResize(g_ktFinderClose, rates_total);

    ArrayCopy(g_ktFinderTime, time, 0, 0, rates_total);
    ArrayCopy(g_ktFinderOpen, open, 0, 0, rates_total);
    ArrayCopy(g_ktFinderHigh, high, 0, 0, rates_total);
    ArrayCopy(g_ktFinderLow, low, 0, 0, rates_total);
    ArrayCopy(g_ktFinderClose, close, 0, 0, rates_total);

    ArraySetAsSeries(g_ktFinderTime, true);
    ArraySetAsSeries(g_ktFinderOpen, true);
    ArraySetAsSeries(g_ktFinderHigh, true);
    ArraySetAsSeries(g_ktFinderLow, true);
    ArraySetAsSeries(g_ktFinderClose, true);
}

//========================================================================
// 1. OnInit: 指标初始化
//========================================================================
string KTarget_InstanceSource()
{
    return Is_EA_Mode
           ? "iCustom/EA模式(推断)"
           : "图表手动挂载/非EA模式(推断)";
}

// 授权状态门闩：每个 MT7 指标实例各自拥有一份变量，初始为 false。
//
// 授权流程原理：
// 1. OnInit() 调用 KTargetFinderMt7LicenseInitialize()。
// 2. 该函数通过 KTLicense 公共授权核心读取 Common\Files\KTLicense\license.dat，
//    校验产品 ID、授权签名、有效期、账户和服务器信息。
// 3. 只有全部校验通过，当前指标实例才把本变量设为 true。
// 4. 变量为 true 后，才允许执行指标计算、绘图和图表事件处理。
//
// 该变量不是跨图表共享变量；其他图表或其他指标实例不会直接改写它。
bool g_ktFinderMt7Authorized = false;

void KTarget_Finder_MT7_InitializeAfterLicense()
{
    // 只有授权成功后才进入这里。该函数负责启动授权后的指标运行环境，
    // 包括参数初始化、缓冲区初始化、对象前缀、界面对象和参数快照发布。
    // 注意：这里不是许可证校验函数，也不会重新决定授权结果。

    // 图表交互仅供手动挂载实例使用；EA/iCustom 实例不需要生成这些图表级事件。
    if (!Is_EA_Mode)
    {
        // 开启鼠标移动事件检测
        ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);

        // 只有设置这个，OnChartEvent 才能接收到 CHARTEVENT_OBJECT_DELETE 事件
        ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
    }

    Init_Smart_Tuning();
    SaveParamsToChartForBot8();

    Init_Object_prefix();

    //+------------------------------------------------------------------+
    // 初始运行次数为0
    // g_run_count = 0;
    //+------------------------------------------------------------------+
    Init_Buffer();

    // 指标简称
    string shortName = "K-Target (B:"+IntegerToString(Lookback_Bottom)+" L:"+IntegerToString(Max_Signal_Lookforward)+") V1.23"; // [V1.22 UPD] 更新版本号
    IndicatorSetString(INDICATOR_SHORTNAME, shortName);

    RunTest();

    SaveParamsToChart();

    if (!Is_EA_Mode)
    {
        // [新增] 探测服务器时区
        DetectServerTimeZone();
    }

    // [新增] 创建交易纪律提醒显示
    CreateTradingRulesDisplay();
    
    // [新增] 创建配置信息显示板
    CreateConfigInfoDisplay();

    // [新增] 创建严格模式快捷切换按钮
    CreateStrictModeButtons();

    Print("[KTarget_Finder_MT7][OnInit] Is_EA_Mode=", (Is_EA_Mode ? "true" : "false"),
        " ChartID=", (long)ChartID(),
        " Symbol=", _Symbol,
        " Period=", _Period,
        " InstanceSource=", KTarget_InstanceSource());

    //#region MARK: 模块--
    // 非EA模式下 才启用 定时器和相关的打印逻辑
    if (!Is_EA_Mode)
    {
        // --- V1.31 NEW: 专门研究 (OnCalculate) ---
        // 2. 启动定时器：用于演示 OnTimer 函数的独立运行
        EventSetTimer(Timer_Interval_Seconds);

        // 3. 在图表上输出初始化信息 (使用 Comment 替代 Print 以获得图表反馈)
        string init_message =
            "*** INDICATOR INITIALIZED ***\n" +
            "Function: OnInit() executed.\n" +
            "Time: " + TimeToString(TimeCurrent(), TIME_SECONDS) + "\n" +
            "Timer set to: " + IntegerToString(Timer_Interval_Seconds) + " seconds.";

        // 减少打印日志的输出
        // Comment(init_message);
        // Print("---->[KTarget_Finder_MT7:205]: init_message: ", init_message);
        // --- V1.31 NEW: 专门研究 (OnCalculate) ---

        // Print("---->[KTarget_Finder_MT7.mq4:208]: ----OnInit 指标初始化完成---- ");
    }
    //#endregion
}

int OnInit()
{
    // 首次授权入口：OnInit() 先完成授权，再决定是否初始化 MT7 的业务逻辑。
    // KTargetFinderMt7LicenseInitialize() 返回 true 时，说明当前账户、服务器、
    // 产品签名和有效期均通过校验；授权失败时不会进入正常初始化流程。
    if (KTargetFinderMt7LicenseInitialize())
    {
        // 这是当前指标实例的本地授权状态。设置为 true 后，OnCalculate() 和
        // OnChartEvent() 才不会被授权门禁直接拦截。
        g_ktFinderMt7Authorized = true;
        KTarget_Finder_MT7_InitializeAfterLicense();
        return(INIT_SUCCEEDED);
    }

    // 账户尚未连接时，授权核心会返回“等待账户”状态。
    // 此时指标允许保持加载，但不能开始正常计算；OnTimer() 会继续重试授权。
    if (KTLicenseIsWaitingForAccount())
    {
        EventSetTimer(1);
        Print("[KT License] Waiting for MT4 account connection before starting KTarget Finder MT7");
        return(INIT_SUCCEEDED);
    }

    // 非等待型授权失败，例如许可证文件、签名、产品、账户或有效期不匹配。
    // 返回 INIT_FAILED 后，MT4 不应把该实例视为已完成初始化。
    Print("[KT License] KTarget Finder MT7 authorization failed: ", KTLicenseGetMessage());
    return(INIT_FAILED);
}

//========================================================================
// 2. OnDeinit: 指标卸载时调用 (清理图表对象)
//========================================================================
void OnDeinit(const int reason)
{
    string reason_text = "UNKNOWN";
    switch (reason)
    {
        case REASON_CHARTCHANGE:  reason_text = "REASON_CHARTCHANGE"; break;
        case REASON_PARAMETERS:   reason_text = "REASON_PARAMETERS"; break;
        case REASON_RECOMPILE:    reason_text = "REASON_RECOMPILE"; break;
        case REASON_REMOVE:       reason_text = "REASON_REMOVE"; break;
        case REASON_ACCOUNT:      reason_text = "REASON_ACCOUNT"; break;
        case REASON_TEMPLATE:     reason_text = "REASON_TEMPLATE"; break;
        case REASON_INITFAILED:   reason_text = "REASON_INITFAILED"; break;
        case REASON_CLOSE:        reason_text = "REASON_CLOSE"; break;
    }

        Print("---->[KTarget_Finder_MT7.mq4:OnDeinit]: reason=", reason, " (", reason_text, ")",
            " Is_EA_Mode=", (Is_EA_Mode ? "true" : "false"),
            " ChartID=", (long)ChartID(),
            " Symbol=", _Symbol,
            " Period=", _Period,
            " InstanceSource=", KTarget_InstanceSource());

    if (!Is_EA_Mode)
    {
        // 停止定时器，避免内存泄漏
        EventKillTimer();

        // 清除图表上的 Comment 输出 (仅在调试模式开启时)
        if (Show_Debug_Comment)
        {
            Comment("");
        }
    }
    // EA模式实例由 iCustom() 创建，不拥有图表可视对象；禁止它清理非EA实例创建的对象。
    if (!Is_EA_Mode)
    {
        DeInit_DelObject();
        // 删除参数
        ObjectDelete(0, "KTarget_Param_Store");
        ObjectDelete(0, "KTarget_Param_Store_Bot8");
        // 清理图表上的对象
        DeleteProfit_CalcObjects();
        // [新增] 清理交易纪律提醒显示
        DeleteTradingRulesDisplay();
        // [新增] 清理配置信息显示板
        DeleteConfigInfoDisplay();
        // [新增] 清理严格模式快捷切换按钮
        DeleteStrictModeButtons();
    }
}

//========================================================================
// 3. OnCalculate: 主计算函数 (无变化)
//========================================================================
int OnCalculate(const int rates_total, 
                const int prev_calculated, 
                const datetime &time[], 
                const double& open[], 
                const double& high[], 
                const double& low[], 
                const double& close[], 
                const long& tick_volume[],
                const long& volume[],    
                const int& spread[])     
{
    KT_FinderSyncPriceSeries(rates_total, time, open, high, low, close);

    // 计算门禁：授权未完成时，指标可能仍然收到 OnCalculate()，但必须立即返回，
    // 防止未授权实例读取行情、执行扫描或创建绘图对象。
    // 因此排查“没有绘图”时，要区分：
    // - 没有进入 OnCalculate()；
    // - 进入 OnCalculate() 后因本状态为 false 而返回。
    if (!g_ktFinderMt7Authorized)
        return(0);

    // ----------------- NEW 切换到真实环境 可以区分Tick触发类型的执行-----------------

    // --- 逻辑判断与计数 ---
    string trigger_type = "UNKNOWN";
    datetime current_time = TimeCurrent();
    on_calculate_count++;
    
    // 1. 判断是否是历史数据加载
    if (prev_calculated == 0 || is_initial_load)
    {
        //先清零统计数据
        g_Stats.Reset();

        trigger_type = "History Load/Initial Run";
        is_initial_load = false;

        // 清除缓冲区中的所有旧标记
        ArrayInitialize(BullishTargetBuffer, EMPTY_VALUE);
        ArrayInitialize(BearishTargetBuffer, EMPTY_VALUE);
        ArrayInitialize(BullishSignalBuffer, EMPTY_VALUE);
        ArrayInitialize(BearishSignalBuffer, EMPTY_VALUE);

        // 寻找并绘制所有符合条件的 K-Target 及突破信号
        ExecuteFindAndDraw(rates_total);

        if (!Is_EA_Mode)
        {
            // 自动回收已失效的信号矩形/标注/辅助线。
            // 触发时机：历史全量重算完成后。
            // 原理：扫描当前图表上的 Rect_B_/Rect_S_ 对象，复用 CheckSignalStatus()
            // 判断它们是否已经被后续价格结构推翻；若失效，则删除对应的矩形、文字和
            // 同锚点的 P1/P2 辅助线，避免“信号已死但图形还活着”的图表残留。
            // CleanupInvalidSignalDrawings();

            // 新版结构替换清理：后续窗口内出现更低/更高 Close 的有效新锚点时，
            // 才删除旧信号整组对象。保留旧逻辑注释，便于直接对比两套策略。
            // CleanupReplacedSignalDrawings_ByLookbackWindow();

            Print("=================================================");
            Print(">>> KTarget 历史信号全量统计完成【prev_calculated】 <<<");
            Print(g_Stats.ToString());
            Print("=================================================");
        }
    }
    // 2. 判断是否是新 K 线触发
    else if (time[0] > last_bar_time)
    {
        g_Stats.Reset();

        trigger_type = "NEW BAR (收线触发)";
        if (!Is_EA_Mode)
        {
            Print("--->[234]: trigger_type: ", trigger_type);
        }

        // 清除缓冲区中的所有旧标记
        ArrayInitialize(BullishTargetBuffer, EMPTY_VALUE);
        ArrayInitialize(BearishTargetBuffer, EMPTY_VALUE);
        ArrayInitialize(BullishSignalBuffer, EMPTY_VALUE);
        ArrayInitialize(BearishSignalBuffer, EMPTY_VALUE);

        // 寻找并绘制所有符合条件的 K-Target 及突破信号
        ExecuteFindAndDraw(rates_total);

        if (!Is_EA_Mode)
        {
            // 自动回收已失效的信号矩形/标注/辅助线。
            // 触发时机：新 K 线收盘后、全图重新扫描完成后。
            // 说明：这里不改动信号判定逻辑，只把“失效后未被重画”的旧对象清掉。
            // CleanupInvalidSignalDrawings();

            // 新版结构替换清理：如果后续 Lookback 窗口里已经出现更低/更高 Close 的
            // 新锚点，则清理旧信号整组对象；否则保留。
            // CleanupReplacedSignalDrawings_ByLookbackWindow();

            // Print("=================================================");
            // Print(">>> KTarget 历史信号全量统计完成【NEW BAR (收线触发)】 <<<");
            // Print(g_Stats.ToString());
            // Print("=================================================");
        }
    }
    // 3. 判断是否是 Tick 触发
    else if (current_time > last_tick_time && rates_total == prev_calculated)
    {
        trigger_type = "TICK Update (Tick触发)";
    }
    else
    {
        trigger_type = "Tick Update (Same Time)";
    }

    // 在更新 last_bar_time 之前捕获"是否新K线"状态
    bool is_new_bar = (time[0] > last_bar_time);

    // 4. 更新全局静态变量
    last_bar_time = time[0];
    last_tick_time = current_time;

    if (!Is_EA_Mode)
    {
        // 5. 构建 OnCalculate 的输出段，并存储到全局变量
        on_calc_output_segment =
            "*** OnCalculate Status ***\n" +
            "Count: " + IntegerToString(on_calculate_count) + "\n" +
            "Trigger: " + trigger_type + "\n" +
            "Trigger Time: " + TimeToString(current_time, TIME_SECONDS) + "\n" +
            "--------------------------------------\n" +
            "K[0] Start Time: " + TimeToString(time[0], TIME_MINUTES) + "\n" +
            "Current Bid: " + DoubleToString(Bid, Digits) + "\n" +
            "Current Ask: " + DoubleToString(Ask, Digits) + "\n" +
            "K-Line Total: " + IntegerToString(rates_total) + "\n" +
            "Last Calculated: " + IntegerToString(prev_calculated) + "\n";

        // 6. 将 OnCalculate 的结果和 OnTimer 的结果合并显示 (仅在调试模式开启时)
        if (Show_Debug_Comment)
        {
            Comment(on_calc_output_segment + "\n" + on_timer_output_segment);
        }
    }

    // ---------------------------------------------------------
    // [新增] 绘制市场时段模块
    // ---------------------------------------------------------
    if (Period() <= PERIOD_H1)
    {
        // 仅在历史加载或新K线时绘制，避免每个Tick都重绘，节省资源
        if (Show_Sessions && (prev_calculated == 0 || is_new_bar))
        {
            DrawMarketSessions(Session_Lookback, Server_Time_Offset);
        }
    }

    // ATR 显示模块重构：快慢分离，分别调用
    AtrDisplaySnapshot atr_snapshot;
    if (CollectAtrDisplaySnapshot(atr_snapshot))
    {
        // 快速模块：不节流（每个 tick 更新）
        UpdateAtrCurrentPriceBigLabel_Fast(atr_snapshot);
        UpdateAtrPriceChangeLabel_Fast(atr_snapshot);

        // 慢速模块：函数内部独立节流
        UpdateAtrDashboardLines_Throttled(atr_snapshot);
        UpdateAtrSlArrows_Throttled(atr_snapshot);
    }

    return(rates_total);

    // ----------------- END 切换到真实环境 可以区分Tick触发类型的执行-----------------
}

//+------------------------------------------------------------------+
//| 4. 定时器函数 (OnTimer)
//+------------------------------------------------------------------+
void OnTimer()
{
    // 延迟授权补偿流程：当 OnInit() 因账户尚未连接而进入等待状态时，
    // MT4 通过定时器再次调用授权核心。授权成功后设置本实例状态为 true，
    // 停止 1 秒重试定时器，并执行授权后的初始化流程。
    // 注意：完成授权本身不等于已经执行 OnCalculate()；历史扫描仍由计算事件负责。
    if (!g_ktFinderMt7Authorized)
    {
        if (KTargetFinderMt7LicenseInitialize())
        {
            g_ktFinderMt7Authorized = true;
            EventKillTimer();
            KTarget_Finder_MT7_InitializeAfterLicense();
            Print("[KT License] KTarget Finder MT7 authorization completed after account connection");
        }
        else if (!KTLicenseIsWaitingForAccount())
        {
            EventKillTimer();
            Print("[KT License] KTarget Finder MT7 authorization failed: ", KTLicenseGetMessage());
        }
        return;
    }

    if (!Is_EA_Mode)
    {
        // OnTimer 独立运行，不依赖Tick或K线收盘
        string timer_output =
            "**OnTimer Status**\n" +
            "Function: OnTimer() executed.\n" +
            "Time: " + TimeToString(TimeCurrent(), TIME_SECONDS) + "\n" +
            "Current Bid: " + DoubleToString(Bid, Digits) + "\n" +
            "Note: OnTimer runs independently of OnCalculate.";

        // 1. 更新 OnTimer 的输出段，并存储到全局变量
        on_timer_output_segment = timer_output;

        // 2. 将 OnCalculate 的最新结果和 OnTimer 的结果合并显示 (仅在调试模式开启时)
        // 即使 OnCalculate 触发频繁，我们总是用最新的两段信息进行组合
        if (Show_Debug_Comment)
        {
            Comment(on_calc_output_segment + "\n" + on_timer_output_segment);
        }
    }
}

//+------------------------------------------------------------------+
//| ChartEvent function - 接收所有图表/对象事件的关键函数
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // 图表事件门禁：鼠标、键盘、对象删除和图表事件只有在当前实例授权后才处理。
    // 该门禁只影响 OnChartEvent()，不负责触发报价计算，也不会替代 OnCalculate()。
    if (!g_ktFinderMt7Authorized)
        return;

    // 🚨 核心修正：在 EA 模式下，立即退出函数，不做任何处理 🚨
    if (Is_EA_Mode)
    {
        return; 
    }
    
    // 1. 打印所有事件的通用信息
    // Print("--- EVENT RECEIVED --- ID:", id, 
    //       ", lparam:", lparam, 
    //       ", dparam:", dparam, 
    //       ", sparam (Name/Key):", sparam);

    // --- 2. 针对特定事件进行处理和深入解析 ---
    switch(id)
    {
        case CHARTEVENT_OBJECT_CLICK:
        {
            HandleObjectClick(sparam);
            break;
        }

        case CHARTEVENT_KEYDOWN:
        {
            // 用户按下了键盘上的键
            // Print("    侦测到键盘按下事件 (CHARTEVENT_KEYDOWN)");
            // Print("    按下的键代码 (lparam): ", lparam);
            break;
        }
            
        case CHARTEVENT_CHART_CHANGE:
        {
            // 图表变动：例如窗口大小改变、缩放、切换周期
            // Print("    图表变动事件 (CHARTEVENT_CHART_CHANGE) 发生。");
            break;
        }

        case CHARTEVENT_OBJECT_DELETE:
        {
            HandleObjectDelete(sparam);
            break;
        }

        case CHARTEVENT_MOUSE_MOVE:
        {
            HandleProfit_Calc(sparam, dparam, lparam);
            break;
        }

        default:
            // 其他事件，例如 CHARTEVENT_MOUSE_MOVE (需要显式开启)
            // Print("    接收到其他事件...");
            break;
    }
}

//========================================================================
// ExecuteFindAndDraw: 统一调度函数 - 根据开关选择标准或老实人模式
//========================================================================
void ExecuteFindAndDraw(int total_bars)
{
    if (Enable_Honest_Filter)
        FindAndDrawTargetCandles_The_Honest(total_bars);
    else
        FindAndDrawTargetCandles(total_bars);
}

//#region MARK: 核心函数流程
//========================================================================
// FindAndDrawTargetCandles: 寻找 K-Target 的核心逻辑 (双向) (无变化)
//========================================================================
void FindAndDrawTargetCandles(int total_bars)
{
    // 确定实际循环上限
    int max_bars_to_scan = MathMin(total_bars, Scan_Range);

    // 循环从第一根已收盘 K 线 (i=1) 开始
    for (int i = 1; i < max_bars_to_scan; i++)
    {
        // 1. 检查 K-Target Bottom (看涨) 锚定条件
        if (IsKTargetBottom(i, total_bars))
        {
            // 1.0
            DrawTargetBottom(i); 
            // 检查信号确认逻辑 (IB/DB 突破)
            //CheckBullishSignalConfirmation(i);

            // --- V1.31 NEW: 流程协调 (看涨) ---

            // 查找 P2 索引和价格
            int P2_index = FindP2Index_Wrapper(i, true);
            if (P2_index == -1) continue; // P2 查找失败，跳过该锚点
            double P2_price = Close[P2_index];

            // --- V2.0 NEW: 查找并绘制 P3/P4/P5 价格线（简化版：只绘制，不检测） ---
            FindAndDrawMultiplePLevels(i, P2_index, P2_price, true);
            // --- END V2.0 NEW ---

            // 查找 P1 突破索引 K_Geo_Index (第一次 P1 突破点)
            int K_Geo_Index = FindFirstP1BreakoutIndex(i, true);
            if (K_Geo_Index == -1) continue; // P1 突破失败，跳过该锚点
            // 如果返回 0，说明是当前K线正在破，还没收盘，为了不重绘，暂时忽略
            if (K_Geo_Index == 0) continue;

            // 计算突破距离 N_Geo
            int N_Geo = i - K_Geo_Index;

            // 绘制 P1 辅助线 (几何绘制职责)
            DrawP1Baseline(i, K_Geo_Index, true, P2_price);
            // --- END V1.31 NEW ---

            // --- V1.35 NEW: 绝对低点支撑线 ---
            int AbsLowIndex = FindAbsoluteLowIndex(i, Look_LLHH_Candles, Look_LLHH_Candles, true);
            //Print("====>[KTarget_Finder4_FromGemini.mq4:298]: AbsLowIndex: ", AbsLowIndex);

            // double lowprice = Low[AbsLowIndex];
            //Print("====>[KTarget_Finder4_FromGemini.mq4:301]: lowprice: ", lowprice);
            
            if (AbsLowIndex != -1)
            {
                // 绘制绝对低点支撑线，向右延伸 15 根 K 线
                DrawAbsoluteSupportLine(AbsLowIndex, true, 15);
            }
            // --- END V1.35 NEW ---

            // 调用信号标记器 (仅传入数据)
            CheckBullishSignalConfirmation(i, P2_index, K_Geo_Index, N_Geo, AbsLowIndex);
        }
        
        // 2. 检查 K-Target Top (看跌) 锚定条件
        if (IsKTargetTop(i, total_bars))
        {
            // 1.0
            DrawTargetTop(i); 
            // 检查信号确认逻辑
            //CheckBearishSignalConfirmation(i);

            // --- V1.31 NEW: 流程协调 (看跌) ---

            // 查找 P2 索引和价格
            int P2_index = FindP2Index_Wrapper(i, false);
            if (P2_index == -1) continue; // P2 查找失败，跳过该锚点
            double P2_price = Close[P2_index];

            // --- V2.0 NEW: 查找并绘制 P3/P4/P5 价格线（简化版：只绘制，不检测） ---
            FindAndDrawMultiplePLevels(i, P2_index, P2_price, false);
            // --- END V2.0 NEW ---

            // 查找 P1 突破索引 K_Geo_Index (第一次 P1 突破点)
            int K_Geo_Index = FindFirstP1BreakoutIndex(i, false);
            if (K_Geo_Index == -1) continue; // P1 突破失败，跳过该锚点
            if (K_Geo_Index == 0) continue;

            // 计算突破距离 N_Geo
            int N_Geo = i - K_Geo_Index;

            // 绘制 P1 辅助线 (几何绘制职责)
            DrawP1Baseline(i, K_Geo_Index, false, P2_price);
            // --- END V1.31 NEW ---

            // --- V1.35 NEW: 绝对高点阻力线 ---
            int AbsHighIndex = FindAbsoluteLowIndex(i, Look_LLHH_Candles, Look_LLHH_Candles, false); // 查找绝对最高点
            if (AbsHighIndex != -1)
            {
                // 绘制绝对高点阻力线，向右延伸 15 根 K 线
                DrawAbsoluteSupportLine(AbsHighIndex, false, 15);
            }
            // --- END V1.35 NEW ---

            // 调用信号标记器 (仅传入数据)
            CheckBearishSignalConfirmation(i, P2_index, K_Geo_Index, N_Geo, AbsHighIndex);
        }
    }
}

//========================================================================
// FindAndDrawTargetCandles: 寻找 K-Target 的核心逻辑 (双向) (老实人过滤机制 (The Honest Filter))
// 设计的机制是可以查看历史行情使用；同时可以判断当前价格处在什么位置
//========================================================================
void FindAndDrawTargetCandles_The_Honest(int total_bars)
{
    // 确定实际循环上限
    int max_bars_to_scan = MathMin(total_bars, Scan_Range);
    // int LookAhead_Confirm_Bars = 20; // 老实人模式：必须等右边走出20根确认
    int LookAhead_Confirm_Bars = MathMax(Lookahead_Bottom, Lookahead_Top);

    // 循环从第一根已收盘 K 线 (i=1) 开始
    for (int i = 1; i < max_bars_to_scan; i++)
    {
        // -------------------------------------------------------------
        // 【新增逻辑】老实人过滤机制 (The Honest Filter)
        // -------------------------------------------------------------
        
        // 1. 如果当前的 i 小于我们需要的确认根数，说明“还没走完20根”，直接跳过
        // 这就是“滞后”的体现：最新的 20 根 K 线内，绝不画信号
        if (i < LookAhead_Confirm_Bars) 
            continue; 

        // 2. 强制检查右侧 (未来) 的 20 根 K 线
        bool is_strict_lowest = true;
        bool is_strict_highest = true;

        for (int k = 1; k <= LookAhead_Confirm_Bars; k++)
        {
            // 向右看 (索引减小)：i-k
            // 如果右边任何一根收盘价/最低价 比 i 还低，说明 i 根本不是底部
            if (Low[i-k] <= Low[i]) 
            {
                is_strict_lowest = false;
            }
            // 如果右边任何一根收盘价/最高价 比 i 还高，说明 i 根本不是顶部
            if (High[i-k] >= High[i])
            {
                is_strict_highest = false;
            }
        }
        // -------------------------------------------------------------

        // 1. 检查 K-Target Bottom (看涨) 锚定条件
        if (is_strict_lowest && IsKTargetBottom(i, total_bars))
        {
            // 1.0
            DrawTargetBottom(i); 
            // 检查信号确认逻辑 (IB/DB 突破)
            //CheckBullishSignalConfirmation(i);

            // --- V1.31 NEW: 流程协调 (看涨) ---

            // 查找 P2 索引和价格
            int P2_index = FindP2Index_Wrapper(i, true);
            if (P2_index == -1) continue; // P2 查找失败，跳过该锚点
            double P2_price = Close[P2_index];

            // --- V2.0 NEW: 查找并绘制 P3/P4/P5 价格线（简化版：只绘制，不检测） ---
            FindAndDrawMultiplePLevels(i, P2_index, P2_price, true);
            // --- END V2.0 NEW ---

            // 查找 P1 突破索引 K_Geo_Index (第一次 P1 突破点)
            int K_Geo_Index = FindFirstP1BreakoutIndex(i, true);
            if (K_Geo_Index == -1) continue; // P1 突破失败，跳过该锚点
            // 如果返回 0，说明是当前K线正在破，还没收盘，为了不重绘，暂时忽略
            if (K_Geo_Index == 0) continue;

            // 计算突破距离 N_Geo
            int N_Geo = i - K_Geo_Index;

            // 绘制 P1 辅助线 (几何绘制职责)
            DrawP1Baseline(i, K_Geo_Index, true, P2_price);
            // --- END V1.31 NEW ---

            // --- V1.35 NEW: 绝对低点支撑线 ---
            int AbsLowIndex = FindAbsoluteLowIndex(i, Look_LLHH_Candles, Look_LLHH_Candles, true);
            //Print("====>[KTarget_Finder4_FromGemini.mq4:298]: AbsLowIndex: ", AbsLowIndex);

            // double lowprice = Low[AbsLowIndex];
            //Print("====>[KTarget_Finder4_FromGemini.mq4:301]: lowprice: ", lowprice);
            
            if (AbsLowIndex != -1)
            {
                // 绘制绝对低点支撑线，向右延伸 15 根 K 线
                DrawAbsoluteSupportLine(AbsLowIndex, true, 15);
            }
            // --- END V1.35 NEW ---

            // 调用信号标记器 (仅传入数据)
            CheckBullishSignalConfirmation(i, P2_index, K_Geo_Index, N_Geo, AbsLowIndex);
        }
        
        // 2. 检查 K-Target Top (看跌) 锚定条件
        if (is_strict_highest && IsKTargetTop(i, total_bars))
        {
            // 1.0
            DrawTargetTop(i); 
            // 检查信号确认逻辑
            //CheckBearishSignalConfirmation(i);

            // --- V1.31 NEW: 流程协调 (看跌) ---

            // 查找 P2 索引和价格
            int P2_index = FindP2Index_Wrapper(i, false);
            if (P2_index == -1) continue; // P2 查找失败，跳过该锚点
            double P2_price = Close[P2_index];

            // --- V2.0 NEW: 查找并绘制 P3/P4/P5 价格线（简化版：只绘制，不检测） ---
            FindAndDrawMultiplePLevels(i, P2_index, P2_price, false);
            // --- END V2.0 NEW ---

            // 查找 P1 突破索引 K_Geo_Index (第一次 P1 突破点)
            int K_Geo_Index = FindFirstP1BreakoutIndex(i, false);
            if (K_Geo_Index == -1) continue; // P1 突破失败，跳过该锚点
            if (K_Geo_Index == 0) continue;

            // 计算突破距离 N_Geo
            int N_Geo = i - K_Geo_Index;

            // 绘制 P1 辅助线 (几何绘制职责)
            DrawP1Baseline(i, K_Geo_Index, false, P2_price);
            // --- END V1.31 NEW ---

            // --- V1.35 NEW: 绝对高点阻力线 ---
            int AbsHighIndex = FindAbsoluteLowIndex(i, Look_LLHH_Candles, Look_LLHH_Candles, false); // 查找绝对最高点
            if (AbsHighIndex != -1)
            {
                // 绘制绝对高点阻力线，向右延伸 15 根 K 线
                DrawAbsoluteSupportLine(AbsHighIndex, false, 15);
            }
            // --- END V1.35 NEW ---

            // 调用信号标记器 (仅传入数据)
            CheckBearishSignalConfirmation(i, P2_index, K_Geo_Index, N_Geo, AbsHighIndex);
        }
    }
}
//#endregion