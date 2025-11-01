#include <Trade\Trade.mqh>

input ENUM_TIMEFRAMES TimeFrame = PERIOD_M5;
input double RiskAmount = 10;
input double RR = 3;
input double TargetAmount = 50;
input bool StopAtTargetHit = true;
input bool TakeTradeOnInit = false;

bool canTrade = true;
datetime previousTime;
CTrade trade;
string tradeComment = "JESU KRISTI V3 DERIV";
double startingBalance;
string symbols[] = {
  "Volatility 10 Index",
  "Volatility 50 Index",
  "Volatility 75 Index",
  "Volatility 100 (1s) Index",
  "Volatility 250 (1s) Index",
  "Boom 500 Index",
  "Boom 1000 Index",
  "Crash 500 Index",
  "Crash 1000 Index",
  "Range Break 200 Index",
  "DEX 600 DOWN Index",
  "DEX 900 DOWN Index",
  "Drift Switch Index 20",
};
int MAHandles[];

int OnInit() {
   SendNotification(tradeComment + " Loaded!");
   startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if (!TakeTradeOnInit)
      previousTime = iTime(_Symbol, TimeFrame, 0);

    int count = ArraySize(symbols);

    ArrayResize(MAHandles, count);

    for (int i = 0; i < count; i++)
    {
        string symbol = symbols[i];

        MAHandles[i] = iMA(symbol, TimeFrame, 20, 0, MODE_SMA, PRICE_CLOSE);
    }
   return(INIT_SUCCEEDED);
}

 void OnDeinit(const int reason)
{
    for (int i = 0; i < ArraySize(symbols); i++)
    {
        if (MAHandles[i] != INVALID_HANDLE) IndicatorRelease(MAHandles[i]);
    }
    
    Print("Indicators released. Deinitialization complete.");
}

void ManageTrades()
{
    // for (int i = 0; i <= PositionsTotal(); i += 1) {
    //     if (
    //         PositionGetSymbol(i) != "" &&
    //         PositionGetString(POSITION_COMMENT) == tradeComment &&
    //         PositionGetString(POSITION_SYMBOL) == symbol &&
    //         PositionGetDouble(POSITION_PROFIT) < 0
    //     ) {
    //         trade.PositionClose(PositionGetInteger(POSITION_TICKET));
    //     }
    // }
}

void OnTick() {
    if (canTrade) {
        ManageBalance();
        if (iTime(_Symbol, TimeFrame, 0) != previousTime) {
            previousTime = iTime(_Symbol, TimeFrame, 0);
            SendNotification(tradeComment + " Health Notif!");
            
                for (int i = 0; i < ArraySize(symbols); i += 1) {
                    string symbol = symbols[i];
                    string signal = CheckEntry(symbol, TimeFrame, i);

                    if (signal == "buy" && !IsSymbolInUse(symbol)) {
                        Buy(symbol, TimeFrame);
                    }

                    if (signal == "sell" && !IsSymbolInUse(symbol)) {
                        Sell(symbol, TimeFrame);
                    }
                }
        }
    }
}

void Buy(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates rates[];

    CopyRates(symbol, timeframe, 0, 3, rates);

    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double sl = MathMin(rates[0].low, MathMin(rates[1].low, rates[2].low));
    double tp = price + ((price - sl) * RR);
    double volumes[];
    
    CalculateVolume(RiskAmount, price, sl, symbol, volumes);

    bool tradeSuccessful = false;

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        if(trade.Buy(volume, symbol, price, sl, tp, tradeComment)) tradeSuccessful = true;
    }

    if (tradeSuccessful)
        SendNotification(tradeComment + " took a buy trade on " + symbol);
}

void Sell(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates rates[];

    CopyRates(symbol, timeframe, 0, 3, rates);

    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double sl = MathMax(rates[0].high, MathMax(rates[1].high, rates[2].high));
    double tp = price + ((price - sl) * RR);
    double volumes[];
    
    CalculateVolume(RiskAmount, price, sl, symbol, volumes);
    
    bool tradeSuccessful = false;

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        if(trade.Sell(volume, symbol, price, sl, tp, tradeComment)) tradeSuccessful = true;
    }

    if (tradeSuccessful)
        SendNotification(tradeComment + " took a sell trade on " + symbol);
}

string CheckEntry(string symbol, ENUM_TIMEFRAMES _timeframe, int index) {
    MqlRates rates[];

    CopyRates(symbol, _timeframe, 0, 3, rates);
    ReverseArray(rates);

    string signal = "";
    double movingAverageArray[];
    int movingAverage = iMA(symbol, _timeframe, 20, 0, MODE_SMA, PRICE_CLOSE);

    CopyBuffer(movingAverage, 0, 0, 3, movingAverageArray);
    ReverseArray(movingAverageArray);

    if (rates[1].close > movingAverageArray[1])
        if (rates[2].close < movingAverageArray[2])
            signal = "buy";

    if (rates[1].close < movingAverageArray[1])
        if (rates[2].close > movingAverageArray[2])
            signal = "sell";

    return signal;
}

template<typename T>
void ReverseArray(T &rates[]) {
    int start = 0;
    int end = ArraySize(rates) - 1;
    T temp;

    while (start < end)
    {
        temp = rates[start];
        rates[start] = rates[end];
        rates[end] = temp;

        start++;
        end--;
    }
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
                // volume = MathMax(volumeMin, volume - lotStep);
                volume -= lotStep;
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

void CloseAllPositions() {
    for (int i = 0; i <= PositionsTotal(); i += 1) {
        if (PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == tradeComment) {
            trade.PositionClose(PositionGetInteger(POSITION_TICKET));
        }
    }
    if (_PositionsTotal() > 0) {
        CloseAllPositions();
    }
}

int _PositionsTotal() {
    int count = 0;
    for (int i = 0; i <= PositionsTotal(); i += 1) {
        if (PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == tradeComment) {
            count += 1;
        }
    }

    return count;
}

bool IsSymbolInUse(string symbol) {
    for(int i = 0; i <= PositionsTotal(); i += 1)
    {
        if(PositionGetSymbol(i) == symbol && PositionGetString(POSITION_COMMENT) == tradeComment)
            {
            return true; 
            }
    }

    return false;
}

void ManageBalance() {
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    if (equity - startingBalance >= TargetAmount) {
        CloseAllPositions();
        startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        SendNotification(tradeComment + " Target Hit!");
        if (StopAtTargetHit) {
            canTrade = false;
        }
    }
}
