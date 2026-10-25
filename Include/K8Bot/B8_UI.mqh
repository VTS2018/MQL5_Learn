//====================================================================
// 文件作用：KTarget_FinderBot8 的面板、控件、参数编辑和图表事件辅助逻辑。
// 本文件原样承载主文件中的用户界面逻辑。
//====================================================================

//#region MARK: 通用控件创建1
//====================================================================
// 面板底层辅助函数: B8_MakeRectLabel
// 创建或更新矩形背景标签 (CORNER_RIGHT_LOWER)
//====================================================================
void B8_MakeRectLabel(string name,
                      int xdist, int ydist, int w, int h,
                      color bg,  color border)
{
    if (ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

    ObjectSetInteger(0, name, OBJPROP_CORNER,      CORNER_RIGHT_LOWER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE,   xdist);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE,   ydist);
    ObjectSetInteger(0, name, OBJPROP_XSIZE,        w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE,        h);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR,      bg);
    ObjectSetInteger(0, name, OBJPROP_COLOR,        border);
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE,  BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE,   false);
    ObjectSetInteger(0, name, OBJPROP_BACK,         false); // 前景层，遮挡面板后方K线
}

//====================================================================
// 面板底层辅助函数: B8_MakeButton
// 创建或更新可点击按钮 (CORNER_RIGHT_LOWER)
//====================================================================
void B8_MakeButton(string name,
                   int xdist, int ydist, int w, int h,
                   string text, color bg, color txt)
{
    if (ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);

    ObjectSetInteger(0, name, OBJPROP_CORNER,    CORNER_RIGHT_LOWER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xdist);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, ydist);
    ObjectSetInteger(0, name, OBJPROP_XSIZE,      w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE,      h);
    ObjectSetString (0, name, OBJPROP_TEXT,       text);
    ObjectSetInteger(0, name, OBJPROP_COLOR,      txt);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    bg);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   9);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_STATE,      false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER,     10);
}

//====================================================================
// 面板底层辅助函数: B8_MakeEdit
// 创建或更新参数输入框 (CORNER_RIGHT_LOWER)
//====================================================================
void B8_MakeEdit(string name,
                 int xdist, int ydist, int w, int h,
                 string text)
{
    if (ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);

    ObjectSetInteger(0, name, OBJPROP_CORNER,      CORNER_RIGHT_LOWER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE,   xdist);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE,   ydist);
    ObjectSetInteger(0, name, OBJPROP_XSIZE,        w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE,        h);
    ObjectSetString (0, name, OBJPROP_TEXT,         text);
    ObjectSetInteger(0, name, OBJPROP_COLOR,        C'25,30,40');
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR,      C'235,238,242');
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'90,110,135');
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,     9);
    ObjectSetInteger(0, name, OBJPROP_READONLY,     false);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE,   false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER,       10);
}

//====================================================================
// 面板底层辅助函数: B8_MakeLabel
// 创建或更新文字标签 (CORNER_RIGHT_LOWER, ANCHOR_RIGHT_LOWER)
// 注意：文字从 (xdist, ydist) 点向左延伸
//====================================================================
void B8_MakeLabel(string name,
                  int xdist, int ydist,
                  string text, color txt, int fontsize)
{
    if (ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

    ObjectSetInteger(0, name, OBJPROP_CORNER,    CORNER_RIGHT_LOWER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xdist);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, ydist);
    ObjectSetString (0, name, OBJPROP_TEXT,      text);
    ObjectSetInteger(0, name, OBJPROP_COLOR,     txt);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  fontsize);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR,    ANCHOR_LEFT); // 文字从左边缘向右延伸
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
}
void B8_SetCustomFibPickObjectVisibility(bool visible)
{
    long value = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_VLINE, OBJPROP_TIMEFRAMES, value);
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_HLINE, OBJPROP_TIMEFRAMES, value);
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_LABEL, OBJPROP_TIMEFRAMES, value);
}

void B8_CreateCustomFibPickObjects()
{
    if (ObjectFind(0, B8_CUSTOM_FIB_PICK_VLINE) < 0)
        ObjectCreate(0, B8_CUSTOM_FIB_PICK_VLINE, OBJ_VLINE, 0, TimeCurrent(), 0.0);
    if (ObjectFind(0, B8_CUSTOM_FIB_PICK_HLINE) < 0)
        ObjectCreate(0, B8_CUSTOM_FIB_PICK_HLINE, OBJ_HLINE, 0, 0, Bid);
    if (ObjectFind(0, B8_CUSTOM_FIB_PICK_LABEL) < 0)
        ObjectCreate(0, B8_CUSTOM_FIB_PICK_LABEL, OBJ_LABEL, 0, 0, 0);

    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_VLINE, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_VLINE, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_VLINE, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_HLINE, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_HLINE, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_HLINE, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_LABEL, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_LABEL, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_LABEL, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_LABEL, OBJPROP_FONTSIZE, 9);
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_LABEL, OBJPROP_SELECTABLE, false);

    ObjectSetString(0, B8_CUSTOM_FIB_PICK_VLINE, OBJPROP_TOOLTIP, "\n");
    ObjectSetString(0, B8_CUSTOM_FIB_PICK_HLINE, OBJPROP_TOOLTIP, "\n");
    ObjectSetString(0, B8_CUSTOM_FIB_PICK_LABEL, OBJPROP_TOOLTIP, "\n");

    B8_SetCustomFibPickObjectVisibility(false);
}

void B8_StartCustomFibPricePick(ENUM_B8_PRICE_PICK_MODE mode)
{
    B8_CreateCustomFibPickObjects();
    g_Custom_Fib_Pick_Mode = mode;
    g_Custom_Fib_Pick_Preview_Price = 0.0;
    g_Custom_Fib_Last_Button_Click = GetTickCount();
    ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
    ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
    B8_SetCustomFibPickObjectVisibility(true);
    g_Custom_Fib_Status_Message = (mode == B8_PRICE_PICK_ENTRY)
                                  ? "请在主图点击入场价"
                                  : "请在主图点击止损价";
    g_Custom_Fib_Panels_Hidden = true;
    B8_SetCorePanelsVisible(false);
    B8_UpdateCustomFibPanel();
    Comment("[Bot8] ", g_Custom_Fib_Status_Message, "（不磁吸K线）");
    ChartRedraw();
}

void B8_CancelCustomFibPricePick()
{
    g_Custom_Fib_Pick_Mode = B8_PRICE_PICK_NONE;
    g_Custom_Fib_Pick_Preview_Price = 0.0;
    ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
    B8_SetCustomFibPickObjectVisibility(false);
    if (g_Custom_Fib_Panels_Hidden)
    {
        g_Custom_Fib_Panels_Hidden = false;
        B8_SetCorePanelsVisible(true);
    }
    Comment("");
    ChartRedraw();
}

bool B8_UpdateCustomFibPickPreview(int x, int y)
{
    if (g_Custom_Fib_Pick_Mode == B8_PRICE_PICK_NONE)
        return false;
    int sub_window = 0;
    datetime time = 0;
    double price = 0.0;
    if (!ChartXYToTimePrice(0, x, y, sub_window, time, price) || sub_window != 0)
        return false;
    price = NormalizeDouble(price, _Digits);
    g_Custom_Fib_Pick_Preview_Price = price;
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_VLINE, OBJPROP_TIME, time);
    ObjectSetDouble(0, B8_CUSTOM_FIB_PICK_HLINE, OBJPROP_PRICE, price);
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_LABEL, OBJPROP_XDISTANCE, x + 12);
    ObjectSetInteger(0, B8_CUSTOM_FIB_PICK_LABEL, OBJPROP_YDISTANCE, y + 12);
    ObjectSetString(0, B8_CUSTOM_FIB_PICK_LABEL, OBJPROP_TEXT,
                    "价格 " + DoubleToString(price, _Digits));
    ChartRedraw();
    return true;
}

bool B8_HandleCustomFibPricePickEvent(const int id, const long &lparam,
                                      const double &dparam)
{
    if (g_Custom_Fib_Pick_Mode == B8_PRICE_PICK_NONE)
        return false;
    if (id == CHARTEVENT_MOUSE_MOVE)
    {
        B8_UpdateCustomFibPickPreview((int)lparam, (int)dparam);
        return true;
    }
    if (id != CHARTEVENT_CLICK)
        return false;
    if (!B8_UpdateCustomFibPickPreview((int)lparam, (int)dparam))
        return true;

    double selected_price = g_Custom_Fib_Pick_Preview_Price;
    if (g_Custom_Fib_Pick_Mode == B8_PRICE_PICK_ENTRY)
    {
        g_Custom_Fib_Entry_Price = selected_price;
        ObjectSetString(0, B8_CUSTOM_FIB_ENTRY_EDIT, OBJPROP_TEXT,
                        DoubleToString(selected_price, _Digits));
    }
    else
    {
        g_Custom_Fib_Stop_Price = selected_price;
        ObjectSetString(0, B8_CUSTOM_FIB_STOP_EDIT, OBJPROP_TEXT,
                        DoubleToString(selected_price, _Digits));
    }
    g_Custom_Fib_Status_Message = "图表价格已选取";
    B8_CancelCustomFibPricePick();
    B8_UpdateCustomFibPanel();
    ChartRedraw();
    return true;
}
//#endregion

//#region MARK: 通用控件创建2
// 创建或更新订单策略面板中的文字标签。
void B8_RuntimeOrderMakeLabel(string name, int x, int y,
                              string text, color txt, int size)
{
    if (ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, txt);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 20);
}

// 创建或更新订单策略面板中的按钮控件。
void B8_RuntimeOrderMakeButton(string name, int x, int y, int w, int h,
                               string text, color bg)
{
    if (ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);

    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_STATE, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 25);
}

// 创建或更新订单策略面板中的可编辑输入框。
void B8_RuntimeOrderMakeEdit(string name, int x, int y, int w, int h,
                             string text)
{
    if (ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);

    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, C'25,30,40');
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'235,238,242');
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'90,110,135');
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, name, OBJPROP_READONLY, false);
    // 输入框保持可编辑，但禁止图表对象拖动；这是项目现有 B8_MakeEdit 的工作属性。
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 25);
}
//#endregion

//#region MARK: 模块--主面板
//====================================================================
// 面板函数: B8_CreatePanel
// 在图表右下角创建交互控制面板
//
// !! 坐标系关键说明 (CORNER_RIGHT_LOWER) !!
//   OBJ_RECTANGLE_LABEL / OBJ_BUTTON 的锚点永远是对象的左上角。
//   XDISTANCE = 图表右边缘 到 对象【左】边缘 的距离 (px)
//   YDISTANCE = 图表下边缘 到 对象【上】边缘 的距离 (px)
//   对象从锚点向右、向下延伸 (XSIZE / YSIZE)。
//
//   因此，要让对象贴近右下角：
//     XDISTANCE = 右边距 + 对象宽度
//     YDISTANCE = 下边距 + 对象高度
//
// 面板布局 (各按钮上边缘距图表底部的距离，从下向上):
//   YDIST=35  : [普通模式] 按钮上边缘  (高度25, 底部在10px)
//   YDIST=65  : [只多/只空] 按钮上边缘 (高度25, 底部在40px)
//   YDIST=95  : [开启/关闭] 按钮上边缘 (高度25, 底部在70px)
//   YDIST=110 : 标题文字中线 (槽位100~120px的中心)
//   YDIST=120 : 面板背景上边缘 (高度115, 底部在5px)
//====================================================================
void B8_CreatePanel()
{
    // ── 布局常量 ──
    const int R_MARGIN = 5;    // 面板距图表右边缘
    const int B_MARGIN = 5;    // 面板距图表下边缘
    const int PAN_W    = 240;  // 与参数面板保持相同宽度
    const int PAN_H    = 170;  // 面板总高度：增加入场方式快速切换行
    const int PAD      = 10;   // 面板内边距
    const int BTN_W    = PAN_W - PAD * 2; // 全宽按钮 = 220px
    const int BTN_H    = 25;   // 按钮高度
    const int ROW_GAP  = 5;    // 行间距

    // 各行【上边缘】距图表下边缘的距离 (YDISTANCE = 下边距 + 高度)
    // 行底部距离 = B_MARGIN + ROW_GAP + 累加
    const int ROW1_TOP = B_MARGIN + ROW_GAP * 2 + BTN_H;           // 35px
    const int ROW2_TOP = ROW1_TOP + ROW_GAP + BTN_H;           // 65px
    const int ROW3_TOP = ROW2_TOP + ROW_GAP + BTN_H;           // 95px，开启/关闭
    const int ROW4_TOP = ROW3_TOP + ROW_GAP + BTN_H;           // 125px，入场方式
    const int TITLE_MID = ROW4_TOP + ROW_GAP + 10;            // 165px (标题槽位155~175px的中心)
    const int PAN_TOP   = B_MARGIN + PAN_H;                    // 175px (面板上边缘)

    // 全宽按钮/面板的 XDISTANCE (= 右边距 + 各自宽度)
    const int PAN_XDIST = R_MARGIN + PAN_W;  // 245px
    const int BTN_XDIST = R_MARGIN + PAD + BTN_W; // 235px (按钮左边缘)

    // ── 面板背景 ──
    B8_MakeRectLabel(B8_PANEL_BG,
                     PAN_XDIST, PAN_TOP,     // xdist=245, ydist=175
                     PAN_W, PAN_H,
                     C'25,30,45',
                     C'60,90,140');

    // ── 标题标签 (ANCHOR_LEFT: 文字从左边缘向右延伸) ──
    B8_MakeLabel(B8_PANEL_TITLE,
                 BTN_XDIST,   // 左边缘与按钮对齐 (205px)
                 TITLE_MID,   // 文字中线高度
                 "KTarget FinderBot8",
                 C'140,170,210', 8);

    // 标题栏右侧常驻入口：显示或隐藏完整参数面板，不占用新的按钮行。
    B8_MakeButton(B8_BTN_SETTINGS_VISIBILITY,
                  R_MARGIN + PAD + 55, 157,
                  55, 25,
                  "隐藏", clrSteelBlue, clrWhite);

    // ── [开启/关闭] 按钮 (行3) ──
    B8_MakeButton(B8_BTN_ENABLE,
                  BTN_XDIST, ROW4_TOP,
                  BTN_W, BTN_H,
                  "开 启", clrDimGray, clrWhite);

    // ── 入场方式按钮 (行4，位于开启/关闭行正上方) ──
    // 三个按钮只改变后续新信号的入口，不自动处理已有订单。
    int entry_w = (BTN_W - ROW_GAP * 2) / 3;
    B8_MakeButton(B8_BTN_ENTRY_MARKET, BTN_XDIST, ROW3_TOP,
                  entry_w, BTN_H, "市价", clrDimGray, clrWhite);
    B8_MakeButton(B8_BTN_ENTRY_PENDING, BTN_XDIST - entry_w - ROW_GAP, ROW3_TOP,
                  entry_w, BTN_H, "挂单", clrDimGray, clrWhite);
    B8_MakeButton(B8_BTN_ENTRY_BOTH, BTN_XDIST - (entry_w + ROW_GAP) * 2, ROW3_TOP,
                  entry_w, BTN_H, "市价+挂单", clrDimGray, clrWhite);

    // ── [只多模式] [只空模式] 按钮 (行2, 各占约一半宽度) ──
    int half_w = (BTN_W - ROW_GAP) / 2; // (220-5)/2 = 107px

    // [只多模式] — 视觉上在左侧 (XDISTANCE 较大 → 更靠左)
    B8_MakeButton(B8_BTN_BUY_ONLY,
                  BTN_XDIST,              // xdist=235 → 左侧
                  ROW2_TOP,
                  half_w, BTN_H,
                  "只多模式", clrDimGray, clrWhite);

    // [只空模式] — 视觉上在右侧 (XDISTANCE 较小 → 更靠右)
    // 右按钮左边缘 = 左按钮右边缘 + 间隙 = (235-107) - 5 = 123px
    B8_MakeButton(B8_BTN_SELL_ONLY,
                  BTN_XDIST - half_w - ROW_GAP, // 235-107-5=123 → 右侧
                  ROW2_TOP,
                  half_w, BTN_H,
                  "只空模式", clrDimGray, clrWhite);

    // ── [普通模式] 按钮 (行1, 底部) ──
    B8_MakeButton(B8_BTN_NORMAL,
                  BTN_XDIST, ROW1_TOP,
                  BTN_W, BTN_H,
                  "普通模式", clrDeepSkyBlue, clrWhite);

    // B8_CreateSettingsPanel(); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
    // B8_CreateRiskPanel(); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
    // B8_SetSettingsPanelVisible(g_SettingsPanelVisible); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
    // B8_UpdatePanel(); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
    // ChartRedraw(); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
}

//====================================================================
// 面板函数: B8_UpdatePanel
// 根据当前 g_EA_Enabled 和 g_Trade_Mode 更新按钮颜色与文字
//====================================================================
void B8_UpdatePanel()
{
    // 颜色方案
    const color CLR_ACTIVE   = clrDeepSkyBlue; // 激活状态背景
    const color CLR_INACTIVE = clrDimGray;     // 未激活状态背景
    const color CLR_ENABLED  = clrForestGreen; // EA 开启背景
    const color CLR_DISABLED = clrDimGray;     // EA 关闭背景
    const color CLR_TXT      = clrWhite;       // 按钮文字

    // ── [开启/关闭] 按钮 ──
    if (g_EA_Enabled)
    {
        ObjectSetInteger(0, B8_BTN_ENABLE, OBJPROP_BGCOLOR, CLR_ENABLED);
        ObjectSetString (0, B8_BTN_ENABLE, OBJPROP_TEXT,    "关 闭");
    }
    else
    {
        ObjectSetInteger(0, B8_BTN_ENABLE, OBJPROP_BGCOLOR, CLR_DISABLED);
        ObjectSetString (0, B8_BTN_ENABLE, OBJPROP_TEXT,    "开 启");
    }

    // ── 三个模式按钮：当前激活的高亮显示 ──
    ObjectSetInteger(0, B8_BTN_NORMAL,    OBJPROP_BGCOLOR,
                     (g_Trade_Mode == B8_MODE_NORMAL)    ? CLR_ACTIVE : CLR_INACTIVE);
    ObjectSetInteger(0, B8_BTN_BUY_ONLY,  OBJPROP_BGCOLOR,
                     (g_Trade_Mode == B8_MODE_BUY_ONLY)  ? CLR_ACTIVE : CLR_INACTIVE);
    ObjectSetInteger(0, B8_BTN_SELL_ONLY, OBJPROP_BGCOLOR,
                     (g_Trade_Mode == B8_MODE_SELL_ONLY) ? CLR_ACTIVE : CLR_INACTIVE);

    // 入场方式按钮：高亮当前运行模式，避免快速切换后状态不明确。
    ObjectSetInteger(0, B8_BTN_ENTRY_MARKET, OBJPROP_BGCOLOR,
                     (g_Runtime_Entry_Mode == B8_ENTRY_MARKET) ? CLR_ACTIVE : CLR_INACTIVE);
    ObjectSetInteger(0, B8_BTN_ENTRY_PENDING, OBJPROP_BGCOLOR,
                     (g_Runtime_Entry_Mode == B8_ENTRY_PENDING) ? CLR_ACTIVE : CLR_INACTIVE);
    ObjectSetInteger(0, B8_BTN_ENTRY_BOTH, OBJPROP_BGCOLOR,
                     (g_Runtime_Entry_Mode == B8_ENTRY_MARKET_AND_PENDING) ? CLR_ACTIVE : CLR_INACTIVE);

    // B8_UpdateSettingsPanel(); // 已迁移到各调用点，原调用保留供回溯
}
//#endregion

