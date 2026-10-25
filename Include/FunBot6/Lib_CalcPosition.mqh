//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 资金管理模块：核心计算库                                         |
//+------------------------------------------------------------------+

/*
//+------------------------------------------------------------------+
//| 辅助函数：修正手数 (符合平台规则)                                |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
   double min_lot  = MarketInfo(Symbol(), MODE_MINLOT);  // 最小手数 (通常 0.01)
   double max_lot  = MarketInfo(Symbol(), MODE_MAXLOT);  // 最大手数
   double lot_step = MarketInfo(Symbol(), MODE_LOTSTEP); // 手数步长 (通常 0.01)

   // 1. 向下取整到步长 (例如 0.098522 -> 0.09)
   // 也可以使用 MathRound 进行四舍五入，看您偏好风险控制的严格程度
   // 这里演示的是标准步长修正：
   lots = MathFloor(lots / lot_step) * lot_step; 

   // 2. 限制在最小和最大范围内
   if (lots < min_lot) lots = min_lot; // 如果算出来太小，至少开最小手 (或者您可以选择不开)
   if (lots > max_lot) lots = max_lot;

   return lots;
}
*/

//+------------------------------------------------------------------+
//| 1. 基础工具：修正手数 (符合平台规则)                                |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
   double min_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // 向下取整到步长 (防止 0.138 -> 0.13 导致风险略微超标，宁可少开不可多开)
   // 如果偏好四舍五入，可改用 MathRound
   lots = MathFloor(lots / lot_step) * lot_step;

   // 边界检查
   if (lots < min_lot) return min_lot; // 注意：如果算出来比最小手数还小，通常建议不交易，这里返回最小手数需谨慎
   if (lots > max_lot) return max_lot;

   return lots;
}

//+------------------------------------------------------------------+
//| 获取当前品种的每手合约大小 (Contract Size)                       |
//+------------------------------------------------------------------+
double GetContractSize()
{
    // MarketInfo(symbol, type)
    // Symbol()      : 当前图表上的品种名称
    // MODE_LOTSIZE  : 请求每手合约大小 (例如: 100000 用于外汇标准手, 100 用于黄金)
    
   double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    
    // 检查返回值是否有效
    if (contract_size <= 0)
    {
        Print(" 错误: 无法获取品种 ", Symbol(), " 的合约大小，返回值: ", contract_size);
        // 通常会返回一个默认值或终止EA
        return 100000.0; // 返回一个标准外汇合约大小作为安全值
    }
    
    return contract_size;
}

//+------------------------------------------------------------------+
//| 方法1：基于合约大小的计算 (您的习惯方式)                         |
//+------------------------------------------------------------------+
double CalculateLots_ByContract(double entry_price, double sl_price, double risk_money)
{
   double price_diff = MathAbs(entry_price - sl_price); // 计算价格差 (10.15)
   double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE); // 获取合约大小 (100)
   
   // 防止除以0
   if (price_diff == 0 || contract_size == 0) return 0;

   // 计算做1标准手会亏损的金额
   double loss_per_lot = contract_size * price_diff; // 100 * 10.15 = 1015
   
   // 计算手数
   double lots = risk_money / loss_per_lot; // 100 / 1015 = 0.0985...
   
   return NormalizeLots(lots); // ⚠️ 必须进行手数修正(见文末)
}

//+------------------------------------------------------------------+
//| ✅ 方法2：基于 TickValue 的通用计算 (推荐用于 EA)                   |
//+------------------------------------------------------------------+
double CalculateLots_ByTickValue(double entry_price, double sl_price, double risk_money)
{
   double price_diff = MathAbs(entry_price - sl_price);
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);  // 例如 0.01
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE); // 例如 1.0 (1手跳一下是多少钱)

   if (tick_size == 0 || tick_value == 0) return 0;

   // 1. 计算止损是多少个 "Tick" (微点)
   // 例如: 10.15 / 0.01 = 1015 个 Tick
   double ticks = price_diff / tick_size; 

   // 2. 计算手数
   // 公式: 风险 / (跳动次数 * 单次跳动价值)
   double lots = risk_money / (ticks * tick_value); 

   return NormalizeLots(lots); // ⚠️ 必须进行手数修正
}



