//+------------------------------------------------------------------+
//|                                           KT_Drawing_Tool_V2.mq5  |
//|                                  Copyright 2024, CD_SMC_Analysis |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, KT Expert."
#property link      "https://www.mql5.com/zh/users/lovellcecil" // 换成你的主页链接
#property version   "2.00" // 初始版本
#property description "KT Drawing Tool - Professional SMC & PA Drawing Assistant"
#property description " "
#property description "Key Features:"
#property description "1. OHLC Magnetic Adsorption: Automatically snaps to Key Prices."
#property description "2. Multi-Timeframe Color Mapping: Auto-color based on H1/H4/D1."
#property description "3. One-Click Ray & Level Drawing."
#property description "4. Visual confirmations with checkmarks."
#property description "Author WeChat: wglove921 |正版授权、续期及技术支持"
// #property icon      "Images\\KT_Logo.ico" // (可选) 如果你有做ICON的话

#property strict
#property indicator_chart_window
#property indicator_plots 0

#include <KTLicense/Products/KT_Drawing_Tool_V2.mqh>
#include <KTLicense/KT_Author_Info.mqh>

// MQL5 replacements for the MQL4 predefined market values used by the
// original drawing logic. Keeping these aliases local preserves the logic
// while making the conversion points explicit.
#define Point  _Point
#define Digits _Digits
#define Bid    SymbolInfoDouble(_Symbol, SYMBOL_BID)

//#region MARK: 模块--
//+------------------------------------------------------------------+
//| 枚举：周期可见性模式
//+------------------------------------------------------------------+
enum ENUM_VISIBILITY_MODE
{
   VISIBILITY_ALL = 0,        // All Timeframes
   VISIBILITY_CURRENT = 1,    // Current Only
   VISIBILITY_LOWER = 2,      // Current & Lower TFs
   VISIBILITY_HIGHER = 3      // Current & Higher TFs
};

//--- 参数设置
input color ColorHLine = clrRed;          // Horizontal Line Color
input color ColorRay   = clrDeepSkyBlue;  // Ray Color (Segment)
input int   LineWidth  = 1;               // Line Width

//--- [新增] 周期可见性控制
input ENUM_VISIBILITY_MODE VisibilityMode = VISIBILITY_ALL; // Timeframe Visibility Mode

input color BtnBgColor  = clrGray;        // Button Background Color
input color BtnTxtColor = clrWhite;       // Button Text Color

//--- FVG手动标注设置
input string Sep_FVG = "======= Manual FVG Mark ======="; // ----
input color  FVG_Bull_Color        = clrPaleGreen;      // Bullish FVG Color (Light Green)
input color  FVG_Bear_Color        = clrPeachPuff;      // Bearish FVG Color (Light Peach)
input color  FVG_Bull_Text_Color   = clrDarkGreen;      // Bullish FVG Text Color
input color  FVG_Bear_Text_Color   = clrFireBrick;      // Bearish FVG Text Color
input color  FVG_Midline_Color     = clrDarkGoldenrod;  // FVG 50% Line Color
input int    FVG_Extend_Bars       = 20;                // Extend Bars To Right
input int    FVG_Min_Points        = 0;                 // Minimum Gap Points (0=Off)
input bool   FVG_Show_Prices       = true;              // Show Upper/Lower Prices
input bool   FVG_Show_Distance     = true;              // Show Gap Distance
input bool   FVG_Show_Midline      = true;              // Show 50% Midline

//--- [新增] 周期专属颜色设置 (针对浅色背景 229,230,250 优化)
input color Color_H1   = clrBlue;         // H1 Timeframe Color
input color Color_H4   = clrDarkOrange;   // H4 Timeframe Color
input color Color_D1   = clrRed;          // D1 Timeframe Color
input color Color_W1   = clrDarkGreen;    // W1 Timeframe Color
input color Color_MN1  = clrDarkViolet;   // MN1 Timeframe Color
//#endregion

//#region MARK: 模块--
//--- [新增] 关口线功能设置
input string Sep_Round = "======= Round Number Lines ======="; // ----
input bool   Enable_Round_100  = false;         // Enable 100 Round Lines
input bool   Enable_Round_50   = false;         // Enable 50 Round Lines
input bool   Enable_Round_10   = false;         // Enable 10 Round Lines
input bool   Enable_Round_5    = false;         // Enable 5 Round Lines
// [已废弃] input int Round_Lines_Range = 500;  // 现在自动使用图表可见范围

input color  Color_Round_100   = clrDarkSlateGray;  // 100 Round Line Color
input color  Color_Round_50    = clrGray;           // 50 Round Line Color
input color  Color_Round_10    = clrLightGray;      // 10 Round Line Color
input color  Color_Round_5     = clrSilver;         // 5 Round Line Color

input int    Width_Round_100   = 2;             // 100 Round Line Width
input int    Width_Round_50    = 2;             // 50 Round Line Width
input int    Width_Round_10    = 1;             // 10 Round Line Width
input int    Width_Round_5     = 1;             // 5 Round Line Width

input ENUM_LINE_STYLE Style_Round_Key    = STYLE_SOLID;  // Key Round Lines Style (100/50)
input ENUM_LINE_STYLE Style_Round_Normal = STYLE_DOT;    // Normal Round Lines Style (10/5)
input bool   Enable_Log_RoundLines = false;         // Enable Round Lines Debug Log (可复用于其他日志开关)
//#endregion

//#region MARK: 模块--
//--- [新增] 北京日开盘标注功能
input string Sep_BJOpen = "======= Beijing Day Open Mark ======="; // ----
input bool   Enable_BJDayOpen_Mark   = false;          // Enable Beijing Day Open Mark
input int    Server_GMT_Offset       = 2;              // Server GMT Offset (2=Winter, 3=Summer)
input int    BJ_DayOpen_Hour         = 7;              // Beijing Open Hour (7=Winter, 6=Summer)
input int    Mark_Days_Range         = 7;              // Mark Recent Days (0=All History)
input bool   Only_H1_Period          = true;           // Only Show on H1 Chart
input bool   Show_BJDayOpen_Label    = true;           // Show Time Label
input color  BJDayOpen_Label_Color   = clrBlack;       // Label Text Color
input int    BJDayOpen_Label_Size    = 9;              // Label Font Size
//#endregion

//#region MARK: 模块--
//--- [新增] 亚盘高低点标注功能（M1源计算）
input string Sep_AsiaHL = "======= Asia Session High/Low ======="; // ----
input string Asia_Session_Name       = "Asia";         // Session Display Name
input string Asia_Session_Start_GMT  = "00:00";        // Session Start GMT (HH:MM)
input string Asia_Session_End_GMT    = "09:00";        // Session End GMT (HH:MM)
input bool   Asia_Session_AutoRefresh = true;           // Auto Refresh While Active
input int    Asia_Session_Refresh_Seconds = 30;         // Auto Refresh Interval (Sec)
input color  Asia_High_Ray_Color     = clrTomato;       // High Ray Color
input color  Asia_Low_Ray_Color      = clrDodgerBlue;   // Low Ray Color
input color  Asia_Session_Label_Color = clrBlack;       // Label Color
input int    Asia_Session_Label_Size = 9;               // Label Font Size

//--- [新增] 伦敦盘高低点标注功能（M1源计算）
input string Sep_LondonHL = "======= London Session High/Low ======="; // ----
input string London_Session_Name       = "London";      // Session Display Name
input string London_Session_Start_GMT  = "08:00";       // Session Start GMT (HH:MM)
input string London_Session_End_GMT    = "17:00";       // Session End GMT (HH:MM)
input bool   London_Session_AutoRefresh = true;          // Auto Refresh While Active
input int    London_Session_Refresh_Seconds = 30;        // Auto Refresh Interval (Sec)
input color  London_High_Ray_Color     = clrDarkOrange;  // High Ray Color
input color  London_Low_Ray_Color      = clrTeal;        // Low Ray Color
input color  London_Session_Label_Color = clrBlack;      // Label Color
input int    London_Session_Label_Size = 9;              // Label Font Size

//--- [新增] 纽约盘高低点标注功能（M1源计算）
input string Sep_NewYorkHL = "======= NewYork Session High/Low ======="; // ----
input string NewYork_Session_Name       = "NewYork";    // Session Display Name
input string NewYork_Session_Start_GMT  = "13:00";      // Session Start GMT (HH:MM)
input string NewYork_Session_End_GMT    = "22:00";      // Session End GMT (HH:MM)
input bool   NewYork_Session_AutoRefresh = true;         // Auto Refresh While Active
input int    NewYork_Session_Refresh_Seconds = 30;       // Auto Refresh Interval (Sec)
input color  NewYork_High_Ray_Color     = clrFireBrick;  // High Ray Color
input color  NewYork_Low_Ray_Color      = clrRoyalBlue;  // Low Ray Color
input color  NewYork_Session_Label_Color = clrBlack;     // Label Color
input int    NewYork_Session_Label_Size = 9;             // Label Font Size
//#endregion

//#region MARK: 模块--
//--- 内部变量
int drawingState = 0; // 0=无, 1=准备画水平线, 2=准备画射线
string btnName_MainMenu = "Btn_MainMenu";  // [新增] 主控菜单按钮
string btnName1 = "Btn_Draw_HLine";
string btnName2 = "Btn_Draw_Ray";
string btnName3 = "Btn_Clean_Current"; // Clean：删除当前周期的Draw_临时画线/FVG，保留Keep_对象
string btnName4 = "Btn_Clean_All";     // Clean All：二次确认后删除全部周期的Draw_临时画线/FVG，保留Keep_对象
string btnName5 = "Btn_Deselect_All";
string btnName6 = "Btn_Toggle_Mode";
string btnName7 = "Btn_Toggle_Magnet";
string btnName8 = "Btn_Stop_Mode";  // 新增：Stop模式按钮
string btnName9 = "Btn_Pinbar_Mode"; // [新增] Pinbar标注按钮
string btnName10 = "Btn_Force_Clear"; // Force Clear：无确认删除当前图表所有对象（包括Keep_、手动画线和UI按钮）
string btnName11 = "Btn_Lock_Lines";  // [新增] 锁定线条按钮
string btnName12 = "Btn_Toggle_Visibility"; // [新增] 隐藏/显示切换按钮
string btnName13 = "Btn_Asia_Session_HL"; // [新增] 亚盘高低点按钮
string btnName14 = "Btn_London_Session_HL"; // [新增] 伦敦盘高低点按钮
string btnName15 = "Btn_NewYork_Session_HL"; // [新增] 纽约盘高低点按钮
string btnName16 = "Btn_All_Session_HL"; // [新增] 三会话总开关按钮
string btnName17 = "Btn_FVG_Mode"; // FVG手动标注按钮
string btnName18 = "Btn_Clean_FVG_Current"; // Clean FVG：删除当前周期全部Draw_/Keep_ FVG
string btnName19 = "Btn_Clean_FVG_All";     // Clean All FVG：二次确认后删除全部周期Draw_/Keep_ FVG
string btnName20 = "Btn_Author_Contact";    // 作者联系方式
string btnName21 = "Btn_Crosshair_Info";    // 模拟十字准星与K线信息
string btnName22 = "Btn_Single_Candle_Fibo"; // 单K线黄金分割

// [新增] 菜单折叠状态
bool isMenuExpanded = false;  // false=折叠, true=展开

// [全局变量] 记录最后一次点击按钮的时间 (用于防误触)
uint lastBtnClickTime = 0;

// [新增] 绘图模式控制
bool isPermanentMode = true;   // false=临时模式(Draw_), true=保持模式(Keep_) [默认Keep模式]
bool isMagneticMode = true;    // true=启用磁吸, false=禁用磁吸（直接使用点击价格）
int stopOrderMode = 0;         // 0=关闭, 1=BUY stop, 2=SELL stop
bool isPinbarMode = false;     // [新增] Pinbar标注模式
bool isFVGMode = false;        // FVG手动标注模式
bool isSingleCandleFiboMode = false; // 单K线黄金分割模式
bool isLinesLocked = false;    // [新增] 线条锁定状态: false=解锁（可选择）, true=锁定（不可选择）

//#region MARK: 模块--模拟十字准星与K线信息
bool g_crosshairInfoVisible = false;
string g_crosshairVLineName = "KT_Crosshair_VLine";
string g_crosshairHLineName = "KT_Crosshair_HLine";
string g_crosshairInfoName = "KT_Crosshair_Info";
string g_crosshairInfoLineNames[4] =
   {"KT_Crosshair_Info_Line1", "KT_Crosshair_Info_Line2",
    "KT_Crosshair_Info_Line3", "KT_Crosshair_Info_Line4"};
int g_crosshairLastShift = -1;
double g_crosshairLastPrice = 0.0;
//#endregion

// [新增] 清除全部按钮的确认状态
bool cleanAllConfirmed = false;
uint cleanAllConfirmTime = 0;
const uint CONFIRM_TIMEOUT = 10000; // 10秒超时

// FVG全周期清理按钮使用独立确认状态，避免与普通Clean All互相触发
bool cleanAllFVGConfirmed = false;
uint cleanAllFVGConfirmTime = 0;

// [新增] 存储对象对关系：记录每个画线对象及其关联的标记对象
string g_drawnObjects[][2];  // [][0]=线对象名, [][1]=标记对象名 

// [新增] 关口线管理变量
uint lastRoundLinesUpdate = 0;          // 上次更新关口线的时间
const uint ROUND_UPDATE_INTERVAL = 60000; // 关口线更新间隔（60秒）

// [新增] 北京日开盘标注管理变量
uint lastBJDayOpenUpdate = 0;           // 上次更新北京日开盘标注的时间
const uint BJOPEN_UPDATE_INTERVAL = 60000; // 北京日开盘标注更新间隔（60秒）

// [新增] 亚盘高低点标注管理变量
bool isAsiaSessionHLVisible = false;
uint lastAsiaSessionHLUpdate = 0;
string g_lastAsiaSessionKey = "";
bool isLondonSessionHLVisible = false;
uint lastLondonSessionHLUpdate = 0;
string g_lastLondonSessionKey = "";
bool isNewYorkSessionHLVisible = false;
uint lastNewYorkSessionHLUpdate = 0;
string g_lastNewYorkSessionKey = "";

void UpdateAllSessionButtonUI();

struct SessionExtremesResult
{
   bool has_result;
   bool is_active;
   datetime session_start;
   datetime session_end;
   datetime calc_end;
   datetime high_time;
   datetime low_time;
   double high_price;
   double low_price;
};

// [新增] 线条显示/隐藏管理变量
bool isLinesHidden = false;           // 线条隐藏状态
string g_objectVisibility[][2];       // [][0]=对象名, [][1]=原始可见性标志 

bool g_ktDrawingToolAuthorized = false;
bool g_ktDrawingToolInitialized = false;
//#endregion

//+------------------------------------------------------------------+
//| 初始化函数
//+------------------------------------------------------------------+
void KT_DrawingTool_InitializeAfterLicense()
  {
   // [新增] 创建主控菜单按钮 (折叠时仅显示此按钮)
   CreateButton(btnName_MainMenu, "Menu", 150, 20, 80, 25, clrDodgerBlue, BtnTxtColor);
   
   // 创建UI按钮 (垂直排列，初始隐藏在屏幕外)
   CreateButton(btnName4, "Clean All", 150, -1000, 80, 25, clrMaroon,    BtnTxtColor); // 全周期Draw_清理，10秒内二次点击确认；Keep_保留
   CreateButton(btnName3, "Clean",     150, -1000, 80, 25, clrDarkOrange, BtnTxtColor); // 当前周期Draw_清理；Keep_和其他周期保留
   CreateButton(btnName1, "Line (H)",  150, -1000, 80, 25, BtnBgColor,    BtnTxtColor); // 灰色常规
   CreateButton(btnName2, "Ray (R)",   150, -1000, 80, 25, BtnBgColor,    BtnTxtColor); // 灰色常规
   CreateButton(btnName5, "Unselect",  150, -1000, 80, 25, clrDarkSlateGray, BtnTxtColor); // 深灰色辅助
   CreateButton(btnName6, "Keep",      150, -1000, 80, 25, clrDarkGreen, BtnTxtColor); // 模式切换（默认Keep）
   CreateButton(btnName7, "Magnet",    150, -1000, 80, 25, clrGreen,     BtnTxtColor); // 磁吸切换
   CreateButton(btnName8, "Normal",    150, -1000, 80, 25, clrGray,      BtnTxtColor); // Stop模式
   CreateButton(btnName9, "Pinbar",    150, -1000, 80, 25, clrGray,      BtnTxtColor); // Pinbar标注
   CreateButton(btnName10, "Force Clear", 150, -1000, 80, 25, clrCrimson, BtnTxtColor); // 无确认删除当前图表全部对象，按钮也会消失
   CreateButton(btnName11, "Unlock",     150, -1000, 80, 25, clrGray,    BtnTxtColor); // 锁定/解锁线条
   CreateButton(btnName12, "Hide All",   150, -1000, 80, 25, clrGray,    BtnTxtColor); // 隐藏/显示切换
   CreateButton(btnName13, "Asia H/L",   150, -1000, 80, 25, clrGray,    BtnTxtColor); // 亚盘高低点
   CreateButton(btnName14, "London H/L", 150, -1000, 80, 25, clrGray,    BtnTxtColor); // 伦敦盘高低点
   CreateButton(btnName15, "NY H/L",     150, -1000, 80, 25, clrGray,    BtnTxtColor); // 纽约盘高低点
   CreateButton(btnName16, "All H/L",    150, -1000, 80, 25, clrGray,    BtnTxtColor); // 三会话总开关
   CreateButton(btnName17, "FVG",        150, -1000, 80, 25, clrGray,    BtnTxtColor); // FVG手动标注
   CreateButton(btnName18, "Clean FVG",  150, -1000, 80, 25, clrDarkOrange, BtnTxtColor); // 当前周期全部Draw_/Keep_ FVG
   CreateButton(btnName19, "All FVG",    150, -1000, 80, 25, clrMaroon,  BtnTxtColor); // 全部周期FVG，需二次确认
   CreateButton(btnName20, "Author",     150, -1000, 80, 25, clrSteelBlue, BtnTxtColor); // 作者联系方式
   CreateButton(btnName21, "Crosshair",  150, -1000, 80, 25, clrDarkSlateBlue, BtnTxtColor); // 模拟十字准星与K线信息
   CreateButton(btnName22, "Candle Fibo", 150, -1000, 80, 25, clrDarkGoldenrod, BtnTxtColor); // 单K线黄金分割

   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true); // 开启鼠标捕捉
   
   // [新增] 启动定时器，每1秒检查一次对象是否被删除
   EventSetTimer(1);
   
   // [修复] 重启后重建对象关联关系
   RebuildObjectPairs();
   
   // [新增] 更新所有射线的终点到最新K线，防止射线"变短"
   UpdateRayEndpoints();
   
   // [新增] 绘制关口线
   DrawRoundNumberLines();
   
   // [新增] 绘制北京日开盘标注
   DrawBeijingDayOpenMarks();
   
   // [新增] 同步三会话总按钮初始状态
   UpdateAllSessionButtonUI();
   
   g_ktDrawingToolInitialized = true;
  }

