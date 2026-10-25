//====================================================================
// 文件作用：KTarget_FinderBot8 的主业务逻辑。
// 本文件原样承载主文件中的用户界面逻辑。
//====================================================================

//#region MARK: 模块--核心业务：账户浮盈保护 绘图功能
//====================================================================
// 可视化函数: B8_UpdateEquityTargetVisual
// 在主图绘制下一次浮盈保护触发目标价（绿色线）及文字信息
//====================================================================
void B8_UpdateEquityTargetVisual()
{
    if (!g_Runtime_Settings.equity_protect_enabled)
    {
        B8_ClearEquityTargetVisual();
        return;
    }

    double target_price = 0.0;
    double current_profit = 0.0;
    double target_profit = 0.0;
    double profit_gap = 0.0;
    double slope_per_price = 0.0;

    bool ok = B8_TryCalcEquityTargetPrice(target_price,
                                          current_profit,
                                          target_profit,
                                          profit_gap,
                                          slope_per_price);

    if (!ok)
    {
        B8_ClearEquityTargetVisual();
        return;
    }

    if (ObjectFind(0, B8_EQ_TARGET_LINE) < 0)
        ObjectCreate(0, B8_EQ_TARGET_LINE, OBJ_HLINE, 0, 0, target_price);

    ObjectSetDouble(0, B8_EQ_TARGET_LINE, OBJPROP_PRICE, target_price);
    ObjectSetInteger(0, B8_EQ_TARGET_LINE, OBJPROP_COLOR, clrForestGreen);
    ObjectSetInteger(0, B8_EQ_TARGET_LINE, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, B8_EQ_TARGET_LINE, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, B8_EQ_TARGET_LINE, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, B8_EQ_TARGET_LINE, OBJPROP_HIDDEN, true);

    if (ObjectFind(0, B8_EQ_TARGET_LABEL) < 0)
        ObjectCreate(0, B8_EQ_TARGET_LABEL, OBJ_LABEL, 0, 0, 0);

    if (ObjectFind(0, B8_EQ_TARGET_STATUS) < 0)
        ObjectCreate(0, B8_EQ_TARGET_STATUS, OBJ_LABEL, 0, 0, 0);

    string status = (profit_gap > 0.0)
                    ? StringFormat("差额: %.2f", profit_gap)
                    : "已达到阈值";

    string txt = StringFormat("EP目标价: %s | 当前浮盈: %.2f",
                              DoubleToString(target_price, _Digits),
                              current_profit);

    string status_txt = StringFormat("目标: %.2f | %s",
                                     target_profit,
                                     status);

    ObjectSetInteger(0, B8_EQ_TARGET_LABEL, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, B8_EQ_TARGET_LABEL, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
    ObjectSetInteger(0, B8_EQ_TARGET_LABEL, OBJPROP_XDISTANCE, 20);
    ObjectSetInteger(0, B8_EQ_TARGET_LABEL, OBJPROP_YDISTANCE, 20);
    ObjectSetString (0, B8_EQ_TARGET_LABEL, OBJPROP_TEXT, txt);
    ObjectSetInteger(0, B8_EQ_TARGET_LABEL, OBJPROP_COLOR, clrForestGreen);
    ObjectSetInteger(0, B8_EQ_TARGET_LABEL, OBJPROP_FONTSIZE, 9);
    ObjectSetInteger(0, B8_EQ_TARGET_LABEL, OBJPROP_SELECTABLE, false);

    ObjectSetInteger(0, B8_EQ_TARGET_STATUS, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, B8_EQ_TARGET_STATUS, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
    ObjectSetInteger(0, B8_EQ_TARGET_STATUS, OBJPROP_XDISTANCE, 20);
    ObjectSetInteger(0, B8_EQ_TARGET_STATUS, OBJPROP_YDISTANCE, 38);
    ObjectSetString (0, B8_EQ_TARGET_STATUS, OBJPROP_TEXT, status_txt);
    ObjectSetInteger(0, B8_EQ_TARGET_STATUS, OBJPROP_COLOR, clrForestGreen);
    ObjectSetInteger(0, B8_EQ_TARGET_STATUS, OBJPROP_FONTSIZE, 9);
    ObjectSetInteger(0, B8_EQ_TARGET_STATUS, OBJPROP_SELECTABLE, false);
}
//#endregion

//#region MARK: 模块--核心业务：账户浮盈保护
//====================================================================
// 账户浮盈保护：达到阈值后减仓并移保本
//====================================================================
void B8_ManageEquityProtection()
{
    if (!g_Runtime_Settings.equity_protect_enabled) return;

    int managed_count = B8_CountOpenPositions();

    // 无持仓时自动重置触发状态，便于下一轮重新生效
    if (managed_count <= 0)
    {
        g_EquityProtect_Triggered = false;
        return;
    }

    if (Protect_Once_Per_Cycle && g_EquityProtect_Triggered) return;

    double effective_base = B8_GetEffectiveEquityBase();
    double target_profit = effective_base * (g_Runtime_Settings.equity_target_percent / 100.0);
    double floating_profit = B8_GetManagedFloatingProfit();

    if (target_profit <= 0.0) return;
    if (floating_profit < target_profit) return;

    // 账户级“仅平仓”独立于订单级保护，达标后关闭本EA管理的全部市价持仓。
    if (g_Runtime_Settings.equity_protection_action == B8_EQUITY_CLOSE_ONLY)
    {
        Print("[Bot8][账户盈利保护] 达到阈值，开始执行账户级全部平仓。",
              " 当前基准:", DoubleToString(effective_base, 2),
              " 当前浮盈:", DoubleToString(floating_profit, 2),
              " 目标阈值:", DoubleToString(target_profit, 2));

        bool close_all_processed = true;
        bool found_market_order = false;

        for (int close_index = OrdersTotal() - 1; close_index >= 0; close_index--)
        {
            if (!OrderSelect(close_index, SELECT_BY_POS, MODE_TRADES)) continue;
            if (!B8_IsManagedOrder()) continue;

            int close_type = OrderType();
            if (close_type != OP_BUY && close_type != OP_SELL) continue;

            found_market_order = true;
            int close_ticket = OrderTicket();
            double close_lots = OrderLots();
            RefreshRates();
            double close_price = (close_type == OP_BUY) ? Bid : Ask;

            ResetLastError();
            if (OrderClose(close_ticket, close_lots, close_price,
                           Slippage, clrOrangeRed))
            {
                Print("[Bot8][账户盈利保护] 全部平仓成功。 Ticket:", close_ticket,
                      " 手数:", DoubleToString(close_lots, 2));
            }
            else
            {
                close_all_processed = false;
                Print("[Bot8][账户盈利保护] 全部平仓失败。 Ticket:", close_ticket,
                      " 手数:", DoubleToString(close_lots, 2),
                      " 错误码:", GetLastError());
            }
        }

        if (found_market_order && close_all_processed)
        {
            g_EquityProtect_Triggered = true;
            g_EquityProtect_TriggerTime = TimeCurrent();
            Print("[Bot8][账户盈利保护] 账户级全部平仓完成，已标记触发状态。",
                  " 触发时间:", TimeToString(g_EquityProtect_TriggerTime,
                                             TIME_DATE | TIME_SECONDS));
            B8_UpdateEquityTargetVisual();
        }
        return;
    }

    double close_ratio = g_Runtime_Settings.partial_close_percent / 100.0;
    if (close_ratio <= 0.0) return;
    if (close_ratio > 1.0) close_ratio = 1.0;

    Print("[Bot8][盈利保护触发] 浮盈达到阈值，开始执行减仓+保本。",
            " 当前基准:", DoubleToString(effective_base, 2),
          " 当前浮盈:", DoubleToString(floating_profit, 2),
          " 目标阈值:", DoubleToString(target_profit, 2),
          " 减仓比例:", DoubleToString(close_ratio * 100.0, 1), "%");

    bool any_close_success = false;

    // 逆序遍历，避免持仓数量变化影响索引
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsManagedOrder()) continue;

        int type = OrderType();
        if (type != OP_BUY && type != OP_SELL) continue;

        int ticket = OrderTicket();

        // 关键顺序调整：先尝试保本，再判断减仓是否可行。
        // 这样即使剩余手数太小无法减仓，也不会错过保本动作。
        if (Move_SL_To_BE)
        {
            double open_price = OrderOpenPrice();
            double be_sl = open_price;
            double buffer = g_Runtime_Settings.be_buffer_points * Point();

            if (type == OP_BUY)
                be_sl = open_price + buffer;
            else if (type == OP_SELL)
                be_sl = open_price - buffer;

            be_sl = NormalizeDouble(be_sl, _Digits);

            ResetLastError();
            if (!OrderModify(ticket, open_price, be_sl, OrderTakeProfit(), 0, clrNONE))
            {
                int err2 = GetLastError();
                Print("[Bot8][盈利保护] 移保本失败(减仓前)。",
                      " Ticket:", ticket,
                      " 目标SL:", DoubleToString(be_sl, _Digits),
                      " 错误码:", err2);
            }
            else
            {
                Print("[Bot8][盈利保护] 移保本成功(减仓前)。",
                      " Ticket:", ticket,
                      " 新SL:", DoubleToString(be_sl, _Digits));
            }
        }

        double lots = OrderLots();
        double min_lot = MarketInfo(_Symbol, MODE_MINLOT);
        double lot_step = MarketInfo(_Symbol, MODE_LOTSTEP);
        if (lot_step <= 0) lot_step = min_lot;
        double lot_epsilon = lot_step * 0.0001;

        double raw_close_lots = lots * close_ratio;
        double close_lots = MathFloor((raw_close_lots + lot_epsilon) / lot_step) * lot_step;
        close_lots = NormalizeDouble(close_lots, 2);

        // 减仓手数必须满足最小手数
        if (close_lots < min_lot)
        {
            Print("[Bot8][盈利保护] 跳过减仓：计划减仓手数小于最小手数。",
                  " Ticket:", ticket,
                  " 计划减仓:", DoubleToString(close_lots, 2),
                  " 最小手:", DoubleToString(min_lot, 2));
            continue;
        }

        // 剩余手数也要满足最小手数，否则将减仓量下调到“至少留最小手”
        double remain_lots = lots - close_lots;
        if (remain_lots + lot_epsilon < min_lot)
        {
            close_lots = lots - min_lot;
            close_lots = MathFloor((close_lots + lot_epsilon) / lot_step) * lot_step;
            close_lots = NormalizeDouble(close_lots, 2);
        }

        if (close_lots < min_lot || close_lots >= lots)
        {
            Print("[Bot8][盈利保护] 跳过减仓：剩余手数约束导致本次不可减。",
                  " Ticket:", ticket,
                  " 当前手数:", DoubleToString(lots, 2),
                  " 计划减仓:", DoubleToString(close_lots, 2));
            continue;
        }

        RefreshRates();
        double close_price = (type == OP_BUY) ? Bid : Ask;

        ResetLastError();
        if (!OrderClose(ticket, close_lots, close_price, Slippage, clrOrange))
        {
            int err = GetLastError();
            Print("[Bot8][盈利保护] 减仓失败。",
                  " Ticket:", ticket,
                  " 计划减仓:", DoubleToString(close_lots, 2),
                  " 错误码:", err);
            continue;
        }

        any_close_success = true;
        Print("[Bot8][盈利保护] 减仓成功。",
              " Ticket:", ticket,
              " 减仓手数:", DoubleToString(close_lots, 2));
    }

    if (any_close_success)
    {
        g_EquityProtect_Triggered = true;
        g_EquityProtect_TriggerTime = TimeCurrent();
        Print("[Bot8][盈利保护] 本轮执行完成，已标记触发状态。",
              " 触发时间:", TimeToString(g_EquityProtect_TriggerTime, TIME_DATE | TIME_SECONDS));

        // 减仓后仓位结构变化，立即刷新下一次目标价可视化
        B8_UpdateEquityTargetVisual();
    }
}

//====================================================================
// 账户浮盈保护 V2：不保存 Ticket 状态，按本轮动作结果完成一次性保护
//====================================================================
void B8_ManageEquityProtectionV2()
{
    if (!g_Runtime_Settings.equity_protect_enabled) return;

    int managed_count = B8_CountOpenPositions();
    if (managed_count <= 0)
    {
        g_EquityProtect_Triggered = false;
        return;
    }

    if (Protect_Once_Per_Cycle && g_EquityProtect_Triggered) return;

    double effective_base = B8_GetEffectiveEquityBase();
    double target_profit = effective_base * (g_Runtime_Settings.equity_target_percent / 100.0);
    double floating_profit = B8_GetManagedFloatingProfit();

    if (target_profit <= 0.0) return;
    if (floating_profit < target_profit) return;

    // 账户级“仅平仓”独立于订单级保护，达标后关闭本EA管理的全部市价持仓。
    if (g_Runtime_Settings.equity_protection_action == B8_EQUITY_CLOSE_ONLY)
    {
        Print("[Bot8][账户盈利保护V2] 达到阈值，开始执行账户级全部平仓。",
              " 当前基准:", DoubleToString(effective_base, 2),
              " 当前浮盈:", DoubleToString(floating_profit, 2),
              " 目标阈值:", DoubleToString(target_profit, 2));

        bool close_all_processed = true;
        bool found_market_order = false;

        for (int close_index = OrdersTotal() - 1; close_index >= 0; close_index--)
        {
            if (!OrderSelect(close_index, SELECT_BY_POS, MODE_TRADES)) continue;
            if (!B8_IsManagedOrder()) continue;

            int close_type = OrderType();
            if (close_type != OP_BUY && close_type != OP_SELL) continue;

            found_market_order = true;
            int close_ticket = OrderTicket();
            double close_lots = OrderLots();
            RefreshRates();
            double close_price = (close_type == OP_BUY) ? Bid : Ask;

            ResetLastError();
            if (OrderClose(close_ticket, close_lots, close_price,
                           Slippage, clrOrangeRed))
            {
                Print("[Bot8][账户盈利保护V2] 全部平仓成功。 Ticket:", close_ticket,
                      " 手数:", DoubleToString(close_lots, 2));
            }
            else
            {
                close_all_processed = false;
                Print("[Bot8][账户盈利保护V2] 全部平仓失败。 Ticket:", close_ticket,
                      " 手数:", DoubleToString(close_lots, 2),
                      " 错误码:", GetLastError());
            }
        }

        if (found_market_order && close_all_processed)
        {
            g_EquityProtect_Triggered = true;
            g_EquityProtect_TriggerTime = TimeCurrent();
            Print("[Bot8][账户盈利保护V2] 账户级全部平仓完成，已标记触发状态。",
                  " 触发时间:", TimeToString(g_EquityProtect_TriggerTime,
                                             TIME_DATE | TIME_SECONDS));
            B8_UpdateEquityTargetVisual();
        }
        return;
    }

    double close_ratio = g_Runtime_Settings.partial_close_percent / 100.0;
    if (close_ratio <= 0.0) return;
    if (close_ratio > 1.0) close_ratio = 1.0;

    Print("[Bot8][盈利保护V2触发] 浮盈达到阈值，开始执行减仓+保本。",
          " 当前基准:", DoubleToString(effective_base, 2),
          " 当前浮盈:", DoubleToString(floating_profit, 2),
          " 目标阈值:", DoubleToString(target_profit, 2),
          " 减仓比例:", DoubleToString(close_ratio * 100.0, 1), "%");

    bool all_processed = true;
    bool found_order = false;

    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsManagedOrder()) continue;

        int type = OrderType();
        if (type != OP_BUY && type != OP_SELL) continue;

        found_order = true;
        int ticket = OrderTicket();
        bool be_done = !Move_SL_To_BE;

        if (Move_SL_To_BE)
        {
            double open_price = OrderOpenPrice();
            double be_sl = open_price;
            double buffer = g_Runtime_Settings.be_buffer_points * Point();

            if (type == OP_BUY)
                be_sl = open_price + buffer;
            else
                be_sl = open_price - buffer;

            be_sl = NormalizeDouble(be_sl, _Digits);
            double current_sl = OrderStopLoss();

            if ((type == OP_BUY && current_sl > 0.0 && current_sl >= be_sl) ||
                (type == OP_SELL && current_sl > 0.0 && current_sl <= be_sl))
            {
                be_done = true;
            }
            else
            {
                ResetLastError();
                if (OrderModify(ticket, open_price, be_sl,
                                OrderTakeProfit(), 0, clrNONE))
                {
                    be_done = true;
                    Print("[Bot8][盈利保护V2] 移保本成功。 Ticket:", ticket,
                          " 新SL:", DoubleToString(be_sl, _Digits));
                }
                else
                {
                    int modify_error = GetLastError();

                    if (modify_error == 1 &&
                        OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
                    {
                        current_sl = OrderStopLoss();
                        be_done = ((type == OP_BUY && current_sl > 0.0 && current_sl >= be_sl) ||
                                   (type == OP_SELL && current_sl > 0.0 && current_sl <= be_sl));
                    }

                    if (!be_done)
                    {
                        all_processed = false;
                        Print("[Bot8][盈利保护V2] 移保本失败。 Ticket:", ticket,
                              " 目标SL:", DoubleToString(be_sl, _Digits),
                              " 错误码:", modify_error);
                    }
                }
            }
        }

        bool partial_processed = false;
        int logical_magic = OrderMagicNumber();
        // 账户级保护不能使用订单级历史减仓状态。
        // 订单级减仓和账户级减仓共用Magic，历史记录无法区分动作来源。
        // if (B8_HasOrderPartialCloseHistory(logical_magic, type))
        // {
        //     partial_processed = true;
        // }
        // else
        // {
            if (!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
            {
                all_processed = false;
                Print("[Bot8][盈利保护V2] 无法重新选择当前订单。 Ticket:", ticket);
                continue;
            }

            double lots = OrderLots();
            double min_lot = MarketInfo(_Symbol, MODE_MINLOT);
            double lot_step = MarketInfo(_Symbol, MODE_LOTSTEP);
            if (min_lot <= 0.0) min_lot = 0.01;
            if (lot_step <= 0.0) lot_step = min_lot;

            double lot_epsilon = lot_step * 0.0001;
            double close_lots = MathFloor((lots * close_ratio + lot_epsilon) / lot_step) * lot_step;
            close_lots = NormalizeDouble(close_lots, 2);

            if (close_lots < min_lot)
            {
                partial_processed = true;
                Print("[Bot8][盈利保护V2] 跳过减仓并结束本轮：计划减仓手数小于最小手数。",
                      " Ticket:", ticket,
                      " Magic:", logical_magic,
                      " 计划减仓:", DoubleToString(close_lots, 2),
                      " 最小手:", DoubleToString(min_lot, 2));
            }
            else
            {
                double remain_lots = lots - close_lots;
                if (remain_lots + lot_epsilon < min_lot)
                {
                    close_lots = lots - min_lot;
                    close_lots = MathFloor((close_lots + lot_epsilon) / lot_step) * lot_step;
                    close_lots = NormalizeDouble(close_lots, 2);
                }

                if (close_lots < min_lot || close_lots >= lots)
                {
                    partial_processed = true;
                    Print("[Bot8][盈利保护V2] 跳过减仓并结束本轮：剩余手数约束导致本次不可减。",
                          " Ticket:", ticket,
                          " Magic:", logical_magic,
                          " 当前手数:", DoubleToString(lots, 2),
                          " 计划减仓:", DoubleToString(close_lots, 2));
                }
                else
                {
                    RefreshRates();
                    double close_price = (type == OP_BUY) ? Bid : Ask;
                    ResetLastError();

                    if (OrderClose(ticket, close_lots, close_price, Slippage, clrOrange))
                    {
                        partial_processed = true;
                        Print("[Bot8][盈利保护V2] 减仓成功。 Ticket:", ticket,
                              " Magic:", logical_magic,
                              " 减仓手数:", DoubleToString(close_lots, 2));
                    }
                    else
                    {
                        all_processed = false;
                        Print("[Bot8][盈利保护V2] 减仓失败。 Ticket:", ticket,
                              " Magic:", logical_magic,
                              " 计划减仓:", DoubleToString(close_lots, 2),
                              " 错误码:", GetLastError());
                    }
                }
            }
        // }

        if (!be_done || !partial_processed)
            all_processed = false;
    }

    if (found_order && all_processed)
    {
        g_EquityProtect_Triggered = true;
        g_EquityProtect_TriggerTime = TimeCurrent();
        Print("[Bot8][盈利保护V2] 本轮执行完成，已标记触发状态。",
              " 触发时间:", TimeToString(g_EquityProtect_TriggerTime,
                                         TIME_DATE | TIME_SECONDS));
        B8_UpdateEquityTargetVisual();
    }
}
//#endregion

//#region MARK: 模块--核心业务：订单级别/减仓/保本
//====================================================================
// 订单级保护：每笔订单按真实成交价/真实止损计算 R
//====================================================================
void B8_ManageOrderProtection()
{
    RefreshRates();
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsManagedOrder()) continue;

        int type = OrderType();
        if (type != OP_BUY && type != OP_SELL) continue;

        int ticket = OrderTicket();
        int order_magic = OrderMagicNumber();
        double open_price = OrderOpenPrice();
        double current_sl = OrderStopLoss();

        // 扩展开关关闭时跳过 Runtime Override，当前订单直接继续使用订单级管理。
        if (g_Advanced_Order_Strategy_Enabled &&
            B8_HasRuntimeOrderOverride(order_magic))
        {
            B8_ManageRuntimeOrderProtection(ticket, type);
            continue;
        }

        // 只有扩展开关开启时，订单注释才允许触发 Fibo 模板接管。
        // 接入说明：全部接管后暂时跳过订单注释触发的Fibo运行时覆盖，
        // 让本次接管真正回归订单级默认策略；原Fibo判断逻辑保持不变。
        if (g_Advanced_Order_Strategy_Enabled &&
            !B8_IsRuntimeTakeoverActive(order_magic))
        {
            string fib_code = B8_RuntimeOrderFibCode(OrderComment());
            int template_index = B8_FibTemplateIndexFromCode(fib_code);
            if (template_index >= 0 && g_Fib_Order_Templates[template_index].configured)
            {
                B8_CopyFibTemplateToOverride(order_magic, template_index, open_price, current_sl);
                if (B8_HasRuntimeOrderOverride(order_magic))
                {
                    B8_ManageRuntimeOrderProtection(ticket, type);
                    continue;
                }
            }
        }

        if (!g_Order_Runtime_Settings.order_protection_enabled)
            continue;

        int protection_state_index = B8_GetOrCreateOrderProtectionState(order_magic,
                                                                         open_price,
                                                                         current_sl);

        double profit_price = (type == OP_BUY) ? Bid - open_price
                                               : open_price - Ask;
        if (profit_price <= 0.0) continue;

        bool triggered = false;
        if (g_Order_Runtime_Settings.order_trigger_mode == B8_ORDER_TRIGGER_R)
        {
            if (protection_state_index < 0) continue;
            if (!g_Order_Protection_States[protection_state_index].initial_risk_valid)
                continue;
            double risk_price = g_Order_Protection_States[protection_state_index].initial_risk_price;
            triggered = (profit_price / risk_price >= g_Order_Runtime_Settings.order_trigger_r);
        }
        else
        {
            triggered = (profit_price / Point() >= g_Order_Runtime_Settings.order_trigger_points);
        }

        if (!triggered) continue;

        // 仅平仓是终止性动作，成功后订单已不存在，不再执行保本或部分平仓。
        if (g_Order_Runtime_Settings.order_protection_mode == B8_ORDER_CLOSE_ONLY)
        {
            B8_CloseOrderFully(ticket, type);
            continue;
        }

        bool need_partial = (g_Order_Runtime_Settings.order_protection_mode == B8_ORDER_PARTIAL_ONLY ||
                     g_Order_Runtime_Settings.order_protection_mode == B8_ORDER_PARTIAL_BE);
        bool need_be = (g_Order_Runtime_Settings.order_protection_mode == B8_ORDER_BE_ONLY ||
                g_Order_Runtime_Settings.order_protection_mode == B8_ORDER_PARTIAL_BE);

        bool be_done = protection_state_index >= 0 &&
                       g_Order_Protection_States[protection_state_index].breakeven_done;
        if (!be_done && B8_IsOrderBreakevenDone(type, open_price, current_sl))
        {
            be_done = true;
            if (protection_state_index >= 0)
                g_Order_Protection_States[protection_state_index].breakeven_done = true;
        }

        bool partial_done = protection_state_index >= 0 &&
                            g_Order_Protection_States[protection_state_index].partial_close_done;
        // 接入说明：接管状态优先于历史记录，重置后允许本周期重新减仓一次。
        // 原始历史判断保留，用于未执行接管的普通订单。
        if (B8_IsRuntimeTakeoverActive(order_magic))
        {
            partial_done = B8_IsRuntimeTakeoverPartialCloseDone(order_magic);
        }
        else if (!partial_done && (B8_HasOrderPartialCloseHistory(order_magic, type) ||
                                   B8_IsPartialCloseBlocked(order_magic)))
        {
            partial_done = true;
            if (protection_state_index >= 0)
                g_Order_Protection_States[protection_state_index].partial_close_done = true;
        }

        // 默认协作模式先保护剩余仓位，再执行部分平仓；失败动作保留到下一 Tick 重试。
        if (need_be && !be_done)
        {
            if (!B8_MoveOrderToBreakeven(ticket, type, open_price)) continue;
            be_done = true;
            if (protection_state_index >= 0)
                g_Order_Protection_States[protection_state_index].breakeven_done = true;
        }

        if (need_partial && !partial_done)
        {
            double lots_before = OrderLots();
            double lot_step = MarketInfo(_Symbol, MODE_LOTSTEP);
            if (lot_step <= 0.0) lot_step = MarketInfo(_Symbol, MODE_MINLOT);
            if (lot_step <= 0.0) lot_step = 0.01;
            double close_lots = MathFloor((lots_before *
                                           g_Order_Runtime_Settings.order_partial_close_percent / 100.0 +
                                           lot_step * 0.0001) / lot_step) * lot_step;
            close_lots = NormalizeDouble(close_lots, 2);
            if (!B8_CloseOrderPartially(ticket, order_magic, type,
                                        g_Order_Runtime_Settings.order_partial_close_percent))
                continue;
            if (protection_state_index >= 0)
            {
                g_Order_Protection_States[protection_state_index].partial_close_done = true;
                g_Order_Protection_States[protection_state_index].partial_closed_lots += close_lots;
                g_Order_Protection_States[protection_state_index].partial_close_count++;
            }
        }
    }

    B8_CleanupOrderProtectionStates();
    // 接入说明：订单消失后清理接管状态，避免当前EA运行期内存持续增长。
    B8_CleanupRuntimeTakeoverStates();
}
//#endregion

