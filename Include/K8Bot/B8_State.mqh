//====================================================================
// 文件作用：KTarget_FinderBot8 的全局运行状态变量。
// 本文件只保存跨函数共享的状态，不包含状态处理逻辑。
//====================================================================

ENUM_B8_TRADE_MODE g_Trade_Mode    = B8_MODE_NORMAL; // 当前交易模式
bool               g_EA_Enabled    = false;           // EA 交易开关
ENUM_B8_ENTRY_MODE g_Runtime_Entry_Mode = B8_ENTRY_MARKET; // 当前运行中的入场方式
datetime           g_last_bar_time = 0;               // 新 K 线检测时间戳
bool               g_manual_recheck_pending = false; // 手动开启后的 K[1] 补检请求（仅消费一次）
datetime           g_manual_recheck_bar_time = 0;    // 最近一次手动补检对应的 K[0] 时间
string             g_object_prefix = "";              // 对象名唯一前缀 (含 ChartID)
bool               g_EquityProtect_Triggered = false; // 本轮持仓是否已触发浮盈保护
datetime           g_EquityProtect_TriggerTime = 0;   // 最近一次触发时间
string             g_state_key_enabled = "";         // 持久化键: EA开关
string             g_state_key_mode    = "";         // 持久化键: 交易模式
bool               g_SettingsPanelVisible = true;    // 参数面板显示状态（主控面板始终保留入口）
B8_RUNTIME_SETTINGS g_Startup_Settings;               // 本次加载时的 input 默认值
B8_RUNTIME_SETTINGS g_Edit_Settings;                  // 面板中尚未应用的编辑值
B8_RUNTIME_SETTINGS g_Runtime_Settings;               // 交易逻辑实际使用的当前值
B8_ORDER_RUNTIME_SETTINGS g_Order_Startup_Settings;   // 订单级 input 默认值
B8_ORDER_RUNTIME_SETTINGS g_Order_Edit_Settings;      // 订单级面板尚未应用的编辑值
B8_ORDER_RUNTIME_SETTINGS g_Order_Runtime_Settings;   // 订单级交易逻辑实际使用的当前值
bool                g_Pending_Fib_Selected[8];        // Fib挂单运行时选择状态
bool                g_History_Select_Mode = false;    // 是否等待用户点击历史K线
bool                g_History_Panels_Hidden = false; // 历史K线选择期间是否隐藏核心面板
int                 g_History_Selected_Shift = 15;    // 当前历史K线shift
uint                g_History_Last_Button_Click = 0; // 防止按钮点击穿透到图表
KBarSignal          g_History_Preview_Signal;         // 历史信号预览数据
bool                g_History_Preview_Valid = false;  // 历史信号预览是否有效
string              g_History_Status_Message = "待选择历史K线";
bool                g_Settings_Dirty = false;         // 编辑值是否尚未应用
string              g_Settings_Message = "参数已同步"; // 参数面板状态提示
bool                g_Order_Settings_Dirty = false;   // 订单编辑值是否尚未应用
string              g_Order_Settings_Message = "订单参数已同步"; // 订单面板状态提示

//#region MARK: 模块--自定义价格补挂运行时状态
double                      g_Custom_Fib_Entry_Price = 0.0;
double                      g_Custom_Fib_Stop_Price = 0.0;
ENUM_B8_CUSTOM_PENDING_TYPE g_Custom_Fib_Order_Type = B8_CUSTOM_PENDING_AUTO;
bool                        g_Custom_Fib_Risk_Shared = true;
string                      g_Custom_Fib_Status_Message = "等待输入自定义价格";
ENUM_B8_PRICE_PICK_MODE     g_Custom_Fib_Pick_Mode = B8_PRICE_PICK_NONE;
double                      g_Custom_Fib_Pick_Preview_Price = 0.0;
uint                        g_Custom_Fib_Last_Button_Click = 0;
bool                        g_Custom_Fib_Panels_Hidden = false;
//#endregion

int                 g_Partial_Close_Blocked_Magics[128]; // 因手数规则无法部分平仓的逻辑订单
int                 g_Partial_Close_Blocked_Count = 0; // 无法部分平仓的逻辑订单数量
B8_ORDER_PROTECTION_STATE g_Order_Protection_States[B8_ORDER_PROTECTION_STATE_MAX]; // 普通订单级保护的运行时状态
int                 g_Order_Protection_State_Count = 0; // 普通订单级保护状态数量
B8_RUNTIME_TAKEOVER_STATE g_Runtime_Takeover_States[B8_RUNTIME_TAKEOVER_STATE_MAX]; // 全部接管的运行期状态
int                 g_Runtime_Takeover_State_Count = 0; // 当前接管状态数量
B8_RUNTIME_ORDER_OVERRIDE g_Runtime_Order_Overrides[B8_RUNTIME_ORDER_MAX]; // 运行时订单策略覆盖记录
int                 g_Runtime_Order_Override_Count = 0; // 当前有效的运行时订单策略数量
int                 g_Runtime_Order_Selected_Ticket = -1; // 运行时订单面板当前选中的订单 Ticket
int                 g_Runtime_Order_Row_Tickets[10]; // 运行时订单面板各行对应的订单 Ticket
int                 g_Runtime_Order_Row_Count = 0; // 运行时订单面板当前显示的订单行数
ENUM_B8_ORDER_TRIGGER_MODE g_Runtime_Order_Edit_Mode = B8_ORDER_TRIGGER_R; // 运行时订单面板正在编辑的触发模式
ENUM_B8_ORDER_PROTECTION_MODE g_Runtime_Order_Edit_Action = B8_ORDER_PARTIAL_BE; // 运行时订单面板正在编辑的保护动作
bool                g_Runtime_Order_Inputs_Editing = false; // 是否正在编辑运行时订单参数
bool                g_Runtime_Order_Panel_Collapsed = true; // 运行时订单策略面板是否折叠

//#region MARK: 模块--运行时订单策略多选应用状态
ENUM_B8_RUNTIME_APPLY_SCOPE g_Runtime_Order_Apply_Scope = B8_RUNTIME_APPLY_CURRENT;
int                 g_Runtime_Order_Selected_Tickets[B8_RUNTIME_ORDER_MAX];
int                 g_Runtime_Order_Selected_Ticket_Count = 0;
//#endregion

B8_FIB_ORDER_TEMPLATE g_Fib_Order_Templates[8]; // 8 个 Fib 位置对应的成交前策略模板
int                 g_Fib_Template_Selected = 0; // Fib 模板面板当前选中的模板索引
ENUM_B8_ORDER_TRIGGER_MODE g_Fib_Template_Edit_Mode = B8_ORDER_TRIGGER_R; // Fib 模板面板正在编辑的触发模式
ENUM_B8_ORDER_PROTECTION_MODE g_Fib_Template_Edit_Action = B8_ORDER_PARTIAL_BE; // Fib 模板面板正在编辑的保护动作
bool                g_Fib_Template_Inputs_Editing = false; // 是否正在编辑 Fib 模板参数
bool                g_Fib_Template_Panel_Collapsed = true; // Fib成交前模板面板是否折叠

//====================================================================
// 是否开启Runtime/Fibo策略模板
//====================================================================
// 扩展订单策略内部开关：false 时完全保持订单级管理，Runtime/Fibo 不参与接管。
// 该变量不是 input 参数，只由代码控制，避免扩展逻辑改变订单级管理的基础行为。
bool g_Advanced_Order_Strategy_Enabled = true;

// 手动平仓模块的作用范围：当前选中订单，或当前品种+Bot8 Magic管理订单。
bool g_Runtime_Close_All_Managed = false;
