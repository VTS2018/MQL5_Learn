//+------------------------------------------------------------------+
//|                                               AutoGammaDelta.mq5 |
//|                        GIT under Copyright 2025, MetaQuotes Ltd. |
//|                     https://www.mql5.com/en/users/johnhlomohang/ |
//+------------------------------------------------------------------+
#property copyright "GIT under Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/johnhlomohang/"
#property version   "1.00"
#include <Trade\Trade.mqh>
#include <Math\Stat\Normal.mqh>
// https://www.mql5.com/en/articles/20287
//--- Input Parameters
input double   StrikePrice     = 5000.0;    // Option strike price
input double   Volatility      = 0.1691;    // Annual volatility (16.91%)
input double   RiskFreeRate    = 0.04;      // Risk-free interest rate
input double   DividendYield   = 0.02;      // Dividend yield
input double   OptionPosition  = 1.0;       // Option contract size (positive long, negative short)
input double   DeltaThreshold  = 0.10;      // Delta hedge threshold
input double   GammaThreshold  = 0.0001;    // Gamma hedge threshold  
input double   LotSize         = 0.1;       // Trading lot size for underlying
input int      StopLoss        = 50;        // Hedge Stop Loss (points)
input int      TakeProfit      = 30;        // Hedge Take Profit (points)
input int      HedgeFrequency  = 1;         // Hedge check frequency (minutes)
input bool     EnableTrading   = true;      // Enable actual trading

//--- Global Variables
CTrade         trade;
double         currentDelta, currentGamma;
double         portfolioDelta, targetDelta;
datetime       lastHedgeTime;
int            currentHedgeFrequency;

//+------------------------------------------------------------------+
//| Black-Scholes Greeks Calculator                                  |
//+------------------------------------------------------------------+
double NormalCDF(double x)
{
   double a1=0.254829592, a2=-0.284496736, a3=1.421413741;
   double a4=-1.453152027, a5=1.061405429, p=0.3275911;
   int sign = 1;
   if(x < 0) { sign = -1; x = -x; }
   double t = 1.0/(1.0 + p*x);
   double y = 1.0 - (((((a5*t + a4)*t) + a3)*t + a2)*t + a1)*t*MathExp(-x*x);
   return 0.5*(1.0 + sign*y);
}

double NormalPDF(double x)
{
   return MathExp(-0.5*x*x)/MathSqrt(2.0*M_PI);
}

void BS_d1d2(double S, double K, double sigma, double T, double r, double q, double &d1, double &d2)
{
   if(T <= 0 || sigma <= 0) { d1 = d2 = 0.0; return; }
   double sqt = sigma * MathSqrt(T);
   d1 = (MathLog(S/K) + (r - q + 0.5*sigma*sigma)*T) / sqt;
   d2 = d1 - sqt;
}

double CalculateDelta(double S, double K, double sigma, double T, double r, double q)
{
   if(T <= 0) return (S > K) ? 1.0 : 0.0;
   double d1, d2;
   BS_d1d2(S, K, sigma, T, r, q, d1, d2);
   return MathExp(-q*T) * NormalCDF(d1);
}

double CalculateGamma(double S, double K, double sigma, double T, double r, double q)
{
   if(T <= 0 || sigma <= 0) return 0.0;
   double d1, d2;
   BS_d1d2(S, K, sigma, T, r, q, d1, d2);
   double pdf = NormalPDF(d1);
   return (pdf * MathExp(-q*T)) / (S * sigma * MathSqrt(T));
}

//+------------------------------------------------------------------+
//| Time to Expiry Calculator                                        |
//+------------------------------------------------------------------+
double TimeToExpiry()
{
   datetime expiry = D'2025.12.31 23:59:59';
   datetime current = TimeCurrent();
   double days = (expiry - current) / (60.0 * 60.0 * 24.0);
   return MathMax(days / 365.0, 0.0);
}

