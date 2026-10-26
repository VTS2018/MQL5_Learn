#ifndef __B8_MQL4_COMPAT_MQH__
#define __B8_MQL4_COMPAT_MQH__

#include <Trade/Trade.mqh>

#define OP_BUY       0
#define OP_SELL      1
#define OP_BUYLIMIT  2
#define OP_SELLLIMIT 3
#define OP_BUYSTOP   4
#define OP_SELLSTOP  5
#define SELECT_BY_POS    0
#define SELECT_BY_TICKET 1
#define MODE_TRADES  0
#define MODE_HISTORY 1
#define MODE_MINLOT  0
#define MODE_MAXLOT  1
#define MODE_LOTSTEP 2
#define MODE_LOTSIZE 3
#define MODE_TICKSIZE 4
#define MODE_TICKVALUE 5
#define MODE_POINT 6
#define MODE_DIGITS 7
#define MODE_STOPLEVEL 8
#define MODE_BID 9
#define MODE_ASK 10

CTrade g_B8_Trade;
ulong g_B8_SelectedTicket = 0;
bool g_B8_SelectedPosition = false;
bool g_B8_SelectedHistory = false;
datetime B8_Time[];
double B8_Close[];

//#region MARK: 模块--统一读取 Series K 线数据
// 新增：直接按 shift 读取 MT5 时间序列，避免依赖 EA 中 Time[]/Close[] 的数组方向。
// 获取指定偏移位置的 K 线开盘时间；shift 小于 0 时返回 0。
datetime B8_GetBarTime(int shift)
{
    if (shift < 0) return 0;
    return iTime(_Symbol, _Period, shift);
}

// 获取指定偏移位置的 K 线收盘价；shift 小于 0 时返回 0.0。
double B8_GetBarClose(int shift)
{
    if (shift < 0) return 0.0;
    return iClose(_Symbol, _Period, shift);
}

// 获取当前 K 线的开盘时间。
datetime B8_GetCurrentBarTime()
{
    return B8_GetBarTime(0);
}

// 获取上一根已收盘 K 线的开盘时间。
datetime B8_GetClosedBarTime()
{
    return B8_GetBarTime(1);
}

// 获取上一根已收盘 K 线的收盘价。
double B8_GetClosedBarClose()
{
    return B8_GetBarClose(1);
}
//#endregion

// 获取当前活动订单总数，按 MQL4 兼容方式合并持仓和挂单数量。
int B8_OrdersTotal()
{
    return PositionsTotal() + ::OrdersTotal();
}

// 获取历史订单总数，并先选择从起始时间至当前时间的全部历史记录。
int B8_OrdersHistoryTotal()
{
    HistorySelect(0, TimeCurrent());
    return HistoryOrdersTotal();
}

// 按位置或票号选择订单、持仓或历史订单，并保存后续属性读取所需的选择状态。
// ticket 为索引或订单票号，select_mode 为选择方式，pool 指定当前订单或历史订单池。
bool B8_OrderSelect(ulong ticket, int select_mode, int pool)
{
    g_B8_SelectedTicket = 0;
    g_B8_SelectedPosition = false;
    g_B8_SelectedHistory = (pool == MODE_HISTORY);

    if (select_mode == SELECT_BY_POS)
    {
        if (pool == MODE_HISTORY)
        {
            HistorySelect(0, TimeCurrent());
            if (ticket >= (ulong)HistoryOrdersTotal()) return false;
            ticket = HistoryOrderGetTicket((int)ticket);
        }
        else if (ticket < (ulong)PositionsTotal())
        {
            ticket = PositionGetTicket((int)ticket);
            g_B8_SelectedPosition = (ticket != 0);
        }
        else
        {
            ticket -= (ulong)PositionsTotal();
            if (ticket >= (ulong)::OrdersTotal()) return false;
            ticket = ::OrderGetTicket((int)ticket);
        }
    }

    if (ticket == 0) return false;
    if (g_B8_SelectedHistory)
    {
        if (!HistoryOrderSelect(ticket)) return false;
    }
    else if (g_B8_SelectedPosition)
    {
        if (!PositionSelectByTicket(ticket)) return false;
    }
    else if (!::OrderSelect(ticket))
    {
        if (!PositionSelectByTicket(ticket)) return false;
        g_B8_SelectedPosition = true;
    }

    g_B8_SelectedTicket = ticket;
    return true;
}

