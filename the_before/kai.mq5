#include <Trade\Trade.mqh>

CTrade Trade;

input string Symbols = "Volatility 75 Index";
input ENUM_TIMEFRAMES TimeFrame = PERIOD_M1;
input ENUM_TIMEFRAMES CashOutTimeFrame = PERIOD_W1;
input double RiskAmount = 100;

string TradeComment = "LUCIFER OYA!";
string _Symbols[];
datetime TimeTracker;
datetime CashOutTimeTracker;

int OnInit() {
    StringSplit(Symbols, ',', _Symbols);

    SendNotification(TradeComment + " Loaded!");

   return (INIT_SUCCEEDED);
}

void OnTick() {
    ENUM_TIMEFRAMES _TimeFrame = PERIOD_M1;
    if (iTime(_Symbol, _TimeFrame, 0) != TimeTracker) {
        TimeTracker = iTime(_Symbol, _TimeFrame, 0);

        for (int i = 0; i < ArraySize(_Symbols); i += 1) {
            string symbol = _Symbols[i];
            double SLMultiplier = 3;
            double RR = 3.0;
            double high = iHigh(symbol, _TimeFrame, 1);
            double low = iLow(symbol, _TimeFrame, 1);

            if (iOpen(symbol, _TimeFrame, 1) < iClose(symbol, _TimeFrame, 1)) {
                double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
                double sl = price - SLMultiplier * (high - low);
                double tp = price + RR * (price - sl);
                
                Trade.Buy(SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN), symbol, price, sl, tp, TradeComment);
            } else {
                double price = SymbolInfoDouble(symbol, SYMBOL_BID);
                double sl = price + SLMultiplier * (high - low);
                double tp = price - RR * (sl - price);
                Trade.Sell(SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN), symbol, SymbolInfoDouble(symbol, SYMBOL_BID), sl, tp, TradeComment);
            }
        }
    }
}

void _OnTick() {
    if (iTime(_Symbol, CashOutTimeFrame, 0) != CashOutTimeTracker) {
        CashOutTimeTracker = iTime(_Symbol, CashOutTimeFrame, 0);

        for (int i = PositionsTotal(); i >= 0; i -= 1) {
            if(PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == TradeComment) {
                Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
            }
        }
    }

    if (iTime(_Symbol, TimeFrame, 0) != TimeTracker) {
        TimeTracker = iTime(_Symbol, TimeFrame, 0);

        CloseLoosers();

        for (int i = 0; i < ArraySize(_Symbols); i += 1) {
            string symbol = _Symbols[i];

            if (iOpen(symbol, TimeFrame, 1) < iClose(symbol, TimeFrame, 1)) {
                Trade.Buy(SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN), symbol, SymbolInfoDouble(symbol, SYMBOL_ASK), 0, 0, TradeComment);
            } else {
                Trade.Sell(SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN), symbol, SymbolInfoDouble(symbol, SYMBOL_BID), 0, 0, TradeComment);
            }
        }
    }
}

void CloseLoosers() {
    for (int i = PositionsTotal(); i >= 0; i -= 1) {
        if(PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == TradeComment) {
            double profit = PositionGetDouble(POSITION_PROFIT);
            if (profit < 0) {
                Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
            }
        }
    }
}

bool FuckOfIt(string symbol, ENUM_TIMEFRAMES timeframe) {
    for (int i = 2; i < 13; i += 1) {
        if (
            MathAbs(iOpen(symbol, timeframe, i) - iClose(symbol, timeframe, i)) * 3 >= MathAbs(iOpen(symbol, timeframe, 1) - iClose(symbol, timeframe, 1))
        ) {
            return false;
        }
    }

    return true;
}

MqlRates GetLastCandle(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates rates[];

    CopyRates(symbol, timeframe, 1, 1, rates);

    return rates[0];
}

void Buy(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates lastCandle = GetLastCandle(symbol, timeframe);
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double sl = price - 0.5 * (lastCandle.high - lastCandle.low);
    double tp = price + 0.1 * (lastCandle.high - lastCandle.low);
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
    double sl = price + 0.5 * (lastCandle.high - lastCandle.low);
    double tp = price - 0.1 * (lastCandle.high - lastCandle.low);
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
