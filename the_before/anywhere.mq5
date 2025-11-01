#include <Trade\Trade.mqh>

input double RiskAmount = 20; // Risk Per Trade
input double RR = 2.0; // Risk to reward per trade
input bool UsePercent = false; // Treat risk amount as percent of account balance instead of amount

CTrade Trade;
string TradeComment = "ABOBI";
int LastSignals[];
datetime LastMinutes[];
int ADXHandles[];
string SymbolArray[] = {
    "Boom 500 Index",
    "Boom 300 Index",
    "Boom 1000 Index",
    "Crash 500 Index",
    "Crash 300 Index",
    "Crash 1000 Index"
};
datetime LastHour = 0;

int OnInit()
{
    int count = ArraySize(SymbolArray);

    ArrayResize(ADXHandles, count);
    ArrayResize(LastSignals, count);
    ArrayResize(LastMinutes, count);

    for (int i = 0; i < count; i++)
    {
        string symbol = SymbolArray[i];

        ADXHandles[i] = iADX(symbol, PERIOD_CURRENT, 14);
        LastSignals[i] = 0;
        LastMinutes[i] = iTime(symbol, PERIOD_M1, 0);

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

void ClosePositionsByType(ENUM_POSITION_TYPE type, string symbol) {
    // for(int i = PositionsTotal() - 1; i >= 0; i--) {
    //     if(!PositionSelectByTicket(PositionGetTicket(i)) || PositionGetString(POSITION_COMMENT) != TradeComment || PositionGetInteger(POSITION_TYPE) != type || PositionGetString(POSITION_SYMBOL) != symbol)
    //         continue;
        
    //     Trade.PositionClose(PositionGetTicket(i));
    // }
}

bool IsPositionOpen(ENUM_POSITION_TYPE type, string symbol) {
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetString(POSITION_COMMENT) == TradeComment && PositionGetInteger(POSITION_TYPE) == type && PositionGetString(POSITION_SYMBOL) == symbol)
            return true;
    }

    return false;
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

void ManageTrade() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (!PositionSelectByTicket(PositionGetTicket(i)) || PositionGetString(POSITION_COMMENT) != TradeComment) {
            continue;
        }
        
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double stopLoss = PositionGetDouble(POSITION_SL);
        bool isBuyPosition = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

        double open = iOpen(PositionGetString(POSITION_SYMBOL), PERIOD_CURRENT, 0);
        double high = iHigh(PositionGetString(POSITION_SYMBOL), PERIOD_CURRENT, 0);
        double low = iLow(PositionGetString(POSITION_SYMBOL), PERIOD_CURRENT, 0);

        if (
            isBuyPosition &&
            stopLoss < entryPrice &&
            low > entryPrice &&
            open > low
        ) {
            double newStopLoss = low;
            Trade.PositionModify(PositionGetTicket(i), newStopLoss, PositionGetDouble(POSITION_TP));
        } else if (
            !isBuyPosition &&
            stopLoss > entryPrice &&
            high < entryPrice &&
            open < high
        ) {
            double newStopLoss = high;
            Trade.PositionModify(PositionGetTicket(i), newStopLoss, PositionGetDouble(POSITION_TP));
        }
    }
}

void OnTick() {
    ManageTrade();

    if (LastHour != iTime(_Symbol, PERIOD_H1, 0)) {
        LastHour = iTime(_Symbol, PERIOD_H1, 0);
        SendNotification(TradeComment + " health check!");
    }
    for (int i = 0; i < ArraySize(SymbolArray); i++)
    {
        string symbol = SymbolArray[i];
        if (LastMinutes[i] == iTime(symbol, PERIOD_M1, 0)) continue;

        LastMinutes[i] = iTime(symbol, PERIOD_M1, 0);

        int trend = GetTrend(i);
        
        if (trend == -1) {
            ClosePositionsByType(POSITION_TYPE_BUY, symbol);

            bool lastSignalNotSell = (LastSignals[i] != -1);
            bool isCrashWithoutSell = (StringFind(symbol, "Crash") != -1 && !IsPositionOpen(POSITION_TYPE_SELL, symbol));
            bool isNotBoom = (StringFind(symbol, "Boom") == -1);
            if ((lastSignalNotSell || isCrashWithoutSell) && isNotBoom) {
                double entryPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
                double stopLoss = MathMax(iHigh(symbol, PERIOD_CURRENT, 0), iHigh(symbol, PERIOD_CURRENT, 1));
                double takeProfit = entryPrice - RR * MathAbs(entryPrice - stopLoss);
                double volumes[];

                CalculateVolume(GetRisk(), entryPrice, stopLoss, symbol, volumes);

                bool tradeEntered = false;

                for (int j = 0; j < ArraySize(volumes); j += 1) {
                    double volume = volumes[j];
                    if (Trade.Sell(volume, symbol, entryPrice, stopLoss, takeProfit, TradeComment)) {
                        tradeEntered = true;
                    }
                    LastSignals[i] = -1;
                }
                if (tradeEntered)
                    SendNotification(TradeComment + " took a sell trade on " + symbol);
            }
        } else if (trend == 1) {
            ClosePositionsByType(POSITION_TYPE_SELL, symbol);
    
            bool lastSignalNotBuy = (LastSignals[i] != 1);
            bool isBoomWithoutBuy = (StringFind(symbol, "Boom") != -1 && !IsPositionOpen(POSITION_TYPE_BUY, symbol));
            bool isNotCrash = (StringFind(symbol, "Crash") == -1);
            if ((lastSignalNotBuy || isBoomWithoutBuy) && isNotCrash) {
                double entryPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
                double stopLoss = MathMin(iLow(symbol, PERIOD_CURRENT, 0), iLow(symbol, PERIOD_CURRENT, 1));
                double takeProfit = entryPrice + RR * MathAbs(entryPrice - stopLoss);
                double volumes[];

                CalculateVolume(GetRisk(), entryPrice, stopLoss, symbol, volumes);

                bool tradeEntered = false;
    
                for (int j = 0; j < ArraySize(volumes); j += 1) {
                    double volume = volumes[j];
                    if (Trade.Buy(volume, symbol, entryPrice, stopLoss, takeProfit, TradeComment)) {
                        tradeEntered = true;
                    }
                    LastSignals[i] = 1;
                }

                if (tradeEntered)
                    SendNotification(TradeComment + " took a buy trade on " + symbol);
            }
            
        } else {
            ClosePositionsByType(POSITION_TYPE_BUY, symbol);
            ClosePositionsByType(POSITION_TYPE_SELL, symbol);
            LastSignals[i] = 0;
        }
    }
}