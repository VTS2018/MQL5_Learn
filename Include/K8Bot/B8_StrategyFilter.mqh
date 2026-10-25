//====================================================================
// Bot8 人工策略位置过滤层
// 作用：让用户手工输入多个价格策略，过滤当前周期的 MT7 信号。
// 不读取 H1，不计算 Fib；Bot8 只使用当前图表周期的信号和价格。
//====================================================================

enum ENUM_B8_STRATEGY_DIRECTION
{
    B8_STRATEGY_BUY = 0,
    B8_STRATEGY_SELL = 1
};

enum ENUM_B8_STRATEGY_TRIGGER_MODE
{
    B8_STRATEGY_ZONE = 0,       // 信号确认价必须位于区间内
    B8_STRATEGY_TOUCH_ARM = 1   // 价格触发后，进入捕获状态
};

enum ENUM_B8_STRATEGY_MATCH_POLICY
{
    B8_STRATEGY_MATCH_FIRST = 0,     // 按策略编号选择第一条
    B8_STRATEGY_MATCH_PRIORITY = 1,  // 选择优先级数字最小的一条
    B8_STRATEGY_MATCH_ALL = 2,       // 所有匹配策略各执行一次
    B8_STRATEGY_MATCH_SKIP = 3       // 多条匹配时全部跳过
};

input string __B8_STRATEGY_FILTER__ = "--- Bot8 人工位置策略过滤 ---";
input bool B8_Strategy_Filter_Enabled = false;
input ENUM_B8_STRATEGY_MATCH_POLICY B8_Strategy_Match_Policy = B8_STRATEGY_MATCH_PRIORITY;
input bool B8_Strategy_Require_M5 = true;
input bool B8_Strategy_Log_Decisions = true;

#define B8_STRATEGY_SLOT_COUNT 8

// MQL4 不支持用宏拼接 input 名称，因此保留固定策略槽位的显式参数。
input string B8_Strategy1_Label = "策略1";
input bool B8_Strategy1_Enabled = false;
input ENUM_B8_STRATEGY_DIRECTION B8_Strategy1_Direction = B8_STRATEGY_SELL;
input ENUM_B8_STRATEGY_TRIGGER_MODE B8_Strategy1_Trigger_Mode = B8_STRATEGY_ZONE;
input double B8_Strategy1_Zone_Lower = 0.0;
input double B8_Strategy1_Zone_Upper = 0.0;
input double B8_Strategy1_Trigger_Price = 0.0;
input bool B8_Strategy1_Require_In_Zone = false;
input int B8_Strategy1_Priority = 1;
input int B8_Strategy1_Max_Trades = 1;

input string B8_Strategy2_Label = "策略2";
input bool B8_Strategy2_Enabled = false;
input ENUM_B8_STRATEGY_DIRECTION B8_Strategy2_Direction = B8_STRATEGY_SELL;
input ENUM_B8_STRATEGY_TRIGGER_MODE B8_Strategy2_Trigger_Mode = B8_STRATEGY_ZONE;
input double B8_Strategy2_Zone_Lower = 0.0;
input double B8_Strategy2_Zone_Upper = 0.0;
input double B8_Strategy2_Trigger_Price = 0.0;
input bool B8_Strategy2_Require_In_Zone = false;
input int B8_Strategy2_Priority = 2;
input int B8_Strategy2_Max_Trades = 1;

input string B8_Strategy3_Label = "策略3";
input bool B8_Strategy3_Enabled = false;
input ENUM_B8_STRATEGY_DIRECTION B8_Strategy3_Direction = B8_STRATEGY_SELL;
input ENUM_B8_STRATEGY_TRIGGER_MODE B8_Strategy3_Trigger_Mode = B8_STRATEGY_ZONE;
input double B8_Strategy3_Zone_Lower = 0.0;
input double B8_Strategy3_Zone_Upper = 0.0;
input double B8_Strategy3_Trigger_Price = 0.0;
input bool B8_Strategy3_Require_In_Zone = false;
input int B8_Strategy3_Priority = 3;
input int B8_Strategy3_Max_Trades = 1;