// 获取已选择订单或持仓对应的交易品种。
string B8_OrderSymbol()
{
    if (g_B8_SelectedHistory) return HistoryOrderGetString(g_B8_SelectedTicket, ORDER_SYMBOL);
    if (g_B8_SelectedPosition) return PositionGetString(POSITION_SYMBOL);
    return ::OrderGetString(ORDER_SYMBOL);
}

// MQL4 兼容接口中的 Magic 使用 int；MQL5 属性读取结果在此处明确收窄。
// 获取已选择订单、持仓或历史订单的 Magic Number。
int B8_OrderMagicNumber()
{
    if (g_B8_SelectedHistory) return (int)HistoryOrderGetInteger(g_B8_SelectedTicket, ORDER_MAGIC);
    if (g_B8_SelectedPosition) return (int)PositionGetInteger(POSITION_MAGIC);
    return (int)::OrderGetInteger(ORDER_MAGIC);
}

// 获取已选择交易对象的 MQL4 订单类型常量。
int B8_OrderType()
{
    ENUM_ORDER_TYPE type;
    if (g_B8_SelectedHistory) type = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(g_B8_SelectedTicket, ORDER_TYPE);
    else if (g_B8_SelectedPosition) return (int)PositionGetInteger(POSITION_TYPE);
    else type = (ENUM_ORDER_TYPE)::OrderGetInteger(ORDER_TYPE);

    switch(type)
    {
        case ORDER_TYPE_BUY: return OP_BUY;
        case ORDER_TYPE_SELL: return OP_SELL;
        case ORDER_TYPE_BUY_LIMIT: return OP_BUYLIMIT;
        case ORDER_TYPE_SELL_LIMIT: return OP_SELLLIMIT;
        case ORDER_TYPE_BUY_STOP: return OP_BUYSTOP;
        case ORDER_TYPE_SELL_STOP: return OP_SELLSTOP;
        default: return -1;
    }
}

// 获取已选择订单或持仓的手数。
double B8_OrderLots()
{
    if (g_B8_SelectedHistory) return HistoryOrderGetDouble(g_B8_SelectedTicket, ORDER_VOLUME_INITIAL);
    if (g_B8_SelectedPosition) return PositionGetDouble(POSITION_VOLUME);
    return ::OrderGetDouble(ORDER_VOLUME_CURRENT);
}

// 获取已选择订单或持仓的开仓价格。
double B8_OrderOpenPrice()
{
    if (g_B8_SelectedHistory) return HistoryOrderGetDouble(g_B8_SelectedTicket, ORDER_PRICE_OPEN);
    if (g_B8_SelectedPosition) return PositionGetDouble(POSITION_PRICE_OPEN);
    return ::OrderGetDouble(ORDER_PRICE_OPEN);
}

// 获取已选择持仓或挂单的止损价格；历史订单返回 0.0。
double B8_OrderStopLoss()
{
    if (g_B8_SelectedHistory) return 0.0;
    if (g_B8_SelectedPosition) return PositionGetDouble(POSITION_SL);
    return ::OrderGetDouble(ORDER_SL);
}

// 获取已选择持仓或挂单的止盈价格；历史订单返回 0.0。
double B8_OrderTakeProfit()
{
    if (g_B8_SelectedHistory) return 0.0;
    if (g_B8_SelectedPosition) return PositionGetDouble(POSITION_TP);
    return ::OrderGetDouble(ORDER_TP);
}