int OnInit()
  {
   if(KTDrawingToolLicenseInitialize())
   {
      g_ktDrawingToolAuthorized = true;
      KT_DrawingTool_InitializeAfterLicense();
      return(INIT_SUCCEEDED);
   }

   if(KTLicenseIsWaitingForAccount())
   {
      EventSetTimer(1);
      Print("[KT License] Waiting for MT4 account connection before starting KT Drawing Tool");
      return(INIT_SUCCEEDED);
   }

   Alert("KT Drawing Tool authorization failed\n", KTLicenseGetMessage());
   Print("[KT License] Authorization failed: ", KTLicenseGetMessage());
   return(INIT_FAILED);
  }

//+------------------------------------------------------------------+
//| 反初始化函数
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // [新增] 安全机制：如果当前处于隐藏状态，自动恢复所有对象
   // 防止切换周期/重载指标时状态丢失导致对象永久不可见
   if(isLinesHidden)
   {
      int size = ArrayRange(g_objectVisibility, 0);
      
      for(int i = 0; i < size; i++)
      {
         string name = g_objectVisibility[i][0];
         long originalFlags = StringToInteger(g_objectVisibility[i][1]);
         
         if(ObjectFind(0, name) >= 0)
         {
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, originalFlags);
         }
      }
      
      // 清空记录并重置状态
      ArrayResize(g_objectVisibility, 0);
      isLinesHidden = false;
      
      // 如果是切换周期导致的重载，提示用户
      if(reason == REASON_CHARTCHANGE)
      {
         Print("[自动恢复] 检测到周期切换，已自动显示所有隐藏的画线");
      }
   }
   
   EventKillTimer();  // 关闭定时器
   
   // [新增] 删除所有关口线
   DeleteRoundNumberLines();
   
   // [新增] 删除所有北京日开盘标注
   DeleteBeijingDayOpenMarks();
   
   // [修复] 切换周期时保留会话标注对象，仅在非周期切换卸载时清理
   if(reason != REASON_CHARTCHANGE)
   {
      DeleteAsiaSessionHLObjects();
      DeleteLondonSessionHLObjects();
      DeleteNewYorkSessionHLObjects();
   }
   
   ObjectDelete(0, btnName_MainMenu);  // [新增] 删除主控按钮
   ObjectDelete(0, btnName1);
   ObjectDelete(0, btnName2);
   ObjectDelete(0, btnName3);
   ObjectDelete(0, btnName4);
   ObjectDelete(0, btnName5);
   ObjectDelete(0, btnName6);
   ObjectDelete(0, btnName7);
   ObjectDelete(0, btnName8);  // 删除Stop模式按钮
   ObjectDelete(0, btnName9);  // 删除Pinbar按钮
   ObjectDelete(0, btnName10); // 删除强制清除按钮
   ObjectDelete(0, btnName11); // 删除锁定线条按钮
   ObjectDelete(0, btnName12); // 删除隐藏/显示按钮
   ObjectDelete(0, btnName13); // 删除亚盘高低点按钮
   ObjectDelete(0, btnName14); // 删除伦敦盘高低点按钮
   ObjectDelete(0, btnName15); // 删除纽约盘高低点按钮
   ObjectDelete(0, btnName16); // 删除三会话总开关按钮
   ObjectDelete(0, btnName17); // 删除FVG按钮
   ObjectDelete(0, btnName18); // 删除当前周期FVG清理按钮
   ObjectDelete(0, btnName19); // 删除全部周期FVG清理按钮
   ObjectDelete(0, btnName20); // 删除作者联系方式按钮
   ObjectDelete(0, btnName21); // 删除模拟十字准星按钮
   ObjectDelete(0, btnName22); // 删除单K线黄金分割按钮
   DeleteCrosshairInfoObjects();

  }

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
  {
   if(!g_ktDrawingToolAuthorized)
      return(0);

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| [新增] 同步三会话总按钮状态显示                                  |
//+------------------------------------------------------------------+
void UpdateAllSessionButtonUI()
{
   if(ObjectFind(0, btnName16) < 0)
      return;

   bool allOn = isAsiaSessionHLVisible && isLondonSessionHLVisible && isNewYorkSessionHLVisible;
   bool anyOn = isAsiaSessionHLVisible || isLondonSessionHLVisible || isNewYorkSessionHLVisible;

   if(allOn)
   {
      ObjectSetString(0, btnName16, OBJPROP_TEXT, "All [ON]");
      ObjectSetInteger(0, btnName16, OBJPROP_BGCOLOR, clrDarkGreen);
   }
   else if(anyOn)
   {
      ObjectSetString(0, btnName16, OBJPROP_TEXT, "All [MIX]");
      ObjectSetInteger(0, btnName16, OBJPROP_BGCOLOR, clrDarkOrange);
   }
   else
   {
      ObjectSetString(0, btnName16, OBJPROP_TEXT, "All H/L");
      ObjectSetInteger(0, btnName16, OBJPROP_BGCOLOR, clrGray);
   }
}

//+------------------------------------------------------------------+
//| 图表事件处理函数 (核心逻辑)
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(!g_ktDrawingToolAuthorized)
      return;

   // =================================================================
   // 1. 监听按钮点击事件
   // =================================================================
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      // [新增] 处理主控菜单按钮点击
      if(sparam == btnName_MainMenu)
        {
         ObjectSetInteger(0, btnName_MainMenu, OBJPROP_STATE, false); // 立即弹起按钮
         
         // 切换菜单展开状态
         isMenuExpanded = !isMenuExpanded;
         
         if(isMenuExpanded)
         {
            // 展开菜单：显示所有功能按钮
            ObjectSetString(0, btnName_MainMenu, OBJPROP_TEXT, "Menu [^]");
            ObjectSetInteger(0, btnName_MainMenu, OBJPROP_BGCOLOR, clrDarkOrange);
            SetButtonVisibility(btnName4, true, 50);   // Clean All
            SetButtonVisibility(btnName3, true, 80);   // Clean
            SetButtonVisibility(btnName1, true, 110);  // Line (H)
            SetButtonVisibility(btnName2, true, 140);  // Ray (R)
            SetButtonVisibility(btnName5, true, 170);  // Unselect
            SetButtonVisibility(btnName6, true, 200);  // KeyLevel
            SetButtonVisibility(btnName7, true, 230);  // Magnet
            SetButtonVisibility(btnName8, true, 260);  // Normal
            SetButtonVisibility(btnName9, true, 290);  // Pinbar
            SetButtonVisibility(btnName10, true, 320); // Force Clear
            SetButtonVisibility(btnName11, true, 350); // Lock/Unlock
            SetButtonVisibility(btnName12, true, 380); // Hide/Show
            SetButtonVisibility(btnName13, true, 410); // Asia H/L
            SetButtonVisibility(btnName14, true, 440); // London H/L
            SetButtonVisibility(btnName15, true, 470); // NY H/L
            SetButtonVisibility(btnName16, true, 500); // All H/L
            SetButtonVisibility(btnName17, true, 530); // FVG
            SetButtonVisibility(btnName18, true, 560); // Clean FVG
            SetButtonVisibility(btnName19, true, 590); // All FVG
            SetButtonVisibility(btnName20, true, 620); // Author
            SetButtonVisibility(btnName21, true, 650); // Crosshair
            SetButtonVisibility(btnName22, true, 680); // Candle Fibo
         }
         else
         {
            // 折叠菜单：隐藏所有功能按钮
            ObjectSetString(0, btnName_MainMenu, OBJPROP_TEXT, "Menu");
            ObjectSetInteger(0, btnName_MainMenu, OBJPROP_BGCOLOR, clrDodgerBlue);
            SetButtonVisibility(btnName4, false, 0);
            SetButtonVisibility(btnName3, false, 0);
            SetButtonVisibility(btnName1, false, 0);
            SetButtonVisibility(btnName2, false, 0);
            SetButtonVisibility(btnName5, false, 0);
            SetButtonVisibility(btnName6, false, 0);
            SetButtonVisibility(btnName7, false, 0);
            SetButtonVisibility(btnName8, false, 0);
            SetButtonVisibility(btnName9, false, 0);
            SetButtonVisibility(btnName10, false, 0);
            SetButtonVisibility(btnName11, false, 0);
            SetButtonVisibility(btnName12, false, 0);
            SetButtonVisibility(btnName13, false, 0);
            SetButtonVisibility(btnName14, false, 0);
            SetButtonVisibility(btnName15, false, 0);
            SetButtonVisibility(btnName16, false, 0);
            SetButtonVisibility(btnName17, false, 0);
            SetButtonVisibility(btnName18, false, 0);
            SetButtonVisibility(btnName19, false, 0);
            SetButtonVisibility(btnName20, false, 0);
            SetButtonVisibility(btnName21, false, 0);
            SetButtonVisibility(btnName22, false, 0);
         }
         
         PlaySound("tick.wav");
         ChartRedraw();
        }

      if(sparam == btnName21)
        {
         ObjectSetInteger(0, btnName21, OBJPROP_STATE, false);
         g_crosshairInfoVisible = !g_crosshairInfoVisible;

         if(g_crosshairInfoVisible)
         {
            drawingState = 0;
            isPinbarMode = false;
            isFVGMode = false;
            ObjectSetInteger(0, btnName1, OBJPROP_STATE, false);
            ObjectSetInteger(0, btnName2, OBJPROP_STATE, false);
            ObjectSetString(0, btnName9, OBJPROP_TEXT, "Pinbar");
            ObjectSetInteger(0, btnName9, OBJPROP_BGCOLOR, clrGray);
            ObjectSetString(0, btnName17, OBJPROP_TEXT, "FVG");
            ObjectSetInteger(0, btnName17, OBJPROP_BGCOLOR, clrGray);
            ObjectSetString(0, btnName21, OBJPROP_TEXT, "Crosshair [ON]");
            ObjectSetInteger(0, btnName21, OBJPROP_BGCOLOR, clrDarkGreen);
            ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
            CreateCrosshairInfoObjects();
         }
         else
         {
            ObjectSetString(0, btnName21, OBJPROP_TEXT, "Crosshair");
            ObjectSetInteger(0, btnName21, OBJPROP_BGCOLOR, clrDarkSlateBlue);
            DeleteCrosshairInfoObjects();
         }

         lastBtnClickTime = GetTickCount();
         PlaySound("tick.wav");
         ChartRedraw();
        }

      if(sparam == btnName22)
        {
         ObjectSetInteger(0, btnName22, OBJPROP_STATE, false);
         isSingleCandleFiboMode = !isSingleCandleFiboMode;

         if(isSingleCandleFiboMode)
         {
            drawingState = 0;
            isPinbarMode = false;
            isFVGMode = false;
                  if(g_crosshairInfoVisible)
                     {
                      g_crosshairInfoVisible = false;
                      ObjectSetString(0, btnName21, OBJPROP_TEXT, "Crosshair");
                      ObjectSetInteger(0, btnName21, OBJPROP_BGCOLOR, clrDarkSlateBlue);
                      DeleteCrosshairInfoObjects();
                     }
            ObjectSetInteger(0, btnName1, OBJPROP_STATE, false);
            ObjectSetInteger(0, btnName2, OBJPROP_STATE, false);
            ObjectSetString(0, btnName9, OBJPROP_TEXT, "Pinbar");
            ObjectSetInteger(0, btnName9, OBJPROP_BGCOLOR, clrGray);
            ObjectSetString(0, btnName17, OBJPROP_TEXT, "FVG");
            ObjectSetInteger(0, btnName17, OBJPROP_BGCOLOR, clrGray);
            ObjectSetString(0, btnName22, OBJPROP_TEXT, "Candle Fibo [ON]");
            ObjectSetInteger(0, btnName22, OBJPROP_BGCOLOR, clrDarkGreen);
            ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
         }
         else
         {
            ObjectSetString(0, btnName22, OBJPROP_TEXT, "Candle Fibo");
            ObjectSetInteger(0, btnName22, OBJPROP_BGCOLOR, clrDarkGoldenrod);
            ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
         }

         lastBtnClickTime = GetTickCount();
         PlaySound("tick.wav");
         ChartRedraw();
        }
      
      if(sparam == btnName1 || sparam == btnName2)
        {
             isFVGMode = false;
             ObjectSetString(0, btnName17, OBJPROP_TEXT, "FVG");
             ObjectSetInteger(0, btnName17, OBJPROP_BGCOLOR, clrGray);
         // [UI优化] 让按钮立刻“弹起”，取消按下的凹陷效果。修改以后一点按下去的效果都没了

         // ObjectSetInteger(0, sparam, OBJPROP_STATE, false); 
         // [交互优化] 这里不要强制弹起！让它保持按下状态，直到画图结束。
         
         // 互斥逻辑：如果点了按钮1，就把按钮2弹起来；反之亦然。
         if(sparam == btnName1) {
            drawingState = 1;
            ObjectSetInteger(0, btnName2, OBJPROP_STATE, false); // 确保另一个按钮是弹起的
         }
         if(sparam == btnName2) {
            drawingState = 2;
            ObjectSetInteger(0, btnName1, OBJPROP_STATE, false); // 确保另一个按钮是弹起的
         }
         // if(sparam == btnName1) drawingState = 1;
         // if(sparam == btnName2) drawingState = 2;
         
         // [核心修复] 记录点击时间，防止穿透
         lastBtnClickTime = GetTickCount(); 
         
         ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
         // Comment("【进入画图模式】\n请点击K线，将自动吸附 开/高/低/收 价格...");
         PlaySound("tick.wav");
         ChartRedraw();
        }
      
      // Clean：仅清理当前图表周期下以Draw_开头的临时画线及FVG。
      // 不影响其他周期的Draw_对象，也不删除任何Keep_永久对象。
      if(sparam == btnName3)
        {
         ObjectSetInteger(0, btnName3, OBJPROP_STATE, false); // 立即弹起按钮
         CleanCurrentPeriodObjects(); // 执行清理
         PlaySound("ok.wav");
         ChartRedraw();
        }
      
      // Clean All：清理所有周期下以Draw_开头的临时画线及FVG，Keep_对象仍保留。
      // 为避免误操作，必须在10秒确认窗口内第二次点击才真正执行删除。
      if(sparam == btnName4)
        {
         ObjectSetInteger(0, btnName4, OBJPROP_STATE, false); // 立即弹起按钮
         
         uint currentTime = GetTickCount();
         
         // 检查是否在确认时间窗口内
         if(cleanAllConfirmed && (currentTime - cleanAllConfirmTime < CONFIRM_TIMEOUT))
         {
            // 第二次点击，执行删除
            CleanAllObjects();
            cleanAllConfirmed = false; // 重置确认状态
            // 恢复按钮颜色为深红色
            ObjectSetInteger(0, btnName4, OBJPROP_BGCOLOR, clrMaroon);
            ChartRedraw();
         }
         else
         {
            // 第一次点击，要求确认
            cleanAllConfirmed = true;
            cleanAllConfirmTime = currentTime;
            
            // 改变按钮颜色为红色警告
            ObjectSetInteger(0, btnName4, OBJPROP_BGCOLOR, clrCrimson);
            
            Alert(" 警告：将删除所有画线！\n\n请再次点击 [Clean All] 按钮以确认删除\n(", CONFIRM_TIMEOUT/1000, "秒内有效)");
            PlaySound("alert.wav");
            ChartRedraw();
         }
        }
      
      // [新增] 处理取消选中按钮点击
      if(sparam == btnName5)
        {
         ObjectSetInteger(0, btnName5, OBJPROP_STATE, false); // 立即弹起按钮
         DeselectAllLines(); // 执行取消选中
         PlaySound("tick.wav");
         ChartRedraw();
        }
      
      // [新增] 处理模式切换按钮点击
      if(sparam == btnName6)
        {
         ObjectSetInteger(0, btnName6, OBJPROP_STATE, false); // 立即弹起按钮
         
         // 切换模式
         isPermanentMode = !isPermanentMode;
         
         if(isPermanentMode)
         {
            // 切换到保持模式
            ObjectSetString(0, btnName6, OBJPROP_TEXT, "Keep");
            ObjectSetInteger(0, btnName6, OBJPROP_BGCOLOR, clrDarkGreen);
            Alert(" 已切换到【保持模式】\n画线将永久保留，不会被工具清理");
         }
         else
         {
            // 切换回关键位模式 关键位模式 就是用来给EA识别 交易用的，画线不带有Keep标记 也就是只有在关键位模式开启的状态下画的线才能被EA识别并执行一笔交易
            ObjectSetString(0, btnName6, OBJPROP_TEXT, "KeyLevel");
            ObjectSetInteger(0, btnName6, OBJPROP_BGCOLOR, clrGray);
            Alert(" 已切换到【关键位模式】\n画线可被工具按钮清理");
         }
         
         PlaySound("tick.wav");
         ChartRedraw();
        }
      
      // [新增] 处理磁吸切换按钮点击
      if(sparam == btnName7)
        {
         ObjectSetInteger(0, btnName7, OBJPROP_STATE, false); // 立即弹起按钮
         
         // 切换磁吸模式
         isMagneticMode = !isMagneticMode;
         
         if(isMagneticMode)
         {
            // 启用磁吸
            ObjectSetString(0, btnName7, OBJPROP_TEXT, "Magnet");
            ObjectSetInteger(0, btnName7, OBJPROP_BGCOLOR, clrGreen);
            Alert(" 磁吸功能已开启\n画线将自动吸附到最近的OHLC价格");
         }
         else
         {
            // 禁用磁吸
            ObjectSetString(0, btnName7, OBJPROP_TEXT, "Direct");
            ObjectSetInteger(0, btnName7, OBJPROP_BGCOLOR, clrGray);
            Alert(" 磁吸功能已关闭\n画线将直接使用鼠标点击价格");
         }
         
         PlaySound("tick.wav");
         ChartRedraw();
        }
      
      // [新增] 处理Stop模式按钮点击
      if(sparam == btnName8)
        {
         // 此按钮的作用是强制在画线中写入方向信息，强制此位置 只能做多或者只能做空 而跳过EA自动判断的做多和做空的方向逻辑
         ObjectSetInteger(0, btnName8, OBJPROP_STATE, false); // 立即弹起按钮
         
         // 循环切换模式：Normal → BUY stop → SELL stop → Normal
         stopOrderMode = (stopOrderMode + 1) % 3;
         
         switch(stopOrderMode)
         {
            case 0:  // Normal模式
               ObjectSetString(0, btnName8, OBJPROP_TEXT, "Normal");
               ObjectSetInteger(0, btnName8, OBJPROP_BGCOLOR, clrGray);
               // Alert(" 已切换到【普通模式】\n画线不带止损挂单标记");
               break;
            case 1:  // BUY stop模式
               ObjectSetString(0, btnName8, OBJPROP_TEXT, "BUY↑");
               ObjectSetInteger(0, btnName8, OBJPROP_BGCOLOR, clrGreen);
               // Alert(" 已切换到【BUY stop模式】\n画线将自动标记为 [BUY stop]\n价格回调到此位置时做多");
               break;
            case 2:  // SELL stop模式
               ObjectSetString(0, btnName8, OBJPROP_TEXT, "SELL↓");
               ObjectSetInteger(0, btnName8, OBJPROP_BGCOLOR, clrRed);
               // Alert(" 已切换到【SELL stop模式】\n画线将自动标记为 [SELL stop]\n价格回调到此位置时做空");
               break;
         }
         
         PlaySound("tick.wav");
         ChartRedraw();
        }
      
      // [新增] 处理Pinbar模式按钮点击
      if(sparam == btnName9)
        {
         ObjectSetInteger(0, btnName9, OBJPROP_STATE, false); // 立即弹起按钮
         
         // 切换Pinbar模式
         isPinbarMode = !isPinbarMode;
         
         if(isPinbarMode)
         {
            // 启用Pinbar模式
            ObjectSetString(0, btnName9, OBJPROP_TEXT, "Pinbar [ON]");
            ObjectSetInteger(0, btnName9, OBJPROP_BGCOLOR, clrDarkViolet);
            //Alert(" Pinbar标注模式已开启\n点击K线将自动识别Pinbar并画0.5/0.618位");
         }
         else
         {
            // 关闭Pinbar模式
            ObjectSetString(0, btnName9, OBJPROP_TEXT, "Pinbar");
            ObjectSetInteger(0, btnName9, OBJPROP_BGCOLOR, clrGray);
            //Alert(" Pinbar标注模式已关闭");
         }
         
         PlaySound("tick.wav");
         ChartRedraw();
        }

      // 处理FVG手动标注模式按钮点击
      if(sparam == btnName17)
        {
         ObjectSetInteger(0, btnName17, OBJPROP_STATE, false);
         isFVGMode = !isFVGMode;

         if(isFVGMode)
         {
            drawingState = 0;
            isPinbarMode = false;
            ObjectSetInteger(0, btnName1, OBJPROP_STATE, false);
            ObjectSetInteger(0, btnName2, OBJPROP_STATE, false);
            ObjectSetString(0, btnName9, OBJPROP_TEXT, "Pinbar");
            ObjectSetInteger(0, btnName9, OBJPROP_BGCOLOR, clrGray);
            ObjectSetString(0, btnName17, OBJPROP_TEXT, "FVG [ON]");
            ObjectSetInteger(0, btnName17, OBJPROP_BGCOLOR, clrDarkGreen);
            lastBtnClickTime = GetTickCount();
         }
         else
         {
            ObjectSetString(0, btnName17, OBJPROP_TEXT, "FVG");
            ObjectSetInteger(0, btnName17, OBJPROP_BGCOLOR, clrGray);
         }

         PlaySound("tick.wav");
         ChartRedraw();
        }

      // Clean FVG：直接删除当前周期全部Draw_/Keep_ FVG，不影响普通画线。
      if(sparam == btnName18)
        {
         ObjectSetInteger(0, btnName18, OBJPROP_STATE, false);
         CleanFVGObjects(false);
         PlaySound("ok.wav");
         ChartRedraw();
        }

      // All FVG：删除全部周期Draw_/Keep_ FVG；10秒内二次点击确认。
      if(sparam == btnName19)
        {
         ObjectSetInteger(0, btnName19, OBJPROP_STATE, false);
         uint currentFVGTime = GetTickCount();

         if(cleanAllFVGConfirmed && (currentFVGTime - cleanAllFVGConfirmTime < CONFIRM_TIMEOUT))
         {
            CleanFVGObjects(true);
            cleanAllFVGConfirmed = false;
            ObjectSetString(0, btnName19, OBJPROP_TEXT, "All FVG");
            ObjectSetInteger(0, btnName19, OBJPROP_BGCOLOR, clrMaroon);
            PlaySound("ok.wav");
         }
         else
         {
            cleanAllFVGConfirmed = true;
            cleanAllFVGConfirmTime = currentFVGTime;
            ObjectSetString(0, btnName19, OBJPROP_TEXT, "Confirm FVG");
            ObjectSetInteger(0, btnName19, OBJPROP_BGCOLOR, clrCrimson);
            Alert("警告：将删除全部周期的Draw_和Keep_ FVG！\n\n请在",
                  CONFIRM_TIMEOUT/1000, "秒内再次点击 [Confirm FVG] 确认");
            PlaySound("alert.wav");
         }

         ChartRedraw();
        }
      
      // Force Clear：紧急重置当前图表，无确认且不检查对象归属。
      // 会删除Draw_、Keep_、手动画线、其他指标对象和本指标UI按钮，按钮需重载指标后恢复。
      if(sparam == btnName10)
        {
         ObjectSetInteger(0, btnName10, OBJPROP_STATE, false); // 立即弹起按钮
         ForceCleanAllObjects(); // 强制清除所有对象
         PlaySound("ok.wav");
         ChartRedraw();
        }
      
      // [新增] 处理锁定/解锁按钮点击
      if(sparam == btnName11)
        {
         ObjectSetInteger(0, btnName11, OBJPROP_STATE, false); // 立即弹起按钮
         ToggleLinesLock(); // 切换锁定状态
         PlaySound("tick.wav");
         ChartRedraw();
        }
      
      // [新增] 处理隐藏/显示按钮点击
      if(sparam == btnName12)
        {
         ObjectSetInteger(0, btnName12, OBJPROP_STATE, false); // 立即弹起按钮
         ToggleLinesVisibility(); // 切换显示/隐藏
         PlaySound("tick.wav");
         ChartRedraw();
        }

      // [新增] 处理亚盘高低点按钮点击
      if(sparam == btnName13)
        {
         ObjectSetInteger(0, btnName13, OBJPROP_STATE, false);

         isAsiaSessionHLVisible = !isAsiaSessionHLVisible;

         if(isAsiaSessionHLVisible)
         {
            ObjectSetString(0, btnName13, OBJPROP_TEXT, "Asia [ON]");
            ObjectSetInteger(0, btnName13, OBJPROP_BGCOLOR, clrDarkGreen);
            if(RefreshAsiaSessionHighLow(true))
            {
               lastAsiaSessionHLUpdate = GetTickCount();
            }
            else
            {
               isAsiaSessionHLVisible = false;
               ObjectSetString(0, btnName13, OBJPROP_TEXT, "Asia H/L");
               ObjectSetInteger(0, btnName13, OBJPROP_BGCOLOR, clrGray);
               Alert("亚盘高低点计算失败，请先确认 M1 历史数据完整且时间参数有效");
            }
         }
         else
         {
            ObjectSetString(0, btnName13, OBJPROP_TEXT, "Asia H/L");
            ObjectSetInteger(0, btnName13, OBJPROP_BGCOLOR, clrGray);
            DeleteAsiaSessionHLObjects();
            g_lastAsiaSessionKey = "";
            lastAsiaSessionHLUpdate = 0;
         }

         UpdateAllSessionButtonUI();

         PlaySound("tick.wav");
         ChartRedraw();
        }

      // [新增] 处理伦敦盘高低点按钮点击
      if(sparam == btnName14)
        {
         ObjectSetInteger(0, btnName14, OBJPROP_STATE, false);

         isLondonSessionHLVisible = !isLondonSessionHLVisible;

         if(isLondonSessionHLVisible)
         {
            ObjectSetString(0, btnName14, OBJPROP_TEXT, "London [ON]");
            ObjectSetInteger(0, btnName14, OBJPROP_BGCOLOR, clrDarkGreen);
            if(RefreshLondonSessionHighLow(true))
            {
               lastLondonSessionHLUpdate = GetTickCount();
            }
            else
            {
               isLondonSessionHLVisible = false;
               ObjectSetString(0, btnName14, OBJPROP_TEXT, "London H/L");
               ObjectSetInteger(0, btnName14, OBJPROP_BGCOLOR, clrGray);
               Alert("伦敦盘高低点计算失败，请先确认 M1 历史数据完整且时间参数有效");
            }
         }
         else
         {
            ObjectSetString(0, btnName14, OBJPROP_TEXT, "London H/L");
            ObjectSetInteger(0, btnName14, OBJPROP_BGCOLOR, clrGray);
            DeleteLondonSessionHLObjects();
            g_lastLondonSessionKey = "";
            lastLondonSessionHLUpdate = 0;
         }

         UpdateAllSessionButtonUI();

         PlaySound("tick.wav");
         ChartRedraw();
        }

      // [新增] 处理纽约盘高低点按钮点击
      if(sparam == btnName15)
        {
         ObjectSetInteger(0, btnName15, OBJPROP_STATE, false);

         isNewYorkSessionHLVisible = !isNewYorkSessionHLVisible;

         if(isNewYorkSessionHLVisible)
         {
            ObjectSetString(0, btnName15, OBJPROP_TEXT, "NY [ON]");
            ObjectSetInteger(0, btnName15, OBJPROP_BGCOLOR, clrDarkGreen);
            if(RefreshNewYorkSessionHighLow(true))
            {
               lastNewYorkSessionHLUpdate = GetTickCount();
            }
            else
            {
               isNewYorkSessionHLVisible = false;
               ObjectSetString(0, btnName15, OBJPROP_TEXT, "NY H/L");
               ObjectSetInteger(0, btnName15, OBJPROP_BGCOLOR, clrGray);
               Alert("纽约盘高低点计算失败，请先确认 M1 历史数据完整且时间参数有效");
            }
         }
         else
         {
            ObjectSetString(0, btnName15, OBJPROP_TEXT, "NY H/L");
            ObjectSetInteger(0, btnName15, OBJPROP_BGCOLOR, clrGray);
            DeleteNewYorkSessionHLObjects();
            g_lastNewYorkSessionKey = "";
            lastNewYorkSessionHLUpdate = 0;
         }

         UpdateAllSessionButtonUI();

         PlaySound("tick.wav");
         ChartRedraw();
        }

      // [新增] 处理三会话总开关按钮点击
      if(sparam == btnName16)
        {
         ObjectSetInteger(0, btnName16, OBJPROP_STATE, false);

         bool enableAll = !(isAsiaSessionHLVisible && isLondonSessionHLVisible && isNewYorkSessionHLVisible);
         string failed = "";

         if(enableAll)
         {
            // --- Asia ---
            isAsiaSessionHLVisible = true;
            ObjectSetString(0, btnName13, OBJPROP_TEXT, "Asia [ON]");
            ObjectSetInteger(0, btnName13, OBJPROP_BGCOLOR, clrDarkGreen);
            if(RefreshAsiaSessionHighLow(true))
               lastAsiaSessionHLUpdate = GetTickCount();
            else
            {
               isAsiaSessionHLVisible = false;
               ObjectSetString(0, btnName13, OBJPROP_TEXT, "Asia H/L");
               ObjectSetInteger(0, btnName13, OBJPROP_BGCOLOR, clrGray);
               failed = failed + "Asia ";
            }

            // --- London ---
            isLondonSessionHLVisible = true;
            ObjectSetString(0, btnName14, OBJPROP_TEXT, "London [ON]");
            ObjectSetInteger(0, btnName14, OBJPROP_BGCOLOR, clrDarkGreen);
            if(RefreshLondonSessionHighLow(true))
               lastLondonSessionHLUpdate = GetTickCount();
            else
            {
               isLondonSessionHLVisible = false;
               ObjectSetString(0, btnName14, OBJPROP_TEXT, "London H/L");
               ObjectSetInteger(0, btnName14, OBJPROP_BGCOLOR, clrGray);
               failed = failed + "London ";
            }

            // --- NewYork ---
            isNewYorkSessionHLVisible = true;
            ObjectSetString(0, btnName15, OBJPROP_TEXT, "NY [ON]");
            ObjectSetInteger(0, btnName15, OBJPROP_BGCOLOR, clrDarkGreen);
            if(RefreshNewYorkSessionHighLow(true))
               lastNewYorkSessionHLUpdate = GetTickCount();
            else
            {
               isNewYorkSessionHLVisible = false;
               ObjectSetString(0, btnName15, OBJPROP_TEXT, "NY H/L");
               ObjectSetInteger(0, btnName15, OBJPROP_BGCOLOR, clrGray);
               failed = failed + "NY ";
            }

            if(StringLen(failed) > 0)
               Alert("以下会话计算失败: ", failed, "请检查 M1 历史数据或会话时间参数");
         }
         else
         {
            isAsiaSessionHLVisible = false;
            ObjectSetString(0, btnName13, OBJPROP_TEXT, "Asia H/L");
            ObjectSetInteger(0, btnName13, OBJPROP_BGCOLOR, clrGray);
            DeleteAsiaSessionHLObjects();
            g_lastAsiaSessionKey = "";
            lastAsiaSessionHLUpdate = 0;

            isLondonSessionHLVisible = false;
            ObjectSetString(0, btnName14, OBJPROP_TEXT, "London H/L");
            ObjectSetInteger(0, btnName14, OBJPROP_BGCOLOR, clrGray);
            DeleteLondonSessionHLObjects();
            g_lastLondonSessionKey = "";
            lastLondonSessionHLUpdate = 0;

            isNewYorkSessionHLVisible = false;
            ObjectSetString(0, btnName15, OBJPROP_TEXT, "NY H/L");
            ObjectSetInteger(0, btnName15, OBJPROP_BGCOLOR, clrGray);
            DeleteNewYorkSessionHLObjects();
            g_lastNewYorkSessionKey = "";
            lastNewYorkSessionHLUpdate = 0;
         }

         UpdateAllSessionButtonUI();

         PlaySound("tick.wav");
         ChartRedraw();
        }

         // 作者/联系方式
         if(sparam == btnName20)
           {
            ObjectSetInteger(0, btnName20, OBJPROP_STATE, false);
            Alert("KT Drawing Tool V2\n正版授权、续期及技术支持请联系作者\n",
               KT_AUTHOR_CONTACT_TEXT);
            PlaySound("tick.wav");
            ChartRedraw();
           }
     }

   // =================================================================
   // 2. 监听图表点击事件 (画图动作)
   // =================================================================
   if(id == CHARTEVENT_CLICK)
     {
      // [核心防御] 如果距离上次点按钮不到 500ms，忽略这次点击
      if (GetTickCount() - lastBtnClickTime < 500) return;

         if(isSingleCandleFiboMode)
            {
             datetime fiboClickTime = 0;
             double fiboClickPrice = 0;
             int fiboWindow = 0;

             if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, fiboWindow, fiboClickTime, fiboClickPrice))
                {
                  if(fiboWindow == 0)
                     {
                      int fiboBarIndex = iBarShift(NULL, 0, fiboClickTime, false);
                      int fiboBars = iBars(NULL, 0);

                      if(fiboBarIndex >= 0 && fiboBarIndex < fiboBars)
                         {
                           double fiboOpen = iOpen(NULL, 0, fiboBarIndex);
                           double fiboClose = iClose(NULL, 0, fiboBarIndex);

                           if(fiboClose == fiboOpen)
                              {
                               Alert("当前K线为十字星，无法判断阳线或阴线");
                               PlaySound("timeout.wav");
                              }
                           else
                              {
                               DrawSingleCandleFibonacci(fiboBarIndex, fiboClose > fiboOpen);
                               PlaySound("ok.wav");
                              }
                         }
                     }
                }

             isSingleCandleFiboMode = false;
             ObjectSetString(0, btnName22, OBJPROP_TEXT, "Candle Fibo");
             ObjectSetInteger(0, btnName22, OBJPROP_BGCOLOR, clrDarkGoldenrod);
             ObjectSetInteger(0, btnName22, OBJPROP_STATE, false);
             ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
             ChartRedraw();
             return;
            }

         if(isFVGMode)
            {
             datetime fvgClickTime = 0;
             double fvgClickPrice = 0;
             int fvgWindow = 0;

             if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, fvgWindow, fvgClickTime, fvgClickPrice))
             {
                  int fvgBarIndex = iBarShift(NULL, 0, fvgClickTime);
                  DrawFVGAtBar(fvgBarIndex);
             }

             isFVGMode = false;
             ObjectSetString(0, btnName17, OBJPROP_TEXT, "FVG");
             ObjectSetInteger(0, btnName17, OBJPROP_BGCOLOR, clrGray);
             ChartRedraw();
             return;
            }

      if(drawingState != 0)
        {
         datetime dt = 0;
         double price = 0;
         int window = 0;
         
         if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, window, dt, price))
           {
            // -------------------------------------------------------------
            // 核心功能升级：全能磁吸逻辑 (OHLC Adsorption)
            // -------------------------------------------------------------
            int barIndex = iBarShift(NULL, 0, dt); // 找到点击位置对应的K线索引
            double finalPrice;
            
            // 获取K线的OHLC数据（用于磁吸计算和Check标记判断）
            double high  = iHigh(NULL, 0, barIndex);
            double low   = iLow(NULL, 0, barIndex);
            double open  = iOpen(NULL, 0, barIndex);
            double close = iClose(NULL, 0, barIndex);
            
            if(isMagneticMode) // 启用磁吸
            {
               // 计算鼠标点击位置与这四个价格的距离
               double distH = MathAbs(price - high);
               double distL = MathAbs(price - low);
               double distO = MathAbs(price - open);
               double distC = MathAbs(price - close);
               
               // 找出距离最近的那个价格
               finalPrice = high;      // 默认先假设 High 最近
               double minDist = distH; // 记录最小距离
               
               if(distL < minDist) { minDist = distL; finalPrice = low;   }
               if(distO < minDist) { minDist = distO; finalPrice = open;  }
               if(distC < minDist) { minDist = distC; finalPrice = close; }
            }
            else // 禁用磁吸，直接使用鼠标点击价格
            {
               finalPrice = price; // 直接使用鼠标点击位置的价格
            }
            
            // -------------------------------------------------------------
            // [新增] Pinbar模式检测与处理
            // -------------------------------------------------------------
            if(isPinbarMode)
            {
               // 递进检测：先尝试严格标准，再尝试宽松标准
               int pinbarType = IsPinbar(barIndex);
               if(pinbarType == 0)  // 严格检测失败，尝试宽松检测
               {
                  pinbarType = IsPinbarV2(barIndex);
               }
               
               if(pinbarType == 0)
               {
                  // 不是Pinbar，提示并退出
                  Alert(" 这不是一个标准Pinbar！\n请选择具有明显长影线的K线");
                  PlaySound("timeout.wav");
                  // 重置状态
                  drawingState = 0;
                  ObjectSetInteger(0, btnName1, OBJPROP_STATE, false);
                  ObjectSetInteger(0, btnName2, OBJPROP_STATE, false);
                  ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
                  ChartRedraw();
                  return;
               }
               
               // 是Pinbar，计算0.5和0.618位置
               double level50, level618;
               string pinbarTypeStr;
               
               if(pinbarType == 1)  // 看涨Pinbar（长下影线，从高到低回撤）
               {
                  double range = high - low;
                  // 斐波0%=最高价, 100%=最低价
                  level50  = high - range * 0.5;    // 50%回撤（在上方）
                  level618 = high - range * 0.618;  // 61.8%回撤（在下方）
                  pinbarTypeStr = "[Bull Pin]";
               }
               else  // 看跌Pinbar (pinbarType == 2)（长上影线，从低到高回撤）
               {
                  double range = high - low;
                  // 斐波0%=最低价, 100%=最高价
                  level50  = low + range * 0.5;     // 50%回撤（在下方）
                  level618 = low + range * 0.618;   // 61.8%回撤（在上方）
                  pinbarTypeStr = "[Bear Pin]";
               }
               
               // [新增] 自动匹配周期颜色（与常规模式保持一致）
               color levelColor;
               int p = Period();
               
               if      (p == PERIOD_H1)  levelColor = Color_H1;
               else if (p == PERIOD_H4)  levelColor = Color_H4;
               else if (p == PERIOD_D1)  levelColor = Color_D1;
               else if (p == PERIOD_W1)  levelColor = Color_W1;
               else if (p == PERIOD_MN1) levelColor = Color_MN1;
               else
               {
                  // 如果不是特定周期，使用默认设置 (区分水平线和射线)
                  levelColor = (drawingState == 1) ? ColorHLine : ColorRay;
               }
               
               // 画两条线（0.5和0.618）
               string tfStr = GetPeriodName(Period());
               string uniqueID = IntegerToString(GetTickCount());
               string prefix = isPermanentMode ? "Keep_" : "Draw_";
               
               // 第一条线：0.5位
               string objName50 = prefix + tfStr + "_Pin50_" + uniqueID;
               // 第二条线：0.618位
               string objName618 = prefix + tfStr + "_Pin618_" + uniqueID;
               
               // 应用周期可见性设置
               int visibilityFlags = CalculateVisibilityFlags(Period(), VisibilityMode);
               
               if(drawingState == 1)  // 画水平线
               {
                  // 创建0.5线
                  ObjectCreate(0, objName50, OBJ_HLINE, 0, 0, level50);
                  ObjectSetInteger(0, objName50, OBJPROP_COLOR, levelColor);
                  ObjectSetInteger(0, objName50, OBJPROP_WIDTH, LineWidth);
                  ObjectSetInteger(0, objName50, OBJPROP_STYLE, STYLE_DOT);  // 虚线
                  ObjectSetString(0, objName50, OBJPROP_TEXT, pinbarTypeStr + " 0.5 @" + DoubleToString(level50, Digits));
                  ObjectSetInteger(0, objName50, OBJPROP_SELECTABLE, !isLinesLocked);
                  ObjectSetInteger(0, objName50, OBJPROP_TIMEFRAMES, visibilityFlags);
                  
                  // 创建0.618线
                  ObjectCreate(0, objName618, OBJ_HLINE, 0, 0, level618);
                  ObjectSetInteger(0, objName618, OBJPROP_COLOR, levelColor);
                  ObjectSetInteger(0, objName618, OBJPROP_WIDTH, LineWidth);
                  ObjectSetString(0, objName618, OBJPROP_TEXT, pinbarTypeStr + " 0.618 @" + DoubleToString(level618, Digits));
                  ObjectSetInteger(0, objName618, OBJPROP_SELECTABLE, !isLinesLocked);
                  ObjectSetInteger(0, objName618, OBJPROP_TIMEFRAMES, visibilityFlags);
               }
               else if(drawingState == 2)  // 画射线
               {
                  datetime time1 = iTime(NULL, 0, barIndex);
                  datetime currentTime = iTime(Symbol(), Period(), 0);
                  
                  // 创建0.5射线
                  ObjectCreate(0, objName50, OBJ_TREND, 0, time1, level50, currentTime, level50);
                  ObjectSetInteger(0, objName50, OBJPROP_COLOR, levelColor);
                  ObjectSetInteger(0, objName50, OBJPROP_WIDTH, LineWidth);
                  ObjectSetInteger(0, objName50, OBJPROP_STYLE, STYLE_DOT);
                  ObjectSetInteger(0, objName50, OBJPROP_RAY_RIGHT, false);
                  ObjectSetString(0, objName50, OBJPROP_TEXT, pinbarTypeStr + " 0.5 @" + DoubleToString(level50, Digits));
                  ObjectSetInteger(0, objName50, OBJPROP_SELECTABLE, !isLinesLocked);
                  ObjectSetInteger(0, objName50, OBJPROP_TIMEFRAMES, visibilityFlags);
                  
                  // 创建0.618射线
                  ObjectCreate(0, objName618, OBJ_TREND, 0, time1, level618, currentTime, level618);
                  ObjectSetInteger(0, objName618, OBJPROP_COLOR, levelColor);
                  ObjectSetInteger(0, objName618, OBJPROP_WIDTH, LineWidth);
                  ObjectSetInteger(0, objName618, OBJPROP_RAY_RIGHT, false);
                  ObjectSetString(0, objName618, OBJPROP_TEXT, pinbarTypeStr + " 0.618 @" + DoubleToString(level618, Digits));
                  ObjectSetInteger(0, objName618, OBJPROP_SELECTABLE, !isLinesLocked);
                  ObjectSetInteger(0, objName618, OBJPROP_TIMEFRAMES, visibilityFlags);
                  
                  // 创建价格标签
                  string labelPrefix = isPermanentMode ? "KeepLabel_" : "PriceLabel_";
                  string priceLabel50 = labelPrefix + tfStr + "_Pin50_" + uniqueID;
                  string priceLabel618 = labelPrefix + tfStr + "_Pin618_" + uniqueID;
                  
                  ObjectCreate(0, priceLabel50, OBJ_ARROW_RIGHT_PRICE, 0, currentTime, level50);
                  ObjectSetInteger(0, priceLabel50, OBJPROP_COLOR, levelColor);
                  ObjectSetInteger(0, priceLabel50, OBJPROP_WIDTH, 1);
                  ObjectSetInteger(0, priceLabel50, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(0, priceLabel50, OBJPROP_HIDDEN, true);
                  RecordObjectPair(objName50, priceLabel50);
                  
                  ObjectCreate(0, priceLabel618, OBJ_ARROW_RIGHT_PRICE, 0, currentTime, level618);
                  ObjectSetInteger(0, priceLabel618, OBJPROP_COLOR, levelColor);
                  ObjectSetInteger(0, priceLabel618, OBJPROP_WIDTH, 1);
                  ObjectSetInteger(0, priceLabel618, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(0, priceLabel618, OBJPROP_HIDDEN, true);
                  RecordObjectPair(objName618, priceLabel618);
               }
               /*
               // 在Pinbar的尾部画标记（长影线端）
               datetime time1 = iTime(NULL, 0, barIndex);
               double markPrice = (pinbarType == 1) ? low : high;
               
               string markPrefix = isPermanentMode ? "KeepMark_" : "Mark_";
               string markName = markPrefix + tfStr + "_PinMark_" + uniqueID;
               
               int arrowCode = (pinbarType == 1) ? 233 : 234;  // 233=向上箭头, 234=向下箭头
               ObjectCreate(0, markName, OBJ_ARROW, 0, time1, markPrice);
               ObjectSetInteger(0, markName, OBJPROP_ARROWCODE, arrowCode);
               ObjectSetInteger(0, markName, OBJPROP_COLOR, levelColor);
               ObjectSetInteger(0, markName, OBJPROP_WIDTH, 3);
               ObjectSetInteger(0, markName, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, markName, OBJPROP_HIDDEN, true);
               RecordObjectPair(objName50, markName);
               */
               PlaySound("ok.wav");
               //Alert(" Pinbar识别成功！\n类型：", pinbarTypeStr, "\n已画0.5和0.618位");
               
               // 重置状态
               isPinbarMode = false;  // 自动关闭Pinbar模式
               ObjectSetString(0, btnName9, OBJPROP_TEXT, "Pinbar");
               ObjectSetInteger(0, btnName9, OBJPROP_BGCOLOR, clrGray);
               
               drawingState = 0;
               ObjectSetInteger(0, btnName1, OBJPROP_STATE, false);
               ObjectSetInteger(0, btnName2, OBJPROP_STATE, false);
               ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
               ChartRedraw();
               return;  // 跳过常规画线逻辑
            }
            
            // -------------------------------------------------------------
            // 执行画图（常规模式）
            // -------------------------------------------------------------
            string tfStr = GetPeriodName(Period());
            // [修改] 生成唯一ID，用于关联线条和标记
            string uniqueID = IntegerToString(GetTickCount());
            // [新增] 根据模式动态生成对象前缀
            string prefix = isPermanentMode ? "Keep_" : "Draw_";
            string objName = prefix + tfStr + "_" + uniqueID;

            // --- [新增] 自动匹配周期颜色 ---
            color finalColor;
            int p = Period();

            if      (p == PERIOD_H1)  finalColor = Color_H1;
            else if (p == PERIOD_H4)  finalColor = Color_H4;
            else if (p == PERIOD_D1)  finalColor = Color_D1;
            else if (p == PERIOD_W1)  finalColor = Color_W1;
            else if (p == PERIOD_MN1) finalColor = Color_MN1;
            else
            {
               // 如果不是特定周期，使用默认设置 (区分水平线和射线)
               finalColor = (drawingState == 1) ? ColorHLine : ColorRay;
            }
            // ------------------------------

            if(drawingState == 1) // 画水平线
              {
               ObjectCreate(0, objName, OBJ_HLINE, 0, 0, finalPrice);
               ObjectSetInteger(0, objName, OBJPROP_COLOR, finalColor);
               ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
               ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, !isLinesLocked);
               
               // [新增] 应用周期可见性设置
               int visibilityFlags = CalculateVisibilityFlags(Period(), VisibilityMode);
               ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, visibilityFlags);
               
               // ⭐[新增] 根据Stop模式自动设置画线描述
               if(stopOrderMode == 1)
                  ObjectSetString(0, objName, OBJPROP_TEXT, "[BUY stop] @" + DoubleToString(finalPrice, Digits));
               else if(stopOrderMode == 2)
                  ObjectSetString(0, objName, OBJPROP_TEXT, "[SELL stop] @" + DoubleToString(finalPrice, Digits));
               else
                  ObjectSetString(0, objName, OBJPROP_TEXT, "@" + DoubleToString(finalPrice, Digits));
               
               // [新增功能] 在磁吸的K线上绘制Check标记（仅在磁吸模式下）
               if(isMagneticMode)
               {
                  bool isBullish = (close > open); // 判断阳线/阴线
                  double markPrice = isBullish ? (high + 5 * Point) : (low - 5 * Point); // 阳线标记在最高价上方，阴线在最低价下方
                  datetime time1 = iTime(NULL, 0, barIndex);
                  // [修改] 使用相同的uniqueID，建立名称关联，根据模式使用不同前缀
                  string markPrefix = isPermanentMode ? "KeepMark_" : "Mark_";
                  string markName = markPrefix + tfStr + "_" + uniqueID;
                  
                  ObjectCreate(0, markName, OBJ_ARROW_CHECK, 0, time1, markPrice);
                  ObjectSetInteger(0, markName, OBJPROP_COLOR, finalColor);
                  ObjectSetInteger(0, markName, OBJPROP_WIDTH, 2);
                  ObjectSetInteger(0, markName, OBJPROP_ANCHOR, isBullish ? ANCHOR_BOTTOM : ANCHOR_TOP); // 阳线锚点在下，阴线锚点在上
                  ObjectSetInteger(0, markName, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(0, markName, OBJPROP_HIDDEN, true);
                  // [新增] 记录对象对关系
                  RecordObjectPair(objName, markName);
               }
              }
            else if(drawingState == 2) // 画射线
              {
               datetime time1 = iTime(NULL, 0, barIndex);
               // [修夏] 使用 iTime 获取当前K线时间
               datetime currentTime = iTime(Symbol(), Period(), 0);
               ObjectCreate(0, objName, OBJ_TREND, 0, time1, finalPrice, currentTime, finalPrice);
               ObjectSetInteger(0, objName, OBJPROP_COLOR, finalColor);
               ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
               ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, !isLinesLocked);
               
               // [新增] 应用周期可见性设置
               int visibilityFlags = CalculateVisibilityFlags(Period(), VisibilityMode);
               ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, visibilityFlags);
               
               // ⭐[新增] 根据Stop模式自动设置画线描述
               if(stopOrderMode == 1)
                  ObjectSetString(0, objName, OBJPROP_TEXT, "[BUY stop] @" + DoubleToString(finalPrice, Digits));
               else if(stopOrderMode == 2)
                  ObjectSetString(0, objName, OBJPROP_TEXT, "[SELL stop] @" + DoubleToString(finalPrice, Digits));
               else
                  ObjectSetString(0, objName, OBJPROP_TEXT, "@" + DoubleToString(finalPrice, Digits));
               
               // [新增功能] 在图表右侧价格轴显示射线价格标签
               // [修改] 使用uniqueID建立关联，根据模式使用不同前缀
               string labelPrefix = isPermanentMode ? "KeepLabel_" : "PriceLabel_";
               string priceLabelName = labelPrefix + tfStr + "_" + uniqueID;
               ObjectCreate(0, priceLabelName, OBJ_ARROW_RIGHT_PRICE, 0, currentTime, finalPrice);
               ObjectSetInteger(0, priceLabelName, OBJPROP_COLOR, finalColor);
               ObjectSetInteger(0, priceLabelName, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, priceLabelName, OBJPROP_SELECTABLE, false); // 不可选中，避免干扰
               ObjectSetInteger(0, priceLabelName, OBJPROP_HIDDEN, true); // 在对象列表中隐藏
               // 价格标签关联到射线
               RecordObjectPair(objName, priceLabelName);
               
               // [新增功能] 在磁吸的K线上绘制Check标记（仅在磁吸模式下）
               if(isMagneticMode)
               {
                  bool isBullish = (close > open); // 判断阳线/阴线
                  double markPrice = isBullish ? (high + 5 * Point) : (low - 5 * Point); // 阳线标记在最高价上方，阴线在最低价下方
                  // [修改] 使用相同的uniqueID，根据模式使用不同前缀
                  string markPrefix = isPermanentMode ? "KeepMark_" : "Mark_";
                  string markName = markPrefix + tfStr + "_" + uniqueID;
                  
                  ObjectCreate(0, markName, OBJ_ARROW_CHECK, 0, time1, markPrice);
                  ObjectSetInteger(0, markName, OBJPROP_COLOR, finalColor);
                  ObjectSetInteger(0, markName, OBJPROP_WIDTH, 2);
                  ObjectSetInteger(0, markName, OBJPROP_ANCHOR, isBullish ? ANCHOR_BOTTOM : ANCHOR_TOP); // 阳线锚点在下，阴线锚点在上
                  ObjectSetInteger(0, markName, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(0, markName, OBJPROP_HIDDEN, true);
                  // [新增] 记录对象对关系
                  RecordObjectPair(objName, markName);
               }
              }
            
            ChartRedraw();
            PlaySound("ok.wav");
           }
         
         // [交互优化] 画完图了！现在才把按钮弹起来，表示“任务结束”
         ObjectSetInteger(0, btnName1, OBJPROP_STATE, false);
         ObjectSetInteger(0, btnName2, OBJPROP_STATE, false);
           
         // 3. 重置状态
         drawingState = 0;
         ChartSetInteger(0, CHART_MOUSE_SCROLL, true); 

         ChartRedraw(); // 强制刷新界面状态
        }
     }
   
    if(id == CHARTEVENT_MOUSE_MOVE && g_crosshairInfoVisible)
       {
         UpdateCrosshairInfo((int)lparam, (int)dparam);
       }

    // =================================================================
    // 3. 监听图表变化事件（缩放、滚动）
    // =================================================================
   if(id == CHARTEVENT_CHART_CHANGE)
     {
      // 当图表缩放或滚动时，更新关口线
      UpdateRoundNumberLines();
     }
  }