input string B8_Strategy4_Label = "策略4";
input bool B8_Strategy4_Enabled = false;
input ENUM_B8_STRATEGY_DIRECTION B8_Strategy4_Direction = B8_STRATEGY_SELL;
input ENUM_B8_STRATEGY_TRIGGER_MODE B8_Strategy4_Trigger_Mode = B8_STRATEGY_ZONE;
input double B8_Strategy4_Zone_Lower = 0.0;
input double B8_Strategy4_Zone_Upper = 0.0;
input double B8_Strategy4_Trigger_Price = 0.0;
input bool B8_Strategy4_Require_In_Zone = false;
input int B8_Strategy4_Priority = 4;
input int B8_Strategy4_Max_Trades = 1;

input string B8_Strategy5_Label = "策略5";
input bool B8_Strategy5_Enabled = false;
input ENUM_B8_STRATEGY_DIRECTION B8_Strategy5_Direction = B8_STRATEGY_SELL;
input ENUM_B8_STRATEGY_TRIGGER_MODE B8_Strategy5_Trigger_Mode = B8_STRATEGY_ZONE;
input double B8_Strategy5_Zone_Lower = 0.0;
input double B8_Strategy5_Zone_Upper = 0.0;
input double B8_Strategy5_Trigger_Price = 0.0;
input bool B8_Strategy5_Require_In_Zone = false;
input int B8_Strategy5_Priority = 5;
input int B8_Strategy5_Max_Trades = 1;

input string B8_Strategy6_Label = "策略6";
input bool B8_Strategy6_Enabled = false;
input ENUM_B8_STRATEGY_DIRECTION B8_Strategy6_Direction = B8_STRATEGY_SELL;
input ENUM_B8_STRATEGY_TRIGGER_MODE B8_Strategy6_Trigger_Mode = B8_STRATEGY_ZONE;
input double B8_Strategy6_Zone_Lower = 0.0;
input double B8_Strategy6_Zone_Upper = 0.0;
input double B8_Strategy6_Trigger_Price = 0.0;
input bool B8_Strategy6_Require_In_Zone = false;
input int B8_Strategy6_Priority = 6;
input int B8_Strategy6_Max_Trades = 1;

input string B8_Strategy7_Label = "策略7";
input bool B8_Strategy7_Enabled = false;
input ENUM_B8_STRATEGY_DIRECTION B8_Strategy7_Direction = B8_STRATEGY_SELL;
input ENUM_B8_STRATEGY_TRIGGER_MODE B8_Strategy7_Trigger_Mode = B8_STRATEGY_ZONE;
input double B8_Strategy7_Zone_Lower = 0.0;
input double B8_Strategy7_Zone_Upper = 0.0;
input double B8_Strategy7_Trigger_Price = 0.0;
input bool B8_Strategy7_Require_In_Zone = false;
input int B8_Strategy7_Priority = 7;
input int B8_Strategy7_Max_Trades = 1;

input string B8_Strategy8_Label = "策略8";
input bool B8_Strategy8_Enabled = false;
input ENUM_B8_STRATEGY_DIRECTION B8_Strategy8_Direction = B8_STRATEGY_SELL;
input ENUM_B8_STRATEGY_TRIGGER_MODE B8_Strategy8_Trigger_Mode = B8_STRATEGY_ZONE;
input double B8_Strategy8_Zone_Lower = 0.0;
input double B8_Strategy8_Zone_Upper = 0.0;
input double B8_Strategy8_Trigger_Price = 0.0;
input bool B8_Strategy8_Require_In_Zone = false;
input int B8_Strategy8_Priority = 8;
input int B8_Strategy8_Max_Trades = 1;