// 获取已选择持仓的浮动盈亏；挂单和历史订单返回 0.0。
double B8_OrderProfit()
{
    if (g_B8_SelectedHistory) return 0.0;
    if (g_B8_SelectedPosition) return PositionGetDouble(POSITION_PROFIT);
    return 0.0;
}

// 获取当前已选择交易对象的票号。
ulong B8_OrderTicket()
{
    return g_B8_SelectedTicket;
}

// 获取已选择订单、持仓或历史订单的备注。
string B8_OrderComment()
{
    if (g_B8_SelectedHistory) return HistoryOrderGetString(g_B8_SelectedTicket, ORDER_COMMENT);
    if (g_B8_SelectedPosition) return PositionGetString(POSITION_COMMENT);
    return ::OrderGetString(ORDER_COMMENT);
}

// 获取已选择交易对象的兼容模式标识；持仓返回 0，订单返回 1。
int B8_OrderMode()
{
    return g_B8_SelectedPosition ? 0 : 1;
}

// 获取已选择订单、持仓或历史订单的开仓或设置时间。
datetime B8_OrderOpenTime()
{
    if (g_B8_SelectedHistory) return (datetime)HistoryOrderGetInteger(g_B8_SelectedTicket, ORDER_TIME_SETUP);
    if (g_B8_SelectedPosition) return (datetime)PositionGetInteger(POSITION_TIME);
    return (datetime)::OrderGetInteger(ORDER_TIME_SETUP);
}