//#region MARK: 模块--核心业务：市价单和挂单
//====================================================================
// 核心函数: B8_ExecuteTrade
// 根据信号数据计算手数/止盈，执行 OrderSend
//====================================================================
void B8_ExecuteTrade(const KBarSignal &signal, int type)
{
    // 1. 开仓价 (市价)
    double open_price = (type == OP_BUY) ? Ask : Bid;
    open_price = NormalizeDouble(open_price, _Digits);

    // 2. 止损价
    double sl_price = (type == OP_BUY)
                      ? signal.BullishStopLossPrice
                      : signal.BearishStopLossPrice;
    sl_price = NormalizeDouble(sl_price, _Digits);

    if (sl_price <= 0)
    {
        Print("[Bot8] 错误：止损价格无效 (", sl_price, ")，取消开仓。");
        return;
    }

    /* [方案B参考实现，暂不启用]
       方案B：在此处（sl_price 确定后、sl_price_diff 计算前）直接叠加容错，
       会让止损距离(sl_price_diff/sl_points)一并变大，进而联动影响：
         1) 超限过滤 SL_Max_Allowed_Points 的判定结果；
         2) B8_GetSLTierByPoints 的分级结果，可能改变 effective_risk_value；
         3) GetPositionSize_V1 以损定仓时算出的手数（距离变大，手数变小）。
       若未来要切换为方案B，把下面这段解开注释，并删除本函数末尾方案A中的
    “仅用于实际订单”的 order_sl_price 计算块，直接用 sl_price 发单即可。

    if (Enable_SL_Buffer && SL_Buffer_Points > 0)
    {
       double buffer_price = SL_Buffer_Points * Point();
       sl_price = (type == OP_BUY) ? (sl_price - buffer_price) : (sl_price + buffer_price);
       sl_price = NormalizeDouble(sl_price, _Digits);
    }
    */

    // 2.1 计算信号止损距离（参考价使用K[1]收盘价，便于信号标准化）
    // [旧代码保留] double signal_close = Close[1];
    // 新代码：Close[] 的 Series 方向在当前 EA 中未被可靠保证，直接按 shift 读取已收盘 K 线。
    double signal_close = B8_GetClosedBarClose();
    double sl_price_diff = (type == OP_BUY)
                           ? (signal_close - sl_price)
                           : (sl_price - signal_close);

    if (sl_price_diff <= 0)
    {
        Print("[Bot8][风控] 信号止损方向异常，取消开仓。",
              " 类型:", (type == OP_BUY ? "BUY" : "SELL"),
              " K[1]收盘:", DoubleToString(signal_close, _Digits),
              " SL:", DoubleToString(sl_price, _Digits),
              " 价差:", DoubleToString(sl_price_diff, _Digits));
        return;
    }

    double sl_points = sl_price_diff / Point();

    // 止损最小距离过滤（独立于分级路由，无论 Enable_SL_Tier_Routing 开关如何都会检查）
    if (Enable_SL_Min_Filter)
    {
        int min_sl = MathMax(1, SL_Min_Allowed_Points);
        if (sl_points < min_sl)
        {
            Print("[Bot8][风控] 信号止损过近，拒绝开仓。",
                  " 类型:", (type == OP_BUY ? "BUY" : "SELL"),
                  " 价差:", DoubleToString(sl_price_diff, _Digits),
                  " points:", DoubleToString(sl_points, 1),
                  " MinPoints:", IntegerToString(min_sl));
            return;
        }
    }

    // 默认路由参数
    ENUM_POS_SIZE_MODE effective_pos_mode = g_Runtime_Settings.position_mode;
    double effective_risk_value = g_Runtime_Settings.risk_value;

    // 止损分级与上限过滤
    if (Enable_SL_Tier_Routing)
    {
        int t1 = MathMax(1, SL_Tier_Threshold_1_Points);
        int t2 = MathMax(t1, SL_Tier_Threshold_2_Points);
        int max_sl = MathMax(t2, SL_Max_Allowed_Points);

        // 先做最大止损距离过滤
        if (sl_points > max_sl)
        {
            Print("[Bot8][风控] 信号止损超限，拒绝开仓。",
                  " 类型:", (type == OP_BUY ? "BUY" : "SELL"),
                  " 价差:", DoubleToString(sl_price_diff, _Digits),
                  " points:", DoubleToString(sl_points, 1),
                  " MaxPoints:", IntegerToString(max_sl),
                  " 超限策略:", (Oversize_Signal_Action == B8_OVERSIZE_SKIP ? "SKIP" : "DEFER_PENDING(预留)"));

            if (Oversize_Signal_Action == B8_OVERSIZE_DEFER_PENDING)
            {
                // 仅预留扩展日志：后续可在此接入“挂单回撤入场”模块
                Print("[Bot8][扩展预留] 超限信号已标记为 DeferredCandidate，当前版本不执行挂单逻辑。");
            }
            return;
        }

        ENUM_B8_SL_TIER tier = B8_GetSLTierByPoints(sl_points, t1, t2);

        // 路由规则：>=阈值1后强制使用以损定仓，但风险值始终使用面板 Risk_Value。
        if (sl_points >= t1)
        {
            effective_pos_mode = POS_RISK_BASED;
        }

        Print("[Bot8][SL路由] 类型:", (type == OP_BUY ? "BUY" : "SELL"),
              " K[1]收盘:", DoubleToString(signal_close, _Digits),
              " SL:", DoubleToString(sl_price, _Digits),
              " 价差:", DoubleToString(sl_price_diff, _Digits),
              " points:", DoubleToString(sl_points, 1),
              " Tier:", B8_SLTierToString(tier),
              " 阈值:", IntegerToString(t1), "/", IntegerToString(t2), "/", IntegerToString(max_sl),
              " 仓位模式:", (effective_pos_mode == POS_FIXED_LOT ? "FIXED" : "RISK_BASED"));
    }
    else
    {
        Print("[Bot8][SL路由关闭] 类型:", (type == OP_BUY ? "BUY" : "SELL"),
              " K[1]收盘:", DoubleToString(signal_close, _Digits),
              " SL:", DoubleToString(sl_price, _Digits),
              " 价差:", DoubleToString(sl_price_diff, _Digits),
              " points:", DoubleToString(sl_points, 1));
    }

    // 3. 止盈价 (固定 Pips；0 表示不设置止盈)
    double tp_price = 0.0;
    if (TP_Fixed_Pips > 0.0)
    {
        // 兼容 5 位小数报价 (EURUSD 等) 和 3 位小数报价 (USDJPY 等)
        double pip_size = Point() * ((_Digits == 3 || _Digits == 5) ? 10.0 : 1.0);
        tp_price = (type == OP_BUY)
                   ? open_price + TP_Fixed_Pips * pip_size
                   : open_price - TP_Fixed_Pips * pip_size;
        tp_price = NormalizeDouble(tp_price, _Digits);
    }

    // 4. 仓位计算
    double trade_lots = 0.0;

    if (effective_pos_mode == POS_FIXED_LOT)
    {
        trade_lots = NormalizeLots(g_Runtime_Settings.fixed_lot);
    }
    else if (effective_pos_mode == POS_RISK_BASED)
    {
        trade_lots = GetPositionSize_V1(open_price, sl_price, g_Runtime_Settings.risk_mode, effective_risk_value);
        Print("[Bot8][资金管理]",
              " 模式:", EnumToString(g_Runtime_Settings.risk_mode),
              " 风险值:", effective_risk_value,
              " SL距:", DoubleToString(MathAbs(open_price - sl_price), _Digits),
              " => 手数:", DoubleToString(trade_lots, 2));
    }

    if (trade_lots <= 0)
    {
        Print("[Bot8] 错误：计算手数无效 (<=0)，可能是余额不足或止损过小，取消开仓。");
        return;
    }

    // 5. 构建订单注释
    string open_time = TimeToString(signal.OpenTime, TIME_DATE | TIME_MINUTES);
    open_time = StringSubstr(open_time, 5);
    StringReplace(open_time, ".", "");

    string comment = EA_Version_Tag + "|" +
                     open_time + "|" +
                     B8_TimeframeToText(_Period);

    // 5.1 止损点差容错（方案A）：只影响实际订单止损价，不改变前面风控/仓位计算用到的 sl_price
    double order_sl_price = sl_price;
    if (Enable_SL_Buffer && SL_Buffer_Points > 0)
    {
        double buffer_price = SL_Buffer_Points * Point();
        order_sl_price = (type == OP_BUY) ? (sl_price - buffer_price) : (sl_price + buffer_price);
        order_sl_price = NormalizeDouble(order_sl_price, _Digits);

        Print("[Bot8][SL容错] 类型:", (type == OP_BUY ? "BUY" : "SELL"),
              " 原始SL:", DoubleToString(sl_price, _Digits),
              " 容错点数:", SL_Buffer_Points,
              " 实际SL:", DoubleToString(order_sl_price, _Digits));
    }

    int order_magic = 0;
    if (!B8_AllocateOrderMagic(order_magic))
    {
        Print("[Bot8] 开仓取消：无法分配唯一订单Magic。 家族Magic:", B8_GetMagicFamily());
        return;
    }

    // 6. 发送订单
    int ticket = OrderSend(_Symbol,
                           type,
                           trade_lots,
                           open_price,
                           Slippage,
                           order_sl_price,
                           tp_price,
                           comment,
                           order_magic,
                           0,
                           (type == OP_BUY) ? clrGreen : clrRed);

    if (ticket > 0)
    {
        Print("[Bot8] 开仓成功!",
              " Ticket:", ticket,
              " 类型:", (type == OP_BUY ? "BUY" : "SELL"),
              " Magic:", order_magic,
              " 序号:", B8_GetOrderMagicSeq(order_magic),
              " 手数:", DoubleToString(trade_lots, 2),
              " 入场:", DoubleToString(open_price, _Digits),
              " SL:", DoubleToString(order_sl_price, _Digits),
              " TP:", (tp_price > 0 ? DoubleToString(tp_price, _Digits) : "无"));
    }
    else
    {
        Print("[Bot8] 开仓失败!",
              " 错误码:", GetLastError(),
              " 入场价:", DoubleToString(open_price, _Digits),
              " SL:", DoubleToString(order_sl_price, _Digits));
    }
}

//====================================================================
// 挂单执行：只处理计划挂单价和限价订单。
//====================================================================
void B8_ExecutePendingTrade(const KBarSignal &signal, int type,
                             double entry_price, string plan_tag,
                             double allocated_risk_value,
                             double override_stop_price = 0.0,
                             int override_pending_type = OP_NONE)
{
    string fib_position_text = B8_PendingPlanPositionText(plan_tag);

    // 1. 计划入场价：市价计划使用当前价，挂单计划使用其目标价。
    double open_price = NormalizeDouble(entry_price, _Digits);

    // 2. 止损价
    // 旧实现：历史信号挂单从信号结构中读取止损价。
    // double sl_price = (type == OP_BUY)
    //                   ? signal.BullishStopLossPrice
    //                   : signal.BearishStopLossPrice;
    double sl_price = (override_stop_price > 0.0)
                      ? override_stop_price
                      : ((type == OP_BUY)
                         ? signal.BullishStopLossPrice
                         : signal.BearishStopLossPrice);
    sl_price = NormalizeDouble(sl_price, _Digits);

    if (sl_price <= 0)
    {
        Print("[Bot8] 错误：止损价格无效 (", sl_price, ")，取消开仓。");
        return;
    }

    /* [方案B参考实现，暂不启用]
       方案B：在此处（sl_price 确定后、sl_price_diff 计算前）直接叠加容错，
       会让止损距离(sl_price_diff/sl_points)一并变大，进而联动影响：
         1) 超限过滤 SL_Max_Allowed_Points 的判定结果；
         2) B8_GetSLTierByPoints 的分级结果，可能改变 effective_risk_value；
         3) GetPositionSize_V1 以损定仓时算出的手数（距离变大，手数变小）。
       若未来要切换为方案B，把下面这段解开注释，并删除本函数末尾方案A中的
       “仅用于挂单”的 order_sl_price 计算块，直接用 sl_price 发单即可。

    if (Enable_SL_Buffer && SL_Buffer_Points > 0)
    {
       double buffer_price = SL_Buffer_Points * Point();
       sl_price = (type == OP_BUY) ? (sl_price - buffer_price) : (sl_price + buffer_price);
       sl_price = NormalizeDouble(sl_price, _Digits);
    }
    */

    // 挂单风险距离使用计划挂单价。
    double signal_close = open_price;
    double sl_price_diff = (type == OP_BUY)
                           ? (signal_close - sl_price)
                           : (sl_price - signal_close);

    if (sl_price_diff <= 0)
    {
        Print("[Bot8][风控] 信号止损方向异常，取消开仓。",
              " 类型:", (type == OP_BUY ? "BUY" : "SELL"),
              " 计划入场:", DoubleToString(signal_close, _Digits),
              " SL:", DoubleToString(sl_price, _Digits),
              " 价差:", DoubleToString(sl_price_diff, _Digits));
        return;
    }

    double sl_points = sl_price_diff / Point();

    // 止损最小距离过滤（独立于分级路由，无论 Enable_SL_Tier_Routing 开关如何都会检查）
    if (Enable_SL_Min_Filter)
    {
        int min_sl = MathMax(1, SL_Min_Allowed_Points);
        if (sl_points < min_sl)
        {
            Print("[Bot8][风控] 信号止损过近，拒绝开仓。",
                  " 类型:", (type == OP_BUY ? "BUY" : "SELL"),
                  " 价差:", DoubleToString(sl_price_diff, _Digits),
                  " points:", DoubleToString(sl_points, 1),
                  " MinPoints:", IntegerToString(min_sl));
            return;
        }
    }

    // 默认路由参数
    ENUM_POS_SIZE_MODE effective_pos_mode = g_Runtime_Settings.position_mode;
    double effective_risk_value = (allocated_risk_value > 0.0)
                                  ? allocated_risk_value
                                  : g_Runtime_Settings.risk_value;

    // 止损分级与上限过滤
    if (Enable_SL_Tier_Routing)
    {
        int t1 = MathMax(1, SL_Tier_Threshold_1_Points);
        int t2 = MathMax(t1, SL_Tier_Threshold_2_Points);
        int max_sl = MathMax(t2, SL_Max_Allowed_Points);

        // 先做最大止损距离过滤
        if (sl_points > max_sl)
        {
            Print("[Bot8][风控] 信号止损超限，拒绝开仓。",
                  " 类型:", (type == OP_BUY ? "BUY" : "SELL"),
                  " 价差:", DoubleToString(sl_price_diff, _Digits),
                  " points:", DoubleToString(sl_points, 1),
                  " MaxPoints:", IntegerToString(max_sl),
                  " 超限策略:", (Oversize_Signal_Action == B8_OVERSIZE_SKIP ? "SKIP" : "DEFER_PENDING(预留)"));

            if (Oversize_Signal_Action == B8_OVERSIZE_DEFER_PENDING)
            {
                // 仅预留扩展日志：后续可在此接入“挂单回撤入场”模块
                Print("[Bot8][扩展预留] 超限信号已标记为 DeferredCandidate，当前版本不执行挂单逻辑。");
            }
            return;
        }

        ENUM_B8_SL_TIER tier = B8_GetSLTierByPoints(sl_points, t1, t2);

        // 路由规则：>=阈值1后强制使用以损定仓，但风险值始终使用面板 Risk_Value。
        if (sl_points >= t1)
        {
            effective_pos_mode = POS_RISK_BASED;
        }

        Print("[Bot8][SL路由] 类型:", (type == OP_BUY ? "BUY" : "SELL"),
              " 计划入场:", DoubleToString(signal_close, _Digits),
              " SL:", DoubleToString(sl_price, _Digits),
              " 价差:", DoubleToString(sl_price_diff, _Digits),
              " points:", DoubleToString(sl_points, 1),
              " Tier:", B8_SLTierToString(tier),
              " 阈值:", IntegerToString(t1), "/", IntegerToString(t2), "/", IntegerToString(max_sl),
              " 仓位模式:", (effective_pos_mode == POS_FIXED_LOT ? "FIXED" : "RISK_BASED"));
    }
    else
    {
        Print("[Bot8][SL路由关闭] 类型:", (type == OP_BUY ? "BUY" : "SELL"),
              " 计划入场:", DoubleToString(signal_close, _Digits),
              " SL:", DoubleToString(sl_price, _Digits),
              " 价差:", DoubleToString(sl_price_diff, _Digits),
              " points:", DoubleToString(sl_points, 1));
    }

    // 3. 止盈价 (固定 Pips；0 表示不设置止盈)
    double tp_price = 0.0;
    if (TP_Fixed_Pips > 0.0)
    {
        // 兼容 5 位小数报价 (EURUSD 等) 和 3 位小数报价 (USDJPY 等)
        double pip_size = Point() * ((_Digits == 3 || _Digits == 5) ? 10.0 : 1.0);
        tp_price = (type == OP_BUY)
                   ? open_price + TP_Fixed_Pips * pip_size
                   : open_price - TP_Fixed_Pips * pip_size;
        tp_price = NormalizeDouble(tp_price, _Digits);
    }

    // 4. 仓位计算
    double trade_lots = 0.0;

    if (effective_pos_mode == POS_FIXED_LOT)
    {
        trade_lots = NormalizeLots(g_Runtime_Settings.fixed_lot);
    }
    else if (effective_pos_mode == POS_RISK_BASED)
    {
        trade_lots = GetPositionSize_V1(open_price, sl_price, g_Runtime_Settings.risk_mode, effective_risk_value);
        Print("[Bot8][资金管理]",
              " 位置:", fib_position_text,
              " 模式:", EnumToString(g_Runtime_Settings.risk_mode),
              " 风险值:", effective_risk_value,
              " SL距:", DoubleToString(MathAbs(open_price - sl_price), _Digits),
              " => 手数:", DoubleToString(trade_lots, 2));
    }

    if (trade_lots <= 0)
    {
        Print("[Bot8] 错误：计算手数无效 (<=0)，可能是余额不足或止损过小，取消开仓。");
        return;
    }

    // 5. 构建订单注释
    string open_time = TimeToString(signal.OpenTime, TIME_DATE | TIME_MINUTES);
    open_time = StringSubstr(open_time, 5);

    // 挂单组标识保持短小，避免MT4订单注释长度限制截断Fib标记。
    string comment = EA_Version_Tag + plan_tag;

    // 5.1 止损点差容错（方案A）：只影响实际挂单止损价，不改变前面风控/仓位计算用到的 sl_price
    double order_sl_price = sl_price;
    if (Enable_SL_Buffer && SL_Buffer_Points > 0)
    {
        double buffer_price = SL_Buffer_Points * Point();
        order_sl_price = (type == OP_BUY) ? (sl_price - buffer_price) : (sl_price + buffer_price);
        order_sl_price = NormalizeDouble(order_sl_price, _Digits);

        Print("[Bot8][SL容错] 类型:", (type == OP_BUY ? "BUY" : "SELL"),
              " 原始SL:", DoubleToString(sl_price, _Digits),
              " 容错点数:", SL_Buffer_Points,
              " 挂单SL:", DoubleToString(order_sl_price, _Digits));
    }

    int order_magic = 0;
    if (!B8_AllocateOrderMagic(order_magic))
    {
        Print("[Bot8] 开仓取消：无法分配唯一订单Magic。 家族Magic:", B8_GetMagicFamily());
        return;
    }

    // 6. 发送订单
    // 旧实现：所有挂单固定使用 Buy Limit / Sell Limit。
    // int ticket = OrderSend(_Symbol,
    //                        (type == OP_BUY) ? OP_BUYLIMIT : OP_SELLLIMIT,
    //                        trade_lots, open_price, Slippage, order_sl_price,
    //                        tp_price, comment, order_magic, 0,
    //                        (type == OP_BUY) ? clrGreen : clrRed);
    int send_order_type = (override_pending_type != OP_NONE)
                          ? override_pending_type
                          : ((type == OP_BUY) ? OP_BUYLIMIT : OP_SELLLIMIT);
    int ticket = OrderSend(_Symbol,
                           send_order_type,
                           trade_lots,
                           open_price,
                           Slippage,
                           order_sl_price,
                           tp_price,
                           comment,
                           order_magic,
                           0,
                           (type == OP_BUY) ? clrGreen : clrRed);

    if (ticket > 0)
    {
        Print("[Bot8] 开仓成功!",
              " Ticket:", ticket,
              " 类型:", (type == OP_BUY ? "BUY" : "SELL"),
              " 位置:", fib_position_text,
              " Magic:", order_magic,
              " 序号:", B8_GetOrderMagicSeq(order_magic),
              " 手数:", DoubleToString(trade_lots, 2),
              " 入场:", DoubleToString(open_price, _Digits),
              " SL:", DoubleToString(order_sl_price, _Digits),
              " TP:", (tp_price > 0 ? DoubleToString(tp_price, _Digits) : "无"));
    }
    else
    {
        Print("[Bot8] 开仓失败!",
              " 错误码:", GetLastError(),
              " 位置:", fib_position_text,
              " 入场价:", DoubleToString(open_price, _Digits),
              " SL:", DoubleToString(order_sl_price, _Digits));
    }
}
//#endregion

