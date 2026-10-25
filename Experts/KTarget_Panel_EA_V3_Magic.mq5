//+------------------------------------------------------------------+
//|                                          KTarget_Panel_EA.mq4    |
//|                                                                  |
//|                               带有可视化面板的EA交易程序          |
//+------------------------------------------------------------------+
#property copyright "KTarget"
#property link      ""
#property version   "1.00"
#property strict

#include <Controls/Dialog.mqh>
#include <Controls/Button.mqh>
#include <Controls/Edit.mqh>
#include <Controls/Label.mqh>
// MQL5转换层：保留原业务调用形态，交易实现位于 Include/KTarget_Panel_MQL5_Compat.mqh
#include <K_Panel/KTarget_Panel_MQL5_Compat.mqh>

//#region MARK: 模块--参数
//+------------------------------------------------------------------+
//| 面板参数                                                          |
//+------------------------------------------------------------------+
input int    PanelX = 250;            // 面板X坐标
input int    PanelY = 20;            // 面板Y坐标
input color  PanelColor = clrWhite;  // 面板背景色
input color  BorderColor = clrNavy;  // 边框颜色

//+------------------------------------------------------------------+
//| 止损标签参数                                                      |
//+------------------------------------------------------------------+
input bool   Show_EA_SL_Labels = false;   // 显示EA止损标签
input int    SL_Distance_Dollars = 5;    // 止损距离（美金）
input double Label_Offset = 0.3;         // 标签偏移量（避免重叠）
input color  Buy_SL_Color = clrOrangeRed;   // 做多止损颜色
input color  Sell_SL_Color = clrLimeGreen; // 做空止损颜色

//+------------------------------------------------------------------+
//| 时区调整说明（已自动化处理）                                        |
//+------------------------------------------------------------------+
// Note: 时区偏移已自动计算 [localOffset = TimeLocal() - TimeCurrent()]
//       无需手动配置，系统自动适应夏令时变化。原参数 ServerGMT_Offset 已废弃。
// input int ServerGMT_Offset = 0;  // [已废弃] 服务器GMT时区偏移修正

//+------------------------------------------------------------------+
//| 日志级别枚举                                                      |
//+------------------------------------------------------------------+
enum LogLevel
{
   LOG_OFF     = 0,  // 静默模式（仅Alert弹窗）
   LOG_ERROR   = 1,  // 仅错误（失败、异常）
   LOG_WARNING = 2,  // 警告信息（切换备用方案、数据异常）
   LOG_INFO    = 3,  // 正常信息（成功汇总、关键事件）
   LOG_DEBUG   = 4   // 调试详情（跳过原因、中间变量）
};

input LogLevel Log_Level = LOG_INFO;  // 日志级别（生产推荐INFO，调试推荐DEBUG）

//+------------------------------------------------------------------+
//| 智能计算参数                                                      |
//+------------------------------------------------------------------+
input double SmartCalc_DefaultScalePct = 80.0;  // 智能计算默认减仓比例 (30-95)
input bool   SmartCalc_AutoEnable = true;       // 计算后自动开启减仓功能

//+------------------------------------------------------------------+
//| 爆仓线 & 浮亏警戒线 参数                                          |
//+------------------------------------------------------------------+
input bool   Show_Liquidation_Line = true;   // 显示爆仓线（实时计算爆仓价）
input bool   Show_Drawdown_Lines   = true;   // 显示浮亏百分比警戒线
input double Drawdown_Level1       = 30.0;   // 浮亏警戒线1（%）
input double Drawdown_Level2       = 50.0;   // 浮亏警戒线2（%）
input int    BE_Buffer_Points      = 30;     // 保本缓冲(点)

//+------------------------------------------------------------------+
//| 价格选择模式枚举                                                  |
//+------------------------------------------------------------------+
enum PriceSelectMode
{
   MODE_NONE = 0,         // 正常模式
   MODE_SELECT_SL = 1,    // 选择止损价格
   MODE_SELECT_TP = 2,    // 选择止盈价格
   MODE_SELECT_ENTRY = 3  // 选择挂单价格
};
//#endregion

//#region MARK: 模块--全局状态变量
//+------------------------------------------------------------------+
//| Magic Number 系统配置                                            |
//+------------------------------------------------------------------+
#define MAGIC_EA_PREFIX 10000000  // EA Magic前缀（10000000-10099999）

//+------------------------------------------------------------------+
//| 全局状态变量                                                      |
//+------------------------------------------------------------------+
PriceSelectMode g_priceSelectMode = MODE_NONE;      // 价格选择模式
uint g_lastButtonClickTime = 0;                     // 上次按钮点击时间戳（防穿透）
bool g_enablePriceSnapping = false;                 // 价格磁吸功能开关（默认关闭）
string g_magicCounterKey = "";                      // Magic计数器全局变量Key（在OnInit中初始化）

//#region MARK: 模块--全局函数原型
void UpdateEA_SL_Display();
void CleanupEA_SL_Labels();
void LiqDrawLevel(const string baseName, double price, color clr, int width,
                  int lineStyle, const string labelText);
void UpdateLiquidationLines();
// int  OnInit();
// void OnDeinit(const int reason);
// void OnTick();
// void OnChartEvent(const int id, const long &lparam, const double &dparam,
//                   const string &sparam);
//#endregion

//+------------------------------------------------------------------+
//| 日志宏定义（避免重复if判断）                                      |
//+------------------------------------------------------------------+
#define LOG_ERROR(msg)   if(Log_Level >= LOG_ERROR)   Print("[ERR] ", msg)
#define LOG_WARNING(msg) if(Log_Level >= LOG_WARNING) Print("[WARN] ", msg)
#define LOG_INFO(msg)    if(Log_Level >= LOG_INFO)    Print("[INFO] ", msg)
#define LOG_DEBUG(msg)   if(Log_Level >= LOG_DEBUG)   Print("[DBG] ", msg)

//+------------------------------------------------------------------+
//| 今日订单记录面板                                                  |
//+------------------------------------------------------------------+
#define ORDERS_ROWS 100  // 绝对上限，今日订单实际不会超过此数
//#endregion

//#region MARK: 模块--OrdersPanel
class COrdersPanel : public CAppDialog
{
private:
   CLabel           m_lblTitle;
   CLabel           m_lblHdr;
   CLabel           m_lblRows[ORDERS_ROWS];
   int              m_rowCount;   // 当前实际显示行数
   int              m_maxRows;    // 本次创建时预分配的行数（由外部按实际订单数设置）

public:
                    COrdersPanel() { m_rowCount = 0; m_maxRows = ORDERS_ROWS; }
                   ~COrdersPanel() {}

   void             SetMaxRows(int n) { m_maxRows = MathMin(MathMax(n, 1), ORDERS_ROWS); }
   virtual bool     Create(const long chart, const string name, const int subwin,
                           const int x1, const int y1, const int x2, const int y2);
   void             RefreshOrders(void);

protected:
   virtual bool     CreateControls(void);
};

//--- COrdersPanel 创建面板
bool COrdersPanel::Create(const long chart, const string name, const int subwin,
                           const int x1, const int y1, const int x2, const int y2)
{
   if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
      return(false);
   Caption("Daily Orders");
   if(!CreateControls())
      return(false);
   return(true);
}

//--- COrdersPanel 创建控件
bool COrdersPanel::CreateControls(void)
{
   int x = 5;
   int w = ClientAreaWidth() - 10;

   // 标题行
   if(!m_lblTitle.Create(m_chart_id, m_name+"OrdTitle", m_subwin, x, 3, x+w, 20))
      return(false);
   m_lblTitle.Text("-- 今日订单 --");
   if(!Add(m_lblTitle)) return(false);

   // 表头行
   if(!m_lblHdr.Create(m_chart_id, m_name+"OrdHdr", m_subwin, x, 23, x+w, 40))
      return(false);
   m_lblHdr.Font("Courier New");
   m_lblHdr.FontSize(8);
   m_lblHdr.Text(" 时间    T Lots Open     SL       Exit     P/L    Pips  Dur   ");
   if(!Add(m_lblHdr)) return(false);

   // 数据行：仅创建本次实际需要的行数（m_maxRows），每行 17px
   for(int i = 0; i < m_maxRows; i++)
   {
      if(!m_lblRows[i].Create(m_chart_id, m_name+"OrdRow"+IntegerToString(i),
                               m_subwin, x, 43+i*17, x+w, 60+i*17))
         return(false);
      m_lblRows[i].Font("Courier New");
      m_lblRows[i].FontSize(8);
      m_lblRows[i].Text("");
      if(!Add(m_lblRows[i])) return(false);
   }

   return(true);
}

//--- COrdersPanel 刷新订单数据
void COrdersPanel::RefreshOrders(void)
{
   // 判断品种类型
   bool isMetals = (StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "XAG") >= 0 ||
                    StringFind(_Symbol, "GOLD") >= 0 || StringFind(_Symbol, "SILVER") >= 0);
   
   bool isCrypto = (StringFind(_Symbol, "BTC") >= 0 || StringFind(_Symbol, "ETH") >= 0 ||
                    StringFind(_Symbol, "LTC") >= 0 || StringFind(_Symbol, "XRP") >= 0 ||
                    StringFind(_Symbol, "BCH") >= 0 || StringFind(_Symbol, "ADA") >= 0 ||
                    StringFind(_Symbol, "DOT") >= 0 || StringFind(_Symbol, "DOGE") >= 0);
   
   // 根据报价位数动态计算 pip 单位（支持4位和5位报价）
   double pointsPerPip = (_Digits == 5 || _Digits == 3) ? 10.0 : 1.0;
   
   // [最优方案] 直接计算本地与服务器的时差（秒级精度，自动适应夏令时）
   int      localOffset = (int)(TimeLocal() - TimeCurrent());
   datetime localNow    = TimeLocal();  // 直接使用本地系统时间
   datetime localToday0 = localNow - (localNow % 86400);
   datetime svrToday0   = (datetime)(localToday0 - localOffset);

   // 更新面板标题（品种 + 本地时间日期）
   m_lblTitle.Text(StringFormat("-- %s  %04d-%02d-%02d (Local) --",
      _Symbol, TimeYear(localNow), TimeMonth(localNow), TimeDay(localNow)));

   int    count    = 0;
   string rowTexts[ORDERS_ROWS];  // 静态上限缓冲，实际只填 m_maxRows 条

   // --- 1. 当前持仓（当前品种，标记 * ）---
   for(int i = 0; i < OrdersTotal() && count < m_maxRows; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      datetime localOpen = (datetime)(OrderOpenTime() + localOffset);
      string   tStr   = StringFormat("%02d:%02d",
                           TimeHour(localOpen), TimeMinute(localOpen));
      string   typ    = (OrderType() == OP_BUY) ? "B" : "S";
      double   exitPx = (OrderType() == OP_BUY) ? Bid : Ask;
      double   prof   = OrderProfit() + OrderSwap() + OrderCommission();
      double   diff   = (OrderType() == OP_BUY) ?
                           exitPx - OrderOpenPrice() :
                           OrderOpenPrice() - exitPx;
      double   pts    = (isMetals || isCrypto) ? diff : diff / (_Point * pointsPerPip);  // 贵金属/加密货币显示价格差，外汇显示pips
      int      dSec   = (int)(TimeCurrent() - OrderOpenTime());
      string   durStr;
      if(dSec < 60)              durStr = StringFormat("%d", dSec) + "s";
      else if(dSec < 3600)       durStr = StringFormat("%dm%02d", dSec/60, dSec%60) + "s";
      else                       durStr = StringFormat("%dh%02dm",     dSec/3600, (dSec%3600)/60);
      string   slStr  = (OrderStopLoss() > 0) ?
                           DoubleToString(OrderStopLoss(), _Digits) : "---";

      rowTexts[count++] = StringFormat("*%s %s %4.2f %-9s%-9s%-9s%+7.2f %+6.1f ",
         tStr, typ, OrderLots(),
         DoubleToString(OrderOpenPrice(), _Digits),
         slStr,
         DoubleToString(exitPx, _Digits),
         prof, pts) + durStr;
   }

   // --- 2. 历史订单（今日北京时间内已关闭）---
   for(int i = OrdersHistoryTotal()-1; i >= 0 && count < m_maxRows; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(OrderCloseTime() < svrToday0) continue;

      datetime localOpen = (datetime)(OrderOpenTime() + localOffset);
      string   tStr   = StringFormat("%02d:%02d",
                           TimeHour(localOpen), TimeMinute(localOpen));
      string   typ    = (OrderType() == OP_BUY) ? "B" : "S";
      double   prof   = OrderProfit() + OrderSwap() + OrderCommission();
      double   diff   = (OrderType() == OP_BUY) ?
                           OrderClosePrice() - OrderOpenPrice() :
                           OrderOpenPrice() - OrderClosePrice();
      double   pts    = (isMetals || isCrypto) ? diff : diff / (_Point * pointsPerPip);  // 贵金属/加密货币显示价格差，外汇显示pips
      int      dSec   = (int)(OrderCloseTime() - OrderOpenTime());
      string   durStr;
      if(dSec < 60)              durStr = StringFormat("%d", dSec) + "s";
      else if(dSec < 3600)       durStr = StringFormat("%dm%02d", dSec/60, dSec%60) + "s";
      else                       durStr = StringFormat("%dh%02dm",     dSec/3600, (dSec%3600)/60);
      string   slStr  = (OrderStopLoss() > 0) ?
                           DoubleToString(OrderStopLoss(), _Digits) : "---";

      rowTexts[count++] = StringFormat(" %s %s %4.2f %-9s%-9s%-9s%+7.2f %+6.1f ",
         tStr, typ, OrderLots(),
         DoubleToString(OrderOpenPrice(), _Digits),
         slStr,
         DoubleToString(OrderClosePrice(), _Digits),
         prof, pts) + durStr;
   }

   // 更新所有行标签
   for(int i = 0; i < m_maxRows; i++)
      m_lblRows[i].Text(i < count ? rowTexts[i] : "");

   m_rowCount = count;
   ChartRedraw();
}
//#endregion

//#region MARK: 模块--结构体
//+------------------------------------------------------------------+
//| 自动减仓记录结构体（Magic Number方案：彻底解决Ticket断链问题）      |
//+------------------------------------------------------------------+
struct ScaleRecord
{
   int      magicNumber; // 唯一不变的订单标识（Magic Number）
   bool     everScaled;  // 该订单是否曾经减仓过（用于"单次减仓模式"）
   bool     tooSmall;    // [优化] 是否已进入"无法减仓"状态（避免重复检查）
   datetime lastCheck;   // 上次检查时间（用于清理）
};

//+------------------------------------------------------------------+
//| 止损保护记录结构体（独立架构：完全分离止损系统与减仓系统）          |
//+------------------------------------------------------------------+
struct StopLossRecord
{
   int      magicNumber;     // 唯一标识（Magic Number）
   bool     slProtected;     // 是否已设置止损保护
   datetime protectedTime;   // 首次设置止损的时间
};
//#endregion

//#region MARK: 模块--自定义面板类
//+------------------------------------------------------------------+
//| 自定义面板类                                                      |
//+------------------------------------------------------------------+
class CTradePanel : public CAppDialog
{
private:
   // === 信息显示容器（模块1之前） ===
   CEdit            m_edtDailyProfit;      // 今日盈亏容器
   CButton          m_btnToggleProfit;     // 盈亏容器显示/隐藏按钮
   bool             m_showProfit;          // 盈亏容器显示状态
   
   CEdit            m_edtPositions;        // 持仓价格容器
   CButton          m_btnTogglePositions;  // 持仓容器显示/隐藏按钮
   bool             m_showPositions;       // 持仓容器显示状态
   
   // 模块1: 开仓交易模块控件
   CLabel           m_lblStopLoss;    // 止损标签
   CEdit            m_edtStopLoss;    // 止损输入框
   CButton          m_btnSelectSL;    // 选择止损按钮 (NEW)
   
   CLabel           m_lblLots;        // 手数标签
   CButton          m_btnLotsDecrease;// 手数减少按钮
   CEdit            m_edtLots;        // 手数输入框
   CButton          m_btnLotsIncrease;// 手数增加按钮
   
   CLabel           m_lblTakeProfit;  // 止盈标签
   CEdit            m_edtTakeProfit;  // 止盈输入框
   CButton          m_btnSelectTP;    // 选择止盈按钮 (NEW)
   
   CButton          m_btnBuy;         // 现价买入按钮
   CButton          m_btnSell;        // 现价卖出按钮
   
   // 模块1B: 挂单交易模块控件
   CLabel           m_lblPendingOrder; // 挂单模块标题
   CEdit            m_edtEntryPrice;   // 挂单价格输入框
   CButton          m_btnSelectEntry;  // 选择挂单价格按钮
   CButton          m_btnBuyLimit;     // Buy Limit按钮
   CButton          m_btnSellLimit;    // Sell Limit按钮
   CButton          m_btnBuyStop;      // Buy Stop按钮
   CButton          m_btnSellStop;     // Sell Stop按钮
   
   // 模块2: 止盈止损管理模块控件
   CLabel           m_lblMod2;         // 模块2标题
   CLabel           m_lblSlPoints;     // 止损点数标签
   CEdit            m_edtSlPoints;     // 止损点数输入框
   CButton          m_btnSetSlPoints;  // 设置止损点数按钮
   CLabel           m_lblSlPrice2;     // 止损价格标签
   CEdit            m_edtSlPrice2;     // 止损价格输入框
   CButton          m_btnSetSlPrice;   // 设置止损价格按钮
   CLabel           m_lblTpPoints;     // 止盈点数标签
   CEdit            m_edtTpPoints;     // 止盈点数输入框
   CButton          m_btnSetTpPoints;  // 设置止盈点数按钮
   CLabel           m_lblTpPrice2;     // 止盈价格标签
   CEdit            m_edtTpPrice2;     // 止盈价格输入框
   CButton          m_btnSetTpPrice;   // 设置止盈价格按钮
   CButton          m_btnClearSl;      // 强制清除止损按钮
   CButton          m_btnClearTp;      // 强制清除止盈按钮

   // 模块3: 比例平仓模块控件
   CLabel           m_lblMod3;          // 模块3标题
   CButton          m_btnClose50;       // 50%平仓按钮
   CButton          m_btnClose80;       // 80%平仓按钮
   CButton          m_btnClose100;      // 100%平仓按钮
   CLabel           m_lblClosePct;      // 自定义比例标签
   CEdit            m_edtClosePct;      // 自定义比例输入框
   CButton          m_btnCloseCustom;   // 执行自定义比例平仓按钮
   // 模块3子功能2: 按手数平仓
   CButton          m_btnCloseLot1;     // -1手平仓按钮
   CButton          m_btnCloseLot01;    // -0.1手平仓按钮
   CButton          m_btnCloseLot001;   // -0.01手平仓按钮
   CLabel           m_lblCloseLots;     // 自定义手数标签
   CEdit            m_edtCloseLots;     // 自定义手数输入框
   CButton          m_btnCloseByLots;   // 按手数执行平仓按钮
   CButton          m_btnCloseSymbol;   // 平当前品种按钮
   CButton          m_btnBreakEven;     // 一键保本按钮
   CButton          m_btnRecoveryExit;  // 回本退出按钮

   // 模块5: 自动减仓模块控件
   CLabel           m_lblScaleOut;         // 模块标题
   CLabel           m_lblTriggerPts;       // 触发点数标签
   CEdit            m_edtTriggerPts;       // 触发点数输入框
   CLabel           m_lblScalePct;         // 减仓比例标签
   CEdit            m_edtScalePct;         // 减仓比例输入框
   CLabel           m_lblScaleLots;        // 减仓手数标签
   CEdit            m_edtScaleLots;        // 减仓手数输入框
   CButton          m_btnToggleScaleOut;   // 开启/关闭按钮
   CButton          m_btnSmartCalc;        // 智能计算按钮
   CButton          m_btnToggleMultiScale; // 允许多次减仓开关（NEW）
   
   // ========== 自动减仓系统（独立管理）==========
   bool             m_scaleOutEnabled;        // 是否启用自动减仓
   bool             m_allowMultipleScaleOut;  // 是否允许同一订单多次减仓（默认false）
   ScaleRecord      m_scaleRecords[100];      // 减仓记录数组（容量：100）
   int              m_scaleRecordCount;       // 减仓记录计数器
   
   // ========== 自动止损系统（独立管理）==========
   double           m_atrMultiplier;          // ATR倍数（默认1.5）
   StopLossRecord   m_slRecords[300];         // 止损记录数组（容量：300，独立于减仓系统）
   int              m_slRecordCount;          // 止损记录计数器
   
