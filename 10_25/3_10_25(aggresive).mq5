#include <Trade\Trade.mqh>

input uint Bias = 0; // Bias, 0 = neutral, 1 = bullish, 2 = bearish
input double MinTradePips = 10.0; // Minimum pips to trade
input double RiskAmount = 4000.0; // Risk amount

string TakenLowHighCombinations[];

CTrade Trade;


int OnInit() {
    return(INIT_SUCCEEDED);
}

bool ShouldBuy() {
    bool lastCandleIsBullish = iClose(_Symbol, PERIOD_CURRENT, 1) > iOpen(_Symbol, PERIOD_CURRENT, 1);
    bool currentCandleIsBearish = iClose(_Symbol, PERIOD_CURRENT, 0) < iOpen(_Symbol, PERIOD_CURRENT, 0);
    bool magnitudeOfCurrentCandleIsEqualOrGreaterThanMinTradePips = MathAbs(iClose(_Symbol, PERIOD_CURRENT, 0) - iOpen(_Symbol, PERIOD_CURRENT, 0)) >= MinTradePips;
    bool isAShapeKeyLevel = iHigh(_Symbol, PERIOD_CURRENT, 3) < iHigh(_Symbol, PERIOD_CURRENT, 2) && iHigh(_Symbol, PERIOD_CURRENT, 2) < iHigh(_Symbol, PERIOD_CURRENT, 1);

    return lastCandleIsBullish && currentCandleIsBearish && magnitudeOfCurrentCandleIsEqualOrGreaterThanMinTradePips && isAShapeKeyLevel && (Bias == 1 || Bias == 0);
}

bool ShouldSell() {
    bool lastCandleIsBearish = iClose(_Symbol, PERIOD_CURRENT, 1) < iOpen(_Symbol, PERIOD_CURRENT, 1);
    bool currentCandleIsBullish = iClose(_Symbol, PERIOD_CURRENT, 0) > iOpen(_Symbol, PERIOD_CURRENT, 0);
    bool magnitudeOfCurrentCandleIsEqualOrGreaterThanMinTradePips = MathAbs(iClose(_Symbol, PERIOD_CURRENT, 0) - iOpen(_Symbol, PERIOD_CURRENT, 0)) >= MinTradePips;
    bool isVShapeKeyLevel = iLow(_Symbol, PERIOD_CURRENT, 3) > iLow(_Symbol, PERIOD_CURRENT, 2) && iLow(_Symbol, PERIOD_CURRENT, 2) > iLow(_Symbol, PERIOD_CURRENT, 1);

    return lastCandleIsBearish && currentCandleIsBullish && magnitudeOfCurrentCandleIsEqualOrGreaterThanMinTradePips && isVShapeKeyLevel && (Bias == 2 || Bias == 0);
}

void OnTick() {
    if (PositionsTotal() > 0) {
        return;
    }

    if (ShouldBuy()) {

        if (Buy()) {
            // TODO: Mark as taken
        }
    }

     if (ShouldSell()) {

        if (Sell()) {
            // TODO: Mark as taken
        }
    }

}

bool Buy() {
    double tp = iOpen(_Symbol, PERIOD_CURRENT, 0);
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double sl = entryPrice - 3.3 * (tp - entryPrice);

    double volumes[];
    CalculateVolume(RiskAmount, entryPrice, sl, _Symbol, volumes);

    bool tradeSuccess = false;
    for (int i = 0; i < ArraySize(volumes); i++) {
        bool _tradeSuccess = Trade.Buy(volumes[i], _Symbol, 0, sl, tp);
        if (!tradeSuccess) {
            tradeSuccess = _tradeSuccess;
        }
    }

    return tradeSuccess;
}

bool Sell() {
    double tp = iOpen(_Symbol, PERIOD_CURRENT, 0);
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double sl = entryPrice + 3.3 * (entryPrice - tp);

    double volumes[];
    CalculateVolume(RiskAmount, entryPrice, sl, _Symbol, volumes);

    bool tradeSuccess = false;
    for (int i = 0; i < ArraySize(volumes); i++) {
        bool _tradeSuccess = Trade.Sell(volumes[i], _Symbol, 0, sl, tp);
        if (!tradeSuccess) {
            tradeSuccess = _tradeSuccess;
        }
    }

    return tradeSuccess;
}

void CalculateVolume(double riskAmount, double entryPrice, double stopLoss, string symbol, double &volumes[]) {
    double totalProfit = 0.0;
    double volumeMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double volumeMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    int decimalPlaces = GetDecimalPlaces(lotStep);
    
    while (totalProfit < riskAmount) {
        double volume = volumeMin;
        double profit = 0.0;
    
        while (OrderCalcProfit(ORDER_TYPE_BUY, symbol, volume, MathMin(entryPrice, stopLoss), MathMax(entryPrice, stopLoss), profit) && profit < (riskAmount - totalProfit) && volume < volumeMax) {
            volume += lotStep;
        }
        
        if (profit > (riskAmount - totalProfit)) {
            volume = volume - lotStep;
        }

        AddToList(volumes, MathMin(volumeMax, NormalizeDouble(volume, decimalPlaces)));
        totalProfit += profit;
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
