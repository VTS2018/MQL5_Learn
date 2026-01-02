//+------------------------------------------------------------------+
//|                                                       GALEIT.mq5 |
//|                        GIT under Copyright 2025, MetaQuotes Ltd. |
//|                     https://www.mql5.com/en/users/johnhlomohang/ |
//+------------------------------------------------------------------+
#property copyright "GIT under Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/johnhlomohang/"
#property version   "1.00"
// https://www.mql5.com/en/articles/20449

//--- Include Libraries
#include <Trade/Trade.mqh>

//--- Global Variables
CTrade trade;
ulong lastTicket = 0;
int martingaleStep = 0;
double dailyProfit = 0.0;
datetime lastTradeTime = 0;
string tradeSequenceId = "";

//--- Global Variable Names
#define GV_PEAK_EQUITY       "GV_PeakEquity"
#define GV_PAUSE_EA          "GV_EA_Paused"
#define GV_DD_LOCK_LEVEL     "GV_DrawdownLockLevel"
#define GV_CONSEC_LOSSES     "GV_ConsecLosses"
#define GV_TRADE_WINDOW_START "GV_TradeWindowStart"
#define GV_TRADES_IN_WINDOW  "GV_TradesInWindow"

//--- Input Parameters
// Trading Strategy
input int FastMAPeriod = 10;
input int SlowMAPeriod = 50;

// Martingale & Money Management
input double InitialLotSize = 0.01;
input double LotMultiplier = 2.0;
input int MaxMartingaleSteps = 5;
input double RiskPercent = 2.0;

// Volatility Management (ATR)
input int ATR_Period = 14;
input double ATR_SL_Factor = 1.5;
input double ATR_TP_Factor = 1.0;

// Account Protection
input bool UseEquityStop = true;
input double EquityStopPercent = 8.0;
input bool UseDailyLossLimit = true;
input double DailyLossPercent = 5.0;
input bool UseMaxSpreadFilter = true;
input int MaxSpreadPoints = 5;

input group "Trailing Stop Parameters"
input bool UseTrailingStop = true;       
input int BreakEvenAtPips = 500;          
input int TrailStartAtPips = 600;        
input int TrailStepPips = 100;          

// Circuit Breaker Settings
input int MaxConsecutiveLosses = 3;
input double CircuitBreakerDD = 15.0;

// Throttle Settings
input int MaxTradesPerHour = 10;
input int ThrottleWindowSeconds = 3600;