   // === 输入框状态保存变量（12个）===
   string           m_lastLots;            // 最后的手数值
   string           m_lastStopLoss;        // 最后的止损价格
   string           m_lastTakeProfit;      // 最后的止盈价格
   string           m_lastSlPoints;        // 止损点数
   string           m_lastSlPrice2;        // 止损价格(模块2)
   string           m_lastTpPoints;        // 止盈点数
   string           m_lastTpPrice2;        // 止盈价格(模块2)
   string           m_lastClosePct;        // 平仓百分比
   string           m_lastCloseLots;       // 平仓手数
   string           m_lastTriggerPts;      // 触发点数
   string           m_lastScalePct;        // 减仓比例
   string           m_lastScaleLots;       // 减仓手数
   string           m_lastEntryPrice;      // 挂单价格

   // 模块4: 订单记录模块控件
   CLabel           m_lblMod4;          // 模块4标题
   CButton          m_btnResetInputs;   // 重置输入框按钮
   CButton          m_btnViewOrders;    // 查看今日订单按钮

public:
                    CTradePanel();
                   ~CTradePanel();
   virtual bool     Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);
   virtual bool     OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam);
   virtual void     ChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam); // 拦截CHART_CHANGE防止自动最小化
   void             UpdateInfoContainers(void);  // 更新信息容器
   void             CheckAutoScaleOut(void);     // 检查并执行自动减仓（需要public以便在OnTick中调用）
   void             CheckAutoStopLoss(void);     // [自动止损] 检查并自动设置止损（需要public以便在OnTick中调用）
   
   // 价格选择功能的公共方法（NEW）
   void             SetStopLossPrice(double price);    // 设置止损价格
   void             SetTakeProfitPrice(double price);  // 设置止盈价格
   void             SetEntryPrice(double price);       // 设置挂单价格
   void             ResetSelectButton(int mode);       // 重置选择按钮颜色
   
   // 状态管理公共方法（需要从外部调用）
   void             SaveInputValues(void);            // 保存输入框值到成员变量
   void             RestoreInputValues(void);         // 从成员变量恢复输入框值
   void             ForceMaximize(void);              // 强制最大化面板
   
protected:
   bool             CreateControls(void);
   void             OnClickLotsDecrease(void);
   void             OnClickLotsIncrease(void);
   void             OnClickBuy(void);
   void             OnClickSell(void);
   void             OnClickSetSlPoints(void);
   void             OnClickSetSlPrice(void);
   void             OnClickSetTpPoints(void);
   void             OnClickSetTpPrice(void);
   void             OnClickClearSl(void);
   void             OnClickClearTp(void);
   void             CloseByPercent(double pct);
   void             OnClickClose50(void);
   void             OnClickClose80(void);
   void             OnClickClose100(void);
   void             OnClickCloseCustom(void);
   void             CloseLots(double lots);
   void             OnClickCloseLot1(void);
   void             OnClickCloseLot01(void);
   void             OnClickCloseLot001(void);
   void             OnClickCloseByLots(void);
   void             OnClickCloseSymbol(void);
   void             OnClickBreakEven(void);
   void             OnClickRecoveryExit(void);
   double           CalculateRecoveryExitPrice(int orderType, double openPrice, int points);
   void             OnClickResetInputs(void);         // 重置所有输入框
   void             OnClickViewOrders(void);
   void             OnClickToggleProfit(void);        // 切换盈亏容器显示
   void             OnClickTogglePositions(void);     // 切换持仓容器显示
   double           CalculateDailyProfit(void);       // 计算今日盈亏
   string           GetCurrentPositions(void);        // 获取当前持仓价格
   
   // 自动减仓相关方法（内部）
   int              GenerateUniqueMagic(void);        // 生成唯一MagicNumber
   void             OnClickToggleScaleOut(void);      // 切换自动减仓开关
   void             OnClickToggleMultiScale(void);    // 切换多次减仓开关（NEW）
   void             OnClickSmartCalc(void);           // 智能计算保本参数
   void             ExecuteScaleOut(int magic, int ticket, double pct, double lots); // 执行减仓
   bool             IsOrderScaled(int magic);         // 检查订单是否已减仓
   void             CleanupScaledOrders(void);        // 清理已关闭订单记录
   
   // 自动止损保护相关方法（内部）
   bool             SetAutoStopLoss(int magic, int ticket);  // 设置自动止损
   bool             UseATRBackup(int magic, int ticket);     // ATR备用方案
   bool             IsOrderProtected(int magic);             // 检查订单是否已设置止损保护
   void             MarkOrderProtected(int magic);           // 标记订单为已保护
   void             CleanupStopLossRecords(void);            // 清理已关闭订单的止损记录（独立于减仓系统）
   double           CalculateStopLoss(int points, int orderType, double openPrice); // 计算止损价格
   double           CalculateATRStopLoss(int orderType);     // 计算ATR动态止损
   
   // 价格选择功能方法（NEW）
   void             OnClickSelectSL(void);            // 点击选择止损按钮
   void             OnClickSelectTP(void);            // 点击选择止盈按钮
   
   // 挂单交易方法（NEW）
   void             OnClickSelectEntryPrice(void);    // 点击选择挂单价格按钮
   void             OnClickBuyLimit(void);            // Buy Limit挂单
   void             OnClickSellLimit(void);           // Sell Limit挂单
   void             OnClickBuyStop(void);             // Buy Stop挂单
   void             OnClickSellStop(void);            // Sell Stop挂单
   
   // 状态同步方法（内部）
   void             SyncUIWithState(void);            // 同步UI显示与内部状态
};

//+------------------------------------------------------------------+
//| 构造函数                                                          |
//+------------------------------------------------------------------+
CTradePanel::CTradePanel()
{
   // ========== 初始化自动减仓系统 ==========
   m_scaleOutEnabled = false;
   m_allowMultipleScaleOut = false;  // 默认：每笔订单只减仓一次
   m_scaleRecordCount = 0;           // 减仓记录计数器
   // 注：m_scaleRecords 结构体数组会自动零初始化，无需手动处理
   
   // ========== 初始化自动止损系统 ==========
   m_atrMultiplier = 1.5;            // 默认ATR倍数
   m_slRecordCount = 0;              // 止损记录计数器
   // 注：m_slRecords 结构体数组会自动零初始化，无需手动处理
   
   // === 初始化输入框默认值（12个）===
   m_lastLots = "0.01";
   m_lastStopLoss = "0.00000";
   m_lastTakeProfit = "0.00000";

   m_lastSlPoints = "500";
   m_lastSlPrice2 = "0.00000";
   m_lastTpPoints = "1000";
   m_lastTpPrice2 = "0.00000";

   m_lastClosePct = "30";
   m_lastCloseLots = "0.10";

   m_lastTriggerPts = "200";
   m_lastScalePct = "80";
   m_lastScaleLots = "0.04";
   
   m_lastEntryPrice = "0.00000";  // 挂单价格
}

//+------------------------------------------------------------------+
//| 析构函数                                                          |
//+------------------------------------------------------------------+
CTradePanel::~CTradePanel()
{
}

//+------------------------------------------------------------------+
//| 创建面板                                                          |
//+------------------------------------------------------------------+
bool CTradePanel::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2)
{
   if(!CAppDialog::Create(chart,name,subwin,x1,y1,x2,y2))
      return(false);
      
   // 设置面板标题
   Caption("K-Trade Magic");
      
   // 创建控件
   if(!CreateControls())
      return(false);
   
   // === 【重要】同步UI与内部状态（解决切换周期后状态不一致问题） ===
   SyncUIWithState();
      
   return(true);
}

//+------------------------------------------------------------------+
//| 重写ChartEvent - 拦截CHART_CHANGE事件防止自动最小化                  |
//+------------------------------------------------------------------+
void CTradePanel::ChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   // 拦截 CHARTEVENT_CHART_CHANGE 事件，防止自动最小化
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      LOG_DEBUG("[面板防护] 拦截CHART_CHANGE事件，防止自动最小化");
      return;  // 不调用父类，完全拦截
   }
   
   // 其他所有事件正常传递给父类处理
   CAppDialog::ChartEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| 创建所有控件                                                      |