//+------------------------------------------------------------------+
//| 辅助函数：创建按钮
//+------------------------------------------------------------------+
void CreateButton(string name, string text, int x, int y, int w, int h, color bg, color txt)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, name, OBJPROP_COLOR, txt);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true); // 不在对象列表中显示按钮
     }
  }

//#region MARK: 模块--单K线黄金分割
//+------------------------------------------------------------------+
//| DrawSingleCandleFibonacci: 按单根K线的High/Low绘制黄金分割      |
//| 阳线: Low为Fibo 0, High为Fibo 1                             |
//| 阴线: High为Fibo 0, Low为Fibo 1                             |
//+------------------------------------------------------------------+
void DrawSingleCandleFibonacci(int bar_index, bool is_bullish)
{
   int total_bars = iBars(NULL, 0);
   if(bar_index < 0 || bar_index >= total_bars)
      return;

   datetime bar_time = iTime(NULL, 0, bar_index);
   double fibo_price0 = is_bullish ? iLow(NULL, 0, bar_index) : iHigh(NULL, 0, bar_index);
   double fibo_price1 = is_bullish ? iHigh(NULL, 0, bar_index) : iLow(NULL, 0, bar_index);

   if(bar_time <= 0 || fibo_price0 <= 0.0 || fibo_price1 <= 0.0 || fibo_price0 == fibo_price1)
      return;

   double custom_values[] =
   {
      0.0, 1.0, 0.12, 0.214, 0.236, 0.382, 0.500, 0.618,
      0.786, 0.880, 1.618, 1.786, 1.880, 2.618, 2.786, 2.880,
      4.236, 4.786, 4.880, 2, 3, 4, 5, 6, 7, 8, 9, 10,
      11, 12, 13, 14
   };

   string custom_texts[] =
   {
      "Base %$", "Setup %$", "0.12 %$", "0.214 %$", "0.236 Major %$",
      "0.382 Minor %$", "50 %$", "0.618 PullBack %$", "0.786 PullBack %$",
      "0.880 PullBack %$", "TP1-1.618-%$", "1MAX-%$", "1MAX-%$",
      "TP2-2.618-%$", "2MAX-%$", "2MAX-%$", "TP3-4.236-%$", "3MAX-%$",
      "3MAX-%$", "1:1的位置-%$", "1:2的位置-%$", "1:3的位置-%$",
      "1:4的位置-%$", "1:5的位置-%$", "1:6的位置-%$", "1:7的位置-%$",
      "1:8的位置-%$", "1:9的位置-%$", "1:10的位置-%$", "1:11的位置-%$",
      "1:12的位置-%$", "1:13的位置-%$"
   };

   string prefix = isPermanentMode ? "Keep_" : "Draw_";
   string tf_name = GetPeriodName(Period());
   string direction = is_bullish ? "B_" : "S_";
   string object_name = prefix + tf_name + "_SingleCandleFibo_" + direction +
                        IntegerToString((long)bar_time) + "_" + IntegerToString(GetTickCount());

   // 旧实现：MT4会将两个锚点解释为反向的Fibo 0/Fibo 1，因此显示方向相反。
   // if(!ObjectCreate(0, object_name, OBJ_FIBO, 0, bar_time, fibo_price0, bar_time, fibo_price1))
   //    return;

   // 新实现：交换两个锚点，使自定义级别中的0.0和1.0符合预期方向。
   if(!ObjectCreate(0, object_name, OBJ_FIBO, 0, bar_time, fibo_price1, bar_time, fibo_price0))
      return;

   int level_count = ArraySize(custom_values);
   int visibility_flags = CalculateVisibilityFlags(Period(), VisibilityMode);

   ObjectSetInteger(0, object_name, OBJPROP_BACK, true);
   ObjectSetInteger(0, object_name, OBJPROP_RAY, false);
   ObjectSetInteger(0, object_name, OBJPROP_SELECTABLE, !isLinesLocked);
   ObjectSetInteger(0, object_name, OBJPROP_COLOR, is_bullish ? clrGreen : clrMagenta);
   ObjectSetInteger(0, object_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, object_name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, object_name, OBJPROP_TIMEFRAMES, visibility_flags);
   ObjectSetString(0, object_name, OBJPROP_TEXT,
                   "Single Candle Fibo " + tf_name + (is_bullish ? " Bull " : " Bear "));
   ObjectSetInteger(0, object_name, OBJPROP_LEVELS, level_count);

   for(int level_index = 0; level_index < level_count; level_index++)
     {
      ObjectSetDouble(0, object_name, OBJPROP_LEVELVALUE, level_index, custom_values[level_index]);
      ObjectSetString(0, object_name, OBJPROP_LEVELTEXT, level_index, custom_texts[level_index]);
      ObjectSetInteger(0, object_name, OBJPROP_LEVELCOLOR, level_index, clrBlack);
      ObjectSetInteger(0, object_name, OBJPROP_LEVELSTYLE, level_index, STYLE_SOLID);
      ObjectSetInteger(0, object_name, OBJPROP_LEVELWIDTH, level_index, 1);
     }
}
//#endregion