//#region MARK: 模块--风险面板
void B8_UpdateRiskPanel()
{
    if (ObjectFind(0, B8_RISK_PANEL_BG) < 0) return;

    double tick_size = MarketInfo(_Symbol, MODE_TICKSIZE);
    double tick_value = MarketInfo(_Symbol, MODE_TICKVALUE);
    double value_per_price_per_lot = 0.0;
    if (tick_size > 0.0 && tick_value > 0.0)
        value_per_price_per_lot = tick_value / tick_size;

    double total_risk = 0.0;
    double buy_risk = 0.0;
    double sell_risk = 0.0;
    double remaining_risk = 0.0;
    double buy_points = 0.0;
    double sell_points = 0.0;
    int buy_count = 0;
    int sell_count = 0;
    int invalid_sl_count = 0;

    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsManagedOrder()) continue;

        int type = OrderType();
        if (type != OP_BUY && type != OP_SELL) continue;

        if (type == OP_BUY) buy_count++;
        else sell_count++;

        double open_price = OrderOpenPrice();
        double stop_loss = OrderStopLoss();
        double adverse_distance = (type == OP_BUY)
                                   ? open_price - stop_loss
                                   : stop_loss - open_price;
        if (stop_loss <= 0.0 || adverse_distance <= 0.0 ||
            value_per_price_per_lot <= 0.0)
        {
            invalid_sl_count++;
            continue;
        }

        double lots = OrderLots();
        double order_risk = adverse_distance * value_per_price_per_lot * lots;
        double order_points = adverse_distance / Point();
        total_risk += order_risk;

        if (type == OP_BUY)
        {
            buy_risk += order_risk;
            buy_points += order_points;
        }
        else
        {
            sell_risk += order_risk;
            sell_points += order_points;
        }

        double current_price = (type == OP_BUY) ? Bid : Ask;
        double remaining_distance = (type == OP_BUY)
                                    ? current_price - stop_loss
                                    : stop_loss - current_price;
        if (remaining_distance > 0.0)
            remaining_risk += remaining_distance * value_per_price_per_lot * lots;
    }

    double balance = AccountBalance();
    double equity = AccountEquity();
    double balance_percent = (balance > 0.0) ? total_risk / balance * 100.0 : 0.0;
    double equity_percent = (equity > 0.0) ? total_risk / equity * 100.0 : 0.0;
    double equity_after_stop = equity - total_risk;
    string currency = AccountCurrency();

    ObjectSetString(0, B8_RISK_LINE1, OBJPROP_TEXT,
                    "止损预估: -" + currency + " " + DoubleToString(total_risk, 2));
    ObjectSetString(0, B8_RISK_LINE2, OBJPROP_TEXT,
                    "多头: -" + currency + " " + DoubleToString(buy_risk, 2) +
                    " | 空头: -" + currency + " " + DoubleToString(sell_risk, 2));
    ObjectSetString(0, B8_RISK_LINE3, OBJPROP_TEXT,
                    "当前到止损: -" + currency + " " + DoubleToString(remaining_risk, 2));
    ObjectSetString(0, B8_RISK_LINE4, OBJPROP_TEXT,
                    "止损点数: 多 " + DoubleToString(buy_points, 0) +
                    " | 空 " + DoubleToString(sell_points, 0));
    ObjectSetString(0, B8_RISK_LINE5, OBJPROP_TEXT,
                    "占余额: " + DoubleToString(balance_percent, 2) + "%" +
                    " | 净值: " + DoubleToString(equity_percent, 2) + "%");
    ObjectSetString(0, B8_RISK_LINE6, OBJPROP_TEXT,
                    "止损后净值: " + currency + " " + DoubleToString(equity_after_stop, 2));
    ObjectSetString(0, B8_RISK_LINE7, OBJPROP_TEXT,
                    "等级: " + B8_RiskLevelText(equity_percent) +
                    " | 持仓 多" + IntegerToString(buy_count) +
                    "/空" + IntegerToString(sell_count) +
                    (invalid_sl_count > 0 ? " | 无效SL:" + IntegerToString(invalid_sl_count) : ""));

    ObjectSetInteger(0, B8_RISK_LINE1, OBJPROP_COLOR,
                     equity_percent >= 5.0 ? clrOrangeRed : clrGold);
    ObjectSetInteger(0, B8_RISK_LINE7, OBJPROP_COLOR,
                     equity_percent >= 10.0 ? clrOrangeRed
                     : (equity_percent >= 5.0 ? clrOrange : clrLimeGreen));
}

void B8_CreateRiskPanel()
{
    const int SETTINGS_Y_GAP = 10;
    const int BG_X = 500;
    const int BG_Y = 175;
    const int BG_W = 240;
    const int BG_H = 170;
    const int LABEL_X = 490;

    B8_MakeRectLabel(B8_RISK_PANEL_BG, BG_X, BG_Y, BG_W, BG_H,
                     C'22,27,38', C'70,95,125');
    B8_MakeLabel(B8_RISK_PANEL_TITLE, LABEL_X, 170 - SETTINGS_Y_GAP,
                 "实时止损风险", clrWhite, 10);
    B8_MakeLabel(B8_RISK_LINE1, LABEL_X, 148 - SETTINGS_Y_GAP, "", clrGold, 8);
    B8_MakeLabel(B8_RISK_LINE2, LABEL_X, 130 - SETTINGS_Y_GAP, "", C'190,205,220', 8);
    B8_MakeLabel(B8_RISK_LINE3, LABEL_X, 112 - SETTINGS_Y_GAP, "", C'190,205,220', 8);
    B8_MakeLabel(B8_RISK_LINE4, LABEL_X, 94 - SETTINGS_Y_GAP, "", C'190,205,220', 8);
    B8_MakeLabel(B8_RISK_LINE5, LABEL_X, 76 - SETTINGS_Y_GAP, "", C'190,205,220', 8);
    B8_MakeLabel(B8_RISK_LINE6, LABEL_X, 58 - SETTINGS_Y_GAP, "", C'190,205,220', 8);
    B8_MakeLabel(B8_RISK_LINE7, LABEL_X, 40 - SETTINGS_Y_GAP, "", clrLimeGreen, 8);
    // B8_UpdateRiskPanel(); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
}
//#endregion

//#region MARK: 模块--运行参数面板
//====================================================================
// 参数面板：创建状态、编辑、预设区域
// 与底部四个主控按钮分离，便于后续继续增加 input 参数
//====================================================================
void B8_CreateSettingsPanel()
{
    // 标题行右侧预留折叠按钮槽位，后续可直接加入参数区展开/收起功能。
    // CORNER_RIGHT_LOWER坐标系中Y值越大越靠上，统一上移以避开扩高后的主面板。
    const int SETTINGS_Y_OFFSET = 83;
    const int BG_X = 245;
    const int BG_Y = 594 + SETTINGS_Y_OFFSET;
    const int BG_W = 240;
    const int BG_H = 500;
    const int LABEL_X = 235;
    const int FIELD_X = 151;
    const int FIELD_W = 136;
    const int FIELD_H = 22;
    const int HALF_W = 66;
    const int HALF_GAP = 4;
    const int PRESET_W = 70;
    const int PRESET_GAP = 5;

    B8_MakeRectLabel(B8_SETTINGS_BG, BG_X, BG_Y, BG_W, BG_H,
                     C'22,27,38', C'70,95,125');

    B8_MakeLabel(B8_SETTINGS_TITLE, LABEL_X, 579 + SETTINGS_Y_OFFSET,
                 "当前运行参数", clrWhite, 10);
    B8_MakeLabel(B8_STATUS_LINE1, LABEL_X, 558 + SETTINGS_Y_OFFSET, "", C'150,210,255', 8);
    B8_MakeLabel(B8_STATUS_LINE2, LABEL_X, 540 + SETTINGS_Y_OFFSET, "", C'190,205,220', 8);
    B8_MakeLabel(B8_STATUS_LINE3, LABEL_X, 522 + SETTINGS_Y_OFFSET, "", C'190,205,220', 8);
    B8_MakeLabel(B8_STATUS_LINE4, LABEL_X, 504 + SETTINGS_Y_OFFSET, "", C'190,205,220', 8);
    B8_MakeLabel(B8_STATUS_LINE5, LABEL_X, 486 + SETTINGS_Y_OFFSET, "", C'190,205,220', 8);
    B8_MakeLabel(B8_STATUS_LINE6, LABEL_X, 468 + SETTINGS_Y_OFFSET, "", C'190,205,220', 8);
    B8_MakeLabel(B8_STATUS_EDIT, LABEL_X, 450 + SETTINGS_Y_OFFSET, "", clrGold, 8);

    B8_MakeLabel("B8_LblPosMode", LABEL_X, 419 + SETTINGS_Y_OFFSET, "仓位模式", clrSilver, 8);
    B8_MakeButton(B8_BTN_POS_FIXED, FIELD_X, 430 + SETTINGS_Y_OFFSET, HALF_W, FIELD_H,
                  "固定手数", clrDimGray, clrWhite);
    B8_MakeButton(B8_BTN_POS_RISK, FIELD_X - HALF_W - HALF_GAP, 430 + SETTINGS_Y_OFFSET,
                  HALF_W, FIELD_H, "以损定仓", clrDimGray, clrWhite);

    B8_MakeLabel("B8_LblFixedLot", LABEL_X, 391 + SETTINGS_Y_OFFSET, "固定手数", clrSilver, 8);
    B8_MakeEdit(B8_EDIT_FIXED_LOT, FIELD_X, 402 + SETTINGS_Y_OFFSET, FIELD_W, FIELD_H, "");

    B8_MakeLabel("B8_LblRiskMode", LABEL_X, 363 + SETTINGS_Y_OFFSET, "风险模式", clrSilver, 8);
    B8_MakeButton(B8_BTN_RISK_MONEY, FIELD_X, 374 + SETTINGS_Y_OFFSET, HALF_W, FIELD_H,
                  "固定金额", clrDimGray, clrWhite);
    B8_MakeButton(B8_BTN_RISK_PCT, FIELD_X - HALF_W - HALF_GAP, 374 + SETTINGS_Y_OFFSET,
                  HALF_W, FIELD_H, "余额 %", clrDimGray, clrWhite);

    B8_MakeLabel("B8_LblRiskValue", LABEL_X, 335 + SETTINGS_Y_OFFSET, "风险值", clrSilver, 8);
    B8_MakeEdit(B8_EDIT_RISK_VALUE, FIELD_X, 346 + SETTINGS_Y_OFFSET, FIELD_W, FIELD_H, "");

    B8_MakeLabel("B8_LblTargetPct", LABEL_X, 307 + SETTINGS_Y_OFFSET, "账户触发 %", clrSilver, 8);
    B8_MakeEdit(B8_EDIT_TARGET_PCT, FIELD_X, 318 + SETTINGS_Y_OFFSET, FIELD_W, FIELD_H, "");

    B8_MakeLabel("B8_LblClosePct", LABEL_X, 279 + SETTINGS_Y_OFFSET, "账户减仓 %", clrSilver, 8);
    B8_MakeEdit(B8_EDIT_CLOSE_PCT, FIELD_X, 290 + SETTINGS_Y_OFFSET, FIELD_W, FIELD_H, "");

    B8_MakeLabel("B8_LblBEBuffer", LABEL_X, 251 + SETTINGS_Y_OFFSET, "账户保本点", clrSilver, 8);
    B8_MakeEdit(B8_EDIT_BE_BUFFER, FIELD_X, 262 + SETTINGS_Y_OFFSET, FIELD_W, FIELD_H, "");

    B8_MakeLabel("B8_LblEPEnabled", LABEL_X, 223 + SETTINGS_Y_OFFSET, "浮盈保护", clrSilver, 8);
    B8_MakeButton(B8_BTN_EP_TOGGLE, FIELD_X, 234 + SETTINGS_Y_OFFSET, FIELD_W, FIELD_H,
                  "", clrDimGray, clrWhite);

    B8_MakeLabel("B8_LblEPAction", LABEL_X, 195 + SETTINGS_Y_OFFSET,
                 "账户保护动作", clrSilver, 8);
    B8_MakeButton(B8_BTN_EP_ACTION_PARTIAL_BE, FIELD_X - HALF_W - HALF_GAP,
                  206 + SETTINGS_Y_OFFSET, HALF_W, FIELD_H,
                  "减仓+保本", clrDimGray, clrWhite);
    B8_MakeButton(B8_BTN_EP_ACTION_CLOSE, FIELD_X, 206 + SETTINGS_Y_OFFSET,
                  HALF_W, FIELD_H, "仅平仓", clrDimGray, clrWhite);

    B8_MakeButton(B8_BTN_PRESET_SAFE, LABEL_X, 178 + SETTINGS_Y_OFFSET, PRESET_W, FIELD_H,
                  "保守", clrSeaGreen, clrWhite);
    B8_MakeButton(B8_BTN_PRESET_STD, LABEL_X - PRESET_W - PRESET_GAP, 178 + SETTINGS_Y_OFFSET,
                  PRESET_W, FIELD_H,
                  "标准", clrSteelBlue, clrWhite);
    B8_MakeButton(B8_BTN_PRESET_FAST, LABEL_X - (PRESET_W + PRESET_GAP) * 2, 178 + SETTINGS_Y_OFFSET,
                  PRESET_W, FIELD_H,
                  "积极", clrDarkOrange, clrWhite);

    B8_MakeButton(B8_BTN_APPLY, LABEL_X, 150 + SETTINGS_Y_OFFSET, BG_W - 20, FIELD_H,
                  "应用参数", clrForestGreen, clrWhite);
    B8_MakeButton(B8_BTN_RESTORE, LABEL_X, 122 + SETTINGS_Y_OFFSET, 107, FIELD_H,
                  "恢复当前", clrSlateGray, clrWhite);
    B8_MakeButton(B8_BTN_DEFAULTS, LABEL_X - 112, 122 + SETTINGS_Y_OFFSET, 108, FIELD_H,
                  "启动值", clrSlateGray, clrWhite);

    // B8_WriteEditFields(); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
    // B8_UpdateSettingsPanel(); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
    // B8_CreateFibPanel(); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
    // B8_CreateOrderPanel(); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
}

//====================================================================
// 参数面板：刷新真实运行状态与编辑态高亮
//====================================================================
void B8_UpdateSettingsPanel()
{
    if (ObjectFind(0, B8_SETTINGS_BG) < 0) return;

    string trade_mode = (g_Trade_Mode == B8_MODE_NORMAL) ? "普通"
                        : ((g_Trade_Mode == B8_MODE_BUY_ONLY) ? "只多" : "只空");
    string line1 = "EA: " + (g_EA_Enabled ? "运行中" : "已停止")
                   + " | 方向: " + trade_mode;
    string line2 = "仓位: " + B8_PositionModeText(g_Runtime_Settings.position_mode);
    string line3 = "手数: " + DoubleToString(g_Runtime_Settings.fixed_lot, 2);
    string risk_mode_text = B8_RiskModeText(g_Runtime_Settings.risk_mode);
    string line4 = "";
    if (g_Runtime_Settings.risk_mode == RISK_PERCENTAGE)
    {
        double balance_risk_money = AccountBalance() *
                                    (g_Runtime_Settings.risk_value / 100.0);
        line4 = "风险: " + risk_mode_text + " | " +
                DoubleToString(g_Runtime_Settings.risk_value, 2) +
                "% = $" + DoubleToString(balance_risk_money, 2);
    }
    else
    {
        line4 = "风险: " + risk_mode_text + " | $" +
                DoubleToString(g_Runtime_Settings.risk_value, 2);
    }
    string line5 = "账户保护: " + (g_Runtime_Settings.equity_protect_enabled ? "开" : "关")
                   + " | 触发: " + DoubleToString(g_Runtime_Settings.equity_target_percent, 2) + "%";
    string equity_action_text =
        (g_Runtime_Settings.equity_protection_action == B8_EQUITY_CLOSE_ONLY)
        ? "仅平仓" : "减仓+保本";
    string line6 = "账户动作: " + equity_action_text
                   + " | 减仓: " + DoubleToString(g_Runtime_Settings.partial_close_percent, 1) + "%"
                   + " | BE: " + IntegerToString(g_Runtime_Settings.be_buffer_points);

    ObjectSetString(0, B8_STATUS_LINE1, OBJPROP_TEXT, line1);
    ObjectSetString(0, B8_STATUS_LINE2, OBJPROP_TEXT, line2);
    ObjectSetString(0, B8_STATUS_LINE3, OBJPROP_TEXT, line3);
    ObjectSetString(0, B8_STATUS_LINE4, OBJPROP_TEXT, line4);
    ObjectSetString(0, B8_STATUS_LINE5, OBJPROP_TEXT, line5);
    ObjectSetString(0, B8_STATUS_LINE6, OBJPROP_TEXT, line6);
    ObjectSetString(0, B8_STATUS_EDIT, OBJPROP_TEXT, g_Settings_Message);
    ObjectSetInteger(0, B8_STATUS_EDIT, OBJPROP_COLOR,
                     g_Settings_Dirty ? clrGold : clrLimeGreen);

    const color ACTIVE = clrDeepSkyBlue;
    const color INACTIVE = clrDimGray;

    ObjectSetInteger(0, B8_BTN_POS_FIXED, OBJPROP_BGCOLOR,
                     (g_Edit_Settings.position_mode == POS_FIXED_LOT) ? ACTIVE : INACTIVE);
    ObjectSetInteger(0, B8_BTN_POS_RISK, OBJPROP_BGCOLOR,
                     (g_Edit_Settings.position_mode == POS_RISK_BASED) ? ACTIVE : INACTIVE);
    ObjectSetInteger(0, B8_BTN_RISK_MONEY, OBJPROP_BGCOLOR,
                     (g_Edit_Settings.risk_mode == RISK_FIXED_MONEY) ? ACTIVE : INACTIVE);
    ObjectSetInteger(0, B8_BTN_RISK_PCT, OBJPROP_BGCOLOR,
                     (g_Edit_Settings.risk_mode == RISK_PERCENTAGE) ? ACTIVE : INACTIVE);
    ObjectSetInteger(0, B8_BTN_EP_TOGGLE, OBJPROP_BGCOLOR,
                     g_Edit_Settings.equity_protect_enabled ? clrForestGreen : clrDimGray);
    ObjectSetString(0, B8_BTN_EP_TOGGLE, OBJPROP_TEXT,
                    g_Edit_Settings.equity_protect_enabled ? "已开启" : "已关闭");
    ObjectSetInteger(0, B8_BTN_EP_ACTION_PARTIAL_BE, OBJPROP_BGCOLOR,
                     (g_Edit_Settings.equity_protection_action == B8_EQUITY_PARTIAL_BE)
                     ? ACTIVE : INACTIVE);
    ObjectSetInteger(0, B8_BTN_EP_ACTION_CLOSE, OBJPROP_BGCOLOR,
                     (g_Edit_Settings.equity_protection_action == B8_EQUITY_CLOSE_ONLY)
                     ? clrIndianRed : INACTIVE);

    // B8_UpdateOrderPanel(); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
}
//#endregion

