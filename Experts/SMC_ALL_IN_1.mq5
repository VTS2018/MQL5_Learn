//+------------------------------------------------------------------+
//|                                                 SMC_ALL_IN_1.mq5 |
//|                        GIT under Copyright 2025, MetaQuotes Ltd. |
//|                     https://www.mql5.com/en/users/johnhlomohang/ |
//+------------------------------------------------------------------+
#property copyright "GIT under Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/johnhlomohang/"
#property version   "1.01"
#property description "Unified SMC: FVG + Order Blocks + BOS. Detect + Draw + Trade."

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

CTrade         trade;
CPositionInfo  pos;

enum ENUM_STRATEGY
{
   STRAT_OB,         // Use Order Blocks Only
   STRAT_FVG,        // Use FVGs Only
   STRAT_BOS,        // Use Break of Structure Only
   STRAT_AUTO        // Auto (All SMC Concepts)
};
enum SWING_TYPE{
   SWING_OB,
   SWING_BOS,
};
//----------------------------- Inputs ------------------------------//
input ENUM_STRATEGY TradeStrategy   = STRAT_AUTO;
input double        In_Lot          = 0.02;
input double        StopLoss        = 3500;    // points
input double        TakeProfit      = 7500;    // points
input long          MagicNumber     = 76543;

input int           SwingPeriod     = 5;      // bars each side to confirm swing
input int           SwingProbeBar   = 5;      // bar index we test for swings (>=SwingPeriod)
input double        Fib_Trade_lvls  = 61.8;   // OB retrace must reach this %
input bool          DrawBOSLines    = true;

input int           FVG_MinPoints   = 3;      // minimal gap in points
input int           FVG_ScanBars    = 20;    // how many bars to scan for FVGs
input bool          FVG_TradeAtEQ   = true;   // trade at 50% of the gap (EQ)
input bool          OneTradePerBar  = true;

//---------------------------- Colors -------------------------------//
#define BullOB   clrLime
#define BearOB   clrRed
#define BullFVG  clrPaleGreen
#define BearFVG  clrMistyRose
#define BOSBull  clrDodgerBlue
#define BOSBear  clrTomato

//---------------------------- Globals ------------------------------//
double   Bid, Ask;
datetime g_lastBarTime = 0;

// OB state
class COrderBlock : public CObject
{
public:
   int      direction;   // +1 bullish, -1 bearish
   datetime time;        // OB candle time
   double   high;        // OB candle high
   double   low;         // OB candle low

   string Key() const { return TimeToString(time, TIME_DATE|TIME_MINUTES); }

   void draw(datetime tmS, datetime tmE, color clr){
      string objOB = " OB REC" + TimeToString(time);
      ObjectCreate( 0, objOB, OBJ_RECTANGLE, 0, time, low, tmS, high);
      ObjectSetInteger( 0, objOB, OBJPROP_FILL, true);
      ObjectSetInteger( 0, objOB, OBJPROP_COLOR, clr);
      
      string objtrade = " OB trade" + TimeToString(time);
      ObjectCreate( 0, objtrade, OBJ_RECTANGLE, 0, tmS, high, tmE, low); // trnary operator
      ObjectSetInteger( 0, objtrade, OBJPROP_FILL, true);
      ObjectSetInteger( 0, objtrade, OBJPROP_COLOR, clr);
   }
};
COrderBlock* OB = NULL;

// OB fib state
// Track if an OB has already been traded
datetime lastTradedOBTime = 0;
bool tradedOB = false;
double fib_low, fib_high;
datetime fib_t1, fib_t2;
bool isBullishOB = false; 
bool isBearishOB = false;
datetime T1;
datetime T2;
color OBClr;
#define FIB_OB_BULL "FIB_OB_BULL"
#define FIB_OB_BEAR "FIB_OB_BEAR"
#define FIBO_OBJ "Fibo Retracement"

// BOS state 
datetime lastBOSTradeTime = 0;
bool Bull_BOS_traded, Bear_BOS_traded;
int lastBOSTradeDirection = 0; // 1 for buy, -1 for sell
double   swng_High = -1.0, swng_Low = -1.0;
datetime bos_tH = 0, bos_tL = 0;

//--------------------------- Helpers -------------------------------//
double  getHigh(int i)   { return iHigh(_Symbol, _Period, i);  }
double  getLow(int i)    { return iLow(_Symbol, _Period, i);   }
double  getOpen(int i)   { return iOpen(_Symbol, _Period, i);  }
double  getClose(int i)  { return iClose(_Symbol, _Period, i); }
datetime getTimeBar(int i){ return iTime(_Symbol, _Period, i); }