struct B8_MANUAL_STRATEGY
{
    bool enabled;
    int direction;
    int trigger_mode;
    double zone_lower;
    double zone_upper;
    double trigger_price;
    bool require_in_zone;
    int priority;
    int max_trades;
};

bool g_B8_Strategy_Armed[B8_STRATEGY_SLOT_COUNT];
int g_B8_Strategy_Trade_Count[B8_STRATEGY_SLOT_COUNT];
int g_B8_Strategy_Selected[B8_STRATEGY_SLOT_COUNT];
int g_B8_Strategy_Selected_Count = 0;
bool g_B8_Strategy_Initialized = false;

// 构造指定策略槽位的持久化状态键，用于保存武装状态和交易次数。
string B8_Strategy_StateKey(int index, string suffix)
{
    return B8_BuildStateKey("strategy_" + IntegerToString(index + 1) + "_" + suffix);
}

// 将指定策略当前的触价武装状态和交易次数写入 MT4 全局变量。
void B8_Strategy_SaveState(int index)
{
    GlobalVariableSet(B8_Strategy_StateKey(index, "armed"),
                      g_B8_Strategy_Armed[index] ? 1.0 : 0.0);
    GlobalVariableSet(B8_Strategy_StateKey(index, "trades"),
                      (double)g_B8_Strategy_Trade_Count[index]);
}

// 从 MT4 全局变量恢复指定策略的触价武装状态和历史交易次数。
void B8_Strategy_LoadState(int index)
{
    string armed_key = B8_Strategy_StateKey(index, "armed");
    string trades_key = B8_Strategy_StateKey(index, "trades");

    g_B8_Strategy_Armed[index] =
        GlobalVariableCheck(armed_key) && GlobalVariableGet(armed_key) > 0.5;
    g_B8_Strategy_Trade_Count[index] = GlobalVariableCheck(trades_key)
                                      ? (int)MathMax(0.0, GlobalVariableGet(trades_key))
                                      : 0;
}

// 返回人工策略过滤总开关的当前状态。
bool B8_Strategy_IsEnabled()
{
    return B8_Strategy_Filter_Enabled;
}