//+------------------------------------------------------------------+
//| [新增] 辅助函数：获取周期短名称
//+------------------------------------------------------------------+
string GetPeriodName(int p)
{
   switch(p)
   {
      case PERIOD_CURRENT: return "CURRENT";
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
   }
   return "Unknown";
}

//+------------------------------------------------------------------+
//| 在用户指定的中间K线上识别并绘制三蜡烛FVG                     |
//+------------------------------------------------------------------+
bool DrawFVGAtBar(int middleBar)
{
   int totalBars = iBars(NULL, 0);
   if(middleBar < 2 || middleBar + 1 >= totalBars)
   {
      Alert("FVG标注需要三根已收盘K线，请选择更早的中间K线");
      PlaySound("timeout.wav");
      return false;
   }

   int oldBar = middleBar + 1;
   int newBar = middleBar - 1;
   double oldHigh = iHigh(NULL, 0, oldBar);
   double oldLow = iLow(NULL, 0, oldBar);
   double newHigh = iHigh(NULL, 0, newBar);
   double newLow = iLow(NULL, 0, newBar);

   bool isBullish = (newLow > oldHigh);
   bool isBearish = (newHigh < oldLow);
   if(!isBullish && !isBearish)
   {
      Alert("所选三根K线未形成FVG缺口");
      PlaySound("timeout.wav");
      return false;
   }

   double upperPrice = isBullish ? newLow : oldLow;
   double lowerPrice = isBullish ? oldHigh : newHigh;
   double gapPrice = upperPrice - lowerPrice;
   double gapPoints = gapPrice / Point;
   if(FVG_Min_Points > 0 && gapPoints < FVG_Min_Points)
   {
      Alert("FVG缺口仅 ", DoubleToString(gapPoints, 1), " points，小于最小过滤值");
      PlaySound("timeout.wav");
      return false;
   }

   datetime startTime = iTime(NULL, 0, oldBar);
   // 旧逻辑：从右侧新K线继续向右固定延伸 FVG_Extend_Bars 个周期。
   // datetime endTime = iTime(NULL, 0, newBar) + PeriodSeconds() * MathMax(FVG_Extend_Bars, 1);
   // 新逻辑：创建时将矩形终点指向当前最新K线 K[0] 的开盘时间。
   datetime endTime = iTime(NULL, 0, 0);
   double middlePrice = (upperPrice + lowerPrice) / 2.0;
   string direction = isBullish ? "Bull" : "Bear";
   string prefix = isPermanentMode ? "Keep_" : "Draw_";
   string groupName = prefix + GetPeriodName(Period()) + "_FVG_" + IntegerToString((long)iTime(NULL, 0, middleBar));
   color zoneColor = isBullish ? FVG_Bull_Color : FVG_Bear_Color;
   color textColor = isBullish ? FVG_Bull_Text_Color : FVG_Bear_Text_Color;
   int visibilityFlags = CalculateVisibilityFlags(Period(), VisibilityMode);

   string zoneName = groupName + "_Zone";
   ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, startTime, upperPrice, endTime, lowerPrice);
   ObjectSetInteger(0, zoneName, OBJPROP_COLOR, zoneColor);
   ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
   ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
   ObjectSetInteger(0, zoneName, OBJPROP_SELECTABLE, !isLinesLocked);
   ObjectSetInteger(0, zoneName, OBJPROP_TIMEFRAMES, visibilityFlags);
   ObjectSetString(0, zoneName, OBJPROP_TEXT, direction + " FVG");

   if(FVG_Show_Midline)
   {
      string midName = groupName + "_Mid";
      ObjectCreate(0, midName, OBJ_TREND, 0, startTime, middlePrice, endTime, middlePrice);
      ObjectSetInteger(0, midName, OBJPROP_COLOR, FVG_Midline_Color);
      ObjectSetInteger(0, midName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, midName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, midName, OBJPROP_SELECTABLE, !isLinesLocked);
      ObjectSetInteger(0, midName, OBJPROP_TIMEFRAMES, visibilityFlags);
      ObjectSetString(0, midName, OBJPROP_TEXT, "FVG 50% @" + DoubleToString(middlePrice, Digits));
   }

   datetime labelTime = iTime(NULL, 0, newBar);
   if(FVG_Show_Prices)
   {
      string upperName = groupName + "_Upper";
      ObjectCreate(0, upperName, OBJ_TEXT, 0, labelTime, upperPrice);
      ObjectSetString(0, upperName, OBJPROP_TEXT, "FVG H " + DoubleToString(upperPrice, Digits));
      ObjectSetInteger(0, upperName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, upperName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, upperName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, upperName, OBJPROP_TIMEFRAMES, visibilityFlags);

      string lowerName = groupName + "_Lower";
      ObjectCreate(0, lowerName, OBJ_TEXT, 0, labelTime, lowerPrice);
      ObjectSetString(0, lowerName, OBJPROP_TEXT, "FVG L " + DoubleToString(lowerPrice, Digits));
      ObjectSetInteger(0, lowerName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, lowerName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, lowerName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lowerName, OBJPROP_TIMEFRAMES, visibilityFlags);
   }

   if(FVG_Show_Distance)
   {
      string infoName = groupName + "_Info";
      ObjectCreate(0, infoName, OBJ_TEXT, 0, labelTime, middlePrice);
      ObjectSetString(0, infoName, OBJPROP_TEXT,
                      direction + " FVG | " + DoubleToString(gapPoints, 1) +
                      " pts | d " + DoubleToString(gapPrice, Digits));
      ObjectSetInteger(0, infoName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, infoName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, infoName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, infoName, OBJPROP_TIMEFRAMES, visibilityFlags);
   }

   PlaySound("ok.wav");
   return true;
}