bool IsNewBar()
{
   datetime lastbar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(g_lastBarTime == 0) { g_lastBarTime = lastbar_time; return false; }
   if(g_lastBarTime != lastbar_time) { g_lastBarTime = lastbar_time; return true; }
   return false;
}

void ExecuteTrade(ENUM_ORDER_TYPE type)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double price = (type==ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = (type==ORDER_TYPE_BUY) ? price - StopLoss*point
                                      : price + StopLoss*point;
   double tp = (type==ORDER_TYPE_BUY) ? price + TakeProfit*point
                                      : price - TakeProfit*point;
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   trade.SetExpertMagicNumber(MagicNumber);
   trade.PositionOpen(_Symbol, type, In_Lot, price, sl, tp, "SMC");
}

//----------------------- Unified Swing Detection -------------------//
// Detects if barIndex is a swing high and/or swing low using len bars on each side.
// If swing high found -> updates fib_high/fib_tH (and swng_High/bos_tH if for BOS).
// If swing low  found -> updates fib_low/fib_tL (and swng_Low/bos_tL if for BOS).
// return: true if at least one swing found.
void DetectSwingForBar(int barIndex, SWING_TYPE type)
{
   const int len = 5;
   bool isSwingH = true, isSwingL = true;   

   for(int i = 1; i <= len; i++){
      int right_bars = barIndex - i;
      int left_bars  = barIndex + i;
      
      if(right_bars < 0) {
         isSwingH = false;
         isSwingL = false;
         break;
      }
      
      if((getHigh(barIndex) <= getHigh(right_bars)) || (left_bars < Bars(_Symbol, _Period) && getHigh(barIndex) < getHigh(left_bars)))
         isSwingH = false;
      
      if((getLow(barIndex) >= getLow(right_bars)) || (left_bars < Bars(_Symbol, _Period) && getLow(barIndex) > getLow(left_bars)))
         isSwingL = false;
   }

   // Assign with ternary operator depending on swing type
   if(isSwingH){
      if(type == SWING_OB) {
         fib_high = getHigh(barIndex);
         fib_t1 = getTimeBar(barIndex);
      } else {
         swng_High = getHigh(barIndex);
         bos_tH = getTimeBar(barIndex);
      }
   }
   if(isSwingL){
      if(type == SWING_OB) {
         fib_low = getLow(barIndex);
         fib_t2 = getTimeBar(barIndex);
      } else {
         swng_Low = getLow(barIndex);
         bos_tL = getTimeBar(barIndex);
      }
   }
}

