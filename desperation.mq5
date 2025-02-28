#include <Trade\Trade.mqh>

CTrade Trade;
string TradeComment = "PriceActionEA";
datetime lastBarTime = 0; // Store last candle time

double previousSupport = 0;
double previousResistance = 0;
input double RiskPercent = 1.0; // Risk percentage per trade
input double RR = 2.0; // Risk-to-reward ratio

// Function to find key support level
double GetSupport(int lookback) {
    return iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, lookback, 0));
}

// Function to find key resistance level
double GetResistance(int lookback) {
    return iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, lookback, 0));
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

// Function to calculate average volume
double GetAverageVolume(int period) {
    double sumVolume = 0;
    for (int i = 1; i <= period; i++) {
        sumVolume += iVolume(_Symbol, PERIOD_CURRENT, i);
    }
    return sumVolume / period;
}

// Function to detect large volume spikes
bool IsVolumeSpike() {
    double volume = iVolume(_Symbol, PERIOD_CURRENT, 1);
    double avgVolume = GetAverageVolume(20);
    
    if (volume > avgVolume * 1.5) {
        Print("Volume Spike Detected - Volume: ", volume, " | Avg Volume: ", avgVolume);
        return true;
    }
    return false;
}

// Function to detect liquidity grabs with volume confirmation
bool IsLiquidityGrab() {
    double close = iClose(_Symbol, PERIOD_CURRENT, 1);
    double high = iHigh(_Symbol, PERIOD_CURRENT, 1);
    double low = iLow(_Symbol, PERIOD_CURRENT, 1);
    
    bool validGrab = false;
    if (high > previousResistance && close < previousResistance) validGrab = true; // Fakeout above resistance
    if (low < previousSupport && close > previousSupport) validGrab = true; // Fakeout below support
    
    // Confirm liquidity grab with volume spike
    if (validGrab /* && IsVolumeSpike() */) {
        return true;
    }
    return false;
}

// Function to detect market structure (Higher Highs, Higher Lows, Lower Highs, Lower Lows)
string GetMarketStructure(int lookback) {
    double lastHigh = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, lookback, 1));
    double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
    double lastLow = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, lookback, 1));
    double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
    
    if (currentHigh > lastHigh && currentLow > lastLow) return "Uptrend";
    if (currentHigh < lastHigh && currentLow < lastLow) return "Downtrend";
    return "Range";
}

// Function to mark liquidity grab zones
void MarkLiquidityGrab(string name, double price, color lineColor) {
    if (ObjectFind(0, name) == -1) {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
    } else {
        ObjectMove(0, name, 0, 0, price);
    }
}

bool CalculateVolume(const double entryPrice, const double stopLoss, const string symbol, double &volumes[]) {
    double riskAmount = (AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent) / 100.0;
    // Validate input parameters
    if (riskAmount <= 0 || entryPrice <= 0 || symbol == "") {
        Print("Error: Invalid input parameters for volume calculation");
        return false;
    }

    // Retrieve symbol trading constraints
    double volumeMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double volumeMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

    // Validate symbol information
    if (volumeMax <= 0 || lotStep <= 0) {
        Print("Error: Unable to retrieve valid symbol volume constraints");
        return false;
    }

    // Calculate point difference
    double entryPointPrice = MathMin(entryPrice, stopLoss);
    double stopPointPrice = MathMax(entryPrice, stopLoss);
    double pointDifference = MathAbs(entryPointPrice - stopPointPrice);

    // Prevent division by zero
    if (pointDifference == 0) {
        Print("Error: Entry and stop loss prices are identical");
        return false;
    }

    // Reset output array
    ArrayFree(volumes);

    double totalProfit = 0.0;
    int decimalPlaces = GetDecimalPlaces(lotStep);
    int iterationCount = 0;
    
    while (totalProfit < riskAmount) {
        double volume = volumeMin;
        double currentProfit = 0.0;
        
        // Find optimal volume that approaches but doesn't exceed risk amount
        while (true) {
            // Check for potential OrderCalcProfit errors
            if (!OrderCalcProfit(ORDER_TYPE_BUY, symbol, volume, entryPointPrice, stopPointPrice, currentProfit)) {
                Print("Error calculating profit for volume: ", volume);
                break;
            }

            // Check if current volume exceeds remaining risk or max volume
            if (currentProfit > (riskAmount - totalProfit) || volume >= volumeMax) {
                // Step back to previous volume if we've gone too far
                volume = MathMax(volumeMin, volume - lotStep);
                break;
            }

            // Increment volume by lot step
            volume = NormalizeDouble(volume + lotStep, decimalPlaces);
        }

        // Verify profit and volume before adding
        if (currentProfit > 0 && volume >= volumeMin) {
            AddToList(volumes, volume);
            totalProfit += currentProfit;
        } else {
            // If we can't find a suitable volume, exit to prevent infinite loop
            break;
        }

        // Safeguard against potential infinite loop
        iterationCount++;
        if (iterationCount > 100) {
            Print("Warning: Maximum iteration limit reached");
            break;
        }
    }

    return ArraySize(volumes) > 0;
}

// Utility function to add to dynamic array
void AddToList(double &arr[], double value) {
    int size = ArraySize(arr);
    ArrayResize(arr, size + 1);
    arr[size] = value;
}

// Determine decimal places for precise volume normalization
int GetDecimalPlaces(double value) {
    int places = 0;
    while (MathMod(value * MathPow(10, places), 1) != 0 && places < 8) {
        places++;
    }
    return places;
}

// Function to execute trades
void ExecuteTrade(string direction) {
    double volumes[];
    double entryPrice = (direction == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double stopLoss = (direction == "BUY") ? previousSupport : previousResistance;
    double takeProfit = entryPrice + ((entryPrice - stopLoss) * RR * ((direction == "BUY") ? 1 : -1));
    if (!CalculateVolume(entryPrice, stopLoss, _Symbol, volumes)) {
        Print("Error: Unable to calculate volume for trade");
        return;
    }
    double lotSize = volumes[0];
    
    if (lotSize <= 0) return;
    
    if (direction == "BUY") {
        Trade.Buy(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, TradeComment);
    } else {
        Trade.Sell(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, TradeComment);
    }
}

// Function to check open positions
bool HasOpenPosition(string direction) {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (PositionSelect(i)) {
            if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
                PositionGetString(POSITION_COMMENT) == TradeComment &&
                ((direction == "BUY" && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ||
                 (direction == "SELL" && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL))) {
                return true;
            }
        }
    }
    return false;
}

int OnInit()
{
    Print("Price Action EA Initialized");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    ObjectDelete(0, "SupportLine");
    ObjectDelete(0, "ResistanceLine");
    ObjectDelete(0, "LiquidityGrabLine");
    ObjectDelete(0, "MarketStructureText");
    Print("Price Action EA Deinitialized");
}

void OnTick()
{
    int lookback = 50; // Number of candles to scan for support/resistance
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    
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