//+------------------------------------------------------------------+
//| [新增] 辅助函数：计算周期可见性标志位
//+------------------------------------------------------------------+
int CalculateVisibilityFlags(int currentPeriod, ENUM_VISIBILITY_MODE mode)
{
   // 模式 A：全周期可见（默认）
   if(mode == VISIBILITY_ALL)
   {
      return OBJ_ALL_PERIODS; // 0x1FF
   }
   
   // 定义周期层级映射表（从小到大）
   int periods[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
   int flags[]   = {0x0001,    0x0002,    0x0004,     0x0008,     0x0010,    0x0020,    0x0040,    0x0080,    0x0100};
   
   int currentIndex = -1;
   int currentFlag = 0;
   
   // 找到当前周期在数组中的位置
   for(int i = 0; i < ArraySize(periods); i++)
   {
      if(periods[i] == currentPeriod)
      {
         currentIndex = i;
         currentFlag = flags[i];
         break;
      }
   }
   
   // 如果当前周期不在标准列表中，返回全周期可见
   if(currentIndex == -1) return OBJ_ALL_PERIODS;
   
   // 模式 B：仅当前周期
   if(mode == VISIBILITY_CURRENT)
   {
      return currentFlag;
   }
   
   // 模式 C：当前及更小周期
   if(mode == VISIBILITY_LOWER)
   {
      int result = 0;
      for(int i = 0; i <= currentIndex; i++)
      {
         result |= flags[i];
      }
      return result;
   }
   
   // 模式 D：当前及更大周期
   if(mode == VISIBILITY_HIGHER)
   {
      int result = 0;
      for(int i = currentIndex; i < ArraySize(periods); i++)
      {
         result |= flags[i];
      }
      return result;
   }
   
   // 默认返回全周期
   return OBJ_ALL_PERIODS;
}

//+------------------------------------------------------------------+
//| [新增] 定时器事件处理：检查并清理孤立的标记对象
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!g_ktDrawingToolAuthorized)
   {
      if(KTDrawingToolLicenseInitialize())
      {
         g_ktDrawingToolAuthorized = true;
         EventKillTimer();
         KT_DrawingTool_InitializeAfterLicense();
         Print("[KT License] KT Drawing Tool authorization completed after account connection");
      }
      else if(!KTLicenseIsWaitingForAccount())
      {
         EventKillTimer();
         Alert("KT Drawing Tool authorization failed\n", KTLicenseGetMessage());
         Print("[KT License] Authorization failed: ", KTLicenseGetMessage());
      }
      return;
   }

   CheckAndCleanOrphanedObjects();
   
   // [新增] 检查Clean All确认超时
   if(cleanAllConfirmed && (GetTickCount() - cleanAllConfirmTime >= CONFIRM_TIMEOUT))
   {
      cleanAllConfirmed = false;
      // 恢复按钮颜色为深红色
      ObjectSetInteger(0, btnName4, OBJPROP_BGCOLOR, clrMaroon);
      ChartRedraw();
   }

   // 检查All FVG确认超时，并恢复按钮状态
   if(cleanAllFVGConfirmed && (GetTickCount() - cleanAllFVGConfirmTime >= CONFIRM_TIMEOUT))
   {
      cleanAllFVGConfirmed = false;
      ObjectSetString(0, btnName19, OBJPROP_TEXT, "All FVG");
      ObjectSetInteger(0, btnName19, OBJPROP_BGCOLOR, clrMaroon);
      ChartRedraw();
   }
   
   // [新增] 定期更新关口线
   uint currentTime = GetTickCount();
   if(currentTime - lastRoundLinesUpdate >= ROUND_UPDATE_INTERVAL)
   {
      UpdateRoundNumberLines();
      lastRoundLinesUpdate = currentTime;
   }
   
   // [新增] 定期更新北京日开盘标注
   if(currentTime - lastBJDayOpenUpdate >= BJOPEN_UPDATE_INTERVAL)
   {
      UpdateBeijingDayOpenMarks();
      lastBJDayOpenUpdate = currentTime;
   }

   // [新增] 亚盘高低点在当前会话进行中时定时刷新
   MaybeAutoRefreshAsiaSessionHL();
   MaybeAutoRefreshLondonSessionHL();
   MaybeAutoRefreshNewYorkSessionHL();
}

//+------------------------------------------------------------------+
//| [新增] 记录对象对关系
//+------------------------------------------------------------------+
void RecordObjectPair(string mainObj, string associatedObj)
{
   int size = ArrayRange(g_drawnObjects, 0);  // [修复] 使用ArrayRange而非ArraySize/2
   ArrayResize(g_drawnObjects, size + 1);
   g_drawnObjects[size][0] = mainObj;
   g_drawnObjects[size][1] = associatedObj;
   
   // [调试日志] 记录对象对关联
   Print("[对象关联] 新增第", size+1, "对: 主对象=", mainObj, " 关联对象=", associatedObj);
}

//+------------------------------------------------------------------+
//| [新增] 检查并清理孤立的标记对象
//+------------------------------------------------------------------+
void CheckAndCleanOrphanedObjects()
{
   int size = ArrayRange(g_drawnObjects, 0);  // [修复] 使用ArrayRange而非ArraySize/2
   
   int cleanedCount = 0;  // [调试] 记录清理数量
   
   for(int i = size - 1; i >= 0; i--)
   {
      string mainObj = g_drawnObjects[i][0];
      string assocObj = g_drawnObjects[i][1];
      
      // 如果主对象（线条）不存在了，删除关联对象（标记）
      if(ObjectFind(0, mainObj) == -1)
      {
         if(ObjectFind(0, assocObj) >= 0)
         {
            ObjectDelete(0, assocObj);
            cleanedCount++;  // [调试] 计数
         }
         
         // 从数组中移除这一对
         RemoveObjectPair(i);
      }
   }
   
   // [调试日志] 输出清理结果（仅在有清理时）
   if(cleanedCount > 0)
      Print("[孤儿清理] 已清理 ", cleanedCount, " 个孤立标记对象，当前剩余 ", ArrayRange(g_drawnObjects, 0), " 对关联");
}

//+------------------------------------------------------------------+
//| [新增] 从数组中移除指定索引的对象对
//+------------------------------------------------------------------+
void RemoveObjectPair(int index)
{
   int size = ArrayRange(g_drawnObjects, 0);  // [修复] 使用ArrayRange而非ArraySize/2
   
   // [调试] 边界检查
   if(index < 0 || index >= size)
   {
      Print("[警告] RemoveObjectPair: 索引越界 index=", index, " size=", size);
      return;
   }
   
   // 将后面的元素前移
   for(int i = index; i < size - 1; i++)
   {
      g_drawnObjects[i][0] = g_drawnObjects[i + 1][0];
      g_drawnObjects[i][1] = g_drawnObjects[i + 1][1];
   }
   
   // 缩小数组
   ArrayResize(g_drawnObjects, size - 1);
}

//+------------------------------------------------------------------+
//| [新增] 重启后重建对象对关系
//+------------------------------------------------------------------+
void RebuildObjectPairs()
{
   // 清空现有数组
   ArrayResize(g_drawnObjects, 0);
   
   int total = ObjectsTotal(0, 0, -1);
   int drawCount = 0;  // Draw对象计数
   int keepCount = 0;  // Keep对象计数
   
   for(int i = 0; i < total; i++)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检测对象前缀类型
      bool isDrawObject = (StringFind(objName, "Draw_") == 0);
      bool isKeepObject = (StringFind(objName, "Keep_") == 0);
      
      // 处理以 "Draw_" 或 "Keep_" 开头的线条对象
      if(isDrawObject || isKeepObject)
      {
         // 提取对象名称中的周期和uniqueID
         // 格式: "Draw_H1_1234567890" 或 "Keep_H1_1234567890"
         // Pinbar格式: "Keep_H1_Pin50_1234567890" 或 "Keep_H1_Pin618_1234567890"
         string parts[];
         int count = StringSplit(objName, '_', parts);
         
         if(count >= 3)
         {
            string prefix = parts[0];   // "Draw" 或 "Keep"
            string tfStr = parts[1];    // "H1"
            
            // 根据前缀确定关联对象的名称格式
            string markPrefix = (prefix == "Draw") ? "Mark_" : "KeepMark_";
            string labelPrefix = (prefix == "Draw") ? "PriceLabel_" : "KeepLabel_";
            
            // [修复] 检查是否为Pinbar对象（4段式命名）
            bool isPinbarObj = (count >= 4 && (parts[2] == "Pin50" || parts[2] == "Pin618"));
            
            string markName, priceLabelName;
            
            if(isPinbarObj)
            {
               // Pinbar对象：Keep_H1_Pin50_12345
               // 构建标签名：KeepLabel_H1_Pin50_12345
               string pinType = parts[2];  // "Pin50" 或 "Pin618"
               string uniqueID = parts[3]; // "12345"
               
               markName = markPrefix + tfStr + "_" + pinType + "_" + uniqueID;
               priceLabelName = labelPrefix + tfStr + "_" + pinType + "_" + uniqueID;
            }
            else
            {
               // 普通对象：Keep_H1_12345
               // 构建标签名：KeepLabel_H1_12345
               string uniqueID = parts[2]; // "12345"
               
               markName = markPrefix + tfStr + "_" + uniqueID;
               priceLabelName = labelPrefix + tfStr + "_" + uniqueID;
            }
            
            // 查找对应的标记对象
            if(ObjectFind(0, markName) >= 0)
            {
               RecordObjectPair(objName, markName);
            }
            
            // 查找对应的价格标签对象（如果是射线）
            if(ObjectFind(0, priceLabelName) >= 0)
            {
               RecordObjectPair(objName, priceLabelName);
            }
            
            // 统计计数
            if(isDrawObject) drawCount++;
            else keepCount++;
         }
      }
   }
   
   // 输出日志（可选，用于调试）
   int pairCount = ArrayRange(g_drawnObjects, 0);  // [修复] 使用ArrayRange而非ArraySize/2
   Print("[重建关联] 找到 ", drawCount, " 个Draw对象, ", keepCount, " 个Keep对象, 共 ", pairCount, " 对关联");
}