// 根据策略编号读取对应输入参数，并填充统一的策略配置结构体。
void B8_Strategy_Load(int index, B8_MANUAL_STRATEGY &strategy)
{
    strategy.enabled = false;
    strategy.direction = B8_STRATEGY_SELL;
    strategy.trigger_mode = B8_STRATEGY_ZONE;
    strategy.zone_lower = 0.0;
    strategy.zone_upper = 0.0;
    strategy.trigger_price = 0.0;
    strategy.require_in_zone = false;
    strategy.priority = index + 1;
    strategy.max_trades = 1;

    switch (index)
    {
        case 0:
            strategy.enabled = B8_Strategy1_Enabled;
            strategy.direction = B8_Strategy1_Direction;
            strategy.trigger_mode = B8_Strategy1_Trigger_Mode;
            strategy.zone_lower = B8_Strategy1_Zone_Lower;
            strategy.zone_upper = B8_Strategy1_Zone_Upper;
            strategy.trigger_price = B8_Strategy1_Trigger_Price;
            strategy.require_in_zone = B8_Strategy1_Require_In_Zone;
            strategy.priority = B8_Strategy1_Priority;
            strategy.max_trades = B8_Strategy1_Max_Trades;
            break;
        case 1:
            strategy.enabled = B8_Strategy2_Enabled;
            strategy.direction = B8_Strategy2_Direction;
            strategy.trigger_mode = B8_Strategy2_Trigger_Mode;
            strategy.zone_lower = B8_Strategy2_Zone_Lower;
            strategy.zone_upper = B8_Strategy2_Zone_Upper;
            strategy.trigger_price = B8_Strategy2_Trigger_Price;
            strategy.require_in_zone = B8_Strategy2_Require_In_Zone;
            strategy.priority = B8_Strategy2_Priority;
            strategy.max_trades = B8_Strategy2_Max_Trades;
            break;
        case 2:
            strategy.enabled = B8_Strategy3_Enabled;
            strategy.direction = B8_Strategy3_Direction;
            strategy.trigger_mode = B8_Strategy3_Trigger_Mode;
            strategy.zone_lower = B8_Strategy3_Zone_Lower;
            strategy.zone_upper = B8_Strategy3_Zone_Upper;
            strategy.trigger_price = B8_Strategy3_Trigger_Price;
            strategy.require_in_zone = B8_Strategy3_Require_In_Zone;
            strategy.priority = B8_Strategy3_Priority;
            strategy.max_trades = B8_Strategy3_Max_Trades;
            break;
        case 3:
            strategy.enabled = B8_Strategy4_Enabled;
            strategy.direction = B8_Strategy4_Direction;
            strategy.trigger_mode = B8_Strategy4_Trigger_Mode;
            strategy.zone_lower = B8_Strategy4_Zone_Lower;
            strategy.zone_upper = B8_Strategy4_Zone_Upper;
            strategy.trigger_price = B8_Strategy4_Trigger_Price;
            strategy.require_in_zone = B8_Strategy4_Require_In_Zone;
            strategy.priority = B8_Strategy4_Priority;
            strategy.max_trades = B8_Strategy4_Max_Trades;
            break;
        case 4:
            strategy.enabled = B8_Strategy5_Enabled;
            strategy.direction = B8_Strategy5_Direction;
            strategy.trigger_mode = B8_Strategy5_Trigger_Mode;
            strategy.zone_lower = B8_Strategy5_Zone_Lower;
            strategy.zone_upper = B8_Strategy5_Zone_Upper;
            strategy.trigger_price = B8_Strategy5_Trigger_Price;
            strategy.require_in_zone = B8_Strategy5_Require_In_Zone;
            strategy.priority = B8_Strategy5_Priority;
            strategy.max_trades = B8_Strategy5_Max_Trades;
            break;
        case 5:
            strategy.enabled = B8_Strategy6_Enabled;
            strategy.direction = B8_Strategy6_Direction;
            strategy.trigger_mode = B8_Strategy6_Trigger_Mode;
            strategy.zone_lower = B8_Strategy6_Zone_Lower;
            strategy.zone_upper = B8_Strategy6_Zone_Upper;
            strategy.trigger_price = B8_Strategy6_Trigger_Price;
            strategy.require_in_zone = B8_Strategy6_Require_In_Zone;
            strategy.priority = B8_Strategy6_Priority;
            strategy.max_trades = B8_Strategy6_Max_Trades;
            break;
        case 6:
            strategy.enabled = B8_Strategy7_Enabled;
            strategy.direction = B8_Strategy7_Direction;
            strategy.trigger_mode = B8_Strategy7_Trigger_Mode;
            strategy.zone_lower = B8_Strategy7_Zone_Lower;
            strategy.zone_upper = B8_Strategy7_Zone_Upper;
            strategy.trigger_price = B8_Strategy7_Trigger_Price;
            strategy.require_in_zone = B8_Strategy7_Require_In_Zone;
            strategy.priority = B8_Strategy7_Priority;
            strategy.max_trades = B8_Strategy7_Max_Trades;
            break;
        case 7:
            strategy.enabled = B8_Strategy8_Enabled;
            strategy.direction = B8_Strategy8_Direction;
            strategy.trigger_mode = B8_Strategy8_Trigger_Mode;
            strategy.zone_lower = B8_Strategy8_Zone_Lower;
            strategy.zone_upper = B8_Strategy8_Zone_Upper;
            strategy.trigger_price = B8_Strategy8_Trigger_Price;
            strategy.require_in_zone = B8_Strategy8_Require_In_Zone;
            strategy.priority = B8_Strategy8_Priority;
            strategy.max_trades = B8_Strategy8_Max_Trades;
            break;
    }
}