// Recovery Settings
input double RecoveryRiskReduction = 0.5;
input double ResumeEquityPercent = 90.0;
input int ResumeAfterSeconds = 86400;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("GaleIT EA Initialized");
   trade.SetExpertMagicNumber(12345);
   tradeSequenceId = GenerateTradeSequenceId();
   
   // Initialize all protection systems
   InitAccountShields();
   InitFailSafes();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("GaleIT EA Deinitialized - Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update protection systems
   UpdatePeakEquity();
   TryResumeFromRecovery();
   
   // Check if trading is allowed
   if(!IsTradingAllowed()) return;
   
   // Check all safety limits
   if(!CheckSafetyLimits()) return;
   
   // Manage existing positions
   ManageExistingPositions();
   
   // Check for new trading opportunities
   if(IsNewBar())
   {
      CheckForNewTrade();
   }
   
   ManageOpenTrades();
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   // Check if EA is paused by protection systems
   if(IsEAProtectedPaused()) return false;
   
   // Check circuit breaker
   if(CheckCircuitBreaker(MaxConsecutiveLosses, CircuitBreakerDD)) return false;
   
   // Check trade throttle
   if(!ThrottleAllowNewTrade(MaxTradesPerHour, ThrottleWindowSeconds)) return false;
   
   // Check spread filter
   if(UseMaxSpreadFilter)
   {
      long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > MaxSpreadPoints * 10) return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check safety limits                                              |
//+------------------------------------------------------------------+
bool CheckSafetyLimits()
{
   // Equity Stop protection
   if(UseEquityStop)
   {
      double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equityDropPercent = (1 - (currentEquity / currentBalance)) * 100;
      
      if(equityDropPercent >= EquityStopPercent)
      {
         Print("Equity stop triggered: ", equityDropPercent, "%");
         CloseAllPositions();
         ExpertRemove();
         return false;
      }
   }
   
   // Daily loss limit
   if(UseDailyLossLimit)
   {
      double dailyLossLimit = (DailyLossPercent / 100) * AccountInfoDouble(ACCOUNT_BALANCE);
      if(dailyProfit <= -dailyLossLimit)
      {
         Print("Daily loss limit reached: ", dailyProfit);
         CloseAllPositions();
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check for new trade opportunity                                  |
//+------------------------------------------------------------------+
void CheckForNewTrade()
{
   if(PositionsTotal() > 0) return;
   
   int signal = GetTradingSignal();
   if(signal != 0)
   {
      double lotSize = CalculateLotSize();
      double sl, tp;
      CalculateSLTP(signal, sl, tp);
      
      if(OpenPosition(signal, lotSize, sl, tp))
      {
         lastTradeTime = TimeCurrent();
         martingaleStep = 0;
         tradeSequenceId = GenerateTradeSequenceId();
      }
   }
}

//+------------------------------------------------------------------+
//| Get trading signal                                               |
//+------------------------------------------------------------------+
int GetTradingSignal()
{
   int fastMA = iMA(_Symbol, _Period, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   int slowMA = iMA(_Symbol, _Period, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   if(fastMA == INVALID_HANDLE || slowMA == INVALID_HANDLE) return 0;
   
   double fastMAValues[], slowMAValues[];
   ArraySetAsSeries(fastMAValues, true);
   ArraySetAsSeries(slowMAValues, true);
   
   if(CopyBuffer(fastMA, 0, 0, 3, fastMAValues) < 3) 
   {
      IndicatorRelease(fastMA);
      IndicatorRelease(slowMA);
      return 0;
   }
   if(CopyBuffer(slowMA, 0, 0, 3, slowMAValues) < 3) 
   {
      IndicatorRelease(fastMA);
      IndicatorRelease(slowMA);
      return 0;
   }
   
   double currentFast = fastMAValues[0];
   double currentSlow = slowMAValues[0];
   double prevFast = fastMAValues[1];
   double prevSlow = slowMAValues[1];
   
   int signal = 0;
   if(prevFast <= prevSlow && currentFast > currentSlow)
      signal = 1;
   else if(prevFast >= prevSlow && currentFast < currentSlow)
      signal = -1;
   
   IndicatorRelease(fastMA);
   IndicatorRelease(slowMA);
   
   return signal;
}

//+------------------------------------------------------------------+
//| Calculate lot size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   if(martingaleStep == 0)
   {
      // Use risk-based lot sizing for first trade
      double atr = GetATR(_Symbol, _Period, ATR_Period);
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double slPrice = currentPrice - (atr * ATR_SL_Factor);
      
      return CalculateLotFromRisk(_Symbol, currentPrice, slPrice, RiskPercent);
   }
   else
   {
      // Martingale recovery trade
      return NormalizeDouble(InitialLotSize * MathPow(LotMultiplier, martingaleStep), 2);
   }
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss and Take Profit                              |
//+------------------------------------------------------------------+
void CalculateSLTP(int signal, double &sl, double &tp)
{
   double atr = GetATR(_Symbol, _Period, ATR_Period);
   double currentPrice = signal > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(signal > 0)
   {
      sl = currentPrice - (atr * ATR_SL_Factor);
      tp = currentPrice + (atr * ATR_TP_Factor);
   }
   else
   {
      sl = currentPrice + (atr * ATR_SL_Factor);
      tp = currentPrice - (atr * ATR_TP_Factor);
   }
   
   // Validate distances
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minDist = 100 * point;
   
   if(signal > 0)
   {
      if(currentPrice - sl < minDist) sl = currentPrice - minDist;
      if(tp - currentPrice < minDist) tp = currentPrice + minDist;
   }
   else
   {
      if(sl - currentPrice < minDist) sl = currentPrice + minDist;
      if(currentPrice - tp < minDist) tp = currentPrice - minDist;
   }
   
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
}

//+------------------------------------------------------------------+
//| Open position                                                    |
//+------------------------------------------------------------------+
bool OpenPosition(int signal, double lotSize, double sl, double tp)
{
   double price = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   ENUM_ORDER_TYPE orderType = (signal > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   // Use protective execution
   return ExecuteProtectedOrder(_Symbol, orderType, lotSize, price, sl);
}

//+------------------------------------------------------------------+
//| Manage existing positions                                        |
//+------------------------------------------------------------------+
void ManageExistingPositions()
{
   int totalPositions = PositionsTotal();
   
   for(int i = totalPositions - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_COMMENT) == tradeSequenceId)
      {
         double currentProfit = PositionGetDouble(POSITION_PROFIT);
         
         if(PositionGetInteger(POSITION_TIME_UPDATE) > lastTradeTime)
         {
            bool wasProfit = (currentProfit > 0);
            OnTradeClosed(wasProfit);
            
            if(!wasProfit)
            {
               martingaleStep++;
               if(martingaleStep > MaxMartingaleSteps)
               {
                  Print("Max martingale steps reached. Activating recovery protocol.");
                  double reducedRisk = RiskPercent;
                  RecoveryProtocol(reducedRisk, RecoveryRiskReduction, ResumeEquityPercent, ResumeAfterSeconds);
                  martingaleStep = 0;
               }
            }
            else
            {
               martingaleStep = 0;
            }
            
            dailyProfit += currentProfit;
            lastTradeTime = TimeCurrent();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| DYNAMIC EXPOSURE CONTROL FUNCTIONS                              |
//+------------------------------------------------------------------+
double GetATR(string symbol, ENUM_TIMEFRAMES tf, int period=14)
{
   int handle = iATR(symbol, tf, period);
   if(handle == INVALID_HANDLE) return(0.0);
   double buffer[];
   if(CopyBuffer(handle, 0, 0, 1, buffer) != 1)
   {
      IndicatorRelease(handle);
      return(0.0);
   }
   IndicatorRelease(handle);
   return(buffer[0]);
}

double CalculateLotFromRisk(string symbol, double entry_price, double sl_price, double risk_percent)
{
   if(risk_percent <= 0) return(InitialLotSize);
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_amount = equity * (risk_percent / 100.0);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double sl_points = MathMax(1.0, MathAbs(entry_price - sl_price) / point);
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tick_value <= 0 || tick_size <= 0) return(InitialLotSize);
   
   double value_per_point_per_lot = tick_value / (tick_size / point);
   double risk_per_lot = sl_points * value_per_point_per_lot;
   if(risk_per_lot <= 0.0) return(InitialLotSize);
   
   double volume = risk_amount / risk_per_lot;
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0) step = 0.01;
   
   double normalized = MathFloor(volume / step) * step;
   if(normalized < minLot) normalized = minLot;
   if(normalized > maxLot) normalized = maxLot;
   
   return(NormalizeDouble(normalized, (int)MathMax(0, (int)(-MathLog10(step)))));
}

//+------------------------------------------------------------------+
//| STRUCTURAL ACCOUNT SHIELDS                                      |
//+------------------------------------------------------------------+
void InitAccountShields()
{
   if(!GlobalVariableCheck(GV_PEAK_EQUITY))
      GlobalVariableSet(GV_PEAK_EQUITY, AccountInfoDouble(ACCOUNT_EQUITY));
   if(!GlobalVariableCheck(GV_PAUSE_EA))
      GlobalVariableSet(GV_PAUSE_EA, 0.0);
   if(!GlobalVariableCheck(GV_DD_LOCK_LEVEL))
      GlobalVariableSet(GV_DD_LOCK_LEVEL, 0.0);
}

void UpdatePeakEquity()
{
   double current = AccountInfoDouble(ACCOUNT_EQUITY);
   double peak = GlobalVariableGet(GV_PEAK_EQUITY);
   if(current > peak) GlobalVariableSet(GV_PEAK_EQUITY, current);
}

double GetCurrentDrawdownPercent()
{
   double peak = GlobalVariableGet(GV_PEAK_EQUITY);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(peak <= 0) return(0.0);
   return ((peak - equity) / peak) * 100.0;
}

bool IsEAProtectedPaused()
{
   return (GlobalVariableGet(GV_PAUSE_EA) != 0.0);
}

//+------------------------------------------------------------------+
//| TRADE-LEVEL REINFORCEMENT                                       |
//+------------------------------------------------------------------+
bool ExecuteProtectedOrder(string symbol, ENUM_ORDER_TYPE type, double volume, double price, double sl_price)
{
   if(IsEAProtectedPaused()) return false;
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double allowableDeviationPoints = 10;
   
   if(type == ORDER_TYPE_BUY)
   {
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(MathAbs(ask - price) / point > allowableDeviationPoints) return false;
   }
   else
   {
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(MathAbs(bid - price) / point > allowableDeviationPoints) return false;
   }
   
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   if(volume < minLot || volume > maxLot) return false;
   
   bool ok = false;
   if(type == ORDER_TYPE_BUY) 
      ok = trade.Buy(volume, symbol, price, sl_price, 0, NULL);
   else if(type == ORDER_TYPE_SELL) 
      ok = trade.Sell(volume, symbol, price, sl_price, 0, NULL);
   
   if(!ok) PrintFormat("Order failed: %s (err %d)", symbol, GetLastError());
   return ok;
}

//+------------------------------------------------------------------+
//| SYSTEMIC FAIL-SAFES                                             |
//+------------------------------------------------------------------+
void InitFailSafes()
{
   if(!GlobalVariableCheck(GV_CONSEC_LOSSES)) GlobalVariableSet(GV_CONSEC_LOSSES, 0);
   if(!GlobalVariableCheck(GV_TRADE_WINDOW_START)) GlobalVariableSet(GV_TRADE_WINDOW_START, TimeCurrent());
   if(!GlobalVariableCheck(GV_TRADES_IN_WINDOW)) GlobalVariableSet(GV_TRADES_IN_WINDOW, 0);
}

void OnTradeClosed(bool wasProfit)
{
   if(wasProfit) 
      GlobalVariableSet(GV_CONSEC_LOSSES, 0);
   else 
      GlobalVariableSet(GV_CONSEC_LOSSES, GlobalVariableGet(GV_CONSEC_LOSSES) + 1);
   
   GlobalVariableSet(GV_TRADES_IN_WINDOW, GlobalVariableGet(GV_TRADES_IN_WINDOW) + 1);
}

bool CheckCircuitBreaker(int maxConsecLosses, double drawdownThresholdPercent)
{
   int consec = (int)GlobalVariableGet(GV_CONSEC_LOSSES);
   double dd = GetCurrentDrawdownPercent();
   if(consec >= maxConsecLosses || dd >= drawdownThresholdPercent)
   {
      GlobalVariableSet(GV_PAUSE_EA, 1.0);
      Print("Circuit breaker engaged: consec=", consec, " dd=", dd);
      return true;
   }
   return false;
}

bool ThrottleAllowNewTrade(int maxTrades, int windowSeconds)
{
   datetime start = (datetime)GlobalVariableGet(GV_TRADE_WINDOW_START);
   int count = (int)GlobalVariableGet(GV_TRADES_IN_WINDOW);
   datetime now = TimeCurrent();
   
   if((now - start) > windowSeconds)
   {
      GlobalVariableSet(GV_TRADE_WINDOW_START, now);
      GlobalVariableSet(GV_TRADES_IN_WINDOW, 0);
      count = 0;
   }
   return (count < maxTrades);
}

void RecoveryProtocol(double &riskPercent, double reductionFactor, double resumeEquityPercentOfPeak, int resumeAfterSeconds)
{
   riskPercent *= reductionFactor;
   GlobalVariableSet(GV_PAUSE_EA, 1.0);
   GlobalVariableSet("GV_RecoveryResumeTime", TimeCurrent() + resumeAfterSeconds);
   GlobalVariableSet("GV_ResumeEquityPercent", resumeEquityPercentOfPeak);
}

bool TryResumeFromRecovery()
{
   double resumeTime = GlobalVariableGet("GV_RecoveryResumeTime");
   if(resumeTime == 0) return false;
   if(TimeCurrent() < (datetime)resumeTime) return false;
   
   double resumePercent = GlobalVariableGet("GV_ResumeEquityPercent");
   if(resumePercent <= 0)
   {
      GlobalVariableSet(GV_PAUSE_EA, 0.0);
      GlobalVariableSet("GV_RecoveryResumeTime", 0);
      return true;
   }
   
   double peak = GlobalVariableGet(GV_PEAK_EQUITY);
   double needed = peak * (resumePercent / 100.0);
   if(AccountInfoDouble(ACCOUNT_EQUITY) >= needed)
   {
      GlobalVariableSet(GV_PAUSE_EA, 0.0);
      GlobalVariableSet("GV_RecoveryResumeTime", 0);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0) trade.PositionClose(ticket);
   }
}

bool IsNewBar()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

string GenerateTradeSequenceId()
{
   return "SEQ_" + IntegerToString(TimeCurrent()) + "_" + IntegerToString(MathRand() % 1000);
}

//+------------------------------------------------------------------+
//| Trailing stop function - FIXED VERSION                          |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   if(!UseTrailingStop) return;

   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(!PositionSelectByTicket(ticket)) continue;

      // Only manage positions for this symbol
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      // Only manage positions opened by this EA
      if(PositionGetInteger(POSITION_MAGIC) != 12345) continue;

      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
      double current_sl = PositionGetDouble(POSITION_SL);
      double current_tp = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Get broker requirements
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double stopLevelPrice = stops_level * point;
      
      // Get current market prices
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      // Calculate current profit in price units
      double profit_price = 0;
      if(pos_type == POSITION_TYPE_BUY)
         profit_price = bid - open_price;
      else if(pos_type == POSITION_TYPE_SELL)
         profit_price = open_price - ask;
      
      // Convert profit to pips
      double pip_value = PipsToPrice(1);
      double profit_pips = profit_price / pip_value;
      
      if(profit_pips <= 0) continue;

      // -------------------------
      // 1) Move to breakeven
      // -------------------------
      if(profit_pips >= BreakEvenAtPips)
      {
         double breakeven = open_price;
         // Small adjustment for spread
         if(pos_type == POSITION_TYPE_BUY)
            breakeven += point;
         else
            breakeven -= point;
         
         breakeven = NormalizeDouble(breakeven, digits);

         // For BUY positions: SL must be below bid by at least stops_level
         if(pos_type == POSITION_TYPE_BUY)
         {
            if((bid - breakeven) >= stopLevelPrice)
            {
               if(breakeven > current_sl || current_sl == 0)
               {
                  // FIX: Ensure TP is valid - if TP is 0, use a reasonable value
                  double new_tp = (current_tp == 0) ? CalculateReasonableTP(pos_type, open_price) : current_tp;
                  new_tp = NormalizeDouble(new_tp, digits);
                  
                  if(!trade.PositionModify(ticket, breakeven, new_tp))
                     PrintFormat("PositionModify failed (BE Buy) ticket %I64u error %d - SL: %.2f, TP: %.2f", 
                                ticket, GetLastError(), breakeven, new_tp);
               }
            }
         }
         // For SELL positions: SL must be above ask by at least stops_level
         else if(pos_type == POSITION_TYPE_SELL)
         {
            if((breakeven - ask) >= stopLevelPrice)
            {
               if(current_sl == 0 || breakeven < current_sl)
               {
                  // FIX: Ensure TP is valid - if TP is 0, use a reasonable value
                  double new_tp = (current_tp == 0) ? CalculateReasonableTP(pos_type, open_price) : current_tp;
                  new_tp = NormalizeDouble(new_tp, digits);
                  
                  if(!trade.PositionModify(ticket, breakeven, new_tp))
                     PrintFormat("PositionModify failed (BE Sell) ticket %I64u error %d - SL: %.2f, TP: %.2f", 
                                ticket, GetLastError(), breakeven, new_tp);
               }
            }
         }
      }

      // -------------------------
      // 2) Trailing stop
      // -------------------------
      if(profit_pips >= TrailStartAtPips)
      {
         double extra_pips = profit_pips - TrailStartAtPips;
         int step_count = (int)(extra_pips / TrailStepPips);
         
         double new_sl_price = 0;
         bool should_modify = false;
         
         if(pos_type == POSITION_TYPE_BUY)
         {
            // Calculate new SL based on open price + trail offset
            new_sl_price = open_price + PipsToPrice((int)(TrailStartAtPips + step_count * TrailStepPips));
            new_sl_price = NormalizeDouble(new_sl_price, digits);
            
            // Ensure minimum distance from current price
            if((bid - new_sl_price) < stopLevelPrice)
               new_sl_price = bid - stopLevelPrice - point;
            
            if(new_sl_price > current_sl || current_sl == 0)
               should_modify = true;
         }
         else if(pos_type == POSITION_TYPE_SELL)
         {
            // Calculate new SL based on open price - trail offset
            new_sl_price = open_price - PipsToPrice((int)(TrailStartAtPips + step_count * TrailStepPips));
            new_sl_price = NormalizeDouble(new_sl_price, digits);
            
            // Ensure minimum distance from current price
            if((new_sl_price - ask) < stopLevelPrice)
               new_sl_price = ask + stopLevelPrice + point;
            
            if(current_sl == 0 || new_sl_price < current_sl)
               should_modify = true;
         }
         
         if(should_modify && new_sl_price > 0)
         {
            // FIX: Ensure TP is valid - if TP is 0, use a reasonable value
            double new_tp = (current_tp == 0) ? CalculateReasonableTP(pos_type, open_price) : current_tp;
            new_tp = NormalizeDouble(new_tp, digits);
            
            // Final validation before modifying
            if(IsValidStopLevel(pos_type, new_sl_price, new_tp, bid, ask))
            {
               if(!trade.PositionModify(ticket, new_sl_price, new_tp))
                  PrintFormat("PositionModify failed (Trail) ticket %I64u error %d - SL: %.2f, TP: %.2f", 
                             ticket, GetLastError(), new_sl_price, new_tp);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate reasonable TP if none is set                          |
//+------------------------------------------------------------------+
double CalculateReasonableTP(ENUM_POSITION_TYPE pos_type, double open_price)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double atr = GetATR(_Symbol, _Period, 14);
   
   if(atr <= 0) atr = 100 * point; // Fallback if ATR fails
   
   if(pos_type == POSITION_TYPE_BUY)
      return open_price + (atr * 2.0); // 2x ATR for TP
   else
      return open_price - (atr * 2.0); // 2x ATR for TP
}

//+------------------------------------------------------------------+
//| Check if stop levels are valid                                  |
//+------------------------------------------------------------------+
bool IsValidStopLevel(ENUM_POSITION_TYPE pos_type, double sl, double tp, double bid, double ask)
{
   if(sl <= 0 || tp <= 0) return false;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_distance = stops_level * point;
   
   if(pos_type == POSITION_TYPE_BUY)
   {
      // For BUY: SL must be below bid by at least stops_level
      if(sl >= bid - min_distance) return false;
      // TP must be above ask by at least stops_level
      if(tp <= ask + min_distance) return false;
      // SL must be below TP
      if(sl >= tp) return false;
   }
   else if(pos_type == POSITION_TYPE_SELL)
   {
      // For SELL: SL must be above ask by at least stops_level
      if(sl <= ask + min_distance) return false;
      // TP must be below bid by at least stops_level
      if(tp >= bid - min_distance) return false;
      // SL must be above TP
      if(sl <= tp) return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Convert pips to price                                           |
//+------------------------------------------------------------------+
double PipsToPrice(int pips)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   return(pips * pip);
}

//+------------------------------------------------------------------+