//+------------------------------------------------------------------+
//| [新增] 更新所有射线的终点到最新K线
//+------------------------------------------------------------------+
void UpdateRayEndpoints()
{
   int total = ObjectsTotal(0, 0, -1);
   
   // [修复] 使用 iTime 代替 Time[0]，防止数组越界
   datetime currentTime = iTime(Symbol(), Period(), 0);
   
   // [保护] 如果时间为0，说明数据未加载完成
   if(currentTime == 0)
   {
      Print("跳过射线更新：数据未就绪");
      return;
   }
   
   int updateCount = 0;
   int drawCount = 0;  // Draw射线计数
   int keepCount = 0;  // Keep射线计数
   
   for(int i = 0; i < total; i++)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检测对象前缀类型
      bool isDrawObject = (StringFind(objName, "Draw_") == 0);
      bool isKeepObject = (StringFind(objName, "Keep_") == 0);
      bool isFVGObject = (StringFind(objName, "_FVG_") > 0);
      
      // 处理射线对象（以 "Draw_" 或 "Keep_" 开头的 OBJ_TREND）
      if((isDrawObject || isKeepObject) && !isFVGObject &&
         ObjectGetInteger(0, objName, OBJPROP_TYPE) == OBJ_TREND)
      {
         // 获取射线的价格
         double price = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
         
         // 更新射线的第二个时间点到当前K线
         ObjectSetInteger(0, objName, OBJPROP_TIME, 1, currentTime);
         ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price);
         updateCount++;
         
         // 统计计数
         if(isDrawObject) drawCount++;
         else keepCount++;
         
         // 同时更新对应的价格标签位置
         string parts[];
         int count = StringSplit(objName, '_', parts);
         if(count >= 3)
         {
            string prefix = parts[0];   // "Draw" 或 "Keep"
            string tfStr = parts[1];
            
            // 根据前缀确定价格标签名称
            string labelPrefix = (prefix == "Draw") ? "PriceLabel_" : "KeepLabel_";
            
            // [修复] 检查是否为Pinbar对象（4段式命名）
            bool isPinbarObj = (count >= 4 && (parts[2] == "Pin50" || parts[2] == "Pin618"));
            
            string priceLabelName;
            
            if(isPinbarObj)
            {
               // Pinbar对象：Keep_H1_Pin50_12345 → KeepLabel_H1_Pin50_12345
               string pinType = parts[2];  // "Pin50" 或 "Pin618"
               string uniqueID = parts[3]; // "12345"
               priceLabelName = labelPrefix + tfStr + "_" + pinType + "_" + uniqueID;
            }
            else
            {
               // 普通对象：Keep_H1_12345 → KeepLabel_H1_12345
               string uniqueID = parts[2]; // "12345"
               priceLabelName = labelPrefix + tfStr + "_" + uniqueID;
            }
            
            if(ObjectFind(0, priceLabelName) >= 0)
            {
               ObjectSetInteger(0, priceLabelName, OBJPROP_TIME, 0, currentTime);
               ObjectSetDouble(0, priceLabelName, OBJPROP_PRICE, 0, price);
            }
         }
      }
   }
   
   if(updateCount > 0)
   {
      Print("更新射线终点: 共更新 ", updateCount, " 条射线 (Draw:", drawCount, " Keep:", keepCount, ") 到最新K线");
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+
//| Clean：清理当前周期的Draw_临时画线/FVG，保留Keep_及其他周期对象
//+------------------------------------------------------------------+
void CleanCurrentPeriodObjects()
{
   string currentTF = GetPeriodName(Period());
   string prefix = "Draw_" + currentTF + "_";
   
   int total = ObjectsTotal(0, 0, -1);
   int deleteCount = 0;
   
   // 从后向前遍历，避免删除后索引变化
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检查是否是当前周期的绘图对象
      if(StringFind(objName, prefix) == 0)
      {
         int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
         bool isFVGObject = (StringFind(objName, prefix + "FVG_") == 0);
         
         // 删除常规画线以及当前周期的整组FVG对象
         if(objType == OBJ_HLINE || objType == OBJ_TREND || isFVGObject)
         {
            // 提取uniqueID，删除关联的标记和价格标签
            string parts[];
            int count = StringSplit(objName, '_', parts);
            
            if(count >= 3)
            {
               string tfStr = parts[1];
               string uniqueID = parts[2];
               
               // 删除关联的标记对象
               string markName = "Mark_" + tfStr + "_" + uniqueID;
               if(ObjectFind(0, markName) >= 0)
               {
                  ObjectDelete(0, markName);
               }
               
               // 删除关联的价格标签（射线）
               string priceLabelName = "PriceLabel_" + tfStr + "_" + uniqueID;
               if(ObjectFind(0, priceLabelName) >= 0)
               {
                  ObjectDelete(0, priceLabelName);
               }
               
               // 从数组中移除关联记录
               int arraySize = ArrayRange(g_drawnObjects, 0);  // [修复] 使用ArrayRange而非ArraySize/2
               for(int j = arraySize - 1; j >= 0; j--)
               {
                  if(g_drawnObjects[j][0] == objName)
                  {
                     RemoveObjectPair(j);
                  }
               }
            }
            
            // 删除主对象
            ObjectDelete(0, objName);
            deleteCount++;
         }
      }
   }
   
   if(deleteCount > 0)
   {
      Print("已清理当前周期 [", currentTF, "] 的绘图对象: ", deleteCount, " 个");
   }
   else
   {
      Print("当前周期 [", currentTF, "] 没有可清理的对象");
   }
}

//+------------------------------------------------------------------+
//| Clean All：清理全部周期的Draw_临时画线/FVG，保留所有Keep_对象
//+------------------------------------------------------------------+
void CleanAllObjects()
{
   int total = ObjectsTotal(0, 0, -1);
   int deleteCount = 0;
   
   // 从后向前遍历，避免删除后索引变化
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检查是否是由本工具创建的对象（以 "Draw_" 开头）
      if(StringFind(objName, "Draw_") == 0)
      {
         int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
         bool isFVGObject = (StringFind(objName, "_FVG_") > 0);
         
         // 删除常规画线以及全部临时FVG对象
         if(objType == OBJ_HLINE || objType == OBJ_TREND || isFVGObject)
         {
            // 提取uniqueID，删除关联的标记和价格标签
            string parts[];
            int count = StringSplit(objName, '_', parts);
            
            if(count >= 3)
            {
               string tfStr = parts[1];
               string uniqueID = parts[2];
               
               // 删除关联的标记对象
               string markName = "Mark_" + tfStr + "_" + uniqueID;
               if(ObjectFind(0, markName) >= 0)
               {
                  ObjectDelete(0, markName);
               }
               
               // 删除关联的价格标签（射线）
               string priceLabelName = "PriceLabel_" + tfStr + "_" + uniqueID;
               if(ObjectFind(0, priceLabelName) >= 0)
               {
                  ObjectDelete(0, priceLabelName);
               }
            }
            
            // 删除主对象
            ObjectDelete(0, objName);
            deleteCount++;
         }
      }
   }
   
   // 清空关联数组
   ArrayResize(g_drawnObjects, 0);
   
   if(deleteCount > 0)
   {
      Print("已清除所有画线对象: ", deleteCount, " 个");
      PlaySound("ok.wav");
      ChartRedraw();
   }
   else
   {
      Print("没有可清除的对象");
   }
}

//+------------------------------------------------------------------+
//| FVG专用清理：allPeriods=false当前周期，true全部周期             |
//| 同时删除Draw_和Keep_整组FVG，但保留普通画线及其他图表对象       |
//+------------------------------------------------------------------+
void CleanFVGObjects(bool allPeriods)
{
   string periodToken = "_" + GetPeriodName(Period()) + "_FVG_";
   int total = ObjectsTotal(0, 0, -1);
   int deleteCount = 0;

   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, -1);
      bool isManagedObject = (StringFind(objName, "Draw_") == 0 ||
                              StringFind(objName, "Keep_") == 0);
      bool isFVGObject = (StringFind(objName, "_FVG_") > 0);
      bool isTargetPeriod = (StringFind(objName, periodToken) > 0);

      if(isManagedObject && isFVGObject && (allPeriods || isTargetPeriod))
      {
         ObjectDelete(0, objName);
         deleteCount++;
      }
   }

   if(deleteCount > 0)
      Print("[FVG清理] ", allPeriods ? "全部周期" : GetPeriodName(Period()),
            " 共删除 ", deleteCount, " 个Draw_/Keep_ FVG对象");
   else
      Print("[FVG清理] ", allPeriods ? "全部周期" : GetPeriodName(Period()),
            " 没有可删除的FVG对象");
}

//+------------------------------------------------------------------+
//| [新增] 取消所有水平线和射线的选中状态
//+------------------------------------------------------------------+
void DeselectAllLines()
{
   int total = ObjectsTotal(0, 0, -1);
   int deselectCount = 0;
   
   for(int i = 0; i < total; i++)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检查是否是由本工具创建的对象（以 "Draw_" 或 "Keep_" 开头）
      bool isDrawObject = (StringFind(objName, "Draw_") == 0);
      bool isKeepObject = (StringFind(objName, "Keep_") == 0);
      
      if(isDrawObject || isKeepObject)
      {
         int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
         
         // 只处理水平线和射线
         if(objType == OBJ_HLINE || objType == OBJ_TREND)
         {
            // 检查是否处于选中状态
            bool isSelected = (bool)ObjectGetInteger(0, objName, OBJPROP_SELECTED);
            
            if(isSelected)
            {
               // 取消选中
               ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
               deselectCount++;
            }
         }
      }
   }
   
   if(deselectCount > 0)
   {
      Print("已取消选中 ", deselectCount, " 个对象");
   }
   else
   {
      Print("没有处于选中状态的对象");
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| [新增] 切换线条锁定状态（防止误操作）
//+------------------------------------------------------------------+
void ToggleLinesLock()
{
   // 切换锁定状态
   isLinesLocked = !isLinesLocked;
   
   // 遍历所有对象
   int total = ObjectsTotal(0, 0, -1);
   int affectedCount = 0;
   
   for(int i = 0; i < total; i++)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检查是否是工具创建的线条对象
      bool isDrawObject = (StringFind(objName, "Draw_") == 0);
      bool isKeepObject = (StringFind(objName, "Keep_") == 0);
      
      if(isDrawObject || isKeepObject)
      {
         int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
         
         // 处理水平线、射线和FVG矩形（不包括辅助文字）
         if(objType == OBJ_HLINE || objType == OBJ_TREND || objType == OBJ_RECTANGLE)
         {
            // 设置可选状态（锁定时=false，解锁时=true）
            ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, !isLinesLocked);
            affectedCount++;
         }
      }
   }
   
   // 更新按钮样式和提示
   if(isLinesLocked)
   {
      ObjectSetString(0, btnName11, OBJPROP_TEXT, "Locked");
      ObjectSetInteger(0, btnName11, OBJPROP_BGCOLOR, clrGoldenrod);
      //Alert(" 线条已锁定\n所有射线和水平线无法选择，防止误操作");
   }
   else
   {
      ObjectSetString(0, btnName11, OBJPROP_TEXT, "Unlock");
      ObjectSetInteger(0, btnName11, OBJPROP_BGCOLOR, clrGray);
      //Alert(" 线条已解锁\n可以正常选择和移动线条");
   }
   
   Print("锁定状态切换: ", (isLinesLocked ? "已锁定" : "已解锁"), ", 影响 ", affectedCount, " 个对象");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| [新增] 辅助函数：显示/隐藏按钮
//+------------------------------------------------------------------+
void SetButtonVisibility(string btnName, bool visible, int yPos)
{
   if(visible)
   {
      // 显示按钮：恢复到指定的Y坐标位置
      ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, yPos);
   }
   else
   {
      // 隐藏按钮：移动到屏幕外
      ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, -1000);
   }
}

//#region MARK: 模块--模拟十字准星与K线信息
void CreateCrosshairInfoObjects()
{
   if(ObjectFind(0, g_crosshairVLineName) < 0)
      ObjectCreate(0, g_crosshairVLineName, OBJ_VLINE, 0, TimeCurrent(), 0.0);

   if(ObjectFind(0, g_crosshairHLineName) < 0)
      ObjectCreate(0, g_crosshairHLineName, OBJ_HLINE, 0, 0, Bid);

   ObjectSetInteger(0, g_crosshairVLineName, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, g_crosshairVLineName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, g_crosshairVLineName, OBJPROP_WIDTH, 1);
   ObjectSetString(0, g_crosshairVLineName, OBJPROP_TOOLTIP, "\n");
   ObjectSetInteger(0, g_crosshairVLineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_crosshairVLineName, OBJPROP_HIDDEN, true);

   ObjectSetInteger(0, g_crosshairHLineName, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, g_crosshairHLineName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, g_crosshairHLineName, OBJPROP_WIDTH, 1);
   ObjectSetString(0, g_crosshairHLineName, OBJPROP_TOOLTIP, "\n");
   ObjectSetInteger(0, g_crosshairHLineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_crosshairHLineName, OBJPROP_HIDDEN, true);

   // 旧版单标签实现保留，原来通过一个OBJ_LABEL承载全部换行文本。
   // if(ObjectFind(0, g_crosshairInfoName) < 0)
   //    ObjectCreate(0, g_crosshairInfoName, OBJ_LABEL, 0, 0, 0);
   // ObjectSetString(0, g_crosshairInfoName, OBJPROP_TEXT, infoText);

   for(int lineIndex = 0; lineIndex < 4; lineIndex++)
   {
      if(ObjectFind(0, g_crosshairInfoLineNames[lineIndex]) < 0)
         ObjectCreate(0, g_crosshairInfoLineNames[lineIndex], OBJ_LABEL, 0, 0, 0);

      ObjectSetInteger(0, g_crosshairInfoLineNames[lineIndex], OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, g_crosshairInfoLineNames[lineIndex], OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, g_crosshairInfoLineNames[lineIndex], OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, g_crosshairInfoLineNames[lineIndex], OBJPROP_YDISTANCE, 40 + lineIndex * 18);
      ObjectSetInteger(0, g_crosshairInfoLineNames[lineIndex], OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, g_crosshairInfoLineNames[lineIndex], OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, g_crosshairInfoLineNames[lineIndex], OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, g_crosshairInfoLineNames[lineIndex], OBJPROP_BACK, false);
      ObjectSetInteger(0, g_crosshairInfoLineNames[lineIndex], OBJPROP_ZORDER, 20);
      ObjectSetString(0, g_crosshairInfoLineNames[lineIndex], OBJPROP_TOOLTIP, "\n");
      ObjectSetInteger(0, g_crosshairInfoLineNames[lineIndex], OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, g_crosshairInfoLineNames[lineIndex], OBJPROP_HIDDEN, true);
   }
}

void DeleteCrosshairInfoObjects()
{
   ObjectDelete(0, g_crosshairVLineName);
   ObjectDelete(0, g_crosshairHLineName);
   ObjectDelete(0, g_crosshairInfoName);
   for(int lineIndex = 0; lineIndex < 4; lineIndex++)
      ObjectDelete(0, g_crosshairInfoLineNames[lineIndex]);
   g_crosshairLastShift = -1;
   g_crosshairLastPrice = 0.0;
}

void PositionCrosshairInfoLabel(int mouseX, int mouseY)
{
   long chartWidth = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   long chartHeight = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   int labelWidthEstimate = 300;
   int labelHeightEstimate = 100;
   int labelX = mouseX + 15;
   int labelY = mouseY + 15;

   if(chartWidth > 0 && labelX + labelWidthEstimate > chartWidth)
      labelX = mouseX - labelWidthEstimate;
   if(chartHeight > 0 && labelY + labelHeightEstimate > chartHeight)
      labelY = mouseY - labelHeightEstimate;

   if(labelX < 5) labelX = 5;
   if(labelY < 5) labelY = 5;

   for(int lineIndex = 0; lineIndex < 4; lineIndex++)
   {
      ObjectSetInteger(0, g_crosshairInfoLineNames[lineIndex], OBJPROP_XDISTANCE, labelX);
      ObjectSetInteger(0, g_crosshairInfoLineNames[lineIndex], OBJPROP_YDISTANCE,
                       labelY + lineIndex * 18);
   }
}

void UpdateCrosshairInfo(int mouseX, int mouseY)
{
   if(ObjectFind(0, g_crosshairVLineName) < 0 ||
      ObjectFind(0, g_crosshairHLineName) < 0 ||
      ObjectFind(0, g_crosshairInfoLineNames[0]) < 0 ||
      ObjectFind(0, g_crosshairInfoLineNames[1]) < 0 ||
      ObjectFind(0, g_crosshairInfoLineNames[2]) < 0 ||
      ObjectFind(0, g_crosshairInfoLineNames[3]) < 0)
      CreateCrosshairInfoObjects();

   int subWindow = 0;
   datetime mouseTime = 0;
   double mousePrice = 0.0;

   if(!ChartXYToTimePrice(0, mouseX, mouseY, subWindow, mouseTime, mousePrice))
      return;

   if(subWindow != 0)
      return;

   int shift = iBarShift(NULL, 0, mouseTime, false);
   if(shift < 0 || shift >= iBars(NULL, 0))
      return;

   datetime barTime = iTime(NULL, 0, shift);
   double openPrice = iOpen(NULL, 0, shift);
   double highPrice = iHigh(NULL, 0, shift);
   double lowPrice = iLow(NULL, 0, shift);
   double closePrice = iClose(NULL, 0, shift);
   double rangePrice = highPrice - lowPrice;
   double rangePoints = (Point > 0.0) ? rangePrice / Point : 0.0;
   double normalizedMousePrice = NormalizeDouble(mousePrice, Digits);

   PositionCrosshairInfoLabel(mouseX, mouseY);

   if(shift == g_crosshairLastShift &&
      MathAbs(normalizedMousePrice - g_crosshairLastPrice) < Point)
      return;

   datetime beijingTime = barTime + (8 - Server_GMT_Offset) * 3600;
   // 旧版单标签文本保留，原逻辑依赖\n实现多行显示。
   // string infoText = "K[" + IntegerToString(shift) + "]  " +
   //                   "北京时间: " + TimeToString(beijingTime, TIME_DATE | TIME_MINUTES) + "\n" +
   //                   "开盘: " + DoubleToString(openPrice, Digits) +
   //                   "  最高: " + DoubleToString(highPrice, Digits) + "\n" +
   //                   "最低: " + DoubleToString(lowPrice, Digits) +
   //                   "  收盘: " + DoubleToString(closePrice, Digits) + "\n" +
   //                   "波幅: " + DoubleToString(rangePrice, Digits) +
   //                   "  (" + DoubleToString(rangePoints, 1) + " points)";

   string infoLines[4];
   infoLines[0] = "K[" + IntegerToString(shift) + "]  北京时间: " +
                  TimeToString(beijingTime, TIME_DATE | TIME_MINUTES);
   infoLines[1] = "开盘: " + DoubleToString(openPrice, Digits) +
                  "  最高: " + DoubleToString(highPrice, Digits);
   infoLines[2] = "最低: " + DoubleToString(lowPrice, Digits) +
                  "  收盘: " + DoubleToString(closePrice, Digits);
   infoLines[3] = "波幅: " + DoubleToString(rangePrice, Digits) +
                  "  (" + DoubleToString(rangePoints, 1) + " points)";

   ObjectMove(0, g_crosshairVLineName, 0, barTime, 0.0);
   ObjectSetDouble(0, g_crosshairHLineName, OBJPROP_PRICE, normalizedMousePrice);
   for(int lineIndex = 0; lineIndex < 4; lineIndex++)
      ObjectSetString(0, g_crosshairInfoLineNames[lineIndex], OBJPROP_TEXT, infoLines[lineIndex]);

   g_crosshairLastShift = shift;
   g_crosshairLastPrice = normalizedMousePrice;
   ChartRedraw();
}
//#endregion

//+------------------------------------------------------------------+
//| [新增] 判断K线是否为Pinbar，返回类型：0=不是, 1=看涨, 2=看跌
//+------------------------------------------------------------------+
int IsPinbar(int barIndex)
{
   double high  = iHigh(NULL, 0, barIndex);
   double low   = iLow(NULL, 0, barIndex);
   double open  = iOpen(NULL, 0, barIndex);
   double close = iClose(NULL, 0, barIndex);
   
   // 计算K线各部分尺寸
   double totalRange = high - low;
   if(totalRange == 0) return 0;  // 防止除零
   
   double bodyHigh = MathMax(open, close);
   double bodyLow  = MathMin(open, close);
   double bodySize = bodyHigh - bodyLow;
   
   double upperWick = high - bodyHigh;  // 上影线
   double lowerWick = bodyLow - low;    // 下影线
   
   // 计算比例
   double bodyPercent = bodySize / totalRange * 100;
   double upperWickPercent = upperWick / totalRange * 100;
   double lowerWickPercent = lowerWick / totalRange * 100;
   
   // 判断看涨Pinbar（长下影线）
   if(lowerWickPercent >= 60 &&          // 下影线至少60%
      bodyPercent <= 30 &&                // 实体小于30%
      upperWickPercent <= 20 &&           // 上影线小于20%
      bodyLow >= low + totalRange * 0.6)  // [修复] 实体在上端（下影线结束位置之上）
   {
      return 1;  // 看涨Pinbar
   }
   
   // 判断看跌Pinbar（长上影线）
   if(upperWickPercent >= 60 &&          // 上影线至少60%
      bodyPercent <= 30 &&                // 实体小于30%
      lowerWickPercent <= 20 &&           // 下影线小于20%
      bodyHigh <= high - totalRange * 0.6) // [修复] 实体在下端（上影线结束位置之下）
   {
      return 2;  // 看跌Pinbar
   }
   
   return 0;  // 不是Pinbar
}