//+------------------------------------------------------------------+
bool CTradePanel::CreateControls(void)
{
   int x = 8;
   int y = 10;
   int width = ClientAreaWidth() - 16;
   int btnHeight = 25;
   int inputHeight = 22;
   int spacing = 10;
   
   //=== 信息容器区域 ===
   int infoY = y;
   int btnW = 45;                          // 按钮宽度
   int gap = 5;                            // 间距
   int editW = width - btnW - gap;         // 容器宽度
   int containerH = 30;                    // 容器高度
   
   // --- 容器1: 今日盈亏 ---
   if(!m_edtDailyProfit.Create(m_chart_id, m_name+"DailyProfit", m_subwin,
                                x, infoY, x+editW, infoY+containerH))
      return(false);
   m_edtDailyProfit.Text("[ 已隐藏 ]");
   m_edtDailyProfit.ReadOnly(true);
   m_edtDailyProfit.ColorBackground(clrLightGray);
   m_edtDailyProfit.ColorBorder(clrGray);
   if(!Add(m_edtDailyProfit)) return(false);
   
   // 按钮1（右侧）
   if(!m_btnToggleProfit.Create(m_chart_id, m_name+"BtnToggleProfit", m_subwin,
                                 x+editW+gap, infoY, x+width, infoY+containerH))
      return(false);
   m_btnToggleProfit.Text("显示");
   m_btnToggleProfit.ColorBackground(clrLightGray);
   if(!Add(m_btnToggleProfit)) return(false);
   
   m_showProfit = false;  // 初始状态：隐藏
   
   // --- 容器2: 持仓价格 ---
   infoY += containerH + 5;  // 向下移动
   
   if(!m_edtPositions.Create(m_chart_id, m_name+"Positions", m_subwin,
                              x, infoY, x+editW, infoY+containerH))
      return(false);
   m_edtPositions.Text("持仓: 加载中...");
   m_edtPositions.ReadOnly(true);
   m_edtPositions.ColorBackground(clrAliceBlue);
   m_edtPositions.ColorBorder(clrDodgerBlue);
   if(!Add(m_edtPositions)) return(false);
   
   // 按钮2（右侧）
   if(!m_btnTogglePositions.Create(m_chart_id, m_name+"BtnTogglePos", m_subwin,
                                    x+editW+gap, infoY, x+width, infoY+containerH))
      return(false);
   m_btnTogglePositions.Text("隐藏");
   m_btnTogglePositions.ColorBackground(clrLightGray);
   if(!Add(m_btnTogglePositions)) return(false);
   
   m_showPositions = true;  // 初始状态：显示
   
   // === 模块1起始位置向下移动 ===
   y = infoY + containerH + 8;
   
   //--- 模块1: 开仓交易模块 (三列横排: 止损 | 手数 | 止盈) ---

   // 列布局: 紧凑优化
   int cGap    = 6;
   int col1W   = 100;                               // 止损列宽（固定）
   int col2W   = 154;                               // 手数列宽（固定）
   int col3W   = 100;                               // 止盈列宽（固定）
   int col1X   = x;
   int col2X   = col1X + col1W + cGap;
   int col3X   = col2X + col2W + cGap;
   int lblRowH = 16;  // 标签行高
   int edtRowH = 22;  // 输入行高
   int lotsBW  = 25;  // +/- 按钮宽度

   // 第一行: 三列标签
   if(!m_lblStopLoss.Create(m_chart_id,m_name+"LblSL",m_subwin,col1X,y,col1X+col1W,y+lblRowH))
      return(false);
   if(!m_lblStopLoss.Text("止  损:")) return(false);
   m_lblStopLoss.FontSize(8);  // 缩小字体
   if(!Add(m_lblStopLoss)) return(false);

   if(!m_lblLots.Create(m_chart_id,m_name+"LblLots",m_subwin,col2X,y,col2X+col2W,y+lblRowH))
      return(false);
   if(!m_lblLots.Text("手    数:")) return(false);
   m_lblLots.FontSize(8);  // 缩小字体
   if(!Add(m_lblLots)) return(false);

   if(!m_lblTakeProfit.Create(m_chart_id,m_name+"LblTP",m_subwin,col3X,y,col3X+col3W,y+lblRowH))
      return(false);
   if(!m_lblTakeProfit.Text("止  盈:")) return(false);
   m_lblTakeProfit.FontSize(8);  // 缩小字体
   if(!Add(m_lblTakeProfit)) return(false);

   // 第二行: 三列输入框 (手数列含 [-][输入][+])
   int rowY    = y + lblRowH + 3;
   int lotsEdtX = col2X + lotsBW + 5;
   int lotsEdtW = col2W - lotsBW * 2 - 10;

   // 止损: [输入框] [📍按钮]
   int selectBtnW = 30;  // 选择按钮宽度
   int slEditW = col1W - selectBtnW - 3;  // 止损输入框宽度
   
   if(!m_edtStopLoss.Create(m_chart_id,m_name+"EdtSL",m_subwin,col1X,rowY,col1X+slEditW,rowY+edtRowH))
      return(false);
   m_edtStopLoss.Text("0.00000");
   m_edtStopLoss.ReadOnly(false);
   if(!Add(m_edtStopLoss)) return(false);
   
   // 选择止损按钮
   if(!m_btnSelectSL.Create(m_chart_id,m_name+"BtnSelectSL",m_subwin,
                             col1X+slEditW+3,rowY,col1X+col1W,rowY+edtRowH))
      return(false);
   m_btnSelectSL.Text(">");
   m_btnSelectSL.ColorBackground(clrLightGray);
   if(!Add(m_btnSelectSL)) return(false);

   // 手数: [-] [输入框] [+]
   if(!m_btnLotsDecrease.Create(m_chart_id,m_name+"BtnLotsDecrease",m_subwin,
                                 col2X,rowY,col2X+lotsBW,rowY+edtRowH))
      return(false);
   if(!m_btnLotsDecrease.Text("-")) return(false);
   m_btnLotsDecrease.ColorBackground(clrLightBlue);
   if(!Add(m_btnLotsDecrease)) return(false);

   if(!m_edtLots.Create(m_chart_id,m_name+"EdtLots",m_subwin,lotsEdtX,rowY,lotsEdtX+lotsEdtW,rowY+edtRowH))
      return(false);
   m_edtLots.Text("0.01");
   m_edtLots.ReadOnly(false);
   if(!Add(m_edtLots)) return(false);

   if(!m_btnLotsIncrease.Create(m_chart_id,m_name+"BtnLotsIncrease",m_subwin,
                                 col2X+col2W-lotsBW,rowY,col2X+col2W,rowY+edtRowH))
      return(false);
   if(!m_btnLotsIncrease.Text("+")) return(false);
   m_btnLotsIncrease.ColorBackground(clrLightGreen);
   if(!Add(m_btnLotsIncrease)) return(false);

   // 止盈: [输入框] [📍按钮]
   int tpEditW = col3W - selectBtnW - 3;  // 止盈输入框宽度
   
   if(!m_edtTakeProfit.Create(m_chart_id,m_name+"EdtTP",m_subwin,col3X,rowY,col3X+tpEditW,rowY+edtRowH))
      return(false);
   m_edtTakeProfit.Text("0.00000");
   m_edtTakeProfit.ReadOnly(false);
   if(!Add(m_edtTakeProfit)) return(false);
   
   // 选择止盈按钮
   if(!m_btnSelectTP.Create(m_chart_id,m_name+"BtnSelectTP",m_subwin,
                             col3X+tpEditW+3,rowY,col3X+col3W,rowY+edtRowH))
      return(false);
   m_btnSelectTP.Text(">");
   m_btnSelectTP.ColorBackground(clrLightGray);
   if(!Add(m_btnSelectTP)) return(false);

   // y 推进到买卖按钮行
   y = rowY + edtRowH + 8;

   // 买入卖出按钮 (占满整行)
   int halfWidth = (width - 5) / 2;

   // 现价买入按钮
   if(!m_btnBuy.Create(m_chart_id,m_name+"BtnBuy",m_subwin,x,y,x+halfWidth,y+30))
      return(false);
   if(!m_btnBuy.Text("买  入"))
      return(false);
   m_btnBuy.ColorBackground(clrLimeGreen);
   m_btnBuy.ColorBorder(clrGreen);
   if(!Add(m_btnBuy))
      return(false);

   // 现价卖出按钮
   int sellX = x + halfWidth + 5;
   if(!m_btnSell.Create(m_chart_id,m_name+"BtnSell",m_subwin,sellX,y,sellX+halfWidth,y+30))
      return(false);
   if(!m_btnSell.Text("卖  出"))
      return(false);
   m_btnSell.ColorBackground(clrTomato);
   m_btnSell.ColorBorder(clrRed);
   if(!Add(m_btnSell))
      return(false);
   
   //=== 模块1B: 挂单交易 ===
   y += 30 + 10;  // 买卖按钮高度 + 间距
   
   // 模块标题
   if(!m_lblPendingOrder.Create(m_chart_id,m_name+"LblPendingOrder",m_subwin,x,y,x+width,y+20))
      return(false);
   m_lblPendingOrder.Text("-- Pending Orders --");
   m_lblPendingOrder.FontSize(9);
   if(!Add(m_lblPendingOrder)) return(false);
   y += 20;
   
   // 挂单价格输入行
   int entryPriceW = width - 35;
   int entrySelectBtnW = 30;
   
   if(!m_edtEntryPrice.Create(m_chart_id,m_name+"EdtEntryPrice",m_subwin,
                               x,y,x+entryPriceW,y+22))
      return(false);
   m_edtEntryPrice.Text("0.00000");
   m_edtEntryPrice.ReadOnly(false);
   if(!Add(m_edtEntryPrice)) return(false);
   
   // 选择挂单价格按钮
   if(!m_btnSelectEntry.Create(m_chart_id,m_name+"BtnSelectEntry",m_subwin,
                                x+entryPriceW+3,y,x+width,y+22))
      return(false);
   m_btnSelectEntry.Text(">");
   m_btnSelectEntry.ColorBackground(clrLightGray);
   if(!Add(m_btnSelectEntry)) return(false);
   y += 22 + 5;
   
   // 2×2按钮网格
   int pendingBtnW = (width - 5) / 2;
   int pendingBtnH = 25;
   
   // 第一行: [Buy Limit] [Sell Limit]
   if(!m_btnBuyLimit.Create(m_chart_id,m_name+"BtnBuyLimit",m_subwin,
                            x,y,x+pendingBtnW,y+pendingBtnH))
      return(false);
   m_btnBuyLimit.Text("Buy Limit");
   m_btnBuyLimit.ColorBackground(clrMediumSeaGreen);
   m_btnBuyLimit.ColorBorder(clrSeaGreen);
   if(!Add(m_btnBuyLimit)) return(false);
   
   if(!m_btnSellLimit.Create(m_chart_id,m_name+"BtnSellLimit",m_subwin,
                             x+pendingBtnW+5,y,x+width,y+pendingBtnH))
      return(false);
   m_btnSellLimit.Text("Sell Limit");
   m_btnSellLimit.ColorBackground(clrOrangeRed);
   m_btnSellLimit.ColorBorder(clrDarkOrange);
   if(!Add(m_btnSellLimit)) return(false);
   y += pendingBtnH + 3;
   
   // 第二行: [Buy Stop] [Sell Stop]
   if(!m_btnBuyStop.Create(m_chart_id,m_name+"BtnBuyStop",m_subwin,
                           x,y,x+pendingBtnW,y+pendingBtnH))
      return(false);
   m_btnBuyStop.Text("Buy Stop");
   m_btnBuyStop.ColorBackground(clrForestGreen);
   m_btnBuyStop.ColorBorder(clrDarkGreen);
   if(!Add(m_btnBuyStop)) return(false);
   
   if(!m_btnSellStop.Create(m_chart_id,m_name+"BtnSellStop",m_subwin,
                            x+pendingBtnW+5,y,x+width,y+pendingBtnH))
      return(false);
   m_btnSellStop.Text("Sell Stop");
   m_btnSellStop.ColorBackground(clrFireBrick);
   m_btnSellStop.ColorBorder(clrDarkRed);
   if(!Add(m_btnSellStop)) return(false);
   
   //=== 模块2: 止盈止损管理 (2列×2行, 标签内联) ===
   y += pendingBtnH + 5;  // 向下移动到模块2

   int rowH2   = 25;                              // 输入行高（模块3也使用此变量）
   int m2Gap   = 6;                               // 两列间距
   int m2ColW  = (width - m2Gap) / 2;             // 每列宽度
   int m2C1X   = x;                               // 左列起点X
   int m2C2X   = x + m2ColW + m2Gap;              // 右列起点X
   int m2LblW  = 40;                              // 内联标签宽度
   int m2BtnW  = 35;                              // Set按钮宽度
   int m2EdtW  = m2ColW - m2LblW - m2BtnW - 6;   // 输入框宽度（两侧各3px间距）
   int m2Edt1X = m2C1X + m2LblW + 3;             // 左列输入框X
   int m2Edt2X = m2C2X + m2LblW + 3;             // 右列输入框X
   int m2Btn1X = m2Edt1X + m2EdtW + 3;           // 左列Set按钮X
   int m2Btn2X = m2Edt2X + m2EdtW + 3;           // 右列Set按钮X

   // 模块2标题
   y += 10;
   if(!m_lblMod2.Create(m_chart_id,m_name+"LblMod2",m_subwin,x,y,x+width,y+20))
      return(false);
   if(!m_lblMod2.Text("-- SL/TP Mgmt --"))
      return(false);
   if(!Add(m_lblMod2))
      return(false);
   y += 20;

   //--- 第一行: [SL pts:][input][Set] | [TP pts:][input][Set] ---
   if(!m_lblSlPoints.Create(m_chart_id,m_name+"LblSlPts",m_subwin,m2C1X,y,m2C1X+m2LblW,y+rowH2))
      return(false);
   if(!m_lblSlPoints.Text("SL pts:")) return(false);
   if(!Add(m_lblSlPoints)) return(false);
   if(!m_edtSlPoints.Create(m_chart_id,m_name+"EdtSlPts",m_subwin,m2Edt1X,y,m2Edt1X+m2EdtW,y+rowH2))
      return(false);
   m_edtSlPoints.Text("500");
   m_edtSlPoints.ReadOnly(false);
   if(!Add(m_edtSlPoints)) return(false);
   if(!m_btnSetSlPoints.Create(m_chart_id,m_name+"BtnSetSlPts",m_subwin,m2Btn1X,y,m2Btn1X+m2BtnW,y+rowH2))
      return(false);
   if(!m_btnSetSlPoints.Text("Set")) return(false);
   m_btnSetSlPoints.ColorBackground(clrSteelBlue);
   if(!Add(m_btnSetSlPoints)) return(false);

   if(!m_lblTpPoints.Create(m_chart_id,m_name+"LblTpPts",m_subwin,m2C2X,y,m2C2X+m2LblW,y+rowH2))
      return(false);
   if(!m_lblTpPoints.Text("TP pts:")) return(false);
   if(!Add(m_lblTpPoints)) return(false);
   if(!m_edtTpPoints.Create(m_chart_id,m_name+"EdtTpPts",m_subwin,m2Edt2X,y,m2Edt2X+m2EdtW,y+rowH2))
      return(false);
   m_edtTpPoints.Text("1000");
   m_edtTpPoints.ReadOnly(false);
   if(!Add(m_edtTpPoints)) return(false);
   if(!m_btnSetTpPoints.Create(m_chart_id,m_name+"BtnSetTpPts",m_subwin,m2Btn2X,y,m2Btn2X+m2BtnW,y+rowH2))
      return(false);
   if(!m_btnSetTpPoints.Text("Set")) return(false);
   m_btnSetTpPoints.ColorBackground(clrDarkOrange);
   if(!Add(m_btnSetTpPoints)) return(false);
   y += rowH2 + 8;

   //--- 第二行: [SL $:][input][Set] | [TP $:][input][Set] ---
   if(!m_lblSlPrice2.Create(m_chart_id,m_name+"LblSlPrc2",m_subwin,m2C1X,y,m2C1X+m2LblW,y+rowH2))
      return(false);
   if(!m_lblSlPrice2.Text("SL $:")) return(false);
   if(!Add(m_lblSlPrice2)) return(false);
   if(!m_edtSlPrice2.Create(m_chart_id,m_name+"EdtSlPrc2",m_subwin,m2Edt1X,y,m2Edt1X+m2EdtW,y+rowH2))
      return(false);
   m_edtSlPrice2.Text("0.00000");
   m_edtSlPrice2.ReadOnly(false);
   if(!Add(m_edtSlPrice2)) return(false);
   if(!m_btnSetSlPrice.Create(m_chart_id,m_name+"BtnSetSlPrc",m_subwin,m2Btn1X,y,m2Btn1X+m2BtnW,y+rowH2))
      return(false);
   if(!m_btnSetSlPrice.Text("Set")) return(false);
   m_btnSetSlPrice.ColorBackground(clrSteelBlue);
   if(!Add(m_btnSetSlPrice)) return(false);

   if(!m_lblTpPrice2.Create(m_chart_id,m_name+"LblTpPrc2",m_subwin,m2C2X,y,m2C2X+m2LblW,y+rowH2))
      return(false);
   if(!m_lblTpPrice2.Text("TP $:")) return(false);
   if(!Add(m_lblTpPrice2)) return(false);
   if(!m_edtTpPrice2.Create(m_chart_id,m_name+"EdtTpPrc2",m_subwin,m2Edt2X,y,m2Edt2X+m2EdtW,y+rowH2))
      return(false);
   m_edtTpPrice2.Text("0.00000");
   m_edtTpPrice2.ReadOnly(false);
   if(!Add(m_edtTpPrice2)) return(false);
   if(!m_btnSetTpPrice.Create(m_chart_id,m_name+"BtnSetTpPrc",m_subwin,m2Btn2X,y,m2Btn2X+m2BtnW,y+rowH2))
      return(false);
   if(!m_btnSetTpPrice.Text("Set")) return(false);
   m_btnSetTpPrice.ColorBackground(clrDarkOrange);
   if(!Add(m_btnSetTpPrice)) return(false);

   //--- 第三行: [强制清除SL] | [强制清除TP] ---
   y += rowH2 + 6;
   if(!m_btnClearSl.Create(m_chart_id,m_name+"BtnClearSL",m_subwin,m2C1X,y,m2C1X+m2ColW,y+rowH2))
      return(false);
   if(!m_btnClearSl.Text("清SL")) return(false);
   m_btnClearSl.ColorBackground(clrDarkSalmon);
   if(!Add(m_btnClearSl)) return(false);

   if(!m_btnClearTp.Create(m_chart_id,m_name+"BtnClearTP",m_subwin,m2C2X,y,m2C2X+m2ColW,y+rowH2))
      return(false);
   if(!m_btnClearTp.Text("清TP")) return(false);
   m_btnClearTp.ColorBackground(clrSandyBrown);
   if(!Add(m_btnClearTp)) return(false);

   //=== 模块3: 比例平仓 (2行紧凑布局) ===
   y += rowH2 + 5;

   // 模块3标题
   if(!m_lblMod3.Create(m_chart_id,m_name+"LblMod3",m_subwin,x,y,x+width,y+20))
      return(false);
   if(!m_lblMod3.Text("-- Close Position --"))
      return(false);
   if(!Add(m_lblMod3))
      return(false);
   y += 20;

   int m3BtnH = 25;                        // 行高
   int m3LW   = (width - 8) / 2;           // 左侧快捷按钮区宽
   int m3RX   = x + m3LW + 8;              // 右侧起点X
   int m3RW   = width - m3LW - 8;          // 右侧宽度
   int m3QB   = (m3LW - 10) / 3;           // 快捷按钮宽（内含5px间距）
   int m3LblW = 28;                        // 右侧标签宽
   int m3GoW  = 35;                        // Go按钮宽
   int m3EdtW = m3RW - m3LblW - m3GoW - 6; // 右侧输入框宽
   int m3EdtX = m3RX + m3LblW + 3;         // 右侧输入框X
   int m3GoX  = m3EdtX + m3EdtW + 3;       // 右侧Go按钮X

   //--- Row1: [50%][80%][100%] | [Pct:][input][Go] ---
   if(!m_btnClose50.Create(m_chart_id,m_name+"BtnClose50",m_subwin,
                            x, y, x+m3QB, y+m3BtnH))
      return(false);
   if(!m_btnClose50.Text("50%")) return(false);
   m_btnClose50.ColorBackground(clrGold);
   if(!Add(m_btnClose50)) return(false);

   if(!m_btnClose80.Create(m_chart_id,m_name+"BtnClose80",m_subwin,
                            x+m3QB+5, y, x+m3QB*2+5, y+m3BtnH))
      return(false);
   if(!m_btnClose80.Text("80%")) return(false);
   m_btnClose80.ColorBackground(clrGold);
   if(!Add(m_btnClose80)) return(false);

   if(!m_btnClose100.Create(m_chart_id,m_name+"BtnClose100",m_subwin,
                             x+m3QB*2+10, y, x+m3LW, y+m3BtnH))
      return(false);
   if(!m_btnClose100.Text("100%")) return(false);
   m_btnClose100.ColorBackground(clrOrangeRed);
   if(!Add(m_btnClose100)) return(false);

   if(!m_lblClosePct.Create(m_chart_id,m_name+"LblClosePct",m_subwin,
                             m3RX, y, m3RX+m3LblW, y+m3BtnH))
      return(false);
   if(!m_lblClosePct.Text("Pct:")) return(false);
   if(!Add(m_lblClosePct)) return(false);

   if(!m_edtClosePct.Create(m_chart_id,m_name+"EdtClosePct",m_subwin,
                             m3EdtX, y, m3EdtX+m3EdtW, y+m3BtnH))
      return(false);
   m_edtClosePct.Text("30");
   m_edtClosePct.ReadOnly(false);
   if(!Add(m_edtClosePct)) return(false);

   if(!m_btnCloseCustom.Create(m_chart_id,m_name+"BtnCloseCustom",m_subwin,
                                m3GoX, y, m3GoX+m3GoW, y+m3BtnH))
      return(false);
   if(!m_btnCloseCustom.Text("Go")) return(false);
   m_btnCloseCustom.ColorBackground(clrOrangeRed);
   if(!Add(m_btnCloseCustom)) return(false);
   y += m3BtnH + 8;

   //--- Row2: [-1][-0.1][-0.01] | [Lot:][input][Go] ---
   if(!m_btnCloseLot1.Create(m_chart_id,m_name+"BtnCloseLot1",m_subwin,
                              x, y, x+m3QB, y+m3BtnH))
      return(false);
   if(!m_btnCloseLot1.Text("-1")) return(false);
   m_btnCloseLot1.ColorBackground(clrMediumPurple);
   if(!Add(m_btnCloseLot1)) return(false);

   if(!m_btnCloseLot01.Create(m_chart_id,m_name+"BtnCloseLot01",m_subwin,
                               x+m3QB+5, y, x+m3QB*2+5, y+m3BtnH))
      return(false);
   if(!m_btnCloseLot01.Text("-0.1")) return(false);
   m_btnCloseLot01.ColorBackground(clrMediumPurple);
   if(!Add(m_btnCloseLot01)) return(false);

   if(!m_btnCloseLot001.Create(m_chart_id,m_name+"BtnCloseLot001",m_subwin,
                                x+m3QB*2+10, y, x+m3LW, y+m3BtnH))
      return(false);
   if(!m_btnCloseLot001.Text("-0.01")) return(false);
   m_btnCloseLot001.ColorBackground(clrMediumPurple);
   if(!Add(m_btnCloseLot001)) return(false);

   if(!m_lblCloseLots.Create(m_chart_id,m_name+"LblCloseLots",m_subwin,
                              m3RX, y, m3RX+m3LblW, y+m3BtnH))
      return(false);
   if(!m_lblCloseLots.Text("Lot:")) return(false);
   if(!Add(m_lblCloseLots)) return(false);

   if(!m_edtCloseLots.Create(m_chart_id,m_name+"EdtCloseLots",m_subwin,
                              m3EdtX, y, m3EdtX+m3EdtW, y+m3BtnH))
      return(false);
   m_edtCloseLots.Text("0.10");
   m_edtCloseLots.ReadOnly(false);
   if(!Add(m_edtCloseLots)) return(false);

   if(!m_btnCloseByLots.Create(m_chart_id,m_name+"BtnCloseByLots",m_subwin,
                                m3GoX, y, m3GoX+m3GoW, y+m3BtnH))
      return(false);
   if(!m_btnCloseByLots.Text("Go")) return(false);
   m_btnCloseByLots.ColorBackground(clrMediumPurple);
   if(!Add(m_btnCloseByLots)) return(false);
   y += m3BtnH + 8;

   //--- Row3: [平当前品种] [一键保本] [回本退出] ---
   int r3Gap = 5;
   int r3BtnW = (width - r3Gap * 2) / 3;
   if(!m_btnCloseSymbol.Create(m_chart_id,m_name+"BtnCloseSymbol",m_subwin,
                               x, y, x+r3BtnW, y+m3BtnH))
      return(false);
   if(!m_btnCloseSymbol.Text("平当前品种")) return(false);
   m_btnCloseSymbol.ColorBackground(clrCrimson);
   if(!Add(m_btnCloseSymbol)) return(false);

   if(!m_btnBreakEven.Create(m_chart_id,m_name+"BtnBreakEven",m_subwin,
                              x+r3BtnW+r3Gap, y, x+r3BtnW*2+r3Gap, y+m3BtnH))
      return(false);
   if(!m_btnBreakEven.Text("一键保本")) return(false);
   m_btnBreakEven.ColorBackground(clrDarkCyan);
   if(!Add(m_btnBreakEven)) return(false);

   if(!m_btnRecoveryExit.Create(m_chart_id,m_name+"BtnRecoveryExit",m_subwin,
                                 x+r3BtnW*2+r3Gap*2, y, x+width, y+m3BtnH))
      return(false);
   if(!m_btnRecoveryExit.Text("回本退出")) return(false);
   m_btnRecoveryExit.ColorBackground(clrTeal);
   if(!Add(m_btnRecoveryExit)) return(false);

   //=== 模块5: 自动减仓 ===
   y += m3BtnH + 5;
   
   // 模块标题
   if(!m_lblScaleOut.Create(m_chart_id,m_name+"LblScaleOut",m_subwin,x,y,x+width,y+20))
      return(false);
   if(!m_lblScaleOut.Text("-- Auto Scale-Out --"))
      return(false);
   if(!Add(m_lblScaleOut))
      return(false);
   y += 20;
   
   // 布局参数
   int m5BtnH = 22;                           // 控件高度
   int m5LblW = 40;                           // 标签宽度（加宽防止遮挡）
   int m5Gap = 4;                             // 间距
   int m5Col1W = (width - m5Gap*2) / 3;      // 第一列宽度（触发点数）
   int m5Col2W = m5Col1W;                     // 第二列宽度（减仓比例）
   int m5Col3W = width - m5Col1W - m5Col2W - m5Gap*2; // 第三列宽度（减仓手数）
   int m5Col1X = x;
   int m5Col2X = m5Col1X + m5Col1W + m5Gap;
   int m5Col3X = m5Col2X + m5Col2W + m5Gap;
   int m5EdtW1 = m5Col1W - m5LblW - 3;
   int m5EdtW2 = m5Col2W - m5LblW - 3;
   int m5EdtW3 = m5Col3W - m5LblW - 3;
   
   // 第一行：[触发:][200]pts | [减仓:][80]% | [或][0.04]lots
   if(!m_lblTriggerPts.Create(m_chart_id,m_name+"LblTrigPts",m_subwin,
                               m5Col1X,y,m5Col1X+m5LblW,y+m5BtnH))
      return(false);
   if(!m_lblTriggerPts.Text("触发:")) return(false);
   m_lblTriggerPts.FontSize(8);  // 缩小字体
   if(!Add(m_lblTriggerPts)) return(false);
   
   if(!m_edtTriggerPts.Create(m_chart_id,m_name+"EdtTrigPts",m_subwin,
                              m5Col1X+m5LblW+3,y,m5Col1X+m5Col1W,y+m5BtnH))
      return(false);
   m_edtTriggerPts.Text("200");
   m_edtTriggerPts.ReadOnly(false);
   if(!Add(m_edtTriggerPts)) return(false);
   
   if(!m_lblScalePct.Create(m_chart_id,m_name+"LblScalePct",m_subwin,
                            m5Col2X,y,m5Col2X+m5LblW,y+m5BtnH))
      return(false);
   if(!m_lblScalePct.Text("减仓:")) return(false);
   m_lblScalePct.FontSize(8);  // 缩小字体
   if(!Add(m_lblScalePct)) return(false);
   
   if(!m_edtScalePct.Create(m_chart_id,m_name+"EdtScalePct",m_subwin,
                            m5Col2X+m5LblW+3,y,m5Col2X+m5Col2W,y+m5BtnH))
      return(false);
   m_edtScalePct.Text("80");
   m_edtScalePct.ReadOnly(false);
   if(!Add(m_edtScalePct)) return(false);
   
   if(!m_lblScaleLots.Create(m_chart_id,m_name+"LblScaleLots",m_subwin,
                             m5Col3X,y,m5Col3X+m5LblW,y+m5BtnH))
      return(false);
   if(!m_lblScaleLots.Text("或:")) return(false);
   m_lblScaleLots.FontSize(8);  // 缩小字体
   if(!Add(m_lblScaleLots)) return(false);
   
   if(!m_edtScaleLots.Create(m_chart_id,m_name+"EdtScaleLots",m_subwin,
                             m5Col3X+m5LblW+3,y,m5Col3X+m5Col3W,y+m5BtnH))
      return(false);
   m_edtScaleLots.Text("0.04");
   m_edtScaleLots.ReadOnly(false);
   if(!Add(m_edtScaleLots)) return(false);
   
   y += m5BtnH + 8;
   
   // 第二行：[开启自动减仓] [智能计算保本] [允许多次减仓] 三个按钮一行
   int m5Btn1W = (width - 2*m5Gap) / 3;      // 第1个按钮宽度
   int m5Btn2W = (width - 2*m5Gap) / 3;      // 第2个按钮宽度
   int m5Btn3W = width - m5Btn1W - m5Btn2W - 2*m5Gap;  // 第3个按钮宽度（自适应剩余）
   
   if(!m_btnToggleScaleOut.Create(m_chart_id,m_name+"BtnToggleScaleOut",m_subwin,
                                   x,y,x+m5Btn1W,y+m5BtnH))
      return(false);
   if(!m_btnToggleScaleOut.Text("自动减仓(关)")) return(false);
   m_btnToggleScaleOut.FontSize(8);  // 缩小字体
   m_btnToggleScaleOut.ColorBackground(clrLightGray);
   if(!Add(m_btnToggleScaleOut)) return(false);
   
   if(!m_btnSmartCalc.Create(m_chart_id,m_name+"BtnSmartCalc",m_subwin,
                             x+m5Btn1W+m5Gap,y,x+m5Btn1W+m5Gap+m5Btn2W,y+m5BtnH))
      return(false);
   if(!m_btnSmartCalc.Text("智能计算保本")) return(false);
   m_btnSmartCalc.FontSize(8);  // 缩小字体
   m_btnSmartCalc.ColorBackground(clrMediumSeaGreen);
   if(!Add(m_btnSmartCalc)) return(false);
   
   if(!m_btnToggleMultiScale.Create(m_chart_id,m_name+"BtnToggleMultiScale",m_subwin,
                                     x+m5Btn1W+m5Gap+m5Btn2W+m5Gap,y,x+width,y+m5BtnH))
      return(false);
   if(!m_btnToggleMultiScale.Text("多次减仓(关)")) return(false);
   m_btnToggleMultiScale.FontSize(8);  // 缩小字体
   m_btnToggleMultiScale.ColorBackground(clrLightGray);
   if(!Add(m_btnToggleMultiScale)) return(false);

   //=== 模块4: 订单记录模块 ===
   y += m3BtnH + 10;
   
   // 重置输入框按钮
   if(!m_btnResetInputs.Create(m_chart_id,m_name+"BtnResetInputs",m_subwin,x,y,x+width,y+28))
      return(false);
   if(!m_btnResetInputs.Text("重置所有输入框"))
      return(false);
   m_btnResetInputs.ColorBackground(clrGold);
   m_btnResetInputs.ColorBorder(clrOrange);
   if(!Add(m_btnResetInputs))
      return(false);
   y += 28 + 5;

   if(!m_lblMod4.Create(m_chart_id,m_name+"LblMod4",m_subwin,x,y,x+width,y+20))
      return(false);
   if(!m_lblMod4.Text("-- Order Log --"))
      return(false);
   if(!Add(m_lblMod4))
      return(false);
   y += 20;

   if(!m_btnViewOrders.Create(m_chart_id,m_name+"BtnViewOrders",m_subwin,x,y,x+width,y+28))
      return(false);
   if(!m_btnViewOrders.Text("查看今日订单记录"))
      return(false);
   m_btnViewOrders.ColorBackground(clrSlateGray);
   if(!Add(m_btnViewOrders))
      return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| 同步UI显示与内部状态（解决切换周期后按钮文字错误问题）            |
//+------------------------------------------------------------------+
void CTradePanel::SyncUIWithState(void)
{
   // === 1. 同步自动减仓按钮状态 ===
   if(m_scaleOutEnabled)
   {
      m_btnToggleScaleOut.Text("自动减仓(开)");
      m_btnToggleScaleOut.ColorBackground(clrOrangeRed);
   }
   else
   {
      m_btnToggleScaleOut.Text("自动减仓(关)");
      m_btnToggleScaleOut.ColorBackground(clrLightGray);
   }
   
   // === 1.1 同步多次减仓按钮状态（NEW）===
   if(m_allowMultipleScaleOut)
   {
      m_btnToggleMultiScale.Text("多次减仓(开)");
      m_btnToggleMultiScale.ColorBackground(clrMediumSeaGreen);
   }
   else
   {
      m_btnToggleMultiScale.Text("多次减仓(关)");
      m_btnToggleMultiScale.ColorBackground(clrLightGray);
   }
   
   // === 2. 同步今日盈亏容器显示状态 ===
   if(m_showProfit)
   {
      m_btnToggleProfit.Text("隐藏");
      // 触发一次更新以显示数据
      UpdateInfoContainers();
   }
   else
   {
      m_btnToggleProfit.Text("显示");
      m_edtDailyProfit.Text("[ 已隐藏 ]");
   }
   
   // === 3. 同步持仓信息容器显示状态 ===
   if(m_showPositions)
   {
      m_btnTogglePositions.Text("隐藏");
      // 触发一次更新以显示数据
      UpdateInfoContainers();
   }
   else
   {
      m_btnTogglePositions.Text("显示");
      m_edtPositions.Text("[ 已隐藏 ]");
   }
   
   // === 4. 恢复输入框值 ===
   RestoreInputValues();
   
   LOG_DEBUG("[状态同步] UI已同步到内部状态：自动减仓=" + IntegerToString(m_scaleOutEnabled) + 
         ", 多次减仓=" + IntegerToString(m_allowMultipleScaleOut) + ", 显示盈亏=" + IntegerToString(m_showProfit) + ", 显示持仓=" + IntegerToString(m_showPositions));
}

//+------------------------------------------------------------------+
//| 强制最大化面板（切换周期时调用）                               |
//+------------------------------------------------------------------+
void CTradePanel::ForceMaximize(void)
{
   Maximize();
}

//+------------------------------------------------------------------+
//| 保存输入框值到成员变量（在OnDeinit中调用）                  |
//+------------------------------------------------------------------+
void CTradePanel::SaveInputValues(void)
{
   // 模块1: 开仓模块
   m_lastLots = m_edtLots.Text();
   m_lastStopLoss = m_edtStopLoss.Text();
   m_lastTakeProfit = m_edtTakeProfit.Text();
   
   // 模块2: SL/TP管理模块
   m_lastSlPoints = m_edtSlPoints.Text();
   m_lastSlPrice2 = m_edtSlPrice2.Text();
   m_lastTpPoints = m_edtTpPoints.Text();
   m_lastTpPrice2 = m_edtTpPrice2.Text();
   
   // 模块3: 平仓模块
   m_lastClosePct = m_edtClosePct.Text();
   m_lastCloseLots = m_edtCloseLots.Text();
   
   // 模块5: 自动减仓模块
   m_lastTriggerPts = m_edtTriggerPts.Text();
   m_lastScalePct = m_edtScalePct.Text();
   m_lastScaleLots = m_edtScaleLots.Text();
   
   // 模块1B: 挂单模块
   m_lastEntryPrice = m_edtEntryPrice.Text();
   
   LOG_DEBUG("[状态保存] 已保存13个输入框的值：手数=" + m_lastLots + ", 止损=" + m_lastStopLoss + ", 挂单价=" + m_lastEntryPrice);
}

//+------------------------------------------------------------------+
//| 从成员变量恢复输入框值（在SyncUIWithState中调用）         |
//+------------------------------------------------------------------+
void CTradePanel::RestoreInputValues(void)
{
   // 模块1: 开仓模块
   m_edtLots.Text(m_lastLots);
   m_edtStopLoss.Text(m_lastStopLoss);
   m_edtTakeProfit.Text(m_lastTakeProfit);
   
   // 模块2: SL/TP管理模块
   m_edtSlPoints.Text(m_lastSlPoints);
   m_edtSlPrice2.Text(m_lastSlPrice2);
   m_edtTpPoints.Text(m_lastTpPoints);
   m_edtTpPrice2.Text(m_lastTpPrice2);
   
   // 模块3: 平仓模块
   m_edtClosePct.Text(m_lastClosePct);
   m_edtCloseLots.Text(m_lastCloseLots);
   
   // 模块5: 自动减仓模块
   m_edtTriggerPts.Text(m_lastTriggerPts);
   m_edtScalePct.Text(m_lastScalePct);
   m_edtScaleLots.Text(m_lastScaleLots);
   
   // 模块1B: 挂单模块
   m_edtEntryPrice.Text(m_lastEntryPrice);
   
   LOG_DEBUG("[状态恢复] 已恢复13个输入框的值：手数=" + m_lastLots + ", 止损=" + m_lastStopLoss + ", 挂单价=" + m_lastEntryPrice);
}
//#endregion

//#region MARK: 模块--事件处理
//+------------------------------------------------------------------+
//| 事件处理                                                          |
//+------------------------------------------------------------------+
bool CTradePanel::OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   // 控件点击事件 id=1000
   if(id == 1000)
   {
      // 手数减少按钮
      if(sparam == m_name+"BtnLotsDecrease")
      {
         OnClickLotsDecrease();
         return(true);
      }
      // 手数增加按钮
      if(sparam == m_name+"BtnLotsIncrease")
      {
         OnClickLotsIncrease();
         return(true);
      }
      // 现价买入按钮
      if(sparam == m_name+"BtnBuy")
      {
         OnClickBuy();
         return(true);
      }
      // 现价卖出按钮
      if(sparam == m_name+"BtnSell")
      {
         OnClickSell();
         return(true);
      }
      // 按点数设置止损
      if(sparam == m_name+"BtnSetSlPts") { OnClickSetSlPoints(); return(true); }
      // 按价格设置止损
      if(sparam == m_name+"BtnSetSlPrc") { OnClickSetSlPrice();  return(true); }
      // 按点数设置止盈
      if(sparam == m_name+"BtnSetTpPts") { OnClickSetTpPoints(); return(true); }
      // 按价格设置止盈
      if(sparam == m_name+"BtnSetTpPrc")     { OnClickSetTpPrice();    return(true); }
      // 强制清除止损/止盈
      if(sparam == m_name+"BtnClearSL")      { OnClickClearSl();       return(true); }
      if(sparam == m_name+"BtnClearTP")      { OnClickClearTp();       return(true); }
      // 50%平仓
      if(sparam == m_name+"BtnClose50")      { OnClickClose50();       return(true); }
      // 80%平仓
      if(sparam == m_name+"BtnClose80")      { OnClickClose80();       return(true); }
      // 100%平仓
      if(sparam == m_name+"BtnClose100")     { OnClickClose100();      return(true); }
      // 自定义比例平仓
      if(sparam == m_name+"BtnCloseCustom")   { OnClickCloseCustom();   return(true); }
      // 按手数平仓 快捷按钮
      if(sparam == m_name+"BtnCloseLot1")     { OnClickCloseLot1();     return(true); }
      if(sparam == m_name+"BtnCloseLot01")    { OnClickCloseLot01();    return(true); }
      if(sparam == m_name+"BtnCloseLot001")   { OnClickCloseLot001();   return(true); }
      // 按手数平仓 自定义
      if(sparam == m_name+"BtnCloseByLots")   { OnClickCloseByLots();   return(true); }
      // 平当前品种
      if(sparam == m_name+"BtnCloseSymbol")   { OnClickCloseSymbol();   return(true); }
      // 一键保本
      if(sparam == m_name+"BtnBreakEven")     { OnClickBreakEven();     return(true); }
      // 无止损浮亏订单回本退出
      if(sparam == m_name+"BtnRecoveryExit")  { OnClickRecoveryExit();  return(true); }
      // 重置所有输入框
      if(sparam == m_name+"BtnResetInputs")   { OnClickResetInputs();   return(true); }
      // 查看今日订单记录
      if(sparam == m_name+"BtnViewOrders")    { OnClickViewOrders();    return(true); }
      // 切换盈亏容器显示
      if(sparam == m_name+"BtnToggleProfit")  { OnClickToggleProfit();  return(true); }
      // 切换持仓容器显示
      if(sparam == m_name+"BtnTogglePos")     { OnClickTogglePositions(); return(true); }
      // 切换自动减仓开关
      if(sparam == m_name+"BtnToggleScaleOut") { OnClickToggleScaleOut(); return(true); }
      // 切换多次减仓开关（NEW）
      if(sparam == m_name+"BtnToggleMultiScale") { OnClickToggleMultiScale(); return(true); }
      // 智能计算保本参数
      if(sparam == m_name+"BtnSmartCalc")     { OnClickSmartCalc();     return(true); }
      // 选择止损价格按钮 (NEW)
      if(sparam == m_name+"BtnSelectSL")      { OnClickSelectSL();      return(true); }
      // 选择止盈价格按钮 (NEW)
      if(sparam == m_name+"BtnSelectTP")      { OnClickSelectTP();      return(true); }
      
      // === 挂单交易按钮 (NEW) ===
      if(sparam == m_name+"BtnSelectEntry")   { OnClickSelectEntryPrice(); return(true); }
      if(sparam == m_name+"BtnBuyLimit")      { OnClickBuyLimit();      return(true); }
      if(sparam == m_name+"BtnSellLimit")     { OnClickSellLimit();     return(true); }
      if(sparam == m_name+"BtnBuyStop")       { OnClickBuyStop();       return(true); }
      if(sparam == m_name+"BtnSellStop")      { OnClickSellStop();      return(true); }
   }
   
   return(CAppDialog::OnEvent(id,lparam,dparam,sparam));
}
//#endregion