//#region MARK: 模块--订单级管理面板
//====================================================================
// 订单管理子面板：独立显示订单级减仓/保本参数
//====================================================================
void B8_CreateOrderPanel()
{
    // CORNER_RIGHT_LOWER坐标系中Y值越大越靠上，整体上移以与参数面板对齐。
    const int ORDER_Y_OFFSET = 55;
    const int BG_X = 500;
    const int BG_Y = 594 + ORDER_Y_OFFSET;
    const int BG_W = 240;
    const int BG_H = 453;
    const int LABEL_X = 490;
    const int FIELD_X = 416;
    const int FIELD_W = 136;
    const int FIELD_H = 22;
    const int HALF_W = 66;
    const int HALF_GAP = 4;

    B8_MakeRectLabel(B8_ORDER_PANEL_BG, BG_X, BG_Y, BG_W, BG_H,
                     C'22,27,38', C'70,95,125');
    B8_MakeLabel(B8_ORDER_PANEL_TITLE, LABEL_X, 579 + ORDER_Y_OFFSET,
                 "订单级管理", clrWhite, 10);
    B8_MakeLabel(B8_ORDER_STATUS_LINE1, LABEL_X, 558 + ORDER_Y_OFFSET, "", C'150,210,255', 8);
    B8_MakeLabel(B8_ORDER_STATUS_LINE2, LABEL_X, 540 + ORDER_Y_OFFSET, "", C'190,205,220', 8);
    B8_MakeLabel(B8_ORDER_STATUS_LINE3, LABEL_X, 522 + ORDER_Y_OFFSET, "", C'190,205,220', 8);
    B8_MakeLabel(B8_ORDER_STATUS_MESSAGE, LABEL_X, 504 + ORDER_Y_OFFSET, "", clrGold, 8);

    B8_MakeLabel("B8_LblOrderEnabled", LABEL_X, 473 + ORDER_Y_OFFSET, "订单保护", clrSilver, 8);
    B8_MakeButton(B8_BTN_ORDER_ENABLED, FIELD_X, 484 + ORDER_Y_OFFSET, FIELD_W, FIELD_H,
                  "", clrDimGray, clrWhite);

    B8_MakeLabel("B8_LblOrderTriggerMode", LABEL_X, 445 + ORDER_Y_OFFSET, "触发方式", clrSilver, 8);
    B8_MakeButton(B8_BTN_ORDER_TRIGGER_R, FIELD_X, 456 + ORDER_Y_OFFSET, HALF_W, FIELD_H,
                  "盈亏比R", clrDimGray, clrWhite);
    B8_MakeButton(B8_BTN_ORDER_TRIGGER_POINTS, FIELD_X - HALF_W - HALF_GAP, 456 + ORDER_Y_OFFSET,
                  HALF_W, FIELD_H, "固定点数", clrDimGray, clrWhite);

    B8_MakeLabel("B8_LblOrderTriggerPoints", LABEL_X, 417 + ORDER_Y_OFFSET, "触发点数", clrSilver, 8);
    B8_MakeEdit(B8_ORDER_EDIT_TRIGGER_POINTS, FIELD_X, 428 + ORDER_Y_OFFSET, FIELD_W, FIELD_H, "");
    B8_MakeLabel("B8_LblOrderTriggerR", LABEL_X, 389 + ORDER_Y_OFFSET, "触发R", clrSilver, 8);
    B8_MakeEdit(B8_ORDER_EDIT_TRIGGER_R, FIELD_X, 400 + ORDER_Y_OFFSET, FIELD_W, FIELD_H, "");

    B8_MakeLabel("B8_LblOrderClosePct", LABEL_X, 361 + ORDER_Y_OFFSET, "单笔减仓 %", clrSilver, 8);
    B8_MakeEdit(B8_ORDER_EDIT_CLOSE_PCT, FIELD_X, 372 + ORDER_Y_OFFSET, FIELD_W, FIELD_H, "");
    B8_MakeLabel("B8_LblOrderBEBuffer", LABEL_X, 333 + ORDER_Y_OFFSET, "保本缓冲点", clrSilver, 8);
    B8_MakeEdit(B8_ORDER_EDIT_BE_BUFFER, FIELD_X, 344 + ORDER_Y_OFFSET, FIELD_W, FIELD_H, "");

    B8_MakeLabel("B8_LblOrderMode", LABEL_X, 305 + ORDER_Y_OFFSET, "协作方式", clrSilver, 8);
    B8_MakeButton(B8_BTN_ORDER_MODE_PARTIAL, FIELD_X - HALF_W - HALF_GAP, 316 + ORDER_Y_OFFSET,
                  HALF_W, FIELD_H, "仅减仓", clrDimGray, clrWhite);
    B8_MakeButton(B8_BTN_ORDER_MODE_BE, FIELD_X, 316 + ORDER_Y_OFFSET,
                  HALF_W, FIELD_H, "仅保本", clrDimGray, clrWhite);
    B8_MakeButton(B8_BTN_ORDER_MODE_PARTIAL_BE, FIELD_X, 288 + ORDER_Y_OFFSET,
                  FIELD_W, FIELD_H, "减仓后保本", clrDimGray, clrWhite);
    B8_MakeButton(B8_BTN_ORDER_MODE_CLOSE, FIELD_X, 260 + ORDER_Y_OFFSET,
                  FIELD_W, FIELD_H, "仅平仓", clrIndianRed, clrWhite);

    B8_MakeButton(B8_BTN_ORDER_PRESET_SAFE, LABEL_X, 230 + ORDER_Y_OFFSET, 70, FIELD_H,
                  "保守", clrSeaGreen, clrWhite);
    B8_MakeButton(B8_BTN_ORDER_PRESET_STD, LABEL_X - 75, 230 + ORDER_Y_OFFSET, 70, FIELD_H,
                  "标准", clrSteelBlue, clrWhite);
    B8_MakeButton(B8_BTN_ORDER_PRESET_FAST, LABEL_X - 150, 230 + ORDER_Y_OFFSET, 70, FIELD_H,
                  "积极", clrDarkOrange, clrWhite);

    B8_MakeButton(B8_BTN_ORDER_APPLY, LABEL_X, 202 + ORDER_Y_OFFSET, BG_W - 20, FIELD_H,
                  "应用订单管理", clrForestGreen, clrWhite);
    B8_MakeButton(B8_BTN_ORDER_RESTORE, LABEL_X, 174 + ORDER_Y_OFFSET, BG_W - 20, FIELD_H,
                  "恢复订单管理", clrSlateGray, clrWhite);

    // B8_WriteOrderEditFields(); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
    // B8_UpdateOrderPanel(); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
}

//====================================================================
// 订单管理子面板：刷新编辑态显示
//====================================================================
void B8_UpdateOrderPanel()
{
    if (ObjectFind(0, B8_ORDER_PANEL_BG) < 0) return;

    const color ACTIVE = clrDeepSkyBlue;
    const color INACTIVE = clrDimGray;
     bool is_r_mode = (g_Order_Edit_Settings.order_trigger_mode == B8_ORDER_TRIGGER_R);
    string mode_text = (g_Order_Edit_Settings.order_protection_mode == B8_ORDER_PARTIAL_ONLY)
                       ? "仅减仓"
                       : ((g_Order_Edit_Settings.order_protection_mode == B8_ORDER_BE_ONLY)
                          ? "仅保本"
                          : ((g_Order_Edit_Settings.order_protection_mode == B8_ORDER_PARTIAL_BE)
                             ? "减仓后保本" : "仅平仓"));
    string trigger_text = is_r_mode
                                  ? DoubleToString(g_Order_Edit_Settings.order_trigger_r, 2) + "R"
                                  : DoubleToString(g_Order_Edit_Settings.order_trigger_points, 0) + "点";

    ObjectSetString(0, B8_ORDER_STATUS_LINE1, OBJPROP_TEXT,
                    "状态: " + (g_Order_Edit_Settings.order_protection_enabled ? "开启" : "关闭") +
                    " | 模式: " + mode_text);
    string action_text = (g_Order_Edit_Settings.order_protection_mode == B8_ORDER_CLOSE_ONLY)
                         ? "动作: 全部平仓"
                         : "减仓: " + DoubleToString(g_Order_Edit_Settings.order_partial_close_percent, 1) + "%";
    ObjectSetString(0, B8_ORDER_STATUS_LINE2, OBJPROP_TEXT,
                    "触发: " + trigger_text + " | " + action_text);
    ObjectSetString(0, B8_ORDER_STATUS_LINE3, OBJPROP_TEXT,
                    "保本缓冲: " + IntegerToString(g_Order_Edit_Settings.order_be_buffer_points) + "点");
    ObjectSetString(0, B8_ORDER_STATUS_MESSAGE, OBJPROP_TEXT, g_Order_Settings_Message);
    ObjectSetInteger(0, B8_ORDER_STATUS_MESSAGE, OBJPROP_COLOR,
                     g_Order_Settings_Dirty ? clrGold : clrLimeGreen);

    ObjectSetInteger(0, B8_BTN_ORDER_ENABLED, OBJPROP_BGCOLOR,
                     g_Order_Edit_Settings.order_protection_enabled ? clrForestGreen : INACTIVE);
    ObjectSetString(0, B8_BTN_ORDER_ENABLED, OBJPROP_TEXT,
                    g_Order_Edit_Settings.order_protection_enabled ? "已开启" : "已关闭");
    ObjectSetInteger(0, B8_BTN_ORDER_TRIGGER_POINTS, OBJPROP_BGCOLOR,
                     is_r_mode ? INACTIVE : ACTIVE);
    ObjectSetInteger(0, B8_BTN_ORDER_TRIGGER_R, OBJPROP_BGCOLOR,
                     is_r_mode ? ACTIVE : INACTIVE);
    ObjectSetInteger(0, B8_BTN_ORDER_MODE_PARTIAL, OBJPROP_BGCOLOR,
                     g_Order_Edit_Settings.order_protection_mode == B8_ORDER_PARTIAL_ONLY ? ACTIVE : INACTIVE);
    ObjectSetInteger(0, B8_BTN_ORDER_MODE_BE, OBJPROP_BGCOLOR,
                     g_Order_Edit_Settings.order_protection_mode == B8_ORDER_BE_ONLY ? ACTIVE : INACTIVE);
    ObjectSetInteger(0, B8_BTN_ORDER_MODE_PARTIAL_BE, OBJPROP_BGCOLOR,
                     g_Order_Edit_Settings.order_protection_mode == B8_ORDER_PARTIAL_BE ? ACTIVE : INACTIVE);
    ObjectSetInteger(0, B8_BTN_ORDER_MODE_CLOSE, OBJPROP_BGCOLOR,
                     g_Order_Edit_Settings.order_protection_mode == B8_ORDER_CLOSE_ONLY ? clrIndianRed : INACTIVE);

    ObjectSetInteger(0, B8_ORDER_EDIT_TRIGGER_POINTS, OBJPROP_BGCOLOR,
                     is_r_mode ? C'55,60,70' : clrWhite);
    ObjectSetInteger(0, B8_ORDER_EDIT_TRIGGER_R, OBJPROP_BGCOLOR,
                     is_r_mode ? clrWhite : C'55,60,70');
}
//#endregion

//#region MARK: 模块--Fibo挂单面板
//====================================================================
// Fib挂单选择区域：与参数和订单区域同属一个Bot8面板体系
// 旧版本函数不在使用留作学习研究
//====================================================================
/*
void B8_CreateFibPanel_Old()
{
    // 坐标基准为 CORNER_RIGHT_LOWER：X从图表右边向左计算，Y从图表底部向上计算。
    // BG_X/BG_Y分别定位背景矩形的左边缘和上边缘，不是图表左上角坐标。
    const int BG_X = 767; // 背景左边缘距图表右边缘的像素距离
    const int BG_Y = 594; // 背景上边缘距图表底部的像素距离
    const int BG_W = 252; // 背景宽度
    const int BG_H = 408; // 背景高度，包含历史信号补挂区域

    // 横向定位：LABEL_X为文字和整行按钮的左边缘参考；COL2_X向右侧列偏移。
    const int LABEL_X = 756;
    const int COL1_X = 756; // Fib左列的左边缘定位值
    const int COL2_X = 682; // Fib右列的左边缘定位值

    const int BTN_W = 70;  // 单个Fib/预设按钮宽度
    const int BTN_H = 22;  // 单个按钮高度
    const int ROW_GAP = 5; // Fib网格相邻两行之间的垂直间距

    // 四个区域之间使用同一个垂直间距，避免分别写死Y坐标造成间距不一致。
    const int SECTION_GAP = 8;
    const int TITLE_Y = 579;  // 第一部分：标题的上边缘定位值
    const int STATUS_Y = 556; // 第一部分：状态文字的上边缘定位值
    const int STATUS_H = 12;  // 状态文字区域预留高度，用于推导第二部分起点

    // 第二部分：4行Fib按钮网格的总高度 = 4个按钮 + 3个行间距。
    const int FIB_GRID_H = BTN_H * 4 + ROW_GAP * 3;
    const int FIB_TOP_Y = STATUS_Y - STATUS_H - SECTION_GAP;
    const int ACTION_Y = FIB_TOP_Y - FIB_GRID_H - SECTION_GAP;
    const int PRESET_Y = ACTION_Y - BTN_H - SECTION_GAP;

    B8_MakeRectLabel(B8_FIB_PANEL_BG, BG_X, BG_Y, BG_W, BG_H,
                     C'22,27,38', C'70,95,125');

    // 第一部分：标题和当前选择状态。
    B8_MakeLabel(B8_FIB_PANEL_TITLE, LABEL_X, TITLE_Y,
                 "Fib挂单位置", clrWhite, 10);
    B8_MakeLabel(B8_FIB_STATUS, LABEL_X, STATUS_Y, "", C'150,210,255', 8);

    // 第二部分：8个Fib位置，4行两列；每行由BTN_H和ROW_GAP统一推导。
    B8_MakeButton(B8_FIB_BTN_0120, COL1_X, FIB_TOP_Y, BTN_W, BTN_H,
                  "Fib 0.120", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_0214, COL2_X, FIB_TOP_Y, BTN_W, BTN_H,
                  "Fib 0.214", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_0236, COL1_X, FIB_TOP_Y - (BTN_H + ROW_GAP), BTN_W, BTN_H,
                  "Fib 0.236", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_0382, COL2_X, FIB_TOP_Y - (BTN_H + ROW_GAP), BTN_W, BTN_H,
                  "Fib 0.382", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_0500, COL1_X, FIB_TOP_Y - (BTN_H + ROW_GAP) * 2, BTN_W, BTN_H,
                  "Fib 0.500", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_0618, COL2_X, FIB_TOP_Y - (BTN_H + ROW_GAP) * 2, BTN_W, BTN_H,
                  "Fib 0.618", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_0786, COL1_X, FIB_TOP_Y - (BTN_H + ROW_GAP) * 3, BTN_W, BTN_H,
                  "Fib 0.786", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_0880, COL2_X, FIB_TOP_Y - (BTN_H + ROW_GAP) * 3, BTN_W, BTN_H,
                  "Fib 0.880", clrDimGray, clrWhite);

    // 第三部分：全部选中/全部取消，距离第二部分统一使用SECTION_GAP。
    B8_MakeButton(B8_FIB_BTN_ALL, LABEL_X, ACTION_Y, 107, BTN_H,
                  "全部选中", clrSteelBlue, clrWhite);
    B8_MakeButton(B8_FIB_BTN_NONE, LABEL_X - 112, ACTION_Y, 108, BTN_H,
                  "全部取消", clrSlateGray, clrWhite);

    // 第四部分：数字预设，距离第三部分同样使用SECTION_GAP。
    B8_MakeButton(B8_FIB_BTN_PRESET_1, LABEL_X - 150, PRESET_Y, 70, BTN_H,
                  "预设1", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_PRESET_2, LABEL_X - 75, PRESET_Y, 70, BTN_H,
                  "预设2", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_PRESET_3, LABEL_X, PRESET_Y, 70, BTN_H,
                  "预设3", clrDimGray, clrWhite);

    // 第五部分：历史信号补挂。shift输入框也可由“选择K线”按钮自动回填。
    const int HISTORY_TITLE_Y = PRESET_Y - 40;
    const int HISTORY_STATUS_Y = HISTORY_TITLE_Y - 22;
    const int HISTORY_EDIT_Y = HISTORY_STATUS_Y - 28;
    const int HISTORY_ACTION_Y = HISTORY_EDIT_Y - 28;

    B8_MakeLabel(B8_FIB_HISTORY_TITLE, LABEL_X, HISTORY_TITLE_Y,
                 "历史信号补挂", clrWhite, 9);
    B8_MakeLabel(B8_FIB_HISTORY_STATUS, LABEL_X, HISTORY_STATUS_Y,
                 "", C'190,205,220', 8);
    B8_MakeEdit(B8_FIB_HISTORY_SHIFT, COL2_X, HISTORY_EDIT_Y,
                BTN_W, BTN_H, IntegerToString(g_History_Selected_Shift));
    B8_MakeLabel("B8_FibHistoryShiftLabel", COL1_X, HISTORY_EDIT_Y - 10,
                 "历史K线 Shift", clrSilver, 8);
    B8_MakeButton(B8_FIB_HISTORY_SELECT, COL1_X, HISTORY_ACTION_Y,
                  BTN_W, BTN_H, "选择K线", clrSteelBlue, clrWhite);
    B8_MakeButton(B8_FIB_HISTORY_CANCEL, COL2_X, HISTORY_ACTION_Y,
                  BTN_W, BTN_H, "取消选择", clrSlateGray, clrWhite);
    B8_MakeButton(B8_FIB_HISTORY_EXECUTE, LABEL_X, HISTORY_ACTION_Y - 28,
                  BTN_W * 2 + 4, BTN_H, "补挂历史信号", clrForestGreen, clrWhite);
    B8_MakeButton(B8_FIB_HISTORY_DELETE, LABEL_X, HISTORY_ACTION_Y - 56,
                  BTN_W * 2 + 4, BTN_H, "删除历史挂单", clrIndianRed, clrWhite);

    B8_UpdateFibPanel();
    B8_UpdateHistoricalFibPanel();
}
*/

