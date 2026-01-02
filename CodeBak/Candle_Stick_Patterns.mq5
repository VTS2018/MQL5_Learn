//+------------------------------------------------------------------+
//|                                        Candle Stick Patterns.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//https://www.mql5.com/en/articles/20223
//+------------------------------------------------------------------+
//| This application attempts to reliably use different candlestick  |
//| patterns. The application will employ the following:             |
//|                                                                  |
//|   1) Engulfing Candle                                            |
//|   2) Momentum Candle                                             |
//|   3) Doji Candle                                                 |
//|   4) Shooting Star Candle                                        |
//|   5) Hammer Candle                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| System constants                                                 |
//+------------------------------------------------------------------+
#define LOT_SIZE SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN)

//+------------------------------------------------------------------+
//| Trading libraries                                                |
//+------------------------------------------------------------------+
#include  <Trade\Trade.mqh>
CTrade Trade;

//+------------------------------------------------------------------+
//| Indicators                                                       |
//+------------------------------------------------------------------+
int atr_handler;
double atr[];

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
MqlDateTime time_stamp,current_time;
double bid,ask;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Set the time
   TimeLocal(time_stamp);
   TimeLocal(current_time);
   atr_handler = iATR(Symbol(),PERIOD_CURRENT,14);
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   IndicatorRelease(atr_handler);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Update the current time
   TimeLocal(current_time);

//--- Check if a new candle has fully formed
   if(time_stamp.day != current_time.day)
     {
      //--- Update the time
      TimeLocal(time_stamp);

      //--- A new candle has formed
      //--- Update the ATR reading
      CopyBuffer(atr_handler,0,0,1,atr);
      ask = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
      bid = SymbolInfoDouble(Symbol(),SYMBOL_BID);

      //--- First check if we have no open positions
      if(PositionsTotal() == 0)
        {
         //--- Then check for a trade
         //--- Check for a bullish engulfing candle stick pattern
         if((iLow(Symbol(),PERIOD_D1,1)<iLow(Symbol(),PERIOD_D1,2)) && (iHigh(Symbol(),PERIOD_D1,1)>iHigh(Symbol(),PERIOD_D1,2)) && (iOpen(Symbol(),PERIOD_D1,1)>iOpen(Symbol(),PERIOD_D1,2)))
           {
            //--- Then, enter long positions
            Trade.Buy(LOT_SIZE,Symbol(),ask,(ask - (atr[0]*1.5)),(ask + (atr[0]*1.5)));
           }

         //--- Otherwise we may check for bearish engulfing pattern
         if((iLow(Symbol(),PERIOD_D1,1)<iLow(Symbol(),PERIOD_D1,2)) && (iHigh(Symbol(),PERIOD_D1,1)>iHigh(Symbol(),PERIOD_D1,2)) && (iOpen(Symbol(),PERIOD_D1,1)<iOpen(Symbol(),PERIOD_D1,2)))
           {
            //--- Then, enter long positions
            Trade.Sell(LOT_SIZE,Symbol(),ask,(ask + (atr[0]*1.5)),(ask - (atr[0]*1.5)));
           }
        }
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| System definitions                                               |
//+------------------------------------------------------------------+
#undef LOT_SIZE