//#region MARK: 模块--买入卖出
//+------------------------------------------------------------------+
//| 现价买入                                                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickBuy(void)
{
   // 检查交易权限
   if(!IsTradeAllowed())
   {
      Alert("交易未开启! 请在EA属性中勾选\"Allow live trading\"，并确认MT4右上角\"AutoTrading\"按钮已开启。");
      return;
   }
   
   double lots    = StringToDouble(m_edtLots.Text());
   double sl      = StringToDouble(m_edtStopLoss.Text());
   double tp      = StringToDouble(m_edtTakeProfit.Text());
   double price   = NormalizeDouble(Ask, _Digits);
   
   if(lots <= 0)
   {
      Alert("手数不能为0!");
      return;
   }
   
   // sl和tp为0时不设置
   double slPrice = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0;
   double tpPrice = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0;
   
   // 生成唯一Magic Number
   int uniqueMagic = GenerateUniqueMagic();
   string comment = "KTarget#" + IntegerToString(uniqueMagic);  // 注释包含Magic信息
   
   int ticket = OrderSend(_Symbol, OP_BUY, lots, price, 3, slPrice, tpPrice,
                          comment, uniqueMagic, 0, clrBlue);
   if(ticket < 0)
   {
      int err = GetLastError();
      string errMsg = "买入失败! 错误码=" + IntegerToString(err);
      if(err == 4109) errMsg += " (未开启交易权限，请开启AutoTrading)";
      if(err == 130)  errMsg += " (止损/止盈价格无效)";
      if(err == 131)  errMsg += " (手数无效)";
      if(err == 138)  errMsg += " (报价变动，重试)";
      LOG_ERROR(errMsg + " 价格=" + DoubleToString(price, _Digits) + " 止损=" + DoubleToString(slPrice, _Digits) + " 止盈=" + DoubleToString(tpPrice, _Digits) + " 手数=" + DoubleToString(lots, 2));
      Alert(errMsg);
   }
   else
      LOG_INFO("买入成功! 订单号=" + IntegerToString(ticket) +
            " Magic=" + IntegerToString(uniqueMagic) +
            " 价格=" + DoubleToString(price, _Digits) + " 止损=" + DoubleToString(slPrice, _Digits) + " 止盈=" + DoubleToString(tpPrice, _Digits) + " 手数=" + DoubleToString(lots, 2));
}

//+------------------------------------------------------------------+
//| 现价卖出                                                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSell(void)
{
   // 检查交易权限
   if(!IsTradeAllowed())
   {
      Alert("交易未开启! 请在EA属性中勾选\"Allow live trading\"，并确认MT4右上角\"AutoTrading\"按钮已开启。");
      return;
   }
   
   double lots    = StringToDouble(m_edtLots.Text());
   double sl      = StringToDouble(m_edtStopLoss.Text());
   double tp      = StringToDouble(m_edtTakeProfit.Text());
   double price   = NormalizeDouble(Bid, _Digits);
   
   if(lots <= 0)
   {
      Alert("手数不能为0!");
      return;
   }
   
   // sl和tp为0时不设置
   double slPrice = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0;
   double tpPrice = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0;
   
   // 生成唯一Magic Number
   int uniqueMagic = GenerateUniqueMagic();
   string comment = "KTarget#" + IntegerToString(uniqueMagic);  // 注释包含Magic信息
   
   int ticket = OrderSend(_Symbol, OP_SELL, lots, price, 3, slPrice, tpPrice,
                          comment, uniqueMagic, 0, clrRed);
   if(ticket < 0)
   {
      int err = GetLastError();
      string errMsg = "卖出失败! 错误码=" + IntegerToString(err);
      if(err == 4109) errMsg += " (未开启交易权限，请开启AutoTrading)";
      if(err == 130)  errMsg += " (止损/止盈价格无效)";
      if(err == 131)  errMsg += " (手数无效)";
      if(err == 138)  errMsg += " (报价变动，重试)";
      LOG_ERROR(errMsg + " 价格=" + DoubleToString(price, _Digits) + " 止损=" + DoubleToString(slPrice, _Digits) + " 止盈=" + DoubleToString(tpPrice, _Digits) + " 手数=" + DoubleToString(lots, 2));
      Alert(errMsg);
   }
   else
      LOG_INFO("卖出成功! 订单号=" + IntegerToString(ticket) +
            " Magic=" + IntegerToString(uniqueMagic) +
            " 价格=" + DoubleToString(price, _Digits) + " 止损=" + DoubleToString(slPrice, _Digits) + " 止盈=" + DoubleToString(tpPrice, _Digits) + " 手数=" + DoubleToString(lots, 2));
}

//+------------------------------------------------------------------+
//| Buy Limit挂单                                                    |
//+------------------------------------------------------------------+
void CTradePanel::OnClickBuyLimit(void)
{
   // 检查交易权限
   if(!IsTradeAllowed())
   {
      Alert("交易未开启! 请在EA属性中勾选\"Allow live trading\"，并确认MT4右上角\"AutoTrading\"按钮已开启。");
      return;
   }
   
   double lots       = StringToDouble(m_edtLots.Text());
   double entryPrice = StringToDouble(m_edtEntryPrice.Text());
   double sl         = StringToDouble(m_edtStopLoss.Text());
   double tp         = StringToDouble(m_edtTakeProfit.Text());
   
   if(lots <= 0)
   {
      Alert("手数不能为0!");
      return;
   }
   
   if(entryPrice <= 0)
   {
      Alert("挂单价格无效!");
      return;
   }
   
   // Buy Limit必须低于当前Ask价
   if(entryPrice >= Ask)
   {
      Alert("Buy Limit价格必须低于当前Ask价(" + DoubleToString(Ask, _Digits) + ")!");
      return;
   }
   
   // sl和tp为0时不设置
   double slPrice = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0;
   double tpPrice = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0;
   
   // 生成唯一Magic Number
   int uniqueMagic = GenerateUniqueMagic();
   string comment = "KTarget#" + IntegerToString(uniqueMagic);
   
   int ticket = OrderSend(_Symbol, OP_BUYLIMIT, lots, NormalizeDouble(entryPrice, _Digits), 3, slPrice, tpPrice,
                          comment, uniqueMagic, 0, clrBlue);
   if(ticket < 0)
   {
      int err = GetLastError();
      string errMsg = "Buy Limit挂单失败! 错误码=" + IntegerToString(err);
      if(err == 4109) errMsg += " (未开启交易权限)";
      if(err == 130)  errMsg += " (价格无效)";
      if(err == 131)  errMsg += " (手数无效)";
      if(err == 138)  errMsg += " (报价变动，重试)";
      LOG_ERROR(errMsg + " 挂单价=" + DoubleToString(entryPrice, _Digits) + " 手数=" + DoubleToString(lots, 2));
      Alert(errMsg);
   }
   else
      LOG_INFO("Buy Limit挂单成功! 订单号=" + IntegerToString(ticket) +
            " Magic=" + IntegerToString(uniqueMagic) +
            " 挂单价=" + DoubleToString(entryPrice, _Digits) + " 手数=" + DoubleToString(lots, 2));
}

//+------------------------------------------------------------------+
//| Sell Limit挂单                                                   |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSellLimit(void)
{
   // 检查交易权限
   if(!IsTradeAllowed())
   {
      Alert("交易未开启! 请在EA属性中勾选\"Allow live trading\"，并确认MT4右上角\"AutoTrading\"按钮已开启。");
      return;
   }
   
   double lots       = StringToDouble(m_edtLots.Text());
   double entryPrice = StringToDouble(m_edtEntryPrice.Text());
   double sl         = StringToDouble(m_edtStopLoss.Text());
   double tp         = StringToDouble(m_edtTakeProfit.Text());
   
   if(lots <= 0)
   {
      Alert("手数不能为0!");
      return;
   }
   
   if(entryPrice <= 0)
   {
      Alert("挂单价格无效!");
      return;
   }
   
   // Sell Limit必须高于当前Bid价
   if(entryPrice <= Bid)
   {
      Alert("Sell Limit价格必须高于当前Bid价(" + DoubleToString(Bid, _Digits) + ")!");
      return;
   }
   
   // sl和tp为0时不设置
   double slPrice = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0;
   double tpPrice = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0;
   
   // 生成唯一Magic Number
   int uniqueMagic = GenerateUniqueMagic();
   string comment = "KTarget#" + IntegerToString(uniqueMagic);
   
   int ticket = OrderSend(_Symbol, OP_SELLLIMIT, lots, NormalizeDouble(entryPrice, _Digits), 3, slPrice, tpPrice,
                          comment, uniqueMagic, 0, clrRed);
   if(ticket < 0)
   {
      int err = GetLastError();
      string errMsg = "Sell Limit挂单失败! 错误码=" + IntegerToString(err);
      if(err == 4109) errMsg += " (未开启交易权限)";
      if(err == 130)  errMsg += " (价格无效)";
      if(err == 131)  errMsg += " (手数无效)";
      if(err == 138)  errMsg += " (报价变动，重试)";
      LOG_ERROR(errMsg + " 挂单价=" + DoubleToString(entryPrice, _Digits) + " 手数=" + DoubleToString(lots, 2));
      Alert(errMsg);
   }
   else
      LOG_INFO("Sell Limit挂单成功! 订单号=" + IntegerToString(ticket) +
            " Magic=" + IntegerToString(uniqueMagic) +
            " 挂单价=" + DoubleToString(entryPrice, _Digits) + " 手数=" + DoubleToString(lots, 2));
}