//+------------------------------------------------------------------+
//| 2. 策略层：根据模式计算具体的“风险金额”                             |
//+------------------------------------------------------------------+
double CalculateRiskMoney(ENUM_RISK_MODE mode, double risk_value)
{
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double final_risk_money = 0.0;

   switch(mode)
   {
      case RISK_FIXED_MONEY:
         // 直接使用固定金额，例如 100
         final_risk_money = risk_value;
         break;
         
      case RISK_PERCENTAGE:
         // 计算百分比金额，例如 10000 * 0.03 = 300
         // 输入 3 代表 3%，所以要除以 100
         final_risk_money = account_balance * (risk_value / 100.0);
         break;
         
      default:
         final_risk_money = 0.0;
   }
   
   return final_risk_money;
}

//+------------------------------------------------------------------+
//| 3. 核心层：以损定仓计算 (通用公式)                                  |
//| 参数:                                                            |
//|   entry_price: 入场价                                            |
//|   sl_price:    止损价                                            |
//|   risk_mode:   风险模式 (固定金额/百分比)                          |
//|   risk_value:  风险值 (如 100 或 3)                               |
//|                                                                  |
//| 说明：此版本是主使用版本。                                      |
//|      与 GetPositionSize_V1 的功能区别：                          |
//|      1) 通过 CalculateRiskMoney() 统一处理风险金额，使用更规范； |
//|      2) 先校验风险金额、TickSize、TickValue 和止损距离，再计算； |
//|      3) 会输出更完整的 Print 提示，适合作为主流程调用；          |
//|      4) 逻辑更偏“正式版/主流程版”。                               |
//+------------------------------------------------------------------+
double GetPositionSize(double entry_price, double sl_price, ENUM_RISK_MODE risk_mode, double risk_value)
{
   // A. 计算具体的风险金额 (美元)
   double risk_money = CalculateRiskMoney(risk_mode, risk_value);
   
   if (risk_money <= 0) 
   {
      Print("Error: 计算出的风险金额无效 (<=0)");
      return 0;
   }

   // B. 获取市场数据
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);  // 最小跳动点
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE); // 单点价值
   
   if (tick_size == 0 || tick_value == 0)
   {
      Print("Error: 无法获取 TickSize 或 TickValue");
      return 0;
   }

   // C. 计算止损距离 (绝对值)
   double price_diff = MathAbs(entry_price - sl_price);
   
   // 防止止损过小 (例如 0 止损) 导致除零错误
   if (price_diff < tick_size) 
   {
      Print("Error: 止损距离太小，无法计算");
      return 0;
   }

   // D. 核心公式: 手数 = 风险金额 / ( (距离/TickSize) * TickValue )
   double ticks = price_diff / tick_size;
   double raw_lots = risk_money / (ticks * tick_value);

   // E. 修正手数
   return NormalizeLots(raw_lots);
}

//+------------------------------------------------------------------+
//| 单元测试：验证仓位计算的准确性                                      |
//+------------------------------------------------------------------+
void Test_PositionSize_Logic()
{
   Print("========== 开始单元测试: 仓位计算模块 ==========");

   // 模拟场景：XAUUSD
   // 假设：账户 $10,000
   // 假设：TickSize=0.01, TickValue=1.0 (标准黄金合约)
   // 假设：入场 2000.00, 止损 1990.00 (距离 $10)
   
   double entry = 2000.00;
   double sl    = 1990.00;
   
   // --- 测试案例 1: 固定金额 $100 ---
   // 预期: 1手亏$10*100=$1000。 总风险$100。 
   // 预期手数 = 100 / 1000 = 0.1 手
   double lot1 = GetPositionSize(entry, sl, RISK_FIXED_MONEY, 100);
   Print("测试 1 [固定金额 $100]: 预期 0.10, 实际: ", DoubleToString(lot1, 2));
   
   // --- 测试案例 2: 百分比风险 3% ---
   // 账户余额读取的是当前的 AccountInfoDouble(ACCOUNT_BALANCE)，假设为 10000。
   // 预期风险 = 10000 * 3% = $300
   // 预期手数 = 300 / 1000 = 0.3 手
   double lot2 = GetPositionSize(entry, sl, RISK_PERCENTAGE, 3.0);
   Print("测试 2 [百分比 3%]: (基于当前余额 ", AccountInfoDouble(ACCOUNT_BALANCE), ") 实际计算手数: ", DoubleToString(lot2, 2));

   // --- 测试案例 3: 极小止损 (测试 Normalize) ---
   // 止损 $1 (1999.00), 风险 $100
   // 1手亏$100。需要 1.0 手。
   double lot3 = GetPositionSize(entry, 1999.00, RISK_FIXED_MONEY, 100);
   Print("测试 3 [窄止损 $1]: 预期 1.00, 实际: ", DoubleToString(lot3, 2));

   Print("========== 结束单元测试: 仓位计算模块 ==========");
}

