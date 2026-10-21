//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ATR 显示快照数据结构（用于函数间传递）                           |
//+------------------------------------------------------------------+
struct AtrDisplaySnapshot
{
    string base_name;
    int atr_period;
    double atr_mult;
    double current_price;
    double atr_value;
    double sl_distance;
    double buy_sl_price;
    double sell_sl_price;
    double yesterday_close;
    double today_open;
    double today_high;
    double today_low;
    int spread;
    int range_points;
    int change_points;
    string change_str;
    int digits;
};