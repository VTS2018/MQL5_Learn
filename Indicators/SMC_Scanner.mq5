//+------------------------------------------------------------------+
//|                                                  SMC_Scanner.mq5 |
//|                        GIT under Copyright 2025, MetaQuotes Ltd. |
//|                     https://www.mql5.com/en/users/johnhlomohang/ |
//+------------------------------------------------------------------+
#property copyright "GIT under Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/johnhlomohang/"
#property version   "2.00"
#property description "SMC Visual Scanner: OB + FVG + BOS Detection (No Trading)"
#property description "Pure Indicator for Manual Trading Decisions"

#property indicator_chart_window
#property indicator_plots 0

enum ENUM_DISPLAY_STRATEGY
{
   STRAT_OB,         // Display Order Blocks Only
   STRAT_FVG,        // Display FVGs Only
   STRAT_BOS,        // Display Break of Structure Only
   STRAT_AUTO        // Display All SMC Concepts
};

enum SWING_TYPE{
   SWING_OB,
   SWING_BOS,
};

//----------------------------- Inputs ------------------------------//
input group "=== Strategy Selection ==="
input ENUM_DISPLAY_STRATEGY DisplayStrategy = STRAT_AUTO;  // Display Strategy

input group "=== Swing Detection ==="
input int           SwingPeriod     = 5;      // Bars each side to confirm swing
input int           SwingProbeBar   = 5;      // Bar index to test for swings

input group "=== Order Block Settings ==="
input double        Fib_Trade_lvls  = 61.8;   // OB Fibonacci level to display
input bool          ShowOBFibonacci = true;   // Show OB Fibonacci retracement
input int           OB_ScanBars     = 100;    // Historical OB scan bars

input group "=== FVG Settings ==="
input int           FVG_MinPoints   = 3;      // Minimal gap in points
input int           FVG_ScanBars    = 50;     // FVG scan bars (realtime)
input bool          ShowFVGEQ       = true;   // Show 50% EQ line on FVG
input int           FVG_HistoryScan = 200;    // Historical FVG scan bars

input group "=== BOS Settings ==="
input bool          DrawBOSLines    = true;   // Draw BOS breakout lines
input bool          ShowBOSArrows   = true;   // Show BOS arrows
input int           BOS_ScanBars    = 50;     // BOS monitoring bars

input group "=== Alert Settings ==="
input bool          EnableAlerts    = true;   // Enable sound alerts
input bool          EnablePush      = false;  // Enable push notifications
input bool          AlertOnOB       = true;   // Alert on new Order Block
input bool          AlertOnFVG      = true;   // Alert on new FVG
input bool          AlertOnBOS      = true;   // Alert on Break of Structure

input group "=== Display Settings ==="
input int           MaxObjectsPerType = 15;   // Max objects per type on chart
input bool          ShowHistoricalScan = true; // Scan history on init

//---------------------------- Colors -------------------------------//
#define BullOB   clrLime
#define BearOB   clrRed
#define BullFVG  clrPaleGreen
#define BearFVG  clrMistyRose
#define BOSBull  clrDodgerBlue
#define BOSBear  clrTomato
#define FibColor clrBlack
#define EQColor  clrGray

//---------------------------- Globals ------------------------------//
double   Bid, Ask;
datetime g_lastBarTime = 0;

// OB state
class COrderBlock
{
public:
   int      direction;   // +1 bullish, -1 bearish
   datetime time;        // OB candle time
   double   high;        // OB candle high
   double   low;         // OB candle low

   string Key() const { return TimeToString(time, TIME_DATE|TIME_MINUTES); }

   void draw(datetime tmS, datetime tmE, color clr){
      string objOB = "OB_REC_" + TimeToString(time);
      ObjectDelete(0, objOB);
      ObjectCreate(0, objOB, OBJ_RECTANGLE, 0, time, low, tmE, high);
      ObjectSetInteger(0, objOB, OBJPROP_FILL, true);
      ObjectSetInteger(0, objOB, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objOB, OBJPROP_BACK, true);
      ObjectSetInteger(0, objOB, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, objOB, OBJPROP_STYLE, STYLE_SOLID);
      
      // Add label
      string objLbl = "OB_LBL_" + TimeToString(time);
      ObjectDelete(0, objLbl);
      ObjectCreate(0, objLbl, OBJ_TEXT, 0, time, direction > 0 ? low : high);
      ObjectSetString(0, objLbl, OBJPROP_TEXT, direction > 0 ? "OB↑" : "OB↓");
      ObjectSetInteger(0, objLbl, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objLbl, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, objLbl, OBJPROP_ANCHOR, direction > 0 ? ANCHOR_UPPER : ANCHOR_LOWER);
   }
};

