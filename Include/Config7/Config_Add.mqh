//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

/*
//+------------------------------------------------------------------+
//| ✅ K_Logic v3.0 Parameters
//+------------------------------------------------------------------+
input string   __V3_Settings__   = "=== v3.0 智能增强 ===";
input bool     Enable_V3_Logic   = true;         // 是否开启 v3 增强逻辑
input ENUM_SIGNAL_GRADE Min_Alert_Grade = GRADE_B; // 报警最低门槛 (建议 B 或 A)

datetime g_LastAlertTime = 0; // 记录上一次成功报警的K线时间

//+------------------------------------------------------------------+
//| ✅ [新增] 斐波那契绘图过滤器
//+------------------------------------------------------------------+
input bool Show_History_Fibo   = false;  // [开关] 是否显示历史信号的斐波投影 (False=只看当前最新)
input bool Hide_Invalid_Fibo   = true;   // [智能] 是否隐藏已失效(止损)或已完成(止盈)的信号
//+------------------------------------------------------------------+
*/

//+------------------------------------------------------------------+
//| ✅ K_Logic v3.0 Parameters
//+------------------------------------------------------------------+
input string   __V3_Settings__   = "=== v3.0 Smart Logic ===";
input bool     Enable_V3_Logic   = true;         // Enable v3 Logic
input ENUM_SIGNAL_GRADE Min_Alert_Grade = GRADE_B; // Min Alert Grade (Rec. B/A)
input bool     Enable_Rich_Alert = true;         // Show Alert/Notification (avoid dup popups)

datetime g_LastAlertTime = 0; // Last Alert Time (Internal)

//+------------------------------------------------------------------+
//| ✅ [New] Fibonacci Drawing Filters
//+------------------------------------------------------------------+
input bool Show_History_Fibo   = false; // Show History Fibo (False=Latest)
input bool Hide_Invalid_Fibo   = true;  // Auto Hide Invalid/Done Fibo
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ [New] Auto Cleanup For SL-Broken Signal Drawings
//| 与 Show_History_Fibo/Hide_Invalid_Fibo 无关：那两个只控制斐波历史投影的
//| 显示偏好；这个开关控制信号矩形/标注/辅助线本体的自动回收。
//+------------------------------------------------------------------+
input bool Enable_Auto_Cleanup_Invalid_Signals = true; // Auto delete SL-broken signal drawings

//+------------------------------------------------------------------+
//| ✅ Trading Rules Reminder Configuration
//+------------------------------------------------------------------+
input string   __Trading_Rules__      = "=== Trading Rules Display ===";
input bool     Show_Trading_Rules     = false;                      // Display Trading Rules Reminder
input int      Rules_X_Distance       = 10;                        // X-axis offset pixels (Container distance from right edge)
input int      Rules_Y_Distance       = 20;                        // Y-axis offset pixels (Container distance from bottom edge)
input int      Rules_Font_Size        = 8;                         // Font size
input color    Rules_Title_Color      = clrOrangeRed;              // Title color
input color    Rules_Text_Color       = clrYellow;                 // Text color (Black BG recommended: White/Yellow/Cyan)
input string   Rules_Font_Name        = "Arial";                    // Font name (Recommended: Arial or SimSun)
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ Configuration Info Display Settings
//+------------------------------------------------------------------+
input string   __Config_Info__        = "=== Config Info Display ===";
input bool     Show_Config_Info       = false;                      // Display Configuration Info Panel
input int      Config_Info_Corner     = CORNER_RIGHT_LOWER;        // Display Corner (0=RL 1=LL 2=RU 3=LU)
input int      Config_Info_X_Distance = 10;                        // X Distance from Edge (pixels)
input int      Config_Info_Y_Distance = 180;                       // Y Distance from Edge (pixels)
input int      Config_Info_Font_Size  = 8;                         // Font Size
input color    Config_Info_BG_Color   = clrNavy;                   // Background Color
input color    Config_Info_Text_Color = clrAqua;                   // Text Color
//+------------------------------------------------------------------+