//====================================================================
// Fib挂单选择区域：与参数和订单区域同属一个Bot8面板体系
//====================================================================
void B8_CreateFibPanel()
{
    // 坐标基准为 CORNER_RIGHT_LOWER：X从图表右边向左计算，Y从图表底部向上计算。
    // BG_X/BG_Y分别定位背景矩形的左边缘和上边缘，不是图表左上角坐标。
    // CORNER_RIGHT_LOWER坐标系中Y值越大越靠上，整体上移以与参数面板对齐。
    const int FIB_Y_OFFSET = 115;
    const int BG_X = 767; // 背景左边缘距图表右边缘的像素距离
    const int BG_Y = 594 + FIB_Y_OFFSET; // 背景上边缘距图表底部的像素距离
    const int BG_W = 252; // 背景宽度
    const int BG_H = 705; // 背景高度，包含Fib策略和历史信号补挂区域

    // 横向定位：LABEL_X为文字和整行按钮的左边缘参考；COL2_X向右侧列偏移。
    const int LABEL_X = 756;
    const int COL1_X = 756; // Fib左列的左边缘定位值
    const int COL2_X = 682; // Fib右列的左边缘定位值

    const int BTN_W = 70;  // 单个Fib/预设按钮宽度
    const int BTN_H = 22;  // 单个按钮高度
    const int ROW_GAP = 5; // Fib网格相邻两行之间的垂直间距

    // 第二部分使用独立的自适应宽度：背景左右各保留11px，列间距沿用当前布局。
    const int FIB_SIDE_MARGIN = 11;
    const int FIB_COLUMN_GAP = COL1_X - COL2_X - BTN_W;
    const int FIB_BUTTON_W = (BG_W - FIB_SIDE_MARGIN * 2 - FIB_COLUMN_GAP) / 2;
    const int FIB_COL1_X = BG_X - FIB_SIDE_MARGIN;
    const int FIB_COL2_X = FIB_COL1_X - FIB_BUTTON_W - FIB_COLUMN_GAP;

    // 四个区域之间使用同一个垂直间距，避免分别写死Y坐标造成间距不一致。
    const int SECTION_GAP = 8;
    const int TITLE_Y = 579 + FIB_Y_OFFSET;  // 第一部分：标题的上边缘定位值
    const int STATUS_Y = 556 + FIB_Y_OFFSET; // 第一部分：状态文字的上边缘定位值
    const int STATUS_H = 12;  // 状态文字区域预留高度，用于推导第二部分起点

    // 第二部分：4行Fib按钮网格的总高度 = 4个按钮 + 3个行间距。
    const int FIB_GRID_H = BTN_H * 4 + ROW_GAP * 3;
    const int RANGE_STATUS_Y = STATUS_Y - 18;
    const int FIB_TOP_Y = STATUS_Y - STATUS_H - SECTION_GAP - 18;
    const int ACTION_Y = FIB_TOP_Y - FIB_GRID_H - SECTION_GAP;
    const int PRESET_Y = ACTION_Y - BTN_H - SECTION_GAP;

    B8_MakeRectLabel(B8_FIB_PANEL_BG, BG_X, BG_Y, BG_W, BG_H,
                     C'22,27,38', C'70,95,125');

    // 第一部分：标题和当前选择状态。
    B8_MakeLabel(B8_FIB_PANEL_TITLE, LABEL_X, TITLE_Y,
                 "Fib挂单位置", clrWhite, 10);
    B8_MakeLabel(B8_FIB_STATUS, LABEL_X, STATUS_Y, "", C'150,210,255', 8);
    B8_MakeLabel(B8_FIB_RANGE_STATUS, LABEL_X, RANGE_STATUS_Y,
                 "", C'190,205,220', 8);

    // 第二部分：8个Fib位置，4行两列；每行由BTN_H和ROW_GAP统一推导。
    B8_MakeButton(B8_FIB_BTN_0120, FIB_COL1_X, FIB_TOP_Y, FIB_BUTTON_W, BTN_H,
                  "Fib 0.120", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_0214, FIB_COL2_X, FIB_TOP_Y, FIB_BUTTON_W, BTN_H,
                  "Fib 0.214", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_0236, FIB_COL1_X, FIB_TOP_Y - (BTN_H + ROW_GAP), FIB_BUTTON_W, BTN_H,
                  "Fib 0.236", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_0382, FIB_COL2_X, FIB_TOP_Y - (BTN_H + ROW_GAP), FIB_BUTTON_W, BTN_H,
                  "Fib 0.382", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_0500, FIB_COL1_X, FIB_TOP_Y - (BTN_H + ROW_GAP) * 2, FIB_BUTTON_W, BTN_H,
                  "Fib 0.500", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_0618, FIB_COL2_X, FIB_TOP_Y - (BTN_H + ROW_GAP) * 2, FIB_BUTTON_W, BTN_H,
                  "Fib 0.618", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_0786, FIB_COL1_X, FIB_TOP_Y - (BTN_H + ROW_GAP) * 3, FIB_BUTTON_W, BTN_H,
                  "Fib 0.786", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_0880, FIB_COL2_X, FIB_TOP_Y - (BTN_H + ROW_GAP) * 3, FIB_BUTTON_W, BTN_H,
                  "Fib 0.880", clrDimGray, clrWhite);

    // 第三部分：全部选中/全部取消，距离第二部分统一使用SECTION_GAP。
    const int ACTION_BUTTON_W = (BG_W - FIB_SIDE_MARGIN * 2 - FIB_COLUMN_GAP) / 2;
    const int ACTION_COL1_X = BG_X - FIB_SIDE_MARGIN;
    const int ACTION_COL2_X = ACTION_COL1_X - ACTION_BUTTON_W - FIB_COLUMN_GAP;

    B8_MakeButton(B8_FIB_BTN_ALL, ACTION_COL1_X, ACTION_Y, ACTION_BUTTON_W, BTN_H,
                  "全部选中", clrSteelBlue, clrWhite);
    B8_MakeButton(B8_FIB_BTN_NONE, ACTION_COL2_X, ACTION_Y, ACTION_BUTTON_W, BTN_H,
                  "全部取消", clrSlateGray, clrWhite);

    // 第四部分：数字预设，距离第三部分同样使用SECTION_GAP。
    const int PRESET_COLUMN_GAP = FIB_COLUMN_GAP;
    const int PRESET_BUTTON_W = (BG_W - FIB_SIDE_MARGIN * 2 - PRESET_COLUMN_GAP * 2) / 3;
    const int PRESET_COL1_X = BG_X - FIB_SIDE_MARGIN;
    const int PRESET_COL2_X = PRESET_COL1_X - PRESET_BUTTON_W - PRESET_COLUMN_GAP;
    const int PRESET_COL3_X = PRESET_COL2_X - PRESET_BUTTON_W - PRESET_COLUMN_GAP;

    B8_MakeButton(B8_FIB_BTN_PRESET_1, PRESET_COL3_X, PRESET_Y, PRESET_BUTTON_W, BTN_H,
                  "预设1", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_PRESET_2, PRESET_COL2_X, PRESET_Y, PRESET_BUTTON_W, BTN_H,
                  "预设2", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_PRESET_3, PRESET_COL1_X, PRESET_Y, PRESET_BUTTON_W, BTN_H,
                  "预设3", clrDimGray, clrWhite);

    // 第五部分：Fib风险分配和淘汰策略，使用运行时全局变量，不改变EA输入参数结构。
    const int STRATEGY_TITLE_Y = PRESET_Y - 38;
    const int STRATEGY_BUTTON_Y = STRATEGY_TITLE_Y - 15;
    const int STRATEGY_POLICY_Y = STRATEGY_BUTTON_Y - 28;
    const int STRATEGY_BUTTON_SHIFT_X = 80;
    const int STRATEGY_COL1_X = COL1_X - STRATEGY_BUTTON_SHIFT_X;
    const int STRATEGY_COL2_X = COL2_X - STRATEGY_BUTTON_SHIFT_X;
    B8_MakeLabel("B8_FibStrategyTitle", LABEL_X, STRATEGY_TITLE_Y,
                 "Fib策略", clrWhite, 9);
    B8_MakeLabel("B8_FibRiskLabel", LABEL_X, STRATEGY_BUTTON_Y - 10,
                 "风险分配", clrSilver, 8);
    B8_MakeButton(B8_FIB_BTN_RISK_ON, STRATEGY_COL1_X, STRATEGY_BUTTON_Y,
                  BTN_W, BTN_H, "开启", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_RISK_OFF, STRATEGY_COL2_X, STRATEGY_BUTTON_Y,
                  BTN_W, BTN_H, "关闭", clrDimGray, clrWhite);
    B8_MakeLabel("B8_FibPolicyLabel", LABEL_X, STRATEGY_POLICY_Y - 10,
                 "淘汰优先", clrSilver, 8);
    B8_MakeButton(B8_FIB_BTN_KEEP_SHALLOW, STRATEGY_COL1_X, STRATEGY_POLICY_Y,
                  BTN_W, BTN_H, "浅层优先", clrDimGray, clrWhite);
    B8_MakeButton(B8_FIB_BTN_KEEP_DEEP, STRATEGY_COL2_X, STRATEGY_POLICY_Y,
                  BTN_W, BTN_H, "深层优先", clrDimGray, clrWhite);

    // 第六部分：历史信号补挂。shift输入框也可由“选择K线”按钮自动回填。
    const int HISTORY_TITLE_Y = STRATEGY_POLICY_Y - 35;
    const int HISTORY_STATUS_Y = HISTORY_TITLE_Y - 22;
    const int HISTORY_EDIT_Y = HISTORY_STATUS_Y - 20;
    const int HISTORY_ACTION_Y = HISTORY_EDIT_Y - 28;

    B8_MakeLabel(B8_FIB_HISTORY_TITLE, LABEL_X, HISTORY_TITLE_Y,
                 "历史信号补挂", clrWhite, 9);
    B8_MakeLabel(B8_FIB_HISTORY_STATUS, LABEL_X, HISTORY_STATUS_Y,
                 "", C'190,205,220', 8);
    B8_MakeEdit(B8_FIB_HISTORY_SHIFT, COL2_X, HISTORY_EDIT_Y,
                BTN_W, BTN_H, IntegerToString(g_History_Selected_Shift));
    B8_MakeLabel("B8_FibHistoryShiftLabel", COL1_X, HISTORY_EDIT_Y - 10,
                 "历史K线 Shift", clrSilver, 8);
    const int HISTORY_BUTTON_W = (BG_W - FIB_SIDE_MARGIN * 2 - FIB_COLUMN_GAP) / 2;
    const int HISTORY_COL1_X = BG_X - FIB_SIDE_MARGIN;
    const int HISTORY_COL2_X = HISTORY_COL1_X - HISTORY_BUTTON_W - FIB_COLUMN_GAP;

    B8_MakeButton(B8_FIB_HISTORY_SELECT, HISTORY_COL1_X, HISTORY_ACTION_Y,
                  HISTORY_BUTTON_W, BTN_H, "选择K线", clrSteelBlue, clrWhite);
    B8_MakeButton(B8_FIB_HISTORY_CANCEL, HISTORY_COL2_X, HISTORY_ACTION_Y,
                  HISTORY_BUTTON_W, BTN_H, "取消选择", clrSlateGray, clrWhite);
    B8_MakeButton(B8_FIB_HISTORY_EXECUTE, LABEL_X, HISTORY_ACTION_Y - 28,
                  BTN_W * 2 + 4, BTN_H, "补挂历史信号", clrForestGreen, clrWhite);
    B8_MakeButton(B8_FIB_HISTORY_DELETE, LABEL_X, HISTORY_ACTION_Y - 56,
                  BTN_W * 2 + 4, BTN_H, "删除历史挂单", clrIndianRed, clrWhite);

    //#region MARK: 模块--自定义价格补挂面板新增控件
    // 新增区域严格接在现有历史补挂区域下方，不改变旧控件坐标。
    const int CUSTOM_TITLE_Y = HISTORY_ACTION_Y - 90;
    const int CUSTOM_ENTRY_Y = CUSTOM_TITLE_Y - 15;
    const int CUSTOM_STOP_Y = CUSTOM_ENTRY_Y - 26;
    const int CUSTOM_ORDER_Y = CUSTOM_STOP_Y - 28;
    const int CUSTOM_RISK_Y = CUSTOM_ORDER_Y - 56;
    const int CUSTOM_EXECUTE_Y = CUSTOM_RISK_Y - 28;

    B8_MakeLabel(B8_CUSTOM_FIB_TITLE, LABEL_X, CUSTOM_TITLE_Y,
                 "自定义价格补挂", clrWhite, 9);
    B8_MakeLabel(B8_CUSTOM_FIB_ENTRY_LABEL, COL1_X, CUSTOM_ENTRY_Y - 10,
                 "入场价 (Fibo1)", clrSilver, 8);
    B8_MakeEdit(B8_CUSTOM_FIB_ENTRY_EDIT, COL2_X, CUSTOM_ENTRY_Y,
                BTN_W, BTN_H, g_Custom_Fib_Entry_Price > 0.0
                ? DoubleToString(g_Custom_Fib_Entry_Price, _Digits) : "");
    B8_MakeButton(B8_CUSTOM_FIB_PICK_ENTRY, COL2_X - 75, CUSTOM_ENTRY_Y,
                  48, BTN_H, "取价", clrSteelBlue, clrWhite);
    B8_MakeLabel(B8_CUSTOM_FIB_STOP_LABEL, COL1_X, CUSTOM_STOP_Y - 10,
                 "止损价 (Fibo0)", clrSilver, 8);
    B8_MakeEdit(B8_CUSTOM_FIB_STOP_EDIT, COL2_X, CUSTOM_STOP_Y,
                BTN_W, BTN_H, g_Custom_Fib_Stop_Price > 0.0
                ? DoubleToString(g_Custom_Fib_Stop_Price, _Digits) : "");
    B8_MakeButton(B8_CUSTOM_FIB_PICK_STOP, COL2_X - 75, CUSTOM_STOP_Y,
                  48, BTN_H, "取价", clrSteelBlue, clrWhite);

    B8_MakeButton(B8_CUSTOM_FIB_ORDER_AUTO, COL1_X, CUSTOM_ORDER_Y,
                  48, BTN_H, "自动", clrDeepSkyBlue, clrWhite);
    B8_MakeButton(B8_CUSTOM_FIB_ORDER_BUY_LIMIT, COL1_X - 54, CUSTOM_ORDER_Y,
                  48, BTN_H, "BuyL", clrDimGray, clrWhite);
    B8_MakeButton(B8_CUSTOM_FIB_ORDER_BUY_STOP, COL1_X - 108, CUSTOM_ORDER_Y,
                  48, BTN_H, "BuyS", clrDimGray, clrWhite);
    B8_MakeButton(B8_CUSTOM_FIB_ORDER_SELL_LIMIT, COL1_X - 54, CUSTOM_ORDER_Y - 28,
                  48, BTN_H, "SellL", clrDimGray, clrWhite);
    B8_MakeButton(B8_CUSTOM_FIB_ORDER_SELL_STOP, COL1_X - 108, CUSTOM_ORDER_Y - 28,
                  48, BTN_H, "SellS", clrDimGray, clrWhite);

    B8_MakeButton(B8_CUSTOM_FIB_RISK_SHARED, COL1_X, CUSTOM_RISK_Y,
                  BTN_W, BTN_H, "共享风险", clrDeepSkyBlue, clrWhite);
    B8_MakeButton(B8_CUSTOM_FIB_RISK_INDEPENDENT, COL2_X, CUSTOM_RISK_Y,
                  BTN_W, BTN_H, "独立风险", clrDimGray, clrWhite);

    B8_MakeButton(B8_CUSTOM_FIB_EXECUTE, LABEL_X, CUSTOM_EXECUTE_Y,
                  BTN_W * 2 + 4, BTN_H, "自定义价格补挂", clrForestGreen, clrWhite);
    B8_MakeLabel(B8_CUSTOM_FIB_STATUS, LABEL_X, CUSTOM_EXECUTE_Y - 35,
                 "", C'190,205,220', 8);
    //#endregion

    // B8_UpdateFibPanel(); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
    // B8_UpdateHistoricalFibPanel(); // 已迁移到 B8_InitializePanels()，原调用保留供回溯
}

//====================================================================
// 刷新实时Fib挂单选择区域的按钮颜色和状态提示。
// 该函数只更新界面，不创建或修改任何订单。
//====================================================================
void B8_UpdateFibPanel()
{
    if (ObjectFind(0, B8_FIB_PANEL_BG) < 0) return;

    string buttons[8] =
    {
        B8_FIB_BTN_0120, B8_FIB_BTN_0214, B8_FIB_BTN_0236, B8_FIB_BTN_0382,
        B8_FIB_BTN_0500, B8_FIB_BTN_0618, B8_FIB_BTN_0786, B8_FIB_BTN_0880
    };
    const color ACTIVE = clrDeepSkyBlue;
    const color INACTIVE = clrDimGray;
    const color DISABLED = C'75,75,75';
    int selected_count = B8_CountSelectedPendingFib();

    for (int i = 0; i < 8; i++)
    {
        ObjectSetInteger(0, buttons[i], OBJPROP_BGCOLOR,
                         g_Pending_Fib_Selected[i] ? ACTIVE : INACTIVE);
    }

    if (Fib_Pending_Algorithm == B8_FIB_ALGO_V2)
    {
        ObjectSetInteger(0, B8_FIB_BTN_RISK_ON, OBJPROP_BGCOLOR, DISABLED);
        ObjectSetInteger(0, B8_FIB_BTN_RISK_OFF, OBJPROP_BGCOLOR, DISABLED);
        ObjectSetInteger(0, B8_FIB_BTN_KEEP_SHALLOW, OBJPROP_BGCOLOR, DISABLED);
        ObjectSetInteger(0, B8_FIB_BTN_KEEP_DEEP, OBJPROP_BGCOLOR, DISABLED);
    }
    else
    {
        ObjectSetInteger(0, B8_FIB_BTN_RISK_ON, OBJPROP_BGCOLOR,
                         Enable_Fib_Risk_Allocation ? clrForestGreen : INACTIVE);
        ObjectSetInteger(0, B8_FIB_BTN_RISK_OFF, OBJPROP_BGCOLOR,
                         Enable_Fib_Risk_Allocation ? INACTIVE : clrIndianRed);
        ObjectSetInteger(0, B8_FIB_BTN_KEEP_SHALLOW, OBJPROP_BGCOLOR,
                         Fib_Elimination_Policy == B8_KEEP_SHALLOW_FIB ? ACTIVE : INACTIVE);
        ObjectSetInteger(0, B8_FIB_BTN_KEEP_DEEP, OBJPROP_BGCOLOR,
                         Fib_Elimination_Policy == B8_KEEP_DEEP_FIB ? ACTIVE : INACTIVE);
    }

    string status = "已选" + IntegerToString(selected_count) + "/8";
    if (Fib_Pending_Algorithm == B8_FIB_ALGO_V2)
        status += " | V2 | 风险/淘汰不适用";
    else
        status += " | 风险" + (Enable_Fib_Risk_Allocation ? "开" : "关")
                  + " | " + (Fib_Elimination_Policy == B8_KEEP_SHALLOW_FIB
                             ? "浅层优先" : "深层优先");
    if (selected_count == 0)
        status += " | 暂不挂单";
    else if (g_Runtime_Entry_Mode == B8_ENTRY_MARKET)
        status += " | 市价不挂单";
    else
        status += " | 新信号生效";

    ObjectSetString(0, B8_FIB_STATUS, OBJPROP_TEXT, status);
    ObjectSetInteger(0, B8_FIB_STATUS, OBJPROP_COLOR,
                     selected_count == 0 ? clrOrangeRed : C'150,210,255');

    string range_status = "";
    color range_color = C'190,205,220';
    if (selected_count == 0)
    {
        range_status = "理论区间：未选择Fib";
        range_color = clrOrangeRed;
    }
    else if (g_Runtime_Entry_Mode == B8_ENTRY_MARKET)
    {
        range_status = "理论区间：市价模式不创建挂单";
    }
    else
    {
        double levels[8] = {0.120, 0.214, 0.236, 0.382, 0.500, 0.618, 0.786, 0.880};
        double min_selected_level = 1.0;
        double max_selected_level = 0.0;

        for (int i = 0; i < 8; i++)
        {
            if (!g_Pending_Fib_Selected[i]) continue;
            if (levels[i] < min_selected_level) min_selected_level = levels[i];
            if (levels[i] > max_selected_level) max_selected_level = levels[i];
        }

        string lower_limit = "不限制";
        if (Enable_SL_Min_Filter)
        {
            double min_range = MathMax(1, SL_Min_Allowed_Points) /
                               max_selected_level;
            lower_limit = DoubleToString(min_range, 0);
        }

        string upper_limit = "不限制";
        if (Enable_SL_Tier_Routing)
        {
            int t2 = MathMax(1, SL_Tier_Threshold_2_Points);
            int max_sl = MathMax(t2, SL_Max_Allowed_Points);
            double max_range = max_sl / min_selected_level;
            upper_limit = DoubleToString(max_range, 0);
        }

        range_status = "理论区间：" + lower_limit + " ~ " + upper_limit + " points";
    }

    ObjectSetString(0, B8_FIB_RANGE_STATUS, OBJPROP_TEXT, range_status);
    ObjectSetInteger(0, B8_FIB_RANGE_STATUS, OBJPROP_COLOR, range_color);
}

//====================================================================
// 刷新历史信号补挂区域。
// 显示当前选择模式、历史K线shift及历史信号方向。
//====================================================================
void B8_UpdateHistoricalFibPanel()
{
    if (ObjectFind(0, B8_FIB_HISTORY_STATUS) < 0) return;

    ObjectSetString(0, B8_FIB_HISTORY_SHIFT, OBJPROP_TEXT,
                    IntegerToString(g_History_Selected_Shift));

    // 选择模式下优先提示用户点击主图，否则显示当前历史处理状态。
    string status = g_History_Select_Mode
                    ? "请点击主图上的已收盘K线"
                    : g_History_Status_Message;
    if (g_History_Preview_Valid)
    {
        // 根据历史信号缓冲区判断是否存在看涨或看跌信号。
        bool has_bull = (g_History_Preview_Signal.BullishReferencePrice != (double)EMPTY_VALUE &&
                         g_History_Preview_Signal.BullishReferencePrice != 0.0 &&
                         g_History_Preview_Signal.BullishStopLossPrice != (double)EMPTY_VALUE &&
                         g_History_Preview_Signal.BullishStopLossPrice != 0.0);
        bool has_bear = (g_History_Preview_Signal.BearishReferencePrice != (double)EMPTY_VALUE &&
                         g_History_Preview_Signal.BearishReferencePrice != 0.0 &&
                         g_History_Preview_Signal.BearishStopLossPrice != (double)EMPTY_VALUE &&
                         g_History_Preview_Signal.BearishStopLossPrice != 0.0);
        string direction = (has_bull && has_bear) ? "多空同时" : (has_bull ? "BUY" : "SELL");
        status = "K[" + IntegerToString(g_History_Selected_Shift) + "] " +
                 TimeToString(g_History_Preview_Signal.OpenTime, TIME_DATE | TIME_MINUTES) +
                 " " + direction;
    }

    ObjectSetString(0, B8_FIB_HISTORY_STATUS, OBJPROP_TEXT, status);
    ObjectSetInteger(0, B8_FIB_HISTORY_STATUS, OBJPROP_COLOR,
                     g_History_Select_Mode ? clrGold : C'190,205,220');
    ObjectSetString(0, B8_FIB_HISTORY_SELECT, OBJPROP_TEXT,
                    g_History_Select_Mode ? "点击主图" : "选择K线");
}

//#region MARK: 模块--自定义价格补挂面板新增显示
void B8_UpdateCustomFibPanel()
{
    if (ObjectFind(0, B8_CUSTOM_FIB_STATUS) < 0) return;

    color active_color = clrDeepSkyBlue;
    color inactive_color = clrDimGray;

    ObjectSetInteger(0, B8_CUSTOM_FIB_ORDER_AUTO, OBJPROP_BGCOLOR,
                     g_Custom_Fib_Order_Type == B8_CUSTOM_PENDING_AUTO
                     ? active_color : inactive_color);
    ObjectSetInteger(0, B8_CUSTOM_FIB_ORDER_BUY_LIMIT, OBJPROP_BGCOLOR,
                     g_Custom_Fib_Order_Type == B8_CUSTOM_PENDING_BUY_LIMIT
                     ? active_color : inactive_color);
    ObjectSetInteger(0, B8_CUSTOM_FIB_ORDER_BUY_STOP, OBJPROP_BGCOLOR,
                     g_Custom_Fib_Order_Type == B8_CUSTOM_PENDING_BUY_STOP
                     ? active_color : inactive_color);
    ObjectSetInteger(0, B8_CUSTOM_FIB_ORDER_SELL_LIMIT, OBJPROP_BGCOLOR,
                     g_Custom_Fib_Order_Type == B8_CUSTOM_PENDING_SELL_LIMIT
                     ? active_color : inactive_color);
    ObjectSetInteger(0, B8_CUSTOM_FIB_ORDER_SELL_STOP, OBJPROP_BGCOLOR,
                     g_Custom_Fib_Order_Type == B8_CUSTOM_PENDING_SELL_STOP
                     ? active_color : inactive_color);
    ObjectSetInteger(0, B8_CUSTOM_FIB_RISK_SHARED, OBJPROP_BGCOLOR,
                     g_Custom_Fib_Risk_Shared ? clrForestGreen : inactive_color);
    ObjectSetInteger(0, B8_CUSTOM_FIB_RISK_INDEPENDENT, OBJPROP_BGCOLOR,
                     g_Custom_Fib_Risk_Shared ? inactive_color : clrOrange);
    ObjectSetString(0, B8_CUSTOM_FIB_STATUS, OBJPROP_TEXT,
                    g_Custom_Fib_Status_Message);
}
//#endregion

//#endregion