COrderBlock* OB = NULL;
datetime lastDrawnOBTime = 0;

// OB fib state
double fib_low, fib_high;
datetime fib_t1, fib_t2;
datetime T1, T2;
color OBClr;

// BOS state 
datetime lastDrawnBOSHigh = 0;
datetime lastDrawnBOSLow = 0;
double   swng_High = -1.0, swng_Low = -1.0;
datetime bos_tH = 0, bos_tL = 0;

// Object counters
int OB_count = 0;
int FVG_count = 0;
int BOS_count = 0;

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

void SendAlert(string message)
{
   if(EnableAlerts)
      Alert(message);
   
   if(EnablePush)
      SendNotification(message);
}

void CleanOldObjects(string prefix, int maxCount)
{
   // Simple cleanup: delete oldest objects if count exceeds max
   int total = ObjectsTotal(0, 0, OBJ_RECTANGLE);
   if(total <= maxCount) return;
   
   // Find and delete oldest objects with prefix
   datetime oldestTime = D'2099.12.31';
   string oldestName = "";
   
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, prefix, 0) == 0)
      {
         datetime t = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
         if(t < oldestTime)
         {
            oldestTime = t;
            oldestName = name;
         }
      }
   }
   
   if(oldestName != "")
   {
      ObjectDelete(0, oldestName);
      // Also delete related objects
      if(StringFind(prefix, "OB_", 0) == 0)
      {
         ObjectDelete(0, StringSubstr(oldestName, 0) + "_LBL");
         ObjectDelete(0, "FIB_" + StringSubstr(oldestName, 3));
      }
   }
}

//----------------------- Unified Swing Detection -------------------//
void DetectSwingForBar(int barIndex, SWING_TYPE type)
{
   const int len = SwingPeriod;
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

//======================== Order Block Detection ====================//
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
      for(int i = 1; i < OB_ScanBars; i++)
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
            break;
         }
         
         // Bearish OB candidate
         if(getOpen(i) > getClose(i) && 
            getOpen(i+2) > getClose(i+2) &&
            getOpen(i+3) < getClose(i+3) && 
            getOpen(i+3) > getClose(i+2))
         {
            OB = new COrderBlock();
            OB.direction = -1;
            OB.time = getTimeBar(i+3);
            OB.high = getHigh(i+3);
            OB.low = getLow(i+3);
            OBClr = BearOB;
            T1 = OB.time;
            break;
         }
      }
   }

   if(OB == NULL) return;
   
   // Check if we already drew this OB
   if(lastDrawnOBTime == OB.time) return;

   // Draw OB immediately when detected
   T2 = getTimeBar(0);
   OB.draw(T1, T2, OBClr);
   
   // Find swing points for Fibonacci
   if(ShowOBFibonacci)
   {
      double mostRecentSwingHigh = 0;
      double mostRecentSwingLow = EMPTY_VALUE;
      datetime mostRecentSwingHighTime = 0;
      datetime mostRecentSwingLowTime = 0;
      
      for(int i = 0; i < 30; i++)
      {
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
      
      // Draw Fibonacci as reference
      if(mostRecentSwingHighTime != 0 && mostRecentSwingLowTime != 0)
      {
         string fibName = "FIB_OB_" + (OB.direction > 0 ? "BULL_" : "BEAR_") + TimeToString(OB.time);
         ObjectDelete(0, fibName);
         
         if(OB.direction > 0)
         {
            ObjectCreate(0, fibName, OBJ_FIBO, 0, mostRecentSwingLowTime, mostRecentSwingLow, 
                        mostRecentSwingHighTime, mostRecentSwingHigh);
         }
         else
         {
            ObjectCreate(0, fibName, OBJ_FIBO, 0, mostRecentSwingHighTime, mostRecentSwingHigh, 
                        mostRecentSwingLowTime, mostRecentSwingLow);
         }
         
         ObjectSetInteger(0, fibName, OBJPROP_COLOR, FibColor);
         ObjectSetInteger(0, fibName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, fibName, OBJPROP_RAY_RIGHT, true);
         
         for(int i = 0; i < ObjectGetInteger(0, fibName, OBJPROP_LEVELS); i++)
         {
            ObjectSetInteger(0, fibName, OBJPROP_LEVELCOLOR, i, FibColor);
            ObjectSetInteger(0, fibName, OBJPROP_LEVELSTYLE, i, STYLE_DOT);
         }
      }
   }
   
   // Send alert
   if(AlertOnOB)
   {
      string msg = StringFormat("%s - New %s Order Block detected at %.5f", 
                               _Symbol, 
                               OB.direction > 0 ? "Bullish" : "Bearish",
                               OB.direction > 0 ? OB.low : OB.high);
      SendAlert(msg);
   }
   
   lastDrawnOBTime = OB.time;
   OB_count++;
   
   // Cleanup old objects
   if(OB_count > MaxObjectsPerType)
      CleanOldObjects("OB_REC_", MaxObjectsPerType);
   
   delete OB;
   OB = NULL;
}