//+------------------------------------------------------------------+
//| Position Management Functions                                    |
//+------------------------------------------------------------------+
double GetUnderlyingPosition()
{
   double position = 0.0;
   int total = PositionsTotal();
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         long type = PositionGetInteger(POSITION_TYPE);
         double volume = PositionGetDouble(POSITION_VOLUME);
         
         if(type == POSITION_TYPE_BUY)
            position += volume;
         else if(type == POSITION_TYPE_SELL)
            position -= volume;
      }
   }
   return position;
}

double CalculatePortfolioDelta()
{
   double underlyingPos = GetUnderlyingPosition();
   double optionDelta = currentDelta * OptionPosition;
   return underlyingPos + optionDelta;
}

//+------------------------------------------------------------------+
//| Gamma Scalping Logic                                           |
//+------------------------------------------------------------------+
int CalculateDynamicFrequency()
{
   // Adjust frequency based on gamma levels
   if(currentGamma > GammaThreshold * 2)
      return 1;  // High gamma - check every minute
   else if(currentGamma > GammaThreshold)
      return HedgeFrequency; // Medium gamma - use base frequency
   else
      return 5;  // Low gamma - check every 5 minutes
}

//+------------------------------------------------------------------+
//| Execute trade with risk parameters                               |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE tradeType, string symbol)
{
   if(!EnableTrading) 
   {
      Print("DEMO: ", EnumToString(tradeType), " ", LotSize, " lots");
      return;
   }
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double price = (tradeType == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) :
                                                SymbolInfoDouble(symbol, SYMBOL_BID);

   double sl_distance = StopLoss * point * 10; // Convert points to price
   double tp_distance = TakeProfit * point * 10;
   
   double sl = (tradeType == ORDER_TYPE_BUY) ? price - sl_distance : price + sl_distance;
   double tp = (tradeType == ORDER_TYPE_BUY) ? price + tp_distance : price - tp_distance;

   if(trade.PositionOpen(symbol, tradeType, LotSize, price, sl, tp, "GammaDelta Hedge"))
   {
      Print("TRADE EXECUTED: ", EnumToString(tradeType), 
            " Lots: ", LotSize, 
            " Price: ", price,
            " SL: ", sl, 
            " TP: ", tp);
   }
   else
   {
      Print("TRADE FAILED: ", EnumToString(tradeType), 
            " Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Gamma-Based Trading Strategy                                   |
//+------------------------------------------------------------------+
void ExecuteGammaStrategy()
{
   double S = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Strategy 1: Gamma Scalping - Trade when gamma indicates high sensitivity
   if(currentGamma > GammaThreshold * 1.5)
   {
      Print("High Gamma detected: ", currentGamma, " - Gamma scalping opportunity");
      
      // If gamma is high and we're near the strike, consider directional trades
      if(MathAbs(S - StrikePrice) < (StrikePrice * 0.02)) // Within 2% of strike
      {
         if(currentDelta > 0.6) 
         {
            Print("Gamma Scalp: BUY signal (High Delta: ", currentDelta, ")");
            ExecuteTrade(ORDER_TYPE_BUY, _Symbol);
         }
         else if(currentDelta < 0.4)
         {
            Print("Gamma Scalp: SELL signal (Low Delta: ", currentDelta, ")");
            ExecuteTrade(ORDER_TYPE_SELL, _Symbol);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Delta Hedging Engine                                           |
//+------------------------------------------------------------------+
void ExecuteDeltaHedge()
{
   portfolioDelta = CalculatePortfolioDelta();
   targetDelta = 0.0; // Target delta-neutral
  
   double deltaDeviation = MathAbs(portfolioDelta - targetDelta);
   
   Print("Delta Check - Portfolio: ", portfolioDelta, " Deviation: ", deltaDeviation);
   
   if(deltaDeviation > DeltaThreshold)
   {
      // Determine trade direction
      ENUM_ORDER_TYPE orderType;
      if(portfolioDelta > targetDelta)
      {
         orderType = ORDER_TYPE_SELL; // Sell to reduce positive delta
         Print("DELTA HEDGE: SELL to reduce positive delta ", portfolioDelta);
      }
      else
      {
         orderType = ORDER_TYPE_BUY;  // Buy to reduce negative delta
         Print("DELTA HEDGE: BUY to reduce negative delta ", portfolioDelta);
      }
      
      ExecuteTrade(orderType, _Symbol);
   }
}

//+------------------------------------------------------------------+
//| Combined Gamma & Delta Strategy                                |
//+------------------------------------------------------------------+
void ExecuteCombinedStrategy()
{
   double S = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double T = TimeToExpiry();
   
   // Update Greeks
   currentDelta = CalculateDelta(S, StrikePrice, Volatility, T, RiskFreeRate, DividendYield);
   currentGamma = CalculateGamma(S, StrikePrice, Volatility, T, RiskFreeRate, DividendYield);
   
   Print("Strategy Analysis - Price: ", S, " Delta: ", currentDelta, " Gamma: ", currentGamma);
   
   // 1. Execute Delta Hedging (Priority)
   ExecuteDeltaHedge();
   
   // 2. Execute Gamma Strategy (Secondary)
   ExecuteGammaStrategy();
   
   // 3. Time-based opportunities (Near expiry)
   if(T * 365 < 30) // Less than 30 days to expiry
   {
      Print("Near expiry detected: ", T*365, " days - Monitoring for time decay opportunities");
      
      // Consider closing positions or adjusting strategy near expiry
      if(currentGamma > GammaThreshold * 3)
      {
         Print("High Gamma near expiry - Potential for volatility plays");
      }
   }
}

//+------------------------------------------------------------------+
//| Main Expert Advisor Functions                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(12345);
   currentHedgeFrequency = HedgeFrequency;
   
   Print("=== Gamma/Delta Auto Trader Initialized ===");
   Print("Strike: ", StrikePrice, " | Vol: ", Volatility);
   Print("Delta Threshold: ", DeltaThreshold, " | Gamma Threshold: ", GammaThreshold);
   Print("Lot Size: ", LotSize, " | SL: ", StopLoss, " | TP: ", TakeProfit);
   Print("Trading: ", EnableTrading ? "LIVE" : "DEMO");
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Print("Auto Trader Shutdown - Reason: ", reason);
   Comment("");
}

void OnTick()
{
   static datetime lastCheck = 0;
   
   // Update display on every tick
   UpdateGreeksDisplay();
   
   // Execute strategy at dynamic frequency
   if(TimeCurrent() - lastCheck >= currentHedgeFrequency * 60)
   {
      lastCheck = TimeCurrent();
      
      Print("\n=== STRATEGY CYCLE ===");
      Print("Time: ", TimeToString(TimeCurrent()));
      
      // Execute combined gamma/delta strategy
      ExecuteCombinedStrategy();
      
      Print("=== CYCLE COMPLETE ===\n");
   }
}

void OnTrade()
{
   Print("Position Update - Total Positions: ", PositionsTotal());
   portfolioDelta = CalculatePortfolioDelta();
}

//+------------------------------------------------------------------+
//| Monitoring and Reporting                                       |
//+------------------------------------------------------------------+
void UpdateGreeksDisplay()
{
   double S = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double T = TimeToExpiry();
   
   currentDelta = CalculateDelta(S, StrikePrice, Volatility, T, RiskFreeRate, DividendYield);
   currentGamma = CalculateGamma(S, StrikePrice, Volatility, T, RiskFreeRate, DividendYield);
   portfolioDelta = CalculatePortfolioDelta();
   
   currentHedgeFrequency = CalculateDynamicFrequency();
   
   Comment(
      "EU50 Gamma/Delta Auto Trader\n",
      "Price: ", DoubleToString(S, 2), " | Strike: ", StrikePrice, "\n",
      "Option Delta: ", DoubleToString(currentDelta, 4), 
      " | Gamma: ", DoubleToString(currentGamma, 6), "\n",
      "Portfolio Delta: ", DoubleToString(portfolioDelta, 4), 
      " | Target: ", targetDelta, "\n",
      "Hedge Freq: ", currentHedgeFrequency, "min",
      " | Days to Expiry: ", DoubleToString(T*365, 0), "\n",
      "Trades: ", PositionsTotal(), " | Mode: ", EnableTrading ? "LIVE" : "DEMO"
   );
}



