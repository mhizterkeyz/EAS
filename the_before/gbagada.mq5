#include <Trade\Trade.mqh>

CTrade Trade;

input string Symbols = "Volatility 10 Index,Volatility 25 Index,Volatility 50 Index,Volatility 75 Index,Volatility 100 Index,Volatility 10 (1s) Index,Volatility 25 (1s) Index,Volatility 50 (1s) Index,Volatility 75 (1s) Index,Volatility 100 (1s) Index,Volatility 150 (1s) Index,Volatility 250 (1s) Index,Volatility 200 (1s) Index,Boom 500 Index,Boom 300 Index,Boom 1000 Index,Crash 500 Index,Crash 300 Index,Crash 1000 Index,Step Index,Step Index 200,Step Index 500,Range Break 100 Index,Range Break 200 Index,Jump 25 Index,Jump 10 Index,Jump 50 Index,Jump 100 Index,Jump 75 Index,DEX 600 DOWN Index,DEX 900 DOWN Index,DEX 1500 DOWN Index,DEX 600 UP Index,DEX 900 UP Index,DEX 1500 UP Index,Drift Switch Index 30,Drift Switch Index 20,Drift Switch Index 10";
input double RiskAmount = 1000.0;
input double RR = 5.0;

string TradeComment = "BumBum";
string _Symbols[];
datetime PreviousTimes[];


int OnInit() {
    SendNotification(TradeComment + " Loaded on " + _Symbol);

    StringSplit(Symbols, ',', _Symbols);
    ArrayResize(PreviousTimes, ArraySize(_Symbols));

    return(INIT_SUCCEEDED);
}

void OnTick() {
    for (int i = 0; i < ArraySize(_Symbols); i += 1) {
        string symbol = _Symbols[i];
        ENUM_TIMEFRAMES TF = PERIOD_M5;

        if (
            PreviousTimes[i] == iTime(symbol, TF, 0) ||
            IsSymbolInUse(symbol)
        ) {
            continue;
        }

        double price = SymbolInfoDouble(symbol, SYMBOL_BID);
        bool skip = false;
        for (int i = 1; i < 3; i += 1) {
            if (iOpen(symbol, TF, i) > iClose(symbol, TF, i)) {
                skip = true;
                break;
            }
        }

        if (skip) 
            continue;


        if (
            iOpen(symbol, TF, 0) > price ||
            iLow(symbol, TF, 0) >= iOpen(symbol, TF, 1) ||
            iLow(symbol, TF, 0) >= iClose(symbol, TF, 2)
        ) {
            continue;
        }
    
        PreviousTimes[i] = iTime(symbol, TF, 0);
        price = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double sl = iLow(symbol, TF, 0);
        double tp = price + RR * (price - sl);
        double volumes[];
        double risk = GetRisk();

        CalculateVolume(risk, price, sl, symbol, volumes);

        for (int i = 0; i < ArraySize(volumes); i++) {
            double volume = volumes[i];
            Trade.Buy(volume, symbol, price, sl, tp, TradeComment);
        }


        SendNotification("New Buy trade on "+symbol+" sl: "+DoubleToString(sl)+" tp: "+DoubleToString(tp));
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

void CalculateVolume(double riskAmount, double entryPrice, double stopLoss, string symbol, double &volumes[]) {
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

void _CalculateVolume(double riskAmount, double entryPrice, double stopLoss, string symbol, double &volumes[]) {

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

        while (OrderCalcProfit(ORDER_TYPE_BUY, symbol, volume, MathMin(entryPrice, stopLoss), MathMax(entryPrice, stopLoss), profit) 
                && profit < (riskAmount - totalProfit) 
                && volume < volumeMax 
                && _iterations < _maxIterations) {
            volume = NormalizeDouble(volume + lotStep, decimalPlaces);
            _iterations++;
        }

        if (profit > (riskAmount - totalProfit)) {
            volume = NormalizeDouble(volume - lotStep, decimalPlaces);
        }

        volume = MathMin(volume, volumeMax);

        AddToList(volumes, volume);
        totalProfit += profit;
        iterations++;
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


