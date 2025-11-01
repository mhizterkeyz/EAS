#include <Trade\Trade.mqh>

datetime dailyTime = 0;
double keyLevelsShapeA[];
double keyLevelsShapeB[];

void GetDailyKeyLevels(int lookBack = 1003)
{
    ENUM_TIMEFRAMES timeFrame = PERIOD_D1;
    if (iTime(_Symbol, timeFrame, 0) == dailyTime) return;
    
    dailyTime = iTime(_Symbol, timeFrame, 0);

    double allowance = 0.10;
    
    for (int i = 2; i <= lookBack; i++)
    {
        // A shape key level
        if (
            MathAbs(iClose(_Symbol, timeFrame, i + 1) - iOpen(_Symbol, timeFrame, i)) <= allowance  &&
            iHigh(_Symbol, timeFrame, i + 2) < iClose(_Symbol, timeFrame, i + 1) &&
            iHigh(_Symbol, timeFrame, i - 1) < iOpen(_Symbol, timeFrame, i)
        ) {
            ArrayResize(keyLevelsShapeA, ArraySize(keyLevelsShapeA) + 1);
            keyLevelsShapeA[ArraySize(keyLevelsShapeA) - 1] = iOpen(_Symbol, timeFrame, i);
        }
        
        // V shape key level
        if (
            MathAbs(iClose(_Symbol, timeFrame, i + 1) == iOpen(_Symbol, timeFrame, i)) <= allowance  &&
            iLow(_Symbol, timeFrame, i + 2) > iClose(_Symbol, timeFrame, i + 1) &&
            iLow(_Symbol, timeFrame, i - 1) > iOpen(_Symbol, timeFrame, i)
        ) {
            ArrayResize(keyLevelsShapeB, ArraySize(keyLevelsShapeB) + 1);
            keyLevelsShapeB[ArraySize(keyLevelsShapeB) - 1] = iOpen(_Symbol, timeFrame, i);
        }
    }

    DrawKeyLevelLines();
}

double nearestKeyLevelAbove;
double nearestKeyLevelBelow;

void DrawKeyLevelLines()
{
    string symbol = _Symbol;
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID); // Use BID price as reference

    // Variables to store the closest key levels
    nearestKeyLevelAbove = DBL_MAX;
    nearestKeyLevelBelow = -DBL_MAX;
    
    // Find the closest key levels above and below
    for (int i = 0; i < ArraySize(keyLevelsShapeA); i++)
    {
        double level = keyLevelsShapeA[i];
        if (level > currentPrice && level < nearestKeyLevelAbove)
            nearestKeyLevelAbove = level;
        if (level < currentPrice && level > nearestKeyLevelBelow)
            nearestKeyLevelBelow = level;
    }

    for (int i = 0; i < ArraySize(keyLevelsShapeB); i++)
    {
        double level = keyLevelsShapeB[i];
        if (level > currentPrice && level < nearestKeyLevelAbove)
            nearestKeyLevelAbove = level;
        if (level < currentPrice && level > nearestKeyLevelBelow)
            nearestKeyLevelBelow = level;
    }

    // Remove all previous key level lines
    int totalObjects = ObjectsTotal(0);
    string prefix = "KeyLevel_";
    
    for (int i = totalObjects - 1; i >= 0; i--)
    {
        string objectName = ObjectName(0, i);
        if (StringFind(objectName, prefix) == 0) // Ensure it's a key level object
        {
            ObjectDelete(0, objectName);
        }
    }

    // Draw only the closest key levels
    if (nearestKeyLevelAbove != DBL_MAX)
        DrawHorizontalLine(prefix + "Above", nearestKeyLevelAbove, clrRed);

    if (nearestKeyLevelBelow != -DBL_MAX)
        DrawHorizontalLine(prefix + "Below", nearestKeyLevelBelow, clrBlue);
}

