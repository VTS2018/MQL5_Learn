//+------------------------------------------------------------------+
//|                                                  Market_Sent.mq5 |
//|                        GIT under Copyright 2025, MetaQuotes Ltd. |
//|                     https://www.mql5.com/en/users/johnhlomohang/ |
//+------------------------------------------------------------------+
#property copyright "GIT under Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/johnhlomohang/"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0
// https://www.mql5.com/en/articles/19422

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input group "Timeframe Settings"
input ENUM_TIMEFRAMES HigherTF = PERIOD_H4;     
input ENUM_TIMEFRAMES LowerTF1 = PERIOD_H1;     
input ENUM_TIMEFRAMES LowerTF2 = PERIOD_M30;    

input group "Indicator Settings"
input int MAPeriod = 200;                       
input int SwingLookback = 5;                    
input double ATRThreshold = 0.002;              

input group "Visual Settings"
// force top-left dark theme
input int PanelCorner = 0;                      
input int PanelX = 10;                          
input int PanelY = 10;                          
input string FontFace = "Arial";                
input int FontSize = 10;                        
input color BullishColor = clrLimeGreen;        
input color BearishColor = clrRed;              
input color RiskOnColor = clrDodgerBlue;        
input color RiskOffColor = clrOrangeRed;        
input color NeutralColor = clrGold;             

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
int higherTFHandle, lowerTF1Handle, lowerTF2Handle;
double higherTFMA[], lowerTF1MA[], lowerTF2MA[];
datetime lastUpdateTime = 0;
string indicatorName = "MarketSentiment";

