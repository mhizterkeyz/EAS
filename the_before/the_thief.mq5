#include <Trade\Trade.mqh>

input string Symbols = "XAUUSD";
input ENUM_TIMEFRAMES TimeFrame = PERIOD_H4;
input double RR = 1;
input double RiskAmount = 100;
input int TradingDaysStart = 2;
input int TradingDaysEnd = 4;
input int TradingHoursStart = 7;
input int TradingHoursEnd = 20;

CTrade Trade;
string TradeComment = "THE THIEF";
string _Symbols[];
double FibMultiplier = 0.382;
datetime TimeTracker;

int OnInit() {
   TimeTracker = iTime(_Symbol, TimeFrame, 0);

   StringSplit(Symbols, ',', _Symbols);

   SendNotification(TradeComment + " Loaded!");

   return(INIT_SUCCEEDED);
}

void OnTick() {
    if (iTime(_Symbol, TimeFrame, 0) != TimeTracker && IsInTradingWindow()) {
        TimeTracker = iTime(_Symbol, TimeFrame, 0);

        for (int i = 0; i < ArraySize(_Symbols); i += 1) {
            string symbol = _Symbols[i];
            if (!IsSymbolInUse(symbol)) {
                string entry = CheckEntry(symbol, TimeFrame);

                if (entry == "buy")
                    Buy(symbol, TimeFrame);

                if (entry == "sell")
                    Sell(symbol, TimeFrame);
            }
        }
    }
}

void Buy(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates lastCandle = GetLastCandle(symbol, timeframe);
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double sl = price - (FibMultiplier * (lastCandle.close - lastCandle.open));
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
    double sl = price + (FibMultiplier * (lastCandle.open - lastCandle.close));
    double tp = price - (sl - price) * RR;
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

MqlRates GetLastCandle(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates rates[];

    CopyRates(symbol, timeframe, 1, 1, rates);

    return rates[0];
}

string CheckEntry(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates rates[];

    CopyRates(symbol, timeframe, 0, 3, rates);
    ReverseArray(rates);

    string signal = "";
    double movingAverageArray[];
    int movingAverage = iMA(symbol, timeframe, 20, 0, MODE_SMA, PRICE_CLOSE);

    CopyBuffer(movingAverage, 0, 0, 3, movingAverageArray);
    ReverseArray(movingAverageArray);
    
    long spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
    double points = SymbolInfoDouble(symbol, SYMBOL_POINT);

    if (MathAbs(rates[1].close - rates[1].open) >= spread * points * 70) {

    if (rates[1].close > movingAverageArray[1])
        if (rates[2].close < movingAverageArray[2])
            signal = "buy";

    if (rates[1].close < movingAverageArray[1])
        if (rates[2].close > movingAverageArray[2])
            signal = "sell";

    }


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

bool IsSymbolInUse(string symbol) {
    for(int i = 0; i <= PositionsTotal(); i += 1) {
        if(PositionGetSymbol(i) == symbol && PositionGetString(POSITION_COMMENT) == TradeComment) {
            return true; 
        }
    }

    return false;
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

bool IsInTradingWindow() {
    MqlDateTime currentTime;
    TimeToStruct(TimeGMT(), currentTime);

    return currentTime.day_of_week >= TradingDaysStart && currentTime.day_of_week <= TradingDaysEnd && currentTime.hour >= TradingHoursStart && currentTime.hour <= TradingHoursEnd;
}
