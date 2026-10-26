#ifndef __KTARGET_PANEL_MQL5_COMPAT_MQH__
#define __KTARGET_PANEL_MQL5_COMPAT_MQH__

//+------------------------------------------------------------------+
//| MQL5 compatibility layer for the converted panel EA.             |
//| The original MQL4 source remains unchanged in the MQL4 terminal. |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>

#define OP_BUY       ORDER_TYPE_BUY
#define OP_SELL      ORDER_TYPE_SELL
#define OP_BUYLIMIT  ORDER_TYPE_BUY_LIMIT
#define OP_SELLLIMIT ORDER_TYPE_SELL_LIMIT
#define OP_BUYSTOP   ORDER_TYPE_BUY_STOP
#define OP_SELLSTOP  ORDER_TYPE_SELL_STOP
#define SELECT_BY_POS 0
#define SELECT_BY_TICKET 1
#define MODE_TRADES 0
#define MODE_HISTORY 1
#define MODE_STOPLEVEL SYMBOL_TRADE_STOPS_LEVEL

CTrade g_ktTrade;
ulong  g_ktSelectedTicket = 0;
bool   g_ktSelectedPosition = false;
bool   g_ktSelectedHistory = false;
int    g_ktAtrHandle = INVALID_HANDLE;

//#region MARK: 模块--MQL5行情与时间兼容函数
class KTMarketCompat
{
public:
   double Bid(void) const
   {
      MqlTick tick;
      return(SymbolInfoTick(_Symbol, tick) ? tick.bid : 0.0);
   }
   double Ask(void) const
   {
      MqlTick tick;
      return(SymbolInfoTick(_Symbol, tick) ? tick.ask : 0.0);
   }
};
KTMarketCompat g_ktMarket;
#define Bid g_ktMarket.Bid()
#define Ask g_ktMarket.Ask()

datetime KT_TimeAt(const int shift)
{
   return(iTime(_Symbol, _Period, shift));
}

int KT_Bars(void)
{
   return(Bars(_Symbol, _Period));
}

datetime KT_DateValue(const datetime value, const int part)
{
   MqlDateTime dt;
   TimeToStruct(value, dt);
   if(part == 0) return(dt.year);
   if(part == 1) return(dt.mon);
   if(part == 2) return(dt.day);
   if(part == 3) return(dt.hour);
   if(part == 4) return(dt.min);
   return(dt.sec);
}
int TimeYear(const datetime value)   { return((int)KT_DateValue(value, 0)); }
int TimeMonth(const datetime value)  { return((int)KT_DateValue(value, 1)); }
int TimeDay(const datetime value)    { return((int)KT_DateValue(value, 2)); }
int TimeHour(const datetime value)   { return((int)KT_DateValue(value, 3)); }
int TimeMinute(const datetime value) { return((int)KT_DateValue(value, 4)); }
void RefreshRates(void) { MqlTick tick; SymbolInfoTick(_Symbol, tick); }

bool IsTradeAllowed(void)
{
   return((bool)MQLInfoInteger(MQL_TRADE_ALLOWED) &&
          (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED));
}

int MarketInfo(const string symbol, const int type)
{
   if(type == MODE_STOPLEVEL)
      return((int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL));
   return(0);
}

double iATR(const string symbol, const ENUM_TIMEFRAMES period, const int ma_period, const int shift)
{
   if(g_ktAtrHandle == INVALID_HANDLE)
      g_ktAtrHandle = ::iATR(symbol, period, ma_period);
   if(g_ktAtrHandle == INVALID_HANDLE) return(0.0);
   double values[1];
   double result = 0.0;
   if(CopyBuffer(g_ktAtrHandle, 0, shift, 1, values) == 1)
      result = values[0];
   return(result);
}

void KT_InitIndicators(void)
{
   if(g_ktAtrHandle == INVALID_HANDLE)
      g_ktAtrHandle = ::iATR(_Symbol, _Period, 14);
}

void KT_ReleaseIndicators(void)
{
   if(g_ktAtrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_ktAtrHandle);
      g_ktAtrHandle = INVALID_HANDLE;
   }
}
//#endregion