//#region MARK: 模块--核心业务：斐波实时挂单和历史挂单
// 根据算法开关分发Fib实时挂单计划创建逻辑。
void B8_CreatePendingPlans(const KBarSignal &signal, int type)
{
    if (Fib_Pending_Algorithm == B8_FIB_ALGO_V2)
        B8_CreatePendingPlansV2(signal, type);
    else
        B8_CreatePendingPlansV3(signal, type);
}

// V3：根据Fib 0到Fib 1的信号区间，为选中的位置创建独立挂单计划。
void B8_CreatePendingPlansV3(const KBarSignal &signal, int type)
{
    double fib0 = (type == OP_BUY) ? signal.BullishStopLossPrice
                                   : signal.BearishStopLossPrice;
    // [旧代码保留] double fib1 = Close[1];
    // 新代码：Fibo 的基准价必须与 MT7 的 shift=1 信号使用同一根已收盘 K 线。
    double fib1 = B8_GetClosedBarClose();
    string group_key = B8_PendingGroupKey(signal, type);
    double levels[8] = {0.120, 0.214, 0.236, 0.382, 0.500, 0.618, 0.786, 0.880};
    bool created_any = false;
    // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 开始插入-------------------
    // 为什么要注销V2版本的代码，因为在审查过程中 【发现 2：预筛选没有提前验证“分配后的风险是否能形成有效手数”】
    // 这是什么意思呢？就是说 如果给Fibo位置分配的风险金额根本不足以该Fibo位置开仓，那么这个Fibo位置就会舍弃
    // 这就导致原本假设30美金的风险预算 没有用完，那么开仓的手数就会降低，实际风险小于预算风险，虽然是好事
    // 但是会导致仓位下不够的结果 所以就是开发v3版本的代码
    // 结论是 是的，当某些 Fib 分配后的风险低于其最小手数可承受风险时，总风险预算无法完全使用，最终实际风险可能明显低于用户设置的 $30。
    // 风险预算分配发生在最小手数可行性检查之前，失败后的风险没有回收和二次分配。
    /*
    int effective_count = 0;

    // 风险分配开启时，先筛选最终有效的Fib，避免无效位置占用权重。
    if (Enable_Fib_Risk_Allocation)
    {
        for (int precheck_index = 0; precheck_index < 8; precheck_index++)
        {
            double precheck_level = levels[precheck_index];
            if (!B8_IsPendingFibSelected(precheck_level)) continue;

            double precheck_entry = NormalizeDouble(fib0 + precheck_level * (fib1 - fib0), _Digits);
            RefreshRates();
            bool precheck_price_valid = (type == OP_BUY) ? (precheck_entry < Ask)
                                                        : (precheck_entry > Bid);
            if (!precheck_price_valid) continue;

            string precheck_code = IntegerToString((int)MathRound(precheck_level * 1000.0));
            string precheck_tag = group_key + "|F" + precheck_code + "|" + B8_TimeframeToText(_Period);
            if (B8_IsFibRiskEligible(signal, type, precheck_entry, precheck_tag))
                effective_count++;
        }

        Print("[Bot8][Fib风险分配] 有效Fib数量:", effective_count,
              " / 已选:", B8_CountSelectedPendingFib(),
              " 总风险值:", DoubleToString(g_Runtime_Settings.risk_value, 2));
    }

    int effective_order_index = 0;
    */
    // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 结束插入-------------------

    // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V3 开始插入-------------------
    int fib_risk_eligible_mask = 0;
    int effective_count = 0;

    if (Enable_Fib_Risk_Allocation)
    {
        for (int precheck_index = 0; precheck_index < 8; precheck_index++)
        {
            double precheck_level = levels[precheck_index];
            if (!B8_IsPendingFibSelected(precheck_level)) continue;

            double precheck_entry = NormalizeDouble(fib0 + precheck_level * (fib1 - fib0), _Digits);
            RefreshRates();
            bool precheck_price_valid = (type == OP_BUY) ? (precheck_entry < Ask)
                                                        : (precheck_entry > Bid);
            if (!precheck_price_valid) continue;

            string precheck_code = IntegerToString((int)MathRound(precheck_level * 1000.0));
            string precheck_tag = group_key + "|F" + precheck_code + "|" + B8_TimeframeToText(_Period);
            if (B8_IsFibRiskEligible(signal, type, precheck_entry, precheck_tag))
                fib_risk_eligible_mask |= (1 << precheck_index);
        }

        bool eligibility_changed = true;
        while (eligibility_changed)
        {
            eligibility_changed = false;
            effective_count = 0;

            for (int count_index = 0; count_index < 8; count_index++)
            {
                if ((fib_risk_eligible_mask & (1 << count_index)) != 0)
                    effective_count++;
            }

            for (int check_order = 0; check_order < 8; check_order++)
            {
                int risk_check_index = B8_GetFibRiskCheckIndex(check_order);
                if ((fib_risk_eligible_mask & (1 << risk_check_index)) == 0) continue;

                double risk_check_level = levels[risk_check_index];
                double risk_check_entry = NormalizeDouble(fib0 + risk_check_level * (fib1 - fib0), _Digits);
                int allocation_index = 0;
                for (int allocation_scan_index = 0;
                     allocation_scan_index < risk_check_index;
                     allocation_scan_index++)
                {
                    if ((fib_risk_eligible_mask & (1 << allocation_scan_index)) != 0)
                        allocation_index++;
                }
                double allocated_risk_value = B8_GetFibAllocatedRisk(allocation_index,
                                                                     effective_count);
                if (!B8_CanFormPendingRiskLot(signal, type, risk_check_entry,
                                              allocated_risk_value))
                {
                    fib_risk_eligible_mask &= ~(1 << risk_check_index);
                    eligibility_changed = true;
                    break;
                }
            }
        }

        Print("[Bot8][Fib风险分配] 有效Fib数量:", effective_count,
              " / 已选:", B8_CountSelectedPendingFib(),
              " 总风险值:", DoubleToString(g_Runtime_Settings.risk_value, 2));
    }

    int effective_order_index = 0;
    // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V3 结束插入-------------------

    for (int i = 0; i < 8; i++)
    {
        double fib_level = levels[i];
        if (!B8_IsPendingFibSelected(fib_level)) continue;

        double entry_price = NormalizeDouble(fib0 + fib_level * (fib1 - fib0), _Digits);
        RefreshRates();
        bool price_valid = (type == OP_BUY) ? (entry_price < Ask) : (entry_price > Bid);
        if (!price_valid)
        {
            Print("[Bot8][挂单] Fib位置不满足Limit方向，跳过。",
                  " 组:", group_key,
                  " Fib:", DoubleToString(fib_level, 3),
                  " 入场:", DoubleToString(entry_price, _Digits));
            continue;
        }

        string fib_code = IntegerToString((int)MathRound(fib_level * 1000.0));
        string plan_tag = group_key + "|F" + fib_code + "|" + B8_TimeframeToText(_Period);

        // ------------------- 手术切入口：开始新增斐波挂单仓位权重计算功能 V1 原始版本 开始注销了-------------------
        /*
        bool duplicate = false;
        for (int j = 0; j < OrdersTotal(); j++)
        {
            if (!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
            if (!B8_IsManagedOrder()) continue;
            if (StringFind(OrderComment(), plan_tag, 0) >= 0)
            {
                duplicate = true;
                break;
            }
        }
        if (duplicate) continue;

        B8_ExecutePendingTrade(signal, type, entry_price, plan_tag);
        */
        // ------------------- 手术切入口：开始新增斐波挂单仓位权重计算功能 V1 原始版本 结束注销了-------------------


        // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 开始插入-------------------
        double allocated_risk_value = -1.0;
        if (Enable_Fib_Risk_Allocation)
        {
            // 下面这一行是v2注销的代码
            // if (!B8_IsFibRiskEligible(signal, type, entry_price, plan_tag)) continue;
            if ((fib_risk_eligible_mask & (1 << i)) == 0) continue;
            allocated_risk_value = B8_GetFibAllocatedRisk(effective_order_index,
                                                          effective_count);
            effective_order_index++;
        }
        else if (B8_IsPendingPlanDuplicate(plan_tag))
        {
            continue;
        }

        B8_ExecutePendingTrade(signal, type, entry_price, plan_tag,
                               allocated_risk_value);
        // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 结束插入-------------------
        created_any = true;
    }

    if (!created_any)
        Print("[Bot8][挂单] 本信号没有创建有效挂单，请检查Fib选择或价格方向。 组:", group_key);
}

// 保留V2版本意义很重要 虽然少于预算的风险 但是在小金额账户下 非常友好
void B8_CreatePendingPlansV2(const KBarSignal &signal, int type)
{
    double fib0 = (type == OP_BUY) ? signal.BullishStopLossPrice
                                   : signal.BearishStopLossPrice;
    // [旧代码保留] double fib1 = Close[1];
    // 新代码：Fibo 的基准价必须与 MT7 的 shift=1 信号使用同一根已收盘 K 线。
    double fib1 = B8_GetClosedBarClose();
    string group_key = B8_PendingGroupKey(signal, type);
    double levels[8] = {0.120, 0.214, 0.236, 0.382, 0.500, 0.618, 0.786, 0.880};
    bool created_any = false;
    // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 开始插入-------------------
    // 为什么要注销V2版本的代码，因为在审查过程中 【发现 2：预筛选没有提前验证“分配后的风险是否能形成有效手数”】
    // 这是什么意思呢？就是说 如果给Fibo位置分配的风险金额根本不足以该Fibo位置开仓，那么这个Fibo位置就会舍弃
    // 这就导致原本假设30美金的风险预算 没有用完，那么开仓的手数就会降低，实际风险小于预算风险，虽然是好事
    // 但是会导致仓位下不够的结果 所以就是开发v3版本的代码
    // 结论是 是的，当某些 Fib 分配后的风险低于其最小手数可承受风险时，总风险预算无法完全使用，最终实际风险可能明显低于用户设置的 $30。
    // 风险预算分配发生在最小手数可行性检查之前，失败后的风险没有回收和二次分配。

    int effective_count = 0;

    // 风险分配开启时，先筛选最终有效的Fib，避免无效位置占用权重。
    if (Enable_Fib_Risk_Allocation)
    {
        for (int precheck_index = 0; precheck_index < 8; precheck_index++)
        {
            double precheck_level = levels[precheck_index];
            if (!B8_IsPendingFibSelected(precheck_level)) continue;

            double precheck_entry = NormalizeDouble(fib0 + precheck_level * (fib1 - fib0), _Digits);
            RefreshRates();
            bool precheck_price_valid = (type == OP_BUY) ? (precheck_entry < Ask)
                                                        : (precheck_entry > Bid);
            if (!precheck_price_valid) continue;

            string precheck_code = IntegerToString((int)MathRound(precheck_level * 1000.0));
            string precheck_tag = group_key + "|F" + precheck_code + "|" + B8_TimeframeToText(_Period);
            if (B8_IsFibRiskEligible(signal, type, precheck_entry, precheck_tag))
                effective_count++;
        }

        Print("[Bot8][Fib风险分配] 有效Fib数量:", effective_count,
              " / 已选:", B8_CountSelectedPendingFib(),
              " 总风险值:", DoubleToString(g_Runtime_Settings.risk_value, 2));
    }

    int effective_order_index = 0;
    // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 结束插入-------------------

    for (int i = 0; i < 8; i++)
    {
        double fib_level = levels[i];
        if (!B8_IsPendingFibSelected(fib_level)) continue;

        double entry_price = NormalizeDouble(fib0 + fib_level * (fib1 - fib0), _Digits);
        RefreshRates();
        bool price_valid = (type == OP_BUY) ? (entry_price < Ask) : (entry_price > Bid);
        if (!price_valid)
        {
            Print("[Bot8][挂单] Fib位置不满足Limit方向，跳过。",
                  " 组:", group_key,
                  " Fib:", DoubleToString(fib_level, 3),
                  " 入场:", DoubleToString(entry_price, _Digits));
            continue;
        }

        string fib_code = IntegerToString((int)MathRound(fib_level * 1000.0));
        string plan_tag = group_key + "|F" + fib_code + "|" + B8_TimeframeToText(_Period);

        // ------------------- 手术切入口：开始新增斐波挂单仓位权重计算功能 V1 原始版本 开始注销了-------------------
        /*
        bool duplicate = false;
        for (int j = 0; j < OrdersTotal(); j++)
        {
            if (!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
            if (!B8_IsManagedOrder()) continue;
            if (StringFind(OrderComment(), plan_tag, 0) >= 0)
            {
                duplicate = true;
                break;
            }
        }
        if (duplicate) continue;

        B8_ExecutePendingTrade(signal, type, entry_price, plan_tag);
        */
        // ------------------- 手术切入口：开始新增斐波挂单仓位权重计算功能 V1 原始版本 结束注销了-------------------


        // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 开始插入-------------------
        double allocated_risk_value = -1.0;
        if (Enable_Fib_Risk_Allocation)
        {
            if (!B8_IsFibRiskEligible(signal, type, entry_price, plan_tag)) continue;
            allocated_risk_value = B8_GetFibAllocatedRisk(effective_order_index,
                                                          effective_count);
            effective_order_index++;
        }
        else if (B8_IsPendingPlanDuplicate(plan_tag))
        {
            continue;
        }

        B8_ExecutePendingTrade(signal, type, entry_price, plan_tag,
                               allocated_risk_value);
        // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 结束插入-------------------
        created_any = true;
    }

    if (!created_any)
        Print("[Bot8][挂单] 本信号没有创建有效挂单，请检查Fib选择或价格方向。 组:", group_key);
}

// 根据算法开关分发历史Fib挂单计划创建逻辑。
bool B8_CreateHistoricalPendingPlans(const KBarSignal &signal, int shift)
{
    if (Fib_Pending_Algorithm == B8_FIB_ALGO_V2)
        return B8_CreateHistoricalPendingPlansV2(signal, shift);

    return B8_CreateHistoricalPendingPlansV3(signal, shift);
}

// V3：独立历史信号补挂计划，Fib基准使用指定历史K线的Close[shift]。
bool B8_CreateHistoricalPendingPlansV3(const KBarSignal &signal, int shift)
{
    Print("[Bot8][历史补挂调试] 进入历史补挂计划函数。shift:", shift,
          " Entry_Mode:", g_Runtime_Entry_Mode,
          " Fib选择数量:", B8_CountSelectedPendingFib());

    if (g_Runtime_Entry_Mode == B8_ENTRY_MARKET)
    {
        Print("[Bot8][历史补挂] 当前Entry_Mode不允许创建挂单。");
        g_History_Status_Message = "当前模式不允许挂单";
        B8_UpdateHistoricalFibPanel();
        return false;
    }

    // 历史补挂由用户通过面板按钮主动触发，不属于OnTick实时信号入口。
    // 因此即使主EA开关g_EA_Enabled为关闭状态，也允许继续执行本次明确的补挂动作。
    // 保留原有开关限制代码，便于未来需要恢复“EA关闭时禁止历史补挂”策略时检查和启用。
    /*
    if (!g_EA_Enabled)
    {
        Print("[Bot8][历史补挂] EA当前未开启，取消执行。");
        g_History_Status_Message = "请先开启EA再补挂";
        B8_UpdateHistoricalFibPanel();
        return false;
    }
    */

    if (shift < 1 || shift >= iBars(_Symbol, _Period))
    {
        g_History_Status_Message = "历史K线范围无效";
        B8_UpdateHistoricalFibPanel();
        return false;
    }

    double fib1 = iClose(_Symbol, _Period, shift);
    if (fib1 <= 0.0)
    {
        g_History_Status_Message = "历史K线收盘价无效";
        B8_UpdateHistoricalFibPanel();
        return false;
    }

    bool has_bull = (signal.BullishReferencePrice != (double)EMPTY_VALUE &&
                     signal.BullishReferencePrice != 0.0 &&
                     signal.BullishStopLossPrice != (double)EMPTY_VALUE &&
                     signal.BullishStopLossPrice != 0.0);
    bool has_bear = (signal.BearishReferencePrice != (double)EMPTY_VALUE &&
                     signal.BearishReferencePrice != 0.0 &&
                     signal.BearishStopLossPrice != (double)EMPTY_VALUE &&
                     signal.BearishStopLossPrice != 0.0);

    if (!has_bull && !has_bear)
    {
        g_History_Status_Message = "该历史K线没有有效信号";
        B8_UpdateHistoricalFibPanel();
        return false;
    }

    if (g_Trade_Mode == B8_MODE_NORMAL && has_bull && has_bear)
    {
        Print("[Bot8][历史补挂] 历史K线同时存在多空信号，本次不执行。",
              " 时间:", TimeToString(signal.OpenTime));
        g_History_Status_Message = "历史K线多空同时出现，未执行";
        B8_UpdateHistoricalFibPanel();
        return false;
    }

    double levels[8] = {0.120, 0.214, 0.236, 0.382, 0.500, 0.618, 0.786, 0.880};
    int types[2] = {OP_BUY, OP_SELL};
    bool created_any = false;

    for (int direction_index = 0; direction_index < 2; direction_index++)
    {
        int type = types[direction_index];
        if (type == OP_BUY && (!has_bull || g_Trade_Mode == B8_MODE_SELL_ONLY))
        {
            Print("[Bot8][历史补挂] 跳过BUY方向：",
                  (!has_bull ? "历史K线没有BUY信号" : "当前为只空模式"));
            continue;
        }
        if (type == OP_SELL && (!has_bear || g_Trade_Mode == B8_MODE_BUY_ONLY))
        {
            Print("[Bot8][历史补挂] 跳过SELL方向：",
                  (!has_bear ? "历史K线没有SELL信号" : "当前为只多模式"));
            continue;
        }

        double fib0 = (type == OP_BUY) ? signal.BullishStopLossPrice
                                       : signal.BearishStopLossPrice;
        string group_key = B8_PendingGroupKey(signal, type);
        // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 开始插入-------------------
        /*
        int effective_count = 0;

        // 风险分配开启时，历史补挂也只按最终有效Fib参与权重计算。
        if (Enable_Fib_Risk_Allocation)
        {
            for (int precheck_index = 0; precheck_index < 8; precheck_index++)
            {
                double precheck_level = levels[precheck_index];
                if (!B8_IsPendingFibSelected(precheck_level)) continue;

                double precheck_entry = NormalizeDouble(fib0 + precheck_level * (fib1 - fib0), _Digits);
                RefreshRates();
                bool precheck_price_valid = (type == OP_BUY) ? (precheck_entry < Ask)
                                                            : (precheck_entry > Bid);
                if (!precheck_price_valid) continue;

                string precheck_code = IntegerToString((int)MathRound(precheck_level * 1000.0));
                string precheck_tag = group_key + B8_HISTORY_PLAN_MARKER
                                      + "|F" + precheck_code + "|" + B8_TimeframeToText(_Period);
                if (B8_IsFibRiskEligible(signal, type, precheck_entry, precheck_tag))
                    effective_count++;
            }

            Print("[Bot8][历史补挂][Fib风险分配] 有效Fib数量:", effective_count,
                  " / 已选:", B8_CountSelectedPendingFib(),
                  " 总风险值:", DoubleToString(g_Runtime_Settings.risk_value, 2));
        }

        int effective_order_index = 0;
        */
        // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 结束插入-------------------

        // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V3 开始插入-------------------
        int fib_risk_eligible_mask = 0;
        int effective_count = 0;

        if (Enable_Fib_Risk_Allocation)
        {
            for (int precheck_index = 0; precheck_index < 8; precheck_index++)
            {
                double precheck_level = levels[precheck_index];
                if (!B8_IsPendingFibSelected(precheck_level)) continue;

                double precheck_entry = NormalizeDouble(fib0 + precheck_level * (fib1 - fib0), _Digits);
                RefreshRates();
                bool precheck_price_valid = (type == OP_BUY) ? (precheck_entry < Ask)
                                                            : (precheck_entry > Bid);
                if (!precheck_price_valid) continue;

                string precheck_code = IntegerToString((int)MathRound(precheck_level * 1000.0));
                string precheck_tag = group_key + B8_HISTORY_PLAN_MARKER
                                      + "|F" + precheck_code + "|" + B8_TimeframeToText(_Period);
                if (B8_IsFibRiskEligible(signal, type, precheck_entry, precheck_tag))
                    fib_risk_eligible_mask |= (1 << precheck_index);
            }

            bool eligibility_changed = true;
            while (eligibility_changed)
            {
                eligibility_changed = false;
                effective_count = 0;

                for (int count_index = 0; count_index < 8; count_index++)
                {
                    if ((fib_risk_eligible_mask & (1 << count_index)) != 0)
                        effective_count++;
                }

                for (int check_order = 0; check_order < 8; check_order++)
                {
                    int risk_check_index = B8_GetFibRiskCheckIndex(check_order);
                    if ((fib_risk_eligible_mask & (1 << risk_check_index)) == 0) continue;

                    double risk_check_level = levels[risk_check_index];
                    double risk_check_entry = NormalizeDouble(fib0 + risk_check_level * (fib1 - fib0), _Digits);
                    int allocation_index = 0;
                    for (int allocation_scan_index = 0;
                         allocation_scan_index < risk_check_index;
                         allocation_scan_index++)
                    {
                        if ((fib_risk_eligible_mask & (1 << allocation_scan_index)) != 0)
                            allocation_index++;
                    }
                    double allocated_risk_value = B8_GetFibAllocatedRisk(allocation_index,
                                                                         effective_count);
                    if (!B8_CanFormPendingRiskLot(signal, type, risk_check_entry,
                                                  allocated_risk_value))
                    {
                        fib_risk_eligible_mask &= ~(1 << risk_check_index);
                        eligibility_changed = true;
                        break;
                    }
                }
            }

            Print("[Bot8][历史补挂][Fib风险分配] 有效Fib数量:", effective_count,
                  " / 已选:", B8_CountSelectedPendingFib(),
                  " 总风险值:", DoubleToString(g_Runtime_Settings.risk_value, 2));
        }

        int effective_order_index = 0;
        // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V3 结束插入-------------------

        for (int i = 0; i < 8; i++)
        {
            double fib_level = levels[i];
            if (!B8_IsPendingFibSelected(fib_level)) continue;

            double entry_price = NormalizeDouble(fib0 + fib_level * (fib1 - fib0), _Digits);
            RefreshRates();
            bool price_valid = (type == OP_BUY) ? (entry_price < Ask) : (entry_price > Bid);
            if (!price_valid)
            {
                Print("[Bot8][历史补挂] Fib不满足当前Limit方向，跳过。",
                      " K[", shift, "] Fib:", DoubleToString(fib_level, 3),
                      " 入场:", DoubleToString(entry_price, _Digits));
                continue;
            }

            string fib_code = IntegerToString((int)MathRound(fib_level * 1000.0));
            string plan_tag = group_key + B8_HISTORY_PLAN_MARKER
                              + "|F" + fib_code + "|" + B8_TimeframeToText(_Period);
            // ------------------- 手术切入口：开始新增斐波挂单仓位权重计算功能 V1 原始版本 开始注销了-------------------
            /*
            bool duplicate = false;
            for (int j = 0; j < OrdersTotal(); j++)
            {
                if (!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
                if (!B8_IsManagedOrder()) continue;
                if (StringFind(OrderComment(), plan_tag, 0) >= 0)
                {
                    duplicate = true;
                    break;
                }
            }
            if (duplicate)
            {
                Print("[Bot8][历史补挂] 已存在相同计划，跳过。计划:", plan_tag);
                continue;
            }

            B8_ExecutePendingTrade(signal, type, entry_price, plan_tag);
            */
            // ------------------- 手术切入口：开始新增斐波挂单仓位权重计算功能 V1 原始版本 结束注销了-------------------

           // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 开始插入-------------------
            double allocated_risk_value = -1.0;
            if (Enable_Fib_Risk_Allocation)
            {
                // if (!B8_IsFibRiskEligible(signal, type, entry_price, plan_tag))
                //     continue;
                if ((fib_risk_eligible_mask & (1 << i)) == 0) continue;
                allocated_risk_value = B8_GetFibAllocatedRisk(effective_order_index,
                                                              effective_count);
                effective_order_index++;
            }
            else if (B8_IsPendingPlanDuplicate(plan_tag))
            {
                Print("[Bot8][历史补挂] 已存在相同计划，跳过。计划:", plan_tag);
                continue;
            }

            B8_ExecutePendingTrade(signal, type, entry_price, plan_tag,
                                   allocated_risk_value);
            // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 结束插入-------------------
            created_any = true;
        }
    }

    g_History_Status_Message = created_any ? "历史补挂计划已提交" : "没有创建有效历史挂单";
    B8_UpdateHistoricalFibPanel();
    return created_any;
}