//+------------------------------------------------------------------+
//| [新增] 判断K线是否为Pinbar（宽松版本），返回类型：0=不是, 1=看涨, 2=看跌
//+------------------------------------------------------------------+
int IsPinbarV2(int barIndex)
{
   double high  = iHigh(NULL, 0, barIndex);
   double low   = iLow(NULL, 0, barIndex);
   double open  = iOpen(NULL, 0, barIndex);
   double close = iClose(NULL, 0, barIndex);
   
   // 计算K线各部分尺寸
   double totalRange = high - low;
   if(totalRange == 0) return 0;  // 防止除零
   
   double bodyHigh = MathMax(open, close);
   double bodyLow  = MathMin(open, close);
   double bodySize = bodyHigh - bodyLow;
   
   double upperWick = high - bodyHigh;  // 上影线
   double lowerWick = bodyLow - low;    // 下影线
   
   // 计算比例
   double bodyPercent = bodySize / totalRange * 100;
   double upperWickPercent = upperWick / totalRange * 100;
   double lowerWickPercent = lowerWick / totalRange * 100;
   
   // 宽松标准：影线 > 55%, 实体 < 1/3 (33.3%)
   
   // 判断看涨Pinbar（长下影线）
   // 下影线超过整根K线的55%，且实体小于1/3
   if(lowerWickPercent > 55 && bodyPercent < 33.3)
   {
      return 1;  // 看涨Pinbar（宽松版）
   }
   
   // 判断看跌Pinbar（长上影线）
   // 上影线超过整根K线的55%，且实体小于1/3
   if(upperWickPercent > 55 && bodyPercent < 33.3)
   {
      return 2;  // 看跌Pinbar（宽松版）
   }
   
   return 0;  // 不是Pinbar
}

//+------------------------------------------------------------------+
//| Force Clear：无确认删除当前图表全部对象，包括Keep_、外部对象和UI
//+------------------------------------------------------------------+
void ForceCleanAllObjects()
{
   // 删除主图表上所有绘图对象
   // chart_id = 0 (当前图表)
   // sub_window = -1 (所有窗口)
   // type = -1 (所有类型对象)
   int total_deleted = ObjectsDeleteAll(0, -1, -1);
   
   // 清空关联数组
   ArrayResize(g_drawnObjects, 0);
   
   // 强制刷新图表
   ChartRedraw(0);
   
   // 打印日志
   if(total_deleted > 0)
      Print("[强制清除] 成功删除 ", total_deleted, " 个绘图对象（包含所有类型）");
   else
      Print("[强制清除] 图表上没有可删除的对象");
}

//+------------------------------------------------------------------+
//| [新增] 绘制关口线（整数价位参考线）
//+------------------------------------------------------------------+
void DrawRoundNumberLines()
{
   // 检查是否所有开关都关闭
   if(!Enable_Round_100 && !Enable_Round_50 && !Enable_Round_10 && !Enable_Round_5)
      return;  // 全部关闭，不绘制
   
   // 获取图表可见范围的价格上下限
   double upperPrice = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   double lowerPrice = ChartGetDouble(0, CHART_PRICE_MIN, 0);
   
   // 检查数据有效性
   if(upperPrice == 0 || lowerPrice == 0 || upperPrice <= lowerPrice)
      return;  // 数据未就绪或无效
   
   // 根据Point大小确定合适的步长单位
   // XAUUSD: Point=0.01, 所以100美金 = 100/0.01 = 10000点
   double unit_100 = 100.0;
   double unit_50 = 50.0;
   double unit_10 = 10.0;
   double unit_5 = 5.0;
   
   // 绘制计数
   int count100 = 0, count50 = 0, count10 = 0, count5 = 0;
   
   // 从下限开始遍历到上限
   // 找到最小的起始价格（向下取整到最小单位）
   double minUnit = 1000.0;  // 默认最大单位
   if(Enable_Round_5) minUnit = unit_5;
   else if(Enable_Round_10) minUnit = unit_10;
   else if(Enable_Round_50) minUnit = unit_50;
   else if(Enable_Round_100) minUnit = unit_100;
   
   double startPrice = MathFloor(lowerPrice / minUnit) * minUnit;
   
   // 遍历价格范围
   for(double price = startPrice; price <= upperPrice; price += minUnit)
   {
      // 优先级覆盖策略：100 > 50 > 10 > 5
      // 如果某个价位同时满足多个条件，只绘制优先级最高的那条线
      
      if(Enable_Round_100 && MathAbs(MathMod(price, unit_100)) < 0.001)
      {
         // 绘制100关口线
         DrawSingleRoundLine(price, 100, Color_Round_100, Width_Round_100, Style_Round_Key);
         count100++;
      }
      else if(Enable_Round_50 && MathAbs(MathMod(price, unit_50)) < 0.001)
      {
         // 绘制50关口线
         DrawSingleRoundLine(price, 50, Color_Round_50, Width_Round_50, Style_Round_Key);
         count50++;
      }
      else if(Enable_Round_10 && MathAbs(MathMod(price, unit_10)) < 0.001)
      {
         // 绘制10关口线
         DrawSingleRoundLine(price, 10, Color_Round_10, Width_Round_10, Style_Round_Normal);
         count10++;
      }
      else if(Enable_Round_5 && MathAbs(MathMod(price, unit_5)) < 0.001)
      {
         // 绘制5关口线
         DrawSingleRoundLine(price, 5, Color_Round_5, Width_Round_5, Style_Round_Normal);
         count5++;
      }
   }
   
   // 打印日志
   int total = count100 + count50 + count10 + count5;
   if(total > 0 && Enable_Log_RoundLines)
   {
      Print("[关口线] 绘制完成: 100(", count100, ") 50(", count50, ") 10(", count10, ") 5(", count5, ") 共", total, "条");
   }
}

//+------------------------------------------------------------------+
//| [新增] 绘制单条关口线
//+------------------------------------------------------------------+
void DrawSingleRoundLine(double price, int interval, color lineColor, int lineWidth, ENUM_LINE_STYLE lineStyle)
{
   // 对象命名：Round_间隔_价格（去掉小数点）
   string priceSt = DoubleToString(price, 2);
   StringReplace(priceSt, ".", "");
   string objName = "Round_" + IntegerToString(interval) + "_" + priceSt;
   
   // 检查对象是否已存在
   if(ObjectFind(0, objName) >= 0)
      return;  // 已存在，跳过
   
   // 创建水平线
   ObjectCreate(0, objName, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, lineWidth);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, lineStyle);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);  // 不可选择
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);       // 对象列表隐藏
   // 注意：不设置OBJPROP_BACK，让线条在前景层，这样MT4会自动显示价格
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);         // 设置为背景层，防止覆盖EA面板
   ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);  // 所有周期可见
   
   // 设置描述文字
   string desc = "";
   if(interval == 100 || interval == 50)
      desc = "[Key Round " + IntegerToString(interval) + "]";
   else
      desc = "[Round " + IntegerToString(interval) + "]";
   
   ObjectSetString(0, objName, OBJPROP_TEXT, desc);
   
   // ✨ 方案1：手动创建价格标签（仅为重要关口：100和50）
   if(interval >= 50)
   {
      datetime currentTime = iTime(NULL, 0, 0);
      if(currentTime == 0) return;  // 数据未就绪
      
      string labelName = "RoundLabel_" + IntegerToString(interval) + "_" + priceSt;
      
      // 创建价格标签对象（OBJ_ARROW_RIGHT_PRICE）
      ObjectCreate(0, labelName, OBJ_ARROW_RIGHT_PRICE, 0, currentTime, price);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, labelName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);      // 标签在前景层
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, labelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      
      // 建立关联（用于后续同步删除和更新）
      RecordObjectPair(objName, labelName);
   }
}

//+------------------------------------------------------------------+
//| [新增] 更新关口线（价格范围变化时）
//+------------------------------------------------------------------+
void UpdateRoundNumberLines()
{
   // 检查是否所有开关都关闭
   if(!Enable_Round_100 && !Enable_Round_50 && !Enable_Round_10 && !Enable_Round_5)
      return;
   
   // 获取图表可见范围的价格上下限
   double upperPrice = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   double lowerPrice = ChartGetDouble(0, CHART_PRICE_MIN, 0);
   
   // 检查数据有效性
   if(upperPrice == 0 || lowerPrice == 0 || upperPrice <= lowerPrice)
      return;
   
   // 删除超出范围的关口线，创建新进入范围的关口线
   int total = ObjectsTotal(0, 0, -1);
   int deletedCount = 0;
   
   // 从后向前遍历，删除超出范围的线
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检查是否是关口线对象
      if(StringFind(objName, "Round_") == 0)
      {
         double linePrice = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
         
         // 如果超出当前价格范围，删除
         if(linePrice < lowerPrice || linePrice > upperPrice)
         {
            ObjectDelete(0, objName);
            deletedCount++;
            
            // ✨ 同时删除关联的价格标签
            string labelName = "RoundLabel_" + StringSubstr(objName, 6);  // 去掉"Round_"前缀
            if(ObjectFind(0, labelName) >= 0)
            {
               ObjectDelete(0, labelName);
            }
         }
      }
      // ✨ 更新手动标签的时间位置（保持在最新K线）
      else if(StringFind(objName, "RoundLabel_") == 0)
      {
         datetime currentTime = iTime(NULL, 0, 0);
         if(currentTime > 0)
         {
            ObjectSetInteger(0, objName, OBJPROP_TIME, 0, currentTime);
         }
      }
   }
   
   // 重新绘制（只会创建不存在的线）
   DrawRoundNumberLines();
   
   if(deletedCount > 0 && Enable_Log_RoundLines)
   {
      Print("[关口线] 更新: 删除超出范围的 ", deletedCount, " 条线及标签");
   }
}

//+------------------------------------------------------------------+
//| [新增] 删除所有关口线
//+------------------------------------------------------------------+
void DeleteRoundNumberLines()
{
   /*
   int total = ObjectsTotal(0, 0, -1);
   int deleteCount = 0;
   
   // 从后向前遍历，删除所有关口线及其标签
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检查是否是关口线对象（以 "Round_" 开头）
      if(StringFind(objName, "Round_") == 0)
      {
         // ✨ 先删除关联的价格标签
         string labelName = "RoundLabel_" + StringSubstr(objName, 6);  // 去掉"Round_"前缀
         if(ObjectFind(0, labelName) >= 0)
         {
            ObjectDelete(0, labelName);
         }
         
         // 删除关口线
         ObjectDelete(0, objName);
         deleteCount++;
      }
      // ✨ 也删除孤立的标签对象
      else if(StringFind(objName, "RoundLabel_") == 0)
      {
         ObjectDelete(0, objName);
      }
   }
   
   */
   int deleteCount = ObjectsDeleteAll(0, "Round_", -1, -1);
   int labelDeleteCount = ObjectsDeleteAll(0, "RoundLabel_", -1, -1);

   if((deleteCount > 0 || labelDeleteCount > 0) && Enable_Log_RoundLines)
   {
      Print("[关口线] 清理: 删除 ", deleteCount, " 条关口线及标签");
   }
}

//+------------------------------------------------------------------+
//| [新增] 切换所有画线的显示/隐藏状态
//+------------------------------------------------------------------+
void ToggleLinesVisibility()
{
   isLinesHidden = !isLinesHidden;
   
   if(isLinesHidden)
   {
      // 隐藏模式：保存当前可见性并设为不可见
      ArrayResize(g_objectVisibility, 0);
      
      int total = ObjectsTotal(0, 0, -1);
      for(int i = 0; i < total; i++)
      {
         string name = ObjectName(0, i, 0, -1);
         
         // 处理本指标创建的所有对象（线条、标签、标记、关口线及其标签）
         if(StringFind(name, "Keep_") == 0 || StringFind(name, "Draw_") == 0 ||
            StringFind(name, "KeepLabel_") == 0 || StringFind(name, "PriceLabel_") == 0 ||
            StringFind(name, "KeepMark_") == 0 || StringFind(name, "Mark_") == 0 ||
            StringFind(name, "Round_") == 0 || StringFind(name, "RoundLabel_") == 0)
         {
            // 保存原始可见性设置
            long originalFlags = ObjectGetInteger(0, name, OBJPROP_TIMEFRAMES);
            
            int size = ArrayRange(g_objectVisibility, 0);
            ArrayResize(g_objectVisibility, size + 1);
            g_objectVisibility[size][0] = name;
            g_objectVisibility[size][1] = IntegerToString(originalFlags);
            
            // 设置为所有周期都不可见
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
         }
      }
      
      ObjectSetString(0, btnName12, OBJPROP_TEXT, "Show All");
      ObjectSetInteger(0, btnName12, OBJPROP_BGCOLOR, clrOrange); // 橙色警示
      Alert("已隐藏所有画线及关联对象\n(包括射线价格标签、Check标记、关口线)");
   }
   else
   {
      // 显示模式：恢复原始可见性
      int size = ArrayRange(g_objectVisibility, 0);
      
      for(int i = 0; i < size; i++)
      {
         string name = g_objectVisibility[i][0];
         long originalFlags = StringToInteger(g_objectVisibility[i][1]);
         
         if(ObjectFind(0, name) >= 0)
         {
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, originalFlags);
         }
      }
      
      ArrayResize(g_objectVisibility, 0); // 清空记录
      
      ObjectSetString(0, btnName12, OBJPROP_TEXT, "Hide All");
      ObjectSetInteger(0, btnName12, OBJPROP_BGCOLOR, clrGray); // 恢复灰色
      Alert("已恢复显示所有画线");
   }
}

//+------------------------------------------------------------------+
//| [新增] 判断某根K线是否为北京时间开盘K线
//+------------------------------------------------------------------+
bool IsDayOpenBar(int barIndex)
{
   // 安全检查
   if(barIndex < 0 || barIndex >= iBars(NULL, 0))
      return false;
   
   // 获取K线服务器时间
   datetime barTime = iTime(NULL, 0, barIndex);
   if(barTime == 0) return false;
   
   // 转为北京时间
   int timeDiff = (8 - Server_GMT_Offset) * 3600; // 秒
   datetime bjTime = barTime + timeDiff;
   
   // 解析时间
   MqlDateTime dt;
   TimeToStruct(bjTime, dt);
   
   // 判断是否为目标开盘小时（小时匹配 且 分钟为0）
   return (dt.hour == BJ_DayOpen_Hour && dt.min == 0);
}

//+------------------------------------------------------------------+
//| [新增] 绘制北京日开盘标注
//+------------------------------------------------------------------+
void DrawBeijingDayOpenMarks()
{
   // 检查功能开关
   if(!Enable_BJDayOpen_Mark)
      return;
   
   // 检查周期限制
   if(Only_H1_Period && Period() != PERIOD_H1)
      return;
   
   // 计算扫描范围
   int maxBars = iBars(NULL, 0);
   int scanLimit = maxBars;
   
   // 如果设置了天数范围（非0），则限制扫描范围
   if(Mark_Days_Range > 0)
   {
      // H1周期，24根K线=1天
      scanLimit = Mark_Days_Range * 24;
      if(scanLimit > maxBars) scanLimit = maxBars;
   }
   
   int markCount = 0;
   
   // 遍历K线查找开盘K线
   for(int i = 0; i < scanLimit; i++)
   {
      if(IsDayOpenBar(i))
      {
         DrawSingleBJDayOpenMark(i);
         markCount++;
      }
   }
   
   if(markCount > 0)
   {
      Print("[北京日开盘] 绘制完成: 共标注 ", markCount, " 个开盘点（最近", Mark_Days_Range > 0 ? Mark_Days_Range : 0, "天）");
   }
}

//+------------------------------------------------------------------+
//| [新增] 绘制单个北京日开盘标注
//+------------------------------------------------------------------+
void DrawSingleBJDayOpenMark(int barIndex)
{
   datetime barTime = iTime(NULL, 0, barIndex);
   if(barTime == 0) return;
   
   // 转北京时间用于显示
   int timeDiff = (8 - Server_GMT_Offset) * 3600;
   datetime bjTime = barTime + timeDiff;
   
   // 生成唯一对象名（基于日期）
   string dateStr = TimeToString(bjTime, TIME_DATE);
   StringReplace(dateStr, ".", "");  // 去掉点号
   
   // 如果启用文字标签
   if(Show_BJDayOpen_Label)
   {
      string labelName = "BJDayOpen_Label_" + dateStr;
      
      if(ObjectFind(0, labelName) < 0)
      {
         // 获取K线最低价，在下方显示标签（避免遮挡价格）
         double low = iLow(NULL, 0, barIndex);
         double labelPrice = low - 30 * Point;
         
         // 创建文字标签
         ObjectCreate(0, labelName, OBJ_TEXT, 0, barTime, labelPrice);
         ObjectSetString(0, labelName, OBJPROP_TEXT, "BJ " + IntegerToString(BJ_DayOpen_Hour) + ":00");
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, BJDayOpen_Label_Color);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, BJDayOpen_Label_Size);
         ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER); // 锚点在左上，标签在K线下方
      }
   }
}

//+------------------------------------------------------------------+
//| [新增] 更新北京日开盘标注（价格范围变化时）
//+------------------------------------------------------------------+
void UpdateBeijingDayOpenMarks()
{
   // 检查功能开关
   if(!Enable_BJDayOpen_Mark)
      return;
   
   // 检查周期限制
   if(Only_H1_Period && Period() != PERIOD_H1)
      return;
   
   // 计算当前应保留的时间范围
   datetime currentTime = iTime(NULL, 0, 0);
   if(currentTime == 0) return;
   
   int maxBars = iBars(NULL, 0);
   int rangeLimit = (Mark_Days_Range > 0) ? (Mark_Days_Range * 24) : maxBars;
   
   datetime oldestAllowedTime = 0;
   if(rangeLimit < maxBars)
   {
      oldestAllowedTime = iTime(NULL, 0, rangeLimit);
   }
   
   // 删除超出范围的标注
   int total = ObjectsTotal(0, 0, -1);
   int deletedCount = 0;
   
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检查是否是北京日开盘标注对象
      if(StringFind(objName, "BJDayOpen_") == 0)
      {
         // 获取对象时间
         datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
         
         // 如果超出范围，删除
         if(oldestAllowedTime > 0 && objTime < oldestAllowedTime)
         {
            ObjectDelete(0, objName);
            deletedCount++;
         }
      }
   }
   
   // 重新绘制（只会创建不存在的标注）
   DrawBeijingDayOpenMarks();
   
   if(deletedCount > 0)
   {
      Print("[北京日开盘] 更新: 删除超出范围的 ", deletedCount, " 个标注");
   }
}

