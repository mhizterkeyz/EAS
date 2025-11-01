#include <Trade\Trade.mqh>

input double RiskAmount = 100; // Risk amount per trade
input double RR = 20;           // Risk to reward ratio
string TradeComment = "Delta Strategy EA";

CTrade Trade;

int OnInit() {
    SendNotification(TradeComment + " Loaded!");
    return(INIT_SUCCEEDED);
}

// Function to check if the last candle is bullish
bool IsLastCandleBullish() {
    double lastCandleOpen = iOpen(_Symbol, PERIOD_M1, 1);
    double lastCandleClose = iClose(_Symbol, PERIOD_M1, 1);
    return lastCandleClose > lastCandleOpen;
}

// Function to find the index of the last bearish candle
int FindLastBearishCandleIndex() {
    int lastBearishIndex = -1; // Initialize to -1 to indicate no bearish candle found
    for (int i = 2; i < 1000; i++) { // Increased limit to 1000
        double currentCandleOpen = iOpen(_Symbol, PERIOD_M1, i);
        double currentCandleClose = iClose(_Symbol, PERIOD_M1, i);
        if (currentCandleClose < currentCandleOpen) {
            lastBearishIndex = i; // Update the index of the last bearish candle
        } else {
            break;
        }
    }
    return lastBearishIndex; // Return the index of the last bearish candle found, or -1 if none
}

// Function to calculate deltas
void CalculateDeltas(int bearishCandleIndex, double &bearishTrendDelta, double &bullishCandleDelta) {
    double highOfBearishCandle = iHigh(_Symbol, PERIOD_M1, bearishCandleIndex);
    double lowOfCandleAtIndex2 = iLow(_Symbol, PERIOD_M1, 2);
    bearishTrendDelta = highOfBearishCandle - lowOfCandleAtIndex2;

    double highOfBullishCandle = iHigh(_Symbol, PERIOD_M1, 1);
    double lowOfBullishCandle = iLow(_Symbol, PERIOD_M1, 1);
    bullishCandleDelta = highOfBullishCandle - lowOfBullishCandle;
}

// Function to calculate volume based on risk amount, entry price, and stop loss
void CalculateVolume(double riskAmount, double entryPrice, double stopLoss, string symbol, double &volumes[]) {
    double totalProfit = 0.0;
    double volumeMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double volumeMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    int decimalPlaces = GetDecimalPlaces(lotStep);
    int maxIterations = 1000;
    
    // Ensure volumes array is cleared before use
    ArrayResize(volumes, 0);

    for (int iterations = 0; totalProfit < riskAmount && iterations < maxIterations; iterations++) {
        double volume = volumeMin;
        double profit = 0.0;
        int _iterations = 0;

        // Calculate profit for increasing volume
        while (true) {
            // Calculate potential profit for the current volume
            if (!OrderCalcProfit(ORDER_TYPE_BUY, symbol, volume, MathMin(entryPrice, stopLoss), MathMax(entryPrice, stopLoss), profit) || 
                profit >= (riskAmount - totalProfit) || 
                volume >= volumeMax || 
                _iterations >= maxIterations) {
                break; // Exit if any condition is not met
            }
            volume += lotStep; // Increase volume by lot step
            _iterations++;
        }

        // Adjust volume if profit exceeds the risk amount
        if (profit > (riskAmount - totalProfit)) {
            volume -= lotStep; // Reduce volume to stay within risk
        }

        // Normalize and add the calculated volume to the list
        double finalVolume = MathMin(volumeMax, NormalizeDouble(volume, decimalPlaces));
        AddToList(volumes, finalVolume);
        totalProfit += profit; // Update total profit
    }
}

int GetDecimalPlaces (double number) {
    int decimalPlaces = 0;
    while (NormalizeDouble(number, decimalPlaces) != number && decimalPlaces < 15) {
        decimalPlaces += 1;
    }

    return decimalPlaces;
}

template<typename T>
void AddToList(T &list[], T item) {
    ArrayResize(list, ArraySize(list) + 1);
    list[ArraySize(list) - 1] = item;
}

// Function to execute a buy trade
void ExecuteBuyTrade(double stopLoss, double takeProfit) {
    if (RiskAmount <= 0) {
        Print("Risk amount must be greater than zero.");
        return;
    }

    double volumes[]; // Declare the volumes array
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID); // Get the current ask price for entry
    double risk = RiskAmount; // Assuming RiskAmount is the amount you are willing to risk

    // Calculate the volume based on the risk amount, entry price, and stop loss
    CalculateVolume(risk, entryPrice, stopLoss, _Symbol, volumes);

    // Check if we have a valid volume
    if (ArraySize(volumes) == 0) {
        Print("Failed to calculate volume.");
        return;
    }

    // Execute the buy trade with the calculated volume
    if (Trade.Buy(volumes[0], _Symbol, entryPrice, stopLoss, takeProfit, TradeComment)) {
        Print("Buy trade executed with SL: ", stopLoss, " and TP: ", takeProfit);
    } else {
        Print("Failed to execute buy trade. Error: ", GetLastError());
    }
}

void OnTick() {
    if (PositionsTotal() == 0 && IsLastCandleBullish()) {
        int lastBearishIndex = FindLastBearishCandleIndex();

        if (lastBearishIndex == -1) {
            Print("No bearish candles found before the bullish candle.");
        } else {
            Print("First bearish candle at index: ", lastBearishIndex);
            double bearishTrendDelta = 0.0;
            double bullishCandleDelta = 0.0;

            CalculateDeltas(lastBearishIndex, bearishTrendDelta, bullishCandleDelta);

            Print("Bearish trend delta: ", bearishTrendDelta);
            Print("Bullish candle delta: ", bullishCandleDelta);

            // Check if delta of bullish candle is >= 50% of delta of bearish trend
            if (bullishCandleDelta >= 0.5 * bearishTrendDelta) {
                double lowOfBullishCandle = iLow(_Symbol, PERIOD_M1, 1);
                double highOfBullishCandle = iHigh(_Symbol, PERIOD_M1, 1);
                double stopLoss = lowOfBullishCandle; // Stop loss at low of candle at index 1
                double takeProfit = highOfBullishCandle + (bullishCandleDelta * RR); // Calculate take profit based on RR

                ExecuteBuyTrade(stopLoss, takeProfit);
            }
        }
    }
}
