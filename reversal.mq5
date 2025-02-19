#include <Trade\Trade.mqh>

input string Symbols = "XAUUSD,EURJPY"; // Comma-separated list of symbols
input double RiskAmount = 100; // Risk per trade
input bool EnableTrailingStop = false; // Enable/Disable Trailing Stop
input double TrailingStopPoints = 100; // Trailing Stop in Points
input double TrailingStepPoints = 50;   // Trailing Step in Points
input int TradingHoursStart = 7;  // Start hour for trading window
input int TradingHoursEnd = 18;     // End hour for trading window
input double RiskToReward = 3; // Risk to reward per trade

CTrade Trade;
string TradeComment = "ABOBI";
string symbolArray[];
int fastMAHandle[], slowMAHandle[]; // Arrays to hold MA indicator handles
datetime lastDay = 0;
datetime lastHour = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Convert Symbols to an array of symbols
    int count = StringSplit(Symbols, ',', symbolArray);
    if (count <= 0)
    {
        Print("Error splitting symbols");
        return INIT_FAILED;
    }

    // Resize indicator handle arrays
    ArrayResize(fastMAHandle, count);
    ArrayResize(slowMAHandle, count);

    // Initialize moving average indicators
    for (int i = 0; i < count; i++)
    {
        string symbol = symbolArray[i];

        fastMAHandle[i] = iMA(symbol, PERIOD_H1, 50, 0, MODE_SMA, PRICE_CLOSE);
        slowMAHandle[i] = iMA(symbol, PERIOD_H1, 200, 0, MODE_SMA, PRICE_CLOSE);

        if (fastMAHandle[i] == INVALID_HANDLE || slowMAHandle[i] == INVALID_HANDLE)
        {
            Print("Error initializing MAs for ", symbol);
            return INIT_FAILED;
        }
    }

    Print("Initialization complete");
    return INIT_SUCCEEDED;
}

