//+------------------------------------------------------------------+
//|                                                  PsychologicalLevels|
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                       http://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Expert variables                                                 |
//+------------------------------------------------------------------+
input double levelsSize = 100;
input double stopSize = 100.0;
input double RR = 0.5;
input double risk = 400;
bool hasTouchedOrCrossed = false;
double psychologicalLevels[], higherLevel, currentLevel, lowerLevel, point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
int sellAdvice = 0, buyAdvice = 0, rejections = 0;
datetime previousTime;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Get symbol properties
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double hundredPipPoint = point * levelsSize * 10.0;
    double nearestPrice = MathFloor(price / hundredPipPoint) * hundredPipPoint;

    ArrayResize(psychologicalLevels, 20);

    // Calculate psychological levels
    double step = levelsSize * 10.0 * point;

    // Draw horizontal lines for psychological levels
    for (int i = -10; i < 10; i++)
    {
        double level = nearestPrice + i * step;

        ObjectCreate(0, "PsychologicalLevel_" + IntegerToString(i), OBJ_HLINE, 0, 0, level);
        ObjectSetInteger(0, "PsychologicalLevel_" + IntegerToString(i), OBJPROP_COLOR, clrLightGray);
        psychologicalLevels[i + 10] = level;
    }

    // Initialize previous candle data
    previousTime = 0;

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Remove horizontal lines
    for (int i = 0; i < 10; i++)
    {
        ObjectDelete(0, "PsychologicalLevel_" + IntegerToString(i));
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if there's a new candle
    if (iTime(_Symbol, PERIOD_CURRENT, 0) != previousTime)
    {
        // Update previous candle data
        previousTime = iTime(_Symbol, PERIOD_CURRENT, 0);

        MqlRates rates[];

        CopyRates(_Symbol, PERIOD_CURRENT, 1, 2, rates);
        
        // Check for engulfing candle at psychological levels
        if (hasTouchedOrCrossed || buyAdvice >= 1 || sellAdvice >= 1 || MathAbs(rejections) >= 3) {
            int isEngulfing = IsEngulfingCandle();
            long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
            if ((isEngulfing == 1 && buyAdvice >= 1) || buyAdvice > 3 || rejections >= 3)
            {
                trade.PositionClose(_Symbol);
                double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                double stopLoss = currentLevel - stopSize * 10 * point;
                double takeProfit = MathMin(higherLevel, entryPrice + RR * (entryPrice - stopLoss));
                trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, MathAbs(NormalizeDouble(risk/((entryPrice - stopLoss) / point), 2)), entryPrice, stopLoss, takeProfit);
                buyAdvice = 0;
                rejections = 0;
            }
            else if ((isEngulfing == -1 && sellAdvice >= 1) || sellAdvice > 3 || rejections <= -3)
            {
                trade.PositionClose(_Symbol);
                double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double stopLoss = currentLevel + stopSize * 10 * point;
                double takeProfit = MathMax(lowerLevel, entryPrice - RR * (stopLoss - entryPrice)) + spread * point;
                trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, MathAbs(NormalizeDouble(risk/((entryPrice - stopLoss) / point), 2)), entryPrice, stopLoss, takeProfit);
                sellAdvice = 0;
                rejections = 0;
            } else {
                hasTouchedOrCrossed = false;
                Print("Touched but no engulfing");
            }
        }
        buyAdvice--;
        sellAdvice--;
        
        for (int i = -10; i < 10; i++)
        {
            double level = psychologicalLevels[i + 10];
            bool resisting = rates[1].close <= level && rates[1].open <= level && rates[1].high >= level;
            bool supporting = rates[1].open >= level && rates[1].close >= level && rates[1].low <= level;
            bool levelBroken = (rates[1].open >= level && rates[1].close <= level) || (rates[1].close >= level && rates[1].open <= level);
            if (resisting) {
                sellAdvice = MathMax(3, sellAdvice + 3);
            }
            if (supporting) {
                buyAdvice = MathMax(3, buyAdvice + 3);
            }
            if (levelBroken) {
                rejections = 0;
            }
            hasTouchedOrCrossed =  resisting || supporting;
            if (hasTouchedOrCrossed) {
                if (level == currentLevel) {
                    if (resisting) {
                        rejections--;
                    }
                    if (supporting) {
                        rejections++;
                    }
                } else {
                    rejections = 0;
                }
                higherLevel = psychologicalLevels[i + 10 + 1];
                currentLevel = level;
                lowerLevel = psychologicalLevels[i + 10 -1];
                break;
            }
        }
    }
}

// Function to check for engulfing candlestick pattern
int IsEngulfingCandle()
{
    MqlRates prevBar[];

    if (CopyRates(_Symbol, PERIOD_CURRENT, 1, 2, prevBar) != 2)
    {
        Print("Error: Unable to copy price data!");
        return 0;
    }
    
    // Check for bullish engulfing candle
    if (prevBar[0].close < prevBar[0].open && prevBar[1].low < prevBar[0].low && prevBar[1].high > prevBar[0].high)
        return 1;
    
    // Check for bearish engulfing candle
    if (prevBar[0].close > prevBar[0].open && prevBar[1].high > prevBar[0].high && prevBar[1].low < prevBar[0].low)
        return -1;
    
    return 0;
}

//+------------------------------------------------------------------+
//| Returns the next higher timeframe                                |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetNextHigherTimeframe(int currentPeriod)
{
    switch (currentPeriod)
    {
        case PERIOD_M1: return PERIOD_M5;
        case PERIOD_M5: return PERIOD_M15;
        case PERIOD_M15: return PERIOD_M30;
        case PERIOD_M30: return PERIOD_H1;
        case PERIOD_H1: return PERIOD_H4;
        case PERIOD_H4: return PERIOD_D1;
        case PERIOD_D1: return PERIOD_W1;
        case PERIOD_W1: return PERIOD_MN1;
        case PERIOD_MN1: return 0; // No higher timeframe
        default: return 0; // Invalid timeframe
    }
}

//+------------------------------------------------------------------+
//| Returns the general trend direction based on historical prices  |
//| of the next higher timeframe                                    |
//+------------------------------------------------------------------+
int GetNextHigherTimeframeTrendDirection(int candles)
{
    int trendDirection = 0;
    
    // Get the current chart timeframe
    int currentPeriod = Period();
    
    // Get the next higher timeframe
    ENUM_TIMEFRAMES higherTimeframe = GetNextHigherTimeframe(currentPeriod);
    if (higherTimeframe <= 0)
    {
        Print("No higher timeframe available");
        return trendDirection;
    }
    
    // Calculate trend direction based on historical prices
    MqlRates bars[];
    CopyRates(_Symbol, PERIOD_CURRENT, 0, candles, bars);
    if (bars[1].low > bars[candles - 1].low) {
        return 1;
    }

    if (bars[1].high < bars[candles - 1].high) {
        return -1;
    }

    return 0;
}
