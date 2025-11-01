#include <Trade\Trade.mqh>

input double RiskAmount = 2.0; // Risk Per Trade
input bool UsePercent = true; // Treat risk amount as percent of account balance instead of amount
input ENUM_TIMEFRAMES HigherTF = PERIOD_M30; // Higher time frame
input int CandlesToTp = 5; // Candles to take profit

CTrade Trade;
string TradeComment = "TOTORI";
int ADXHandles[];
string SymbolArray[] = {
    // "Boom 500 Index",
    // "Boom 300 Index",
    "Boom 1000 Index",
    // "Crash 500 Index",
    // "Crash 300 Index",
    "Crash 1000 Index"
};

int OnInit()
{
    int count = ArraySize(SymbolArray);

    ArrayResize(ADXHandles, count);

    for (int i = 0; i < count; i++)
    {
        string symbol = SymbolArray[i];

        ADXHandles[i] = iADX(symbol, HigherTF, 14);

        if (ADXHandles[i] == INVALID_HANDLE)
        {
            Print("Error initializing ADX for ", symbol);
            return INIT_FAILED;
        }
    }
    
    Print("Initialization complete");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    for (int i = 0; i < ArraySize(SymbolArray); i++)
    {
        if (ADXHandles[i] != INVALID_HANDLE) IndicatorRelease(ADXHandles[i]);
    }
    
    Print("Indicators released. Deinitialization complete.");
}

int GetTrend(int index)
{
    double values[], plus_values[], minus_values[];

    CopyBuffer(ADXHandles[index], 0, 0, 1, values);
    CopyBuffer(ADXHandles[index], 1, 0, 1, plus_values);
    CopyBuffer(ADXHandles[index], 2, 0, 1, minus_values);

    if (values[0] >= 25)
    {
        if (plus_values[0] > minus_values[0]) return 1;
        if (plus_values[0] < minus_values[0]) return -1;
    }

    return 0;
}

bool CalculateVolume(const double riskAmount, const double entryPrice, const double stopLoss, const string symbol, double &volumes[]) {
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

double GetRisk() {
    if (UsePercent) {
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        return (RiskAmount / 100.0) * accountBalance;
    }

    return RiskAmount;
}

bool IsPositionOpen(ENUM_POSITION_TYPE type, string symbol) {
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetString(POSITION_COMMENT) == TradeComment && PositionGetInteger(POSITION_TYPE) == type && PositionGetString(POSITION_SYMBOL) == symbol)
            return true;
    }

    return false;
}

void ManageTrade() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (!PositionSelectByTicket(PositionGetTicket(i)) || PositionGetString(POSITION_COMMENT) != TradeComment) {
            continue;
        }
        
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        string symbol = PositionGetString(POSITION_SYMBOL);
        double bidPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
        double askPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
        bool isBuyPosition = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

        bool shouldCloseBuyPosition = isBuyPosition && askPrice < entryPrice;
        bool shouldCloseSellPosition = !isBuyPosition && bidPrice > entryPrice;

        if (shouldCloseBuyPosition || shouldCloseSellPosition) {
            Trade.PositionClose(PositionGetTicket(i));
            continue;
        }

        bool hasHitTp = true;

        for (int i = 1; i <= CandlesToTp; i += 1) {
            if (isBuyPosition && iOpen(symbol, PERIOD_M1, i) > iClose(symbol, PERIOD_M1, i)) {
                hasHitTp = false;
            }
            if (!isBuyPosition && iOpen(symbol, PERIOD_M1, i) < iClose(symbol, PERIOD_M1, i)) {
                hasHitTp = false;
            }
        }

        if (hasHitTp) {
            Trade.PositionClose(PositionGetTicket(i));
        }
    }
}

datetime LastMinute = 0;

void OnTick() {
    if (LastMinute != iTime(_Symbol, PERIOD_M1, 0)) {
        LastMinute = iTime(_Symbol, PERIOD_M1, 0);

        ManageTrade();
    }

    for (int i = 0; i < ArraySize(SymbolArray); i++)
    {
        string symbol = SymbolArray[i];
        int trend = GetTrend(i);

        bool isBearishTrend = trend == -1;
        bool isBoom = StringFind(symbol, "Boom") != -1;
        bool lastCandleWasBullish = iOpen(symbol, PERIOD_M1, 1) < iClose(symbol, PERIOD_M1, 1);
        bool noOpenSellPositions = !IsPositionOpen(POSITION_TYPE_SELL, symbol);

        if (
            isBoom &&
            isBearishTrend &&
            lastCandleWasBullish &&
            noOpenSellPositions
        ) {
            double entryPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double stopLoss = iHigh(symbol, PERIOD_M1, 1);
            double volumes[];

            CalculateVolume(GetRisk(), entryPrice, stopLoss, symbol, volumes);

            bool tradeEntered = false;

            for (int j = 0; j < ArraySize(volumes); j += 1) {
                double volume = volumes[j];
                if (Trade.Sell(volume, symbol, 0, 0, 0, TradeComment)) {
                    tradeEntered = true;
                }
            }
            if (tradeEntered)
                SendNotification(TradeComment + " took a sell trade on " + symbol);
        }

        bool isBullishTrend = trend == 1;
        bool isCrash = StringFind(symbol, "Crash") != -1;
        bool lastCandleWasBearish = iOpen(symbol, PERIOD_M1, 1) > iClose(symbol, PERIOD_M1, 1);
        bool noOpenBuyPositions = !IsPositionOpen(POSITION_TYPE_BUY, symbol);

        if (
            isCrash &&
            isBullishTrend &&
            lastCandleWasBearish &&
            noOpenBuyPositions
        ) {
            double entryPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
            double stopLoss = iLow(symbol, PERIOD_M1, 1);
            double volumes[];

            CalculateVolume(GetRisk(), entryPrice, stopLoss, symbol, volumes);

            bool tradeEntered = false;

            for (int j = 0; j < ArraySize(volumes); j += 1) {
                double volume = volumes[j];
                if (Trade.Buy(volume, symbol, 0, 0, 0, TradeComment)) {
                    tradeEntered = true;
                }
            }
            if (tradeEntered)
                SendNotification(TradeComment + " took a buy trade on " + symbol);
        }
    }
}