//--- helper: convert timeframe to string
string TFtoString(int tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default: return "TF?";
   }
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
    indicatorName = "MarketSentiment_" + IntegerToString(ChartID());
    
    higherTFHandle = iMA(_Symbol, HigherTF, MAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    lowerTF1Handle = iMA(_Symbol, LowerTF1, MAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    lowerTF2Handle = iMA(_Symbol, LowerTF2, MAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    
    ArraySetAsSeries(higherTFMA, true);
    ArraySetAsSeries(lowerTF1MA, true);
    ArraySetAsSeries(lowerTF2MA, true);
    
    CreatePanel();
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, indicatorName);
    IndicatorRelease(higherTFHandle);
    IndicatorRelease(lowerTF1Handle);
    IndicatorRelease(lowerTF2Handle);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    if (TimeCurrent() - lastUpdateTime < 10 && prev_calculated > 0)
        return(rates_total);
    
    lastUpdateTime = TimeCurrent();
    
    CopyBuffer(higherTFHandle, 0, 0, 3, higherTFMA);
    CopyBuffer(lowerTF1Handle, 0, 0, 3, lowerTF1MA);
    CopyBuffer(lowerTF2Handle, 0, 0, 3, lowerTF2MA);
    
    double higherTFPrice = iClose(_Symbol, HigherTF, 0);
    double lowerTF1Price = iClose(_Symbol, LowerTF1, 0);
    double lowerTF2Price = iClose(_Symbol, LowerTF2, 0);
    
    int higherTFBias = GetHigherTFBias(higherTFPrice, higherTFMA[0]);
    
    bool lowerTF1Bullish = IsBullishStructure(LowerTF1, SwingLookback);
    bool lowerTF1Bearish = IsBearishStructure(LowerTF1, SwingLookback);
    bool lowerTF2Bullish = IsBullishStructure(LowerTF2, SwingLookback);
    bool lowerTF2Bearish = IsBearishStructure(LowerTF2, SwingLookback);
    
    bool lowerTF1Breakout = HasBreakout(LowerTF1, SwingLookback, higherTFBias);
    bool lowerTF2Breakout = HasBreakout(LowerTF2, SwingLookback, higherTFBias);
    
    int sentiment = DetermineSentiment(
        higherTFBias, 
        lowerTF1Bullish, lowerTF1Bearish, lowerTF1Breakout,
        lowerTF2Bullish, lowerTF2Bearish, lowerTF2Breakout
    );
    
    UpdatePanel(higherTFBias,
                lowerTF1Bullish, lowerTF1Bearish,
                lowerTF2Bullish, lowerTF2Bearish,
                sentiment);
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Determine higher timeframe bias                                  |
//+------------------------------------------------------------------+
int GetHigherTFBias(double price, double maValue)
{
    double deviation = MathAbs(price - maValue) / maValue;
    if (price > maValue && deviation > ATRThreshold) return 1;
    else if (price < maValue && deviation > ATRThreshold) return -1;
    else return 0;
}

//+------------------------------------------------------------------+
//| Bullish structure                                                |
//+------------------------------------------------------------------+
bool IsBullishStructure(ENUM_TIMEFRAMES tf, int lookback)
{
    int swingHighIndex = iHighest(_Symbol, tf, MODE_HIGH, lookback * 2, 1);
    int swingLowIndex  = iLowest (_Symbol, tf, MODE_LOW,  lookback * 2, 1);
    int prevHigh = iHighest(_Symbol, tf, MODE_HIGH, lookback, lookback+1);
    int prevLow  = iLowest (_Symbol, tf, MODE_LOW,  lookback, lookback+1);
    if (swingHighIndex==-1 || swingLowIndex==-1 || prevHigh==-1 || prevLow==-1) return false;
    return (iHigh(_Symbol, tf, swingHighIndex) > iHigh(_Symbol, tf, prevHigh) &&
            iLow(_Symbol, tf, swingLowIndex)   > iLow (_Symbol, tf, prevLow));
}
//+------------------------------------------------------------------+
//| Bearish structure                                                |
//+------------------------------------------------------------------+
bool IsBearishStructure(ENUM_TIMEFRAMES tf, int lookback)
{
    int swingHighIndex = iHighest(_Symbol, tf, MODE_HIGH, lookback * 2, 1);
    int swingLowIndex  = iLowest (_Symbol, tf, MODE_LOW,  lookback * 2, 1);
    int prevHigh = iHighest(_Symbol, tf, MODE_HIGH, lookback, lookback+1);
    int prevLow  = iLowest (_Symbol, tf, MODE_LOW,  lookback, lookback+1);
    if (swingHighIndex==-1 || swingLowIndex==-1 || prevHigh==-1 || prevLow==-1) return false;
    return (iHigh(_Symbol, tf, swingHighIndex) < iHigh(_Symbol, tf, prevHigh) &&
            iLow(_Symbol, tf, swingLowIndex)   < iLow (_Symbol, tf, prevLow));
}

//+------------------------------------------------------------------+
bool HasBreakout(ENUM_TIMEFRAMES tf, int lookback, int higherTFBias)
{
    int swingHighIndex = iHighest(_Symbol, tf, MODE_HIGH, lookback, 1);
    int swingLowIndex  = iLowest (_Symbol, tf, MODE_LOW,  lookback, 1);
    if (swingHighIndex==-1 || swingLowIndex==-1) return false;
    double swingHigh = iHigh(_Symbol, tf, swingHighIndex);
    double swingLow  = iLow (_Symbol, tf, swingLowIndex);
    double price = iClose(_Symbol, tf, 0);
    if (higherTFBias==1) return (price > swingHigh);
    if (higherTFBias==-1) return (price < swingLow);
    return false;
}

//+------------------------------------------------------------------+
int DetermineSentiment(int higherTFBias, 
                      bool tf1Bullish, bool tf1Bearish, bool tf1Breakout,
                      bool tf2Bullish, bool tf2Bearish, bool tf2Breakout)
{
    if (higherTFBias==1 && tf1Bullish && tf2Bullish) return 1;
    if (higherTFBias==-1 && tf1Bearish && tf2Bearish) return -1;
    if (higherTFBias==1 && (tf1Breakout||tf2Breakout)) return 2;
    if (higherTFBias==-1 && (tf1Breakout||tf2Breakout)) return -2;
    return 0;
}

//+------------------------------------------------------------------+
//| Panel Creation (dark theme, top-left)                            |
//+------------------------------------------------------------------+
void CreatePanel()
{
   string bg = indicatorName + "_BG";
   ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, PanelX);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, PanelY);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, 200);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, 120);
   ObjectSetInteger(0, bg, OBJPROP_CORNER, 0);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, bg, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, bg, OBJPROP_BACK, true);
   ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);

   string title = indicatorName + "_Title";
   ObjectCreate(0, title, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, title, OBJPROP_XDISTANCE, PanelX+10);
   ObjectSetInteger(0, title, OBJPROP_YDISTANCE, PanelY+10);
   ObjectSetInteger(0, title, OBJPROP_CORNER, 0);
   ObjectSetString (0, title, OBJPROP_TEXT, "Market Sentiment");
   ObjectSetInteger(0, title, OBJPROP_COLOR, clrWhite);
   ObjectSetString (0, title, OBJPROP_FONT, FontFace);
   ObjectSetInteger(0, title, OBJPROP_FONTSIZE, FontSize);

   string tfs[3] = { TFtoString(HigherTF), TFtoString(LowerTF1), TFtoString(LowerTF2) };
   for(int i=0;i<3;i++)
   {
      string tfLabel = indicatorName+"_TF"+(string)i;
      ObjectCreate(0, tfLabel, OBJ_LABEL, 0,0,0);
      ObjectSetInteger(0, tfLabel, OBJPROP_XDISTANCE, PanelX+10);
      ObjectSetInteger(0, tfLabel, OBJPROP_YDISTANCE, PanelY+30+i*20);
      ObjectSetInteger(0, tfLabel, OBJPROP_CORNER, 0);
      ObjectSetString (0, tfLabel, OBJPROP_TEXT, tfs[i]+":");
      ObjectSetInteger(0, tfLabel, OBJPROP_COLOR, clrLightGray);
      ObjectSetString (0, tfLabel, OBJPROP_FONT, FontFace);
      ObjectSetInteger(0, tfLabel, OBJPROP_FONTSIZE, FontSize);

      string sentLabel = indicatorName+"_Sentiment"+(string)i;
      ObjectCreate(0, sentLabel, OBJ_LABEL, 0,0,0);
      ObjectSetInteger(0, sentLabel, OBJPROP_XDISTANCE, PanelX+100);
      ObjectSetInteger(0, sentLabel, OBJPROP_YDISTANCE, PanelY+30+i*20);
      ObjectSetInteger(0, sentLabel, OBJPROP_CORNER, 0);
      ObjectSetString (0, sentLabel, OBJPROP_TEXT, "N/A");
      ObjectSetInteger(0, sentLabel, OBJPROP_COLOR, NeutralColor);
      ObjectSetString (0, sentLabel, OBJPROP_FONT, FontFace);
      ObjectSetInteger(0, sentLabel, OBJPROP_FONTSIZE, FontSize);
   }

   string fnl = indicatorName+"_Final";
   ObjectCreate(0, fnl, OBJ_LABEL, 0,0,0);
   ObjectSetInteger(0, fnl, OBJPROP_XDISTANCE, PanelX+10);
   ObjectSetInteger(0, fnl, OBJPROP_YDISTANCE, PanelY+100);
   ObjectSetInteger(0, fnl, OBJPROP_CORNER, 0);
   ObjectSetString (0, fnl, OBJPROP_TEXT, "Final: Neutral");
   ObjectSetInteger(0, fnl, OBJPROP_COLOR, NeutralColor);
   ObjectSetString (0, fnl, OBJPROP_FONT, FontFace);
   ObjectSetInteger(0, fnl, OBJPROP_FONTSIZE, FontSize+2);
}