void DetectAndDrawOrderBlocks()
{
   static datetime lastDetect = 0;
   datetime lastBar = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   
   // Reset OB detection on new bar
   if(lastDetect != lastBar)
   {
      if(OB != NULL) 
      { 
         delete OB; 
         OB = NULL; 
      }
      lastDetect = lastBar;
   }
   
   // Only detect new OB if we don't have one already
   if(OB == NULL)
   {
      for(int i = 1; i < 100; i++)
      {
         // Bullish OB candidate
         if(getOpen(i) < getClose(i) && 
            getOpen(i+2) < getClose(i+2) &&
            getOpen(i+3) > getClose(i+3) && 
            getOpen(i+3) < getClose(i+2))
         {
            OB = new COrderBlock();
            OB.direction = 1;
            OB.time = getTimeBar(i+3);
            OB.high = getHigh(i+3);
            OB.low = getLow(i+3);
            OBClr = BullOB;
            T1 = OB.time;
            Print("Bullish Order Block detected at: ", TimeToString(OB.time));
            break;
         }
         
         // Bearish OB candidate
         if(getOpen(i) > getClose(i) && 
            getOpen(i+2) > getClose(i+2) &&
            getOpen(i+3) < getClose(i+3) && 
            getOpen(i+3) > getClose(i+2)) // Fixed condition
         {
            OB = new COrderBlock();
            OB.direction = -1;
            OB.time = getTimeBar(i+3);
            OB.high = getHigh(i+3);
            OB.low = getLow(i+3);
            OBClr = BearOB;
            T1 = OB.time;
            Print("Bearish Order Block detected at: ", TimeToString(OB.time));
            break;
         }
      }
   }

   if(OB == NULL) return;
   
   // Check if we already traded this OB
   if(lastTradedOBTime == OB.time) return;

   // If price retraces inside OB zone
   Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool inBullZone = (OB.direction > 0 && Ask <= OB.high && Ask >= OB.low);
   bool inBearZone = (OB.direction < 0 && Bid >= OB.low && Bid <= OB.high);

   if(!inBullZone && !inBearZone) return;

   // Use your DetectSwing function to find swings
   // We need to call it multiple times to find the most recent swings
   double mostRecentSwingHigh = 0;
   double mostRecentSwingLow = EMPTY_VALUE;
   datetime mostRecentSwingHighTime = 0;
   datetime mostRecentSwingLowTime = 0;
   
   // Scan recent bars to find the most recent swings
   for(int i = 0; i < 20; i++) // Check the last 20 bars
   {
      // Reset swing variables
      fib_high = 0;
      fib_low = 0;
      fib_t1 = 0;
      fib_t2 = 0;
      
      DetectSwingForBar(i, SWING_OB);
      
      if(fib_high > 0 && (mostRecentSwingHighTime == 0 || fib_t1 > mostRecentSwingHighTime))
      {
         mostRecentSwingHigh = fib_high;
         mostRecentSwingHighTime = fib_t1;
      }
      
      if(fib_low < EMPTY_VALUE && (mostRecentSwingLowTime == 0 || fib_t2 > mostRecentSwingLowTime))
      {
         mostRecentSwingLow = fib_low;
         mostRecentSwingLowTime = fib_t2;
      }
   }
   
   // Ensure we found both swing points
   if(mostRecentSwingHighTime == 0 || mostRecentSwingLowTime == 0) return;
   
   // Draw Fibonacci before trading to validate
   if(OB.direction > 0 && inBullZone)
   {
      // Draw Fibonacci from recent swing low to recent swing high
      ObjectDelete(0, "FIB_OB_BULL");
      if(ObjectCreate(0, "FIB_OB_BULL", OBJ_FIBO, 0, mostRecentSwingLowTime, mostRecentSwingLow, 
                     mostRecentSwingHighTime, mostRecentSwingHigh))
      {
         // Format Fibonacci
         ObjectSetInteger(0, "FIB_OB_BULL", OBJPROP_COLOR, clrBlack);
         for(int i = 0; i < ObjectGetInteger(0, "FIB_OB_BULL", OBJPROP_LEVELS); i++)
         {
            ObjectSetInteger(0, "FIB_OB_BULL", OBJPROP_LEVELCOLOR, i, clrBlack);
         }
         
         double entLvlBull = mostRecentSwingHigh - (mostRecentSwingHigh - mostRecentSwingLow) * (Fib_Trade_lvls / 100.0);
         
         if(Ask <= entLvlBull)
         {
            T2 = getTimeBar(0);
            OB.draw(T1, T2, BullOB);
            ExecuteTrade(ORDER_TYPE_BUY);
            lastTradedOBTime = OB.time; // Mark this OB as traded
            delete OB;
            OB = NULL;
         }
      }
   }
   else if(OB.direction < 0 && inBearZone)
   {
      // Draw Fibonacci from recent swing high to recent swing low
      ObjectDelete(0, "FIB_OB_BEAR");
      if(ObjectCreate(0, "FIB_OB_BEAR", OBJ_FIBO, 0, mostRecentSwingHighTime, mostRecentSwingHigh, 
                     mostRecentSwingLowTime, mostRecentSwingLow))
      {
         // Format Fibonacci
         ObjectSetInteger(0, "FIB_OB_BEAR", OBJPROP_COLOR, clrBlack);
         for(int i = 0; i < ObjectGetInteger(0, "FIB_OB_BEAR", OBJPROP_LEVELS); i++)
         {
            ObjectSetInteger(0, "FIB_OB_BEAR", OBJPROP_LEVELCOLOR, i, clrBlack);
         }
         
         double entLvlBear = mostRecentSwingLow + (mostRecentSwingHigh - mostRecentSwingLow) * (Fib_Trade_lvls / 100.0);
         
         if(Bid >= entLvlBear)
         {
            T2 = getTimeBar(0);
            OB.draw(T1, T2, BearOB);
            ExecuteTrade(ORDER_TYPE_SELL);
            lastTradedOBTime = OB.time; // Mark this OB as traded
            delete OB;
            OB = NULL;
         }
      }
   }
}


