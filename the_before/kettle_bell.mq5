#include <Trade\Trade.mqh>

CTrade Trade;

input string Symbols = "EURGBP,EURJPY,NZDJPY,USDJPY,XAUUSD,GBPJPY,AUDJPY,EURUSD,BTCUSD,GBPUSD,NZDUSD,EURCHF,AUDCHF,NZDCHF,EURNZD,GBPAUD,GBPCAD,EURCAD,GBPCHF,NZDCAD,AUDNZD,GBPNZD,CADCHF,AUDUSD";
input double RiskAmount = 100.0;
input double RR = 2.0;

string TradeComment = "DingDong";
string _Symbols[];
datetime PreviousTimes[];
datetime DayTracker;
bool CanTradeToday = true;


int OnInit() {
    SendNotification(TradeComment + " Loaded on " + _Symbol);

    StringSplit(Symbols, ',', _Symbols);
    ArrayResize(PreviousTimes, ArraySize(_Symbols));

    for (int i = 0; i < ArraySize(PreviousTimes); i += 1) {
        PreviousTimes[i] = iTime(_Symbols[i], PERIOD_H1, 0);
    }

    return(INIT_SUCCEEDED);
}

void OnTick() {
    if (DayTracker != iTime(_Symbol, PERIOD_D1, 0)) {
        DayTracker = iTime(_Symbol, PERIOD_D1, 0);
        CanTradeToday = true;
    }

    if (!CanTradeToday) {
        return;
    }

    for (int i = 0; i < ArraySize(_Symbols); i += 1) {
        string symbol = _Symbols[i];

        if (
            PreviousTimes[i] == iTime(symbol, PERIOD_H1, 0) ||
            IsSymbolInUse(symbol) ||
            !CanTradeToday
        ) {
            continue;
        }

        double price = SymbolInfoDouble(symbol, SYMBOL_BID);
        bool skip = false;
        for (int i = 1; i < 3; i += 1) {
            if (iOpen(symbol, PERIOD_H1, i) > iClose(symbol, PERIOD_H1, i)) {
                skip = true;
                break;
            }
        }

        if (skip || !CanTradeToday) 
            continue;


        if (
            iOpen(symbol, PERIOD_H1, 0) > price ||
            iLow(symbol, PERIOD_H1, 0) >= iOpen(symbol, PERIOD_H1, 1) ||
            iLow(symbol, PERIOD_H1, 0) >= iClose(symbol, PERIOD_H1, 2) ||
            !CanTradeToday
        ) {
            continue;
        }
    
        CanTradeToday = false;
        PreviousTimes[i] = iTime(symbol, PERIOD_H1, 0);
        double entryPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
        double sl = iLow(symbol, PERIOD_H1, 0);
        double tp = entryPrice + RR * (entryPrice - sl);
        double volumes[];
        double risk = GetRisk();

        CalculateVolume(risk, entryPrice, sl, symbol, volumes);

        for (int i = 0; i < ArraySize(volumes); i++) {
            double volume = volumes[i];
            Trade.Buy(volume, symbol, entryPrice, sl, tp, TradeComment);
        }


        SendNotification("New BUY trade on "+symbol+" sl: "+DoubleToString(sl)+" tp: "+DoubleToString(tp));
    }
}

bool IsSymbolInUse(string symbol) {
    for(int i = 0; i <= PositionsTotal(); i += 1) {
        if(PositionGetSymbol(i) == symbol && PositionGetString(POSITION_COMMENT) == TradeComment) {
            return true; 
        }
    }

    return false;
}

double GetRisk() {
    return RiskAmount;
}

void _CalculateVolume(double riskAmount, double entryPrice, double stopLoss, string symbol, double &volumes[]) {
    double totalProfit = 0.0;
    double volumeMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double volumeMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    int decimalPlaces = GetDecimalPlaces(lotStep);
    double profitForMinLot = 0.0;

    if (!OrderCalcProfit(ORDER_TYPE_BUY, symbol, volumeMin, MathMin(entryPrice, stopLoss), MathMax(entryPrice, stopLoss), profitForMinLot)) {
        AddToList(volumes, volumeMin);
        return;
    }

    double volume = NormalizeDouble((riskAmount * volumeMin) / profitForMinLot, decimalPlaces);

    while (profitForMinLot * volume > riskAmount && volume > lotStep) {
        volume = NormalizeDouble(volume - lotStep, decimalPlaces);
    }

    if (volume > volumeMax) {
        int n = volume / volumeMax;
        for (int i = 0; i < n; i += 1) {
            volume = NormalizeDouble(volume - volumeMax, decimalPlaces);
            AddToList(volumes, volumeMax);
        }
    }

    if (volume > 0.0) {
        AddToList(volumes, volume);
    }
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


