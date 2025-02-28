#include <Trade\Trade.mqh>

CTrade Trade;
string TradeComment = "GYAAAT";
string SymbolArray[] = {
    "Volatility 75 Index",
};
datetime LastHigherTFBarTime = 0;

ENUM_TIMEFRAMES GetHigherTimeframe(ENUM_TIMEFRAMES lowerTimeframe) {
    if (lowerTimeframe == PERIOD_CURRENT) {
        lowerTimeframe = (ENUM_TIMEFRAMES)ChartPeriod(0);
    }

    switch (lowerTimeframe) {
        case PERIOD_M1:   return PERIOD_M30;  // M1 → M15
        case PERIOD_M5:   return PERIOD_H4;  // M5 → M30
        case PERIOD_M15:  return PERIOD_H4;   // M15 → H1
        case PERIOD_M30:  return PERIOD_H4;   // M30 → H4
        case PERIOD_H1:   return PERIOD_D1;   // H1 → D1
        case PERIOD_H4:   return PERIOD_W1;   // H4 → W1
        case PERIOD_D1:   return PERIOD_MN1;  // D1 → MN1
        default:          return lowerTimeframe;
    }
}

// Function to find key support level
double GetSupport(int lookback, string symbol, ENUM_TIMEFRAMES timeframe) {
    return iLow(symbol, timeframe, iLowest(symbol, timeframe, MODE_LOW, lookback, 0));
}

// Function to find key resistance level
double GetResistance(int lookback, string symbol, ENUM_TIMEFRAMES timeframe) {
    return iHigh(symbol, timeframe, iHighest(symbol, timeframe, MODE_HIGH, lookback, 0));
}

// Function to draw horizontal lines
void DrawHorizontalLine(string name, double price, color lineColor) {
    if (ObjectFind(0, name) == -1) {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    } else {
        ObjectMove(0, name, 0, 0, price);
    }
}

int OnInit()
{
    return INIT_SUCCEEDED;
}

void OnTick()
{
    int lookback = 50; // Number of candles to scan for support/resistance
    datetime LastHigherTFBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    ENUM_TIMEFRAMES higherTimeframe = GetHigherTimeframe(PERIOD_CURRENT);
    int count = ArraySize(SymbolArray);
    
    for (int i = 0; i < count; i++) {
        string symbol = SymbolArray[i];
        double support = GetSupport(lookback, symbol, higherTimeframe);
        double resistance = GetResistance(lookback, symbol, higherTimeframe);
        DrawHorizontalLine("SupportLine", support, clrGreen);
        DrawHorizontalLine("ResistanceLine", resistance, clrRed);
    }

    
    // Only update support & resistance when a new candle forms
    if (currentBarTime != lastBarTime) {
        lastBarTime = currentBarTime;
        
        // Store previous support and resistance before updating
        previousSupport = ObjectGetDouble(0, "SupportLine", OBJPROP_PRICE);
        previousResistance = ObjectGetDouble(0, "ResistanceLine", OBJPROP_PRICE);
        
        double support = GetSupport(lookback);
        double resistance = GetResistance(lookback);

        // Draw fixed support and resistance lines
        DrawHorizontalLine("SupportLine", support, clrGreen);
        DrawHorizontalLine("ResistanceLine", resistance, clrRed);
    }

    // Detect and mark liquidity grabs using stored levels
    if (IsLiquidityGrab()) {
        double lastClose = iClose(_Symbol, PERIOD_CURRENT, 1);
        MarkLiquidityGrab("LiquidityGrabLine", lastClose, clrBlue);
        Print("Liquidity Grab Detected at: ", lastClose, " with High Volume Confirmation");
    }
    
    // Detect and display market structure
    string marketStructure = GetMarketStructure(lookback);
    Comment("Market Structure: " + marketStructure);

    if (marketStructure == "Uptrend" && IsLiquidityGrab() && !HasOpenPosition("BUY")) {
        ExecuteTrade("BUY");
    }
    if (marketStructure == "Downtrend" && IsLiquidityGrab() && !HasOpenPosition("SELL")) {
        ExecuteTrade("SELL");
    }
}