bool B8_CreateHistoricalPendingPlansV2(const KBarSignal &signal, int shift)
{
    Print("[Bot8][历史补挂调试] 进入历史补挂计划函数。shift:", shift,
          " Entry_Mode:", g_Runtime_Entry_Mode,
          " Fib选择数量:", B8_CountSelectedPendingFib());

    if (g_Runtime_Entry_Mode == B8_ENTRY_MARKET)
    {
        Print("[Bot8][历史补挂] 当前Entry_Mode不允许创建挂单。");
        g_History_Status_Message = "当前模式不允许挂单";
        B8_UpdateHistoricalFibPanel();
        return false;
    }

    // 历史补挂由用户通过面板按钮主动触发，不属于OnTick实时信号入口。
    // 因此即使主EA开关g_EA_Enabled为关闭状态，也允许继续执行本次明确的补挂动作。
    // 保留原有开关限制代码，便于未来需要恢复“EA关闭时禁止历史补挂”策略时检查和启用。
    /*
    if (!g_EA_Enabled)
    {
        Print("[Bot8][历史补挂] EA当前未开启，取消执行。");
        g_History_Status_Message = "请先开启EA再补挂";
        B8_UpdateHistoricalFibPanel();
        return false;
    }
    */

    if (shift < 1 || shift >= iBars(_Symbol, _Period))
    {
        g_History_Status_Message = "历史K线范围无效";
        B8_UpdateHistoricalFibPanel();
        return false;
    }

    double fib1 = iClose(_Symbol, _Period, shift);
    if (fib1 <= 0.0)
    {
        g_History_Status_Message = "历史K线收盘价无效";
        B8_UpdateHistoricalFibPanel();
        return false;
    }

    bool has_bull = (signal.BullishReferencePrice != (double)EMPTY_VALUE &&
                     signal.BullishReferencePrice != 0.0 &&
                     signal.BullishStopLossPrice != (double)EMPTY_VALUE &&
                     signal.BullishStopLossPrice != 0.0);
    bool has_bear = (signal.BearishReferencePrice != (double)EMPTY_VALUE &&
                     signal.BearishReferencePrice != 0.0 &&
                     signal.BearishStopLossPrice != (double)EMPTY_VALUE &&
                     signal.BearishStopLossPrice != 0.0);

    if (!has_bull && !has_bear)
    {
        g_History_Status_Message = "该历史K线没有有效信号";
        B8_UpdateHistoricalFibPanel();
        return false;
    }

    if (g_Trade_Mode == B8_MODE_NORMAL && has_bull && has_bear)
    {
        Print("[Bot8][历史补挂] 历史K线同时存在多空信号，本次不执行。",
              " 时间:", TimeToString(signal.OpenTime));
        g_History_Status_Message = "历史K线多空同时出现，未执行";
        B8_UpdateHistoricalFibPanel();
        return false;
    }

    double levels[8] = {0.120, 0.214, 0.236, 0.382, 0.500, 0.618, 0.786, 0.880};
    int types[2] = {OP_BUY, OP_SELL};
    bool created_any = false;

    for (int direction_index = 0; direction_index < 2; direction_index++)
    {
        int type = types[direction_index];
        if (type == OP_BUY && (!has_bull || g_Trade_Mode == B8_MODE_SELL_ONLY))
        {
            Print("[Bot8][历史补挂] 跳过BUY方向：",
                  (!has_bull ? "历史K线没有BUY信号" : "当前为只空模式"));
            continue;
        }
        if (type == OP_SELL && (!has_bear || g_Trade_Mode == B8_MODE_BUY_ONLY))
        {
            Print("[Bot8][历史补挂] 跳过SELL方向：",
                  (!has_bear ? "历史K线没有SELL信号" : "当前为只多模式"));
            continue;
        }

        double fib0 = (type == OP_BUY) ? signal.BullishStopLossPrice
                                       : signal.BearishStopLossPrice;
        string group_key = B8_PendingGroupKey(signal, type);
        // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 开始插入-------------------

        int effective_count = 0;

        // 风险分配开启时，历史补挂也只按最终有效Fib参与权重计算。
        if (Enable_Fib_Risk_Allocation)
        {
            for (int precheck_index = 0; precheck_index < 8; precheck_index++)
            {
                double precheck_level = levels[precheck_index];
                if (!B8_IsPendingFibSelected(precheck_level)) continue;

                double precheck_entry = NormalizeDouble(fib0 + precheck_level * (fib1 - fib0), _Digits);
                RefreshRates();
                bool precheck_price_valid = (type == OP_BUY) ? (precheck_entry < Ask)
                                                            : (precheck_entry > Bid);
                if (!precheck_price_valid) continue;

                string precheck_code = IntegerToString((int)MathRound(precheck_level * 1000.0));
                string precheck_tag = group_key + B8_HISTORY_PLAN_MARKER
                                      + "|F" + precheck_code + "|" + B8_TimeframeToText(_Period);
                if (B8_IsFibRiskEligible(signal, type, precheck_entry, precheck_tag))
                    effective_count++;
            }

            Print("[Bot8][历史补挂][Fib风险分配] 有效Fib数量:", effective_count,
                  " / 已选:", B8_CountSelectedPendingFib(),
                  " 总风险值:", DoubleToString(g_Runtime_Settings.risk_value, 2));
        }

        int effective_order_index = 0;
        // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 结束插入-------------------

        for (int i = 0; i < 8; i++)
        {
            double fib_level = levels[i];
            if (!B8_IsPendingFibSelected(fib_level)) continue;

            double entry_price = NormalizeDouble(fib0 + fib_level * (fib1 - fib0), _Digits);
            RefreshRates();
            bool price_valid = (type == OP_BUY) ? (entry_price < Ask) : (entry_price > Bid);
            if (!price_valid)
            {
                Print("[Bot8][历史补挂] Fib不满足当前Limit方向，跳过。",
                      " K[", shift, "] Fib:", DoubleToString(fib_level, 3),
                      " 入场:", DoubleToString(entry_price, _Digits));
                continue;
            }

            string fib_code = IntegerToString((int)MathRound(fib_level * 1000.0));
            string plan_tag = group_key + B8_HISTORY_PLAN_MARKER
                              + "|F" + fib_code + "|" + B8_TimeframeToText(_Period);
            // ------------------- 手术切入口：开始新增斐波挂单仓位权重计算功能 V1 原始版本 开始注销了-------------------
            /*
            bool duplicate = false;
            for (int j = 0; j < OrdersTotal(); j++)
            {
                if (!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
                if (!B8_IsManagedOrder()) continue;
                if (StringFind(OrderComment(), plan_tag, 0) >= 0)
                {
                    duplicate = true;
                    break;
                }
            }
            if (duplicate)
            {
                Print("[Bot8][历史补挂] 已存在相同计划，跳过。计划:", plan_tag);
                continue;
            }

            B8_ExecutePendingTrade(signal, type, entry_price, plan_tag);
            */
            // ------------------- 手术切入口：开始新增斐波挂单仓位权重计算功能 V1 原始版本 结束注销了-------------------

           // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 开始插入-------------------
            double allocated_risk_value = -1.0;
            if (Enable_Fib_Risk_Allocation)
            {
                if (!B8_IsFibRiskEligible(signal, type, entry_price, plan_tag))
                    continue;
                allocated_risk_value = B8_GetFibAllocatedRisk(effective_order_index,
                                                              effective_count);
                effective_order_index++;
            }
            else if (B8_IsPendingPlanDuplicate(plan_tag))
            {
                Print("[Bot8][历史补挂] 已存在相同计划，跳过。计划:", plan_tag);
                continue;
            }

            B8_ExecutePendingTrade(signal, type, entry_price, plan_tag,
                                   allocated_risk_value);
            // ------------------- 手数切入口：新增斐波挂单位置权重仓位分配功能 V2 结束插入-------------------
            created_any = true;
        }
    }

    g_History_Status_Message = created_any ? "历史补挂计划已提交" : "没有创建有效历史挂单";
    B8_UpdateHistoricalFibPanel();
    return created_any;
}
//#endregion

//====================================================================
// 完成主业务逻辑所调用的函数
//====================================================================

//#region MARK: 模块--核心业务：账户浮盈保护 绘图功能
//====================================================================
// 辅助函数: B8_GetManagedFloatingProfit
// 统计本EA管理范围内（同品种+同家族Magic）的总浮动盈亏
//====================================================================
double B8_GetManagedFloatingProfit()
{
    double total = 0.0;
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsManagedOrder()) continue;
        if (OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

        total += (OrderProfit() + OrderSwap() + OrderCommission());
    }
    return total;
}

//====================================================================
// 辅助函数: B8_GetManagedClosedProfit
// 统计本EA管理范围内（同品种+同家族Magic）的历史已实现净利润
//====================================================================
double B8_GetManagedClosedProfit()
{
    double total = 0.0;
    for (int i = 0; i < OrdersHistoryTotal(); i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
        if (!B8_IsManagedOrder()) continue;
        if (OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

        total += (OrderProfit() + OrderSwap() + OrderCommission());
    }
    return total;
}

//====================================================================
// 辅助函数: B8_GetEffectiveEquityBase
// 根据配置计算浮盈保护的有效基准资金
//====================================================================
double B8_GetEffectiveEquityBase()
{
    double base = Equity_Base_Amount;

    if (!Enable_Dynamic_Equity_Base)
        return base;

    double closed_profit = B8_GetManagedClosedProfit();

    // 仅上调模式下，忽略负向已实现盈亏
    if (Dynamic_Base_Direction == B8_BASE_UP_ONLY && closed_profit < 0.0)
        closed_profit = 0.0;

    base += closed_profit;

    if (Dynamic_Base_Min_Amount > 0.0 && base < Dynamic_Base_Min_Amount)
        base = Dynamic_Base_Min_Amount;

    return base;
}

//====================================================================
// 辅助函数: B8_GetManagedProfitSlopePerPrice
// 计算本EA管理仓位的“价格每变动1.0，对应浮盈变化金额($)”
//====================================================================
double B8_GetManagedProfitSlopePerPrice()
{
    double tick_size = MarketInfo(_Symbol, MODE_TICKSIZE);
    double tick_value = MarketInfo(_Symbol, MODE_TICKVALUE);
    if (tick_size <= 0.0 || tick_value <= 0.0) return 0.0;

    double value_per_price_per_lot = tick_value / tick_size;
    double slope = 0.0;

    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsManagedOrder()) continue;

        int type = OrderType();
        if (type != OP_BUY && type != OP_SELL) continue;

        double dir = (type == OP_BUY) ? 1.0 : -1.0;
        slope += dir * OrderLots() * value_per_price_per_lot;
    }

    return slope;
}

//====================================================================
// 辅助函数: B8_TryCalcEquityTargetPrice
// 反解下一次浮盈保护触发所需的目标价格（以Bid为参考）
//====================================================================
bool B8_TryCalcEquityTargetPrice(double &target_price,
                                 double &current_profit,
                                 double &target_profit,
                                 double &profit_gap,
                                 double &slope_per_price)
{
    target_price = 0.0;
    current_profit = 0.0;
    target_profit = 0.0;
    profit_gap = 0.0;
    slope_per_price = 0.0;

    if (!g_Runtime_Settings.equity_protect_enabled) return false;
    if (B8_CountOpenPositions() <= 0) return false;

    double effective_base = B8_GetEffectiveEquityBase();
    target_profit = effective_base * (g_Runtime_Settings.equity_target_percent / 100.0);
    if (target_profit <= 0.0) return false;

    current_profit = B8_GetManagedFloatingProfit();
    profit_gap = target_profit - current_profit;

    // 阈值已达到：目标价即当前Bid
    if (profit_gap <= 0.0)
    {
        target_price = NormalizeDouble(Bid, _Digits);
        return true;
    }

    slope_per_price = B8_GetManagedProfitSlopePerPrice();
    if (MathAbs(slope_per_price) < 1e-10) return false;

    double delta_price = profit_gap / slope_per_price;
    target_price = NormalizeDouble(Bid + delta_price, _Digits);
    return true;
}

//====================================================================
// 可视化函数: B8_ClearEquityTargetVisual
//====================================================================
void B8_ClearEquityTargetVisual()
{
    if (ObjectFind(0, B8_EQ_TARGET_LINE) >= 0)
        ObjectDelete(0, B8_EQ_TARGET_LINE);

    if (ObjectFind(0, B8_EQ_TARGET_LABEL) >= 0)
        ObjectDelete(0, B8_EQ_TARGET_LABEL);

    if (ObjectFind(0, B8_EQ_TARGET_STATUS) >= 0)
        ObjectDelete(0, B8_EQ_TARGET_STATUS);
}

//====================================================================
// 账户目标线拖动：按拖动后的价格反算账户触发百分比并立即应用
// 目标浮盈 = 当前浮盈 + (拖动价格 - Bid) * 管理仓位浮盈斜率
// 触发百分比 = 目标浮盈 / 有效资金基准 * 100
//====================================================================
bool B8_ApplyDraggedEquityTargetPrice(double dragged_price)
{
    if (!g_Runtime_Settings.equity_protect_enabled)
        return false;

    if (dragged_price <= 0.0 || Bid <= 0.0)
    {
        Print("[Bot8][账户目标线] 拖动价格无效，未更新账户触发百分比。",
              " 拖动价格:", DoubleToString(dragged_price, _Digits));
        B8_UpdateEquityTargetVisual();
        return false;
    }

    if (B8_CountOpenPositions() <= 0)
    {
        Print("[Bot8][账户目标线] 当前没有本EA管理的持仓，无法反算账户触发百分比。");
        B8_UpdateEquityTargetVisual();
        return false;
    }

    double effective_base = B8_GetEffectiveEquityBase();
    double current_profit = B8_GetManagedFloatingProfit();
    double slope_per_price = B8_GetManagedProfitSlopePerPrice();

    if (effective_base <= 0.0 || MathAbs(slope_per_price) < 1e-10)
    {
        Print("[Bot8][账户目标线] 当前仓位无法稳定反算账户触发百分比。",
              " 基准:", DoubleToString(effective_base, 2),
              " 浮盈斜率:", DoubleToString(slope_per_price, 6));
        B8_UpdateEquityTargetVisual();
        return false;
    }

    double target_profit = current_profit +
                           (dragged_price - Bid) * slope_per_price;
    double target_percent = target_profit / effective_base * 100.0;
    target_percent = NormalizeDouble(target_percent, 2);

    // 原规则曾限制账户触发百分比不得超过100%；策略基准资金允许独立设置，
    // 因此账户目标百分比可以超过100%，这里只拒绝无效的非正数结果。
    // if (target_percent <= 0.0 || target_percent > 100.0)
    if (target_percent <= 0.0)
    {
        Print("[Bot8][账户目标线] 拖动结果无效，未更新账户触发百分比。",
              " 反算百分比:", DoubleToString(target_percent, 2), "%",
              " 目标浮盈:", DoubleToString(target_profit, 2));
        B8_UpdateEquityTargetVisual();
        return false;
    }

    // 拖动目标线直接修改运行参数，同时同步编辑态，避免还需点击“应用参数”。
    g_Runtime_Settings.equity_target_percent = target_percent;
    g_Edit_Settings.equity_target_percent = target_percent;
    g_Settings_Dirty = false;
    g_Settings_Message = "目标线已更新触发: " +
                         DoubleToString(target_percent, 2) + "%";

    B8_SaveRuntimeSettings();
    if (ObjectFind(0, B8_EDIT_TARGET_PCT) >= 0)
        ObjectSetString(0, B8_EDIT_TARGET_PCT, OBJPROP_TEXT,
                        DoubleToString(target_percent, 2));

    Print("[Bot8][账户目标线] 已应用拖动结果。",
          " 目标价:", DoubleToString(dragged_price, _Digits),
          " 目标浮盈:", DoubleToString(target_profit, 2),
          " 账户触发:", DoubleToString(target_percent, 2), "%");

    B8_UpdateSettingsPanel();
    B8_UpdateEquityTargetVisual();
    ChartRedraw();
    return true;
}
//#endregion

//#region MARK: 模块--核心业务：订单级别/减仓/保本
//====================================================================
// 订单级保护：从当前订单价格结构读取初始风险距离
//====================================================================
int B8_FindOrderProtectionState(int logical_magic)
{
    for (int i = 0; i < g_Order_Protection_State_Count; i++)
    {
        if (g_Order_Protection_States[i].logical_magic == logical_magic)
            return i;
    }
    return -1;
}

int B8_GetOrCreateOrderProtectionState(int logical_magic,
                                       double open_price,
                                       double current_sl)
{
    int index = B8_FindOrderProtectionState(logical_magic);
    if (index >= 0) return index;
    if (g_Order_Protection_State_Count >= B8_ORDER_PROTECTION_STATE_MAX)
        return -1;

    index = g_Order_Protection_State_Count++;
    g_Order_Protection_States[index].logical_magic = logical_magic;
    g_Order_Protection_States[index].initial_open_price = open_price;
    g_Order_Protection_States[index].initial_sl = current_sl;
    g_Order_Protection_States[index].initial_risk_price = 0.0;
    g_Order_Protection_States[index].initial_risk_valid = false;
    if (current_sl > 0.0)
    {
        double risk_price = MathAbs(open_price - current_sl);
        if (risk_price > Point())
        {
            g_Order_Protection_States[index].initial_risk_price = risk_price;
            g_Order_Protection_States[index].initial_risk_valid = true;
        }
    }
    g_Order_Protection_States[index].breakeven_done = false;
    g_Order_Protection_States[index].partial_close_done = false;
    g_Order_Protection_States[index].partial_closed_lots = 0.0;
    g_Order_Protection_States[index].partial_close_count = 0;
    return index;
}

