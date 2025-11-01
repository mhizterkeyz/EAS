//+------------------------------------------------------------------+
//|                                                      MyTradingBot|
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property strict

// Support and resistance levels
double resistanceLevel, supportLevel;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    FindSupportResistance();
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, "Resistance");
    ObjectsDeleteAll(0, "Support");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check for engulfing candlestick pattern
    if (IsEngulfingCandle())
    {
        // Place buy or sell order depending on the direction of the engulfing candle
        if (EngulfingCandleDirection() == 1) // Bullish engulfing
        {
            // Place buy order
            PlaceBuyOrder();
        }
        else if (EngulfingCandleDirection() == -1) // Bearish engulfing
        {
            // Place sell order
            PlaceSellOrder();
        }
    }

    // Check for invalidation conditions
    if (IsSupportResistanceInvalidated())
    {
        double res = (resistanceLevel - currentPrice) * 1e4;
    double sus = (currentPrice - supportLevel) * 1e4;
    Print("R", res);
    Print("S", sus);
        // Re-run FindSupportResistance() to recalculate levels
        FindSupportResistance();
    }
}

// Function to find support and resistance levels
void FindSupportResistance()
{
    int bars = 100; // Number of bars to consider for finding levels
    
    double highs[], lows[];
    ArrayResize(highs, bars);
    ArrayResize(lows, bars);
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    
    // Copy historical high and low prices into arrays
    CopyHigh(_Symbol, PERIOD_CURRENT, 0, bars, highs);
    CopyLow(_Symbol, PERIOD_CURRENT, 0, bars, lows);
    
    // Find potential support and resistance levels
    resistanceLevel = highs[ArrayMaximum(highs, 0, 20)]; // Highest high in the last 20 bars
    supportLevel = lows[ArrayMinimum(lows, 0, 20)]; // Lowest low in the last 20 bars
    
    // Mark resistance level
    ObjectCreate(0, "Resistance", OBJ_HLINE, 0, iTime(_Symbol, PERIOD_CURRENT, 0), resistanceLevel);
    ObjectSetInteger(0, "Resistance", OBJPROP_COLOR, clrRed);
    
    // Mark support level
    ObjectCreate(0, "Support", OBJ_HLINE, 0, iTime(_Symbol, PERIOD_CURRENT, 0), supportLevel);
    ObjectSetInteger(0, "Support", OBJPROP_COLOR, clrGreen);
}

bool IsSupportResistanceInvalidated()
{
    // Get the current price
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Check for significant price movement beyond support or resistance
    double priceMovementThreshold = 20.0; // Adjust as needed
    double priceAwayFromLevelThreshold = 100.0; // Adjust as needed
    double res = (resistanceLevel - currentPrice) * 1e4;
    double sus = (currentPrice - supportLevel) * 1e4;

    return (res < 0 && MathAbs(res) > priceMovementThreshold) || res > priceAwayFromLevelThreshold || sus > priceAwayFromLevelThreshold || (sus < 0 && MathAbs(sus) > priceMovementThreshold);
}

// Function to check for engulfing candlestick pattern
bool IsEngulfingCandle()
{
    MqlRates prevBar[], currBar[];
    if (CopyRates(_Symbol, PERIOD_CURRENT, 1, 2, prevBar) != 2 || CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, currBar) != 1)
    {
        Print("Error: Unable to copy price data!");
        return false;
    }
    
    // Check for bullish engulfing candle
    if (prevBar[0].close < prevBar[0].open && currBar[0].close > currBar[0].open && currBar[0].low < prevBar[0].low && currBar[0].high > prevBar[0].high)
        return true;
    
    // Check for bearish engulfing candle
    if (prevBar[0].close > prevBar[0].open && currBar[0].close < currBar[0].open && currBar[0].high > prevBar[0].high && currBar[0].low < prevBar[0].low)
        return true;
    
    return false;
}

// Function to determine the direction of the engulfing candle
int EngulfingCandleDirection()
{
    MqlRates prevBar[], currBar[];
    if (CopyRates(_Symbol, PERIOD_CURRENT, 1, 2, prevBar) != 2 || CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, currBar) != 1)
    {
        Print("Error: Unable to copy price data!");
        return 0; // No engulfing candle
    }
    
    // Check for bullish engulfing candle
    if (currBar[0].close > currBar[0].open && prevBar[0].close < prevBar[0].open)
        return 1;
    
    // Check for bearish engulfing candle
    if (currBar[0].close < currBar[0].open && prevBar[0].close > prevBar[0].open)
        return -1;
    
    return 0; // No engulfing candle
}

// Function to place a buy order
void PlaceBuyOrder()
{
    // Place buy order logic goes here
    // Example:
    // OrderSend(_Symbol, OP_BUY, 0.1, Ask, 3, 0, 0, "Buy order", 0, 0, clrGreen);
}

// Function to place a sell order
void PlaceSellOrder()
{
    // Place sell order logic goes here
    // Example:
    // OrderSend(_Symbol, OP_SELL, 0.1, Bid, 3, 0, 0, "Sell order", 0, 0, clrRed);
}