// Helper function to create a horizontal line
void DrawHorizontalLine(string name, double price, color lineColor)
{
    if (!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
    {
        Print("Error creating horizontal line: ", name);
        return;
    }

    ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
}

int GetPriceRejection()
{
    ENUM_TIMEFRAMES timeFrame = PERIOD_D1;

    // Get current and previous candle data
    double open  = iOpen(_Symbol, timeFrame, 0);
    double high  = iHigh(_Symbol, timeFrame, 0);
    double low   = iLow(_Symbol, timeFrame, 0);
    double close = iClose(_Symbol, timeFrame, 0);

    if (
        (high >= nearestKeyLevelAbove && close < nearestKeyLevelAbove && open < nearestKeyLevelAbove) ||
        (high >= nearestKeyLevelBelow && close < nearestKeyLevelBelow && open < nearestKeyLevelBelow)
    ) return -1;

    if (
        (low <= nearestKeyLevelAbove && close > nearestKeyLevelAbove && open > nearestKeyLevelAbove) ||
        (low <= nearestKeyLevelBelow && close > nearestKeyLevelBelow && open > nearestKeyLevelBelow)
    ) return 1;
    
    return 0;
}

struct FVG
{
    double high;
    double low;
    double gapPrice1;
    double gapPrice2;
    int type;
    datetime time;
};

bool FindClosestFVG(double upperPrice, double lowerPrice, datetime startDate, FVG &foundFVG)
{
    ENUM_TIMEFRAMES timeFrame = PERIOD_M30;
    int bars = iBars(_Symbol, timeFrame);

    FVG closestFVG;
    bool fvgFound = false;
    double minDistance = DBL_MAX;
    datetime latestTime = 0;

    for (int i = 1; i < bars; i++) 
    {
        datetime candleTime = iTime(_Symbol, timeFrame, i);
        if (candleTime < startDate) break; // Stop when reaching start date

        double low2 = iLow(_Symbol, timeFrame, i + 2);
        double high1 = iHigh(_Symbol, timeFrame, i);
        double high2 = iHigh(_Symbol, timeFrame, i + 2);
        double low1 = iLow(_Symbol, timeFrame, i);

        double fvgHigh, fvgLow, fvgGapPrice1, fvgGapPrice2;
        int fvgType;

        if (high2 < low1) // Bullish FVG
        {
            fvgHigh = high1;
            fvgLow = low2;
            fvgGapPrice1 = low1;
            fvgGapPrice2 = high2;
            fvgType = 1;
        }
        else if (low2 > high1) // Bearish FVG
        {
            fvgHigh = high2;
            fvgLow = low1;
            fvgGapPrice1 = high1;
            fvgGapPrice2 = low2;
            fvgType = -1;
        }
        else continue; // No FVG

        if (fvgHigh >= lowerPrice && fvgLow <= upperPrice) // FVG within range
        {
            if (fvgType == 1)
            {
                DrawFVGBox("BUY_FVG_BOX", low1, high2, iTime(_Symbol, timeFrame, i + 2), clrGreen);
            }
            
            if (fvgType == -1)
            {
                DrawFVGBox("SELL_FVG_BOX", low2, high1, iTime(_Symbol, timeFrame, i + 2), clrRed);
            }
            return true;
            // double midFVG = (fvgHigh + fvgLow) / 2;
            // double distance = MathAbs(midFVG - ((upperPrice + lowerPrice) / 2));

            // if (distance < minDistance || (distance == minDistance && candleTime > latestTime))
            // {
            //     minDistance = distance;
            //     latestTime = candleTime;
            //     closestFVG.high = fvgHigh;
            //     closestFVG.low = fvgLow;
            //     closestFVG.time = candleTime;
            //     fvgFound = true;
            // }
        }
    }

    if (fvgFound)
    {
        foundFVG = closestFVG;
        return true;
    }

    return false;
}

void DrawFVGBox(string name, double upperPrice, double lowerPrice, datetime startTime, color boxColor)
{
    ENUM_TIMEFRAMES timeFrame = PERIOD_M30;
    
    datetime endTime = startTime + 7200;

    // Ensure the object doesn't already exist
    if (ObjectFind(0, name) >= 0) ObjectDelete(0, name);

    // Create the rectangle object
    if (!ObjectCreate(0, name, OBJ_RECTANGLE, 0, startTime, upperPrice, endTime, lowerPrice))
    {
        Print("Error creating rectangle: ", name);
        return;
    }

    // Set rectangle properties
    ObjectSetInteger(0, name, OBJPROP_COLOR, boxColor);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
}


int OnInit()
{
    return INIT_SUCCEEDED;
}

datetime last30M = 0;

void OnTick()
{
    GetDailyKeyLevels();

    if (last30M == iTime(_Symbol, PERIOD_M30, 0)) return;

    last30M = iTime(_Symbol, PERIOD_M30, 0);

    int priceRejection = GetPriceRejection();

    Comment("Price rejecting: " + (string)priceRejection);
    
    if (priceRejection == 0) return;

    FVG foundFVG;

    FindClosestFVG(nearestKeyLevelAbove, nearestKeyLevelBelow, iTime(_Symbol, PERIOD_D1, 0), foundFVG);
}