//#region MARK: Fib模板面板
// 创建左上角的 Fib 成交前策略模板面板。
void B8_CreateFibTemplatePanel()
{
    const int x = 696;
    const int y = 20;
    const int w = 430;
    const int h = 360;

    if (ObjectFind(0, B8_FIB_TEMPLATE_PANEL_BG) < 0)
        ObjectCreate(0, B8_FIB_TEMPLATE_PANEL_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, B8_FIB_TEMPLATE_PANEL_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, B8_FIB_TEMPLATE_PANEL_BG, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, B8_FIB_TEMPLATE_PANEL_BG, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, B8_FIB_TEMPLATE_PANEL_BG, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, B8_FIB_TEMPLATE_PANEL_BG, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, B8_FIB_TEMPLATE_PANEL_BG, OBJPROP_BGCOLOR, C'25,35,30');
    ObjectSetInteger(0, B8_FIB_TEMPLATE_PANEL_BG, OBJPROP_COLOR, C'75,125,90');
    ObjectSetInteger(0, B8_FIB_TEMPLATE_PANEL_BG, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, B8_FIB_TEMPLATE_PANEL_BG, OBJPROP_ZORDER, 15);

    B8_RuntimeOrderMakeLabel(B8_FIB_TEMPLATE_TITLE, x + 10, y + 8,
                             "Fib成交前策略模板", clrWhite, 10);
    B8_RuntimeOrderMakeButton(B8_FIB_TEMPLATE_COLLAPSE, x + 344, y + 6,
                              76, 20,
                              g_Fib_Template_Panel_Collapsed ? "展开" : "折叠",
                              clrSteelBlue);
    B8_RuntimeOrderMakeLabel(B8_FIB_TEMPLATE_STATUS, x + 10, y + 28,
                             "空仓也可配置，成交后按Fib自动继承", clrLimeGreen, 8);
    for (int i = 0; i < 8; i++)
        B8_RuntimeOrderMakeButton(B8_FibTemplateRowName(i), x + 10,
                                  y + 52 + i * 23, w - 20, 20,
                                  "", clrDimGray);

    const int Y_GAP_LINE1 = 4;
    B8_RuntimeOrderMakeLabel("B8_FibTemplateLabelValue", x + 10, y + 243 + Y_GAP_LINE1,
                             "触发值", clrSilver, 8);
    B8_RuntimeOrderMakeEdit(B8_FIB_TEMPLATE_EDIT_VALUE, x + 55, y + 238 + Y_GAP_LINE1, 65, 20, "1.00");
    B8_RuntimeOrderMakeLabel("B8_FibTemplateLabelClose", x + 130, y + 243 + Y_GAP_LINE1,
                             "减仓%", clrSilver, 8);
    B8_RuntimeOrderMakeEdit(B8_FIB_TEMPLATE_EDIT_CLOSE, x + 175, y + 238 + Y_GAP_LINE1, 60, 20, "80.0");
    B8_RuntimeOrderMakeLabel("B8_FibTemplateLabelBE", x + 245, y + 243 + Y_GAP_LINE1,
                             "BE点", clrSilver, 8);
    B8_RuntimeOrderMakeEdit(B8_FIB_TEMPLATE_EDIT_BE, x + 285, y + 238 + Y_GAP_LINE1, 55, 20, "10");
    B8_RuntimeOrderMakeButton(B8_FIB_TEMPLATE_MODE_R, x + 345, y + 238 + Y_GAP_LINE1, 35, 20, "R", clrDeepSkyBlue);
    B8_RuntimeOrderMakeButton(B8_FIB_TEMPLATE_MODE_POINTS, x + 383, y + 238 + Y_GAP_LINE1, 37, 20, "点", clrDimGray);

    B8_RuntimeOrderMakeButton(B8_FIB_TEMPLATE_ACTION_PARTIAL, x + 10, y + 270, 82, 20, "仅减仓", clrDimGray);
    B8_RuntimeOrderMakeButton(B8_FIB_TEMPLATE_ACTION_BE, x + 96, y + 270, 82, 20, "仅保本", clrDimGray);
    B8_RuntimeOrderMakeButton(B8_FIB_TEMPLATE_ACTION_PARTIAL_BE, x + 182, y + 270, 92, 20, "减仓后保本", clrDeepSkyBlue);
    B8_RuntimeOrderMakeButton(B8_FIB_TEMPLATE_ACTION_CLOSE, x + 278, y + 270, 62, 20, "仅平仓", clrIndianRed);
    B8_RuntimeOrderMakeButton(B8_FIB_TEMPLATE_APPLY, x + 344, y + 270, 76, 20, "应用模板", clrForestGreen);
    B8_RuntimeOrderMakeButton(B8_FIB_TEMPLATE_PRESET_SAFE, x + 10, y + 298,
                              100, 20, "保守预设", clrSteelBlue);
    B8_RuntimeOrderMakeButton(B8_FIB_TEMPLATE_PRESET_STD, x + 115, y + 298,
                              100, 20, "标准预设", clrSteelBlue);
    B8_RuntimeOrderMakeButton(B8_FIB_TEMPLATE_PRESET_FAST, x + 220, y + 298,
                              100, 20, "激进预设", clrDarkOrange);
    B8_RuntimeOrderMakeButton(B8_FIB_TEMPLATE_RESET, x + 10, y + 324,
                              130, 20, "全部恢复默认", clrSlateGray);
    B8_SyncFibTemplateInputs();
    // B8_UpdateFibTemplatePanel(); // 已迁移到 OnInit() 和展开分支，创建函数只负责创建和同步输入框，保留供回溯
}

// 刷新八个 Fib 模板按钮、状态提示和动作按钮高亮。
// 输入框不在此处持续回写，避免 OnTick 抢占用户编辑内容。
void B8_UpdateFibTemplatePanel()
{
    if (ObjectFind(0, B8_FIB_TEMPLATE_PANEL_BG) < 0) return;
    ObjectSetString(0, B8_FIB_TEMPLATE_COLLAPSE, OBJPROP_TEXT,
                    g_Fib_Template_Panel_Collapsed ? "展开" : "折叠");
    if (g_Fib_Template_Panel_Collapsed) return;
    // OnTick 只刷新列表和按钮，绝不回写输入框，避免抢夺编辑焦点或覆盖用户文本。
    for (int i = 0; i < 8; i++)
    {
        ObjectSetString(0, B8_FibTemplateRowName(i), OBJPROP_TEXT,
                        "Fib " + StringSubstr(B8_FibTemplateCode(i), 0, 1) + "." +
                        StringSubstr(B8_FibTemplateCode(i), 1) + " | " +
                        (g_Fib_Order_Templates[i].configured ? "已启用" : "未启用") + " | " +
                        (g_Fib_Order_Templates[i].trigger_mode == B8_ORDER_TRIGGER_R
                         ? DoubleToString(g_Fib_Order_Templates[i].trigger_r, 2) + "R"
                         : DoubleToString(g_Fib_Order_Templates[i].trigger_points, 0) + "点") +
                        " | " + DoubleToString(g_Fib_Order_Templates[i].partial_close_percent, 0) + "%" +
                        " | 动作:" + B8_RuntimeOrderActionText(g_Fib_Order_Templates[i].protection_mode) +
                        (i == g_Fib_Template_Selected ? "  [编辑]" : ""));
        ObjectSetInteger(0, B8_FibTemplateRowName(i), OBJPROP_BGCOLOR,
                         i == g_Fib_Template_Selected ? clrSeaGreen : clrDimGray);
    }
    ObjectSetString(0, B8_FIB_TEMPLATE_STATUS, OBJPROP_TEXT,
                    "当前编辑 Fib " + StringSubstr(B8_FibTemplateCode(g_Fib_Template_Selected), 0, 1) + "." +
                    StringSubstr(B8_FibTemplateCode(g_Fib_Template_Selected), 1) +
                    "，模板仅当前运行周期有效");
    ObjectSetInteger(0, B8_FIB_TEMPLATE_MODE_R, OBJPROP_BGCOLOR,
                     g_Fib_Order_Templates[g_Fib_Template_Selected].trigger_mode == B8_ORDER_TRIGGER_R ? clrDeepSkyBlue : clrDimGray);
    ObjectSetInteger(0, B8_FIB_TEMPLATE_MODE_POINTS, OBJPROP_BGCOLOR,
                     g_Fib_Order_Templates[g_Fib_Template_Selected].trigger_mode == B8_ORDER_TRIGGER_POINTS ? clrDeepSkyBlue : clrDimGray);
    ObjectSetInteger(0, B8_FIB_TEMPLATE_ACTION_PARTIAL, OBJPROP_BGCOLOR,
                     g_Fib_Order_Templates[g_Fib_Template_Selected].protection_mode == B8_ORDER_PARTIAL_ONLY ? clrDeepSkyBlue : clrDimGray);
    ObjectSetInteger(0, B8_FIB_TEMPLATE_ACTION_BE, OBJPROP_BGCOLOR,
                     g_Fib_Order_Templates[g_Fib_Template_Selected].protection_mode == B8_ORDER_BE_ONLY ? clrDeepSkyBlue : clrDimGray);
    ObjectSetInteger(0, B8_FIB_TEMPLATE_ACTION_PARTIAL_BE, OBJPROP_BGCOLOR,
                     g_Fib_Order_Templates[g_Fib_Template_Selected].protection_mode == B8_ORDER_PARTIAL_BE ? clrDeepSkyBlue : clrDimGray);
    ObjectSetInteger(0, B8_FIB_TEMPLATE_ACTION_CLOSE, OBJPROP_BGCOLOR,
                     g_Fib_Order_Templates[g_Fib_Template_Selected].protection_mode == B8_ORDER_CLOSE_ONLY ? clrIndianRed : clrDimGray);
}
//#endregion

//#region MARK: 运行时订单面板
// 创建左上角的运行时订单策略面板及其订单列表、编辑控件和操作按钮。
void B8_CreateRuntimeOrderPanel()
{
    const int x = 256;
    const int y = 20;
    const int w = 430;
    const int h = 678;
    const int row_x = x + 10;
    const int row_w = w - 20;
    const int row_h = 20;
    const int row_gap = 3;

    if (ObjectFind(0, B8_RUNTIME_ORDER_PANEL_BG) < 0)
        ObjectCreate(0, B8_RUNTIME_ORDER_PANEL_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_PANEL_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_PANEL_BG, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_PANEL_BG, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_PANEL_BG, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_PANEL_BG, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_PANEL_BG, OBJPROP_BGCOLOR, C'22,27,38');
    ObjectSetInteger(0, B8_RUNTIME_ORDER_PANEL_BG, OBJPROP_COLOR, C'70,95,125');
    ObjectSetInteger(0, B8_RUNTIME_ORDER_PANEL_BG, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_PANEL_BG, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_PANEL_BG, OBJPROP_ZORDER, 15);

    B8_RuntimeOrderMakeLabel(B8_RUNTIME_ORDER_TITLE, x + 10, y + 8,
                             "订单运行时策略", clrWhite, 10);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_ORDER_COLLAPSE, x + 344, y + 6,
                              76, 20,
                              g_Runtime_Order_Panel_Collapsed ? "展开" : "折叠",
                              clrSteelBlue);
    B8_RuntimeOrderMakeLabel(B8_RUNTIME_ORDER_STATUS, x + 10, y + 28,
                             "等待订单", C'150,210,255', 8);

    for (int i = 0; i < 10; i++)
        B8_RuntimeOrderMakeButton(B8_RuntimeOrderRowName(i), row_x,
                                  y + 52 + i * (row_h + row_gap), row_w, row_h,
                                  "", clrDimGray);

    // 新增：仅将订单持仓列表按钮的文字设置为左对齐，其他按钮保持原样。
    for (int i = 0; i < 10; i++)
        ObjectSetInteger(0, B8_RuntimeOrderRowName(i), OBJPROP_ALIGN, ALIGN_LEFT);

    B8_RuntimeOrderMakeLabel(B8_RUNTIME_ORDER_DETAIL1, x + 10, y + 285,
                             "当前订单：--", C'190,205,220', 8);
    B8_RuntimeOrderMakeLabel(B8_RUNTIME_ORDER_DETAIL2, x + 10, y + 303,
                             "策略来源：--", C'190,205,220', 8);
    B8_RuntimeOrderMakeLabel(B8_RUNTIME_ORDER_DETAIL3, x + 10, y + 321,
                             "当前R：--", C'190,205,220', 8);
    B8_RuntimeOrderMakeLabel(B8_RUNTIME_ORDER_DETAIL4, x + 10, y + 339,
                             "运行时修改仅当前运行周期有效", clrGold, 8);

    // 拉开一点距离
    const int Y_GAP_LINE1 = 5;
    B8_RuntimeOrderMakeLabel("B8_RuntimeOrderLabelR", x + 10, y + 359 + Y_GAP_LINE1,
                             "触发R", clrSilver, 8);
    B8_RuntimeOrderMakeEdit(B8_RUNTIME_ORDER_EDIT_R, x + 55, y + 354 + Y_GAP_LINE1, 55, 20, "1.00");
    B8_RuntimeOrderMakeLabel("B8_RuntimeOrderLabelClose", x + 120, y + 359 + Y_GAP_LINE1,
                             "减仓%", clrSilver, 8);
    B8_RuntimeOrderMakeEdit(B8_RUNTIME_ORDER_EDIT_CLOSE, x + 165, y + 354 + Y_GAP_LINE1, 55, 20, "80.0");
    B8_RuntimeOrderMakeLabel("B8_RuntimeOrderLabelBE", x + 230, y + 359 + Y_GAP_LINE1,
                             "BE点", clrSilver, 8);
    B8_RuntimeOrderMakeEdit(B8_RUNTIME_ORDER_EDIT_BE, x + 270, y + 354 + Y_GAP_LINE1, 55, 20, "10");

    B8_RuntimeOrderMakeButton(B8_RUNTIME_ORDER_MODE_R, x + 335, y + 354 + Y_GAP_LINE1, 38, 20, "R", clrDeepSkyBlue);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_ORDER_MODE_POINTS, x + 376, y + 354 + Y_GAP_LINE1, 44, 20, "点数", clrDimGray);

    B8_RuntimeOrderMakeButton(B8_RUNTIME_ORDER_ACTION_PARTIAL, x + 10, y + 386, 82, 20, "仅减仓", clrDimGray);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_ORDER_ACTION_BE, x + 96, y + 386, 82, 20, "仅保本", clrDimGray);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_ORDER_ACTION_PARTIAL_BE, x + 182, y + 386, 92, 20, "减仓后保本", clrDeepSkyBlue);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_ORDER_ACTION_CLOSE, x + 278, y + 386, 62, 20, "仅平仓", clrIndianRed);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_ORDER_APPLY, x + 344, y + 386, 76, 20, "应用", clrForestGreen);

    B8_RuntimeOrderMakeButton(B8_RUNTIME_ORDER_DEFAULT, x + 10, y + 412, 130, 20, "恢复订单级", clrSlateGray);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_ORDER_DISABLE, x + 146, y + 412, 130, 20, "关闭此单保护", clrIndianRed);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_ORDER_APPLY_SCOPE, x + 282, y + 412,
                              138, 20, "范围:当前", clrDeepSkyBlue);

    // 在订单级保护操作与手动平仓模块之间增加固定像素分割线。
    if (ObjectFind(0, B8_RUNTIME_ORDER_CLOSE_DIVIDER) < 0)
        ObjectCreate(0, B8_RUNTIME_ORDER_CLOSE_DIVIDER,
                     OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_CLOSE_DIVIDER, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_CLOSE_DIVIDER, OBJPROP_XDISTANCE, x + 10);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_CLOSE_DIVIDER, OBJPROP_YDISTANCE, y + 443);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_CLOSE_DIVIDER, OBJPROP_XSIZE, w - 20);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_CLOSE_DIVIDER, OBJPROP_YSIZE, 2);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_CLOSE_DIVIDER, OBJPROP_BGCOLOR, C'70,95,125');
    ObjectSetInteger(0, B8_RUNTIME_ORDER_CLOSE_DIVIDER, OBJPROP_COLOR, C'70,95,125');
    ObjectSetInteger(0, B8_RUNTIME_ORDER_CLOSE_DIVIDER, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_CLOSE_DIVIDER, OBJPROP_ZORDER, 20);

    const int row_gap_2 = 20;

    // 手动平仓模块：范围、比例平仓和按lot平仓均放在运行时策略面板底部。
    B8_RuntimeOrderMakeLabel("B8_RuntimeCloseScopeLabel", x + 10, y + 440 + row_gap_2,
                             "范围", clrSilver, 8);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_CLOSE_SCOPE_ONE, x + 45, y + 436 + row_gap_2,
                              115, 20, "选中单笔", clrDeepSkyBlue);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_CLOSE_SCOPE_ALL, x + 165, y + 436 + row_gap_2,
                              115, 20, "品种+Magic", clrDimGray);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_ORDER_BREAKEVEN, x + 285, y + 436 + row_gap_2,
                              66, 20, "保本", clrGold);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_ORDER_TAKEOVER, x + 354, y + 436 + row_gap_2,
                              66, 20, "全接管", clrOrange);

    B8_RuntimeOrderMakeLabel("B8_RuntimeClosePercentLabel", x + 10, y + 468 + row_gap_2,
                             "比例", clrSilver, 8);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_CLOSE_PERCENT_50, x + 45, y + 464 + row_gap_2,
                              48, 20, "50%", clrDimGray);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_CLOSE_PERCENT_80, x + 96, y + 464 + row_gap_2,
                              48, 20, "80%", clrDimGray);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_CLOSE_PERCENT_100, x + 147, y + 464 + row_gap_2,
                              55, 20, "100%", clrIndianRed);
    B8_RuntimeOrderMakeEdit(B8_RUNTIME_CLOSE_PERCENT_EDIT, x + 207, y + 464 + row_gap_2,
                            55, 20, "50");
    B8_RuntimeOrderMakeButton(B8_RUNTIME_CLOSE_PERCENT_GO, x + 267, y + 464 + row_gap_2,
                              55, 20, "Go", clrForestGreen);

    B8_RuntimeOrderMakeLabel("B8_RuntimeCloseLotsLabel", x + 10, y + 496 + row_gap_2,
                             "手数", clrSilver, 8);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_CLOSE_LOTS_1, x + 45, y + 492 + row_gap_2,
                              48, 20, "1", clrDimGray);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_CLOSE_LOTS_01, x + 96, y + 492 + row_gap_2,
                              48, 20, "0.1", clrDimGray);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_CLOSE_LOTS_001, x + 147, y + 492 + row_gap_2,
                              55, 20, "0.01", clrDimGray);
    B8_RuntimeOrderMakeEdit(B8_RUNTIME_CLOSE_LOTS_EDIT, x + 207, y + 492 + row_gap_2,
                            55, 20, "0.10");
    B8_RuntimeOrderMakeButton(B8_RUNTIME_CLOSE_LOTS_GO, x + 267, y + 492 + row_gap_2,
                              55, 20, "Go", clrViolet);

    // 快捷订单管理：本按钮只处理当前品种+当前Bot8 Magic，全按钮处理全账户。
    B8_RuntimeOrderMakeLabel("B8_RuntimeQuickTitle", x + 10, y + 520 + row_gap_2,
                             "快捷订单管理", clrWhite, 9);
    B8_RuntimeOrderMakeLabel(B8_RUNTIME_QUICK_STATUS, x + 230, y + 520 + row_gap_2,
                             "快捷操作待命", clrGold, 8);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_QUICK_THIS_ALL, x + 10, y + 543 + row_gap_2,
                              78, 22, "本全平", clrIndianRed);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_QUICK_THIS_LOSS, x + 92, y + 543 + row_gap_2,
                              78, 22, "亏平", clrDarkOrange);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_QUICK_THIS_PROFIT, x + 174, y + 543 + row_gap_2,
                              78, 22, "盈平", clrForestGreen);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_QUICK_THIS_SELL, x + 256, y + 543 + row_gap_2,
                              78, 22, "空平", clrSteelBlue);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_QUICK_THIS_BUY, x + 338, y + 543 + row_gap_2,
                              78, 22, "多平", clrSteelBlue);

    B8_RuntimeOrderMakeButton(B8_RUNTIME_QUICK_ALL_LOSS, x + 10, y + 571 + row_gap_2,
                              98, 22, "亏全平", clrDarkOrange);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_QUICK_ALL_PROFIT, x + 114, y + 571 + row_gap_2,
                              98, 22, "盈全平", clrForestGreen);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_QUICK_ALL_SELL, x + 218, y + 571 + row_gap_2,
                              98, 22, "空全平", clrSteelBlue);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_QUICK_ALL_BUY, x + 322, y + 571 + row_gap_2,
                              98, 22, "多全平", clrSteelBlue);

    B8_RuntimeOrderMakeButton(B8_RUNTIME_QUICK_CLEAR_ALL, x + 10, y + 599 + row_gap_2,
                              198, 22, "清仓", clrCrimson);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_QUICK_DELETE_PENDING, x + 212, y + 599 + row_gap_2,
                              208, 22, "删挂", clrSlateGray);
    B8_RuntimeOrderMakeButton(B8_RUNTIME_QUICK_DELETE_MANAGED, x + 10, y + 627 + row_gap_2,
                              410, 22, "本品种删挂", clrSteelBlue);
    // B8_UpdateRuntimeOrderPanel(); // 已迁移到 OnInit()，创建函数只负责创建和配置对象，保留供回溯
}