//============================== FVG ================================//
struct SFVG
{
   int      dir;    // +1 bull, -1 bear
   datetime tLeft;  // left time anchor
   double   top;    // zone top price
   double   bot;    // zone bottom price

   string Name() const
   {
      string k = TimeToString(tLeft, TIME_DATE|TIME_MINUTES);
      return (dir>0 ? "FVG_B_" : "FVG_S_") + k + "_" + IntegerToString((int)(top*10000.0));
   }
};

void DrawFVG(const SFVG &z)
{
   string name = z.Name();
   datetime tNow = getTimeBar(0);
   
   if(ObjectFind(0, name) != -1) 
      return; // Already drawn
   
   // Create rectangle object for FVG
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, z.tLeft, z.bot, tNow, z.top))
      return;
   
   color fvgColor = z.dir > 0 ? BullFVG : BearFVG;
   ObjectSetInteger(0, name, OBJPROP_COLOR, fvgColor);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   
   // Draw 50% EQ line if enabled
   if(ShowFVGEQ)
   {
      string eqName = "EQ_" + name;
      double eqPrice = (z.top + z.bot) * 0.5;
      ObjectCreate(0, eqName, OBJ_TREND, 0, z.tLeft, eqPrice, tNow, eqPrice);
      ObjectSetInteger(0, eqName, OBJPROP_COLOR, EQColor);
      ObjectSetInteger(0, eqName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, eqName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, eqName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, eqName, OBJPROP_BACK, true);
   }
   
   // Add label
   string lblName = "LBL_" + name;
   ObjectCreate(0, lblName, OBJ_TEXT, 0, z.tLeft, z.dir > 0 ? z.bot : z.top);
   ObjectSetString(0, lblName, OBJPROP_TEXT, z.dir > 0 ? "FVG↑" : "FVG↓");
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, fvgColor);
   ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, z.dir > 0 ? ANCHOR_UPPER : ANCHOR_LOWER);
   
   FVG_count++;
   
   // Cleanup old objects
   if(FVG_count > MaxObjectsPerType)
      CleanOldObjects("FVG_", MaxObjectsPerType);
}

void DetectAndDrawFVGs()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int counted = 0;

   for(int i=2; i<MathMin(FVG_ScanBars, Bars(_Symbol, _Period))-2; i++)
   {
      double lowA  = getLow(i+2);
      double highA = getHigh(i+2);
      double highC = getHigh(i);
      double lowC  = getLow(i);

      // Bullish FVG: Low of A > High of C
      if(lowA > highC && (lowA - highC >= FVG_MinPoints * point))
      {
         SFVG z;
         z.dir   = +1;
         z.tLeft = getTimeBar(i+2);
         z.top   = lowA;
         z.bot   = highC;
         
         // Check if not already drawn
         if(ObjectFind(0, z.Name()) == -1)
         {
            DrawFVG(z);
            
            if(AlertOnFVG && i < 5) // Only alert on recent FVGs
            {
               string msg = StringFormat("%s - Bullish FVG detected: %.5f - %.5f", 
                                       _Symbol, z.bot, z.top);
               SendAlert(msg);
            }
            counted++;
         }
      }
      // Bearish FVG: High of A < Low of C
      else if(highA < lowC && (lowC - highA >= FVG_MinPoints * point))
      {
         SFVG z;
         z.dir   = -1;
         z.tLeft = getTimeBar(i+2);
         z.top   = lowC;
         z.bot   = highA;
         
         if(ObjectFind(0, z.Name()) == -1)
         {
            DrawFVG(z);
            
            if(AlertOnFVG && i < 5)
            {
               string msg = StringFormat("%s - Bearish FVG detected: %.5f - %.5f", 
                                       _Symbol, z.bot, z.top);
               SendAlert(msg);
            }
            counted++;
         }
      }
      
      if(counted > 15) break;
   }
}