//#region MARK: 模块--MQL5订单选择与属性兼容函数
bool KT_SelectPositionByIndex(const int index)
{
   ulong ticket = PositionGetTicket(index);
   if(ticket == 0) return(false);
   g_ktSelectedTicket = ticket;
   g_ktSelectedPosition = true;
   g_ktSelectedHistory = false;
   return(true);
}

bool KT_SelectOrderByIndex(const int index, const bool history)
{
   ulong ticket = 0;
   if(history)
   {
      if(index < 0 || index >= HistoryOrdersTotal()) return(false);
      ticket = HistoryOrderGetTicket(index);
      if(ticket == 0) return(false);
      g_ktSelectedHistory = true;
   }
   else
   {
      ticket = OrderGetTicket(index);
      if(ticket == 0) return(false);
      g_ktSelectedHistory = false;
   }
   g_ktSelectedTicket = ticket;
   g_ktSelectedPosition = false;
   return(true);
}

bool OrderSelect(const int index, const int select=SELECT_BY_TICKET, const int pool=MODE_TRADES)
{
   if(select == SELECT_BY_TICKET)
   {
      if(PositionSelectByTicket((ulong)index))
      {
         g_ktSelectedTicket = (ulong)index;
         g_ktSelectedPosition = true;
         g_ktSelectedHistory = false;
         return(true);
      }
      if(::OrderSelect((ulong)index))
      {
         g_ktSelectedTicket = (ulong)index;
         g_ktSelectedPosition = false;
         g_ktSelectedHistory = false;
         return(true);
      }
      return(false);
   }
   if(pool == MODE_HISTORY)
   {
      if(!g_ktSelectedHistory)
         HistorySelect(0, TimeCurrent());
      return(KT_SelectOrderByIndex(index, true));
   }
   if(index < PositionsTotal())
      return(KT_SelectPositionByIndex(index));
   return(KT_SelectOrderByIndex(index - PositionsTotal(), false));
}

bool KT_IsPosition(void) { return(g_ktSelectedPosition && g_ktSelectedTicket != 0); }
string OrderSymbol(void) { return(KT_IsPosition() ? PositionGetString(POSITION_SYMBOL) : OrderGetString(ORDER_SYMBOL)); }
int OrderType(void) { return(KT_IsPosition() ? (int)PositionGetInteger(POSITION_TYPE) : (int)OrderGetInteger(ORDER_TYPE)); }
int OrderMagicNumber(void) { return((int)(KT_IsPosition() ? PositionGetInteger(POSITION_MAGIC) : OrderGetInteger(ORDER_MAGIC))); }
int OrderTicket(void) { return((int)g_ktSelectedTicket); }
double OrderLots(void) { return(KT_IsPosition() ? PositionGetDouble(POSITION_VOLUME) : OrderGetDouble(ORDER_VOLUME_INITIAL)); }
double OrderOpenPrice(void) { return(KT_IsPosition() ? PositionGetDouble(POSITION_PRICE_OPEN) : OrderGetDouble(ORDER_PRICE_OPEN)); }
double OrderStopLoss(void) { return(KT_IsPosition() ? PositionGetDouble(POSITION_SL) : OrderGetDouble(ORDER_SL)); }
double OrderTakeProfit(void) { return(KT_IsPosition() ? PositionGetDouble(POSITION_TP) : OrderGetDouble(ORDER_TP)); }
datetime OrderOpenTime(void) { return((datetime)(KT_IsPosition() ? PositionGetInteger(POSITION_TIME) : OrderGetInteger(ORDER_TIME_SETUP))); }
datetime OrderCloseTime(void) { return((datetime)OrderGetInteger(ORDER_TIME_DONE)); }
double OrderClosePrice(void)
{
   if(KT_IsPosition()) return((OrderType() == OP_BUY) ? Bid : Ask);
   return(OrderGetDouble(ORDER_PRICE_CURRENT));
}
double OrderProfit(void) { return(KT_IsPosition() ? PositionGetDouble(POSITION_PROFIT) : 0.0); }
double OrderSwap(void) { return(KT_IsPosition() ? PositionGetDouble(POSITION_SWAP) : 0.0); }
double OrderCommission(void) { return(0.0); }
int OrdersHistoryTotal(void) { HistorySelect(0, TimeCurrent()); return(HistoryOrdersTotal()); }
//#endregion