// 刷新订单列表、当前订单详情以及运行时策略按钮的选中状态。
void B8_UpdateRuntimeOrderPanel()
{
    if (ObjectFind(0, B8_RUNTIME_ORDER_PANEL_BG) < 0) return;
    ObjectSetString(0, B8_RUNTIME_ORDER_COLLAPSE, OBJPROP_TEXT,
                    g_Runtime_Order_Panel_Collapsed ? "展开" : "折叠");
    if (g_Runtime_Order_Panel_Collapsed) return;

    B8_RuntimeOrderPruneSelectedTickets();
    B8_RuntimeOrderUpdateApplyScopeControl();

    // 每次刷新都同步手动平仓范围，避免面板折叠/展开后高亮状态丢失。
    ObjectSetInteger(0, B8_RUNTIME_CLOSE_SCOPE_ONE, OBJPROP_BGCOLOR,
                     g_Runtime_Close_All_Managed ? clrDimGray : clrDeepSkyBlue);
    ObjectSetInteger(0, B8_RUNTIME_CLOSE_SCOPE_ALL, OBJPROP_BGCOLOR,
                     g_Runtime_Close_All_Managed ? clrDeepSkyBlue : clrDimGray);

    g_Runtime_Order_Row_Count = 0;
    for (int i = 0; i < OrdersTotal() && g_Runtime_Order_Row_Count < 10; i++)
    {
        // 旧版静默筛选逻辑：
        // if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        // if (!B8_IsManagedOrder()) continue;
        // if (OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            B8_LogRuntimeOrderFilterMismatch(i, -1, "OrderSelect失败");
            continue;
        }

        if (!B8_IsManagedOrder())
        {
            string mismatch_reason = "";
            if (OrderSymbol() != _Symbol)
                mismatch_reason = mismatch_reason + "品种不匹配;";
            if (!B8_IsManagedOrderMagic(OrderMagicNumber()))
                mismatch_reason = mismatch_reason + "Magic不匹配;";
            if (mismatch_reason == "")
                mismatch_reason = "不属于Bot8管理订单";
            B8_LogRuntimeOrderFilterMismatch(i, OrderTicket(), mismatch_reason);
            continue;
        }

        if (OrderType() != OP_BUY && OrderType() != OP_SELL)
        {
            B8_LogRuntimeOrderFilterMismatch(i, OrderTicket(),
                                              "订单类型不是已成交市价单");
            continue;
        }
        g_Runtime_Order_Row_Tickets[g_Runtime_Order_Row_Count++] = OrderTicket();
    }

    for (int row = 0; row < 10; row++)
    {
        string name = B8_RuntimeOrderRowName(row);
        if (row >= g_Runtime_Order_Row_Count)
        {
            ObjectSetString(0, name, OBJPROP_TEXT, "");
            ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'45,50,60');
            continue;
        }

        int ticket = g_Runtime_Order_Row_Tickets[row];
        if (!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) continue;
        int logical_magic = OrderMagicNumber();
        // 旧版方向文本：
        // string direction = OrderType() == OP_BUY ? "BUY" : "SELL";
        int override_index = B8_FindRuntimeOrderOverride(logical_magic);
        string fib = override_index >= 0
                 ? g_Runtime_Order_Overrides[override_index].fib_code
                 : B8_RuntimeOrderFibCode(OrderComment());
        // 旧版来源文本：
        // string source = override_index >= 0 ? "运行时" : "默认";
        double current_r = B8_RuntimeOrderCurrentR(ticket);
        double target_r = override_index >= 0 ? g_Runtime_Order_Overrides[override_index].trigger_r
                                              : g_Order_Runtime_Settings.order_trigger_r;
        // 旧版订单行文本：
        // string text = IntegerToString(ticket) + " | F" + fib + " | " + direction +
        //               " | lot: " + DoubleToString(OrderLots(), 2) +
        //               " | " + DoubleToString(current_r, 2) + "R/" +
        //               DoubleToString(target_r, 2) + "R | " + source;

        // 新版订单行文本：使用短字段显示单笔预估止损，避免超出面板宽度。
        double stop_risk = 0.0;
        string stop_risk_text = "SL--";
        if (B8_TryGetCurrentOrderStopRisk(stop_risk))
            stop_risk_text = "SL-" + DoubleToString(stop_risk, 2);

        string short_direction = OrderType() == OP_BUY ? "多" : "空";
        string short_source = override_index >= 0 ? "运" : "默";
        // 旧版订单行文本：
        // string text = IntegerToString(ticket) + "|F" + fib + "|" + short_direction +
        //               "|" + DoubleToString(OrderLots(), 2) + "手|" + stop_risk_text +
        //               "|" + DoubleToString(current_r, 2) + "/" +
        //               DoubleToString(target_r, 2) + "|" + short_source;
        string selection_mark = B8_RuntimeOrderTicketIsSelected(ticket) ? "[X] " : "[ ] ";
        string text = selection_mark + IntegerToString(ticket) + "|F" + fib + "|" + short_direction +
                  "|" + DoubleToString(OrderLots(), 2) + "手|" + stop_risk_text +
                  "|" + DoubleToString(current_r, 2) + "/" +
                  DoubleToString(target_r, 2) + "|" + short_source;
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        // 旧版订单行颜色：
        // ObjectSetInteger(0, name, OBJPROP_BGCOLOR,
        //                  ticket == g_Runtime_Order_Selected_Ticket ? clrSteelBlue : clrDimGray);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR,
                 ticket == g_Runtime_Order_Selected_Ticket
                 ? clrSteelBlue
                 : (B8_RuntimeOrderTicketIsSelected(ticket)
                    ? C'55,95,125' : clrDimGray));
    }

    if (!B8_RuntimeOrderIsOpen(g_Runtime_Order_Selected_Ticket) &&
        !g_Runtime_Order_Inputs_Editing)
    {
        g_Runtime_Order_Selected_Ticket = g_Runtime_Order_Row_Count > 0
                                          ? g_Runtime_Order_Row_Tickets[0] : -1;
        if (g_Runtime_Order_Selected_Ticket > 0)
            B8_RuntimeOrderSelectTicket(g_Runtime_Order_Selected_Ticket);
    }

    if (g_Runtime_Order_Selected_Ticket > 0 &&
        B8_RuntimeOrderIsOpen(g_Runtime_Order_Selected_Ticket))
    {
        if (!OrderSelect(g_Runtime_Order_Selected_Ticket, SELECT_BY_TICKET, MODE_TRADES))
        {
            // B8_UpdateRuntimeOrderPanel(); // 已改为本次刷新直接降级，避免订单选择失败时递归刷新
            g_Runtime_Order_Selected_Ticket = -1;
            ObjectSetString(0, B8_RUNTIME_ORDER_STATUS, OBJPROP_TEXT,
                            "暂无已成交订单");
            ObjectSetString(0, B8_RUNTIME_ORDER_DETAIL1, OBJPROP_TEXT,
                            "当前订单：--");
            ObjectSetString(0, B8_RUNTIME_ORDER_DETAIL2, OBJPROP_TEXT,
                            "策略来源：--");
            ObjectSetString(0, B8_RUNTIME_ORDER_DETAIL3, OBJPROP_TEXT,
                            "当前R：--");
            return;
        }
        int logical_magic = OrderMagicNumber();
        int override_index = B8_FindRuntimeOrderOverride(logical_magic);
        string source = override_index >= 0 ? "运行时覆盖" : "订单级默认";
        string fib = override_index >= 0
                 ? g_Runtime_Order_Overrides[override_index].fib_code
                 : B8_RuntimeOrderFibCode(OrderComment());
        string direction = OrderType() == OP_BUY ? "BUY" : "SELL";
        ObjectSetString(0, B8_RUNTIME_ORDER_DETAIL1, OBJPROP_TEXT,
                        "当前订单：" + IntegerToString(g_Runtime_Order_Selected_Ticket) +
                        " F" + fib + " " + direction +
                        " | lot: " + DoubleToString(OrderLots(), 2));
        ObjectSetString(0, B8_RUNTIME_ORDER_DETAIL2, OBJPROP_TEXT,
                        "策略来源：" + source + " | 动作：" +
                        B8_RuntimeOrderActionText(override_index >= 0
                                                   ? g_Runtime_Order_Overrides[override_index].protection_mode
                                                   : g_Order_Runtime_Settings.order_protection_mode));
        ObjectSetString(0, B8_RUNTIME_ORDER_DETAIL3, OBJPROP_TEXT,
                        "当前R：" + DoubleToString(B8_RuntimeOrderCurrentR(g_Runtime_Order_Selected_Ticket), 2));
        ObjectSetString(0, B8_RUNTIME_ORDER_STATUS, OBJPROP_TEXT,
                        "已成交订单 " + IntegerToString(g_Runtime_Order_Row_Count) + " 笔 | 已选 " +
                        IntegerToString(g_Runtime_Order_Selected_Ticket));
    }
    else
    {
        ObjectSetString(0, B8_RUNTIME_ORDER_STATUS, OBJPROP_TEXT, "暂无已成交订单");
        ObjectSetString(0, B8_RUNTIME_ORDER_DETAIL1, OBJPROP_TEXT, "当前订单：--");
        ObjectSetString(0, B8_RUNTIME_ORDER_DETAIL2, OBJPROP_TEXT, "策略来源：--");
        ObjectSetString(0, B8_RUNTIME_ORDER_DETAIL3, OBJPROP_TEXT, "当前R：--");
    }

    ObjectSetString(0, "B8_RuntimeOrderLabelR", OBJPROP_TEXT,
                    g_Runtime_Order_Edit_Mode == B8_ORDER_TRIGGER_R ? "触发R" : "触发点");
    ObjectSetInteger(0, B8_RUNTIME_ORDER_MODE_R, OBJPROP_BGCOLOR,
                     g_Runtime_Order_Edit_Mode == B8_ORDER_TRIGGER_R ? clrDeepSkyBlue : clrDimGray);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_MODE_POINTS, OBJPROP_BGCOLOR,
                     g_Runtime_Order_Edit_Mode == B8_ORDER_TRIGGER_POINTS ? clrDeepSkyBlue : clrDimGray);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_ACTION_PARTIAL, OBJPROP_BGCOLOR,
                     g_Runtime_Order_Edit_Action == B8_ORDER_PARTIAL_ONLY ? clrDeepSkyBlue : clrDimGray);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_ACTION_BE, OBJPROP_BGCOLOR,
                     g_Runtime_Order_Edit_Action == B8_ORDER_BE_ONLY ? clrDeepSkyBlue : clrDimGray);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_ACTION_PARTIAL_BE, OBJPROP_BGCOLOR,
                     g_Runtime_Order_Edit_Action == B8_ORDER_PARTIAL_BE ? clrDeepSkyBlue : clrDimGray);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_ACTION_CLOSE, OBJPROP_BGCOLOR,
                     g_Runtime_Order_Edit_Action == B8_ORDER_CLOSE_ONLY ? clrIndianRed : clrDimGray);
    B8_RuntimeOrderUpdateApplyScopeControl();
}
//#endregion

//#region MARK: 面板显示隐藏与折叠
//====================================================================
// 参数相关核心面板：统一显示/隐藏及显示后的状态同步
// 风险面板保持独立显示，不参与此协调。
//====================================================================
void B8_SetCorePanelsVisible(bool visible)
{
    B8_SetSettingsPanelVisible(visible);
    B8_SetFibPanelVisible(visible);
    B8_SetOrderPanelVisible(visible);

    if (visible)
    {
        B8_WriteEditFields();
        B8_UpdateSettingsPanel();
        B8_UpdateFibPanel();
        B8_UpdateHistoricalFibPanel();
        B8_UpdateCustomFibPanel();
        B8_WriteOrderEditFields();
        B8_UpdateOrderPanel();
    }
}

//====================================================================
// 参数面板：统一显示/隐藏全部参数对象
// 隐藏时删除参数对象，显示时调用现有创建函数重建，避免周期可见性属性失效。
//====================================================================
void B8_SetSettingsPanelVisible(bool visible)
{
    string objects[] =
    {
        B8_SETTINGS_BG, B8_SETTINGS_TITLE,
        B8_STATUS_LINE1, B8_STATUS_LINE2, B8_STATUS_LINE3,
        B8_STATUS_LINE4, B8_STATUS_LINE5, B8_STATUS_LINE6, B8_STATUS_EDIT,
        "B8_LblPosMode", B8_BTN_POS_FIXED, B8_BTN_POS_RISK,
        "B8_LblFixedLot", B8_EDIT_FIXED_LOT,
        "B8_LblRiskMode", B8_BTN_RISK_MONEY, B8_BTN_RISK_PCT,
        "B8_LblRiskValue", B8_EDIT_RISK_VALUE,
        "B8_LblTargetPct", B8_EDIT_TARGET_PCT,
        "B8_LblClosePct", B8_EDIT_CLOSE_PCT,
        "B8_LblBEBuffer", B8_EDIT_BE_BUFFER,
        "B8_LblEPEnabled", B8_BTN_EP_TOGGLE,
        "B8_LblEPAction", B8_BTN_EP_ACTION_PARTIAL_BE, B8_BTN_EP_ACTION_CLOSE,
        B8_BTN_PRESET_SAFE, B8_BTN_PRESET_STD, B8_BTN_PRESET_FAST,
        B8_BTN_APPLY, B8_BTN_RESTORE, B8_BTN_DEFAULTS
    };

    if (visible)
    {
        // 参数背景不存在时才重建，避免重复创建和覆盖当前输入框内容。
        if (ObjectFind(0, B8_SETTINGS_BG) < 0)
            B8_CreateSettingsPanel();
        // B8_SetFibPanelVisible(true); // 已迁移到调用方，原调用保留供回溯
        // B8_SetOrderPanelVisible(true); // 已迁移到调用方，原调用保留供回溯
    }
    else
    {
        B8_SyncSettingsBeforeHide();

        // 删除完整参数面板，主控面板及其“参数”入口不在此清单内。
        for (int i = 0; i < ArraySize(objects); i++)
        {
            if (ObjectFind(0, objects[i]) >= 0)
                ObjectDelete(0, objects[i]);
        }
        // B8_SetFibPanelVisible(false); // 已迁移到调用方，原调用保留供回溯
        // B8_SetOrderPanelVisible(false); // 已迁移到调用方，原调用保留供回溯
    }

    // 主控入口始终可见，按钮文字直接反馈下一步操作。
    ObjectSetString(0, B8_BTN_SETTINGS_VISIBILITY, OBJPROP_TEXT,
                    visible ? "隐藏" : "参数");
    ObjectSetInteger(0, B8_BTN_SETTINGS_VISIBILITY, OBJPROP_BGCOLOR,
                     visible ? clrSteelBlue : clrDimGray);
}

//====================================================================
// Fib挂单选择区域：显示/隐藏
//====================================================================
void B8_SetFibPanelVisible(bool visible)
{
    string objects[] =
    {
        B8_FIB_PANEL_BG, B8_FIB_PANEL_TITLE, B8_FIB_STATUS, B8_FIB_RANGE_STATUS,
        B8_FIB_BTN_0120, B8_FIB_BTN_0214, B8_FIB_BTN_0236, B8_FIB_BTN_0382,
        B8_FIB_BTN_0500, B8_FIB_BTN_0618, B8_FIB_BTN_0786, B8_FIB_BTN_0880,
        B8_FIB_BTN_ALL, B8_FIB_BTN_NONE,
        B8_FIB_BTN_PRESET_1, B8_FIB_BTN_PRESET_2, B8_FIB_BTN_PRESET_3,
        "B8_FibStrategyTitle", "B8_FibRiskLabel", "B8_FibPolicyLabel",
        B8_FIB_BTN_RISK_ON, B8_FIB_BTN_RISK_OFF,
        B8_FIB_BTN_KEEP_SHALLOW, B8_FIB_BTN_KEEP_DEEP
        , B8_FIB_HISTORY_TITLE, B8_FIB_HISTORY_STATUS, B8_FIB_HISTORY_SHIFT,
        "B8_FibHistoryShiftLabel", B8_FIB_HISTORY_SELECT,
        B8_FIB_HISTORY_CANCEL, B8_FIB_HISTORY_EXECUTE, B8_FIB_HISTORY_DELETE,
        B8_CUSTOM_FIB_TITLE, B8_CUSTOM_FIB_ENTRY_LABEL,
        B8_CUSTOM_FIB_ENTRY_EDIT, B8_CUSTOM_FIB_PICK_ENTRY,
        B8_CUSTOM_FIB_STOP_LABEL,
        B8_CUSTOM_FIB_STOP_EDIT, B8_CUSTOM_FIB_ORDER_AUTO,
        B8_CUSTOM_FIB_PICK_STOP,
        B8_CUSTOM_FIB_ORDER_BUY_LIMIT, B8_CUSTOM_FIB_ORDER_BUY_STOP,
        B8_CUSTOM_FIB_ORDER_SELL_LIMIT, B8_CUSTOM_FIB_ORDER_SELL_STOP,
        B8_CUSTOM_FIB_RISK_SHARED, B8_CUSTOM_FIB_RISK_INDEPENDENT,
        B8_CUSTOM_FIB_EXECUTE, B8_CUSTOM_FIB_STATUS
    };

    if (visible)
    {
        if (ObjectFind(0, B8_FIB_PANEL_BG) < 0)
            B8_CreateFibPanel();
    }
    else
    {
        for (int i = 0; i < ArraySize(objects); i++)
        {
            if (ObjectFind(0, objects[i]) >= 0)
                ObjectDelete(0, objects[i]);
        }
    }
}

//====================================================================
// 订单管理子面板：显示/隐藏
//====================================================================
void B8_SetOrderPanelVisible(bool visible)
{
    string objects[] =
    {
        B8_ORDER_PANEL_BG, B8_ORDER_PANEL_TITLE,
        B8_ORDER_STATUS_LINE1, B8_ORDER_STATUS_LINE2, B8_ORDER_STATUS_LINE3,
        B8_ORDER_STATUS_MESSAGE,
        "B8_LblOrderEnabled", B8_BTN_ORDER_ENABLED,
        "B8_LblOrderTriggerMode", B8_BTN_ORDER_TRIGGER_POINTS, B8_BTN_ORDER_TRIGGER_R,
        "B8_LblOrderTriggerPoints", B8_ORDER_EDIT_TRIGGER_POINTS,
        "B8_LblOrderTriggerR", B8_ORDER_EDIT_TRIGGER_R,
        "B8_LblOrderClosePct", B8_ORDER_EDIT_CLOSE_PCT,
        "B8_LblOrderBEBuffer", B8_ORDER_EDIT_BE_BUFFER,
        "B8_LblOrderMode", B8_BTN_ORDER_MODE_PARTIAL,
        B8_BTN_ORDER_MODE_BE, B8_BTN_ORDER_MODE_PARTIAL_BE, B8_BTN_ORDER_MODE_CLOSE,
        B8_BTN_ORDER_PRESET_SAFE, B8_BTN_ORDER_PRESET_STD,
        B8_BTN_ORDER_PRESET_FAST,
        B8_BTN_ORDER_APPLY, B8_BTN_ORDER_RESTORE
    };

    if (visible)
    {
        if (ObjectFind(0, B8_ORDER_PANEL_BG) < 0)
            B8_CreateOrderPanel();
    }
    else
    {
        B8_SyncOrderSettingsBeforeHide();

        for (int i = 0; i < ArraySize(objects); i++)
        {
            if (ObjectFind(0, objects[i]) >= 0)
                ObjectDelete(0, objects[i]);
        }
    }
}