void B8_CleanupOrderProtectionStates()
{
    for (int state_index = g_Order_Protection_State_Count - 1; state_index >= 0; state_index--)
    {
        bool found = false;
        for (int order_index = 0; order_index < OrdersTotal(); order_index++)
        {
            if (!OrderSelect(order_index, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderSymbol() != _Symbol) continue;
            if (OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
            if (OrderMagicNumber() == g_Order_Protection_States[state_index].logical_magic)
            {
                found = true;
                break;
            }
        }
        if (found) continue;

        int last_index = g_Order_Protection_State_Count - 1;
        if (state_index != last_index)
            g_Order_Protection_States[state_index] = g_Order_Protection_States[last_index];
        g_Order_Protection_State_Count--;
    }
}

// bool B8_GetOrderInitialRisk(double open_price, double current_sl, double &risk_price)
// {
//     risk_price = 0.0;
//     if (current_sl <= 0.0) return false;

//     risk_price = MathAbs(open_price - current_sl);
//     if (risk_price <= Point()) return false;
//     return true;
// }

//====================================================================
// 订单级保护：由当前止损位置判断保本是否已经完成
//====================================================================
bool B8_IsOrderBreakevenDone(int type, double open_price, double current_sl)
{
    if (current_sl <= 0.0) return false;

    double buffer_price = g_Order_Runtime_Settings.order_be_buffer_points * Point();
    double be_sl = (type == OP_BUY) ? open_price + buffer_price
                                    : open_price - buffer_price;
    be_sl = NormalizeDouble(be_sl, _Digits);

    return ((type == OP_BUY && current_sl >= be_sl) ||
            (type == OP_SELL && current_sl <= be_sl));
}

//====================================================================
// 订单级保护：同一订单Magic出现历史平仓记录，即视为已发生过部分平仓
//====================================================================
bool B8_HasOrderPartialCloseHistory(int order_magic, int type)
{
    for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
        if (OrderMagicNumber() != order_magic) continue;
        if (!B8_IsManagedOrder()) continue;
        if (OrderType() != type) continue;
        if (OrderLots() <= 0.0) continue;
        return true;
    }

    return false;
}

// 判断订单是否已经因手数规则被标记为不可部分平仓。
bool B8_IsPartialCloseBlocked(int logical_magic)
{
    for (int i = 0; i < g_Partial_Close_Blocked_Count; i++)
    {
        if (g_Partial_Close_Blocked_Magics[i] == logical_magic)
            return true;
    }

    return false;
}

// 记录永久性的手数规则限制，避免后续每个Tick重复尝试和打印。
void B8_MarkPartialCloseBlocked(int logical_magic)
{
    if (B8_IsPartialCloseBlocked(logical_magic)) return;
    if (g_Partial_Close_Blocked_Count >= 128) return;

    g_Partial_Close_Blocked_Magics[g_Partial_Close_Blocked_Count] = logical_magic;
    g_Partial_Close_Blocked_Count++;
}

//====================================================================
// 订单级保护：移动到订单自身的保本价
//====================================================================
bool B8_MoveOrderToBreakeven(int ticket, int type, double open_price)
{
    if (!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return false;

    double buffer_price = g_Order_Runtime_Settings.order_be_buffer_points * Point();
    double be_sl = (type == OP_BUY) ? open_price + buffer_price
                                    : open_price - buffer_price;
    be_sl = NormalizeDouble(be_sl, _Digits);

    double old_sl = OrderStopLoss();
    if ((type == OP_BUY && old_sl > 0.0 && old_sl >= be_sl) ||
        (type == OP_SELL && old_sl > 0.0 && old_sl <= be_sl))
        return true;

    RefreshRates();
    int stop_level_points = (int)MarketInfo(_Symbol, MODE_STOPLEVEL);
    double min_distance = stop_level_points * Point();
    if ((type == OP_BUY && be_sl > Bid - min_distance) ||
        (type == OP_SELL && be_sl < Ask + min_distance))
    {
        Print("[Bot8][订单保本] 当前价格距离不足，稍后重试。 Ticket:", ticket,
              " 目标SL:", DoubleToString(be_sl, _Digits),
              " StopLevel:", stop_level_points);
        return false;
    }

    ResetLastError();
    if (!OrderModify(ticket, OrderOpenPrice(), be_sl, OrderTakeProfit(), 0, clrNONE))
    {
        Print("[Bot8][订单保本] 移动失败。 Ticket:", ticket,
              " 错误码:", GetLastError());
        return false;
    }

    Print("[Bot8][订单保本] 已移动。 Ticket:", ticket,
          " 新SL:", DoubleToString(be_sl, _Digits));
    return true;
}

//====================================================================
// 订单级保护：按交易商手数规则执行一次部分平仓
//====================================================================
bool B8_CloseOrderPartially(int ticket, int logical_magic, int type, double close_percent)
{
    if (!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return false;

    double lots = OrderLots();
    double min_lot = MarketInfo(_Symbol, MODE_MINLOT);
    double lot_step = MarketInfo(_Symbol, MODE_LOTSTEP);
    if (min_lot <= 0.0) min_lot = 0.01;
    if (lot_step <= 0.0) lot_step = min_lot;

    double close_lots = MathFloor((lots * close_percent / 100.0 + lot_step * 0.0001) /
                                  lot_step) * lot_step;
    close_lots = NormalizeDouble(close_lots, 2);
    double remain_lots = NormalizeDouble(lots - close_lots, 2);

    if (close_lots < min_lot || remain_lots < min_lot || close_lots >= lots)
    {
        Print("[Bot8][订单减仓] 手数约束导致跳过。 Ticket:", ticket,
              " 当前:", DoubleToString(lots, 2),
              " 计划:", DoubleToString(close_lots, 2),
              " 剩余:", DoubleToString(remain_lots, 2));
        B8_MarkPartialCloseBlocked(logical_magic);
        return false;
    }

    RefreshRates();
    double close_price = (type == OP_BUY) ? Bid : Ask;
    ResetLastError();
    if (!OrderClose(ticket, close_lots, close_price, Slippage, clrOrange))
    {
        Print("[Bot8][订单减仓] 执行失败。 Ticket:", ticket,
              " 错误码:", GetLastError());
        return false;
    }

    // 接入说明：只有确认OrderClose成功后，才锁定本次接管周期的减仓状态。
    // 失败不会写入状态，下一次OnTick仍允许按原规则重试。
    if (B8_IsRuntimeTakeoverActive(logical_magic))
        B8_MarkRuntimeTakeoverPartialCloseDone(logical_magic);

    Print("[Bot8][订单减仓] 执行成功。 Ticket:", ticket,
          " 减仓:", DoubleToString(close_lots, 2),
          " 比例:", DoubleToString(close_percent, 1), "%");
    return true;
}

//====================================================================
// 订单级保护：全部平仓
// 达到订单保护触发条件后直接关闭全部手数，不复用部分平仓逻辑。
//====================================================================
bool B8_CloseOrderFully(int ticket, int type)
{
    if (!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return false;

    double close_lots = OrderLots();
    if (close_lots <= 0.0) return false;

    RefreshRates();
    double close_price = (type == OP_BUY) ? Bid : Ask;
    ResetLastError();
    if (!OrderClose(ticket, close_lots, close_price, Slippage, clrOrangeRed))
    {
        Print("[Bot8][订单全平] 执行失败。 Ticket:", ticket,
              " 错误码:", GetLastError());
        return false;
    }

    Print("[Bot8][订单全平] 执行成功。 Ticket:", ticket,
          " 手数:", DoubleToString(close_lots, 2));
    return true;
}
//#endregion

//#region MARK: 模块--新增实现：全部接管运行期状态
int B8_FindRuntimeTakeoverState(int logical_magic)
{
    for (int i = 0; i < g_Runtime_Takeover_State_Count; i++)
    {
        if (g_Runtime_Takeover_States[i].logical_magic == logical_magic)
            return i;
    }
    return -1;
}

bool B8_IsRuntimeTakeoverActive(int logical_magic)
{
    return B8_FindRuntimeTakeoverState(logical_magic) >= 0;
}

bool B8_IsRuntimeTakeoverPartialCloseDone(int logical_magic)
{
    int index = B8_FindRuntimeTakeoverState(logical_magic);
    return index >= 0 && g_Runtime_Takeover_States[index].partial_close_done;
}

void B8_MarkRuntimeTakeoverPartialCloseDone(int logical_magic)
{
    int index = B8_FindRuntimeTakeoverState(logical_magic);
    if (index < 0) return;
    g_Runtime_Takeover_States[index].partial_close_done = true;
}

// 接管后允许再次评估手数规则，避免旧的“不可减仓”结果阻断本次接管。
void B8_ClearPartialCloseBlocked(int logical_magic)
{
    for (int i = 0; i < g_Partial_Close_Blocked_Count; i++)
    {
        if (g_Partial_Close_Blocked_Magics[i] != logical_magic) continue;
        for (int j = i; j < g_Partial_Close_Blocked_Count - 1; j++)
            g_Partial_Close_Blocked_Magics[j] = g_Partial_Close_Blocked_Magics[j + 1];
        g_Partial_Close_Blocked_Count--;
        return;
    }
}

int B8_ResetAllManagedOrdersToOrderLevel()
{
    int reset_count = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsManagedOrder()) continue;
        if (OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

        int logical_magic = OrderMagicNumber();
        int takeover_index = B8_FindRuntimeTakeoverState(logical_magic);
        if (takeover_index < 0)
        {
            if (g_Runtime_Takeover_State_Count >= B8_RUNTIME_TAKEOVER_STATE_MAX)
                continue;
            takeover_index = g_Runtime_Takeover_State_Count++;
            g_Runtime_Takeover_States[takeover_index].logical_magic = logical_magic;
        }
        g_Runtime_Takeover_States[takeover_index].takeover_lots = OrderLots();
        g_Runtime_Takeover_States[takeover_index].partial_close_done = false;

        // 接入说明：全部接管只清除运行时覆盖，订单级默认策略仍由原流程继续执行。
        B8_ClearRuntimeOrderOverride(logical_magic);
        B8_ClearPartialCloseBlocked(logical_magic);

        int protection_index = B8_FindOrderProtectionState(logical_magic);
        if (protection_index >= 0)
        {
            g_Order_Protection_States[protection_index].initial_open_price = OrderOpenPrice();
            g_Order_Protection_States[protection_index].initial_sl = OrderStopLoss();
            g_Order_Protection_States[protection_index].initial_risk_price =
                MathAbs(OrderOpenPrice() - OrderStopLoss());
            g_Order_Protection_States[protection_index].initial_risk_valid =
                g_Order_Protection_States[protection_index].initial_risk_price > Point();
            g_Order_Protection_States[protection_index].breakeven_done = false;
            g_Order_Protection_States[protection_index].partial_close_done = false;
            g_Order_Protection_States[protection_index].partial_closed_lots = 0.0;
            g_Order_Protection_States[protection_index].partial_close_count = 0;
        }

        Print("[Bot8][全部接管] 已恢复订单级管理。 Ticket:", OrderTicket(),
              " Magic:", logical_magic,
              " 当前手数:", DoubleToString(OrderLots(), 2));
        reset_count++;
    }
    return reset_count;
}

void B8_CleanupRuntimeTakeoverStates()
{
    for (int state_index = g_Runtime_Takeover_State_Count - 1;
         state_index >= 0; state_index--)
    {
        bool found = false;
        for (int order_index = 0; order_index < OrdersTotal(); order_index++)
        {
            if (!OrderSelect(order_index, SELECT_BY_POS, MODE_TRADES)) continue;
            if (!B8_IsManagedOrder()) continue;
            if (OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
            if (OrderMagicNumber() ==
                g_Runtime_Takeover_States[state_index].logical_magic)
            {
                found = true;
                break;
            }
        }
        if (found) continue;

        int last_index = g_Runtime_Takeover_State_Count - 1;
        if (state_index != last_index)
            g_Runtime_Takeover_States[state_index] =
                g_Runtime_Takeover_States[last_index];
        g_Runtime_Takeover_State_Count--;
    }
}
//#endregion

//#region MARK: 模块--新增实现：运行时订单一键保本
// 返回值：1=已移动，0=原止损已处于保本或更优，-1=执行失败。
int B8_ManualMoveRuntimeOrderToBreakeven(int ticket, int be_buffer_points)
{
    if (!B8_SelectRuntimeOrderByTicket(ticket)) return -1;

    int type = OrderType();
    double open_price = OrderOpenPrice();
    double buffer_price = be_buffer_points * Point();
    double be_sl = type == OP_BUY ? open_price + buffer_price
                                  : open_price - buffer_price;
    be_sl = NormalizeDouble(be_sl, _Digits);

    double old_sl = OrderStopLoss();
    if ((type == OP_BUY && old_sl > 0.0 && old_sl >= be_sl) ||
        (type == OP_SELL && old_sl > 0.0 && old_sl <= be_sl))
        return 0;

    RefreshRates();
    int stop_level_points = (int)MarketInfo(_Symbol, MODE_STOPLEVEL);
    double min_distance = stop_level_points * Point();
    if ((type == OP_BUY && be_sl > Bid - min_distance) ||
        (type == OP_SELL && be_sl < Ask + min_distance))
    {
        Print("[Bot8][一键保本] 当前价格距离不足。 Ticket:", ticket,
              " 目标SL:", DoubleToString(be_sl, _Digits),
              " BE点:", be_buffer_points,
              " StopLevel:", stop_level_points);
        return -1;
    }

    ResetLastError();
    if (!OrderModify(ticket, OrderOpenPrice(), be_sl, OrderTakeProfit(), 0, clrNONE))
    {
        Print("[Bot8][一键保本] 修改失败。 Ticket:", ticket,
              " 目标SL:", DoubleToString(be_sl, _Digits),
              " 错误码:", GetLastError());
        return -1;
    }

    Print("[Bot8][一键保本] 修改成功。 Ticket:", ticket,
          " 新SL:", DoubleToString(be_sl, _Digits),
          " BE点:", be_buffer_points);
    return 1;
}

bool B8_ExecuteRuntimeBreakevenAllManaged(int &moved_count,
                                          int &already_count,
                                          int &failed_count)
{
    moved_count = 0;
    already_count = 0;
    failed_count = 0;

    double be_value = StringToDouble(
        ObjectGetString(0, B8_RUNTIME_ORDER_EDIT_BE, OBJPROP_TEXT));
    if (be_value < 0.0) return false;
    int be_buffer_points = (int)MathRound(be_value);

    int tickets[];
    int ticket_count = 0;
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsManagedOrder()) continue;
        if (OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
        ArrayResize(tickets, ticket_count + 1);
        tickets[ticket_count++] = OrderTicket();
    }

    if (ticket_count <= 0) return false;

    for (int j = 0; j < ticket_count; j++)
    {
        int result = B8_ManualMoveRuntimeOrderToBreakeven(
            tickets[j], be_buffer_points);
        if (result > 0)
            moved_count++;
        else if (result == 0)
            already_count++;
        else
            failed_count++;
    }

    return moved_count > 0 || already_count > 0;
}
//#endregion

//#region MARK: 模块--斐波挂单辅助函数
//====================================================================
// V1 挂单模块：信号区间 Fib 位置
//====================================================================
// 判断订单类型是否属于挂单类型。
bool B8_IsPendingOrderType(int order_type)
{
    return (order_type == OP_BUYLIMIT || order_type == OP_SELLLIMIT ||
            order_type == OP_BUYSTOP || order_type == OP_SELLSTOP);
}

// 根据当前信号时间和交易方向生成挂单组唯一标识。
string B8_PendingGroupKey(const KBarSignal &signal, int type)
{
    return "|P" + (type == OP_BUY ? "B" : "S") + IntegerToString((int)signal.OpenTime);
}

// 判断指定的 Fib 回撤位置是否已在输入参数中启用。
bool B8_IsPendingFibSelected(double fib_level)
{
    if (MathAbs(fib_level - 0.120) < 0.0001) return g_Pending_Fib_Selected[0];
    if (MathAbs(fib_level - 0.214) < 0.0001) return g_Pending_Fib_Selected[1];
    if (MathAbs(fib_level - 0.236) < 0.0001) return g_Pending_Fib_Selected[2];
    if (MathAbs(fib_level - 0.382) < 0.0001) return g_Pending_Fib_Selected[3];
    if (MathAbs(fib_level - 0.500) < 0.0001) return g_Pending_Fib_Selected[4];
    if (MathAbs(fib_level - 0.618) < 0.0001) return g_Pending_Fib_Selected[5];
    if (MathAbs(fib_level - 0.786) < 0.0001) return g_Pending_Fib_Selected[6];
    if (MathAbs(fib_level - 0.880) < 0.0001) return g_Pending_Fib_Selected[7];
    return false;
}
//#endregion

//#region MARK: 模块--核心业务：斐波挂单权重仓位分配业务
//====================================================================
// 手数切入口：新增斐波挂单位置权重仓位分配功能V2 代码开始
//====================================================================
// 检查指定Fib计划是否已经存在于当前挂单列表中。
bool B8_IsPendingPlanDuplicate(string plan_tag)
{
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsManagedOrder()) continue;
        if (StringFind(OrderComment(), plan_tag, 0) >= 0)
            return true;
    }
    return false;
}

// 从挂单计划标签中提取Fib位置编号，例如从“|F880|”提取“880”。
string B8_PendingPlanPositionText(string plan_tag)
{
    int marker_start = StringFind(plan_tag, "|F", 0);
    if (marker_start < 0) return "--";

    int value_start = marker_start + 2;
    int value_end = StringFind(plan_tag, "|", value_start);
    if (value_end < 0) return StringSubstr(plan_tag, value_start);

    string position_text = StringSubstr(plan_tag, value_start,
                                        value_end - value_start);
    return (StringLen(position_text) > 0) ? position_text : "--";
}

// 使用挂单执行路径现有的止损过滤规则，判断计划是否可参与风险分配。
bool B8_IsFibRiskEligible(const KBarSignal &signal, int type,
                          double entry_price, string plan_tag)
{
    if (B8_IsPendingPlanDuplicate(plan_tag)) return false;

    double sl_price = (type == OP_BUY)
                      ? signal.BullishStopLossPrice
                      : signal.BearishStopLossPrice;
    double sl_price_diff = (type == OP_BUY)
                           ? (entry_price - sl_price)
                           : (sl_price - entry_price);
    if (sl_price <= 0.0 || sl_price_diff <= 0.0) return false;

    double sl_points = sl_price_diff / Point();
    if (Enable_SL_Min_Filter &&
        sl_points < MathMax(1, SL_Min_Allowed_Points))
        return false;

    if (Enable_SL_Tier_Routing)
    {
        int threshold_1 = MathMax(1, SL_Tier_Threshold_1_Points);
        int threshold_2 = MathMax(threshold_1, SL_Tier_Threshold_2_Points);
        int max_sl = MathMax(threshold_2, SL_Max_Allowed_Points);
        if (sl_points > max_sl) return false;
    }

    return true;
}

// 风险分配预筛选：仅在最终会采用风险模式时检查最小手数可行性。
bool B8_CanFormPendingRiskLot(const KBarSignal &signal, int type,
                              double entry_price, double risk_value)
{
    double sl_price = (type == OP_BUY)
                      ? signal.BullishStopLossPrice
                      : signal.BearishStopLossPrice;
    double sl_points = MathAbs(entry_price - sl_price) / Point();
    bool uses_risk_mode = (g_Runtime_Settings.position_mode == POS_RISK_BASED);

    if (Enable_SL_Tier_Routing)
    {
        int threshold_1 = MathMax(1, SL_Tier_Threshold_1_Points);
        if (sl_points >= threshold_1)
            uses_risk_mode = true;
    }

    if (!uses_risk_mode)
        return true;

    return CanFormPositionSize_V1(entry_price, sl_price,
                                  g_Runtime_Settings.risk_mode, risk_value);
}

// 返回风险淘汰检查顺序中的Fib数组索引：120靠近止损，880靠近当前价格。
int B8_GetFibRiskCheckIndex(int check_order)
{
    if (check_order < 0 || check_order >= 8)
        return -1;

    return (Fib_Elimination_Policy == B8_KEEP_DEEP_FIB)
           ? (7 - check_order)
           : check_order;
}

// 反向金字塔：越靠近止损的Fib排序越靠前，风险权重越大。
double B8_GetFibAllocatedRisk(int fib_order_index, int effective_count)
{
    if (!Enable_Fib_Risk_Allocation || effective_count <= 0)
        return g_Runtime_Settings.risk_value;

    if (fib_order_index < 0 || fib_order_index >= effective_count)
        return g_Runtime_Settings.risk_value;

    double total_weight = effective_count * (effective_count + 1) / 2.0;
    double weight = effective_count - fib_order_index;
    return g_Runtime_Settings.risk_value * weight / total_weight;
}
//====================================================================
// 手数切入口：新增斐波挂单位置权重仓位分配功能V2 代码结束
//====================================================================
//#endregion

//#region MARK: 模块--核心业务：斐波实时挂单和历史挂单
// 删除指定历史K线创建的、尚未成交的Fib挂单。
// 通过历史标记区分历史补挂与同组实时挂单，不依赖当前交易模式。
bool B8_DeleteHistoricalPendingPlans(int shift)
{
    int bars_count = iBars(_Symbol, _Period);
    if (bars_count <= 1 || shift < 1 || shift >= bars_count)
    {
        g_History_Status_Message = "历史K线范围无效，无法删除挂单";
        B8_UpdateHistoricalFibPanel();
        return false;
    }

    datetime signal_time = iTime(_Symbol, _Period, shift);
    if (signal_time <= 0)
    {
        g_History_Status_Message = "无法读取历史K线时间，未删除挂单";
        B8_UpdateHistoricalFibPanel();
        return false;
    }

    string buy_group_key = "|PB" + IntegerToString((int)signal_time);
    string sell_group_key = "|PS" + IntegerToString((int)signal_time);
    int deleted_count = 0;
    int failed_count = 0;

    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsManagedOrder()) continue;
        if (!B8_IsPendingOrderType(OrderType())) continue;

        string comment = OrderComment();
        bool same_history_group = (StringFind(comment, buy_group_key, 0) >= 0 ||
                                   StringFind(comment, sell_group_key, 0) >= 0);
        if (!same_history_group) continue;
        if (StringFind(comment, B8_HISTORY_PLAN_MARKER, 0) < 0) continue;

        int ticket = OrderTicket();
        ResetLastError();
        if (!OrderDelete(ticket, clrNONE))
        {
            failed_count++;
            Print("[Bot8][历史补挂] 删除挂单失败。 Ticket:", ticket,
                  " 错误码:", GetLastError());
        }
        else
        {
            deleted_count++;
            Print("[Bot8][历史补挂] 已删除历史挂单。 Ticket:", ticket,
                  " K[", shift, "]");
        }
    }

    if (deleted_count <= 0 && failed_count <= 0)
        g_History_Status_Message = "未找到该历史K线的历史挂单";
    else if (failed_count > 0)
        g_History_Status_Message = "历史挂单部分删除，请检查日志";
    else
        g_History_Status_Message = "已删除 K[" + IntegerToString(shift) + "] 的历史挂单";

    B8_UpdateHistoricalFibPanel();
    return (deleted_count > 0 && failed_count == 0);
}

// 删除指定挂单组中尚未成交的剩余挂单。
void B8_TryCancelPendingGroup(const string group_key)
{
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsManagedOrder()) continue;
        if (!B8_IsPendingOrderType(OrderType())) continue;
        if (StringFind(OrderComment(), group_key, 0) < 0) continue;

        int ticket = OrderTicket();
        ResetLastError();
        if (!OrderDelete(ticket, clrNONE))
            Print("[Bot8][挂单组] 取消剩余挂单失败。 Ticket:", ticket,
                  " 错误码:", GetLastError());
        else
            Print("[Bot8][挂单组] 已取消同组剩余挂单。 Ticket:", ticket);
    }
}

// 监测已成交挂单所属的组，并按组策略处理剩余挂单。
void B8_ManagePendingGroups()
{
    if (Pending_Group_Action != B8_PENDING_CANCEL_REST) return;

    string filled_groups[64];
    int filled_count = 0;
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsManagedOrder()) continue;
        if (OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

        string comment = OrderComment();
        int group_pos = StringFind(comment, "|P", 0);
        if (group_pos < 0) continue;
        int group_end = StringFind(comment, "|F", group_pos);
        if (group_end < 0) group_end = StringLen(comment);
        string group_key = StringSubstr(comment, group_pos, group_end - group_pos);

        bool known = false;
        for (int j = 0; j < filled_count; j++)
        {
            if (filled_groups[j] == group_key)
            {
                known = true;
                break;
            }
        }
        if (!known && filled_count < 64)
            filled_groups[filled_count++] = group_key;
    }

    for (int k = 0; k < filled_count; k++)
        B8_TryCancelPendingGroup(filled_groups[k]);
}

//====================================================================
// 统计当前面板选中的Fib挂单位置数量。
//====================================================================
int B8_CountSelectedPendingFib()
{
    int count = 0;
    for (int i = 0; i < 8; i++)
    {
        if (g_Pending_Fib_Selected[i]) count++;
    }
    return count;
}

//#region MARK: 模块--自定义价格补挂核心逻辑
int B8_GetCustomPendingOrderType(int side, double entry_price)
{
    RefreshRates();

    if (g_Custom_Fib_Order_Type == B8_CUSTOM_PENDING_AUTO)
    {
        if (side == OP_BUY)
            return entry_price < Ask ? OP_BUYLIMIT : OP_BUYSTOP;
        return entry_price > Bid ? OP_SELLLIMIT : OP_SELLSTOP;
    }

    if (side == OP_BUY)
    {
        if (g_Custom_Fib_Order_Type == B8_CUSTOM_PENDING_BUY_LIMIT && entry_price < Ask)
            return OP_BUYLIMIT;
        if (g_Custom_Fib_Order_Type == B8_CUSTOM_PENDING_BUY_STOP && entry_price > Ask)
            return OP_BUYSTOP;
    }
    else
    {
        if (g_Custom_Fib_Order_Type == B8_CUSTOM_PENDING_SELL_LIMIT && entry_price > Bid)
            return OP_SELLLIMIT;
        if (g_Custom_Fib_Order_Type == B8_CUSTOM_PENDING_SELL_STOP && entry_price < Bid)
            return OP_SELLSTOP;
    }

    return OP_NONE;
}

double B8_GetCustomFibAllocatedRisk(int fib_order_index, int effective_count)
{
    if (effective_count <= 0 || fib_order_index < 0 ||
        fib_order_index >= effective_count)
        return g_Runtime_Settings.risk_value;

    double total_weight = effective_count * (effective_count + 1) / 2.0;
    double weight = effective_count - fib_order_index;
    return g_Runtime_Settings.risk_value * weight / total_weight;
}

