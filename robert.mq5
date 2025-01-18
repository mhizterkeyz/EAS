#include <Trade\Trade.mqh>

CTrade Trade;

input string Symbols = "Volatility 75 Index";
input ENUM_TIMEFRAMES TimeFrame = PERIOD_H4;
input double RR = 2;
input double RiskAmount = 100;

string TradeComment = "GOD NAHHHHH. TILL I CRY?";
string _Symbols[];
datetime TimeTracker;

int OnInit() {
    StringSplit(Symbols, ',', _Symbols);

    SendNotification(TradeComment + " Loaded!");

   return (INIT_SUCCEEDED);
}

void OnTick() {
    if (iTime(_Symbol, TimeFrame, 0) != TimeTracker) {
        TimeTracker = iTime(_Symbol, TimeFrame, 0);

        for (int i = 0; i < ArraySize(_Symbols); i += 1) {
            string symbol = _Symbols[i];
            string entry = CheckEntry(symbol, TimeFrame);

            if (entry == "buy")
                Buy(symbol, TimeFrame);

            if (entry == "sell")
                Sell(symbol, TimeFrame);
        }
    }
}

MqlRates GetLastCandle(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates rates[];

    CopyRates(symbol, timeframe, 1, 1, rates);

    return rates[0];
}

string CheckEntry(string symbol, ENUM_TIMEFRAMES timeframe) {
    string entry = "";
    MqlRates candles[];
    
    CopyRates(symbol, timeframe, 1, 3, candles);

    bool isBullish = candles[2].open < candles[2].close;
    double magnitude = 0.7 * (candles[2].high - candles[2].low);
    

    if (
        isBullish &&
        candles[0].close == candles[1].open &&
        candles[2].low < candles[1].open &&
        candles[2].open > candles[1].open &&
        candles[2].open - candles[2].low >= magnitude
    ) {
        entry = "buy";
    }

    if (
        !isBullish &&
        candles[0].close == candles[1].open &&
        candles[2].high > candles[1].open &&
        candles[2].open < candles[1].open &&
        candles[2].high - candles[2].open >= magnitude
    ) {
        entry = "sell";
    }


    return entry;
}

void Buy(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates lastCandle = GetLastCandle(symbol, timeframe);
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double sl = MathMin(lastCandle.open, price - (lastCandle.close - lastCandle.open));
    double tp = price + (price - sl) * RR;
    double volumes[];
    double risk = GetRisk();

    CalculateVolume(risk, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        Trade.Buy(volume, symbol, price, sl, tp, TradeComment);
    }
}

void Sell(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates lastCandle = GetLastCandle(symbol, timeframe);
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double sl = MathMax(lastCandle.open, price + (lastCandle.open - lastCandle.close));
    double tp = price + (price - sl) * RR;
    double volumes[];
    double risk = GetRisk();

    CalculateVolume(risk, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        Trade.Sell(volume, symbol, price, sl, tp, TradeComment);
    }
}

double GetRisk() {
    return RiskAmount;
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
        decimalPlaces += 1;
    }

    return decimalPlaces;
}

template<typename T>
void AddToList(T &list[], T item) {
    ArrayResize(list, ArraySize(list) + 1);
    list[ArraySize(list) - 1] = item;
}