// 折叠或展开运行时订单策略面板。
// 折叠时只保留背景、标题和标题栏按钮；展开时复用原创建函数恢复全部控件。
void B8_SetRuntimeOrderPanelCollapsed(bool collapsed)
{
    g_Runtime_Order_Panel_Collapsed = collapsed;
    if (ObjectFind(0, B8_RUNTIME_ORDER_PANEL_BG) < 0) return;

    if (!collapsed)
    {
        B8_CreateRuntimeOrderPanel();
        if (B8_RuntimeOrderIsOpen(g_Runtime_Order_Selected_Ticket))
            B8_RuntimeOrderSelectTicket(g_Runtime_Order_Selected_Ticket);
        B8_UpdateRuntimeOrderPanel();
        return;
    }

    string objects[] =
    {
        B8_RUNTIME_ORDER_STATUS,
        B8_RUNTIME_QUICK_STATUS,
        B8_RUNTIME_ORDER_DETAIL1, B8_RUNTIME_ORDER_DETAIL2,
        B8_RUNTIME_ORDER_DETAIL3, B8_RUNTIME_ORDER_DETAIL4,
        "B8_RuntimeOrderLabelR", B8_RUNTIME_ORDER_EDIT_R,
        "B8_RuntimeOrderLabelClose", B8_RUNTIME_ORDER_EDIT_CLOSE,
        "B8_RuntimeOrderLabelBE", B8_RUNTIME_ORDER_EDIT_BE,
        B8_RUNTIME_ORDER_MODE_R, B8_RUNTIME_ORDER_MODE_POINTS,
        B8_RUNTIME_ORDER_ACTION_PARTIAL, B8_RUNTIME_ORDER_ACTION_BE,
        B8_RUNTIME_ORDER_ACTION_PARTIAL_BE, B8_RUNTIME_ORDER_ACTION_CLOSE,
        B8_RUNTIME_ORDER_APPLY, B8_RUNTIME_ORDER_DEFAULT,
        B8_RUNTIME_ORDER_DISABLE, B8_RUNTIME_ORDER_APPLY_SCOPE,
        B8_RUNTIME_ORDER_BREAKEVEN,
        B8_RUNTIME_ORDER_TAKEOVER,
        B8_RUNTIME_ORDER_CLOSE_DIVIDER,
        "B8_RuntimeCloseScopeLabel", B8_RUNTIME_CLOSE_SCOPE_ONE,
        B8_RUNTIME_CLOSE_SCOPE_ALL, "B8_RuntimeClosePercentLabel",
        B8_RUNTIME_CLOSE_PERCENT_EDIT, B8_RUNTIME_CLOSE_PERCENT_GO,
        "B8_RuntimeCloseLotsLabel", B8_RUNTIME_CLOSE_LOTS_EDIT,
        B8_RUNTIME_CLOSE_LOTS_GO,
        "B8_RuntimeQuickTitle", B8_RUNTIME_QUICK_THIS_ALL,
        B8_RUNTIME_QUICK_THIS_LOSS, B8_RUNTIME_QUICK_THIS_PROFIT,
        B8_RUNTIME_QUICK_THIS_SELL, B8_RUNTIME_QUICK_THIS_BUY,
        B8_RUNTIME_QUICK_ALL_LOSS, B8_RUNTIME_QUICK_ALL_PROFIT,
        B8_RUNTIME_QUICK_ALL_SELL, B8_RUNTIME_QUICK_ALL_BUY,
        B8_RUNTIME_QUICK_CLEAR_ALL, B8_RUNTIME_QUICK_DELETE_PENDING,
        B8_RUNTIME_QUICK_DELETE_MANAGED
    };

    for (int i = 0; i < ArraySize(objects); i++)
    {
        if (ObjectFind(0, objects[i]) >= 0)
            ObjectDelete(0, objects[i]);
    }
    for (int row = 0; row < 10; row++)
    {
        string row_name = B8_RuntimeOrderRowName(row);
        if (ObjectFind(0, row_name) >= 0)
            ObjectDelete(0, row_name);
    }

    string close_buttons[] =
    {
        B8_RUNTIME_CLOSE_PERCENT_50, B8_RUNTIME_CLOSE_PERCENT_80,
        B8_RUNTIME_CLOSE_PERCENT_100, B8_RUNTIME_CLOSE_LOTS_1,
        B8_RUNTIME_CLOSE_LOTS_01, B8_RUNTIME_CLOSE_LOTS_001
    };
    for (int close_index = 0; close_index < ArraySize(close_buttons); close_index++)
    {
        if (ObjectFind(0, close_buttons[close_index]) >= 0)
            ObjectDelete(0, close_buttons[close_index]);
    }

    ObjectSetInteger(0, B8_RUNTIME_ORDER_PANEL_BG, OBJPROP_YSIZE, 32);
    ObjectSetString(0, B8_RUNTIME_ORDER_COLLAPSE, OBJPROP_TEXT, "展开");
    ChartRedraw();
}

// 折叠或展开 Fib 成交前策略模板面板。
// 折叠时保留标题栏，展开时调用原创建函数恢复模板编辑控件。
void B8_SetFibTemplatePanelCollapsed(bool collapsed)
{
    g_Fib_Template_Panel_Collapsed = collapsed;
    if (ObjectFind(0, B8_FIB_TEMPLATE_PANEL_BG) < 0) return;

    if (!collapsed)
    {
        B8_CreateFibTemplatePanel();
        B8_UpdateFibTemplatePanel();
        return;
    }

    string objects[] =
    {
        B8_FIB_TEMPLATE_STATUS,
        "B8_FibTemplateLabelValue", B8_FIB_TEMPLATE_EDIT_VALUE,
        "B8_FibTemplateLabelClose", B8_FIB_TEMPLATE_EDIT_CLOSE,
        "B8_FibTemplateLabelBE", B8_FIB_TEMPLATE_EDIT_BE,
        B8_FIB_TEMPLATE_MODE_R, B8_FIB_TEMPLATE_MODE_POINTS,
        B8_FIB_TEMPLATE_ACTION_PARTIAL, B8_FIB_TEMPLATE_ACTION_BE,
        B8_FIB_TEMPLATE_ACTION_PARTIAL_BE, B8_FIB_TEMPLATE_ACTION_CLOSE,
        B8_FIB_TEMPLATE_APPLY,
        B8_FIB_TEMPLATE_PRESET_SAFE, B8_FIB_TEMPLATE_PRESET_STD,
        B8_FIB_TEMPLATE_PRESET_FAST, B8_FIB_TEMPLATE_RESET
    };

    for (int i = 0; i < ArraySize(objects); i++)
    {
        if (ObjectFind(0, objects[i]) >= 0)
            ObjectDelete(0, objects[i]);
    }
    for (int row = 0; row < 8; row++)
    {
        string row_name = B8_FibTemplateRowName(row);
        if (ObjectFind(0, row_name) >= 0)
            ObjectDelete(0, row_name);
    }

    ObjectSetInteger(0, B8_FIB_TEMPLATE_PANEL_BG, OBJPROP_YSIZE, 32);
    ObjectSetString(0, B8_FIB_TEMPLATE_COLLAPSE, OBJPROP_TEXT, "展开");
    ChartRedraw();
}
//#endregion

//#region MARK: 面板事件处理
//====================================================================
// 处理历史K线选择模式下的主图点击。
// 将屏幕坐标转换为时间，再转换为当前周期对应的K线shift。
//====================================================================
void B8_HandleHistoricalChartClick(const long &lparam, const double &dparam)
{
    datetime click_time = 0;
    double click_price = 0.0;
    int sub_window = 0;

    // 将鼠标屏幕坐标转换为图表时间、价格和所在子窗口。
    if (!ChartXYToTimePrice(0, (int)lparam, (int)dparam,
                            sub_window, click_time, click_price))
    {
        g_History_Status_Message = "无法读取点击位置，请重新选择";
        B8_UpdateHistoricalFibPanel();
        return;
    }

    // 历史信号只能从主图选择，副图点击不参与处理。
    if (sub_window != 0)
    {
        g_History_Status_Message = "请点击主图上的K线，不要点击副图";
        B8_UpdateHistoricalFibPanel();
        return;
    }

    // 根据点击时间定位当前图表周期中的K线索引。
    int shift = iBarShift(_Symbol, _Period, click_time, false);
    if (shift < 1)
    {
        g_History_Status_Message = "当前K线尚未收盘，请选择历史K线";
        B8_UpdateHistoricalFibPanel();
        return;
    }

    g_History_Selected_Shift = shift;
    ObjectSetString(0, B8_FIB_HISTORY_SHIFT, OBJPROP_TEXT,
                    IntegerToString(shift));
    B8_CancelHistoricalSelectMode();
    g_History_Status_Message = "已选择 K[" + IntegerToString(shift) + "]";
    B8_RefreshHistoricalSignalPreview();
    Comment("");
    PlaySound("ok.wav");
    ChartRedraw();
}

bool B8_HandleFibPanelEvent(const string object_name)
{
    if (Fib_Pending_Algorithm == B8_FIB_ALGO_V2 &&
        (object_name == B8_FIB_BTN_RISK_ON ||
         object_name == B8_FIB_BTN_RISK_OFF ||
         object_name == B8_FIB_BTN_KEEP_SHALLOW ||
         object_name == B8_FIB_BTN_KEEP_DEEP))
    {
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        return true;
    }

    if (object_name == B8_FIB_BTN_RISK_ON)
        Enable_Fib_Risk_Allocation = true;
    else if (object_name == B8_FIB_BTN_RISK_OFF)
        Enable_Fib_Risk_Allocation = false;
    else if (object_name == B8_FIB_BTN_KEEP_SHALLOW)
        Fib_Elimination_Policy = B8_KEEP_SHALLOW_FIB;
    else if (object_name == B8_FIB_BTN_KEEP_DEEP)
        Fib_Elimination_Policy = B8_KEEP_DEEP_FIB;
    else
        return false;

    ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
    B8_SaveFibRuntimeSettings();
    B8_UpdateFibPanel();
    return true;
}

// 处理运行时订单面板中的订单选择、模式、动作和应用按钮事件。
bool B8_HandleRuntimeOrderPanelEvent(const string object_name)
{
    if (!B8_IsRuntimeOrderPanelObject(object_name)) return false;

    if (object_name == B8_RUNTIME_ORDER_COLLAPSE)
    {
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        B8_SetRuntimeOrderPanelCollapsed(!g_Runtime_Order_Panel_Collapsed);
        return true;
    }

    if (object_name == B8_RUNTIME_ORDER_APPLY_SCOPE)
    {
        B8_RuntimeOrderCycleApplyScope();
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        B8_UpdateRuntimeOrderPanel();
        ChartRedraw();
        return true;
    }

    if (StringFind(object_name, B8_RUNTIME_ORDER_ROW_PREFIX, 0) == 0 &&
        g_Runtime_Order_Apply_Scope == B8_RUNTIME_APPLY_SELECTED)
    {
        int selected_row = (int)StringToInteger(StringSubstr(
            object_name, StringLen(B8_RUNTIME_ORDER_ROW_PREFIX)));
        if (selected_row >= 0 && selected_row < g_Runtime_Order_Row_Count)
        {
            B8_RuntimeOrderToggleSelectedTicket(
                g_Runtime_Order_Row_Tickets[selected_row]);
        }
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        B8_UpdateRuntimeOrderPanel();
        // 旧位置保留记录：批量结果提示必须放在批量应用分支，不能放在订单行分支。
        // if (!applied) { ... }
        // else { ... }
        ChartRedraw();
        return true;
    }

    if (StringFind(object_name, B8_RUNTIME_ORDER_ROW_PREFIX, 0) == 0)
    {
        int row = (int)StringToInteger(StringSubstr(object_name,
                                                    StringLen(B8_RUNTIME_ORDER_ROW_PREFIX)));
        if (row >= 0 && row < g_Runtime_Order_Row_Count)
        {
            g_Runtime_Order_Inputs_Editing = false;
            B8_RuntimeOrderSelectTicket(g_Runtime_Order_Row_Tickets[row]);
        }
        // 订单行仅用于选择订单，不保留 OBJ_BUTTON 的原生按下态，避免按钮视觉塌陷。
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        B8_UpdateRuntimeOrderPanel();
        ChartRedraw();
        return true;
    }

    if (object_name == B8_RUNTIME_ORDER_APPLY &&
        g_Runtime_Order_Apply_Scope != B8_RUNTIME_APPLY_CURRENT)
    {
        int success_count = 0;
        int failure_count = 0;
        bool applied = B8_ApplyRuntimeOrderOverrideByScope(success_count,
                                                           failure_count);
        if (!applied)
        {
            ObjectSetString(0, B8_RUNTIME_ORDER_STATUS, OBJPROP_TEXT,
                            "批量应用失败：请检查订单、选择或输入值");
        }
        else
        {
            g_Runtime_Order_Inputs_Editing = false;
            ObjectSetString(0, B8_RUNTIME_ORDER_STATUS, OBJPROP_TEXT,
                            "批量应用完成：成功 " + IntegerToString(success_count) +
                            " 笔，失败 " + IntegerToString(failure_count) + " 笔");
        }
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        B8_UpdateRuntimeOrderPanel();
        // 面板刷新会重写订单状态，因此在刷新后保留本次批量应用结果。
        if (!applied)
        {
            ObjectSetString(0, B8_RUNTIME_ORDER_STATUS, OBJPROP_TEXT,
                            "批量应用失败：请检查订单、选择或输入值");
        }
        else
        {
            ObjectSetString(0, B8_RUNTIME_ORDER_STATUS, OBJPROP_TEXT,
                            "批量应用完成：成功 " + IntegerToString(success_count) +
                            " 笔，失败 " + IntegerToString(failure_count) + " 笔");
        }
        ChartRedraw();
        return true;
    }

    // 接入说明：按钮只重置当前EA运行期状态，不删除历史成交记录或恢复已平仓手数。
    else if (object_name == B8_RUNTIME_ORDER_TAKEOVER)
    {
        int reset_count = B8_ResetAllManagedOrdersToOrderLevel();
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        B8_UpdateRuntimeOrderPanel();
        ObjectSetString(0, B8_RUNTIME_ORDER_STATUS, OBJPROP_TEXT,
                        "全部接管完成：恢复订单级管理 " +
                        IntegerToString(reset_count) + " 笔");
        ChartRedraw();
        return true;
    }
    else if (object_name == B8_RUNTIME_ORDER_BREAKEVEN)
    {
        int moved_count = 0;
        int already_count = 0;
        int failed_count = 0;
        bool executed = B8_ExecuteRuntimeBreakevenAllManaged(
            moved_count, already_count, failed_count);
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        B8_UpdateRuntimeOrderPanel();
        if (executed)
        {
            ObjectSetString(0, B8_RUNTIME_ORDER_STATUS, OBJPROP_TEXT,
                            "一键保本完成：移动 " + IntegerToString(moved_count) +
                            " 笔，已保本 " + IntegerToString(already_count) +
                            " 笔，失败 " + IntegerToString(failed_count) + " 笔");
        }
        else
        {
            ObjectSetString(0, B8_RUNTIME_ORDER_STATUS, OBJPROP_TEXT,
                            "一键保本失败：没有可处理的当前品种+Magic订单");
        }
        ChartRedraw();
    }
    // 手动平仓范围切换只改变后续点击的目标，不立即执行交易。
    else if (object_name == B8_RUNTIME_CLOSE_SCOPE_ONE)
    {
        g_Runtime_Close_All_Managed = false;
        B8_SetRuntimeCloseStatus("平仓范围：当前选中单笔", true);
    }
    else if (object_name == B8_RUNTIME_CLOSE_SCOPE_ALL)
    {
        g_Runtime_Close_All_Managed = true;
        B8_SetRuntimeCloseStatus("平仓范围：当前品种+Magic", true);
    }
    else if (object_name == B8_RUNTIME_CLOSE_PERCENT_50)
        B8_ExecuteRuntimeClosePercent(50.0);
    else if (object_name == B8_RUNTIME_CLOSE_PERCENT_80)
        B8_ExecuteRuntimeClosePercent(80.0);
    else if (object_name == B8_RUNTIME_CLOSE_PERCENT_100)
        B8_ExecuteRuntimeClosePercent(100.0);
    else if (object_name == B8_RUNTIME_CLOSE_PERCENT_GO)
        B8_ExecuteRuntimeClosePercent(StringToDouble(
                                      ObjectGetString(0, B8_RUNTIME_CLOSE_PERCENT_EDIT,
                                                      OBJPROP_TEXT)));
    else if (object_name == B8_RUNTIME_CLOSE_LOTS_1)
        B8_ExecuteRuntimeCloseLots(1.0);
    else if (object_name == B8_RUNTIME_CLOSE_LOTS_01)
        B8_ExecuteRuntimeCloseLots(0.1);
    else if (object_name == B8_RUNTIME_CLOSE_LOTS_001)
        B8_ExecuteRuntimeCloseLots(0.01);
    else if (object_name == B8_RUNTIME_CLOSE_LOTS_GO)
        B8_ExecuteRuntimeCloseLots(StringToDouble(
                                   ObjectGetString(0, B8_RUNTIME_CLOSE_LOTS_EDIT,
                                                   OBJPROP_TEXT)));
    else if (object_name == B8_RUNTIME_QUICK_THIS_ALL)
        B8_HandleQuickThisAll();
    else if (object_name == B8_RUNTIME_QUICK_THIS_LOSS)
        B8_HandleQuickThisLoss();
    else if (object_name == B8_RUNTIME_QUICK_THIS_PROFIT)
        B8_HandleQuickThisProfit();
    else if (object_name == B8_RUNTIME_QUICK_THIS_SELL)
        B8_HandleQuickThisSell();
    else if (object_name == B8_RUNTIME_QUICK_THIS_BUY)
        B8_HandleQuickThisBuy();
    else if (object_name == B8_RUNTIME_QUICK_ALL_LOSS)
        B8_HandleQuickAllLoss();
    else if (object_name == B8_RUNTIME_QUICK_ALL_PROFIT)
        B8_HandleQuickAllProfit();
    else if (object_name == B8_RUNTIME_QUICK_ALL_SELL)
        B8_HandleQuickAllSell();
    else if (object_name == B8_RUNTIME_QUICK_ALL_BUY)
        B8_HandleQuickAllBuy();
    else if (object_name == B8_RUNTIME_QUICK_CLEAR_ALL)
        B8_HandleQuickClearAll();
    else if (object_name == B8_RUNTIME_QUICK_DELETE_PENDING)
        B8_HandleQuickDeletePending();
    else if (object_name == B8_RUNTIME_QUICK_DELETE_MANAGED)
        B8_HandleQuickDeleteManaged();
    else if (object_name == B8_RUNTIME_ORDER_MODE_R)
        g_Runtime_Order_Edit_Mode = B8_ORDER_TRIGGER_R;
    else if (object_name == B8_RUNTIME_ORDER_MODE_POINTS)
        g_Runtime_Order_Edit_Mode = B8_ORDER_TRIGGER_POINTS;
    else if (object_name == B8_RUNTIME_ORDER_ACTION_PARTIAL)
        g_Runtime_Order_Edit_Action = B8_ORDER_PARTIAL_ONLY;
    else if (object_name == B8_RUNTIME_ORDER_ACTION_BE)
        g_Runtime_Order_Edit_Action = B8_ORDER_BE_ONLY;
    else if (object_name == B8_RUNTIME_ORDER_ACTION_PARTIAL_BE)
        g_Runtime_Order_Edit_Action = B8_ORDER_PARTIAL_BE;
    else if (object_name == B8_RUNTIME_ORDER_ACTION_CLOSE)
        g_Runtime_Order_Edit_Action = B8_ORDER_CLOSE_ONLY;
    else if (object_name == B8_RUNTIME_ORDER_APPLY)
    {
        if (!B8_ApplyRuntimeOrderOverride())
            ObjectSetString(0, B8_RUNTIME_ORDER_STATUS, OBJPROP_TEXT, "应用失败：请检查订单或输入值");
        else
            g_Runtime_Order_Inputs_Editing = false;
    }
    else if (object_name == B8_RUNTIME_ORDER_DEFAULT)
    {
        g_Runtime_Order_Inputs_Editing = false;
        if (B8_SelectRuntimeOrderByTicket(g_Runtime_Order_Selected_Ticket))
            B8_ClearRuntimeOrderOverride(OrderMagicNumber());
        B8_RuntimeOrderSelectTicket(g_Runtime_Order_Selected_Ticket);
    }
    else if (object_name == B8_RUNTIME_ORDER_DISABLE &&
             g_Advanced_Order_Strategy_Enabled)
    {
        int logical_magic = 0;
        if (B8_SelectRuntimeOrderByTicket(g_Runtime_Order_Selected_Ticket))
            logical_magic = OrderMagicNumber();
        int index = B8_FindRuntimeOrderOverride(logical_magic);
        if (index < 0 && g_Runtime_Order_Selected_Ticket > 0)
        {
            if (g_Runtime_Order_Override_Count < B8_RUNTIME_ORDER_MAX)
            {
                index = g_Runtime_Order_Override_Count++;
                g_Runtime_Order_Overrides[index].logical_magic = logical_magic;
                g_Runtime_Order_Overrides[index].fib_code = "--";
                g_Runtime_Order_Overrides[index].initial_open_price = OrderOpenPrice();
                g_Runtime_Order_Overrides[index].initial_sl = OrderStopLoss();
                g_Runtime_Order_Overrides[index].initial_risk_price =
                    MathAbs(OrderOpenPrice() - OrderStopLoss());
                g_Runtime_Order_Overrides[index].partial_closed_lots = 0.0;
                g_Runtime_Order_Overrides[index].partial_close_count = 0;
                g_Runtime_Order_Overrides[index].breakeven_done = false;
            }
        }
        if (index >= 0)
        {
            g_Runtime_Order_Overrides[index].active = true;
            g_Runtime_Order_Overrides[index].protection_enabled = false;
        }
    }

    ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
    B8_UpdateRuntimeOrderPanel();
    ChartRedraw();
    return true;
}

