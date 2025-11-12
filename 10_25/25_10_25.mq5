// 25_10_25.mq5
#include <Trade\Trade.mqh>

CTrade Trade;

input double maximumTradeSize = 30; // Maximum trade size in points
input double minimumTradeSize = 10; // Minimum trade size in points
input double riskAmountPerTrade = 200; // Risk amount per trade
input double dailyNumberOfTrades = 3; // Daily number of trades
input int bias = 0; // Bias, 0 = neutral, 1 = bullish, 2 = bearish


double startingBalance;
double highestPoint;
double lowestPoint;
int tradesCount = 0;
double lastPointTraded;

int OnInit() {
    startingBalance = startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    highestPoint = DBL_MIN;
    lowestPoint = DBL_MAX;

    return(INIT_SUCCEEDED);
}

void OnTick() {
    Comment("hasOpenPositions: " + (string)hasOpenPositions() + "\ncanTrade: " + (string)canTrade());

    if (hasOpenPositions()) {
        return;
    }

    if (!canTrade()) {
        return;
    }

    static datetime currentTime = iTime(Symbol(), PERIOD_CURRENT, 0);
    if (currentTime == iTime(Symbol(), PERIOD_CURRENT, 0)) {
        return;
    }

    currentTime = iTime(Symbol(), PERIOD_CURRENT, 0);

    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double diffBetweenCurrentPriceAndHighestPoint = highestPoint - currentPrice;
    double diffBetweenCurrentPriceAndLowestPoint = currentPrice - lowestPoint;



    if (diffBetweenCurrentPriceAndHighestPoint > 0 && bias != 2) {
        Buy();
    } else if (diffBetweenCurrentPriceAndLowestPoint > 0 && bias != 1) {
        Sell();
    }

    updateHighestAndLowestPoints();

    DrawHorizontalLine("Highest Point", highestPoint, clrGreen);
    DrawHorizontalLine("Lowest Point", lowestPoint, clrRed);
}

bool hasOpenPositions() {

    for (int i = 0; i < PositionsTotal(); i++) {
        if (PositionGetSymbol(i) == _Symbol) {
            return true;
        }
    }

    return false;
}

bool IsBullish(int index) {
    return iClose(_Symbol, PERIOD_CURRENT, index) > iOpen(_Symbol, PERIOD_CURRENT, index);
}

bool IsBearish(int index) {
    return iClose(_Symbol, PERIOD_CURRENT, index) < iOpen(_Symbol, PERIOD_CURRENT, index);
}

void updateHighestAndLowestPoints() {

    static datetime previousDay = iTime(Symbol(), PERIOD_D1, 0);
    datetime day = iTime(Symbol(), PERIOD_D1, 0);

    if (day != previousDay) {
        previousDay = iTime(Symbol(), PERIOD_D1, 0);
        highestPoint = DBL_MIN;
        lowestPoint = DBL_MAX;

        return;
    }
    
    if (
        (IsBullish(1) && iClose(_Symbol, PERIOD_CURRENT, 1) > iClose(_Symbol, PERIOD_CURRENT, 2) && iClose(_Symbol, PERIOD_CURRENT, 1) > iOpen(_Symbol, PERIOD_CURRENT, 2)) ||
        (IsBearish(1) && IsBullish(2) && iClose(_Symbol, PERIOD_CURRENT, 2) > iClose(_Symbol, PERIOD_CURRENT, 3))
    ) {
        highestPoint = MathMax(iOpen(_Symbol, PERIOD_CURRENT, 1), iClose(_Symbol, PERIOD_CURRENT, 1));
    }

    if (
        (IsBearish(1) && iClose(_Symbol, PERIOD_CURRENT, 1) < iClose(_Symbol, PERIOD_CURRENT, 2) && iClose(_Symbol, PERIOD_CURRENT, 1) < iOpen(_Symbol, PERIOD_CURRENT, 2)) ||
        (IsBullish(1) && IsBearish(2) && iClose(_Symbol, PERIOD_CURRENT, 2) < iClose(_Symbol, PERIOD_CURRENT, 3))
    ) {
        lowestPoint = MathMin(iOpen(_Symbol, PERIOD_CURRENT, 1), iClose(_Symbol, PERIOD_CURRENT, 1));
    }
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

bool canTrade() {
    static datetime previousDay = iTime(Symbol(), PERIOD_D1, 0);
    datetime day = iTime(Symbol(), PERIOD_D1, 0);
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    if (day != previousDay) {
        previousDay = iTime(Symbol(), PERIOD_D1, 0);
        startingBalance = startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        tradesCount = 0;

        return true;
    }

    if (tradesCount < dailyNumberOfTrades && currentBalance >= startingBalance) {
        startingBalance = startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);

        return true;
    }

    return false;
}

void Buy() {
    if (lastPointTraded == highestPoint) {
        return;
    }

    lastPointTraded = highestPoint;
    tradesCount++;
    
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double size = MathMax(highestPoint - entryPrice, minimumTradeSize);
    size = MathMin(size, maximumTradeSize);
    double sl = entryPrice - size * 3;
    double tp = MathMax(entryPrice + size, highestPoint);
    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);

    bool tradeSuccess = false;
    for (int i = 0; i < ArraySize(volumes); i++) {
        bool _tradeSuccess = Trade.Buy(volumes[i], _Symbol, 0, sl, tp);
        if (!tradeSuccess) {
            tradeSuccess = _tradeSuccess;
        }
    }
}

void Sell() {
    if (lastPointTraded == lowestPoint) {
        return;
    }

    lastPointTraded = lowestPoint;
    tradesCount++;

    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double size = MathMax(entryPrice - lowestPoint, minimumTradeSize);
    size = MathMin(size, maximumTradeSize);
    double sl = entryPrice + size * 3;
    double tp =  MathMin(entryPrice - size, lowestPoint);
    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);
    
    bool tradeSuccess = false;
    for (int i = 0; i < ArraySize(volumes); i++) {
        bool _tradeSuccess = Trade.Sell(volumes[i], _Symbol, 0, sl, tp);
        if (!tradeSuccess) {
            tradeSuccess = _tradeSuccess;
        }
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
