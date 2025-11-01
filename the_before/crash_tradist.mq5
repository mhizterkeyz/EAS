#include <Trade\Trade.mqh>

CTrade Trade;

input double RiskAmount = 100.0;

string TradeComment = "CrashTradist";

int OnInit() {
    SendNotification(TradeComment + " Loaded!");

    return(INIT_SUCCEEDED);
}

double GetSLPrice() {
    double sl = DBL_MAX;
    int lastRedCandleIndex = INT_MAX;
    int lastGreenCandleIndex = INT_MAX;

    for (int i = 1; i < 1000; i += 1) {
        if (iOpen(_Symbol, PERIOD_M1, i) > iClose(_Symbol, PERIOD_M1, i)) {
            lastRedCandleIndex = i;
            break;
        }
    }

    for (int i = 1; i < 1000; i += 1) {
        if (iOpen(_Symbol, PERIOD_M1, i) < iClose(_Symbol, PERIOD_M1, i)) {
            lastGreenCandleIndex = i;
            break;
        }
    }

    if (lastRedCandleIndex < INT_MAX && lastGreenCandleIndex < INT_MAX) {
        sl = iHigh(_Symbol, PERIOD_M1, lastRedCandleIndex) + (iHigh(_Symbol, PERIOD_M1, lastGreenCandleIndex) - iLow(_Symbol, PERIOD_M1, lastGreenCandleIndex)) * 3;
    }

    return sl;
} 

 void OnTick() {
    for (int i = 0; i <= PositionsTotal(); i += 1) {
        if(PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == TradeComment) {
            double sl = GetSLPrice();
            if (sl < DBL_MAX) {
                double stopLoss = PositionGetDouble(POSITION_SL);
                if (sl < stopLoss) {
                    Trade.PositionModify(PositionGetInteger(POSITION_TICKET), sl, 0);
                }
            }
        }
    }

    if (IsSymbolInUse(_Symbol)) {
        return;
    }

    MqlRates rates[];

    CopyRates(_Symbol, PERIOD_H4, 0, 3, rates);
    ReverseArray(rates);

    double movingAverageArray[];
    int movingAverage = iMA(_Symbol, PERIOD_H4, 20, 0, MODE_SMA, PRICE_CLOSE);

    CopyBuffer(movingAverage, 0, 0, 3, movingAverageArray);
    ReverseArray(movingAverageArray);


    if (rates[1].close < movingAverageArray[1] && rates[2].close > movingAverageArray[2]) {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double sl = GetSLPrice();

        if (sl < DBL_MAX) {
            double volumes[];
            double risk = GetRisk();

            CalculateVolume(risk, price, sl, _Symbol, volumes);

            for (int i = 0; i < ArraySize(volumes); i++) {
                double volume = volumes[i];
                Trade.Sell(volume, _Symbol, price, sl, 0, TradeComment);
            }
        }
    }
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