// 处理 Fib 模板选择、模式切换、动作选择、应用和恢复默认事件。
bool B8_HandleFibTemplatePanelEvent(const string object_name)
{
    if (!B8_IsFibTemplatePanelObject(object_name)) return false;

    if (object_name == B8_FIB_TEMPLATE_COLLAPSE)
    {
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        B8_SetFibTemplatePanelCollapsed(!g_Fib_Template_Panel_Collapsed);
        return true;
    }

    if (StringFind(object_name, B8_FIB_TEMPLATE_ROW_PREFIX, 0) == 0)
    {
        g_Fib_Template_Selected = (int)StringToInteger(StringSubstr(object_name,
                                                                      StringLen(B8_FIB_TEMPLATE_ROW_PREFIX)));
        g_Fib_Template_Edit_Mode = g_Fib_Order_Templates[g_Fib_Template_Selected].trigger_mode;
        g_Fib_Template_Edit_Action = g_Fib_Order_Templates[g_Fib_Template_Selected].protection_mode;
        g_Fib_Template_Inputs_Editing = false;
    }
    else if (object_name == B8_FIB_TEMPLATE_MODE_R)
    {
        g_Fib_Template_Edit_Mode = B8_ORDER_TRIGGER_R;
        g_Fib_Template_Inputs_Editing = false;
    }
    else if (object_name == B8_FIB_TEMPLATE_MODE_POINTS)
    {
        g_Fib_Template_Edit_Mode = B8_ORDER_TRIGGER_POINTS;
        g_Fib_Template_Inputs_Editing = false;
    }
    else if (object_name == B8_FIB_TEMPLATE_ACTION_PARTIAL)
    {
        g_Fib_Template_Edit_Action = B8_ORDER_PARTIAL_ONLY;
        g_Fib_Template_Inputs_Editing = false;
    }
    else if (object_name == B8_FIB_TEMPLATE_ACTION_BE)
    {
        g_Fib_Template_Edit_Action = B8_ORDER_BE_ONLY;
        g_Fib_Template_Inputs_Editing = false;
    }
    else if (object_name == B8_FIB_TEMPLATE_ACTION_PARTIAL_BE)
    {
        g_Fib_Template_Edit_Action = B8_ORDER_PARTIAL_BE;
        g_Fib_Template_Inputs_Editing = false;
    }
    else if (object_name == B8_FIB_TEMPLATE_ACTION_CLOSE)
    {
        g_Fib_Template_Edit_Action = B8_ORDER_CLOSE_ONLY;
        g_Fib_Template_Inputs_Editing = false;
    }
    else if (object_name == B8_FIB_TEMPLATE_APPLY)
    {
        if (!B8_ApplyFibTemplate())
            ObjectSetString(0, B8_FIB_TEMPLATE_STATUS, OBJPROP_TEXT, "应用失败：请检查模板输入");
        else
            g_Fib_Template_Inputs_Editing = false;
    }
    else if (object_name == B8_FIB_TEMPLATE_PRESET_SAFE ||
             object_name == B8_FIB_TEMPLATE_PRESET_STD ||
             object_name == B8_FIB_TEMPLATE_PRESET_FAST)
    {
        int preset_index = (object_name == B8_FIB_TEMPLATE_PRESET_SAFE) ? 0
                           : ((object_name == B8_FIB_TEMPLATE_PRESET_STD) ? 1 : 2);
        B8_ApplyFibTemplatePreset(preset_index);
    }
    else if (object_name == B8_FIB_TEMPLATE_RESET)
    {
        B8_InitializeFibOrderTemplates();
        g_Fib_Template_Inputs_Editing = false;
    }
    g_Fib_Order_Templates[g_Fib_Template_Selected].trigger_mode = g_Fib_Template_Edit_Mode;
    g_Fib_Order_Templates[g_Fib_Template_Selected].protection_mode = g_Fib_Template_Edit_Action;
    if (!g_Fib_Template_Inputs_Editing)
        B8_SyncFibTemplateInputs();
    ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
    B8_UpdateFibTemplatePanel();
    ChartRedraw();
    return true;
}
//#endregion

//#region MARK: 面板输入同步
//====================================================================
// 参数面板：把编辑态写入输入框
//====================================================================
void B8_WriteEditFields()
{
    ObjectSetString(0, B8_EDIT_FIXED_LOT, OBJPROP_TEXT,
                    DoubleToString(g_Edit_Settings.fixed_lot, 2));
    ObjectSetString(0, B8_EDIT_RISK_VALUE, OBJPROP_TEXT,
                    DoubleToString(g_Edit_Settings.risk_value, 2));
    ObjectSetString(0, B8_EDIT_TARGET_PCT, OBJPROP_TEXT,
                    DoubleToString(g_Edit_Settings.equity_target_percent, 2));
    ObjectSetString(0, B8_EDIT_CLOSE_PCT, OBJPROP_TEXT,
                    DoubleToString(g_Edit_Settings.partial_close_percent, 2));
    ObjectSetString(0, B8_EDIT_BE_BUFFER, OBJPROP_TEXT,
                    IntegerToString(g_Edit_Settings.be_buffer_points));
}

//====================================================================
// 参数面板：读取输入框到编辑态
//====================================================================
bool B8_ReadEditFields(string &error_text)
{
    error_text = "";

    string lot_text = ObjectGetString(0, B8_EDIT_FIXED_LOT, OBJPROP_TEXT);
    string risk_text = ObjectGetString(0, B8_EDIT_RISK_VALUE, OBJPROP_TEXT);
    string target_text = ObjectGetString(0, B8_EDIT_TARGET_PCT, OBJPROP_TEXT);
    string close_text = ObjectGetString(0, B8_EDIT_CLOSE_PCT, OBJPROP_TEXT);
    string buffer_text = ObjectGetString(0, B8_EDIT_BE_BUFFER, OBJPROP_TEXT);

    if (StringLen(lot_text) <= 0 || StringLen(risk_text) <= 0 ||
        StringLen(target_text) <= 0 || StringLen(close_text) <= 0 ||
        StringLen(buffer_text) <= 0)
    {
        error_text = "输入框不能为空";
        return false;
    }

    g_Edit_Settings.fixed_lot = StringToDouble(lot_text);
    g_Edit_Settings.risk_value = StringToDouble(risk_text);
    g_Edit_Settings.equity_target_percent = StringToDouble(target_text);
    g_Edit_Settings.partial_close_percent = StringToDouble(close_text);
    g_Edit_Settings.be_buffer_points = (int)MathRound(StringToDouble(buffer_text));

    return B8_ValidateSettings(g_Edit_Settings, error_text);
}

//====================================================================
// 订单管理子面板：写入编辑态
//====================================================================
void B8_WriteOrderEditFields()
{
    ObjectSetString(0, B8_ORDER_EDIT_TRIGGER_POINTS, OBJPROP_TEXT,
                    DoubleToString(g_Order_Edit_Settings.order_trigger_points, 0));
    ObjectSetString(0, B8_ORDER_EDIT_TRIGGER_R, OBJPROP_TEXT,
                    DoubleToString(g_Order_Edit_Settings.order_trigger_r, 2));
    ObjectSetString(0, B8_ORDER_EDIT_CLOSE_PCT, OBJPROP_TEXT,
                    DoubleToString(g_Order_Edit_Settings.order_partial_close_percent, 1));
    ObjectSetString(0, B8_ORDER_EDIT_BE_BUFFER, OBJPROP_TEXT,
                    IntegerToString(g_Order_Edit_Settings.order_be_buffer_points));
}

//====================================================================
// 订单管理子面板：读取编辑态
//====================================================================
bool B8_ReadOrderEditFields(string &error_text)
{
    error_text = "";

    string points_text = ObjectGetString(0, B8_ORDER_EDIT_TRIGGER_POINTS, OBJPROP_TEXT);
    string r_text = ObjectGetString(0, B8_ORDER_EDIT_TRIGGER_R, OBJPROP_TEXT);
    string close_text = ObjectGetString(0, B8_ORDER_EDIT_CLOSE_PCT, OBJPROP_TEXT);
    string buffer_text = ObjectGetString(0, B8_ORDER_EDIT_BE_BUFFER, OBJPROP_TEXT);

    if (StringLen(points_text) <= 0 || StringLen(r_text) <= 0 ||
        StringLen(close_text) <= 0 || StringLen(buffer_text) <= 0)
    {
        error_text = "订单管理输入框不能为空";
        return false;
    }

    g_Order_Edit_Settings.order_trigger_points = StringToDouble(points_text);
    g_Order_Edit_Settings.order_trigger_r = StringToDouble(r_text);
    g_Order_Edit_Settings.order_partial_close_percent = StringToDouble(close_text);
    g_Order_Edit_Settings.order_be_buffer_points = (int)MathRound(StringToDouble(buffer_text));

    return B8_ValidateOrderSettings(g_Order_Edit_Settings, error_text);
}

//====================================================================
// 参数面板：隐藏前同步编辑态
//====================================================================
void B8_SyncSettingsBeforeHide()
{
    if (!g_Settings_Dirty || ObjectFind(0, B8_SETTINGS_BG) < 0)
        return;

    string error_text = "";
    if (!B8_ReadEditFields(error_text))
        g_Settings_Message = "隐藏前输入校验: " + error_text;
}

//====================================================================
// 订单管理子面板：隐藏前同步编辑态
//====================================================================
void B8_SyncOrderSettingsBeforeHide()
{
    if (!g_Order_Settings_Dirty || ObjectFind(0, B8_ORDER_PANEL_BG) < 0)
        return;

    string order_error = "";
    if (!B8_ReadOrderEditFields(order_error))
        g_Order_Settings_Message = "隐藏前订单校验: " + order_error;
}

// 将当前选中 Fib 模板的参数主动同步到三个输入框。
void B8_SyncFibTemplateInputs()
{
    ObjectSetString(0, B8_FIB_TEMPLATE_EDIT_VALUE, OBJPROP_TEXT,
                    g_Fib_Order_Templates[g_Fib_Template_Selected].trigger_mode == B8_ORDER_TRIGGER_R
                    ? DoubleToString(g_Fib_Order_Templates[g_Fib_Template_Selected].trigger_r, 2)
                    : DoubleToString(g_Fib_Order_Templates[g_Fib_Template_Selected].trigger_points, 0));
    ObjectSetString(0, B8_FIB_TEMPLATE_EDIT_CLOSE, OBJPROP_TEXT,
                    DoubleToString(g_Fib_Order_Templates[g_Fib_Template_Selected].partial_close_percent, 1));
    ObjectSetString(0, B8_FIB_TEMPLATE_EDIT_BE, OBJPROP_TEXT,
                    IntegerToString(g_Fib_Order_Templates[g_Fib_Template_Selected].be_buffer_points));
    g_Fib_Template_Inputs_Editing = false;
}
//#endregion

//#region MARK: 模块--相关对象识别函数
//====================================================================
// 参数面板：识别主参数输入框对象
//====================================================================
bool B8_IsMainSettingsEditObject(string object_name)
{
    return (object_name == B8_EDIT_FIXED_LOT ||
            object_name == B8_EDIT_RISK_VALUE ||
            object_name == B8_EDIT_TARGET_PCT ||
            object_name == B8_EDIT_CLOSE_PCT ||
            object_name == B8_EDIT_BE_BUFFER);
}

// 订单面板：识别订单参数输入框对象
bool B8_IsOrderSettingsEditObject(string object_name)
{
    return (object_name == B8_ORDER_EDIT_TRIGGER_POINTS ||
            object_name == B8_ORDER_EDIT_TRIGGER_R ||
            object_name == B8_ORDER_EDIT_CLOSE_PCT ||
            object_name == B8_ORDER_EDIT_BE_BUFFER);
}

// 判断图表对象是否属于运行时订单策略面板的按钮区域。
bool B8_IsRuntimeOrderPanelObject(string object_name)
{
    if (object_name == B8_RUNTIME_ORDER_APPLY_SCOPE) return true;
    if (object_name == B8_RUNTIME_ORDER_BREAKEVEN) return true;
    if (object_name == B8_RUNTIME_ORDER_TAKEOVER) return true;
    return object_name == B8_RUNTIME_ORDER_COLLAPSE ||
           StringFind(object_name, B8_RUNTIME_ORDER_ROW_PREFIX, 0) == 0 ||
           object_name == B8_RUNTIME_ORDER_APPLY ||
           object_name == B8_RUNTIME_ORDER_DEFAULT ||
           object_name == B8_RUNTIME_ORDER_DISABLE ||
           object_name == B8_RUNTIME_ORDER_MODE_R ||
           object_name == B8_RUNTIME_ORDER_MODE_POINTS ||
           object_name == B8_RUNTIME_ORDER_ACTION_PARTIAL ||
           object_name == B8_RUNTIME_ORDER_ACTION_BE ||
           object_name == B8_RUNTIME_ORDER_ACTION_PARTIAL_BE ||
           object_name == B8_RUNTIME_ORDER_ACTION_CLOSE ||
           object_name == B8_RUNTIME_CLOSE_SCOPE_ONE ||
           object_name == B8_RUNTIME_CLOSE_SCOPE_ALL ||
           object_name == B8_RUNTIME_CLOSE_PERCENT_50 ||
           object_name == B8_RUNTIME_CLOSE_PERCENT_80 ||
           object_name == B8_RUNTIME_CLOSE_PERCENT_100 ||
           object_name == B8_RUNTIME_CLOSE_PERCENT_GO ||
           object_name == B8_RUNTIME_CLOSE_LOTS_1 ||
           object_name == B8_RUNTIME_CLOSE_LOTS_01 ||
           object_name == B8_RUNTIME_CLOSE_LOTS_001 ||
           object_name == B8_RUNTIME_CLOSE_LOTS_GO ||
           object_name == B8_RUNTIME_QUICK_THIS_ALL ||
           object_name == B8_RUNTIME_QUICK_THIS_LOSS ||
           object_name == B8_RUNTIME_QUICK_THIS_PROFIT ||
           object_name == B8_RUNTIME_QUICK_THIS_SELL ||
           object_name == B8_RUNTIME_QUICK_THIS_BUY ||
           object_name == B8_RUNTIME_QUICK_ALL_LOSS ||
           object_name == B8_RUNTIME_QUICK_ALL_PROFIT ||
           object_name == B8_RUNTIME_QUICK_ALL_SELL ||
           object_name == B8_RUNTIME_QUICK_ALL_BUY ||
           object_name == B8_RUNTIME_QUICK_CLEAR_ALL ||
           object_name == B8_RUNTIME_QUICK_DELETE_PENDING ||
           object_name == B8_RUNTIME_QUICK_DELETE_MANAGED;
}

// 判断图表对象是否属于运行时订单策略面板的输入框区域。
bool B8_IsRuntimeOrderEditObject(string object_name)
{
    return object_name == B8_RUNTIME_ORDER_EDIT_R ||
           object_name == B8_RUNTIME_ORDER_EDIT_CLOSE ||
           object_name == B8_RUNTIME_ORDER_EDIT_BE ||
           object_name == B8_RUNTIME_CLOSE_PERCENT_EDIT ||
           object_name == B8_RUNTIME_CLOSE_LOTS_EDIT;
}

// 判断图表对象是否属于 Fib 模板面板的按钮或列表区域。
bool B8_IsFibTemplatePanelObject(string object_name)
{
    return object_name == B8_FIB_TEMPLATE_COLLAPSE ||
           StringFind(object_name, B8_FIB_TEMPLATE_ROW_PREFIX, 0) == 0 ||
           object_name == B8_FIB_TEMPLATE_MODE_R ||
           object_name == B8_FIB_TEMPLATE_MODE_POINTS ||
           object_name == B8_FIB_TEMPLATE_ACTION_PARTIAL ||
           object_name == B8_FIB_TEMPLATE_ACTION_BE ||
           object_name == B8_FIB_TEMPLATE_ACTION_PARTIAL_BE ||
           object_name == B8_FIB_TEMPLATE_ACTION_CLOSE ||
           object_name == B8_FIB_TEMPLATE_APPLY ||
           object_name == B8_FIB_TEMPLATE_PRESET_SAFE ||
           object_name == B8_FIB_TEMPLATE_PRESET_STD ||
           object_name == B8_FIB_TEMPLATE_PRESET_FAST ||
           object_name == B8_FIB_TEMPLATE_RESET;
}

// 判断图表对象是否属于 Fib 模板面板的三个输入框。
bool B8_IsFibTemplateEditObject(string object_name)
{
    return object_name == B8_FIB_TEMPLATE_EDIT_VALUE ||
           object_name == B8_FIB_TEMPLATE_EDIT_CLOSE ||
           object_name == B8_FIB_TEMPLATE_EDIT_BE;
}
//#endregion

//#region MARK: 模块--编辑状态和预设应用
//====================================================================
// 参数面板：标记存在未应用修改
//====================================================================
void B8_MarkSettingsDirty()
{
    g_Settings_Dirty = true;
    g_Settings_Message = "存在未应用修改";
    B8_UpdateSettingsPanel();
    ChartRedraw();
}

// 订单面板：标记订单参数存在未应用修改
void B8_MarkOrderSettingsDirty()
{
    g_Order_Settings_Dirty = true;
    g_Order_Settings_Message = "存在未应用订单修改";
    B8_UpdateOrderPanel();
    ChartRedraw();
}

//====================================================================
// 参数面板：预设写入编辑区并立即应用
//====================================================================
void B8_ApplyPreset(int preset_index)
{
    string preset_name = "标准";

    if (preset_index == 0)
    {
        preset_name = "保守";
        g_Edit_Settings.position_mode = POS_FIXED_LOT;
        g_Edit_Settings.fixed_lot = 0.01;
        g_Edit_Settings.risk_mode = RISK_FIXED_MONEY;
        g_Edit_Settings.risk_value = 10.0;
        g_Edit_Settings.equity_protect_enabled = true;
        g_Edit_Settings.equity_target_percent = 3.0;
        g_Edit_Settings.partial_close_percent = 50.0;
        g_Edit_Settings.be_buffer_points = 0;
    }
    else if (preset_index == 1)
    {
        // 标准预设始终等于本次挂载EA时的 input 参数
        B8_CopySettings(g_Startup_Settings, g_Edit_Settings);
    }
    else
    {
        preset_name = "积极";
        g_Edit_Settings.position_mode = POS_FIXED_LOT;
        g_Edit_Settings.fixed_lot = 0.15;
        g_Edit_Settings.risk_mode = RISK_FIXED_MONEY;
        g_Edit_Settings.risk_value = 150.0;
        g_Edit_Settings.equity_protect_enabled = true;
        g_Edit_Settings.equity_target_percent = 1.5;
        g_Edit_Settings.partial_close_percent = 80.0;
        g_Edit_Settings.be_buffer_points = 30;
    }

    if (B8_ApplyEditSettings("预设-" + preset_name))
        g_Settings_Message = "已应用" + preset_name + "预设";
    else
        g_Settings_Message = preset_name + "预设应用失败";

    B8_WriteEditFields();
    B8_UpdateSettingsPanel();
    ChartRedraw();
}

//====================================================================
// 订单管理子面板：预设写入编辑区并立即应用
//====================================================================
void B8_ApplyOrderPreset(int preset_index)
{
    string preset_name = "标准";

    if (preset_index == 0)
    {
        preset_name = "保守";
        g_Order_Edit_Settings.order_protection_enabled = true;
        g_Order_Edit_Settings.order_trigger_mode = B8_ORDER_TRIGGER_R;
        g_Order_Edit_Settings.order_trigger_points = 300.0;
        g_Order_Edit_Settings.order_trigger_r = 1.5;
        g_Order_Edit_Settings.order_partial_close_percent = 50.0;
        g_Order_Edit_Settings.order_protection_mode = B8_ORDER_PARTIAL_BE;
        g_Order_Edit_Settings.order_be_buffer_points = 0;
    }
    else if (preset_index == 1)
    {
        B8_CopyOrderSettings(g_Order_Startup_Settings, g_Order_Edit_Settings);
    }
    else
    {
        preset_name = "积极";
        g_Order_Edit_Settings.order_protection_enabled = true;
        g_Order_Edit_Settings.order_trigger_mode = B8_ORDER_TRIGGER_R;
        g_Order_Edit_Settings.order_trigger_points = 150.0;
        g_Order_Edit_Settings.order_trigger_r = 0.8;
        g_Order_Edit_Settings.order_partial_close_percent = 80.0;
        g_Order_Edit_Settings.order_protection_mode = B8_ORDER_PARTIAL_BE;
        g_Order_Edit_Settings.order_be_buffer_points = 10;
    }

    if (B8_ApplyOrderEditSettings("订单预设-" + preset_name))
        g_Order_Settings_Message = "已应用" + preset_name + "订单预设";
    else
        g_Order_Settings_Message = preset_name + "订单预设应用失败";

    B8_WriteOrderEditFields();
    B8_UpdateOrderPanel();
    ChartRedraw();
}
//#endregion