//+------------------------------------------------------------------+
//| [新增] 删除所有北京日开盘标注
//+------------------------------------------------------------------+
void DeleteBeijingDayOpenMarks()
{
   /*
   int total = ObjectsTotal(0, 0, -1);
   int deleteCount = 0;
   
   // 从后向前遍历，删除所有北京日开盘标注
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检查是否是北京日开盘标注对象（以 "BJDayOpen_" 开头）
      if(StringFind(objName, "BJDayOpen_") == 0)
      {
         ObjectDelete(0, objName);
         deleteCount++;
      }
   }
   
   */
   int deleteCount = ObjectsDeleteAll(0, "BJDayOpen_", -1, -1);

   if(deleteCount > 0)
   {
      Print("[北京日开盘] 清理: 删除 ", deleteCount, " 个标注对象（含标签）");
   }
}

//+------------------------------------------------------------------+
//| [新增] 解析 HH:MM 到分钟数                                      |
//+------------------------------------------------------------------+
int ParseTimeStringToMinutes(string timeStr)
{
   int colonPos = StringFind(timeStr, ":");
   if(colonPos < 0)
      return (int)StringToInteger(timeStr) * 60;

   string hourStr = StringSubstr(timeStr, 0, colonPos);
   string minuteStr = StringSubstr(timeStr, colonPos + 1);
   int hours = (int)StringToInteger(hourStr);
   int minutes = (int)StringToInteger(minuteStr);

   if(hours < 0) hours = 0;
   if(minutes < 0) minutes = 0;
   if(minutes > 59) minutes = 59;

   return hours * 60 + minutes;
}

//+------------------------------------------------------------------+
//| [新增] 获取服务器时间当天零点                                   |
//+------------------------------------------------------------------+
datetime GetServerDayStart(datetime serverTime)
{
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| [新增] 解析最近一场会话时间窗口                                 |
//+------------------------------------------------------------------+
bool ResolveRecentSessionWindow(datetime nowServer, string sessionStartGmt, string sessionEndGmt, datetime &sessionStart, datetime &sessionEnd, bool &isActive)
{
   int startMinutesGmt = ParseTimeStringToMinutes(sessionStartGmt);
   int endMinutesGmt = ParseTimeStringToMinutes(sessionEndGmt);
   int durationMinutes = endMinutesGmt - startMinutesGmt;
   if(durationMinutes <= 0)
      durationMinutes += 24 * 60;

   int serverStartMinutes = startMinutesGmt + Server_GMT_Offset * 60;
   datetime dayStart = GetServerDayStart(nowServer);
   datetime todaySessionStart = dayStart + serverStartMinutes * 60;
   datetime todaySessionEnd = todaySessionStart + durationMinutes * 60;

   if(nowServer < todaySessionStart)
   {
      sessionStart = todaySessionStart - 24 * 60 * 60;
      sessionEnd = sessionStart + durationMinutes * 60;
   }
   else
   {
      sessionStart = todaySessionStart;
      sessionEnd = todaySessionEnd;
   }

   isActive = (nowServer >= sessionStart && nowServer <= sessionEnd);
   return (sessionEnd > sessionStart);
}

//+------------------------------------------------------------------+
//| [新增] 生成最近一场会话的日期键                                 |
//+------------------------------------------------------------------+
string GetSessionKey(datetime sessionStart)
{
   return TimeToString(sessionStart, TIME_DATE);
}

//+------------------------------------------------------------------+
//| [新增] 使用 M1 数据计算最近一场会话高低点                        |
//+------------------------------------------------------------------+
bool CalculateSessionExtremesFromM1(string sessionCode, string sessionStartGmt, string sessionEndGmt, SessionExtremesResult &result)
{
   datetime nowServer = TimeCurrent();
   datetime sessionStart = 0;
   datetime sessionEnd = 0;
   bool isActive = false;

   result.has_result = false;

   if(!ResolveRecentSessionWindow(nowServer, sessionStartGmt, sessionEndGmt, sessionStart, sessionEnd, isActive))
      return false;

   datetime calcEnd = isActive ? nowServer : sessionEnd;
   if(calcEnd <= sessionStart)
      return false;

   int m1Bars = iBars(Symbol(), PERIOD_M1);
   if(m1Bars <= 0)
   {
      Print("[", sessionCode, " Session HL] M1 数据不可用，无法计算会话高低点");
      return false;
   }

   int startIndex = iBarShift(Symbol(), PERIOD_M1, sessionStart, false);
   int endIndex = iBarShift(Symbol(), PERIOD_M1, calcEnd, false);
   if(startIndex < 0 || endIndex < 0)
   {
      Print("[", sessionCode, " Session HL] 无法定位会话时间窗口对应的 M1 K线");
      return false;
   }

   if(startIndex < endIndex)
   {
      int temp = startIndex;
      startIndex = endIndex;
      endIndex = temp;
   }

   int barCount = startIndex - endIndex + 1;
   if(barCount <= 0)
      return false;

   int highIndex = iHighest(Symbol(), PERIOD_M1, MODE_HIGH, barCount, endIndex);
   int lowIndex = iLowest(Symbol(), PERIOD_M1, MODE_LOW, barCount, endIndex);
   if(highIndex < 0 || lowIndex < 0)
      return false;

   result.has_result = true;
   result.is_active = isActive;
   result.session_start = sessionStart;
   result.session_end = sessionEnd;
   result.calc_end = calcEnd;
   result.high_time = iTime(Symbol(), PERIOD_M1, highIndex); // 高点时间=高点所在M1源K线的时间（服务器/图表时间）
   result.low_time = iTime(Symbol(), PERIOD_M1, lowIndex);   // 低点时间=低点所在M1源K线的时间（如显示03:59，即该分钟K线时间）
   result.high_price = iHigh(Symbol(), PERIOD_M1, highIndex);
   result.low_price = iLow(Symbol(), PERIOD_M1, lowIndex);
   return true;
}

//+------------------------------------------------------------------+
//| [新增] 创建或更新亚盘高低点射线                                  |
//+------------------------------------------------------------------+
void CreateOrUpdateSessionRay(string name, datetime sourceTime, double price, color lineColor)
{
   datetime rayTime2 = TimeCurrent() + 24 * 60 * 60;
   int visibilityFlags = CalculateVisibilityFlags(Period(), VisibilityMode);
   bool isHighRay = (StringFind(name, "High") >= 0);

   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_TREND, 0, sourceTime, price, rayTime2, price))
         return;
   }

   ObjectSetInteger(0, name, OBJPROP_TIME, 0, sourceTime);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, rayTime2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, isHighRay ? STYLE_SOLID : STYLE_DASH);
   ObjectSetInteger(0, name, OBJPROP_RAY, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, visibilityFlags);
}

//+------------------------------------------------------------------+
//| [新增] 创建或更新亚盘高低点源蜡烛标记                            |
//+------------------------------------------------------------------+
void CreateOrUpdateSessionMarker(string name, datetime sourceTime, double price, bool isHigh, color markerColor)
{
   int visibilityFlags = CalculateVisibilityFlags(Period(), VisibilityMode);
   int arrowCode = isHigh ? 234 : 233;
   double chartMax = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   double chartMin = ChartGetDouble(0, CHART_PRICE_MIN, 0);
   double chartRange = MathAbs(chartMax - chartMin);

   if(chartRange <= 0.0)
      chartRange = MathMax(100 * Point, MathAbs(price) * 0.002);

   // 使用可视范围做动态偏移，避免缩放后箭头贴到K线上
   double visualOffset = MathMax(12 * Point, chartRange * 0.012);
   double markerPrice = isHigh ? (price + visualOffset) : (price - visualOffset);

   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_ARROW, 0, sourceTime, markerPrice))
         return;
   }

   ObjectSetInteger(0, name, OBJPROP_TIME, 0, sourceTime);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, markerPrice);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, markerColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, visibilityFlags);
}

//+------------------------------------------------------------------+
//| [新增] 创建或更新亚盘高低点右侧价格牌                            |
//+------------------------------------------------------------------+
void CreateOrUpdateSessionPriceTag(string name, double price, color lineColor)
{
   int visibilityFlags = CalculateVisibilityFlags(Period(), VisibilityMode);
   datetime currentTime = iTime(_Symbol, _Period, 0);

   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_ARROW_RIGHT_PRICE, 0, currentTime, price))
         return;
   }

   ObjectSetInteger(0, name, OBJPROP_TIME, 0, currentTime);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, visibilityFlags);
}

//+------------------------------------------------------------------+
//| [新增] 创建或更新亚盘高低点文本标签                              |
//+------------------------------------------------------------------+
void CreateOrUpdateSessionLabel(string name, datetime sourceTime, double anchorPrice, string text, bool isHigh, color labelColor, int labelSize)
{
   int visibilityFlags = CalculateVisibilityFlags(Period(), VisibilityMode);
   double priceOffset = MathMax(45 * Point, MathAbs(anchorPrice) * 0.0004);
   double labelPrice = isHigh ? (anchorPrice + priceOffset) : (anchorPrice - priceOffset);
   datetime labelTime = iTime(_Symbol, _Period, 0);

   if(Bars(_Symbol, _Period) > 1)
      labelTime = iTime(_Symbol, _Period, 1);

   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_TEXT, 0, labelTime, labelPrice))
         return;
   }

   ObjectSetInteger(0, name, OBJPROP_TIME, 0, labelTime);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, labelPrice);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, labelColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, MathMax(8, labelSize - 1));
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, isHigh ? ANCHOR_RIGHT_LOWER : ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, visibilityFlags);
}

//+------------------------------------------------------------------+
//| [新增] 绘制或更新会话高低点对象                                  |
//+------------------------------------------------------------------+
void DrawSessionHLObjects(string sessionCode, string sessionName, color highColor, color lowColor, color labelColor, int labelSize, const SessionExtremesResult &result)
{
   if(!result.has_result)
      return;

   string prefix = "SessHL_" + sessionCode + "_";
   string highRay = prefix + "High_Ray";
   string lowRay = prefix + "Low_Ray";
   string highMark = prefix + "High_Mark";
   string lowMark = prefix + "Low_Mark";
   string highPriceTag = prefix + "High_Price";
   string lowPriceTag = prefix + "Low_Price";
   string highLabel = prefix + "High_Label";
   string lowLabel = prefix + "Low_Label";

   string stateText = result.is_active ? "进行中" : "已完成";
   string highTimeText = TimeToString(result.high_time, TIME_MINUTES); // 标签中的时间是会话极值对应M1 K线的分钟时间，不是点击时间
   string lowTimeText = TimeToString(result.low_time, TIME_MINUTES);   // 例如“03:59”表示低点出现在03:59这根M1 K线上
   string highText = sessionName + "高点 " + highTimeText + "  " + stateText;
   string lowText = sessionName + "低点 " + lowTimeText + "  " + stateText;

   CreateOrUpdateSessionRay(highRay, result.high_time, result.high_price, highColor);
   CreateOrUpdateSessionRay(lowRay, result.low_time, result.low_price, lowColor);
   CreateOrUpdateSessionMarker(highMark, result.high_time, result.high_price, true, highColor);
   CreateOrUpdateSessionMarker(lowMark, result.low_time, result.low_price, false, lowColor);
   CreateOrUpdateSessionPriceTag(highPriceTag, result.high_price, highColor);
   CreateOrUpdateSessionPriceTag(lowPriceTag, result.low_price, lowColor);
   CreateOrUpdateSessionLabel(highLabel, result.high_time, result.high_price, highText, true, labelColor, labelSize);
   CreateOrUpdateSessionLabel(lowLabel, result.low_time, result.low_price, lowText, false, labelColor, labelSize);
}

//+------------------------------------------------------------------+
//| [新增] 删除会话高低点对象                                        |
//+------------------------------------------------------------------+
void DeleteSessionHLObjects(string sessionCode)
{
   string prefix = "SessHL_" + sessionCode + "_";
   string names[];
   ArrayResize(names, 8);
   names[0] = prefix + "High_Ray";
   names[1] = prefix + "Low_Ray";
   names[2] = prefix + "High_Mark";
   names[3] = prefix + "Low_Mark";
   names[4] = prefix + "High_Price";
   names[5] = prefix + "Low_Price";
   names[6] = prefix + "High_Label";
   names[7] = prefix + "Low_Label";

   for(int i = 0; i < ArraySize(names); i++)
   {
      if(ObjectFind(0, names[i]) >= 0)
         ObjectDelete(0, names[i]);
   }
}

//+------------------------------------------------------------------+
//| [新增] 手动或首次刷新会话高低点                                  |
//+------------------------------------------------------------------+
bool RefreshSessionHighLow(bool &isVisible,
                           string &lastSessionKey,
                           string sessionCode,
                           string sessionName,
                           string sessionStartGmt,
                           string sessionEndGmt,
                           bool forceRefresh,
                           color highColor,
                           color lowColor,
                           color labelColor,
                           int labelSize)
{
   if(!isVisible)
      return false;

   SessionExtremesResult result;
   if(!CalculateSessionExtremesFromM1(sessionCode, sessionStartGmt, sessionEndGmt, result))
      return false;

   string sessionKey = GetSessionKey(result.session_start);
   if(!forceRefresh && !result.is_active && lastSessionKey == sessionKey)
      return true;

   DrawSessionHLObjects(sessionCode, sessionName, highColor, lowColor, labelColor, labelSize, result);
   lastSessionKey = sessionKey;
   return true;
}

//+------------------------------------------------------------------+
//| [新增] 定时器节流刷新会话高低点                                  |
//+------------------------------------------------------------------+
void MaybeAutoRefreshSessionHL(bool isVisible,
                               string &lastSessionKey,
                               uint &lastUpdateTick,
                               string sessionCode,
                               string sessionName,
                               string sessionStartGmt,
                               string sessionEndGmt,
                               bool autoRefresh,
                               int refreshSeconds,
                               color highColor,
                               color lowColor,
                               color labelColor,
                               int labelSize)
{
   if(!isVisible)
      return;

   SessionExtremesResult result;
   if(!CalculateSessionExtremesFromM1(sessionCode, sessionStartGmt, sessionEndGmt, result))
      return;

   string sessionKey = GetSessionKey(result.session_start);
   uint nowTick = GetTickCount();
   uint intervalMs = (uint)MathMax(5, refreshSeconds) * 1000;

   if(result.is_active)
   {
      if(!autoRefresh)
         return;

      if(nowTick - lastUpdateTick < intervalMs)
         return;

      DrawSessionHLObjects(sessionCode, sessionName, highColor, lowColor, labelColor, labelSize, result);
      lastSessionKey = sessionKey;
      lastUpdateTick = nowTick;
      return;
   }

   if(lastSessionKey != sessionKey)
   {
      DrawSessionHLObjects(sessionCode, sessionName, highColor, lowColor, labelColor, labelSize, result);
      lastSessionKey = sessionKey;
      lastUpdateTick = nowTick;
   }
}

//+------------------------------------------------------------------+
//| [新增] 亚盘封装                                                   |
//+------------------------------------------------------------------+
void DeleteAsiaSessionHLObjects()
{
   DeleteSessionHLObjects("Asia");
}

bool RefreshAsiaSessionHighLow(bool forceRefresh)
{
   return RefreshSessionHighLow(isAsiaSessionHLVisible,
                                g_lastAsiaSessionKey,
                                "Asia",
                                Asia_Session_Name,
                                Asia_Session_Start_GMT,
                                Asia_Session_End_GMT,
                                forceRefresh,
                                Asia_High_Ray_Color,
                                Asia_Low_Ray_Color,
                                Asia_Session_Label_Color,
                                Asia_Session_Label_Size);
}

void MaybeAutoRefreshAsiaSessionHL()
{
   MaybeAutoRefreshSessionHL(isAsiaSessionHLVisible,
                             g_lastAsiaSessionKey,
                             lastAsiaSessionHLUpdate,
                             "Asia",
                             Asia_Session_Name,
                             Asia_Session_Start_GMT,
                             Asia_Session_End_GMT,
                             Asia_Session_AutoRefresh,
                             Asia_Session_Refresh_Seconds,
                             Asia_High_Ray_Color,
                             Asia_Low_Ray_Color,
                             Asia_Session_Label_Color,
                             Asia_Session_Label_Size);
}

//+------------------------------------------------------------------+
//| [新增] 伦敦盘封装                                                 |
//+------------------------------------------------------------------+
void DeleteLondonSessionHLObjects()
{
   DeleteSessionHLObjects("London");
}

bool RefreshLondonSessionHighLow(bool forceRefresh)
{
   return RefreshSessionHighLow(isLondonSessionHLVisible,
                                g_lastLondonSessionKey,
                                "London",
                                London_Session_Name,
                                London_Session_Start_GMT,
                                London_Session_End_GMT,
                                forceRefresh,
                                London_High_Ray_Color,
                                London_Low_Ray_Color,
                                London_Session_Label_Color,
                                London_Session_Label_Size);
}

void MaybeAutoRefreshLondonSessionHL()
{
   MaybeAutoRefreshSessionHL(isLondonSessionHLVisible,
                             g_lastLondonSessionKey,
                             lastLondonSessionHLUpdate,
                             "London",
                             London_Session_Name,
                             London_Session_Start_GMT,
                             London_Session_End_GMT,
                             London_Session_AutoRefresh,
                             London_Session_Refresh_Seconds,
                             London_High_Ray_Color,
                             London_Low_Ray_Color,
                             London_Session_Label_Color,
                             London_Session_Label_Size);
}

//+------------------------------------------------------------------+
//| [新增] 纽约盘封装                                                 |
//+------------------------------------------------------------------+
void DeleteNewYorkSessionHLObjects()
{
   DeleteSessionHLObjects("NewYork");
}

bool RefreshNewYorkSessionHighLow(bool forceRefresh)
{
   return RefreshSessionHighLow(isNewYorkSessionHLVisible,
                                g_lastNewYorkSessionKey,
                                "NewYork",
                                NewYork_Session_Name,
                                NewYork_Session_Start_GMT,
                                NewYork_Session_End_GMT,
                                forceRefresh,
                                NewYork_High_Ray_Color,
                                NewYork_Low_Ray_Color,
                                NewYork_Session_Label_Color,
                                NewYork_Session_Label_Size);
}

void MaybeAutoRefreshNewYorkSessionHL()
{
   MaybeAutoRefreshSessionHL(isNewYorkSessionHLVisible,
                             g_lastNewYorkSessionKey,
                             lastNewYorkSessionHLUpdate,
                             "NewYork",
                             NewYork_Session_Name,
                             NewYork_Session_Start_GMT,
                             NewYork_Session_End_GMT,
                             NewYork_Session_AutoRefresh,
                             NewYork_Session_Refresh_Seconds,
                             NewYork_High_Ray_Color,
                             NewYork_Low_Ray_Color,
                             NewYork_Session_Label_Color,
                             NewYork_Session_Label_Size);
}