//+------------------------------------------------------------------+
//| Panel Update                                                     |
//+------------------------------------------------------------------+
void UpdatePanel(int higherTFBias,
                 bool tf1Bullish, bool tf1Bearish,
                 bool tf2Bullish, bool tf2Bearish,
                 int sentiment)
{
    // Higher TF
    string txt="Neutral"; color col=NeutralColor;
    if(higherTFBias==1){txt="Bullish"; col=BullishColor;}
    else if(higherTFBias==-1){txt="Bearish"; col=BearishColor;}
    ObjectSetString(0, indicatorName+"_Sentiment0", OBJPROP_TEXT, txt);
    ObjectSetInteger(0, indicatorName+"_Sentiment0", OBJPROP_COLOR, col);

    // Lower TF1
    txt="Neutral"; col=NeutralColor;
    if(tf1Bullish){txt="Bullish"; col=BullishColor;}
    else if(tf1Bearish){txt="Bearish"; col=BearishColor;}
    ObjectSetString(0, indicatorName+"_Sentiment1", OBJPROP_TEXT, txt);
    ObjectSetInteger(0, indicatorName+"_Sentiment1", OBJPROP_COLOR, col);

    // Lower TF2
    txt="Neutral"; col=NeutralColor;
    if(tf2Bullish){txt="Bullish"; col=BullishColor;}
    else if(tf2Bearish){txt="Bearish"; col=BearishColor;}
    ObjectSetString(0, indicatorName+"_Sentiment2", OBJPROP_TEXT, txt);
    ObjectSetInteger(0, indicatorName+"_Sentiment2", OBJPROP_COLOR, col);

    // Final
    string finalSent="Neutral"; color finalCol=NeutralColor;
    switch(sentiment){
        case 1: finalSent="Bullish"; finalCol=BullishColor; break;
        case -1: finalSent="Bearish"; finalCol=BearishColor; break;
        case 2: finalSent="Risk-On"; finalCol=RiskOnColor; break;
        case -2: finalSent="Risk-Off"; finalCol=RiskOffColor; break;
    }
    ObjectSetString(0, indicatorName+"_Final", OBJPROP_TEXT, "Final: "+finalSent);
    ObjectSetInteger(0, indicatorName+"_Final", OBJPROP_COLOR, finalCol);
}