//+------------------------------------------------------------------+
//| Buy Stop挂单                                                     |
//+------------------------------------------------------------------+
void CTradePanel::OnClickBuyStop(void)
{
   // 检查交易权限
   if(!IsTradeAllowed())
   {
      Alert("交易未开启! 请在EA属性中勾选\"Allow live trading\"，并确认MT4右上角\"AutoTrading\"按钮已开启。");
      return;
   }
   
   double lots       = StringToDouble(m_edtLots.Text());
   double entryPrice = StringToDouble(m_edtEntryPrice.Text());
   double sl         = StringToDouble(m_edtStopLoss.Text());
   double tp         = StringToDouble(m_edtTakeProfit.Text());
   
   if(lots <= 0)
   {
      Alert("手数不能为0!");
      return;
   }
   
   if(entryPrice <= 0)
   {
      Alert("挂单价格无效!");
      return;
   }
   
   // Buy Stop必须高于当前Ask价
   if(entryPrice <= Ask)
   {
      Alert("Buy Stop价格必须高于当前Ask价(" + DoubleToString(Ask, _Digits) + ")!");
      return;
   }
   
   // sl和tp为0时不设置
   double slPrice = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0;
   double tpPrice = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0;
   
   // 生成唯一Magic Number
   int uniqueMagic = GenerateUniqueMagic();
   string comment = "KTarget#" + IntegerToString(uniqueMagic);
   
   int ticket = OrderSend(_Symbol, OP_BUYSTOP, lots, NormalizeDouble(entryPrice, _Digits), 3, slPrice, tpPrice,
                          comment, uniqueMagic, 0, clrBlue);
   if(ticket < 0)
   {
      int err = GetLastError();
      string errMsg = "Buy Stop挂单失败! 错误码=" + IntegerToString(err);
      if(err == 4109) errMsg += " (未开启交易权限)";
      if(err == 130)  errMsg += " (价格无效)";
      if(err == 131)  errMsg += " (手数无效)";
      if(err == 138)  errMsg += " (报价变动，重试)";
      LOG_ERROR(errMsg + " 挂单价=" + DoubleToString(entryPrice, _Digits) + " 手数=" + DoubleToString(lots, 2));
      Alert(errMsg);
   }
   else
      LOG_INFO("Buy Stop挂单成功! 订单号=" + IntegerToString(ticket) +
            " Magic=" + IntegerToString(uniqueMagic) +
            " 挂单价=" + DoubleToString(entryPrice, _Digits) + " 手数=" + DoubleToString(lots, 2));
}

//+------------------------------------------------------------------+
//| Sell Stop挂单                                                    |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSellStop(void)
{
   // 检查交易权限
   if(!IsTradeAllowed())
   {
      Alert("交易未开启! 请在EA属性中勾选\"Allow live trading\"，并确认MT4右上角\"AutoTrading\"按钮已开启。");
      return;
   }
   
   double lots       = StringToDouble(m_edtLots.Text());
   double entryPrice = StringToDouble(m_edtEntryPrice.Text());
   double sl         = StringToDouble(m_edtStopLoss.Text());
   double tp         = StringToDouble(m_edtTakeProfit.Text());
   
   if(lots <= 0)
   {
      Alert("手数不能为0!");
      return;
   }
   
   if(entryPrice <= 0)
   {
      Alert("挂单价格无效!");
      return;
   }
   
   // Sell Stop必须低于当前Bid价
   if(entryPrice >= Bid)
   {
      Alert("Sell Stop价格必须低于当前Bid价(" + DoubleToString(Bid, _Digits) + ")!");
      return;
   }
   
   // sl和tp为0时不设置
   double slPrice = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0;
   double tpPrice = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0;
   
   // 生成唯一Magic Number
   int uniqueMagic = GenerateUniqueMagic();
   string comment = "KTarget#" + IntegerToString(uniqueMagic);
   
   int ticket = OrderSend(_Symbol, OP_SELLSTOP, lots, NormalizeDouble(entryPrice, _Digits), 3, slPrice, tpPrice,
                          comment, uniqueMagic, 0, clrRed);
   if(ticket < 0)
   {
      int err = GetLastError();
      string errMsg = "Sell Stop挂单失败! 错误码=" + IntegerToString(err);
      if(err == 4109) errMsg += " (未开启交易权限)";
      if(err == 130)  errMsg += " (价格无效)";
      if(err == 131)  errMsg += " (手数无效)";
      if(err == 138)  errMsg += " (报价变动，重试)";
      LOG_ERROR(errMsg + " 挂单价=" + DoubleToString(entryPrice, _Digits) + " 手数=" + DoubleToString(lots, 2));
      Alert(errMsg);
   }
   else
      LOG_INFO("Sell Stop挂单成功! 订单号=" + IntegerToString(ticket) +
            " Magic=" + IntegerToString(uniqueMagic) +
            " 挂单价=" + DoubleToString(entryPrice, _Digits) + " 手数=" + DoubleToString(lots, 2));
}
//#endregion

//#region MARK: 模块--面板事件
//+------------------------------------------------------------------+
//| 选择挂单价格按钮                                                  |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSelectEntryPrice(void)
{
   // 激活挂单价格选择模式
   g_priceSelectMode = MODE_SELECT_ENTRY;
   g_lastButtonClickTime = GetTickCount();  // 记录时间戳（防穿透）
   
   // 视觉反馈：按钮高亮
   m_btnSelectEntry.ColorBackground(clrYellow);
   
   // 禁用鼠标滚动（避免误操作）
   ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
   
   // 显示提示
   // Comment("【选择挂单价格】\n请点击图表任意位置...\n(将自动磁吸到最近的High/Low)");
   
   ChartRedraw();
   PlaySound("tick.wav");
}

//+------------------------------------------------------------------+
//| 按点数设置止损（对当前品种所有持仓订单）                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSetSlPoints(void)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }
   
   int pts = (int)StringToInteger(m_edtSlPoints.Text());
   if(pts <= 0) { Alert("止损点数必须大于0!"); return; }
   
   int count = 0, skipped = 0, failed = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      
      double newSL;
      if(OrderType() == OP_BUY)
         newSL = NormalizeDouble(OrderOpenPrice() - pts * _Point, _Digits);
      else
         newSL = NormalizeDouble(OrderOpenPrice() + pts * _Point, _Digits);
      
      // === 智能保护：跳过已有更优止损的订单 ===
      double oldSL = OrderStopLoss();
      if(oldSL > 0)  // 订单已有止损
      {
         if(OrderType() == OP_BUY && newSL <= oldSL)
         {
            // 买单：新止损更危险或相同 → 跳过
            LOG_DEBUG("订单#" + IntegerToString(OrderTicket()) + " 跳过：新止损(" + DoubleToString(newSL, _Digits) + 
                  ")≤当前(" + DoubleToString(oldSL, _Digits) + ")");
            skipped++;
            continue;
         }
         if(OrderType() == OP_SELL && newSL >= oldSL)
         {
            // 卖单：新止损更危险或相同 → 跳过
            LOG_DEBUG("订单#" + IntegerToString(OrderTicket()) + " 跳过：新止损(" + DoubleToString(newSL, _Digits) + 
                  ")≥当前(" + DoubleToString(oldSL, _Digits) + ")");
            skipped++;
            continue;
         }
      }
      
      if(OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrYellow))
         count++;
      else
      {
         LOG_ERROR("设置止损失败 订单=" + IntegerToString(OrderTicket()) + " 错误=" + IntegerToString(GetLastError()));
         failed++;
      }
   }
   if(count == 0 && failed == 0 && skipped == 0)
      LOG_INFO("当前品种无持仓订单");
   else
      LOG_INFO("按点数设置止损: 成功=" + IntegerToString(count) + " 跳过已保护=" + IntegerToString(skipped) + " 失败=" + IntegerToString(failed) + " 点数=" + IntegerToString(pts));
   if(failed > 0) Alert("部分订单设置止损失败! 失败数=" + IntegerToString(failed));
   if(skipped > 0) Alert("提示: 已跳过" + IntegerToString(skipped) + "笔受保护订单（止损更优）");
}

//+------------------------------------------------------------------+
//| 按价格设置止损（对当前品种所有持仓订单）                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSetSlPrice(void)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }
   
   double slPrice = NormalizeDouble(StringToDouble(m_edtSlPrice2.Text()), _Digits);
   if(slPrice <= 0) { Alert("止损价格无效!"); return; }
   
   int count = 0, skipped = 0, failed = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      
      // === 智能保护：跳过已有更优止损的订单 ===
      double oldSL = OrderStopLoss();
      if(oldSL > 0)  // 订单已有止损
      {
         if(OrderType() == OP_BUY && slPrice <= oldSL)
         {
            // 买单：新止损更危险或相同 → 跳过
            LOG_DEBUG("订单#" + IntegerToString(OrderTicket()) + " 跳过：新止损(" + DoubleToString(slPrice, _Digits) + 
                  ")≤当前(" + DoubleToString(oldSL, _Digits) + ")");
            skipped++;
            continue;
         }
         if(OrderType() == OP_SELL && slPrice >= oldSL)
         {
            // 卖单：新止损更危险或相同 → 跳过
            LOG_DEBUG("订单#" + IntegerToString(OrderTicket()) + " 跳过：新止损(" + DoubleToString(slPrice, _Digits) + 
                  ")≥当前(" + DoubleToString(oldSL, _Digits) + ")");
            skipped++;
            continue;
         }
      }
      
      if(OrderModify(OrderTicket(), OrderOpenPrice(), slPrice, OrderTakeProfit(), 0, clrYellow))
         count++;
      else
      {
         LOG_ERROR("设置止损失败 订单=" + IntegerToString(OrderTicket()) + " 错误=" + IntegerToString(GetLastError()));
         failed++;
      }
   }
   if(count == 0 && failed == 0 && skipped == 0)
      LOG_INFO("当前品种无持仓订单");
   else
      LOG_INFO("按价格设置止损: 成功=" + IntegerToString(count) + " 跳过已保护=" + IntegerToString(skipped) + " 失败=" + IntegerToString(failed) + " 价格=" + DoubleToString(slPrice, _Digits));
   if(failed > 0) Alert("部分订单设置止损失败! 失败数=" + IntegerToString(failed));
   if(skipped > 0) Alert("提示: 已跳过" + IntegerToString(skipped) + "笔受保护订单（止损更优）");
}

//+------------------------------------------------------------------+
//| 按点数设置止盈（对当前品种所有持仓订单）                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSetTpPoints(void)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }
   
   int pts = (int)StringToInteger(m_edtTpPoints.Text());
   if(pts <= 0) { Alert("止盈点数必须大于0!"); return; }
   
   int count = 0, skipped = 0, failed = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      
      double newTP;
      if(OrderType() == OP_BUY)
         newTP = NormalizeDouble(OrderOpenPrice() + pts * _Point, _Digits);
      else
         newTP = NormalizeDouble(OrderOpenPrice() - pts * _Point, _Digits);
      
      // === 智能保护：跳过已有更优止盈的订单 ===
      double oldTP = OrderTakeProfit();
      if(oldTP > 0)  // 订单已有止盈
      {
         if(OrderType() == OP_BUY && newTP <= oldTP)
         {
            // 买单：新止盈更差或相同 → 跳过
            LOG_DEBUG("订单#" + IntegerToString(OrderTicket()) + " 跳过：新止盈(" + DoubleToString(newTP, _Digits) + 
                  ")≤当前(" + DoubleToString(oldTP, _Digits) + ")");
            skipped++;
            continue;
         }
         if(OrderType() == OP_SELL && newTP >= oldTP)
         {
            // 卖单：新止盈更差或相同 → 跳过
            LOG_DEBUG("订单#" + IntegerToString(OrderTicket()) + " 跳过：新止盈(" + DoubleToString(newTP, _Digits) + 
                  ")≥当前(" + DoubleToString(oldTP, _Digits) + ")");
            skipped++;
            continue;
         }
      }
      
      if(OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), newTP, 0, clrAqua))
         count++;
      else
      {
         LOG_ERROR("设置止盈失败 订单=" + IntegerToString(OrderTicket()) + " 错误=" + IntegerToString(GetLastError()));
         failed++;
      }
   }
   if(count == 0 && failed == 0 && skipped == 0)
      LOG_INFO("当前品种无持仓订单");
   else
      LOG_INFO("按点数设置止盈: 成功=" + IntegerToString(count) + " 跳过已保护=" + IntegerToString(skipped) + " 失败=" + IntegerToString(failed) + " 点数=" + IntegerToString(pts));
   if(failed > 0) Alert("部分订单设置止盈失败! 失败数=" + IntegerToString(failed));
   if(skipped > 0) Alert("提示: 已跳过" + IntegerToString(skipped) + "笔受保护订单（止盈更优）");
}

//+------------------------------------------------------------------+
//| 按价格设置止盈（对当前品种所有持仓订单）                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSetTpPrice(void)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }
   
   double tpPrice = NormalizeDouble(StringToDouble(m_edtTpPrice2.Text()), _Digits);
   if(tpPrice <= 0) { Alert("止盈价格无效!"); return; }
   
   int count = 0, skipped = 0, failed = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      
      // === 智能保护：跳过已有更优止盈的订单 ===
      double oldTP = OrderTakeProfit();
      if(oldTP > 0)  // 订单已有止盈
      {
         if(OrderType() == OP_BUY && tpPrice <= oldTP)
         {
            // 买单：新止盈更差或相同 → 跳过
            LOG_DEBUG("订单#" + IntegerToString(OrderTicket()) + " 跳过：新止盈(" + DoubleToString(tpPrice, _Digits) + 
                  ")≤当前(" + DoubleToString(oldTP, _Digits) + ")");
            skipped++;
            continue;
         }
         if(OrderType() == OP_SELL && tpPrice >= oldTP)
         {
            // 卖单：新止盈更差或相同 → 跳过
            LOG_DEBUG("订单#" + IntegerToString(OrderTicket()) + " 跳过：新止盈(" + DoubleToString(tpPrice, _Digits) + 
                  ")≥当前(" + DoubleToString(oldTP, _Digits) + ")");
            skipped++;
            continue;
         }
      }
      
      if(OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tpPrice, 0, clrAqua))
         count++;
      else
      {
         LOG_ERROR("设置止盈失败 订单=" + IntegerToString(OrderTicket()) + " 错误=" + IntegerToString(GetLastError()));
         failed++;
      }
   }
   if(count == 0 && failed == 0 && skipped == 0)
      LOG_INFO("当前品种无持仓订单");
   else
      LOG_INFO("按价格设置止盈: 成功=" + IntegerToString(count) + " 跳过已保护=" + IntegerToString(skipped) + " 失败=" + IntegerToString(failed) + " 价格=" + DoubleToString(tpPrice, _Digits));
   if(failed > 0) Alert("部分订单设置止盈失败! 失败数=" + IntegerToString(failed));
   if(skipped > 0) Alert("提示: 已跳过" + IntegerToString(skipped) + "笔受保护订单（止盈更优）");
}

//+------------------------------------------------------------------+
//| 强制清除止损（对当前品种所有持仓订单）                            |
//+------------------------------------------------------------------+
void CTradePanel::OnClickClearSl(void)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }

   if(MessageBox("将清除当前品种全部持仓的止损(SL)，是否继续?", "风险确认", 4|32) != 6)
      return;

   int count = 0, skipped = 0, failed = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      if(OrderStopLoss() <= 0)
      {
         skipped++;
         continue;
      }

      if(OrderModify(OrderTicket(), OrderOpenPrice(), 0, OrderTakeProfit(), 0, clrIndianRed))
         count++;
      else
      {
         LOG_ERROR("清除止损失败 订单=" + IntegerToString(OrderTicket()) + " 错误=" + IntegerToString(GetLastError()));
         failed++;
      }
   }

   if(count == 0 && failed == 0 && skipped == 0)
      LOG_INFO("当前品种无持仓订单");
   else
      LOG_INFO("强制清除止损: 成功=" + IntegerToString(count) + " 已为空=" + IntegerToString(skipped) + " 失败=" + IntegerToString(failed));

   if(failed > 0) Alert("部分订单清除止损失败! 失败数=" + IntegerToString(failed));
}

//+------------------------------------------------------------------+
//| 强制清除止盈（对当前品种所有持仓订单）                            |
//+------------------------------------------------------------------+
void CTradePanel::OnClickClearTp(void)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }

   if(MessageBox("将清除当前品种全部持仓的止盈(TP)，是否继续?", "风险确认", 4|32) != 6)
      return;

   int count = 0, skipped = 0, failed = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      if(OrderTakeProfit() <= 0)
      {
         skipped++;
         continue;
      }

      if(OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), 0, 0, clrPeru))
         count++;
      else
      {
         LOG_ERROR("清除止盈失败 订单=" + IntegerToString(OrderTicket()) + " 错误=" + IntegerToString(GetLastError()));
         failed++;
      }
   }

   if(count == 0 && failed == 0 && skipped == 0)
      LOG_INFO("当前品种无持仓订单");
   else
      LOG_INFO("强制清除止盈: 成功=" + IntegerToString(count) + " 已为空=" + IntegerToString(skipped) + " 失败=" + IntegerToString(failed));

   if(failed > 0) Alert("部分订单清除止盈失败! 失败数=" + IntegerToString(failed));
}

//+------------------------------------------------------------------+
//| 比例平仓核心函数                                                   |
//+------------------------------------------------------------------+
void CTradePanel::CloseByPercent(double pct)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }
   if(pct <= 0 || pct > 100) { Alert("比例必须在 1~100 之间!"); return; }

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // 先收集所有持仓信息，避免平仓后索引漂移
   int    tickets[];
   double lotsArr[];
   int    typesArr[];
   int    n = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      ArrayResize(tickets,  n+1);
      ArrayResize(lotsArr,  n+1);
      ArrayResize(typesArr, n+1);
      tickets[n]  = OrderTicket();
      lotsArr[n]  = OrderLots();
      typesArr[n] = OrderType();
      n++;
   }
   if(n == 0) { LOG_INFO("当前品种无持仓订单"); return; }

   int count = 0, failed = 0;
   for(int i = 0; i < n; i++)
   {
      // 计算应平手数，向下取整到手数步长
      double closeLots = MathFloor(lotsArr[i] * pct / 100.0 / lotStep) * lotStep;
      closeLots = NormalizeDouble(closeLots, 2);
      if(closeLots < minLot)     closeLots = minLot;       // 至少平最小手
      if(closeLots > lotsArr[i]) closeLots = lotsArr[i];   // 不超过持仓手数

      double closePrice = (typesArr[i] == OP_BUY)
                          ? NormalizeDouble(Bid, _Digits)
                          : NormalizeDouble(Ask, _Digits);

      if(OrderClose(tickets[i], closeLots, closePrice, 3, clrOrange))
         count++;
      else
      {
         LOG_ERROR("平仓失败 订单=" + IntegerToString(tickets[i]) + " 手数=" + DoubleToString(closeLots, 2) +
               " 错误码=" + IntegerToString(GetLastError()));
         failed++;
      }
   }
   LOG_INFO("比例平仓完成: 比例=" + DoubleToString(pct, 0) + "% 成功=" + IntegerToString(count) + " 失败=" + IntegerToString(failed));
   if(failed > 0) Alert("部分订单平仓失败! 失败数=" + IntegerToString(failed));
}

void CTradePanel::OnClickClose50(void)     { CloseByPercent(50.0);  }
void CTradePanel::OnClickClose80(void)     { CloseByPercent(80.0);  }
void CTradePanel::OnClickClose100(void)    { CloseByPercent(100.0); }

void CTradePanel::OnClickCloseCustom(void)
{
   double pct = StringToDouble(m_edtClosePct.Text());
   if(pct <= 0 || pct > 100)
   {
      Alert("比例必须在 1~100 之间! 当前输入=" + m_edtClosePct.Text());
      return;
   }
   CloseByPercent(pct);
}

//+------------------------------------------------------------------+
//| 按手数平仓核心函数                                                  |
//+------------------------------------------------------------------+
void CTradePanel::CloseLots(double lots)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // 归一化到步长
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = NormalizeDouble(lots, 2);
   if(lots < minLot)
   {
      Alert("平仓手数不能小于最小手数 " + DoubleToString(minLot,2));
      return;
   }

   // 收集持仓，按手数从小到大排序（优先平手数小的单子）
   int    tickets[];
   double lotsArr[];
   int    typesArr[];
   int    n = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      ArrayResize(tickets,  n+1);
      ArrayResize(lotsArr,  n+1);
      ArrayResize(typesArr, n+1);
      tickets[n]  = OrderTicket();
      lotsArr[n]  = OrderLots();
      typesArr[n] = OrderType();
      n++;
   }
   if(n == 0) { LOG_INFO("当前品种无持仓订单"); return; }

   double remaining = lots;
   int count = 0, failed = 0;

   for(int i = 0; i < n && remaining >= minLot; i++)
   {
      double closeThis = MathMin(lotsArr[i], remaining);
      closeThis = MathFloor(closeThis / lotStep) * lotStep;
      closeThis = NormalizeDouble(closeThis, 2);
      if(closeThis < minLot) continue;

      double closePrice = (typesArr[i] == OP_BUY)
                          ? NormalizeDouble(Bid, _Digits)
                          : NormalizeDouble(Ask, _Digits);

      if(OrderClose(tickets[i], closeThis, closePrice, 3, clrViolet))
      {
         remaining = NormalizeDouble(remaining - closeThis, 2);
         count++;
      }
      else
      {
         LOG_ERROR("平仓失败 订单=" + IntegerToString(tickets[i]) + " 手数=" + DoubleToString(closeThis, 2) +
               " 错误码=" + IntegerToString(GetLastError()));
         failed++;
      }
   }
   if(remaining > minLot)
      LOG_INFO("注意: 持仓不足, 尚有 " + DoubleToString(remaining, 2) + " 手未平。共平仓单数=" + IntegerToString(count) + " 失败=" + IntegerToString(failed));
   else
      LOG_INFO("手数平仓完成: 平入=" + DoubleToString(lots, 2) + " 手 成功单数=" + IntegerToString(count) + " 失败=" + IntegerToString(failed));
   if(failed > 0) Alert("部分订单平仓失败! 失败数=" + IntegerToString(failed));
}