//=============================== BOS ===============================//
void DrawBOS(const string name, datetime t1, double p1, datetime t2, double p2, color col, int dir)
{
   if(ObjectFind(0, name) != -1) return; // Already drawn
   
   if(DrawBOSLines)
   {
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   }
   
   if(ShowBOSArrows)
   {
      string arrowName = name + "_arrow";
      ObjectCreate(0, arrowName, OBJ_ARROW, 0, t2, p2);
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, dir > 0 ? 233 : 234); // Up/Down arrow
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, col);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
   }

   string lbl = name + "_lbl";
   ObjectCreate(0, lbl, OBJ_TEXT, 0, t2, p2);
   ObjectSetInteger(0, lbl, OBJPROP_COLOR, col);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, lbl, OBJPROP_TEXT, "BOS");
   ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, (dir>0)?ANCHOR_LOWER:ANCHOR_UPPER);
   
   BOS_count++;
   
   // Cleanup old objects
   if(BOS_count > MaxObjectsPerType)
      CleanOldObjects("BOS_", MaxObjectsPerType);
}

void DetectAndDrawBOS()
{
   double mostRecentSwingHigh = 0;
   double mostRecentSwingLow = EMPTY_VALUE;
   datetime mostRecentSwingHighTime = 0;
   datetime mostRecentSwingLowTime = 0;
   
   for(int i = 0; i < BOS_ScanBars; i++)
   {
      swng_High = 0;
      swng_Low = 0;
      bos_tH = 0;
      bos_tL = 0;
      
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
   
   if(mostRecentSwingHighTime > 0)
   {
      swng_High = mostRecentSwingHigh;
      bos_tH = mostRecentSwingHighTime;
   }
   
   if(mostRecentSwingLowTime > 0)
   {
      swng_Low = mostRecentSwingLow;
      bos_tL = mostRecentSwingLowTime;
   }
   
   Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Detect break above swing high
   if(swng_High > 0 && Ask > swng_High)
   {
      string bosName = "BOS_H_" + TimeToString(bos_tH);
      if(ObjectFind(0, bosName) == -1) // Not yet drawn
      {
         DrawBOS(bosName, bos_tH, swng_High, TimeCurrent(), swng_High, BOSBull, +1);
         
         if(AlertOnBOS)
         {
            string msg = StringFormat("%s - Bullish BOS: Break above %.5f", _Symbol, swng_High);
            SendAlert(msg);
         }
         
         lastDrawnBOSHigh = bos_tH;
      }
   }
   
   // Detect break below swing low
   if(swng_Low > 0 && Bid < swng_Low)
   {
      string bosName = "BOS_L_" + TimeToString(bos_tL);
      if(ObjectFind(0, bosName) == -1) // Not yet drawn
      {
         DrawBOS(bosName, bos_tL, swng_Low, TimeCurrent(), swng_Low, BOSBear, -1);
         
         if(AlertOnBOS)
         {
            string msg = StringFormat("%s - Bearish BOS: Break below %.5f", _Symbol, swng_Low);
            SendAlert(msg);
         }
         
         lastDrawnBOSLow = bos_tL;
      }
   }
}

//==================== Historical Scanning ==========================//
void ScanHistoricalOBs()
{
   Print("Scanning historical Order Blocks...");
   int foundCount = 0;
   
   for(int startBar = SwingPeriod + 3; startBar < OB_ScanBars && startBar < Bars(_Symbol, _Period) - 3; startBar++)
   {
      // Check for bullish OB pattern
      if(getOpen(startBar) < getClose(startBar) && 
         getOpen(startBar+2) < getClose(startBar+2) &&
         getOpen(startBar+3) > getClose(startBar+3) && 
         getOpen(startBar+3) < getClose(startBar+2))
      {
         datetime obTime = getTimeBar(startBar+3);
         string objName = "OB_REC_" + TimeToString(obTime);
         
         if(ObjectFind(0, objName) == -1)
         {
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, obTime, getLow(startBar+3), getTimeBar(0), getHigh(startBar+3));
            ObjectSetInteger(0, objName, OBJPROP_FILL, true);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, BullOB);
            ObjectSetInteger(0, objName, OBJPROP_BACK, true);
            
            string lblName = "OB_LBL_" + TimeToString(obTime);
            ObjectCreate(0, lblName, OBJ_TEXT, 0, obTime, getLow(startBar+3));
            ObjectSetString(0, lblName, OBJPROP_TEXT, "OB↑");
            ObjectSetInteger(0, lblName, OBJPROP_COLOR, BullOB);
            ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_UPPER);
            
            foundCount++;
         }
      }
      
      // Check for bearish OB pattern
      if(getOpen(startBar) > getClose(startBar) && 
         getOpen(startBar+2) > getClose(startBar+2) &&
         getOpen(startBar+3) < getClose(startBar+3) && 
         getOpen(startBar+3) > getClose(startBar+2))
      {
         datetime obTime = getTimeBar(startBar+3);
         string objName = "OB_REC_" + TimeToString(obTime);
         
         if(ObjectFind(0, objName) == -1)
         {
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, obTime, getLow(startBar+3), getTimeBar(0), getHigh(startBar+3));
            ObjectSetInteger(0, objName, OBJPROP_FILL, true);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, BearOB);
            ObjectSetInteger(0, objName, OBJPROP_BACK, true);
            
            string lblName = "OB_LBL_" + TimeToString(obTime);
            ObjectCreate(0, lblName, OBJ_TEXT, 0, obTime, getHigh(startBar+3));
            ObjectSetString(0, lblName, OBJPROP_TEXT, "OB↓");
            ObjectSetInteger(0, lblName, OBJPROP_COLOR, BearOB);
            ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_LOWER);
            
            foundCount++;
         }
      }
      
      if(foundCount >= MaxObjectsPerType) break;
   }
   
   Print("Historical OB scan complete. Found: ", foundCount);
}

