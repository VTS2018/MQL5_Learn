// https://www.mql5.com/en/articles/19989
//+------------------------------------------------------------------+
//|                                            Scalps and Swings.mq5 |
//|                        GIT under Copyright 2025, MetaQuotes Ltd. |
//|                     https://www.mql5.com/en/users/johnhlomohang/ |
//+------------------------------------------------------------------+
#property copyright "GIT under Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/johnhlomohang/"
#property version   "1.00"
#property description "Dual-mode EA for Scalping and Swing Trading"
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
enum ENUM_MODE
{
   MODE_SCALP,  // Scalping
   MODE_SWING   // Swing Trading
};

input ENUM_MODE          TradeMode = MODE_SCALP;          // Trading Mode
input string             TradePairs = "XAUUSD,BTCUSD,US100,GBPUSD"; // Trading Pairs (comma separated)
input bool               UseATR = false;                  // Use ATR for SL/TP

// Scalping Parameters
input double             LotSize_Scalp = 0.1;             // Scalp Lot Size
input int                StopLoss_Scalp = 50;             // Scalp Stop Loss (pips)
input int                TakeProfit_Scalp = 30;           // Scalp Take Profit (pips)
input int                ScalpTrailingStop = 15;          // Scalp Trailing Stop (pips)
input ENUM_TIMEFRAMES    ScalpTimeframe = PERIOD_M5;      // Scalping Timeframe
input int                Scalp_EMA_Fast = 5;              // Scalp Fast EMA
input int                Scalp_EMA_Slow = 20;             // Scalp Slow EMA
input int                Scalp_RSI_Period = 14;           // Scalp RSI Period
input int                Scalp_RSI_Overbought = 55;       // Scalp RSI Overbought
input int                Scalp_RSI_Oversold = 45;         // Scalp RSI Oversold

// Swing Trading Parameters
input double             LotSize_Swing = 0.1;             // Swing Lot Size
input int                StopLoss_Swing = 200;            // Swing Stop Loss (pips)
input int                TakeProfit_Swing = 400;          // Swing Take Profit (pips)
input int                SwingTrailingStop = 100;         // Swing Trailing Stop (pips)
input ENUM_TIMEFRAMES    SwingTimeframe = PERIOD_H4;      // Swing Timeframe
input int                Swing_Lookback = 20;             // Swing Lookback Period
input double             Fib_Level = 0.618;               // Fibonacci Retracement Level
input bool               UseHigherTFConfirmation = true;  // Use D1 Confirmation
input ENUM_TIMEFRAMES    HigherTF = PERIOD_D1;            // Higher Timeframe

// Risk Management
input int                MaxOpenPositions = 4;            // Max Open Positions per Pair
input int                MagicNumber = 12345;             // Magic Number
input int                Slippage = 3;                    // Slippage (points)

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
string   SymbolList[];
int      TotalPairs;
datetime LastTickTime = 0;
color    TextColor = clrWhite;
CTrade   trade;