// 初始化所有策略槽位，并恢复已经持久化的运行状态。
void B8_Strategy_Initialize()
{
    if (g_B8_Strategy_Initialized) return;

    for (int i = 0; i < B8_STRATEGY_SLOT_COUNT; i++)
    {
        g_B8_Strategy_Armed[i] = false;
        g_B8_Strategy_Trade_Count[i] = 0;
        g_B8_Strategy_Selected[i] = -1;
        B8_Strategy_LoadState(i);
    }

    g_B8_Strategy_Selected_Count = 0;
    g_B8_Strategy_Initialized = true;
}

// 检查策略是否配置了有效的上下价格区间。
bool B8_Strategy_ValidZone(const B8_MANUAL_STRATEGY &strategy)
{
    return (strategy.zone_lower > 0.0 &&
            strategy.zone_upper > 0.0 &&
            MathAbs(strategy.zone_upper - strategy.zone_lower) > Point() * 0.5);
}

// 判断指定价格是否位于策略定义的上下限区间内。
bool B8_Strategy_PriceInZone(double price, const B8_MANUAL_STRATEGY &strategy)
{
    if (!B8_Strategy_ValidZone(strategy)) return false;

    double lower = MathMin(strategy.zone_lower, strategy.zone_upper);
    double upper = MathMax(strategy.zone_lower, strategy.zone_upper);
    return (price >= lower && price <= upper);
}

// 根据策略方向判断当前价格是否已经触发策略的武装价格。
bool B8_Strategy_TouchTriggered(double price, const B8_MANUAL_STRATEGY &strategy)
{
    if (strategy.trigger_price <= 0.0) return false;

    if (strategy.direction == B8_STRATEGY_BUY)
        return price <= strategy.trigger_price;

    return price >= strategy.trigger_price;
}

// 每个 Tick 检查触价后捕获模式，并把满足条件的策略置为已武装。
void B8_Strategy_OnTick()
{
    if (!B8_Strategy_Filter_Enabled) return;

    B8_Strategy_Initialize();
    RefreshRates();

    for (int i = 0; i < B8_STRATEGY_SLOT_COUNT; i++)
    {
        B8_MANUAL_STRATEGY strategy;
        B8_Strategy_Load(i, strategy);

        if (!strategy.enabled || strategy.trigger_mode != B8_STRATEGY_TOUCH_ARM)
            continue;
        if (g_B8_Strategy_Armed[i])
            continue;
        if (B8_Strategy_TouchTriggered(Bid, strategy))
        {
            g_B8_Strategy_Armed[i] = true;
            B8_Strategy_SaveState(i);
            if (B8_Strategy_Log_Decisions)
                Print("[Bot8][策略过滤] 策略", i + 1, " 已触价武装，Bid=",
                      DoubleToString(Bid, _Digits),
                      " 触发价=", DoubleToString(strategy.trigger_price, _Digits));
        }
    }
}

// 判断指定交易方向和信号价格是否满足某一条人工策略。
bool B8_Strategy_Matches(int index, int type, double signal_price)
{
    B8_MANUAL_STRATEGY strategy;
    B8_Strategy_Load(index, strategy);

    if (!strategy.enabled) return false;
    if (strategy.max_trades > 0 && g_B8_Strategy_Trade_Count[index] >= strategy.max_trades)
        return false;

    int expected_type = (strategy.direction == B8_STRATEGY_BUY) ? OP_BUY : OP_SELL;
    if (type != expected_type) return false;

    if (strategy.trigger_mode == B8_STRATEGY_ZONE)
        return B8_Strategy_PriceInZone(signal_price, strategy);

    if (!g_B8_Strategy_Armed[index]) return false;
    if (strategy.require_in_zone &&
        !B8_Strategy_PriceInZone(signal_price, strategy))
        return false;

    return true;
}