bool inTradingWindow(int startHour, int endHour)
{
    MqlDateTime currentTime;
    TimeToStruct(TimeGMT(), currentTime);

    // Check if the current time is within the trading window
    if (startHour < TradingHoursEnd) {
        return currentTime.hour >= startHour && currentTime.hour <= endHour;
    } else {
        return currentTime.hour >= startHour || currentTime.hour <= endHour;
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release all indicator handles
    for (int i = 0; i < ArraySize(symbolArray); i++)
    {
        if (fastMAHandle[i] != INVALID_HANDLE) 
            IndicatorRelease(fastMAHandle[i]);

        if (slowMAHandle[i] != INVALID_HANDLE) 
            IndicatorRelease(slowMAHandle[i]);
    }
    
    Print("Indicators released. Deinitialization complete.");
}

//+------------------------------------------------------------------+
//| Determine the trend based on moving averages                     |
//+------------------------------------------------------------------+
int GetTrend(string symbol, ENUM_TIMEFRAMES tf,  int index)
{
    // Get the ADX values
   int handle = iADX(symbol, tf, 14);
   double values[], plus_values[], minus_values[];

   CopyBuffer(handle, 0, 0, 1, values);
   CopyBuffer(handle, 1, 0, 1, plus_values);
   CopyBuffer(handle, 2, 0, 1, minus_values);

   Print(symbol, " ADX=", NormalizeDouble(values[0], 2));
   Print(symbol, " ADX_PLUS=", NormalizeDouble(plus_values[0], 2));
   Print(symbol, " ADX_MINUS=", NormalizeDouble(minus_values[0], 2));

   if (NormalizeDouble(values[0], 2) >= 25.0) {
    if (plus_values[0] > minus_values[0]) {
        return 1;
    }

    if (plus_values[0] < minus_values[0]) {
        return -1;
    }
   }
    // double fastMAArray[1];
    // double slowMAArray[1];

    // if (fastMAHandle[index] == INVALID_HANDLE || slowMAHandle[index] == INVALID_HANDLE) return 0;

    // if (CopyBuffer(fastMAHandle[index], 0, 0, 1, fastMAArray) < 1 ||
    //     CopyBuffer(slowMAHandle[index], 0, 0, 1, slowMAArray) < 1) return 0;

    // // Confirming a strong uptrend
    // if (fastMAArray[0] > slowMAArray[0])  
    //     return 1;  // Uptrend

    // // Confirming a strong downtrend
    // if (fastMAArray[0] < slowMAArray[0])  
    //     return -1; // Downtrend

    return 0;  // No trend
}

//+------------------------------------------------------------------+
//| Determine potential trade signals                                |
//+------------------------------------------------------------------+
int GetSignal(string symbol, ENUM_TIMEFRAMES tf)
{
    if (iLow(symbol, tf, 5) > iLow(symbol, tf, 4) &&
        iLow(symbol, tf, 4) > iLow(symbol, tf, 3) &&
        iLow(symbol, tf, 3) < iLow(symbol, tf, 2) &&
        iLow(symbol, tf, 2) < iLow(symbol, tf, 1))
    {
        return 1; // Buy
    }

    if (iHigh(symbol, tf, 5) < iHigh(symbol, tf, 4) &&
        iHigh(symbol, tf, 4) < iHigh(symbol, tf, 3) &&
        iHigh(symbol, tf, 3) > iHigh(symbol, tf, 2) &&
        iHigh(symbol, tf, 2) > iHigh(symbol, tf, 1))
    {
        return -1; // Sell
    }

    return 0; // No signal
}

//+------------------------------------------------------------------+
//| Volume calculation logic                                         |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Function to check if the market is trending                      |
//+------------------------------------------------------------------+
bool IsMarketTrending(string symbol, ENUM_TIMEFRAMES tf)
{
    return true;

   // Get the ADX values
   int handle = iADX(symbol, tf, 14);
   double values[];

   CopyBuffer(handle, 0, 0, 1, values);

   Print(symbol, " ADX=", NormalizeDouble(values[0], 2));

   return NormalizeDouble(values[0], 2) >= 25.0;
}

void TrailStopLoss() {
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(!PositionSelectByTicket(PositionGetTicket(i)) || PositionGetString(POSITION_COMMENT) != TradeComment)
            continue;
            
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double takeProfit = PositionGetDouble(POSITION_TP);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentPrice;
        
        // Get current price based on position type
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            currentPrice = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_ASK);
        else
            currentPrice = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_BID);
            
        // Calculate price movement percentage
        double totalDistance = MathAbs(takeProfit - entryPrice);
        double currentDistance;
        
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            currentDistance = currentPrice - entryPrice;
        } else {
            currentDistance = entryPrice - currentPrice;
        }
        
        double progressPercent = (currentDistance / totalDistance) * 100;
        
        // Only proceed if we've moved at least 50% towards TP
        if(progressPercent >= 50) {
            // Calculate how many 10% segments we've moved beyond 50%
            double segmentsCompleted = MathFloor((progressPercent - 50) / 10);
            
            // Calculate new stop loss position (10% of total distance)
            double slDistance = totalDistance * 0.10;
            double newSL;
            
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                newSL = entryPrice + (slDistance * segmentsCompleted);
                // Only modify if new SL is higher than current SL
                if(newSL > currentSL) {
                    if(!Trade.PositionModify(PositionGetTicket(i), newSL, takeProfit)) {
                        Print("Error modifying position: ", GetLastError());
                    }
                }
            } else {
                newSL = entryPrice - (slDistance * segmentsCompleted);
                // Only modify if new SL is lower than current SL
                if(newSL < currentSL || currentSL == 0) {
                    if(!Trade.PositionModify(PositionGetTicket(i), newSL, takeProfit)) {
                        Print("Error modifying position: ", GetLastError());
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Main execution logic on tick update                              |
//+------------------------------------------------------------------+
void OnTick()
{
    TrailStopLoss();
    datetime currentDay = iTime(_Symbol, PERIOD_D1, 0);

    if (lastDay == currentDay) return;

    datetime currentHour = iTime(_Symbol, PERIOD_H1, 0);

    if (!inTradingWindow(TradingHoursStart, TradingHoursEnd)) return;

    if (lastHour == currentHour) return;
    lastHour = currentHour;

    for (int i = 0; i < ArraySize(symbolArray); i++)
    {
        string symbol = symbolArray[i];

        if (Bars(symbol, PERIOD_H1) < 4) continue;

        if (!IsMarketTrending(symbol, PERIOD_H1)) continue;

        int trend = GetTrend(symbol, PERIOD_H1, i);
        int signal = GetSignal(symbol, PERIOD_H1);

        if (signal == 1 && trend == 1) 
        {
            double entryPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double stopLoss = iLow(symbol, PERIOD_H1, 3);
            double takeProfit = entryPrice + (RiskToReward * (entryPrice - stopLoss));
            double volumes[];
            CalculateVolume(RiskAmount, entryPrice, stopLoss, symbol, volumes);


            Print("Placing BUY on ", symbol, " volume count ", ArraySize(volumes));

            for (int i = 0; i < ArraySize(volumes); i += 1) {
                double lotSize = volumes[i];
                if (Trade.Buy(lotSize, symbol, entryPrice, stopLoss, takeProfit, TradeComment)) {
                    lastDay = currentDay;
                }
            }
            // double entryPrice = iLow(symbol, PERIOD_H1, 3);
            // double stopLoss = entryPrice + (SymbolInfoDouble(symbol, SYMBOL_ASK) - iLow(symbol, PERIOD_H1, 3));
            // double takeProfit = entryPrice - (RiskToReward * (stopLoss - entryPrice));
            // double volumes[];
            // CalculateVolume(RiskAmount, entryPrice, stopLoss, symbol, volumes);


            // Print("Placing SELL_STOP on ", symbol);

            // for (int i = 0; i < ArraySize(volumes); i += 1) {
            //     double lotSize = volumes[i];
            //     if (Trade.SellStop(lotSize, entryPrice, symbol, stopLoss, takeProfit, 0, 0, TradeComment)) {
            //         lastDay = currentDay;
            //     }
            // }
        }

        if (signal == -1 && trend == -1) 
        {
            double entryPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
            double stopLoss = iHigh(symbol, PERIOD_H1, 3);
            double takeProfit = entryPrice - (RiskToReward * (stopLoss - entryPrice));
            double volumes[];
            CalculateVolume(RiskAmount, entryPrice, stopLoss, symbol, volumes);


            Print("Placing SELL on ", symbol);
            for (int i = 0; i < ArraySize(volumes); i += 1) {
                double lotSize = volumes[i];
                if (Trade.Sell(lotSize, symbol, entryPrice, stopLoss, takeProfit, TradeComment)) {
                    lastDay = currentDay;
                }
            }

            // double entryPrice = iHigh(symbol, PERIOD_H1, 3);
            // double stopLoss = entryPrice - (iHigh(symbol, PERIOD_H1, 3) - SymbolInfoDouble(symbol, SYMBOL_BID));
            // double takeProfit = entryPrice + (RiskToReward * (entryPrice - stopLoss));
            // double volumes[];
            // CalculateVolume(RiskAmount, entryPrice, stopLoss, symbol, volumes);


            // Print("Placing BUY_STOP on ", symbol);

            // for (int i = 0; i < ArraySize(volumes); i += 1) {
            //     double lotSize = volumes[i];
            //     if (Trade.BuyStop(lotSize, entryPrice, symbol, stopLoss, takeProfit, 0, 0, TradeComment)) {
            //         lastDay = currentDay;
            //     }
            // }
        }
    }
}