//#region MARK: 模块--MQL5交易操作兼容函数
int OrderSend(const string symbol, const int type, const double volume, const double price,
              const int deviation, const double sl, const double tp, const string comment,
              const int magic, const datetime expiration, const color arrow)
{
   g_ktTrade.SetExpertMagicNumber((ulong)magic);
   g_ktTrade.SetDeviationInPoints(deviation);
   bool result = false;
   switch(type)
   {
      case OP_BUY:       result = g_ktTrade.Buy(volume, symbol, price, sl, tp, comment); break;
      case OP_SELL:      result = g_ktTrade.Sell(volume, symbol, price, sl, tp, comment); break;
      case OP_BUYLIMIT:  result = g_ktTrade.BuyLimit(volume, price, symbol, sl, tp, ORDER_TIME_GTC, expiration, comment); break;
      case OP_SELLLIMIT: result = g_ktTrade.SellLimit(volume, price, symbol, sl, tp, ORDER_TIME_GTC, expiration, comment); break;
      case OP_BUYSTOP:   result = g_ktTrade.BuyStop(volume, price, symbol, sl, tp, ORDER_TIME_GTC, expiration, comment); break;
      case OP_SELLSTOP:  result = g_ktTrade.SellStop(volume, price, symbol, sl, tp, ORDER_TIME_GTC, expiration, comment); break;
   }
   if(!result)
   {
      Print("[ERR] CTrade request rejected. retcode=",
            IntegerToString((int)g_ktTrade.ResultRetcode()), " ",
            g_ktTrade.ResultRetcodeDescription());
      return(-1);
   }
   ulong ticket = g_ktTrade.ResultOrder();
   if(ticket == 0) ticket = g_ktTrade.ResultDeal();
   return((int)ticket);
}

bool OrderClose(const int ticket, const double volume, const double price, const int deviation, const color arrow=clrNONE)
{
   g_ktTrade.SetDeviationInPoints(deviation);
   if(!PositionSelectByTicket((ulong)ticket)) return(false);
   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   if(volume >= currentVolume - 0.00000001)
      return(g_ktTrade.PositionClose((ulong)ticket, deviation));
   return(g_ktTrade.PositionClosePartial((ulong)ticket, volume, deviation));
}

bool OrderModify(const int ticket, const double openPrice, const double sl, const double tp,
                 const datetime expiration, const color arrow=clrNONE)
{
   if(PositionSelectByTicket((ulong)ticket))
      return(g_ktTrade.PositionModify((ulong)ticket, sl, tp));
   if(::OrderSelect((ulong)ticket))
      return(g_ktTrade.OrderModify((ulong)ticket, openPrice, sl, tp, ORDER_TIME_GTC, expiration, 0.0));
   return(false);
}

bool OrderDelete(const int ticket, const color arrow=clrNONE)
{
   return(g_ktTrade.OrderDelete((ulong)ticket));
}
//#endregion

//#region MARK: 模块--MQL5账户与图表兼容函数
double AccountBalance(void) { return(AccountInfoDouble(ACCOUNT_BALANCE)); }
double AccountMargin(void) { return(AccountInfoDouble(ACCOUNT_MARGIN)); }
int AccountStopoutMode(void) { return((int)AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE)); }
double AccountStopoutLevel(void)
{
   if(AccountStopoutMode() == ACCOUNT_STOPOUT_MODE_PERCENT)
      return(AccountInfoDouble(ACCOUNT_MARGIN_SO_SO));
   return(AccountInfoDouble(ACCOUNT_MARGIN_SO_SO));
}

int ObjectsTotal(void) { return(::ObjectsTotal(0, -1, -1)); }
string ObjectName(const int index) { return(::ObjectName(0, index, -1, -1)); }

//#endregion

#endif
