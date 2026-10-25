//+------------------------------------------------------------------+
//|                              KT_Delete_All_Global_Variables.mq4 |
//|                                  Copyright 2026, K-Target System |
//+------------------------------------------------------------------+
#property copyright "K-Target User"
#property version   "1.00"
#property strict
// 旧代码保留：#property show_inputs
// MQL5脚本会自动显示 input 参数，不需要该 MQL4 属性。

//#region MARK: 模块--MQL5转换说明
// MQL5转换：GlobalVariablesDeleteAll() 同样操作当前 MT5 终端级全局变量。
// 注意：全局变量属于终端级数据，不限于当前图表或当前 EA，删除后不可恢复。
//#endregion
input bool Confirm_Delete = true;

//+------------------------------------------------------------------+
//| 脚本程序起始函数                                                 |
//+------------------------------------------------------------------+
void OnStart()
{
   if(Confirm_Delete)
   {
      // 旧代码保留：int result = MessageBox("确定要删除当前 MT4 终端中的全部全局变量吗？\n\n"
      //                              "这会同时删除其他 EA、指标和脚本保存的全局变量，且无法恢复。",
      //                              "清除全部全局变量",
      //                              MB_YESNO | MB_ICONWARNING);
      int result = MessageBox("确定要删除当前 MT5 终端中的全部全局变量吗？\n\n"
                  "这会同时删除其他 EA、指标和脚本保存的全局变量，且无法恢复。",
                              "清除全部全局变量",
                              MB_YESNO | MB_ICONWARNING);

      if(result != IDYES)
      {
         Print("已取消清除全局变量操作。");
         return;
      }
   }

   int deleted_count = GlobalVariablesDeleteAll();

   if(deleted_count >= 0)
   {
      Print("全局变量清除完成，共删除 ", deleted_count, " 个全局变量。");
   }
   else
   {
      Print("清除全局变量失败，错误代码: ", GetLastError());
   }
}
//+------------------------------------------------------------------+