int handleEmaFast_Scalp, handleEmaSlow_Scalp, handleRsi_Scalp;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize trade object
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(Slippage);

    // Split trading pairs
    SplitString(TradePairs, ",", SymbolList);
    TotalPairs = ArraySize(SymbolList);

    // Validate symbols
    for(int i = 0; i < TotalPairs; i++)
    {
        if(!SymbolInfoInteger(SymbolList[i], SYMBOL_TRADE_MODE))
        {
            Print("Error: Symbol ", SymbolList[i], " is not available for trading");
            return(INIT_FAILED);
        }
    }

    // Create indicator handles for scalping mode
    handleEmaFast_Scalp = iMA(NULL, ScalpTimeframe, Scalp_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    if(handleEmaFast_Scalp == INVALID_HANDLE)
    {
        Print("Failed to create handle for fast EMA (Scalp)");
        return(INIT_FAILED);
    }
    handleEmaSlow_Scalp = iMA(NULL, ScalpTimeframe, Scalp_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
    if(handleEmaSlow_Scalp == INVALID_HANDLE)
    {
        Print("Failed to create handle for slow EMA (Scalp)");
        return(INIT_FAILED);
    }
    handleRsi_Scalp = iRSI(NULL, ScalpTimeframe, Scalp_RSI_Period, PRICE_CLOSE);
    if(handleRsi_Scalp == INVALID_HANDLE)
    {
        Print("Failed to create handle for RSI (Scalp)");
        return(INIT_FAILED);
    }

    Print("EA initialized successfully with ", TotalPairs, " pairs");
    Print("Trading Mode: ", EnumToString(TradeMode));

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment(""); // Clear chart comment
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Avoid multiple processing in the same tick
   if(LastTickTime == iTime(_Symbol, _Period, 0)) return;
   LastTickTime = iTime(_Symbol, _Period, 0);
   
   // Process each trading pair
   for(int i = 0; i < TotalPairs; i++)
   {
      string symbol = SymbolList[i];
      
      if(TradeMode == MODE_SCALP)
      {
         ScalpModeHandler(symbol);
         
         if(IsNewBar(symbol, ScalpTimeframe))
         {
            ExecuteScalpTrade(symbol);
         }
         
         ManageScalpTrades(symbol);
      }
      else if(TradeMode == MODE_SWING)
      {
         if(SwingSignal(symbol))
         {
            if(IsNewBar(symbol, SwingTimeframe))
            {
               ExecuteSwingTrade(symbol);
            }
         }
         ManageSwingTrades(symbol);
      }
   }
   
   // Update dashboard
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Check if new bar formed                                         |
//+------------------------------------------------------------------+
bool IsNewBar(string symbol, ENUM_TIMEFRAMES timeframe)
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(symbol, timeframe, 0);
   
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Scalping Signal Function                                         |
//+------------------------------------------------------------------+
void ScalpModeHandler(string symbol)
{
    // Define arrays to hold indicator values
    double emaFastArr[2], emaSlowArr[2], rsiArr[2];

    // Copy values: current and previous
    if(CopyBuffer(handleEmaFast_Scalp, 0, 0, 2, emaFastArr) < 2) return;
    if(CopyBuffer(handleEmaSlow_Scalp, 0, 0, 2, emaSlowArr) < 2) return;
    if(CopyBuffer(handleRsi_Scalp,     0, 0, 2, rsiArr)     < 2) return;

    // Assign named values
    double emaFastCurr = emaFastArr[0];
    double emaFastPrev = emaFastArr[1];
    double emaSlowCurr = emaSlowArr[0];
    double emaSlowPrev = emaSlowArr[1];
    double rsiCurr     = rsiArr[0];

    // Validate (avoid zero or invalid)
    if(emaFastCurr == 0 || emaSlowCurr == 0 || rsiCurr == 0) return;

    // Check open positions for this symbol
    if(CountOpenPositions(symbol) >= MaxOpenPositions) return;

    // BUY signal condition
    if(emaFastCurr > emaSlowCurr && emaFastPrev <= emaSlowPrev && rsiCurr > Scalp_RSI_Overbought)
    {
        ExecuteAdaptiveTrade(ORDER_TYPE_BUY, symbol, LotSize_Scalp);
        Print("Scalp BUY Signal executed for ", symbol);
    }
    // SELL signal condition
    else if(emaFastCurr < emaSlowCurr && emaFastPrev >= emaSlowPrev && rsiCurr < Scalp_RSI_Oversold)
    {
        ExecuteAdaptiveTrade(ORDER_TYPE_SELL, symbol, LotSize_Scalp);
        Print("Scalp SELL Signal executed for ", symbol);
    }
}

//+------------------------------------------------------------------+
//| Swing Trading Signal Function                                    |
//+------------------------------------------------------------------+
bool SwingSignal(string symbol)
{
   int swingHighBar = iHighest(symbol, SwingTimeframe, MODE_HIGH, Swing_Lookback, 1);
   int swingLowBar  = iLowest(symbol, SwingTimeframe, MODE_LOW, Swing_Lookback, 1);
   if(swingHighBar == -1 || swingLowBar == -1) return false;

   double swingHigh     = iHigh(symbol, SwingTimeframe, swingHighBar);
   double swingLow      = iLow(symbol, SwingTimeframe, swingLowBar);
   double currentClose  = iClose(symbol, SwingTimeframe, 0);
   double range         = swingHigh - swingLow;
   if(range == 0) return false;

   double fib618_Up     = swingHigh - Fib_Level * range;
   double fib618_Down   = swingLow + Fib_Level * range;

   bool higherTFBullish = true;
   bool higherTFBearish = true;

   if(UseHigherTFConfirmation)
   {
      int handleEMA = iMA(symbol, HigherTF, 20, 0, MODE_EMA, PRICE_CLOSE);
      if(handleEMA == INVALID_HANDLE) return false;

      double emaVal[1];
      if(CopyBuffer(handleEMA, 0, 0, 1, emaVal) < 1) return false;

      double htEMA20 = emaVal[0];
      double htClose = iClose(symbol, HigherTF, 0);
      higherTFBullish = htClose > htEMA20;
      higherTFBearish = htClose < htEMA20;
   }

   // --- Buy Signal
   if(currentClose <= fib618_Down && currentClose > swingLow && higherTFBullish)
      return true;

   // --- Sell Signal
   if(currentClose >= fib618_Up && currentClose < swingHigh && higherTFBearish)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Execute Scalp Trade                                              |
//+------------------------------------------------------------------+
void ExecuteScalpTrade(string symbol)
{
   if(CountOpenPositions(symbol) >= MaxOpenPositions) return;

   int handleEmaFast = iMA(symbol, ScalpTimeframe, Scalp_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   int handleEmaSlow = iMA(symbol, ScalpTimeframe, Scalp_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   int handleRSI     = iRSI(symbol, ScalpTimeframe, Scalp_RSI_Period, PRICE_CLOSE);

   double emaFast[1], emaSlow[1], rsi[1];
   if(CopyBuffer(handleEmaFast, 0, 0, 1, emaFast) < 1) return;
   if(CopyBuffer(handleEmaSlow, 0, 0, 1, emaSlow) < 1) return;
   if(CopyBuffer(handleRSI, 0, 0, 1, rsi) < 1) return;

   double emaF = emaFast[0];
   double emaS = emaSlow[0];
   double rsiV = rsi[0];

   if(emaF > emaS && rsiV > Scalp_RSI_Overbought)
      ExecuteTrade(ORDER_TYPE_BUY, symbol, LotSize_Scalp, StopLoss_Scalp, TakeProfit_Scalp);
   else if(emaF < emaS && rsiV < Scalp_RSI_Oversold)
      ExecuteTrade(ORDER_TYPE_SELL, symbol, LotSize_Scalp, StopLoss_Scalp, TakeProfit_Scalp);
}


//+------------------------------------------------------------------+
//| Execute Swing Trade                                             |
//+------------------------------------------------------------------+
void ExecuteSwingTrade(string symbol)
{
   if(CountOpenPositions(symbol) >= MaxOpenPositions) return;
   
   // Determine trade direction (simplified logic)
   int swingHighBar = iHighest(symbol, SwingTimeframe, MODE_HIGH, Swing_Lookback, 1);
   int swingLowBar = iLowest(symbol, SwingTimeframe, MODE_LOW, Swing_Lookback, 1);
   
   if(swingHighBar != -1 && swingLowBar != -1)
   {
      double swingHigh = iHigh(symbol, SwingTimeframe, swingHighBar);
      double swingLow = iLow(symbol, SwingTimeframe, swingLowBar);
      double currentClose = iClose(symbol, SwingTimeframe, 0);
      double range = swingHigh - swingLow;
      double fib618_Down = swingLow + Fib_Level * range;
      double fib618_Up = swingHigh - Fib_Level * range;
      
      if(currentClose <= fib618_Down && currentClose > swingLow)
      {
         ExecuteTrade(ORDER_TYPE_BUY, symbol, LotSize_Swing, StopLoss_Swing, TakeProfit_Swing);
      }
      else if(currentClose >= fib618_Up && currentClose < swingHigh)
      {
         ExecuteTrade(ORDER_TYPE_SELL, symbol, LotSize_Swing, StopLoss_Swing, TakeProfit_Swing);
      }
   }
}

//+------------------------------------------------------------------+
//| Execute trade with dynamic stop/TP adaption per symbol           |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE tradeType, string symbol, double lotSize, int stopLossPips, int takeProfitPips)
{
   //--- Symbol info
   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits    = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double price = (tradeType == ORDER_TYPE_BUY) ? ask : bid;

   //--- Detect pip size automatically (handles forex, gold, crypto, indices)
   double pipSize;
   if(StringFind(symbol, "JPY") != -1)              // JPY pairs (2/3 digits)
      pipSize = (digits == 3) ? point * 10 : point;
   else if(StringFind(symbol, "XAU") != -1 || StringFind(symbol, "GOLD") != -1)  // Metals
      pipSize = 0.10;
   else if(StringFind(symbol, "BTC") != -1 || StringFind(symbol, "ETH") != -1)   // Cryptos
      pipSize = point * 100.0;
   else if(StringFind(symbol, "US") != -1 && digits <= 2)                         // Indices
      pipSize = point;
   else
      pipSize = (digits == 3 || digits == 5) ? point * 10 : point;                // Default Forex

   //--- Convert SL/TP from pips to price distances
   double sl_distance = stopLossPips * pipSize;
   double tp_distance = takeProfitPips * pipSize;

   //--- Determine broker minimum stop levels
   double minStopPoints = 0.0;
   if(SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) > 0)
      minStopPoints = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   else if(SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) > 0)
      minStopPoints = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   else
      minStopPoints = 30; // fallback default (points)

   double minStop = minStopPoints * point;

   //--- Ensure SL/TP distances are greater than min stop level
   if(sl_distance < minStop) sl_distance = minStop;
   if(tp_distance < minStop) tp_distance = minStop;

   //--- Calculate final SL/TP prices
   double sl = (tradeType == ORDER_TYPE_BUY) ? price - sl_distance : price + sl_distance;
   double tp = (tradeType == ORDER_TYPE_BUY) ? price + tp_distance : price - tp_distance;

   //--- Normalize prices
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   price = NormalizeDouble(price, digits);

   //--- Safety validation (correct SL/TP relation)
   if((tradeType == ORDER_TYPE_BUY && (sl >= price || tp <= price)) ||
      (tradeType == ORDER_TYPE_SELL && (sl <= price || tp >= price)))
   {
      Print("Invalid SL/TP detected for ", symbol, " — auto-adjusting...");
      if(tradeType == ORDER_TYPE_BUY)
      {
         sl = NormalizeDouble(price - minStop, digits);
         tp = NormalizeDouble(price + minStop * 2, digits);
      }
      else
      {
         sl = NormalizeDouble(price + minStop, digits);
         tp = NormalizeDouble(price - minStop * 2, digits);
      }
   }

   //--- Try executing trade
   if(trade.PositionOpen(symbol, tradeType, lotSize, price, sl, tp, "Adaptive Multi-Pair EA"))
   {
      PrintFormat("%s opened on %s | Lot: %.2f | SL: %.5f | TP: %.5f | TickValue: %.2f",
                  EnumToString(tradeType), symbol, lotSize, sl, tp, tickValue);
   }
   else
   {
      int err = GetLastError();
      PrintFormat("Failed to open %s on %s | Error %d: %s",
                  EnumToString(tradeType), symbol, err, err);
      ResetLastError();
      
   }
}

//+------------------------------------------------------------------+
//| Execute trade with adaptive SL/TP by symbol type                 |
//+------------------------------------------------------------------+
void ExecuteAdaptiveTrade(ENUM_ORDER_TYPE type, string symbol, double lotSize)
{
   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits    = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double ask    = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(symbol, SYMBOL_BID);
   double price  = (type == ORDER_TYPE_BUY) ? ask : bid;

   //--- Determine adaptive pip scale per asset
   double pipScale;
   if(StringFind(symbol, "XAU") != -1 || StringFind(symbol, "GOLD") != -1)
      pipScale = 1.0;          // Gold → 1 dollar movement = 1 pip
   else if(StringFind(symbol, "BTC") != -1)
      pipScale = 50.0;         // Crypto → 50-point unit for volatility
   else if(StringFind(symbol, "US") != -1 && digits <= 2)
      pipScale = 10.0;         // Indices (US100, US30)
   else if(StringFind(symbol, "JPY") != -1)
      pipScale = 0.1;          // Yen pairs
   else
      pipScale = 0.0001;       // Standard Forex

   ENUM_TIMEFRAMES tf = ScalpTimeframe;

   //--- Calculate SL/TP dynamically
   double atr = iATR(symbol, tf, 14);
   if(atr <= 0) atr = pipScale * 30;  // Fallback default

   double slDistance = atr * 1.5;     // SL = 1.5x ATR
   double tpDistance = atr * 3.0;     // TP = 3x ATR

   //--- Validate broker min stop distance
   double minStop = 0;
   if(SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) > 0)
      minStop = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   else if(SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) > 0)
      minStop = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   else
      minStop = atr * 0.5;

   if(slDistance < minStop) slDistance = minStop;
   if(tpDistance < minStop) tpDistance = minStop * 2;

   //--- Final price calculation
   double sl = (type == ORDER_TYPE_BUY) ? price - slDistance : price + slDistance;
   double tp = (type == ORDER_TYPE_BUY) ? price + tpDistance : price - tpDistance;

   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   //--- Trade execution
   if(trade.PositionOpen(symbol, type, lotSize, price, sl, tp, "Scalp-Mode"))
   {
      PrintFormat("%s %s | Lot: %.2f | SL: %.5f | TP: %.5f | ATR: %.5f",
                  EnumToString(type), symbol, lotSize, sl, tp, atr);
   }
   else
   {
      int err = GetLastError();
      PrintFormat("Trade failed on %s | Error %d: %s",
                  symbol, err, GetLastError());
      ResetLastError();
   }
}

//+------------------------------------------------------------------+
//| Manage Scalping Trades                                          |
//+------------------------------------------------------------------+
void ManageScalpTrades(string symbol)
{
   // Loop through all open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      string posSymbol = PositionGetString(POSITION_SYMBOL);
      if(posSymbol != symbol) continue; // only manage current symbol

      string posComment = PositionGetString(POSITION_COMMENT);
      if(posComment != "Scalp-Mode") continue; // only manage scalp trades

      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double stopLoss   = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      double volume     = PositionGetDouble(POSITION_VOLUME);
      double currentPrice = (posType == POSITION_TYPE_BUY)
                            ? SymbolInfoDouble(symbol, SYMBOL_BID)
                            : SymbolInfoDouble(symbol, SYMBOL_ASK);

      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      // Calculate 1R (initial risk distance)
      double initialRisk = MathAbs(entryPrice - stopLoss);
      if(initialRisk <= 0) continue;

      double currentProfitDist = MathAbs(currentPrice - entryPrice);

      // Once price moves 1R in favor, move SL to breakeven
      if(currentProfitDist >= initialRisk && stopLoss != entryPrice)
      {
         double newSL = entryPrice;

         if(posType == POSITION_TYPE_BUY)
            trade.PositionModify(symbol, NormalizeDouble(newSL, digits), takeProfit);
         else if(posType == POSITION_TYPE_SELL)
            trade.PositionModify(symbol, NormalizeDouble(newSL, digits), takeProfit);

         PrintFormat("%s %s moved SL to breakeven (%.5f)", 
                     EnumToString(posType), symbol, newSL);
      }

      // Once price moves beyond 1.5R, trail SL by half of open profit
      if(currentProfitDist >= 1.5 * initialRisk)
      {
         double newSL;
         if(posType == POSITION_TYPE_BUY)
            newSL = currentPrice - (currentProfitDist / 2.0);
         else
            newSL = currentPrice + (currentProfitDist / 2.0);

         // Ensure SL is not behind breakeven
         if((posType == POSITION_TYPE_BUY && newSL > stopLoss && newSL < currentPrice) ||
            (posType == POSITION_TYPE_SELL && newSL < stopLoss && newSL > currentPrice))
         {
            trade.PositionModify(symbol, NormalizeDouble(newSL, digits), takeProfit);
            PrintFormat("Trailing SL updated for %s %s | New SL: %.5f | Current: %.5f",
                        EnumToString(posType), symbol, newSL, currentPrice);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage Swing Trades                                             |
//+------------------------------------------------------------------+
void ManageSwingTrades(string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         int type = (int)PositionGetInteger(POSITION_TYPE);
         
         // Swing trailing stop based on recent swing
         if(SwingTrailingStop > 0)
         {
            double newSl = CalculateSwingTrailingStop(symbol, type, SwingTimeframe);
            if(newSl > 0)
            {
               double currentSl = PositionGetDouble(POSITION_SL);
               if((type == POSITION_TYPE_BUY && newSl > currentSl) || 
                  (type == POSITION_TYPE_SELL && newSl < currentSl))
               {
                  trade.PositionModify(ticket, newSl, PositionGetDouble(POSITION_TP));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Swing Trailing Stop                                   |
//+------------------------------------------------------------------+
double CalculateSwingTrailingStop(string symbol, int type, ENUM_TIMEFRAMES tf)
{
   int lookback = 10;
   double pipSize = GetPipSize(symbol);
   double buffer = 10 * pipSize;
   
   if(type == POSITION_TYPE_BUY)
   {
      int swingLowBar = iLowest(symbol, tf, MODE_LOW, lookback, 1);
      if(swingLowBar != -1)
      {
         return iLow(symbol, tf, swingLowBar) - buffer;
      }
   }
   else if(type == POSITION_TYPE_SELL)
   {
      int swingHighBar = iHighest(symbol, tf, MODE_HIGH, lookback, 1);
      if(swingHighBar != -1)
      {
         return iHigh(symbol, tf, swingHighBar) + buffer;
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Utility Functions                                               |
//+------------------------------------------------------------------+
int CountOpenPositions(string symbol)
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         count++;
   }
   return count;
}

double GetPipSize(string symbol)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return (digits == 3 || digits == 5) ? point * 10 : point;
}

void SplitString(string inputString, string separator, string &result[])
{
   string split[];
   int count = StringSplit(inputString, StringGetCharacter(separator, 0), split);
   ArrayResize(result, count);
   for(int i = 0; i < count; i++)
      result[i] = split[i];
}

//+------------------------------------------------------------------+
//| Dashboard Functions                                             |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   string dashboardText = "";
   string newLine = "\n";
   
   dashboardText += "=== MULTI-PAIR TRADING EA ===" + newLine;
   dashboardText += "Trading Mode: " + EnumToString(TradeMode) + newLine;
   dashboardText += "Active Pairs: " + IntegerToString(TotalPairs) + newLine;
   dashboardText += "Account Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + newLine;
   dashboardText += "=================================" + newLine;
   
   // Show status for each pair
   for(int i = 0; i < TotalPairs; i++)
   {
      string symbol = SymbolList[i];
      int positions = CountOpenPositions(symbol);
      
      dashboardText += symbol + ":" + newLine;
      dashboardText += "  Positions: " + IntegerToString(positions) + newLine;
      
      // Add signal status with detailed info
      if(TradeMode == MODE_SCALP)
      {
         //bool signal = ScalpModeHandler(symbol);
         double emaFast = iMA(symbol, ScalpTimeframe, Scalp_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
         double emaSlow = iMA(symbol, ScalpTimeframe, Scalp_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
         double rsi = iRSI(symbol, ScalpTimeframe, Scalp_RSI_Period, PRICE_CLOSE);
         
         //dashboardText += "  Scalp Signal: " + (signal ? "ACTIVE" : "INACTIVE") + newLine;
         dashboardText += "  EMA Fast: " + DoubleToString(emaFast, 5) + newLine;
         dashboardText += "  EMA Slow: " + DoubleToString(emaSlow, 5) + newLine;
         dashboardText += "  RSI: " + DoubleToString(rsi, 1) + newLine;
      }
      else
      {
         bool signal = SwingSignal(symbol);
         dashboardText += "  Swing Signal: " + (signal ? "ACTIVE" : "INACTIVE") + newLine;
      }
      dashboardText += newLine;
   }
   
   Comment(dashboardText);
}
//+------------------------------------------------------------------+