// 按 MQL4 的 mode 常量获取指定品种的市场信息。
// 不支持的 mode 返回 0.0。
double B8_MarketInfo(string symbol, int mode)
{
    switch(mode)
    {
        case MODE_MINLOT: return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        case MODE_MAXLOT: return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        case MODE_LOTSTEP: return SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
        case MODE_LOTSIZE: return SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
        case MODE_TICKSIZE: return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        case MODE_TICKVALUE: return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        case MODE_POINT: return SymbolInfoDouble(symbol, SYMBOL_POINT);
        case MODE_DIGITS: return (double)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        case MODE_STOPLEVEL: return (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        case MODE_BID: return SymbolInfoDouble(symbol, SYMBOL_BID);
        case MODE_ASK: return SymbolInfoDouble(symbol, SYMBOL_ASK);
        default: return 0.0;
    }
}

// 获取当前图表品种的卖价。
double B8_Ask() { return SymbolInfoDouble(_Symbol, SYMBOL_ASK); }

// 获取当前图表品种的买价。
double B8_Bid() { return SymbolInfoDouble(_Symbol, SYMBOL_BID); }

// 刷新当前品种的报价、时间序列和收盘价数组。
void B8_RefreshRates()
{
    MqlTick tick;
    SymbolInfoTick(_Symbol, tick);
    CopyTime(_Symbol, _Period, 0, 2000, B8_Time);
    CopyClose(_Symbol, _Period, 0, 2000, B8_Close);
}

// 获取已选择订单的隔夜利息；当前实现返回 0.0。
double B8_OrderSwap() { return 0.0; }

// 获取已选择订单的手续费；当前实现返回 0.0。
double B8_OrderCommission() { return 0.0; }

// 判断终端是否允许交易。
bool B8_IsTradeAllowed() { return (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED); }

// 获取账户余额。
double B8_AccountBalance() { return AccountInfoDouble(ACCOUNT_BALANCE); }

// 获取账户净值。
double B8_AccountEquity() { return AccountInfoDouble(ACCOUNT_EQUITY); }

// 获取账户登录编号。
long B8_AccountNumber() { return (long)AccountInfoInteger(ACCOUNT_LOGIN); }

// 获取账户货币名称。
string B8_AccountCurrency() { return AccountInfoString(ACCOUNT_CURRENCY); }

// 按 MQL4 参数形式发送市价单或挂单，并返回生成的订单或成交票号。
// 发送失败时返回 0。
ulong B8_OrderSend(string symbol, int cmd, double volume, double price, int slippage,
                   double stop_loss, double take_profit, string comment, int magic,
                   datetime expiration, color arrow_color)
{
    g_B8_Trade.SetExpertMagicNumber((ulong)magic);
    g_B8_Trade.SetDeviationInPoints((ulong)slippage);
    bool sent = false;
    if (cmd == OP_BUY) sent = g_B8_Trade.Buy(volume, symbol, price, stop_loss, take_profit, comment);
    else if (cmd == OP_SELL) sent = g_B8_Trade.Sell(volume, symbol, price, stop_loss, take_profit, comment);
    else
    {
        ENUM_ORDER_TYPE type = (cmd == OP_BUYLIMIT ? ORDER_TYPE_BUY_LIMIT :
                                cmd == OP_SELLLIMIT ? ORDER_TYPE_SELL_LIMIT :
                                cmd == OP_BUYSTOP ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP);
        sent = g_B8_Trade.OrderOpen(symbol, type, volume, 0.0, price, stop_loss,
                                    take_profit, ORDER_TIME_GTC, expiration, comment);
    }
    if (!sent) return 0;
    ulong ticket = g_B8_Trade.ResultOrder();
    if (ticket == 0) ticket = g_B8_Trade.ResultDeal();
    return ticket;
}

// 按指定手数平仓或部分平仓；仅处理当前持仓，操作失败时返回 false。
bool B8_OrderClose(ulong ticket, double lots, double price, int slippage, color arrow_color)
{
    g_B8_Trade.SetDeviationInPoints((ulong)slippage);
    if (PositionSelectByTicket(ticket))
    {
        double current_volume = PositionGetDouble(POSITION_VOLUME);
        if (lots >= current_volume) return g_B8_Trade.PositionClose(ticket);
        return g_B8_Trade.PositionClosePartial(ticket, lots);
    }
    return false;
}

// 删除指定票号的挂单；操作结果由交易类返回。
bool B8_OrderDelete(ulong ticket, color arrow_color = clrNONE)
{
    return g_B8_Trade.OrderDelete(ticket);
}

// 修改指定持仓的止损止盈，或修改指定挂单的价格、止损和止盈。
// 操作结果由交易类返回。
bool B8_OrderModify(ulong ticket, double price, double stop_loss, double take_profit,
                    datetime expiration, color arrow_color)
{
    if (PositionSelectByTicket(ticket))
        return g_B8_Trade.PositionModify(ticket, stop_loss, take_profit);
    return g_B8_Trade.OrderModify(ticket, price, stop_loss, take_profit,
                                  ORDER_TIME_GTC, expiration);
}

#define OrdersTotal B8_OrdersTotal
#define OrdersHistoryTotal B8_OrdersHistoryTotal
#define OrderSelect B8_OrderSelect
#define OrderSymbol B8_OrderSymbol
#define OrderMagicNumber B8_OrderMagicNumber
#define OrderType B8_OrderType
#define OrderLots B8_OrderLots
#define OrderOpenPrice B8_OrderOpenPrice
#define OrderStopLoss B8_OrderStopLoss
#define OrderTakeProfit B8_OrderTakeProfit
#define OrderProfit B8_OrderProfit
#define OrderTicket B8_OrderTicket
#define OrderComment B8_OrderComment
#define OrderOpenTime B8_OrderOpenTime
#define OrderSwap B8_OrderSwap
#define OrderCommission B8_OrderCommission
#define OrderMode B8_OrderMode
#define OrderSend B8_OrderSend
#define OrderClose B8_OrderClose
#define OrderDelete B8_OrderDelete
#define OrderModify B8_OrderModify
#define MarketInfo B8_MarketInfo
#define Ask B8_Ask()
#define Bid B8_Bid()
#define RefreshRates B8_RefreshRates
#define Time B8_Time
#define Close B8_Close
#define AccountBalance B8_AccountBalance
#define AccountEquity B8_AccountEquity
#define AccountNumber B8_AccountNumber
#define AccountCurrency B8_AccountCurrency
#define IsTradeAllowed B8_IsTradeAllowed

#endif
