// 3_10_25.mq5
#include <Trade\Trade.mqh>

input uint Bias = 0; // Bias, 0 = neutral, 1 = bullish, 2 = bearish
input double MinTradePips = 10.0; // Minimum pips to trade
input double RiskAmount = 4000.0; // Risk amount

string TakenLowHighCombinations[];

CTrade Trade;


int OnInit() {
    return(INIT_SUCCEEDED);
}

void OnTick() {
    if (PositionsTotal() > 0) {
        return;
    }

    double low = GetRecentLow();
    double high = GetRecentHigh();
    double mid = (low + high) / 2;

    DrawHorizontalLine("Recent Low", low, clrRed);
    DrawHorizontalLine("Recent High", high, clrGreen);
    DrawHorizontalLine("Mid", mid, clrBlue);

    if (IsLowHighCombinationTaken(low, high)) {
        return;
    }

    double diffBetweenMidAndHigh = high - mid;
    double diffBetweenMidAndLow = mid - low;

    if (Bias == 1 || Bias == 0) {
        if (diffBetweenMidAndHigh < MinTradePips || SymbolInfoDouble(_Symbol, SYMBOL_BID) > mid) {
            return;
        }

        if (Buy(low, high)) {
            MarkLowHighCombinationAsTaken(low, high);
        }
    } else if (Bias == 2 || Bias == 0) {
        if (diffBetweenMidAndLow < MinTradePips || SymbolInfoDouble(_Symbol, SYMBOL_BID) < mid) {
            return;
        }

        if (Sell(low, high)) {
            MarkLowHighCombinationAsTaken(low, high);
        }
    }

}

bool Buy(double low, double high) {
    double mid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double diffBetweenMidAndHigh = high - mid;
    double sl = mid - diffBetweenMidAndHigh * 3.3;

    double volumes[];
    CalculateVolume(RiskAmount, mid, sl, _Symbol, volumes);

    bool tradeSuccess = false;
    for (int i = 0; i < ArraySize(volumes); i++) {
        bool _tradeSuccess = Trade.Buy(volumes[i], _Symbol, 0, sl, high);
        if (!tradeSuccess) {
            tradeSuccess = _tradeSuccess;
        }
    }

    return tradeSuccess;
}

bool Sell(double low, double high) {
    double mid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double diffBetweenMidAndLow = mid - low;
    double sl = mid + diffBetweenMidAndLow * 3.3;

    double volumes[];
    CalculateVolume(RiskAmount, mid, sl, _Symbol, volumes);

    bool tradeSuccess = false;
    for (int i = 0; i < ArraySize(volumes); i++) {
        bool _tradeSuccess = Trade.Sell(volumes[i], _Symbol, 0, sl, low);
        if (!tradeSuccess) {
            tradeSuccess = _tradeSuccess;
        }
    }

    return tradeSuccess;
}


bool IsLowHighCombinationTaken(double low, double high) {
    for (int i = 0; i < ArraySize(TakenLowHighCombinations); i++) {
        if (TakenLowHighCombinations[i] == DoubleToString(low) + DoubleToString(high)) {
            return true;
        }
    }

    return false;
}

void MarkLowHighCombinationAsTaken(double low, double high) {

    if (IsLowHighCombinationTaken(low, high)) {
        return;
    }

    ArrayResize(TakenLowHighCombinations, ArraySize(TakenLowHighCombinations) + 1);

    TakenLowHighCombinations[ArraySize(TakenLowHighCombinations) - 1] = DoubleToString(low) + DoubleToString(high);
}

double GetRecentLow() {
    double low = DBL_MAX;

    int i = 1;

    do {
        low = MathMin(low, iLow(_Symbol, PERIOD_CURRENT, i));
        i++;
    } while (low > iLow(_Symbol, PERIOD_CURRENT, i));

    return low;
}

double GetRecentHigh() {
    double high = DBL_MIN;

    int i = 1;

    do {
        high = MathMax(high, iHigh(_Symbol, PERIOD_CURRENT, i));
        i++;
    } while (high < iHigh(_Symbol, PERIOD_CURRENT, i));

    return high;
}

void DrawHorizontalLine(string name, double price, color lineColor) {
    if (ObjectFind(0, name) == -1) {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    } else {
        ObjectMove(0, name, 0, 0, price);
    }
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