void CTradePanel::OnClickCloseLot1(void)   { CloseLots(1.0);  }
void CTradePanel::OnClickCloseLot01(void)  { CloseLots(0.1);  }
void CTradePanel::OnClickCloseLot001(void) { CloseLots(0.01); }

void CTradePanel::OnClickCloseByLots(void)
{
   double lots = StringToDouble(m_edtCloseLots.Text());
   if(lots <= 0)
   {
      Alert("手数必须大于0! 当前输入=" + m_edtCloseLots.Text());
      return;
   }
   CloseLots(lots);
}

//+------------------------------------------------------------------+
//| 平当前品种所有持仓订单                                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickCloseSymbol(void)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   int    tickets[];
   double lotsArr[];
   int    typesArr[];
   int    n = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      ArrayResize(tickets,  n+1);
      ArrayResize(lotsArr,  n+1);
      ArrayResize(typesArr, n+1);
      tickets[n]  = OrderTicket();
      lotsArr[n]  = OrderLots();
      typesArr[n] = OrderType();
      n++;
   }
   if(n == 0) { LOG_INFO("当前品种无持仓订单"); return; }

   int count = 0, failed = 0;
   for(int i = 0; i < n; i++)
   {
      double closePrice = (typesArr[i] == OP_BUY)
                          ? NormalizeDouble(Bid, _Digits)
                          : NormalizeDouble(Ask, _Digits);
      if(OrderClose(tickets[i], lotsArr[i], closePrice, 3, clrRed))
         count++;
      else
      {
         LOG_ERROR("平仓失败 订单=" + IntegerToString(tickets[i]) + " 错误码=" + IntegerToString(GetLastError()));
         failed++;
      }
   }
   LOG_INFO("平当前品种完成: 成功=" + IntegerToString(count) + " 失败=" + IntegerToString(failed));
   if(failed > 0) Alert("部分订单平仓失败! 失败数=" + IntegerToString(failed));
}

//+------------------------------------------------------------------+
//| 一键保本（将本品种所有持仓订单的止损设置为开仓价）          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickBreakEven(void)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }

   int count = 0, skipped = 0, failed = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      double openPrice = OrderOpenPrice();
      double curSL     = OrderStopLoss();
      double buffer    = MathMax(0, BE_Buffer_Points) * Point();

      double targetSL = openPrice;
      if(OrderType() == OP_BUY)
         targetSL = openPrice + buffer;
      else if(OrderType() == OP_SELL)
         targetSL = openPrice - buffer;

      targetSL = NormalizeDouble(targetSL, _Digits);

      // 已经是保本或止损优于目标保本价则跳过
      if(OrderType() == OP_BUY  && curSL >= targetSL) { skipped++; continue; }
      if(OrderType() == OP_SELL && curSL <= targetSL && curSL > 0) { skipped++; continue; }

      if(OrderModify(OrderTicket(), openPrice, targetSL, OrderTakeProfit(), 0, clrCyan))
         count++;
      else
      {
         LOG_ERROR("保本设置失败 订单=" + IntegerToString(OrderTicket()) + " 错误=" + IntegerToString(GetLastError()));
         failed++;
      }
   }
   if(count == 0 && failed == 0 && skipped == 0)
      LOG_INFO("当前品种无持仓订单");
   else
      LOG_INFO("一键保本: 成功=" + IntegerToString(count) + " 跳过已保本=" + IntegerToString(skipped) + " 失败=" + IntegerToString(failed));
   if(failed > 0) Alert("部分订单保本失败! 失败数=" + IntegerToString(failed));
}

//+------------------------------------------------------------------+
//| 计算无止损浮亏订单的回本退出目标价                               |
//+------------------------------------------------------------------+
double CTradePanel::CalculateRecoveryExitPrice(int orderType, double openPrice, int points)
{
   double offset = points * Point();
   double target = (orderType == OP_BUY) ? openPrice - offset : openPrice + offset;
   return NormalizeDouble(target, _Digits);
}

//+------------------------------------------------------------------+
//| 回本退出（无止损浮亏订单：目标已到达则平仓，否则设置服务器TP）    |
//+------------------------------------------------------------------+
void CTradePanel::OnClickRecoveryExit(void)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }

   int points = (int)StringToInteger(m_edtSlPoints.Text());
   if(points < 0) { Alert("回本退出点数不能小于0!"); return; }

   int modified = 0, closed = 0, hasSL = 0, notLosing = 0;
   int tooClose = 0, unchanged = 0, failed = 0;
   double stopDistance = MarketInfo(_Symbol, MODE_STOPLEVEL) * Point();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      if(OrderStopLoss() > 0) { hasSL++; continue; }

      RefreshRates();
      int type = OrderType();
      bool isLosing = (type == OP_BUY && Bid < OrderOpenPrice()) ||
                      (type == OP_SELL && Ask > OrderOpenPrice());
      if(!isLosing) { notLosing++; continue; }

      double targetTP = CalculateRecoveryExitPrice(type, OrderOpenPrice(), points);

      // 买单示例（XAUUSD，_Point=0.01）：开仓价3000.00，输入500点，
      // 允许亏损距离为5.00，回本退出目标价为2995.00。
      // 1. 点击按钮时Bid=2990.00：尚未到达2995.00，后续设置服务器TP=2995.00，
      //    等待价格反弹到目标后由服务器平仓。
      // 2. 点击按钮时Bid=2997.00：订单仍然浮亏，但当前价已经优于2995.00目标，
      //    此时买单TP不能设置在当前Bid下方，因此直接按当前市价平仓；
      //    实际退出价约2997.00，也优于原定的2995.00退出目标。
      bool targetReached = (type == OP_BUY && Bid >= targetTP) ||
                           (type == OP_SELL && Ask <= targetTP);

      ResetLastError();
      if(targetReached)
      {
         double closePrice = NormalizeDouble(type == OP_BUY ? Bid : Ask, _Digits);
         if(OrderClose(OrderTicket(), OrderLots(), closePrice, 3, clrTeal))
            closed++;
         else
         {
            LOG_ERROR("回本退出平仓失败 订单=" + IntegerToString(OrderTicket()) +
                      " 错误=" + IntegerToString(GetLastError()));
            failed++;
         }
         continue;
      }

      bool distanceInvalid = (type == OP_BUY && targetTP - Bid < stopDistance) ||
                             (type == OP_SELL && Ask - targetTP < stopDistance);
      if(distanceInvalid)
      {
         tooClose++;
         LOG_WARNING("回本退出TP距离当前价过近 订单=" + IntegerToString(OrderTicket()) +
                     " 目标TP=" + DoubleToString(targetTP, _Digits));
         continue;
      }

      if(OrderTakeProfit() > 0 && MathAbs(OrderTakeProfit() - targetTP) < Point() / 2.0)
      {
         unchanged++;
         continue;
      }

      double oldTP = OrderTakeProfit();
      if(OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), targetTP, 0, clrTeal))
      {
         modified++;
         LOG_INFO("回本退出TP设置成功 订单=" + IntegerToString(OrderTicket()) +
                  " 原TP=" + DoubleToString(oldTP, _Digits) +
                  " 新TP=" + DoubleToString(targetTP, _Digits));
      }
      else
      {
         LOG_ERROR("回本退出TP设置失败 订单=" + IntegerToString(OrderTicket()) +
                   " 目标TP=" + DoubleToString(targetTP, _Digits) +
                   " 错误=" + IntegerToString(GetLastError()));
         failed++;
      }
   }

   LOG_INFO("回本退出: 设置TP=" + IntegerToString(modified) +
            " 直接平仓=" + IntegerToString(closed) +
            " 已有SL=" + IntegerToString(hasSL) +
            " 非浮亏=" + IntegerToString(notLosing) +
            " 距离过近=" + IntegerToString(tooClose) +
            " 无需修改=" + IntegerToString(unchanged) +
            " 失败=" + IntegerToString(failed) +
            " 点数=" + IntegerToString(points));
   if(failed > 0) Alert("部分订单回本退出设置失败! 失败数=" + IntegerToString(failed));
}

//+------------------------------------------------------------------+
//| 查看今日订单（切换侧边订单面板）                                  |
//+------------------------------------------------------------------+
void CTradePanel::OnClickViewOrders(void)
{
   if(!g_ordersCreated)
   {
      // 首次打开：统计今日订单数、动态计算高度、创建面板（只创建一次）
      int      localOffset = (int)(TimeLocal() - TimeCurrent());
      datetime localNow    = TimeLocal();
      datetime localToday0 = localNow - (localNow % 86400);
      datetime svrToday0   = (datetime)(localToday0 - localOffset);

      int todayCnt = 0;
      for(int i = 0; i < OrdersTotal(); i++)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderSymbol() != _Symbol) continue;
         if(OrderType() == OP_BUY || OrderType() == OP_SELL) todayCnt++;
      }
      for(int i = OrdersHistoryTotal()-1; i >= 0; i--)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
         if(OrderSymbol() != _Symbol) continue;
         if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
         if(OrderCloseTime() >= svrToday0) todayCnt++;
      }
      int rows   = MathMax(todayCnt, 3);
      int panelH = 43 + rows * 17 + 36;

      int ox = PanelX + 410;
      int oy = PanelY;
      g_ordersPanel.SetMaxRows(rows);
      if(!g_ordersPanel.Create(0,"OrdersPanel",0,ox,oy,ox+460,oy+panelH))
      {
         LOG_ERROR("创建订单记录面板失败!");
         return;
      }
      g_ordersPanel.Run();
      g_ordersPanel.RefreshOrders();
      g_ordersCreated      = true;
      g_ordersPanelVisible = true;
      m_btnViewOrders.Text("隐藏今日订单记录");
      // Create() 完成后面板已可见，直接返回
      return;
   }

   // 面板已创建过：用 Hide/Show 切换，绝不调用 Destroy
   // （Destroy 会触发 ON_APP_CLOSE 自定义事件级联销毁主面板）
   if(!g_ordersPanelVisible)
   {
      g_ordersPanel.RefreshOrders();
      g_ordersPanel.Show();
      g_ordersPanelVisible = true;
      m_btnViewOrders.Text("隐藏今日订单记录");
   }
   else
   {
      g_ordersPanel.Hide();
      g_ordersPanelVisible = false;
      m_btnViewOrders.Text("查看今日订单记录");
   }
}

//+------------------------------------------------------------------+
//| 重置所有输入框为默认值                                            |
//+------------------------------------------------------------------+
void CTradePanel::OnClickResetInputs(void)
{
   // 将成员变量重置为构造函数中定义的默认值
   m_lastLots = "0.03";
   m_lastStopLoss = "0.00000";
   m_lastTakeProfit = "0.00000";
   m_lastSlPoints = "400";
   m_lastSlPrice2 = "0.00000";
   m_lastTpPoints = "1000";
   m_lastTpPrice2 = "0.00000";
   m_lastClosePct = "30";
   m_lastCloseLots = "0.10";
   m_lastTriggerPts = "200";
   m_lastScalePct = "80";
   m_lastScaleLots = "0.04";
   m_lastEntryPrice = "0.00000";
   
   // 调用现有方法将默认值应用到UI控件
   RestoreInputValues();
   
   // 刷新面板
   ChartRedraw();
   
   // 音效反馈
   PlaySound("ok.wav");
   
   LOG_INFO("已重置所有输入框为默认值");
}