void ScanHistoricalFVGs()
{
   Print("Scanning historical FVGs...");
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int foundCount = 0;
   
   for(int i = 2; i < FVG_HistoryScan && i < Bars(_Symbol, _Period) - 2; i++)
   {
      double lowA  = getLow(i+2);
      double highA = getHigh(i+2);
      double highC = getHigh(i);
      double lowC  = getLow(i);

      // Bullish FVG
      if(lowA > highC && (lowA - highC >= FVG_MinPoints * point))
      {
         SFVG z;
         z.dir = +1;
         z.tLeft = getTimeBar(i+2);
         z.top = lowA;
         z.bot = highC;
         
         if(ObjectFind(0, z.Name()) == -1)
         {
            DrawFVG(z);
            foundCount++;
         }
      }
      // Bearish FVG
      else if(highA < lowC && (lowC - highA >= FVG_MinPoints * point))
      {
         SFVG z;
         z.dir = -1;
         z.tLeft = getTimeBar(i+2);
         z.top = lowC;
         z.bot = highA;
         
         if(ObjectFind(0, z.Name()) == -1)
         {
            DrawFVG(z);
            foundCount++;
         }
      }
      
      if(foundCount >= MaxObjectsPerType) break;
   }
   
   Print("Historical FVG scan complete. Found: ", foundCount);
}

//=========================== EA Lifecycle ==========================//
int OnInit()
{
   Print("SMC Scanner initialized - Display Strategy: ", EnumToString(DisplayStrategy));
   
   // Clear old objects on init
   ObjectsDeleteAll(0, "OB_");
   ObjectsDeleteAll(0, "FVG_");
   ObjectsDeleteAll(0, "BOS_");
   ObjectsDeleteAll(0, "FIB_");
   ObjectsDeleteAll(0, "EQ_");
   ObjectsDeleteAll(0, "LBL_");
   
   // Perform historical scan if enabled
   if(ShowHistoricalScan)
   {
      if(DisplayStrategy == STRAT_OB || DisplayStrategy == STRAT_AUTO)
         ScanHistoricalOBs();
      
      if(DisplayStrategy == STRAT_FVG || DisplayStrategy == STRAT_AUTO)
         ScanHistoricalFVGs();
   }
   
   ChartRedraw();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(OB != NULL) { delete OB; OB = NULL; }
   
   Comment("");
   Print("SMC Scanner removed from chart. Reason: ", reason);
}

void OnTick()
{
   if(!IsNewBar()) return;

   // Update display based on strategy
   if(DisplayStrategy == STRAT_FVG || DisplayStrategy == STRAT_AUTO)
      DetectAndDrawFVGs();

   if(DisplayStrategy == STRAT_OB || DisplayStrategy == STRAT_AUTO)
      DetectAndDrawOrderBlocks();

   if(DisplayStrategy == STRAT_BOS || DisplayStrategy == STRAT_AUTO)
      DetectAndDrawBOS();
}
