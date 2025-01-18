#include <Trade\Trade.mqh>

CTrade Trade;

input ENUM_POSITION_TYPE  OrderType = POSITION_TYPE_BUY;
input double RiskAmount = 100.0;
input double Price = 0.0;
input double SL = 0.0;
input double RR = 2.0;

int OnInit() {
    double TP = Price + RR * (Price - SL);

    if (OrderType == POSITION_TYPE_BUY) {
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        ENUM_ORDER_TYPE _OrderType = currentPrice < Price ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_BUY_LIMIT;
        double volumes[];

        CalculateVolume(RiskAmount, Price, SL, _Symbol, volumes);

        for (int i = 0; i < ArraySize(volumes); i++) {
            double volume = volumes[i];

            if (currentPrice < Price) {
                Trade.BuyStop(volume, Price, _Symbol, SL, TP);
            } else {
                Trade.BuyLimit(volume, Price, _Symbol, SL, TP);
            }
        }
    }

    if (OrderType == POSITION_TYPE_SELL) {
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double volumes[];

        CalculateVolume(RiskAmount, Price, SL, _Symbol, volumes);

        for (int i = 0; i < ArraySize(volumes); i++) {
            double volume = volumes[i];

            if (currentPrice < Price) {
                Trade.SellLimit(volume, Price, _Symbol, SL, TP);
            } else {
                Trade.SellStop(volume, Price, _Symbol, SL, TP);
            }
        }
    }

    return(INIT_SUCCEEDED);
}

void CalculateVolume(double riskAmount, double entryPrice, double stopLoss, string symbol, double &volumes[]) {
    double totalProfit = 0.0;
    double volumeMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double volumeMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    int decimalPlaces = GetDecimalPlaces(lotStep);
    int maxIterations = 1000;
    int iterations = 0;
    
    while (totalProfit < riskAmount && iterations < maxIterations) {
        double volume = volumeMin;
        double profit = 0.0;
        int _maxIterations = 1000;
        int _iterations = 0;

    
        while (OrderCalcProfit(ORDER_TYPE_BUY, symbol, volume, MathMin(entryPrice, stopLoss), MathMax(entryPrice, stopLoss), profit) && profit < (riskAmount - totalProfit) && volume < volumeMax && _iterations < _maxIterations) {
            volume += lotStep;
            _iterations += 1;
        }
        
        if (profit > (riskAmount - totalProfit)) {
            volume = volume - lotStep;
        }

        AddToList(volumes, MathMin(volumeMax, NormalizeDouble(volume, decimalPlaces)));
        totalProfit += profit;
        iterations += 1;
    }
}

int GetDecimalPlaces (double number) {
    int decimalPlaces = 0;
    while (NormalizeDouble(number, decimalPlaces) != number && decimalPlaces < 15) {
        decimalPlaces++;
    }
    return decimalPlaces;
}

template<typename T>
void AddToList(T &list[], T item) {
    ArrayResize(list, ArraySize(list) + 1);
    list[ArraySize(list) - 1] = item;
}