bool B8_CreateCustomPendingPlans(int shift)
{
    Print("[Bot8][自定义补挂] 开始。Symbol=", _Symbol,
          " Period=", _Period,
          " Shift=", shift,
          " Entry=", DoubleToString(g_Custom_Fib_Entry_Price, _Digits),
          " Stop=", DoubleToString(g_Custom_Fib_Stop_Price, _Digits),
          " EntryMode=", IntegerToString((int)g_Runtime_Entry_Mode),
          " OrderMode=", IntegerToString((int)g_Custom_Fib_Order_Type),
          " RiskShared=", (g_Custom_Fib_Risk_Shared ? "true" : "false"));

    if (g_Runtime_Entry_Mode == B8_ENTRY_MARKET)
    {
        Print("[Bot8][自定义补挂] 终止：当前为市价模式，不创建挂单。");
        g_Custom_Fib_Status_Message = "当前模式不允许创建挂单";
        return false;
    }

    if (g_Custom_Fib_Entry_Price <= 0.0 || g_Custom_Fib_Stop_Price <= 0.0)
    {
        Print("[Bot8][自定义补挂] 终止：入场价或止损价无效。");
        g_Custom_Fib_Status_Message = "请输入有效的入场价和止损价";
        return false;
    }

    if (NormalizeDouble(g_Custom_Fib_Entry_Price, _Digits) ==
        NormalizeDouble(g_Custom_Fib_Stop_Price, _Digits))
    {
        Print("[Bot8][自定义补挂] 终止：入场价等于止损价。");
        g_Custom_Fib_Status_Message = "入场价不能等于止损价";
        return false;
    }

    if (shift < 1 || shift >= iBars(_Symbol, _Period))
    {
        Print("[Bot8][自定义补挂] 终止：历史K线Shift无效。Bars=",
              iBars(_Symbol, _Period));
        g_Custom_Fib_Status_Message = "历史K线范围无效";
        return false;
    }

    KBarSignal custom_signal = B8_ReadHistoricalSignal(shift);
    custom_signal.OpenTime = iTime(_Symbol, _Period, shift);
    if (custom_signal.OpenTime <= 0)
    {
        Print("[Bot8][自定义补挂] 终止：无法读取历史K线时间。Shift=", shift);
        g_Custom_Fib_Status_Message = "无法读取历史K线时间";
        return false;
    }

    double fib0 = NormalizeDouble(g_Custom_Fib_Stop_Price, _Digits);
    double fib1 = NormalizeDouble(g_Custom_Fib_Entry_Price, _Digits);
    int type = (fib1 > fib0) ? OP_BUY : OP_SELL;

    if ((type == OP_BUY && g_Trade_Mode == B8_MODE_SELL_ONLY) ||
        (type == OP_SELL && g_Trade_Mode == B8_MODE_BUY_ONLY))
    {
        Print("[Bot8][自定义补挂] 终止：交易模式过滤方向。方向=",
              (type == OP_BUY ? "BUY" : "SELL"));
        g_Custom_Fib_Status_Message = "当前交易模式过滤了自定义方向";
        return false;
    }

    RefreshRates();
    Print("[Bot8][自定义补挂] 方向=", (type == OP_BUY ? "BUY" : "SELL"),
          " Fib0=", DoubleToString(fib0, _Digits),
          " Fib1=", DoubleToString(fib1, _Digits),
          " Bid=", DoubleToString(Bid, _Digits),
          " Ask=", DoubleToString(Ask, _Digits));

    custom_signal.BullishStopLossPrice = fib0;
    custom_signal.BearishStopLossPrice = fib0;
    custom_signal.BullishReferencePrice = fib1;
    custom_signal.BearishReferencePrice = fib1;

    double levels[9] = {0.120, 0.214, 0.236, 0.382, 0.500,
                        0.618, 0.786, 0.880, 1.000};
    bool selected[9] = {false, false, false, false, false, false, false, false, false};
    double entries[9] = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
    int order_types[9] = {OP_NONE, OP_NONE, OP_NONE, OP_NONE, OP_NONE,
                          OP_NONE, OP_NONE, OP_NONE, OP_NONE};
    string plan_tags[9] = {"", "", "", "", "", "", "", "", ""};
    bool plan_valid[9] = {false, false, false, false, false, false, false, false, false};
    int risk_mask = 0;
    int effective_count = 0;
    bool created_any = false;
    string group_key = B8_PendingGroupKey(custom_signal, type);

    for (int i = 0; i < 9; i++)
    {
        selected[i] = (i < 8) ? g_Pending_Fib_Selected[i] : true;
        plan_valid[i] = false;
        entries[i] = NormalizeDouble(fib0 + levels[i] * (fib1 - fib0), _Digits);
        order_types[i] = B8_GetCustomPendingOrderType(type, entries[i]);
        string fib_code = IntegerToString((int)MathRound(levels[i] * 1000.0));
        plan_tags[i] = group_key + B8_HISTORY_PLAN_MARKER +
                       B8_CUSTOM_FIB_PLAN_MARKER + "|F" + fib_code +
                       "|" + B8_TimeframeToText(_Period);

        if (!selected[i])
        {
            Print("[Bot8][自定义补挂][跳过] F", fib_code,
                  " 原因=未选择",
                  " 入场=", DoubleToString(entries[i], _Digits));
            continue;
        }

        if (order_types[i] == OP_NONE)
        {
            Print("[Bot8][自定义补挂][跳过] F", fib_code,
                  " 原因=订单类型与当前价格方向不匹配",
                  " 入场=", DoubleToString(entries[i], _Digits),
                  " Bid=", DoubleToString(Bid, _Digits),
                  " Ask=", DoubleToString(Ask, _Digits),
                  " OrderMode=", IntegerToString((int)g_Custom_Fib_Order_Type));
            continue;
        }

        plan_valid[i] = true;
        Print("[Bot8][自定义补挂][候选] F", fib_code,
              " 入场=", DoubleToString(entries[i], _Digits),
              " 类型=", IntegerToString(order_types[i]));
    }

    bool risk_pool_enabled = g_Custom_Fib_Risk_Shared ||
                              Enable_Fib_Risk_Allocation;
    int risk_pool_limit = g_Custom_Fib_Risk_Shared ? 9 : 8;
    if (risk_pool_enabled)
    {
        for (int precheck_index = 0; precheck_index < risk_pool_limit; precheck_index++)
        {
            if (!plan_valid[precheck_index]) continue;
            bool risk_eligible = B8_IsFibRiskEligible(
                custom_signal, type, entries[precheck_index],
                plan_tags[precheck_index]);
            string precheck_code = IntegerToString(
                (int)MathRound(levels[precheck_index] * 1000.0));
            if (risk_eligible)
                risk_mask |= (1 << precheck_index);
            else
            {
                bool duplicate = B8_IsPendingPlanDuplicate(
                    plan_tags[precheck_index]);
                double eligible_sl = (type == OP_BUY)
                                     ? custom_signal.BullishStopLossPrice
                                     : custom_signal.BearishStopLossPrice;
                double eligible_sl_diff = (type == OP_BUY)
                                          ? entries[precheck_index] - eligible_sl
                                          : eligible_sl - entries[precheck_index];
                double eligible_sl_points = eligible_sl_diff / Point();
                string reason = duplicate ? "重复计划"
                                          : ((eligible_sl <= 0.0 ||
                                              eligible_sl_diff <= 0.0)
                                             ? "止损方向无效"
                                             : ((Enable_SL_Min_Filter &&
                                                 eligible_sl_points < MathMax(1, SL_Min_Allowed_Points))
                                                ? "小于最小止损距离"
                                                : ((Enable_SL_Tier_Routing &&
                                                    eligible_sl_points > MathMax(MathMax(1, SL_Tier_Threshold_2_Points),
                                                                                 SL_Max_Allowed_Points))
                                                   ? "超过最大止损距离" : "其他风险过滤")));
                Print("[Bot8][自定义补挂][风险跳过] F", precheck_code,
                      " 原因=", reason,
                      " 入场=", DoubleToString(entries[precheck_index], _Digits),
                      " SL点数=", DoubleToString(eligible_sl_points, 1));
            }
        }

        if (Fib_Pending_Algorithm == B8_FIB_ALGO_V3)
        {
            bool eligibility_changed = true;
            while (eligibility_changed)
            {
                eligibility_changed = false;
                effective_count = 0;
                for (int count_index = 0; count_index < risk_pool_limit; count_index++)
                {
                    if ((risk_mask & (1 << count_index)) != 0)
                        effective_count++;
                }

                for (int check_order = 0; check_order < risk_pool_limit; check_order++)
                {
                    int risk_check_index = g_Custom_Fib_Risk_Shared
                                           ? ((Fib_Elimination_Policy == B8_KEEP_DEEP_FIB)
                                              ? (8 - check_order) : check_order)
                                           : B8_GetFibRiskCheckIndex(check_order);
                    if ((risk_mask & (1 << risk_check_index)) == 0) continue;

                    int allocation_index = 0;
                    for (int allocation_scan_index = 0;
                         allocation_scan_index < risk_check_index;
                         allocation_scan_index++)
                    {
                        if ((risk_mask & (1 << allocation_scan_index)) != 0)
                            allocation_index++;
                    }

                    double allocated_risk_value = g_Custom_Fib_Risk_Shared
                                                  ? B8_GetCustomFibAllocatedRisk(allocation_index,
                                                                                 effective_count)
                                                  : B8_GetFibAllocatedRisk(allocation_index,
                                                                           effective_count);
                    if (!B8_CanFormPendingRiskLot(custom_signal, type,
                                                  entries[risk_check_index],
                                                  allocated_risk_value))
                    {
                        Print("[Bot8][自定义补挂][V3淘汰] F",
                              IntegerToString((int)MathRound(levels[risk_check_index] * 1000.0)),
                              " 分配风险=", DoubleToString(allocated_risk_value, 2),
                              " 入场=", DoubleToString(entries[risk_check_index], _Digits),
                              " 原因=无法形成有效手数");
                        risk_mask &= ~(1 << risk_check_index);
                        eligibility_changed = true;
                        break;
                    }
                }
            }
        }

        effective_count = 0;
        for (int count_index = 0; count_index < risk_pool_limit; count_index++)
        {
            if ((risk_mask & (1 << count_index)) != 0)
                effective_count++;
        }
    }

    int effective_order_index = 0;
    for (int i = 0; i < 9; i++)
    {
        if (!plan_valid[i]) continue;

        double allocated_risk_value = -1.0;
        if (g_Custom_Fib_Risk_Shared)
        {
            if ((risk_mask & (1 << i)) == 0)
            {
                Print("[Bot8][自定义补挂][跳过] F",
                      IntegerToString((int)MathRound(levels[i] * 1000.0)),
                      " 原因=不在最终风险池");
                continue;
            }
            allocated_risk_value = B8_GetCustomFibAllocatedRisk(
                effective_order_index, effective_count);
            effective_order_index++;
        }
        else if (i == 8)
        {
            if (B8_IsPendingPlanDuplicate(plan_tags[i]))
            {
                Print("[Bot8][自定义补挂][跳过] F1000 原因=重复计划");
                continue;
            }
            allocated_risk_value = g_Runtime_Settings.risk_value;
        }
        else if (Enable_Fib_Risk_Allocation)
        {
            if ((risk_mask & (1 << i)) == 0)
            {
                Print("[Bot8][自定义补挂][跳过] F",
                      IntegerToString((int)MathRound(levels[i] * 1000.0)),
                      " 原因=不在最终风险池");
                continue;
            }
            allocated_risk_value = B8_GetFibAllocatedRisk(
                effective_order_index, effective_count);
            effective_order_index++;
        }
        else if (B8_IsPendingPlanDuplicate(plan_tags[i]))
        {
            Print("[Bot8][自定义补挂][跳过] F",
                IntegerToString((int)MathRound(levels[i] * 1000.0)),
                " 原因=重复计划");
            continue;
        }

          Print("[Bot8][自定义补挂][发单] F",
              IntegerToString((int)MathRound(levels[i] * 1000.0)),
              " 类型=", IntegerToString(order_types[i]),
              " 入场=", DoubleToString(entries[i], _Digits),
              " SL=", DoubleToString(fib0, _Digits),
              " 分配风险=", DoubleToString(allocated_risk_value, 2));
        B8_ExecutePendingTrade(custom_signal, type, entries[i],
                               plan_tags[i], allocated_risk_value,
                               fib0, order_types[i]);
        created_any = true;
    }

    if (created_any)
        g_Custom_Fib_Status_Message = "自定义价格补挂计划已提交";
    else
        g_Custom_Fib_Status_Message = "没有创建有效自定义挂单";
    Print("[Bot8][自定义补挂] 结束。RiskMask=", risk_mask,
          " EffectiveCount=", effective_count,
          " CreatedAny=", (created_any ? "true" : "false"),
          " Status=", g_Custom_Fib_Status_Message);
    return created_any;
}
//#endregion

//#region MARK: 模块--自定义价格补挂面板事件
bool B8_HandleCustomFibPanelEvent(const string object_name)
{
    if (object_name == B8_CUSTOM_FIB_ORDER_AUTO)
        g_Custom_Fib_Order_Type = B8_CUSTOM_PENDING_AUTO;
    else if (object_name == B8_CUSTOM_FIB_ORDER_BUY_LIMIT)
        g_Custom_Fib_Order_Type = B8_CUSTOM_PENDING_BUY_LIMIT;
    else if (object_name == B8_CUSTOM_FIB_ORDER_BUY_STOP)
        g_Custom_Fib_Order_Type = B8_CUSTOM_PENDING_BUY_STOP;
    else if (object_name == B8_CUSTOM_FIB_ORDER_SELL_LIMIT)
        g_Custom_Fib_Order_Type = B8_CUSTOM_PENDING_SELL_LIMIT;
    else if (object_name == B8_CUSTOM_FIB_ORDER_SELL_STOP)
        g_Custom_Fib_Order_Type = B8_CUSTOM_PENDING_SELL_STOP;
    else if (object_name == B8_CUSTOM_FIB_RISK_SHARED)
        g_Custom_Fib_Risk_Shared = true;
    else if (object_name == B8_CUSTOM_FIB_RISK_INDEPENDENT)
        g_Custom_Fib_Risk_Shared = false;
    else if (object_name == B8_CUSTOM_FIB_EXECUTE)
    {
        string entry_text = ObjectGetString(0, B8_CUSTOM_FIB_ENTRY_EDIT,
                                            OBJPROP_TEXT);
        string stop_text = ObjectGetString(0, B8_CUSTOM_FIB_STOP_EDIT,
                                           OBJPROP_TEXT);
        g_Custom_Fib_Entry_Price = StringToDouble(entry_text);
        g_Custom_Fib_Stop_Price = StringToDouble(stop_text);
        ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
        B8_CreateCustomPendingPlans(g_History_Selected_Shift);
        B8_UpdateCustomFibPanel();
        ChartRedraw();
        return true;
    }
    else
        return false;

    ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
    g_Custom_Fib_Status_Message = "订单类型/风险模式已选择";
    B8_UpdateCustomFibPanel();
    ChartRedraw();
    return true;
}
//#endregion

//====================================================================
// 将全部Fib挂单位置统一设置为选中或取消选中。
// 同步保存设置并刷新Fib面板显示。
//====================================================================
void B8_SetAllPendingFib(bool selected)
{
    for (int i = 0; i < 8; i++)
        g_Pending_Fib_Selected[i] = selected;

    B8_SavePendingFibSettings();
    B8_UpdateFibPanel();
}

//====================================================================
// 应用Fib挂单位置预设：预设1、预设2或预设3。
// 应用前先清空原选择，避免旧选择残留。
//====================================================================
void B8_ApplyPendingFibPreset(int preset_index)
{
    for (int i = 0; i < 8; i++)
        g_Pending_Fib_Selected[i] = false;

    if (preset_index == 0)
    {
        g_Pending_Fib_Selected[4] = true;
        g_Pending_Fib_Selected[5] = true;
    }
    else if (preset_index == 1)
    {
        g_Pending_Fib_Selected[3] = true;
        g_Pending_Fib_Selected[4] = true;
        g_Pending_Fib_Selected[5] = true;
    }
    else if (preset_index == 2)
    {
        for (int j = 0; j < 8; j++)
            g_Pending_Fib_Selected[j] = true;
    }

    B8_SavePendingFibSettings();
    B8_UpdateFibPanel();
}

//====================================================================
// 进入历史K线选择模式，等待用户点击主图上的已收盘K线。
// 暂时关闭图表滚动，避免选择期间误拖动图表。
//====================================================================
void B8_EnterHistoricalSelectMode()
{
    g_History_Select_Mode = true;
    g_History_Last_Button_Click = GetTickCount();
    g_History_Status_Message = "请点击主图上的已收盘K线";
    ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
    g_History_Panels_Hidden = true;
    B8_SetCorePanelsVisible(false);
    B8_UpdateHistoricalFibPanel();
    Comment("[Bot8] 历史信号选择模式：请点击主图上的已收盘K线");
    PlaySound("tick.wav");
    ChartRedraw();
}

//====================================================================
// 取消历史K线选择模式并恢复图表滚动状态。
//====================================================================
void B8_CancelHistoricalSelectMode()
{
    g_History_Select_Mode = false;
    ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
    if (g_History_Panels_Hidden)
    {
        g_History_Panels_Hidden = false;
        B8_SetCorePanelsVisible(true);
    }
    g_History_Status_Message = "已取消历史K线选择";
    B8_UpdateHistoricalFibPanel();
    Comment("");
    ChartRedraw();
}

//====================================================================
// 根据输入框中的shift重新读取历史信号并刷新预览状态。
// 该函数只负责读取和显示，不执行挂单。
//====================================================================
void B8_RefreshHistoricalSignalPreview()
{
    // 读取并规范化用户输入的历史K线shift。
    string shift_text = ObjectGetString(0, B8_FIB_HISTORY_SHIFT, OBJPROP_TEXT);
    int requested_shift = (int)StringToInteger(shift_text);
    if (requested_shift < 1)
        requested_shift = 1;

    // 确认历史数据范围有效，避免访问不存在的K线。
    int bars_count = iBars(_Symbol, _Period);
    if (bars_count <= 1 || requested_shift >= bars_count)
    {
        g_History_Preview_Valid = false;
        g_History_Status_Message = "历史K线范围无效";
        B8_UpdateHistoricalFibPanel();
        return;
    }

    // 使用独立历史读取函数获取指定K线的指标信号。
    g_History_Selected_Shift = requested_shift;
    g_History_Preview_Signal = B8_ReadHistoricalSignal(requested_shift);

    // 同时检查信号参考值和对应止损值，确认信号是否完整有效。
    bool has_bull = (g_History_Preview_Signal.BullishReferencePrice != (double)EMPTY_VALUE &&
                     g_History_Preview_Signal.BullishReferencePrice != 0.0 &&
                     g_History_Preview_Signal.BullishStopLossPrice != (double)EMPTY_VALUE &&
                     g_History_Preview_Signal.BullishStopLossPrice != 0.0);
    bool has_bear = (g_History_Preview_Signal.BearishReferencePrice != (double)EMPTY_VALUE &&
                     g_History_Preview_Signal.BearishReferencePrice != 0.0 &&
                     g_History_Preview_Signal.BearishStopLossPrice != (double)EMPTY_VALUE &&
                     g_History_Preview_Signal.BearishStopLossPrice != 0.0);

    g_History_Preview_Valid = (has_bull || has_bear);
    if (!g_History_Preview_Valid)
        g_History_Status_Message = "K[" + IntegerToString(requested_shift) + "] 没有有效信号";
    else
        g_History_Status_Message = "已读取 K[" + IntegerToString(requested_shift) + "]";

    B8_UpdateHistoricalFibPanel();
}
//#endregion

//#region MARK: 模块--新增实现：运行时订单策略多选应用
// 判断指定Ticket是否已经加入运行时订单的批量选择集合。
bool B8_RuntimeOrderTicketIsSelected(int ticket)
{
    for (int i = 0; i < g_Runtime_Order_Selected_Ticket_Count; i++)
    {
        if (g_Runtime_Order_Selected_Tickets[i] == ticket)
            return true;
    }
    return false;
}

// 切换指定Ticket的批量选择状态：已选则移除，未选则加入。
// 该集合只用于“范围:选中”模式，不改变当前正在编辑的订单。
void B8_RuntimeOrderToggleSelectedTicket(int ticket)
{
    if (ticket <= 0) return;

    for (int i = 0; i < g_Runtime_Order_Selected_Ticket_Count; i++)
    {
        if (g_Runtime_Order_Selected_Tickets[i] != ticket) continue;
        for (int j = i; j < g_Runtime_Order_Selected_Ticket_Count - 1; j++)
            g_Runtime_Order_Selected_Tickets[j] = g_Runtime_Order_Selected_Tickets[j + 1];
        g_Runtime_Order_Selected_Ticket_Count--;
        return;
    }

    if (g_Runtime_Order_Selected_Ticket_Count >= B8_RUNTIME_ORDER_MAX) return;
    g_Runtime_Order_Selected_Tickets[g_Runtime_Order_Selected_Ticket_Count++] = ticket;
}

// 清理批量选择集合中已经平仓或不再存在的订单Ticket。
// 订单列表刷新和批量应用前调用，避免对失效订单继续执行策略覆盖。
void B8_RuntimeOrderPruneSelectedTickets()
{
    for (int i = g_Runtime_Order_Selected_Ticket_Count - 1; i >= 0; i--)
    {
        if (B8_RuntimeOrderIsOpen(g_Runtime_Order_Selected_Tickets[i])) continue;
        for (int j = i; j < g_Runtime_Order_Selected_Ticket_Count - 1; j++)
            g_Runtime_Order_Selected_Tickets[j] = g_Runtime_Order_Selected_Tickets[j + 1];
        g_Runtime_Order_Selected_Ticket_Count--;
    }
}

// 循环切换运行时策略的应用范围：当前订单、选中订单、全部托管订单。
// 切换到“范围:选中”时，自动把当前订单加入批量选择集合，方便从单笔操作继续扩展。
void B8_RuntimeOrderCycleApplyScope()
{
    int next_scope = (int)g_Runtime_Order_Apply_Scope + 1;
    if (next_scope > (int)B8_RUNTIME_APPLY_ALL_MANAGED)
        next_scope = (int)B8_RUNTIME_APPLY_CURRENT;

    g_Runtime_Order_Apply_Scope = (ENUM_B8_RUNTIME_APPLY_SCOPE)next_scope;
    if (g_Runtime_Order_Apply_Scope == B8_RUNTIME_APPLY_SELECTED &&
        g_Runtime_Order_Selected_Ticket > 0 &&
        B8_RuntimeOrderIsOpen(g_Runtime_Order_Selected_Ticket) &&
        !B8_RuntimeOrderTicketIsSelected(g_Runtime_Order_Selected_Ticket))
    {
        B8_RuntimeOrderToggleSelectedTicket(g_Runtime_Order_Selected_Ticket);
    }
}

// 根据当前应用范围刷新范围按钮文字、颜色及面板范围提示信息。
// 该函数只更新界面，不执行订单策略应用。
void B8_RuntimeOrderUpdateApplyScopeControl()
{
    if (ObjectFind(0, B8_RUNTIME_ORDER_APPLY_SCOPE) < 0) return;

    string scope_text = "范围:当前";
    color scope_color = clrDeepSkyBlue;
    if (g_Runtime_Order_Apply_Scope == B8_RUNTIME_APPLY_SELECTED)
    {
        scope_text = "范围:选中";
        scope_color = clrDarkOrange;
    }
    else if (g_Runtime_Order_Apply_Scope == B8_RUNTIME_APPLY_ALL_MANAGED)
    {
        scope_text = "范围:全部";
        scope_color = clrDarkOrange;
    }

    ObjectSetString(0, B8_RUNTIME_ORDER_APPLY_SCOPE, OBJPROP_TEXT, scope_text);
    ObjectSetInteger(0, B8_RUNTIME_ORDER_APPLY_SCOPE, OBJPROP_BGCOLOR, scope_color);
    if (ObjectFind(0, B8_RUNTIME_ORDER_DETAIL4) >= 0)
    {
        ObjectSetString(0, B8_RUNTIME_ORDER_DETAIL4, OBJPROP_TEXT,
                        "应用范围: " + scope_text +
                        " | 已选: " + IntegerToString(g_Runtime_Order_Selected_Ticket_Count));
    }
}

// 输出运行时订单列表筛选失败原因；相同订单和相同原因每3秒最多打印一次。
// 当前函数入口处保留提前返回，实际日志输出暂未启用。
void B8_LogRuntimeOrderFilterMismatch(int position,
                                      int ticket,
                                      string reason)
{
    return;
    static uint last_log_tick = 0;
    static int last_ticket = -1;
    static string last_reason = "";

    uint current_tick = GetTickCount();
    if (ticket == last_ticket && reason == last_reason &&
        current_tick - last_log_tick < 3000)
        return;

    last_log_tick = current_tick;
    last_ticket = ticket;
    last_reason = reason;

    if (ticket <= 0)
    {
        Print("[Bot8][运行时订单列表筛选] Position:", position,
              " 无法OrderSelect。原因:", reason);
        return;
    }

    Print("[Bot8][运行时订单列表筛选] Position:", position,
          " Ticket:", ticket,
          " 品种:", OrderSymbol(),
          " 图表品种:", _Symbol,
          " Magic:", OrderMagicNumber(),
          " 当前家族Magic:", B8_GetMagicFamily(),
          " Magic序号:", B8_GetOrderMagicSeq(OrderMagicNumber()),
          " 类型:", OrderType(),
          " 原因:", reason);
}