//+------------------------------------------------------------------+
//| 辅助函数：根据风险模型计算仓位 (以损定仓核心算法) 这是单独独立出来的函数
//|                                                                  |
//| 说明：此版本是辅助/备份版本。                                   |
//|      与 GetPositionSize 的功能区别：                              |
//|      1) 风险金额计算直接写在函数内部，不依赖 CalculateRiskMoney()； |
//|      2) 只做基础校验，Print 提示较少，属于更轻量的实现；         |
//|      3) 公式与主版本一致，但更偏独立/兼容式调用；                 |
//|      4) 适合做对比测试或临时备份版本。                             |
//+------------------------------------------------------------------+
double GetPositionSize_V1(double entry_price, double sl_price, ENUM_RISK_MODE risk_mode, double risk_val)
{
   // 1. 计算具体的风险金额 (美元)
   double money_to_risk = 0.0;
   
   if (risk_mode == RISK_FIXED_MONEY)
   {
      money_to_risk = risk_val; // 直接使用固定金额，例如 100
   }
   else if (risk_mode == RISK_PERCENTAGE)
   {
      // 账户余额 * 百分比 (输入 3.0 代表 3%)
      money_to_risk = AccountInfoDouble(ACCOUNT_BALANCE) * (risk_val / 100.0);
   }

   // 安全检查
   if (money_to_risk <= 0) return 0;

   // 2. 获取市场数据
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);  // 最小跳动点
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE); // 单点价值

   if (tick_size == 0 || tick_value == 0) return 0;

   // 3. 计算止损距离 (绝对值)
   double price_diff = MathAbs(entry_price - sl_price);
   
   // 防止除以零
   if (price_diff < tick_size) return 0; 

   // 4. 核心公式: 手数 = 风险金额 / ( (距离/TickSize) * TickValue )
   // 计算止损包含多少个 Tick
   double ticks = price_diff / tick_size;
   // 计算手数
   double raw_lots = money_to_risk / (ticks * tick_value);

   // 理论手数低于最小手数时，先检查开最小手数是否会超出目标风险
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if (raw_lots < min_lot)
   {
      double min_lot_risk = ticks * tick_value * min_lot;

      if (min_lot_risk > money_to_risk)
      {
         Print("拒绝开仓 [最小手数风险超标] 品种=", Symbol(),
               " 目标风险=", DoubleToString(money_to_risk, 2),
               " 理论手数=", DoubleToString(raw_lots, 4),
               " 最小手数=", DoubleToString(min_lot, 2),
               " 最小手数实际风险=", DoubleToString(min_lot_risk, 2),
               " 止损距离Ticks=", DoubleToString(ticks, 1));
         return 0;
      }
   }

   return NormalizeLots(raw_lots);
}

// 静默判断目标风险是否可以形成有效手数，供下单前预筛选使用。
bool CanFormPositionSize_V1(double entry_price, double sl_price,
                            ENUM_RISK_MODE risk_mode, double risk_val)
{
   double money_to_risk = 0.0;

   if (risk_mode == RISK_FIXED_MONEY)
      money_to_risk = risk_val;
   else if (risk_mode == RISK_PERCENTAGE)
      money_to_risk = AccountInfoDouble(ACCOUNT_BALANCE) * (risk_val / 100.0);

   if (money_to_risk <= 0.0) return false;

   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double min_lot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   if (tick_size <= 0.0 || tick_value <= 0.0 || min_lot <= 0.0)
      return false;

   double price_diff = MathAbs(entry_price - sl_price);
   if (price_diff < tick_size) return false;

   double ticks = price_diff / tick_size;
   double raw_lots = money_to_risk / (ticks * tick_value);

   if (raw_lots < min_lot)
   {
      double min_lot_risk = ticks * tick_value * min_lot;
      if (min_lot_risk > money_to_risk)
         return false;
   }

   return true;
}