//+------------------------------------------------------------------+
//| 切换盈亏容器显示                                                  |
//+------------------------------------------------------------------+
void CTradePanel::OnClickToggleProfit(void)
{
   m_showProfit = !m_showProfit;
   
   if(m_showProfit)
   {
      UpdateInfoContainers();              // 重新加载数据
      m_btnToggleProfit.Text("隐藏");
   }
   else
   {
      m_edtDailyProfit.Text("[ 已隐藏 ]");
      m_edtDailyProfit.ColorBackground(clrLightGray);
      m_edtDailyProfit.ColorBorder(clrGray);
      m_btnToggleProfit.Text("显示");
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 切换持仓容器显示                                                  |
//+------------------------------------------------------------------+
void CTradePanel::OnClickTogglePositions(void)
{
   m_showPositions = !m_showPositions;
   
   if(m_showPositions)
   {
      UpdateInfoContainers();              // 重新加载数据
      m_btnTogglePositions.Text("隐藏");
   }
   else
   {
      m_edtPositions.Text("[ 已隐藏 ]");
      m_edtPositions.ColorBackground(clrLightGray);
      m_edtPositions.ColorBorder(clrGray);
      m_btnTogglePositions.Text("显示");
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 更新信息容器                                                      |
//+------------------------------------------------------------------+
void CTradePanel::UpdateInfoContainers(void)
{
   // 更新盈亏容器
   if(m_showProfit)
   {
      double dailyProfit = CalculateDailyProfit();
      double balance = AccountBalance();
      // === 【修复】正确计算百分比：相对于今日起始余额，而不是当前余额 ===
      double startBalance = balance - dailyProfit;  // 今日起始余额 = 当前余额 - 今日盈亏
      double profitPercent = (startBalance > 0) ? (dailyProfit / startBalance * 100) : 0;
      
      string profitText = StringFormat("今日盈亏: %s$%.2f (%s%.2f%%)",
         dailyProfit >= 0 ? "+" : "",
         dailyProfit,
         profitPercent >= 0 ? "+" : "",
         profitPercent);
      m_edtDailyProfit.Text(profitText);
      
      // 动态变色
      if(dailyProfit >= 0)
      {
         m_edtDailyProfit.ColorBackground(clrHoneydew);
         m_edtDailyProfit.ColorBorder(clrGreen);
      }
      else
      {
         m_edtDailyProfit.ColorBackground(clrMistyRose);
         m_edtDailyProfit.ColorBorder(clrRed);
      }
   }
   
   // 更新持仓容器
   if(m_showPositions)
   {
      string posText = GetCurrentPositions();
      m_edtPositions.Text(posText);
   }
}

//+------------------------------------------------------------------+
//| 计算今日盈亏                                                      |
//+------------------------------------------------------------------+
double CTradePanel::CalculateDailyProfit(void)
{
   // 计算今日本地时间起始点
   int      localOffset = (int)(TimeLocal() - TimeCurrent());
   datetime localNow    = TimeLocal();
   datetime localToday0 = localNow - (localNow % 86400);
   datetime svrToday0   = (datetime)(localToday0 - localOffset);
   
   double totalProfit = 0;
   
   // 统计当前持仓（今日开仓的）
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(OrderOpenTime() >= svrToday0)  // 今日开仓
      {
         totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }
   
   // 统计今日已平仓订单
   for(int i = OrdersHistoryTotal()-1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(OrderCloseTime() >= svrToday0)  // 今日平仓
      {
         totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
//| 获取当前持仓价格                                                  |
//+------------------------------------------------------------------+
string CTradePanel::GetCurrentPositions(void)
{
   string buyPrices = "";
   string sellPrices = "";
   int buyCount = 0;
   int sellCount = 0;
   
   // 遍历当前持仓
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      
      if(OrderType() == OP_BUY)
      {
         if(buyCount > 0) buyPrices += ", ";
         buyPrices += DoubleToString(OrderOpenPrice(), _Digits);
         buyCount++;
      }
      else if(OrderType() == OP_SELL)
      {
         if(sellCount > 0) sellPrices += ", ";
         sellPrices += DoubleToString(OrderOpenPrice(), _Digits);
         sellCount++;
      }
   }
   
   // 组装显示文本
   string result = "持仓: ";
   if(buyCount == 0 && sellCount == 0)
   {
      result += "无持仓";
   }
   else
   {
      if(buyCount > 0)
         result += "买" + IntegerToString(buyCount) + " [" + buyPrices + "]";
      if(buyCount > 0 && sellCount > 0)
         result += " | ";
      if(sellCount > 0)
         result += "卖" + IntegerToString(sellCount) + " [" + sellPrices + "]";
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| 切换自动减仓开关                                                  |
//+------------------------------------------------------------------+
void CTradePanel::OnClickToggleScaleOut(void)
{
   m_scaleOutEnabled = !m_scaleOutEnabled;
   
   if(m_scaleOutEnabled)
   {
      m_btnToggleScaleOut.Text("自动减仓(开)");
      m_btnToggleScaleOut.ColorBackground(clrOrangeRed);
      LOG_INFO("自动减仓功能已开启");
   }
   else
   {
      m_btnToggleScaleOut.Text("自动减仓(关)");
      m_btnToggleScaleOut.ColorBackground(clrLightGray);
      LOG_INFO("自动减仓功能已关闭");
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 切换多次减仓开关（NEW）                                            |
//+------------------------------------------------------------------+
void CTradePanel::OnClickToggleMultiScale(void)
{
   m_allowMultipleScaleOut = !m_allowMultipleScaleOut;
   
   if(m_allowMultipleScaleOut)
   {
      m_btnToggleMultiScale.Text("多次减仓(开)");
      m_btnToggleMultiScale.ColorBackground(clrMediumSeaGreen);
      LOG_INFO("多次减仓已启用：同一订单可多次达标减仓");
   }
   else
   {
      m_btnToggleMultiScale.Text("多次减仓(关)");
      m_btnToggleMultiScale.ColorBackground(clrLightGray);
      LOG_INFO("多次减仓已关闭：每笔订单仅减仓一次");
      // 注意：不清除 everScaled 标记，已减仓的订单保持状态
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 智能计算保本参数                                                  |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSmartCalc(void)
{
   // 检查是否有持仓
   bool found = false;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      
      found = true;
      
      // 获取订单参数
      double openPrice = OrderOpenPrice();
      double stopLoss = OrderStopLoss();
      double lots = OrderLots();
      
      if(stopLoss == 0)
      {
         Alert("订单 ", OrderTicket(), " 没有设置止损，无法计算！");
         continue;
      }
      
      // 计算止损风险（点数）
      double slDiff = (OrderType() == OP_BUY) ? 
                      (openPrice - stopLoss) :
                      (stopLoss - openPrice);
      int slPts = (int)(slDiff / _Point);
      
      // 计算最大亏损金额
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double maxLoss = slDiff * lots / _Point * tickValue;
      
      // 智能获取减仓比例：优先使用UI当前设置，否则用默认值
      double scalePct = SmartCalc_DefaultScalePct;
      string currentScalePct = m_edtScalePct.Text();
      if(currentScalePct != "" && StringToDouble(currentScalePct) > 0)
      {
         double uiValue = StringToDouble(currentScalePct);
         if(uiValue >= 30.0 && uiValue <= 95.0)
            scalePct = uiValue;  // 使用UI设置的合理值
         else
            LOG_INFO("[智能计算] UI减仓比例 " + DoubleToString(uiValue, 0) + "% 超出范围(30-95%)，使用默认值 " + DoubleToString(SmartCalc_DefaultScalePct, 0) + "%");
      }
      double remainPct = 100.0 - scalePct;
      
      // 剩余仓位如果止损的亏损
      double remainLoss = maxLoss * remainPct / 100.0;
      
      // 计算需要走多少点（减仓部分获利 = 剩余部分风险）
      // scalePct% × triggerPts = remainPct% × slPts
      // triggerPts = remainPct × slPts / scalePct
      int triggerPts = (int)(remainPct * slPts / scalePct);
      
      // === 参数验证 ===
      if(triggerPts <= 0)
      {
         Alert("计算错误：触发点数为 ", triggerPts, "！\n可能原因：减仓比例设置不合理（当前 ", DoubleToString(scalePct, 0), "%）");
         LOG_ERROR("[智能计算] 计算结果异常：triggerPts=" + IntegerToString(triggerPts) + ", scalePct=" + DoubleToString(scalePct, 1));
         return;
      }
      
      if(triggerPts >= slPts)
      {
         string warning = StringFormat(
            "警告：触发点数(%d点)接近或超过止损点数(%d点)！\n"
            "这意味着需要走很远才减仓，风险较大。\n\n"
            "建议：增加减仓比例（当前%.0f%%）或调整止损。",
            triggerPts, slPts, scalePct
         );
         Alert(warning);
         LOG_INFO("[智能计算] " + warning);
      }
      
      // 更新UI
      m_edtTriggerPts.Text(IntegerToString(triggerPts));
      m_edtScalePct.Text(DoubleToString(scalePct, 0));
      
      string msg = StringFormat(
         "智能计算完成！\n\n"
         "订单: %d\n"
         "手数: %.2f\n"
         "止损点数: %d 点\n"
         "最大风险: $%.2f\n\n"
         "建议参数：\n"
         "触发点数: %d 点\n"
         "减仓比例: %.0f%%\n\n"
         "逻辑：走出 %d 点后减仓 %.0f%%，\n"
         "锁定利润 $%.2f，可覆盖剩余仓位风险 $%.2f",
         OrderTicket(), lots, slPts, maxLoss,
         triggerPts, scalePct,
         triggerPts, scalePct, remainLoss, remainLoss
      );
      
      Alert(msg);
      LOG_INFO(msg);
      
      // === 自动开启减仓功能 ===
      if(SmartCalc_AutoEnable)
      {
         if(!m_scaleOutEnabled)
         {
            m_scaleOutEnabled = true;
            m_btnToggleScaleOut.Text("关闭自动减仓");
            m_btnToggleScaleOut.ColorBackground(clrOrangeRed);
            LOG_INFO("[智能计算] 自动减仓功能已自动开启");
            
            // Comment("【智能计算完成】\n参数已更新，自动减仓已启动！");
         }
         else
         {
            LOG_INFO("[智能计算] 自动减仓已在运行中，参数已更新");
            // Comment("【智能计算完成】\n参数已更新，自动减仓继续运行！");
         }
         
         ChartRedraw();
      }
      else
      {
         // Comment("【智能计算完成】\n参数已更新，请手动开启自动减仓功能！");
         LOG_INFO("[智能计算] 参数已更新，自动开启功能已禁用");
      }
      
      break;  // 只计算第一个订单
   }
   
   if(!found)
   {
      Alert("当前品种没有持仓订单！");
   }
}

//+------------------------------------------------------------------+
//| 生成唯一MagicNumber（用于EA开仓）                                   |
//+------------------------------------------------------------------+
int CTradePanel::GenerateUniqueMagic(void)
{
   // 从全局变量读取计数器
   double counter = GlobalVariableGet(g_magicCounterKey);
   
   // 生成Magic: 前缀 + 计数器
   int magic = MAGIC_EA_PREFIX + (int)counter;
   
   // 递增计数器
   GlobalVariableSet(g_magicCounterKey, counter + 1);
   
   LOG_DEBUG("生成唯一Magic: " + IntegerToString(magic));
   return magic;
}

//+------------------------------------------------------------------+
//| 检查并执行自动减仓                                                |
//+------------------------------------------------------------------+
void CTradePanel::CheckAutoScaleOut(void)
{
   if(!m_scaleOutEnabled) return;  // 功能未开启
   
   // 读取参数
   int triggerPts = (int)StringToInteger(m_edtTriggerPts.Text());
   double scalePct = StringToDouble(m_edtScalePct.Text());
   double scaleLots = StringToDouble(m_edtScaleLots.Text());
   
   if(triggerPts <= 0)
   {
      LOG_DEBUG("触发点数无效，已跳过检测");
      return;
   }
   
   // 定期清理已关闭订单（两个系统独立清理）
   CleanupScaledOrders();     // 清理减仓记录
   CleanupStopLossRecords();  // 清理止损记录
   
   // 遍历所有持仓订单
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      
      int magic = OrderMagicNumber();  // ← 获取Magic（不变ID）
      int ticket = OrderTicket();
      
      // 通过Magic检查是否已减仓
      if(IsOrderScaled(magic))  // ← 使用Magic而非Ticket
      {
         continue;  // 已减仓，跳过
      }
      
      // 计算浮盈点数
      double currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
      double diff = (OrderType() == OP_BUY) ? 
                    (currentPrice - OrderOpenPrice()) :
                    (OrderOpenPrice() - currentPrice);
      int profitPts = (int)(diff / _Point);
      
      // 达到触发条件？
      if(profitPts >= triggerPts)
      {
         ExecuteScaleOut(magic, ticket, scalePct, scaleLots);  // ← 传入magic和ticket
      }
   }
}

//+------------------------------------------------------------------+
//| 执行减仓（Magic Number方案：无需追踪Ticket变化）                  |
//+------------------------------------------------------------------+
void CTradePanel::ExecuteScaleOut(int magic, int ticket, double pct, double lots)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   
   // 计算减仓手数
   double currentLots = OrderLots();
   double closeAmount = 0;
   
   // 优先使用比例，如果比例为0则使用固定手数
   if(pct > 0)
   {
      closeAmount = NormalizeDouble(currentLots * pct / 100.0, 2);
   }
   else if(lots > 0)
   {
      closeAmount = lots;
   }
   else
   {
      LOG_ERROR("减仓参数无效");
      return;
   }
   
   // 确保手数符合规范
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   closeAmount = MathFloor(closeAmount / lotStep) * lotStep;
   
   // 确保不超过当前手数，并至少保留最小手数
   if(closeAmount >= currentLots)
   {
      closeAmount = currentLots - minLot;
      if(closeAmount < minLot)
      {
         // [优化] 标记该Magic为"太小"状态，避免后续重复检查
         bool alreadyMarked = false;
         for(int i = 0; i < m_scaleRecordCount; i++)
         {
            if(m_scaleRecords[i].magicNumber == magic)
            {
               alreadyMarked = m_scaleRecords[i].tooSmall;  // 记录之前的状态
               m_scaleRecords[i].tooSmall = true;           // 永久标记
               break;
            }
         }
         
         // 仅第一次标记时输出日志（避免日志爆炸）
         if(!alreadyMarked)
         {
            LOG_INFO("Magic " + IntegerToString(magic) + " 仓位太小(" + DoubleToString(currentLots, 2) + "手)，已停止自动减仓检测");
         }
         return;
      }
   }
   
   // 执行部分平仓
   double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
   bool result = OrderClose(ticket, closeAmount, closePrice, 3);
   
   if(result)
   {
      // === 核心简化：Magic不变，只需标记 everScaled = true ===
      for(int i = 0; i < m_scaleRecordCount; i++)
      {
         if(m_scaleRecords[i].magicNumber == magic)
         {
            m_scaleRecords[i].everScaled = true;  // 标记为已减仓
            m_scaleRecords[i].lastCheck = TimeCurrent();
            break;
         }
      }
      
      // === 详细调试信息 ===
      LOG_DEBUG("========== 自动减仓利润计算调试 ==========");
      LOG_DEBUG("OrderOpenPrice: " + DoubleToString(OrderOpenPrice(), _Digits));
      LOG_DEBUG("closePrice: " + DoubleToString(closePrice, _Digits));
      
      // 计算锁定利润
      double profit = (OrderType() == OP_BUY) ? 
                      (closePrice - OrderOpenPrice()) :
                      (OrderOpenPrice() - closePrice);
      LOG_DEBUG("profit (价格差): " + DoubleToString(profit, _Digits));
      LOG_DEBUG("closeAmount (减仓手数): " + DoubleToString(closeAmount, 2));
      LOG_DEBUG("_Point: " + DoubleToString(_Point, _Digits));
      
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      LOG_DEBUG("SYMBOL_TRADE_TICK_VALUE: " + DoubleToString(tickValue, 4));
      LOG_DEBUG("SYMBOL_TRADE_TICK_SIZE: " + DoubleToString(tickSize, _Digits));
      LOG_DEBUG("SYMBOL_TRADE_CONTRACT_SIZE: " + DoubleToString(contractSize, 0));
      
      double lockedProfit = profit * closeAmount / _Point * tickValue;
      LOG_DEBUG("lockedProfit (当前公式): " + DoubleToString(lockedProfit, 2));
      
      // 使用标准公式重新计算
      double standardProfit = profit * closeAmount * contractSize;
      LOG_DEBUG("standardProfit (标准公式): " + DoubleToString(standardProfit, 2));
      LOG_DEBUG("==========================================");
      
      LOG_INFO("自动减仓成功: Magic=" + IntegerToString(magic) + 
            " Ticket=" + IntegerToString(ticket) +
            " 减仓=" + DoubleToString(closeAmount, 2) + " 手，锁定利润=$" + DoubleToString(lockedProfit, 2));
   }
   else
   {
      int error = GetLastError();
      LOG_ERROR("自动减仓失败: Magic=" + IntegerToString(magic) + " Ticket=" + IntegerToString(ticket) + " Error=" + IntegerToString(error));
   }
}

//+------------------------------------------------------------------+
//| 检查订单是否应该跳过减仓（基于Magic Number，不再需要手数追踪）     |
//+------------------------------------------------------------------+
bool CTradePanel::IsOrderScaled(int magic)
{
   // 查找该Magic的历史记录
   for(int i = 0; i < m_scaleRecordCount; i++)
   {
      if(m_scaleRecords[i].magicNumber == magic)
      {
         // === [状态1] 检查是否已标记为"太小"状态 ===
         if(m_scaleRecords[i].tooSmall)
         {
            return true;  // 永久跳过（MT4订单手数只能减少不能增加）
         }
         
         // === [状态2] 单次减仓模式（默认）：检查是否曾减仓过 ===
         if(!m_allowMultipleScaleOut && m_scaleRecords[i].everScaled)
         {
            return true;  // 已经减仓过，永久跳过
         }
         
         // 更新最后检查时间
         m_scaleRecords[i].lastCheck = TimeCurrent();
         return false;  // 允许减仓（单次模式的首次，或多次模式）
      }
   }
   
   // 首次遇到该Magic，添加新记录
   if(m_scaleRecordCount < 100)
   {
      m_scaleRecords[m_scaleRecordCount].magicNumber = magic;
      m_scaleRecords[m_scaleRecordCount].everScaled = false;  // 初始化为未减仓
      m_scaleRecords[m_scaleRecordCount].tooSmall = false;    // 初始化为"未太小"
      m_scaleRecords[m_scaleRecordCount].lastCheck = TimeCurrent();
      m_scaleRecordCount++;
   }
   return false;  // 首次检查，允许减仓
}

//+------------------------------------------------------------------+
//| 清理已关闭订单记录（基于Magic Number检查，无需Ticket查询）        |
//+------------------------------------------------------------------+
void CTradePanel::CleanupScaledOrders(void)
{
   // 倒序遍历，删除时不影响后续索引
   for(int i = m_scaleRecordCount - 1; i >= 0; i--)
   {
      int magic = m_scaleRecords[i].magicNumber;
      
      // 检查是否还有该Magic的持仓
      bool found = false;
      for(int j = 0; j < OrdersTotal(); j++)
      {
         if(OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderMagicNumber() == magic && OrderSymbol() == _Symbol)
            {
               found = true;
               break;
            }
         }
      }
      
      // 没有找到该Magic的持仓，删除记录
      if(!found)
      {
         for(int j = i; j < m_scaleRecordCount - 1; j++)
         {
            m_scaleRecords[j] = m_scaleRecords[j + 1];
         }
         m_scaleRecordCount--;
      }
   }
}

//+------------------------------------------------------------------+
//| 清理已关闭订单的止损记录（独立架构：止损系统专用）                 |
//+------------------------------------------------------------------+
void CTradePanel::CleanupStopLossRecords(void)
{
   // 倒序遍历，删除时不影响后续索引
   for(int i = m_slRecordCount - 1; i >= 0; i--)
   {
      int magic = m_slRecords[i].magicNumber;
      
      // 检查是否还有该Magic的持仓
      bool found = false;
      for(int j = 0; j < OrdersTotal(); j++)
      {
         if(OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderMagicNumber() == magic && OrderSymbol() == _Symbol)
            {
               found = true;
               break;
            }
         }
      }
      
      // 没有找到该Magic的持仓，删除止损记录
      if(!found)
      {
         LOG_DEBUG("[止损系统] 清理记录: Magic=" + IntegerToString(magic) + " (订单已关闭)");
         
         for(int j = i; j < m_slRecordCount - 1; j++)
         {
            m_slRecords[j] = m_slRecords[j + 1];
         }
         m_slRecordCount--;
      }
   }
}

//+------------------------------------------------------------------+
//| [自动止损] 检查并自动设置止损（每秒调用1次）                      |
//+------------------------------------------------------------------+
void CTradePanel::CheckAutoStopLoss(void)
{
   // 遍历所有持仓订单
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      
      int magic = OrderMagicNumber();
      int ticket = OrderTicket();
      
      // 性能优化：已标记为已保护的订单直接跳过
      if(IsOrderProtected(magic)) continue;
      
      // 订单已有止损，标记为已保护
      if(OrderStopLoss() > 0.00001)
      {
         MarkOrderProtected(magic);
         continue;
      }
      
      // 执行自动设置止损
      SetAutoStopLoss(magic, ticket);
   }
}

//+------------------------------------------------------------------+
//| [自动止损] 设置自动止损（主方案：按点数）                         |
//+------------------------------------------------------------------+
bool CTradePanel::SetAutoStopLoss(int magic, int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
   
   // 读取止损点数（方案A：直接从输入框实时读取，避免缓存不同步问题）
   int slPoints = (int)StringToInteger(m_edtSlPoints.Text());
   if(slPoints <= 0)
   {
      LOG_DEBUG("止损点数无效，跳过自动设置");
      return false;
   }
   
   // 计算止损价格
   double slPrice = CalculateStopLoss(slPoints, OrderType(), OrderOpenPrice());
   
   // 执行OrderModify
   if(OrderModify(ticket, OrderOpenPrice(), slPrice, OrderTakeProfit(), 0, clrYellow))
   {
      MarkOrderProtected(magic);
      LOG_INFO("自动设置止损成功: 订单#" + IntegerToString(ticket) + " SL=" + DoubleToString(slPrice, _Digits) + " 点数=" + IntegerToString(slPoints));
      return true;
   }
   else
   {
      int error = GetLastError();
      
      // 检查是否是止损无效错误（快速行情导致）
      if(error == 130 || error == 3)  // ERR_INVALID_STOPS || ERR_INVALID_TRADE_PARAMETERS
      {
         LOG_WARNING("止损价格无效（快速行情），切换ATR备用方案: 订单#" + IntegerToString(ticket) + " 错误=" + IntegerToString(error));
         return UseATRBackup(magic, ticket);  // 调用ATR备用方案
      }
      
      LOG_ERROR("自动设置止损失败: 订单#" + IntegerToString(ticket) + " 错误=" + IntegerToString(error));
      return false;
   }
}

//+------------------------------------------------------------------+
//| [自动止损] 检查订单是否已设置止损保护（独立架构）                     |
//+------------------------------------------------------------------+
bool CTradePanel::IsOrderProtected(int magic)
{
   // 查找止损记录（使用独立的 m_slRecords 数组）
   for(int i = 0; i < m_slRecordCount; i++)
   {
      if(m_slRecords[i].magicNumber == magic)
      {
         return m_slRecords[i].slProtected;
      }
   }
   return false;  // 未找到记录，视为未保护
}

//+------------------------------------------------------------------+
//| [自动止损] 标记订单为已保护（独立架构）                               |
//+------------------------------------------------------------------+
void CTradePanel::MarkOrderProtected(int magic)
{
   // 先查找是否已有记录（使用独立的 m_slRecords 数组）
   for(int i = 0; i < m_slRecordCount; i++)
   {
      if(m_slRecords[i].magicNumber == magic)
      {
         m_slRecords[i].slProtected = true;
         m_slRecords[i].protectedTime = TimeCurrent();  // 记录保护时间
         return;
      }
   }
   
   // 没有记录，创建新记录（只初始化止损相关字段）
   if(m_slRecordCount < 300)  // 独立容量限制：300
   {
      m_slRecords[m_slRecordCount].magicNumber = magic;
      m_slRecords[m_slRecordCount].slProtected = true;
      m_slRecords[m_slRecordCount].protectedTime = TimeCurrent();
      m_slRecordCount++;
      
      LOG_DEBUG("[止损系统] 创建新记录: Magic=" + IntegerToString(magic) + " (当前记录数:" + IntegerToString(m_slRecordCount) + "/300)");
   }
   else
   {
      LOG_WARNING("止损记录数组已满(300)，无法添加 Magic=" + IntegerToString(magic));
   }
}

//+------------------------------------------------------------------+
//| [自动止损] 计算止损价格（多空自动判断）                           |
//+------------------------------------------------------------------+
double CTradePanel::CalculateStopLoss(int points, int orderType, double openPrice)
{
   double slPrice = 0;
   
   if(orderType == OP_BUY)
   {
      // 买单：止损低于开仓价
      slPrice = NormalizeDouble(openPrice - points * _Point, _Digits);
   }
   else if(orderType == OP_SELL)
   {
      // 卖单：止损高于开仓价
      slPrice = NormalizeDouble(openPrice + points * _Point, _Digits);
   }
   
   return slPrice;
}

//+------------------------------------------------------------------+
//| [自动止损] ATR备用方案（快速行情应急）                            |
//+------------------------------------------------------------------+
bool CTradePanel::UseATRBackup(int magic, int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
   
   // 计算ATR动态止损
   double atrSL = CalculateATRStopLoss(OrderType());
   
   // 如果ATR计算失败，使用固定50点作为最终备用
   if(atrSL == 0)
   {
      LOG_WARNING("ATR计算失败，使用固定50点备用方案");
      atrSL = CalculateStopLoss(50, OrderType(), OrderOpenPrice());
   }
   
   // 执行OrderModify
   if(OrderModify(ticket, OrderOpenPrice(), atrSL, OrderTakeProfit(), 0, clrOrange))
   {
      MarkOrderProtected(magic);
      LOG_INFO("ATR备用方案成功: 订单#" + IntegerToString(ticket) + " SL=" + DoubleToString(atrSL, _Digits) + " (ATR×" + DoubleToString(m_atrMultiplier, 1) + ")");
      return true;
   }
   else
   {
      int error = GetLastError();
      LOG_ERROR("ATR备用方案失败: 订单#" + IntegerToString(ticket) + " 错误=" + IntegerToString(error));
      return false;
   }
}

//+------------------------------------------------------------------+
//| [自动止损] 计算ATR动态止损价格                                    |
//+------------------------------------------------------------------+
double CTradePanel::CalculateATRStopLoss(int orderType)
{
   // 获取14周期ATR（上一根K线）
   double atr14 = iATR(NULL, 0, 14, 1);
   
   // ATR无效（数据不足或异常）
   if(atr14 <= 0 || atr14 == EMPTY_VALUE)
   {
      LOG_WARNING("ATR数据无效，返回0");
      return 0;
   }
   
   double slPrice = 0;
   
   if(orderType == OP_BUY)
   {
      // 买单：止损 = 当前卖价 - ATR × 倍数
      slPrice = NormalizeDouble(Bid - atr14 * m_atrMultiplier, _Digits);
   }
   else if(orderType == OP_SELL)
   {
      // 卖单：止损 = 当前买价 + ATR × 倍数
      slPrice = NormalizeDouble(Ask + atr14 * m_atrMultiplier, _Digits);
   }
   
   LOG_DEBUG("ATR止损计算: ATR=" + DoubleToString(atr14, _Digits) + " 倍数=" + DoubleToString(m_atrMultiplier, 1) + " SL=" + DoubleToString(slPrice, _Digits));
   
   return slPrice;
}

//+------------------------------------------------------------------+
//| 手数减少                                                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickLotsDecrease(void)
{
   double currentLots = StringToDouble(m_edtLots.Text());
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   currentLots -= lotStep;
   if(currentLots < minLot)
      currentLots = minLot;
   
   string newValue = DoubleToString(currentLots, 2);
   m_edtLots.Text(newValue);
   
   LOG_DEBUG("手数减少: 当前值=" + DoubleToString(currentLots, 2) + " 最小=" + DoubleToString(minLot, 2) + " 步长=" + DoubleToString(lotStep, 2));
   
   // 强制刷新控件
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 手数增加                                                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickLotsIncrease(void)
{
   double currentLots = StringToDouble(m_edtLots.Text());
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   currentLots += lotStep;
   if(currentLots > maxLot)
      currentLots = maxLot;
   
   string newValue = DoubleToString(currentLots, 2);
   m_edtLots.Text(newValue);
   
   LOG_DEBUG("手数增加: 当前值=" + DoubleToString(currentLots, 2) + " 最大=" + DoubleToString(maxLot, 2) + " 步长=" + DoubleToString(lotStep, 2));
   
   // 强制刷新控件
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 点击选择止损按钮                                                  |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSelectSL(void)
{
   // 激活止损选择模式
   g_priceSelectMode = MODE_SELECT_SL;
   g_lastButtonClickTime = GetTickCount();  // 记录时间戳（防穿透）
   
   // 视觉反馈：按钮高亮
   m_btnSelectSL.ColorBackground(clrYellow);
   
   // 禁用鼠标滚动（避免误操作）
   ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
   
   // 显示提示
   // Comment("【选择止损价格】\n请点击图表任意位置...\n(将自动磁吸到最近的High/Low)");
   
   ChartRedraw();
   PlaySound("tick.wav");
}

//+------------------------------------------------------------------+
//| 点击选择止盈按钮                                                  |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSelectTP(void)
{
   // 激活止盈选择模式
   g_priceSelectMode = MODE_SELECT_TP;
   g_lastButtonClickTime = GetTickCount();  // 记录时间戳（防穿透）
   
   // 视觉反馈：按钮高亮
   m_btnSelectTP.ColorBackground(clrYellow);
   
   // 禁用鼠标滚动（避免误操作）
   ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
   
   // 显示提示
   // Comment("【选择止盈价格】\n请点击图表任意位置...\n(将自动磁吸到最近的High/Low)");
   
   ChartRedraw();
   PlaySound("tick.wav");
}

//+------------------------------------------------------------------+
//| 设置止损价格（公共方法）                                          |
//+------------------------------------------------------------------+
void CTradePanel::SetStopLossPrice(double price)
{
   m_edtStopLoss.Text(DoubleToString(price, _Digits));
}

//+------------------------------------------------------------------+
//| 设置止盈价格（公共方法）                                          |
//+------------------------------------------------------------------+
void CTradePanel::SetTakeProfitPrice(double price)
{
   m_edtTakeProfit.Text(DoubleToString(price, _Digits));
}

//+------------------------------------------------------------------+
//| 设置挂单价格（公共方法）                                          |
//+------------------------------------------------------------------+
void CTradePanel::SetEntryPrice(double price)
{
   m_edtEntryPrice.Text(DoubleToString(price, _Digits));
}

//+------------------------------------------------------------------+
//| 重置选择按钮颜色（公共方法）                                      |
//+------------------------------------------------------------------+
void CTradePanel::ResetSelectButton(int mode)
{
   if(mode == MODE_SELECT_SL)
      m_btnSelectSL.ColorBackground(clrLightGray);
   else if(mode == MODE_SELECT_TP)
      m_btnSelectTP.ColorBackground(clrLightGray);
   else if(mode == MODE_SELECT_ENTRY)
      m_btnSelectEntry.ColorBackground(clrLightGray);
}
//#endregion

//+------------------------------------------------------------------+
//| 全局变量                                                          |
//+------------------------------------------------------------------+
CTradePanel  g_tradePanel;
COrdersPanel g_ordersPanel;
bool         g_ordersPanelVisible = false;  // 当前是否可见
bool         g_ordersCreated      = false;  // 是否已创建过（Create 只调用一次）
// bool        g_allowNextMouseMove = false; // 点击后允许下一次鼠标释放事件通过

//+------------------------------------------------------------------+
//| 全局常量：EA 对象命名前缀                                          |
//+------------------------------------------------------------------+
string EA_OBJECT_PREFIX = "KT_EA_Panel_";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // MQL5转换：ATR句柄在EA启动时创建，避免每次止损计算重复创建/释放指标。
   KT_InitIndicators();

   // 初始化Magic计数器全局变量Key（包含品种名，避免不同品种冲突）
   g_magicCounterKey = "KTarget_MagicCounter_" + _Symbol;
   
   // 检查并初始化Magic计数器
   if(!GlobalVariableCheck(g_magicCounterKey))
   {
      GlobalVariableSet(g_magicCounterKey, 1);
      LOG_INFO("初始化Magic计数器: " + g_magicCounterKey);
   }
   
   // 创建面板（宽400×高714：包含SL/TP清除按钮行）
   if(!g_tradePanel.Create(0,"TradePanelEA",0,PanelX,PanelY,PanelX+400,PanelY+714))
   {
      LOG_ERROR("创建交易面板失败!");
      return(INIT_FAILED);
   }
   
   // 运行面板
   g_tradePanel.Run();
   
   LOG_INFO("交易面板EA已启动");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // MQL5转换：释放OnInit创建的ATR句柄。
   KT_ReleaseIndicators();

   // 清理EA止损标签
   CleanupEA_SL_Labels();
   
   // === 【修复】切换周期前强制最大化，确保重建时状态正确 ===
   g_tradePanel.ForceMaximize();
   
   // === 【重要】保存输入框值到成员变量（即使是图表切换也要保存） ===
   g_tradePanel.SaveInputValues();
   
   // 销毁面板（OnDeinit 时 EA 本身已在退出，不会再处理图表事件，无级联风险）
   if(g_ordersCreated)
   {
      g_ordersPanel.Destroy(reason);
      g_ordersCreated      = false;
      g_ordersPanelVisible = false;
   }
   g_tradePanel.Destroy(reason);
   LOG_INFO("交易面板EA已停止");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 更新信息容器（每次tick刷新数据）
   static datetime lastUpdate = 0;
   if(TimeCurrent() != lastUpdate)  // 每秒最多更新一次
   {
      g_tradePanel.UpdateInfoContainers();
      UpdateLiquidationLines();         // 更新爆仓线 & 浮亏警戒线
      lastUpdate = TimeCurrent();
   }
   
   // 自动减仓节流优化：每秒最多检查1次（避免频繁扫描）
   static datetime lastScaleCheck = 0;
   if(TimeCurrent() != lastScaleCheck)
   {
      g_tradePanel.CheckAutoScaleOut();
      lastScaleCheck = TimeCurrent();
   }
   
   // 自动止损保护：每秒最多检查1次（避免频繁扫描）
   static datetime lastSlCheck = 0;
   if(TimeCurrent() != lastSlCheck)
   {
      g_tradePanel.CheckAutoStopLoss();
      lastSlCheck = TimeCurrent();
   }
   
   // 更新EA止损标签（实时显示）
   UpdateEA_SL_Display();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   /*
   // 每次有对象被点击，标记允许下一次鼠标释放事件通过
   // 原因：MQL4 Controls库的CButton是在收到鼠标释放(CHARTEVENT_MOUSE_MOVE sparam="0")
   // 之后才真正触发ON_CLICK(id=1000)，必须允许这个释放事件通过
   if(id == CHARTEVENT_OBJECT_CLICK)
      g_allowNextMouseMove = true;
   
   // 对于纯悬停移动事件(sparam="0"无按键按下)进行过滤
   if(id == CHARTEVENT_MOUSE_MOVE && sparam == "0")
   {
      if(!g_allowNextMouseMove)
         return; // 过滤纯悬停移动，避免触发控件重绘导致输入框闪烁
      g_allowNextMouseMove = false; // 允许过一次后重置，下次继续过滤
   }
   
   // sparam!="0"的鼠标移动（拖拽面板）正常传递
   g_tradePanel.ChartEvent(id,lparam,dparam,sparam);
   */

   // === [NEW] 处理图表点击事件（价格选择） ===
   if(id == CHARTEVENT_CLICK && g_priceSelectMode != MODE_NONE)
   {
      // 防穿透：如果距离按钮点击时间不到300ms，忽略
      if(GetTickCount() - g_lastButtonClickTime < 300)
         return;
      
      // 获取点击位置的价格
      datetime time;
      double price;
      int sub_window;
      
      if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, sub_window, time, price))
      {
         double finalPrice = price;  // 默认使用原始点击价格
         
         // === 可选：磁吸到最近的High/Low（提升精度） ===
         if(g_enablePriceSnapping)
         {
            int barIndex = iBarShift(NULL, 0, time);
            double high = iHigh(NULL, 0, barIndex);
            double low = iLow(NULL, 0, barIndex);
            
            // 简单磁吸：选最近的High或Low
            if(MathAbs(price - high) < MathAbs(price - low))
               finalPrice = high;
            else
               finalPrice = low;
         }
         
         // 填入对应的输入框（使用公共方法）
         if(g_priceSelectMode == MODE_SELECT_SL)
         {
            g_tradePanel.SetStopLossPrice(finalPrice);
            g_tradePanel.ResetSelectButton(MODE_SELECT_SL);
         }
         else if(g_priceSelectMode == MODE_SELECT_TP)
         {
            g_tradePanel.SetTakeProfitPrice(finalPrice);
            g_tradePanel.ResetSelectButton(MODE_SELECT_TP);
         }
         else if(g_priceSelectMode == MODE_SELECT_ENTRY)
         {
            g_tradePanel.SetEntryPrice(finalPrice);
            g_tradePanel.ResetSelectButton(MODE_SELECT_ENTRY);
         }
         
         // 退出选择模式
         g_priceSelectMode = MODE_NONE;
         Comment("");  // 清除提示
         ChartSetInteger(0, CHART_MOUSE_SCROLL, true);  // 恢复滚动
         
         PlaySound("ok.wav");  // 音效反馈
         ChartRedraw();
      }
      
      return;  // 不再传递给面板
   }
   
   // === 传递事件给面板处理（原有逻辑） ===
   g_tradePanel.ChartEvent(id,lparam,dparam,sparam);
   if(g_ordersCreated && g_ordersPanelVisible)
      g_ordersPanel.ChartEvent(id,lparam,dparam,sparam);
}
//+------------------------------------------------------------------+

//#region MARK: 模块--爆仓线 & 浮亏警戒线
//+------------------------------------------------------------------+
//| [爆仓线] 更新爆仓线 & 浮亏警戒线（每秒调用一次）                  |
//+------------------------------------------------------------------+
void UpdateLiquidationLines()
{
   if(!Show_Liquidation_Line && !Show_Drawdown_Lines) return;

   string pfx = EA_OBJECT_PREFIX + "Liq_";  // "KT_EA_Panel_Liq_"

   //--- 1. 扫描当前品种持仓 ---
   double netBuyLots  = 0.0, netSellLots = 0.0;
   double wSumBuy     = 0.0, wSumSell    = 0.0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol)                   continue;
      if(OrderType() == OP_BUY)
      {
         netBuyLots += OrderLots();
         wSumBuy    += OrderLots() * OrderOpenPrice();
      }
      else if(OrderType() == OP_SELL)
      {
         netSellLots += OrderLots();
         wSumSell    += OrderLots() * OrderOpenPrice();
      }
   }

   //--- 无持仓：删除所有爆仓线对象 ---
   if(netBuyLots == 0.0 && netSellLots == 0.0)
   {
      for(int i = ObjectsTotal() - 1; i >= 0; i--)
      {
         string n = ObjectName(i);
         if(StringFind(n, pfx) == 0) ObjectDelete(0, n);
      }
      return;
   }

   //--- 2. 账户参数 ---
   // 旧代码保留：美分账户中 AccountBalance() 与 contractSize 可能不在同一金额单位。
   // double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double tickValue    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize     = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double balance      = AccountBalance();
   double usedMargin   = AccountMargin();

   // 经纪商爆仓触发最低权益（兼容百分比模式和金额模式，兼容无限杠杆）
   double safeEquity;
   if(AccountStopoutMode() == 0)   // 百分比模式（常见）
      safeEquity = (usedMargin > 0.001) ? (usedMargin * AccountStopoutLevel() / 100.0) : 0.0;
   else                             // 金额模式（部分经纪商）
      safeEquity = AccountStopoutLevel();

   double maxLoss = balance - safeEquity;
   if(maxLoss <= 0) maxLoss = balance;  // 兜底：保证金为零时用全部余额

   //--- 3. 净合约量 & 加权开仓价 ---
   double netLots  = netBuyLots - netSellLots;
   // 旧代码保留：
   // double netValue = netLots * contractSize;
   // 使用经纪商返回的点值，使账户金额单位（包括美分账户）保持一致。
   double priceValuePerLot;
   if(tickValue > 0.0 && tickSize > 0.0)
      priceValuePerLot = tickValue / tickSize;
   else
   {
      LOG_WARNING("爆仓线点值无效，回退合约大小公式: TickValue=" +
                  DoubleToString(tickValue, 8) + " TickSize=" +
                  DoubleToString(tickSize, 8));
      priceValuePerLot = contractSize;
   }
   double netValue = netLots * priceValuePerLot;

   // 净仓为零（完全对冲）：无法计算单一爆仓方向，删旧线退出
   if(MathAbs(netValue) < 0.000001)
   {
      for(int i = ObjectsTotal() - 1; i >= 0; i--)
      {
         string n = ObjectName(i);
         if(StringFind(n, pfx) == 0) ObjectDelete(0, n);
      }
      return;
   }

   double avgOpenPrice;
   if(netLots > 0)      avgOpenPrice = wSumBuy  / netBuyLots;
   else if(netLots < 0) avgOpenPrice = wSumSell / netSellLots;
   else                 avgOpenPrice = (wSumBuy + wSumSell) / (netBuyLots + netSellLots);

   //--- 4. 计算各警戒线价位 ---
   // dir=+1 净多头：价格下跌亏损，爆仓线在开仓价下方
   // dir=-1 净空头：价格上涨亏损，爆仓线在开仓价上方
   double dir    = (netValue > 0) ? 1.0 : -1.0;
   double absNV  = MathAbs(netValue);

   // 旧代码保留：
   // double liqPrice   = avgOpenPrice - dir * (maxLoss                           / absNV);
   // double loss1Price = avgOpenPrice - dir * (balance * Drawdown_Level1 / 100.0 / absNV);
   // double loss2Price = avgOpenPrice - dir * (balance * Drawdown_Level2 / 100.0 / absNV);
   double liqPrice   = avgOpenPrice - dir * (maxLoss                           / absNV);
   double loss1Price = avgOpenPrice - dir * (balance * Drawdown_Level1 / 100.0 / absNV);
   double loss2Price = avgOpenPrice - dir * (balance * Drawdown_Level2 / 100.0 / absNV);

   //--- 5. 绘制/更新图形对象 ---
   if(Show_Liquidation_Line)
      LiqDrawLevel(pfx + "Main", liqPrice, clrRed, 2, STYLE_SOLID,
                   StringFormat("<< 爆仓 %.2f", liqPrice));
   else
   {
      ObjectDelete(0, pfx + "Main_L");
      ObjectDelete(0, pfx + "Main_T");
   }

   if(Show_Drawdown_Lines)
   {
      LiqDrawLevel(pfx + "L1", loss1Price, clrOrange,     1, STYLE_DASH,
                   StringFormat("<< 浮亏%.0f%% %.2f", Drawdown_Level1, loss1Price));
      LiqDrawLevel(pfx + "L2", loss2Price, clrDarkOrange,  1, STYLE_DASH,
                   StringFormat("<< 浮亏%.0f%% %.2f", Drawdown_Level2, loss2Price));
   }
   else
   {
      ObjectDelete(0, pfx + "L1_L"); ObjectDelete(0, pfx + "L1_T");
      ObjectDelete(0, pfx + "L2_L"); ObjectDelete(0, pfx + "L2_T");
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| [爆仓线] 绘制或更新一条水平线 + 文字标签                          |
//| 对象命名规则：baseName + "_L"(线) / baseName + "_T"(文字)        |
//| 所有对象以 EA_OBJECT_PREFIX("KT_EA_Panel_") 为前缀，              |
//| OnDeinit 时由 CleanupEA_SL_Labels() 统一回收，无需额外清理代码。  |
//+------------------------------------------------------------------+
void LiqDrawLevel(const string baseName, double price,
                  color clr, int width, int lineStyle, const string labelText)
{
   string lineName  = baseName + "_L";
   string labelName = baseName + "_T";

   // --- 水平线 ---
   if(ObjectFind(0, lineName) == -1)
   {
      ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR,      clr);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE,      lineStyle);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH,      width);
      ObjectSetInteger(0, lineName, OBJPROP_BACK,       true);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   }
   else
      ObjectSetDouble(0, lineName, OBJPROP_PRICE, 0, price);

   // --- 文字标签（定位在最近K线处，随行情推进每秒更新一次）---
   // 旧代码保留：datetime t = (Bars > 3) ? Time[3] : Time[MathMax(Bars - 1, 0)];
   datetime t = (KT_Bars() > 3) ? KT_TimeAt(3) : KT_TimeAt(MathMax(KT_Bars() - 1, 0));
   if(ObjectFind(0, labelName) == -1)
   {
      ObjectCreate(0, labelName, OBJ_TEXT, 0, t, price);
      ObjectSetString (0, labelName, OBJPROP_TEXT,      labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR,     clr);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE,  8);
      ObjectSetString (0, labelName, OBJPROP_FONT,      "Arial Bold");
      ObjectSetInteger(0, labelName, OBJPROP_BACK,      false);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE,false);
   }
   else
   {
      ObjectSetDouble (0, labelName, OBJPROP_PRICE, 0, price);
      ObjectSetString (0, labelName, OBJPROP_TEXT,  labelText);
      ObjectSetInteger(0, labelName, OBJPROP_TIME,  0, t);
   }
}
//#endregion