// 将当前编辑中的运行时策略覆盖应用到指定的一个已成交订单。
// 策略记录按逻辑Magic保存，因此同一逻辑订单后续分单或部分平仓时仍可追踪。
bool B8_ApplyRuntimeOrderOverrideToTicket(int ticket,
                                          double trigger_value,
                                          double close_percent,
                                          int be_buffer)
{
    if (!g_Advanced_Order_Strategy_Enabled) return false;
    if (!B8_RuntimeOrderIsOpen(ticket)) return false;

    int logical_magic = OrderMagicNumber();
    int index = B8_FindRuntimeOrderOverride(logical_magic);
    if (index < 0)
    {
        if (g_Runtime_Order_Override_Count >= B8_RUNTIME_ORDER_MAX) return false;
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

    g_Runtime_Order_Overrides[index].active = true;
    g_Runtime_Order_Overrides[index].protection_enabled = true;
    g_Runtime_Order_Overrides[index].trigger_mode = g_Runtime_Order_Edit_Mode;
    g_Runtime_Order_Overrides[index].trigger_points =
        g_Runtime_Order_Edit_Mode == B8_ORDER_TRIGGER_POINTS
        ? trigger_value : g_Order_Runtime_Settings.order_trigger_points;
    g_Runtime_Order_Overrides[index].trigger_r =
        g_Runtime_Order_Edit_Mode == B8_ORDER_TRIGGER_R
        ? trigger_value : g_Order_Runtime_Settings.order_trigger_r;
    g_Runtime_Order_Overrides[index].partial_close_percent = close_percent;
    g_Runtime_Order_Overrides[index].protection_mode = g_Runtime_Order_Edit_Action;
    g_Runtime_Order_Overrides[index].be_buffer_points = be_buffer;
    return true;
}

// 按当前应用范围批量应用运行时订单策略，并统计成功与失败数量。
// 当前范围直接使用当前订单；选中范围使用批量选择集合；全部范围扫描所有托管市价订单。
bool B8_ApplyRuntimeOrderOverrideByScope(int &success_count,
                                         int &failure_count)
{
    success_count = 0;
    failure_count = 0;
    if (!g_Advanced_Order_Strategy_Enabled) return false;

    double trigger_value = StringToDouble(
        ObjectGetString(0, B8_RUNTIME_ORDER_EDIT_R, OBJPROP_TEXT));
    double close_percent = StringToDouble(
        ObjectGetString(0, B8_RUNTIME_ORDER_EDIT_CLOSE, OBJPROP_TEXT));
    int be_buffer = (int)MathRound(StringToDouble(
        ObjectGetString(0, B8_RUNTIME_ORDER_EDIT_BE, OBJPROP_TEXT)));
    if (trigger_value <= 0.0 || close_percent <= 0.0 ||
        close_percent >= 100.0 || be_buffer < 0)
        return false;

    if (g_Runtime_Order_Apply_Scope == B8_RUNTIME_APPLY_CURRENT)
    {
        if (B8_ApplyRuntimeOrderOverride())
            success_count = 1;
        else
            failure_count = 1;
        return success_count > 0;
    }

    if (g_Runtime_Order_Apply_Scope == B8_RUNTIME_APPLY_SELECTED)
    {
        B8_RuntimeOrderPruneSelectedTickets();
        if (g_Runtime_Order_Selected_Ticket_Count <= 0) return false;
        for (int i = 0; i < g_Runtime_Order_Selected_Ticket_Count; i++)
        {
            if (B8_ApplyRuntimeOrderOverrideToTicket(
                    g_Runtime_Order_Selected_Tickets[i],
                    trigger_value, close_percent, be_buffer))
                success_count++;
            else
                failure_count++;
        }
        return success_count > 0;
    }

    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsManagedOrder()) continue;
        if (OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
        int ticket = OrderTicket();
        if (B8_ApplyRuntimeOrderOverrideToTicket(
                ticket, trigger_value, close_percent, be_buffer))
            success_count++;
        else
            failure_count++;
    }
    return success_count > 0;
}
//#endregion

//#region MARK: 模块--独立运行时订单策略面板（基础版）
//====================================================================
// 独立运行时订单策略面板（基础版）
// 只维护当前运行内存中的单笔订单覆盖，不写入外部配置文件。
//====================================================================

// 按逻辑订单Magic查找运行时覆盖数组中的下标。
int B8_FindRuntimeOrderOverride(int logical_magic)
{
    for (int i = 0; i < g_Runtime_Order_Override_Count; i++)
    {
        if (g_Runtime_Order_Overrides[i].logical_magic == logical_magic)
            return i;
    }
    return -1;
}

// 判断指定逻辑订单Magic是否已经存在运行时策略覆盖。
bool B8_HasRuntimeOrderOverride(int logical_magic)
{
    return B8_FindRuntimeOrderOverride(logical_magic) >= 0;
}

// 仅从当前持仓池按 Ticket 查找并选中当前 EA 管理的市价订单。
// 不使用 SELECT_BY_TICKET，避免已平仓历史订单被误当作当前持仓。
bool B8_SelectRuntimeOrderByTicket(int ticket)
{
    if (ticket <= 0) return false;

    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (OrderTicket() != ticket) continue;
        if (!B8_IsManagedOrder()) return false;
        if (OrderType() != OP_BUY && OrderType() != OP_SELL) return false;
        return true;
    }

    return false;
}

// 检查 Ticket 是否为当前品种、当前 EA 管理的已成交多单或空单。
bool B8_RuntimeOrderIsOpen(int ticket)
{
    return B8_SelectRuntimeOrderByTicket(ticket);
}

// 从订单评论中提取 Fib 编号，用于显示和匹配 Fib 模板。
string B8_RuntimeOrderFibCode(string comment)
{
    int position = StringFind(comment, "|F", 0);
    if (position < 0) return "--";

    int code_start = position + 2;
    int code_end = StringFind(comment, "|", code_start);
    if (code_end < 0 || code_end - code_start != 3) return "--";

    return "0" + StringSubstr(comment, code_start, 3);
}

// 根据当前价格和订单止损距离计算面板显示用的当前 R 值。
double B8_RuntimeOrderCurrentR(int ticket)
{
    if (!B8_SelectRuntimeOrderByTicket(ticket)) return 0.0;
    int type = OrderType();
    int logical_magic = OrderMagicNumber();

    int override_index = B8_FindRuntimeOrderOverride(logical_magic);
    double risk = override_index >= 0
                  ? g_Runtime_Order_Overrides[override_index].initial_risk_price
                  : MathAbs(OrderOpenPrice() - OrderStopLoss());
    if (risk <= Point()) return 0.0;

    RefreshRates();
    double profit_distance = (type == OP_BUY) ? Bid - OrderOpenPrice()
                                              : OrderOpenPrice() - Ask;
    return profit_distance / risk;
}

// 计算当前已选订单触发止损时的预估亏损金额。
// 调用前应确保当前订单已经通过 OrderSelect() 选中。
bool B8_TryGetCurrentOrderStopRisk(double &risk_money)
{
    risk_money = 0.0;

    int type = OrderType();
    if (type != OP_BUY && type != OP_SELL) return false;

    double stop_loss = OrderStopLoss();
    if (stop_loss <= 0.0) return false;

    double adverse_distance = (type == OP_BUY)
                              ? OrderOpenPrice() - stop_loss
                              : stop_loss - OrderOpenPrice();
    if (adverse_distance <= 0.0) return false;

    string order_symbol = OrderSymbol();
    double tick_size = MarketInfo(order_symbol, MODE_TICKSIZE);
    double tick_value = MarketInfo(order_symbol, MODE_TICKVALUE);
    if (tick_size <= 0.0 || tick_value <= 0.0) return false;

    risk_money = adverse_distance * (tick_value / tick_size) * OrderLots();
    return risk_money >= 0.0;
}

// 选中订单并将该订单当前策略回填到运行时订单面板。
bool B8_RuntimeOrderSelectTicket(int ticket)
{
    if (!B8_SelectRuntimeOrderByTicket(ticket)) return false;
    g_Runtime_Order_Selected_Ticket = ticket;
    if (g_Runtime_Order_Inputs_Editing) return true;
    int logical_magic = OrderMagicNumber();
    int index = B8_FindRuntimeOrderOverride(logical_magic);
    if (index >= 0)
    {
        g_Runtime_Order_Edit_Mode = g_Runtime_Order_Overrides[index].trigger_mode;
        g_Runtime_Order_Edit_Action = g_Runtime_Order_Overrides[index].protection_mode;
        ObjectSetString(0, B8_RUNTIME_ORDER_EDIT_R, OBJPROP_TEXT,
                        g_Runtime_Order_Edit_Mode == B8_ORDER_TRIGGER_R
                        ? DoubleToString(g_Runtime_Order_Overrides[index].trigger_r, 2)
                        : DoubleToString(g_Runtime_Order_Overrides[index].trigger_points, 0));
        ObjectSetString(0, B8_RUNTIME_ORDER_EDIT_CLOSE, OBJPROP_TEXT,
                        DoubleToString(g_Runtime_Order_Overrides[index].partial_close_percent, 1));
        ObjectSetString(0, B8_RUNTIME_ORDER_EDIT_BE, OBJPROP_TEXT,
                        IntegerToString(g_Runtime_Order_Overrides[index].be_buffer_points));
    }
    else
    {
        g_Runtime_Order_Edit_Mode = g_Order_Runtime_Settings.order_trigger_mode;
        g_Runtime_Order_Edit_Action = g_Order_Runtime_Settings.order_protection_mode;
        ObjectSetString(0, B8_RUNTIME_ORDER_EDIT_R, OBJPROP_TEXT,
                        g_Runtime_Order_Edit_Mode == B8_ORDER_TRIGGER_R
                        ? DoubleToString(g_Order_Runtime_Settings.order_trigger_r, 2)
                        : DoubleToString(g_Order_Runtime_Settings.order_trigger_points, 0));
        ObjectSetString(0, B8_RUNTIME_ORDER_EDIT_CLOSE, OBJPROP_TEXT,
                        DoubleToString(g_Order_Runtime_Settings.order_partial_close_percent, 1));
        ObjectSetString(0, B8_RUNTIME_ORDER_EDIT_BE, OBJPROP_TEXT,
                        IntegerToString(g_Order_Runtime_Settings.order_be_buffer_points));
    }
    return true;
}

// 将全局订单级默认策略复制到运行时覆盖结构体。
// void B8_CopyDefaultToRuntimeOverride(B8_RUNTIME_ORDER_OVERRIDE &item)
// {
//     item.protection_enabled = g_Order_Runtime_Settings.order_protection_enabled;
//     item.trigger_mode = g_Order_Runtime_Settings.order_trigger_mode;
//     item.trigger_points = g_Order_Runtime_Settings.order_trigger_points;
//     item.trigger_r = g_Order_Runtime_Settings.order_trigger_r;
//     item.partial_close_percent = g_Order_Runtime_Settings.order_partial_close_percent;
//     item.protection_mode = g_Order_Runtime_Settings.order_protection_mode;
//     item.be_buffer_points = g_Order_Runtime_Settings.order_be_buffer_points;
// }

// 读取订单面板输入框，将当前选中订单保存为运行时策略覆盖。
bool B8_ApplyRuntimeOrderOverride()
{
    // 定位 #sym:B8_ApplyRuntimeOrderOverride 帮用户详解一下 该函数的业务逻辑；只分析
    // 扩展开关关闭时不允许创建或修改 Runtime Override，订单继续由订单级管理接管。
    if (!g_Advanced_Order_Strategy_Enabled) return false;

    int ticket = g_Runtime_Order_Selected_Ticket;
    if (!B8_RuntimeOrderIsOpen(ticket)) return false;
    int logical_magic = OrderMagicNumber();

    double trigger_value = StringToDouble(ObjectGetString(0, B8_RUNTIME_ORDER_EDIT_R, OBJPROP_TEXT));
    double close_percent = StringToDouble(ObjectGetString(0, B8_RUNTIME_ORDER_EDIT_CLOSE, OBJPROP_TEXT));
    int be_buffer = (int)MathRound(StringToDouble(ObjectGetString(0, B8_RUNTIME_ORDER_EDIT_BE, OBJPROP_TEXT)));
    if (trigger_value <= 0.0 || close_percent <= 0.0 || close_percent >= 100.0 || be_buffer < 0)
        return false;

    // 创建新的覆盖记录 如果当前 Magic 没有覆盖记录
    int index = B8_FindRuntimeOrderOverride(logical_magic);
    if (index < 0)
    {
        // 容量足够时创建新记录，并保存订单的初始状态
        if (g_Runtime_Order_Override_Count >= B8_RUNTIME_ORDER_MAX) return false;
        index = g_Runtime_Order_Override_Count++;
        g_Runtime_Order_Overrides[index].logical_magic = logical_magic;
        g_Runtime_Order_Overrides[index].fib_code = "--";
        g_Runtime_Order_Overrides[index].initial_open_price = OrderOpenPrice();
        g_Runtime_Order_Overrides[index].initial_sl = OrderStopLoss();
        // 这个值非常重要。之后如果使用 R 模式，实际触发条件会以这个初始风险距离计算，而不是以当前止损距离计算
        // 如果订单没有止损 initial_risk_price = 0；那么后续使用 R 模式时不会触发保护，因为执行器会拒绝风险距离过小的情况
        g_Runtime_Order_Overrides[index].initial_risk_price =
            MathAbs(OrderOpenPrice() - OrderStopLoss());
        g_Runtime_Order_Overrides[index].partial_closed_lots = 0.0;
        g_Runtime_Order_Overrides[index].partial_close_count = 0;
        g_Runtime_Order_Overrides[index].breakeven_done = false;
    }

    // 写入运行时策略参数
    g_Runtime_Order_Overrides[index].active = true;
    g_Runtime_Order_Overrides[index].protection_enabled = true;
    g_Runtime_Order_Overrides[index].trigger_mode = g_Runtime_Order_Edit_Mode;
    g_Runtime_Order_Overrides[index].trigger_points = g_Runtime_Order_Edit_Mode == B8_ORDER_TRIGGER_POINTS
                                                      ? trigger_value
                                                      : g_Order_Runtime_Settings.order_trigger_points;
    g_Runtime_Order_Overrides[index].trigger_r = g_Runtime_Order_Edit_Mode == B8_ORDER_TRIGGER_R
                                                 ? trigger_value
                                                 : g_Order_Runtime_Settings.order_trigger_r;
    g_Runtime_Order_Overrides[index].partial_close_percent = close_percent;
    g_Runtime_Order_Overrides[index].protection_mode = g_Runtime_Order_Edit_Action;
    g_Runtime_Order_Overrides[index].be_buffer_points = be_buffer;

    Print("[Bot8][运行时订单策略] 已应用。 Ticket:", ticket,
                " 触发:", DoubleToString(trigger_value,
                                g_Runtime_Order_Edit_Mode == B8_ORDER_TRIGGER_R ? 2 : 0),
                g_Runtime_Order_Edit_Mode == B8_ORDER_TRIGGER_R ? "R" : "点",
          " 减仓:", DoubleToString(close_percent, 1), "%",
            " 动作:", B8_RuntimeOrderActionText(g_Runtime_Order_Overrides[index].protection_mode));
    return true;
}

// 删除指定逻辑订单Magic的运行时覆盖，使其恢复使用订单级默认策略。
void B8_ClearRuntimeOrderOverride(int logical_magic)
{
    int index = B8_FindRuntimeOrderOverride(logical_magic);
    if (index < 0) return;

    for (int i = index; i < g_Runtime_Order_Override_Count - 1; i++)
        g_Runtime_Order_Overrides[i] = g_Runtime_Order_Overrides[i + 1];
    g_Runtime_Order_Override_Count--;
}