// 收集所有匹配策略，并按照用户选择的冲突处理规则筛选最终策略。
void B8_Strategy_SelectMatches(int type, double signal_price)
{
    g_B8_Strategy_Selected_Count = 0;

    for (int i = 0; i < B8_STRATEGY_SLOT_COUNT; i++)
    {
        if (B8_Strategy_Matches(i, type, signal_price))
            g_B8_Strategy_Selected[g_B8_Strategy_Selected_Count++] = i;
    }

    if (g_B8_Strategy_Selected_Count <= 1) return;

    if (B8_Strategy_Match_Policy == B8_STRATEGY_MATCH_ALL)
        return;

    if (B8_Strategy_Match_Policy == B8_STRATEGY_MATCH_SKIP)
    {
        g_B8_Strategy_Selected_Count = 0;
        return;
    }

    int selected_position = 0;
    if (B8_Strategy_Match_Policy == B8_STRATEGY_MATCH_PRIORITY)
    {
        B8_MANUAL_STRATEGY best;
        B8_Strategy_Load(g_B8_Strategy_Selected[0], best);
        for (int j = 1; j < g_B8_Strategy_Selected_Count; j++)
        {
            B8_MANUAL_STRATEGY candidate;
            B8_Strategy_Load(g_B8_Strategy_Selected[j], candidate);
            if (candidate.priority < best.priority)
            {
                best = candidate;
                selected_position = j;
            }
        }
    }

    int selected_index = g_B8_Strategy_Selected[selected_position];
    g_B8_Strategy_Selected[0] = selected_index;
    g_B8_Strategy_Selected_Count = 1;
}

// 只有启用策略过滤时调用；关闭时由旧代码完整执行。
// 对通过筛选的策略调用原有市价交易和挂单计划函数。
void B8_Strategy_ExecuteSignal(const KBarSignal &signal, int type)
{
    B8_Strategy_Initialize();

    if (B8_Strategy_Require_M5 && Period() != PERIOD_M5)
    {
        Print("[Bot8][策略过滤] 当前周期不是M5，策略信号不执行。当前周期=", Period());
        return;
    }

    double signal_price = Close[1];
    B8_Strategy_SelectMatches(type, signal_price);

    if (g_B8_Strategy_Selected_Count <= 0)
    {
        if (B8_Strategy_Log_Decisions)
            Print("[Bot8][策略过滤] M5信号未匹配任何人工策略，跳过。方向=",
                  (type == OP_BUY ? "BUY" : "SELL"),
                  " Close[1]=", DoubleToString(signal_price, _Digits));
        return;
    }

    for (int i = 0; i < g_B8_Strategy_Selected_Count; i++)
    {
        int strategy_index = g_B8_Strategy_Selected[i];
        B8_MANUAL_STRATEGY strategy;
        B8_Strategy_Load(strategy_index, strategy);

        if (g_Runtime_Entry_Mode == B8_ENTRY_MARKET &&
            B8_CountOpenPositions() >= Max_Open_Orders)
        {
            Print("[Bot8][策略过滤] 已达到最大持仓数，停止继续执行匹配策略。策略",
                  strategy_index + 1);
            break;
        }

        if (B8_Strategy_Log_Decisions)
            Print("[Bot8][策略过滤] 策略", strategy_index + 1,
                  " 匹配，开始执行。模式=", strategy.trigger_mode == B8_STRATEGY_ZONE ? "区间内" : "触价后",
                  " 方向=", type == OP_BUY ? "BUY" : "SELL",
                  " Close[1]=", DoubleToString(signal_price, _Digits));

        if (g_Runtime_Entry_Mode != B8_ENTRY_PENDING)
            B8_ExecuteTrade(signal, type);
        if (g_Runtime_Entry_Mode != B8_ENTRY_MARKET)
            B8_CreatePendingPlans(signal, type);

        g_B8_Strategy_Trade_Count[strategy_index]++;
        B8_Strategy_SaveState(strategy_index);
    }
}