//============================== FVG ================================//
// Definition (ICT-style):
// Let C=i, B=i+1, A=i+2.
// Bullish FVG if Low(A) > High(C) -> gap [High(C), Low(A)]
// Bearish FVG if High(A) < Low(C) -> gap [High(A), Low(C)]
struct SFVG
{
   int      dir;    // +1 bull, -1 bear
   datetime tLeft;  // left time anchor
   double   top;    // zone top price
   double   bot;    // zone bottom price

   string Name() const
   {
      string k = TimeToString(tLeft, TIME_DATE|TIME_MINUTES);
      return (dir>0 ? "FVG_B_" : "FVG_S_") + k + "_" + IntegerToString((int)(top*1000.0));
   }
};



bool FVGExistsAt(const string &name){ return ObjectFind(0, name) != -1; }

void DetectAndDrawFVGs()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int counted = 0;

   for(int i=2; i<MathMin(FVG_ScanBars, Bars(_Symbol, _Period))-2; i++)
   {
      // Build A,B,C
      double lowA  = getLow(i+2);
      double highA = getHigh(i+2);
      double highC = getHigh(i);
      double lowC  = getLow(i);

      // Bullish FVG: Low of A > High of C
      if(lowA > highC && (lowA - highC >= FVG_MinPoints * point))
      {
         SFVG z;
         z.dir   = +1;
         z.tLeft = getTimeBar(i+2);  // Changed from getTimeBar to getTime
         z.top   = lowA;
         z.bot   = highC;
         DrawFVG(z);
         counted++;
      }
      // Bearish FVG: High of A < Low of C
      else if(highA < lowC && (lowC - highA >= FVG_MinPoints * point))
      {
         SFVG z;
         z.dir   = -1;
         z.tLeft = getTimeBar(i+2);  // Changed from getTimeBar to getTime
         z.top   = lowC;          // Fixed: should be lowC for bearish FVG top
         z.bot   = highA;         // Fixed: should be highA for bearish FVG bottom
         DrawFVG(z);
         counted++;
      }
      
      if(counted > 15) break; // avoid clutter
   }

   // --- Simplified trading for FVGs ---
   Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // scan drawn objects and trade on first valid touch of EQ (50%)
   int total = ObjectsTotal(0, 0, -1);
   static datetime lastTradeBar = 0;
   
   if(OneTradePerBar)
   {
      datetime barNow = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
      if(lastTradeBar == barNow) return; // already traded this bar
   }

   for(int idx=0; idx<total; idx++)
   {
      string name = ObjectName(0, idx);
      if(StringFind(name, "FVG_", 0) != 0) continue; // only our FVGs

      // Get object coordinates
      datetime t1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
      double y1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
      datetime t2 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
      double y2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);

      double top = MathMax(y1, y2);
      double bot = MathMin(y1, y2);
      bool isBull = (StringFind(name, "FVG_B_", 0) == 0);
      double mid  = (top + bot) * 0.5;

      if(isBull)
      {
         // trade when Ask is inside the gap and at/under EQ
         if(Ask <= top && Ask >= bot && (!FVG_TradeAtEQ || Ask <= mid))
         {
            ExecuteTrade(ORDER_TYPE_BUY);
            lastTradeBar = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
            break;
         }
      }
      else
      {
         // trade when Bid is inside the gap and at/over EQ
         if(Bid <= top && Bid >= bot && (!FVG_TradeAtEQ || Bid >= mid))
         {
            ExecuteTrade(ORDER_TYPE_SELL);
            lastTradeBar = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
            break;
         }
      }
   }
}