// 按单笔订单的运行时覆盖执行减仓、保本或全部平仓动作。
bool B8_ManageRuntimeOrderProtection(int ticket, int type)
{
    if (!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return true;
    int logical_magic = OrderMagicNumber();
    int index = B8_FindRuntimeOrderOverride(logical_magic);
    if (index < 0) return false;

    if (!g_Runtime_Order_Overrides[index].active ||
        !g_Runtime_Order_Overrides[index].protection_enabled) return true;

    double open_price = OrderOpenPrice();
    double current_sl = OrderStopLoss();
    double risk_price = g_Runtime_Order_Overrides[index].initial_risk_price;

    RefreshRates();
    double profit_price = (type == OP_BUY) ? Bid - open_price : open_price - Ask;
    if (profit_price <= 0.0) return true;

    bool triggered = false;
    if (g_Runtime_Order_Overrides[index].trigger_mode == B8_ORDER_TRIGGER_R)
    {
        if (risk_price <= Point()) return true;
        triggered = (profit_price / risk_price >= g_Runtime_Order_Overrides[index].trigger_r);
    }
    else
    {
        triggered = (profit_price / Point() >= g_Runtime_Order_Overrides[index].trigger_points);
    }
    if (!triggered) return true;

    if (g_Runtime_Order_Overrides[index].protection_mode == B8_ORDER_CLOSE_ONLY)
    {
        B8_CloseOrderFully(ticket, type);
        return true;
    }

    bool need_partial = g_Runtime_Order_Overrides[index].protection_mode == B8_ORDER_PARTIAL_ONLY ||
                        g_Runtime_Order_Overrides[index].protection_mode == B8_ORDER_PARTIAL_BE;
    bool need_be = g_Runtime_Order_Overrides[index].protection_mode == B8_ORDER_BE_ONLY ||
                   g_Runtime_Order_Overrides[index].protection_mode == B8_ORDER_PARTIAL_BE;

    double be_buffer = g_Runtime_Order_Overrides[index].be_buffer_points * Point();
    double be_sl = type == OP_BUY ? open_price + be_buffer : open_price - be_buffer;
    be_sl = NormalizeDouble(be_sl, _Digits);
    bool be_done = (type == OP_BUY && current_sl >= be_sl) ||
                   (type == OP_SELL && current_sl <= be_sl);

    if (need_be && !be_done)
    {
        RefreshRates();
        int stop_level_points = (int)MarketInfo(_Symbol, MODE_STOPLEVEL);
        double min_distance = stop_level_points * Point();
        if ((type == OP_BUY && be_sl > Bid - min_distance) ||
            (type == OP_SELL && be_sl < Ask + min_distance))
            return true;
        if (!OrderModify(ticket, open_price, be_sl, OrderTakeProfit(), 0, clrNONE))
            return true;
        g_Runtime_Order_Overrides[index].breakeven_done = true;
    }

    bool partial_done = (g_Runtime_Order_Overrides[index].partial_close_count > 0) ||
                        B8_HasOrderPartialCloseHistory(logical_magic, type) ||
                        B8_IsPartialCloseBlocked(logical_magic);
    if (need_partial && !partial_done)
    {
        double lots_before = OrderLots();
        if (B8_CloseOrderPartially(ticket, logical_magic, type,
                                   g_Runtime_Order_Overrides[index].partial_close_percent))
        {
            g_Runtime_Order_Overrides[index].partial_closed_lots +=
                lots_before * g_Runtime_Order_Overrides[index].partial_close_percent / 100.0;
            g_Runtime_Order_Overrides[index].partial_close_count++;
        }
    }
    return true;
}

// 返回 Fib 模板使用的标准编号字符串，例如 0120、0236、0880。
string B8_FibTemplateCode(int index)
{
    string codes[8] = {"0120", "0214", "0236", "0382", "0500", "0618", "0786", "0880"};
    if (index < 0 || index >= 8) return "----";
    return codes[index];
}

// 根据模板下标生成 Fib 模板列表按钮的唯一对象名称。
string B8_FibTemplateRowName(int index)
{
    return B8_FIB_TEMPLATE_ROW_PREFIX + IntegerToString(index);
}

// 根据订单评论中的 Fib 编号查找对应的模板下标。
int B8_FibTemplateIndexFromCode(string fib_code)
{
    for (int i = 0; i < 8; i++)
    {
        if (fib_code == B8_FibTemplateCode(i)) return i;
    }
    return -1;
}

// 使用当前订单级默认参数初始化八个 Fib 模板。
void B8_InitializeFibOrderTemplates()
{
    for (int i = 0; i < 8; i++)
    {
        g_Fib_Order_Templates[i].configured = false;
        g_Fib_Order_Templates[i].trigger_mode = g_Order_Runtime_Settings.order_trigger_mode;
        g_Fib_Order_Templates[i].trigger_points = g_Order_Runtime_Settings.order_trigger_points;
        g_Fib_Order_Templates[i].trigger_r = g_Order_Runtime_Settings.order_trigger_r;
        g_Fib_Order_Templates[i].partial_close_percent = g_Order_Runtime_Settings.order_partial_close_percent;
        g_Fib_Order_Templates[i].protection_mode = g_Order_Runtime_Settings.order_protection_mode;
        g_Fib_Order_Templates[i].be_buffer_points = g_Order_Runtime_Settings.order_be_buffer_points;
    }
    g_Fib_Template_Selected = 0;
    g_Fib_Template_Edit_Mode = g_Fib_Order_Templates[0].trigger_mode;
    g_Fib_Template_Edit_Action = g_Fib_Order_Templates[0].protection_mode;
}

// 将指定 Fib 模板复制为某个已成交订单的运行时覆盖策略。
void B8_CopyFibTemplateToOverride(int logical_magic, int template_index,
                                  double open_price, double initial_sl)
{
    if (template_index < 0 || template_index >= 8) return;
    int index = B8_FindRuntimeOrderOverride(logical_magic);
    if (index < 0)
    {
        if (g_Runtime_Order_Override_Count >= B8_RUNTIME_ORDER_MAX) return;
        index = g_Runtime_Order_Override_Count++;
        g_Runtime_Order_Overrides[index].logical_magic = logical_magic;
        g_Runtime_Order_Overrides[index].fib_code = B8_FibTemplateCode(template_index);
        g_Runtime_Order_Overrides[index].partial_closed_lots = 0.0;
        g_Runtime_Order_Overrides[index].partial_close_count = 0;
        g_Runtime_Order_Overrides[index].breakeven_done = false;
    }

    g_Runtime_Order_Overrides[index].active = true;
    g_Runtime_Order_Overrides[index].protection_enabled = true;
    g_Runtime_Order_Overrides[index].trigger_mode = g_Fib_Order_Templates[template_index].trigger_mode;
    g_Runtime_Order_Overrides[index].trigger_points = g_Fib_Order_Templates[template_index].trigger_points;
    g_Runtime_Order_Overrides[index].trigger_r = g_Fib_Order_Templates[template_index].trigger_r;
    g_Runtime_Order_Overrides[index].partial_close_percent = g_Fib_Order_Templates[template_index].partial_close_percent;
    g_Runtime_Order_Overrides[index].protection_mode = g_Fib_Order_Templates[template_index].protection_mode;
    g_Runtime_Order_Overrides[index].be_buffer_points = g_Fib_Order_Templates[template_index].be_buffer_points;
    g_Runtime_Order_Overrides[index].fib_code = B8_FibTemplateCode(template_index);
    g_Runtime_Order_Overrides[index].initial_open_price = open_price;
    g_Runtime_Order_Overrides[index].initial_sl = initial_sl;
    g_Runtime_Order_Overrides[index].initial_risk_price = MathAbs(open_price - initial_sl);
    Print("[Bot8][Fib模板] Magic:", logical_magic, " 已继承 Fib ", B8_FibTemplateCode(template_index), " 模板");
}

// 读取 Fib 模板编辑框，并保存当前选中 Fib 的独立策略参数。
bool B8_ApplyFibTemplate()
{
    double trigger_value = StringToDouble(ObjectGetString(0, B8_FIB_TEMPLATE_EDIT_VALUE, OBJPROP_TEXT));
    double close_percent = StringToDouble(ObjectGetString(0, B8_FIB_TEMPLATE_EDIT_CLOSE, OBJPROP_TEXT));
    int be_buffer = (int)MathRound(StringToDouble(ObjectGetString(0, B8_FIB_TEMPLATE_EDIT_BE, OBJPROP_TEXT)));
    if (trigger_value <= 0.0 || close_percent <= 0.0 || close_percent >= 100.0 || be_buffer < 0)
        return false;

    g_Fib_Order_Templates[g_Fib_Template_Selected].configured = true;
    g_Fib_Order_Templates[g_Fib_Template_Selected].trigger_mode = g_Fib_Template_Edit_Mode;
    g_Fib_Order_Templates[g_Fib_Template_Selected].trigger_points = g_Fib_Template_Edit_Mode == B8_ORDER_TRIGGER_POINTS
                                                                      ? trigger_value
                                                                      : g_Order_Runtime_Settings.order_trigger_points;
    g_Fib_Order_Templates[g_Fib_Template_Selected].trigger_r = g_Fib_Template_Edit_Mode == B8_ORDER_TRIGGER_R
                                                                 ? trigger_value
                                                                 : g_Order_Runtime_Settings.order_trigger_r;
    g_Fib_Order_Templates[g_Fib_Template_Selected].partial_close_percent = close_percent;
    g_Fib_Order_Templates[g_Fib_Template_Selected].protection_mode = g_Fib_Template_Edit_Action;
    g_Fib_Order_Templates[g_Fib_Template_Selected].be_buffer_points = be_buffer;
    return true;
}

// 为八个Fib模板统一应用内置策略，并立即启用全部模板。
void B8_ApplyFibTemplatePreset(int preset_index)
{
    if (preset_index < 0 || preset_index > 2) return;

    // 每一列对应一个 Fib 模板，三行分别是保守、标准、激进预设。
    double trigger_r[3][8] =
    {
        {10.0, 8.0, 6.0, 4.0, 3.0, 2.5, 2.0, 1.5},
        { 5.0, 4.0, 3.0, 2.5, 2.0, 1.5, 1.0, 0.5},
        { 2.0, 1.5, 1.0, 0.8, 0.6, 0.5, 0.4, 0.3}
    };
    double close_percent[3][8] =
    {
        {80.0, 80.0, 80.0, 75.0, 70.0, 70.0, 60.0, 50.0},
        {80.0, 80.0, 75.0, 70.0, 60.0, 60.0, 50.0, 50.0},
        {50.0, 50.0, 50.0, 50.0, 40.0, 40.0, 30.0, 30.0}
    };
    int protection_mode[3][8] =
    {
        {B8_ORDER_PARTIAL_BE, B8_ORDER_PARTIAL_BE, B8_ORDER_PARTIAL_BE, B8_ORDER_PARTIAL_BE,
         B8_ORDER_PARTIAL_BE, B8_ORDER_PARTIAL_BE, B8_ORDER_BE_ONLY, B8_ORDER_BE_ONLY},
        {B8_ORDER_PARTIAL_BE, B8_ORDER_PARTIAL_BE, B8_ORDER_PARTIAL_BE, B8_ORDER_PARTIAL_BE,
         B8_ORDER_PARTIAL_BE, B8_ORDER_BE_ONLY, B8_ORDER_PARTIAL_ONLY, B8_ORDER_PARTIAL_ONLY},
        {B8_ORDER_PARTIAL_ONLY, B8_ORDER_PARTIAL_ONLY, B8_ORDER_PARTIAL_ONLY, B8_ORDER_PARTIAL_ONLY,
         B8_ORDER_PARTIAL_ONLY, B8_ORDER_PARTIAL_ONLY, B8_ORDER_PARTIAL_ONLY, B8_ORDER_PARTIAL_ONLY}
    };
    int be_buffer[3][8] =
    {
        {10, 10, 10, 10, 10, 10, 10, 10},
        {10, 10, 10, 10, 10, 10, 10, 10},
        { 5,  5,  5,  5,  5,  5,  5,  5}
    };

    for (int i = 0; i < 8; i++)
    {
        g_Fib_Order_Templates[i].configured = true;
        g_Fib_Order_Templates[i].trigger_mode = B8_ORDER_TRIGGER_R;
        g_Fib_Order_Templates[i].trigger_points = g_Order_Runtime_Settings.order_trigger_points;
        g_Fib_Order_Templates[i].trigger_r = trigger_r[preset_index][i];
        g_Fib_Order_Templates[i].partial_close_percent = close_percent[preset_index][i];
        g_Fib_Order_Templates[i].protection_mode = (ENUM_B8_ORDER_PROTECTION_MODE)protection_mode[preset_index][i];
        g_Fib_Order_Templates[i].be_buffer_points = be_buffer[preset_index][i];
    }

    g_Fib_Template_Edit_Mode = g_Fib_Order_Templates[g_Fib_Template_Selected].trigger_mode;
    g_Fib_Template_Edit_Action = g_Fib_Order_Templates[g_Fib_Template_Selected].protection_mode;
    g_Fib_Template_Inputs_Editing = false;
}
//#endregion

//#region MARK: 模块--手动平仓模块
//+------------------------------------------------------------------+
// 手动平仓模块：按当前品种的交易商规则规范化平仓手数。
// 返回值为0表示输入手数无效；不会在这里强行放大到最小手数。
//+------------------------------------------------------------------+
double B8_NormalizeManualCloseLots(double lots)
{
    double lot_step = MarketInfo(_Symbol, MODE_LOTSTEP);
    if (lot_step <= 0.0) lot_step = MarketInfo(_Symbol, MODE_MINLOT);
    if (lot_step <= 0.0 || lots <= 0.0) return 0.0;

    double normalized = MathFloor((lots + lot_step * 0.0001) / lot_step) * lot_step;
    return NormalizeDouble(normalized, 2);
}

// 手动平仓模块：对指定的当前持仓执行指定手数。
// 订单会再次校验品种和Bot8家族Magic，避免旧Ticket或外部订单被误操作。
//+------------------------------------------------------------------+
bool B8_CloseManualOrderLots(int ticket, double requested_lots, color close_color)
{
    if (!IsTradeAllowed())
    {
        Print("[Bot8][手动平仓] 交易未开启，Ticket:", ticket);
        return false;
    }
    if (!B8_SelectRuntimeOrderByTicket(ticket)) return false;

    double min_lot = MarketInfo(_Symbol, MODE_MINLOT);
    if (min_lot <= 0.0) min_lot = 0.01;
    double current_lots = OrderLots();
    double close_lots = B8_NormalizeManualCloseLots(requested_lots);
    if (close_lots <= 0.0 || close_lots < min_lot) return false;

    // 请求手数达到当前持仓时直接全平；否则必须保留合法的最小剩余手数。
    if (close_lots > current_lots) close_lots = current_lots;
    close_lots = NormalizeDouble(close_lots, 2);
    double remain_lots = NormalizeDouble(current_lots - close_lots, 2);
    if (close_lots < current_lots && remain_lots < min_lot)
    {
        Print("[Bot8][手动平仓] 剩余手数不足，跳过。Ticket:", ticket,
              " 当前:", DoubleToString(current_lots, 2),
              " 请求:", DoubleToString(requested_lots, 2));
        return false;
    }

    int type = OrderType();
    RefreshRates();
    double close_price = type == OP_BUY ? Bid : Ask;
    ResetLastError();
    if (!OrderClose(ticket, close_lots, close_price, Slippage, close_color))
    {
        Print("[Bot8][手动平仓] 执行失败。Ticket:", ticket,
              " 手数:", DoubleToString(close_lots, 2),
              " 错误码:", GetLastError());
        return false;
    }

    Print("[Bot8][手动平仓] 执行成功。Ticket:", ticket,
          " 手数:", DoubleToString(close_lots, 2));
    return true;
}

// 手动平仓模块：对运行时面板当前选中的单笔订单按手数平仓。
//+------------------------------------------------------------------+
bool B8_CloseSelectedManualLots(double lots)
{
    if (g_Runtime_Order_Selected_Ticket <= 0) return false;
    return B8_CloseManualOrderLots(g_Runtime_Order_Selected_Ticket, lots, clrViolet);
}

// 手动平仓模块：对当前选中的单笔订单按比例平仓。
//+------------------------------------------------------------------+
bool B8_CloseSelectedManualPercent(double percent)
{
    if (percent <= 0.0 || percent > 100.0) return false;
    if (!B8_SelectRuntimeOrderByTicket(g_Runtime_Order_Selected_Ticket)) return false;

    double current_lots = OrderLots();
    if (percent >= 100.0)
        return B8_CloseManualOrderLots(g_Runtime_Order_Selected_Ticket,
                                       current_lots, clrOrangeRed);
    return B8_CloseManualOrderLots(g_Runtime_Order_Selected_Ticket,
                                   current_lots * percent / 100.0, clrOrange);
}

// 手动平仓模块：对当前品种+Bot8家族Magic的全部持仓按比例平仓。
// 先保存Ticket快照，避免OrderClose后订单池索引变化导致漏单或错单。
//+------------------------------------------------------------------+
bool B8_CloseManagedManualPercent(double percent)
{
    if (percent <= 0.0 || percent > 100.0) return false;

    int tickets[];
    double lots[];
    int count = 0;
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsManagedOrder()) continue;
        if (OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
        ArrayResize(tickets, count + 1);
        ArrayResize(lots, count + 1);
        tickets[count] = OrderTicket();
        lots[count] = OrderLots();
        count++;
    }
    if (count == 0) return false;

    bool any_success = false;
    for (int j = 0; j < count; j++)
    {
        double close_lots = percent >= 100.0 ? lots[j] : lots[j] * percent / 100.0;
        if (B8_CloseManualOrderLots(tickets[j], close_lots,
                                    percent >= 100.0 ? clrOrangeRed : clrOrange))
            any_success = true;
    }
    return any_success;
}

// 手动平仓模块：对当前品种+Bot8家族Magic的全部持仓按总手数平仓。
// 处理顺序按持仓手数从小到大，尽量优先清理小单并减少零碎仓位。
//+------------------------------------------------------------------+
bool B8_CloseManagedManualLots(double lots_to_close)
{
    double requested_lots = B8_NormalizeManualCloseLots(lots_to_close);
    double min_lot = MarketInfo(_Symbol, MODE_MINLOT);
    if (min_lot <= 0.0) min_lot = 0.01;
    if (requested_lots < min_lot) return false;

    int tickets[];
    double lots[];
    int count = 0;
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsManagedOrder()) continue;
        if (OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
        ArrayResize(tickets, count + 1);
        ArrayResize(lots, count + 1);
        tickets[count] = OrderTicket();
        lots[count] = OrderLots();
        count++;
    }
    if (count == 0) return false;

    // 对快照按持仓手数升序排序，不改变实际订单池。
    for (int left = 0; left < count - 1; left++)
    {
        for (int right = left + 1; right < count; right++)
        {
            if (lots[right] >= lots[left]) continue;
            double temp_lots = lots[left];
            lots[left] = lots[right];
            lots[right] = temp_lots;
            int temp_ticket = tickets[left];
            tickets[left] = tickets[right];
            tickets[right] = temp_ticket;
        }
    }

    double remaining = requested_lots;
    bool any_success = false;
    for (int row = 0; row < count && remaining >= min_lot; row++)
    {
        double close_lots = MathMin(lots[row], remaining);
        close_lots = B8_NormalizeManualCloseLots(close_lots);
        if (close_lots < min_lot) continue;
        if (!B8_CloseManualOrderLots(tickets[row], close_lots, clrViolet)) continue;
        remaining = NormalizeDouble(remaining - close_lots, 2);
        any_success = true;
    }

    if (remaining >= min_lot)
        Print("[Bot8][手动平仓] 管理订单剩余目标手数:", DoubleToString(remaining, 2));
    return any_success;
}

// 手动平仓模块：刷新范围按钮颜色和操作结果提示。
//+------------------------------------------------------------------+
void B8_SetRuntimeCloseStatus(string text, bool success)
{
    if (ObjectFind(0, B8_RUNTIME_QUICK_STATUS) >= 0)
        ObjectSetString(0, B8_RUNTIME_QUICK_STATUS, OBJPROP_TEXT, text);
    if (ObjectFind(0, B8_RUNTIME_CLOSE_SCOPE_ONE) >= 0)
        ObjectSetInteger(0, B8_RUNTIME_CLOSE_SCOPE_ONE, OBJPROP_BGCOLOR,
                         g_Runtime_Close_All_Managed ? clrDimGray : clrDeepSkyBlue);
    if (ObjectFind(0, B8_RUNTIME_CLOSE_SCOPE_ALL) >= 0)
        ObjectSetInteger(0, B8_RUNTIME_CLOSE_SCOPE_ALL, OBJPROP_BGCOLOR,
                         g_Runtime_Close_All_Managed ? clrDeepSkyBlue : clrDimGray);
    if (!success)
        Print("[Bot8][手动平仓] ", text);
}

// 手动平仓模块：按当前范围执行比例平仓，并刷新运行时订单面板。
//+------------------------------------------------------------------+
bool B8_ExecuteRuntimeClosePercent(double percent)
{
    if (percent <= 0.0 || percent > 100.0)
    {
        B8_SetRuntimeCloseStatus("比例无效：请输入1~100", false);
        return false;
    }

    bool success = g_Runtime_Close_All_Managed
                   ? B8_CloseManagedManualPercent(percent)
                   : B8_CloseSelectedManualPercent(percent);
    B8_SetRuntimeCloseStatus(success ? "比例平仓完成" : "比例平仓失败或无可用订单",
                             success);
    B8_UpdateRuntimeOrderPanel();
    ChartRedraw();
    return success;
}

// 手动平仓模块：按当前范围执行lot平仓，并刷新运行时订单面板。
//+------------------------------------------------------------------+
bool B8_ExecuteRuntimeCloseLots(double lots)
{
    if (lots <= 0.0)
    {
        B8_SetRuntimeCloseStatus("lot无效：请输入大于0的数值", false);
        return false;
    }

    bool success = g_Runtime_Close_All_Managed
                   ? B8_CloseManagedManualLots(lots)
                   : B8_CloseSelectedManualLots(lots);
    B8_SetRuntimeCloseStatus(success ? "lot平仓完成" : "lot平仓失败或无可用订单",
                             success);
    B8_UpdateRuntimeOrderPanel();
    ChartRedraw();
    return success;
}
//#endregion

//#region MARK: 模块--快捷订单管理
// 快捷订单管理：判断订单是否为四类挂单之一。
bool B8_IsQuickPendingOrder(int order_type)
{
    return order_type == OP_BUYLIMIT || order_type == OP_BUYSTOP ||
           order_type == OP_SELLLIMIT || order_type == OP_SELLSTOP;
}

// 快捷订单管理：执行市价订单筛选平仓。
// direction=-1表示多空全部；profit_filter=-1表示不筛选，0表示亏损，1表示盈利。
bool B8_QuickCloseMarketOrders(bool current_scope, int direction,
                                int profit_filter, string action_name)
{
    if (!IsTradeAllowed())
    {
        B8_SetRuntimeCloseStatus(action_name + "失败：交易未开启", false);
        return false;
    }

    int success_count = 0;
    int failed_count = 0;
    int skipped_count = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            skipped_count++;
            continue;
        }
        int order_type = OrderType();
        if (order_type != OP_BUY && order_type != OP_SELL)
        {
            skipped_count++;
            continue;
        }
        if (current_scope && !B8_IsManagedOrder())
        {
            skipped_count++;
            continue;
        }
        if (direction >= 0 && order_type != direction)
        {
            skipped_count++;
            continue;
        }

        double net_profit = OrderProfit() + OrderSwap() + OrderCommission();
        if ((profit_filter == 0 && net_profit >= 0.0) ||
            (profit_filter == 1 && net_profit <= 0.0))
        {
            skipped_count++;
            continue;
        }

        string order_symbol = OrderSymbol();
        int symbol_digits = (int)MarketInfo(order_symbol, MODE_DIGITS);
        double close_price = order_type == OP_BUY
                             ? MarketInfo(order_symbol, MODE_BID)
                             : MarketInfo(order_symbol, MODE_ASK);
        close_price = NormalizeDouble(close_price, symbol_digits);
        int ticket = OrderTicket();
        double close_lots = OrderLots();
        ResetLastError();
        if (OrderClose(ticket, close_lots, close_price, Slippage, clrOrangeRed))
            success_count++;
        else
        {
            failed_count++;
            Print("[Bot8][快捷平仓] ", action_name,
                  "失败。Ticket:", ticket,
                  " 错误码:", GetLastError());
        }
    }

    string status = action_name + "完成：成功" + IntegerToString(success_count) +
                    " 失败" + IntegerToString(failed_count);
    B8_SetRuntimeCloseStatus(status, failed_count == 0);
    B8_UpdateRuntimeOrderPanel();
    ChartRedraw();
    return success_count > 0 && failed_count == 0;
}

// 快捷订单管理：删除全账户全部挂单，不处理市价持仓。
bool B8_QuickDeleteAllPending(string action_name)
{
    if (!IsTradeAllowed())
    {
        B8_SetRuntimeCloseStatus(action_name + "失败：交易未开启", false);
        return false;
    }

    int success_count = 0;
    int failed_count = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsQuickPendingOrder(OrderType())) continue;

        int ticket = OrderTicket();
        ResetLastError();
        if (OrderDelete(ticket, clrSlateGray))
            success_count++;
        else
        {
            failed_count++;
            Print("[Bot8][快捷删挂] ", action_name,
                  "失败。Ticket:", ticket,
                  " 错误码:", GetLastError());
        }
    }

    string status = action_name + "完成：成功" + IntegerToString(success_count) +
                    " 失败" + IntegerToString(failed_count);
    B8_SetRuntimeCloseStatus(status, failed_count == 0);
    B8_UpdateRuntimeOrderPanel();
    ChartRedraw();
    return success_count > 0 && failed_count == 0;
}

// 快捷订单管理：执行全账户清仓，包括全部市价持仓和全部挂单。
bool B8_QuickClearAllOrders()
{
    if (!IsTradeAllowed())
    {
        B8_SetRuntimeCloseStatus("清仓失败：交易未开启", false);
        return false;
    }

    int close_success = 0;
    int close_failed = 0;
    int delete_success = 0;
    int delete_failed = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        int order_type = OrderType();
        int ticket = OrderTicket();
        ResetLastError();
        if (order_type == OP_BUY || order_type == OP_SELL)
        {
            string order_symbol = OrderSymbol();
            int symbol_digits = (int)MarketInfo(order_symbol, MODE_DIGITS);
            double close_price = order_type == OP_BUY
                                 ? MarketInfo(order_symbol, MODE_BID)
                                 : MarketInfo(order_symbol, MODE_ASK);
            close_price = NormalizeDouble(close_price, symbol_digits);
            if (OrderClose(ticket, OrderLots(), close_price, Slippage, clrCrimson))
                close_success++;
            else
            {
                close_failed++;
                Print("[Bot8][清仓] 平仓失败。Ticket:", ticket,
                      " 错误码:", GetLastError());
            }
        }
        else if (B8_IsQuickPendingOrder(order_type))
        {
            if (OrderDelete(ticket, clrCrimson))
                delete_success++;
            else
            {
                delete_failed++;
                Print("[Bot8][清仓] 删挂失败。Ticket:", ticket,
                      " 错误码:", GetLastError());
            }
        }
    }

    string status = "清仓完成：平仓" + IntegerToString(close_success) +
                    "笔，删挂" + IntegerToString(delete_success) + "笔";
    if (close_failed > 0 || delete_failed > 0)
        status = status + "，失败" + IntegerToString(close_failed + delete_failed);
    B8_SetRuntimeCloseStatus(status, close_failed == 0 && delete_failed == 0);
    B8_UpdateRuntimeOrderPanel();
    ChartRedraw();
    return close_failed == 0 && delete_failed == 0;
}

// 快捷订单管理：仅删除当前品种、当前Bot8家族Magic下的全部挂单。
// 这是独立于“删挂”（全账户）之外的受限删挂入口。
bool B8_QuickDeleteManagedPending()
{
    if (!IsTradeAllowed())
    {
        B8_SetRuntimeCloseStatus("本品种删挂失败：交易未开启", false);
        return false;
    }

    int success_count = 0;
    int failed_count = 0;
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (!B8_IsQuickPendingOrder(OrderType())) continue;
        if (!B8_IsManagedOrder()) continue;

        int ticket = OrderTicket();
        ResetLastError();
        if (OrderDelete(ticket, clrSteelBlue))
            success_count++;
        else
        {
            failed_count++;
            Print("[Bot8][本品种删挂] 删除失败。Ticket:", ticket,
                  " 品种:", OrderSymbol(),
                  " Magic:", OrderMagicNumber(),
                  " 错误码:", GetLastError());
        }
    }

    string status = "本品种删挂完成：成功" + IntegerToString(success_count) +
                    " 失败" + IntegerToString(failed_count);
    B8_SetRuntimeCloseStatus(status, failed_count == 0);
    B8_UpdateRuntimeOrderPanel();
    ChartRedraw();
    return success_count > 0 && failed_count == 0;
}

// 以下11个入口保持按钮语义独立，底层只复用订单遍历和执行机制。
bool B8_HandleQuickThisAll()
{
    return B8_QuickCloseMarketOrders(true, -1, -1, "本全平");
}

bool B8_HandleQuickThisLoss()
{
    return B8_QuickCloseMarketOrders(true, -1, 0, "亏平");
}

bool B8_HandleQuickThisProfit()
{
    return B8_QuickCloseMarketOrders(true, -1, 1, "盈平");
}

bool B8_HandleQuickThisSell()
{
    return B8_QuickCloseMarketOrders(true, OP_SELL, -1, "空平");
}

bool B8_HandleQuickThisBuy()
{
    return B8_QuickCloseMarketOrders(true, OP_BUY, -1, "多平");
}

bool B8_HandleQuickAllLoss()
{
    return B8_QuickCloseMarketOrders(false, -1, 0, "亏全平");
}

bool B8_HandleQuickAllProfit()
{
    return B8_QuickCloseMarketOrders(false, -1, 1, "盈全平");
}

bool B8_HandleQuickAllSell()
{
    return B8_QuickCloseMarketOrders(false, OP_SELL, -1, "空全平");
}

bool B8_HandleQuickAllBuy()
{
    return B8_QuickCloseMarketOrders(false, OP_BUY, -1, "多全平");
}

bool B8_HandleQuickClearAll()
{
    int result = MessageBox("将关闭账户全部市价订单并删除全部挂单，是否继续？",
                            "确认清仓", MB_OKCANCEL | MB_ICONWARNING);
    if (result != IDOK)
    {
        B8_SetRuntimeCloseStatus("已取消清仓", true);
        return false;
    }
    return B8_QuickClearAllOrders();
}

bool B8_HandleQuickDeletePending()
{
    return B8_QuickDeleteAllPending("删挂");
}

// 快捷订单管理：独立的当前品种+Bot8 Magic删挂按钮入口。
bool B8_HandleQuickDeleteManaged()
{
    return B8_QuickDeleteManagedPending();
}
//#endregion