//#region MARK: 模块--止损标签
//+------------------------------------------------------------------+
//| 更新EA止损标签（实时显示现价±5美金的止损位置）                    |
//+------------------------------------------------------------------+
void UpdateEA_SL_Display()
{
   if(!Show_EA_SL_Labels) return; // 用户关闭功能
   
   // 1. 计算止损价格（现价 ± SL_Distance_Dollars 美金）
   double current_price = (Bid + Ask) / 2.0;
   double sl_distance = SL_Distance_Dollars;
   
   // 应用偏移量避免与指标重叠
   double buy_sl_price = current_price - sl_distance - Label_Offset;  // 做多止损（下方）
   double sell_sl_price = current_price + sl_distance + Label_Offset; // 做空止损（上方）
   
   // 旧代码保留：datetime current_time = Time[0]; // 当前K线时间
   datetime current_time = KT_TimeAt(0); // MQL5通过iTime读取当前K线时间
   
   // 2. 创建/更新 Buy SL 标签（做多止损，显示在下方）
   string buy_label_name = EA_OBJECT_PREFIX + "Buy_SL_Label";
   if(ObjectFind(0, buy_label_name) == -1)
   {
      // 首次创建
      ObjectCreate(0, buy_label_name, OBJ_ARROW_RIGHT_PRICE, 0, current_time, buy_sl_price);
      ObjectSetInteger(0, buy_label_name, OBJPROP_COLOR, Buy_SL_Color);
      ObjectSetInteger(0, buy_label_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, buy_label_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, buy_label_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, buy_label_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, buy_label_name, OBJPROP_HIDDEN, true);
   }
   else
   {
      // 更新位置
      ObjectSetInteger(0, buy_label_name, OBJPROP_TIME, 0, current_time);
      ObjectSetDouble(0, buy_label_name, OBJPROP_PRICE, 0, buy_sl_price);
   }
   
   // 3. 创建/更新 Sell SL 标签（做空止损，显示在上方）
   string sell_label_name = EA_OBJECT_PREFIX + "Sell_SL_Label";
   if(ObjectFind(0, sell_label_name) == -1)
   {
      // 首次创建
      ObjectCreate(0, sell_label_name, OBJ_ARROW_RIGHT_PRICE, 0, current_time, sell_sl_price);
      ObjectSetInteger(0, sell_label_name, OBJPROP_COLOR, Sell_SL_Color);
      ObjectSetInteger(0, sell_label_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, sell_label_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, sell_label_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, sell_label_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, sell_label_name, OBJPROP_HIDDEN, true);
   }
   else
   {
      // 更新位置
      ObjectSetInteger(0, sell_label_name, OBJPROP_TIME, 0, current_time);
      ObjectSetDouble(0, sell_label_name, OBJPROP_PRICE, 0, sell_sl_price);
   }
}

//+------------------------------------------------------------------+
//| 清理EA止损标签                                                    |
//+------------------------------------------------------------------+
void CleanupEA_SL_Labels()
{
   // 删除所有以 EA_OBJECT_PREFIX 开头的对象（含爆仓线，因其也使用同一前缀）
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
   {
      string obj_name = ObjectName(i);
      if(StringFind(obj_name, EA_OBJECT_PREFIX) == 0) // 检查前缀
      {
         ObjectDelete(0, obj_name);
      }
   }
}
//#endregion