//=============================== BOS ===============================//
// Use unified swings (no RSI). Trading logic mirrors your earlier code:
// - Sell when price breaks above last swing high (liquidity run idea)
// - Buy  when price breaks below last swing low
void DetectAndDrawBOS()
{
   // Use DetectSwingForBar to find the most recent swing points
   double mostRecentSwingHigh = 0;
   double mostRecentSwingLow = EMPTY_VALUE;
   datetime mostRecentSwingHighTime = 0;
   datetime mostRecentSwingLowTime = 0;
   
   // Scan recent bars to find the most recent swings for BOS
   for(int i = 0; i < 20; i++) // Check the last 20 bars
   {
      // Reset swing variables
      swng_High = 0;
      swng_Low = 0;
      bos_tH = 0;
      bos_tL = 0;
      
      // Detect swing at this bar for BOS
      DetectSwingForBar(i, SWING_BOS);
      
      if(swng_High > 0 && (mostRecentSwingHighTime == 0 || bos_tH > mostRecentSwingHighTime))
      {
         mostRecentSwingHigh = swng_High;
         mostRecentSwingHighTime = bos_tH;
      }
      
      if(swng_Low < EMPTY_VALUE && (mostRecentSwingLowTime == 0 || bos_tL > mostRecentSwingLowTime))
      {
         mostRecentSwingLow = swng_Low;
         mostRecentSwingLowTime = bos_tL;
      }
   }
   
   // Update the global BOS variables with the most recent swings
   if(mostRecentSwingHighTime > 0)
   {
      if(mostRecentSwingHighTime != bos_tH)
         Bull_BOS_traded = false;
      swng_High = mostRecentSwingHigh;
      bos_tH = mostRecentSwingHighTime;
   }
   
   if(mostRecentSwingLowTime > 0)
   {
      if(mostRecentSwingLowTime != bos_tL)
         Bear_BOS_traded = false;
      swng_Low = mostRecentSwingLow;
      bos_tL = mostRecentSwingLowTime;
   }
   
   // Now check for break of structure
   Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Get current bar time to prevent multiple trades on same bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   
   // SELL on break above swing high
   if(swng_High > 0 && Ask > swng_High && Bull_BOS_traded == false)
   {
      // Check if we haven't already traded this breakout
      if(lastBOSTradeTime != currentBarTime || lastBOSTradeDirection != -1)
      {
         if(DrawBOSLines)
            DrawBOS("BOS_H_" + TimeToString(bos_tH), bos_tH, swng_High,
                    TimeCurrent(), swng_High, BOSBear, -1);
         
         ExecuteTrade(ORDER_TYPE_BUY);
         
         // Update trade tracking
         lastBOSTradeTime = currentBarTime;
         lastBOSTradeDirection = -1;
         Bull_BOS_traded = true;
         
         // Reset the swing high to prevent immediate re-trading
         swng_High = -1.0;
      }
   }
   
   
   // BUY on break below swing low
   if(swng_Low > 0 && Bid < swng_Low && Bear_BOS_traded == false)
   {
      // Check if we haven't already traded this breakout
      if(lastBOSTradeTime != currentBarTime || lastBOSTradeDirection != 1)
      {
         if(DrawBOSLines)
            DrawBOS("BOS_L_" + TimeToString(bos_tL), bos_tL, swng_Low,
                    TimeCurrent(), swng_Low, BOSBull, +1);
         
         ExecuteTrade(ORDER_TYPE_SELL);
         
         // Update trade tracking
         Bear_BOS_traded = true;
         lastBOSTradeTime = currentBarTime;
         lastBOSTradeDirection = 1;
         
         // Reset the swing low to prevent immediate re-trading
         swng_Low = -1.0;
      }
   }
   
}

//=========================== EA Lifecycle ==========================//
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
   if(OB!=NULL){ delete OB; OB=NULL; }
}

//---------------------------- BOS UI -------------------------------//
void DrawBOS(const string name, datetime t1, double p1, datetime t2, double p2, color col, int dir)
{
   if(ObjectFind(0, name) == -1)
   {
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);

      string lbl = name + "_lbl";
      ObjectCreate(0, lbl, OBJ_TEXT, 0, t2, p2);
      ObjectSetInteger(0, lbl, OBJPROP_COLOR, col);
      ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0,  lbl, OBJPROP_TEXT, "Break");
      ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, (dir>0)?ANCHOR_RIGHT_UPPER:ANCHOR_RIGHT_LOWER);
   }
}

void DrawFVG(const SFVG &z)
{
   string name = z.Name();
   datetime tNow = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   
   // Delete existing object if it exists
   if(ObjectFind(0, name) != -1) 
      ObjectDelete(0, name);
   
   // Create rectangle object for FVG
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, z.tLeft, z.bot, tNow, z.top))
   {
      Print("Error creating FVG object: ", GetLastError());
      return;
   }
   
   // Set object properties
   ObjectSetInteger(0, name, OBJPROP_COLOR, z.dir>0 ? BullFVG : BearFVG);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   
   // Set Z-order to make sure it's visible
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
}

void OnTick()
{
   if(!IsNewBar()) return;

   // Strategy switch
   if(TradeStrategy == STRAT_FVG || TradeStrategy == STRAT_AUTO)
      DetectAndDrawFVGs();

   if(TradeStrategy == STRAT_OB  || TradeStrategy == STRAT_AUTO)
      DetectAndDrawOrderBlocks();

   if(TradeStrategy == STRAT_BOS || TradeStrategy == STRAT_AUTO)
      DetectAndDrawBOS();
}
