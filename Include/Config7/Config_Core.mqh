//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ 所有的指标打印日志行为 只能在!Is_EA_Mode 模式下运行
//+------------------------------------------------------------------+
/*
extern bool Is_EA_Mode = false; // 是否以EA后台模式运行 (关闭所有绘图和对象创建) true：EA静默模式；false：绘图模式
extern bool Smart_Tuning_Enabled = true;        // 【新增】启动智能周期调优

// --- 外部可调参数 (输入) ---
extern int Scan_Range = 500;              // 总扫描范围：向后查找 N 根 K 线

// --- 看涨 K-Target (底部) 锚点参数 ---
extern int Lookahead_Bottom = 20;         // 看涨信号右侧检查周期 (未来/较新的K线)
extern int Lookback_Bottom = 20;          // 看涨信号左侧检查周期 (历史/较旧的K线)

// --- 看跌 K-Target (顶部) 锚点参数 ---
extern int Lookahead_Top = 20;            // 看跌信号右侧检查周期
extern int Lookback_Top = 20;             // 看跌信号左侧检查周期

// --- 信号确认参数 ---
extern int Max_Signal_Lookforward = 20;    // 最大信号确认前瞻 K 线数量 (P1 突破检查范围)
extern int DB_Threshold_Candles = 3;       // DB 突破的最小 K 线数量 (N >= 3 为 DB, N < 3 为 IB)
extern int Look_LLHH_Candles = 3;          // 寻找绝对最低和最高价的K线范围查找数量(FindAbsoluteLowIndex)

extern int Find_Target_Model = 1;          // 锚点查找方式 1 是默认查找；2 是更加严格的查找。 严格查找限定看涨必须是阴线， 看跌必须是阳线才能作为锚点
*/

//+------------------------------------------------------------------+
//| ✅ All indicator logging behaviors only run in !Is_EA_Mode
//+------------------------------------------------------------------+
input bool Is_EA_Mode = false;            // EA Silent Mode (True=No GFX)
input bool Smart_Tuning_Enabled = false;  // Enable Smart Tuning

// --- External Adjustable Parameters (Inputs) ---
input int Inp_Scan_Range = 500;           // History Scan Range

// --- Bullish K-Target (Bottom) Anchor Parameters ---
input int Inp_Lookahead_Bottom = 20;      // Bull: Right Check
input int Inp_Lookback_Bottom = 20;       // Bull: Left Check

// --- Bearish K-Target (Top) Anchor Parameters ---
input int Inp_Lookahead_Top = 20;         // Bear: Right Check
input int Inp_Lookback_Top = 20;          // Bear: Left Check

// --- Signal Confirmation Parameters ---
input int Inp_Max_Signal_Lookforward = 20; // Signal Confirm Range
input int DB_Threshold_Candles = 3;       // DB Min Bars (>=3)
input int Inp_Look_LLHH_Candles = 5;       // Abs. High/Low Scan
input bool Enable_IB_Signal_Marking = false; // Mark/Alert IB-only signals (no CB)

input string  __Anchor_Honest_Filter_Settings__   = "=== Anchor point and Honest Filter Settings ===";
input int Inp_Find_Target_Model = 1;         // Anchor point lookup method. Search Mode (1=Std, 2=Strict)
input bool Inp_Enable_Honest_Filter = false; // Enable Honest Filter Mode (Needs Right-side Confirm)

input bool Inp_Use_Enhanced_P2_Search = false; // P2 Search Algorithm (false=Standard, true=Enhanced)
// (false=Standard, true=Enhanced with Bar/Price Distance Constraints)

input int Enhanced_P2_Min_Bars_Between = 2;  // Min K-line Gap for Enhanced P2 (0=No Limit, 2=Filter Noise)

input bool Inp_Use_Strict_PLevel_Search = false; // P3/P4/P5 Search Mode (false=Standard, true=Strict)
// P3/P4/P5 Search Mode (false=Standard, true=Strict Body Separation)

input int Inp_Strict_PLevel_Min_Bars_Between = 0; // Min K-line Gap for Strict P-Level (0=No Limit, 2=Filter Noise)
input string  __Anchor_Honest_Filter_Settings__End__   = "=== Anchor point and Honest Filter Settings End ===";

//#region MARK: 模块--输入参数运行时变量集中管理
int Scan_Range = Inp_Scan_Range;
int Lookahead_Bottom = Inp_Lookahead_Bottom;
int Lookback_Bottom = Inp_Lookback_Bottom;
int Lookahead_Top = Inp_Lookahead_Top;
int Lookback_Top = Inp_Lookback_Top;
int Max_Signal_Lookforward = Inp_Max_Signal_Lookforward;
int Look_LLHH_Candles = Inp_Look_LLHH_Candles;
int Find_Target_Model = Inp_Find_Target_Model;
bool Enable_Honest_Filter = Inp_Enable_Honest_Filter;
bool Use_Enhanced_P2_Search = Inp_Use_Enhanced_P2_Search;
bool Use_Strict_PLevel_Search = Inp_Use_Strict_PLevel_Search;
int Strict_PLevel_Min_Bars_Between = Inp_Strict_PLevel_Min_Bars_Between;
//#endregion

// 严格模式快捷按钮的运行状态枚举：标准、严格、严格+Honest。
enum StrictQuickMode
{
	STRICT_QUICK_STANDARD = 0,       // 标准模式：使用参数面板中的默认查找设置。
	STRICT_QUICK_STRICT = 1,         // 严格模式：启用严格锚点、增强P2查找、严格P等级间隔。
	STRICT_QUICK_STRICT_HONEST = 2   // 严格+Honest模式：在严格模式基础上启用Honest过滤。
};

// 当前快捷按钮模式，初始化为标准模式。
StrictQuickMode Current_Strict_Quick_Mode = STRICT_QUICK_STANDARD;

// 快捷按钮关闭时用于恢复的默认参数值。
const int DEFAULT_Find_Target_Model = 1;                         // 默认锚点查找模式：标准模式。
const bool DEFAULT_Enable_Honest_Filter = false;                 // 默认不启用Honest过滤。
const bool DEFAULT_Use_Enhanced_P2_Search = false;               // 默认使用标准P2查找算法。
const bool DEFAULT_Use_Strict_PLevel_Search = false;             // 默认不启用P3/P4/P5严格查找。
const int DEFAULT_Strict_PLevel_Min_Bars_Between = 0;            // 默认不限制P等级之间的最小K线间隔。