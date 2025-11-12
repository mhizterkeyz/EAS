//12_11_25.mq5
#include <Trade\Trade.mqh>

CTrade Trade;

input double riskAmountPerTrade = 200; // Risk amount per trade
input double slMultiplier = 3; // SL multiplier

int OnInit() {
    return(INIT_SUCCEEDED);
}

void OnTick() {
    if (PositionsTotal() > 0) {
        return;
    }

    double neckLine;
    bool direction;
    if (!GetNeckLine(neckLine, direction)) {
        return;
    }

    if (direction) {
        DrawHorizontalLine("Bullish Neck Line", neckLine, clrGreen);
    } else {
        DrawHorizontalLine("Bearish Neck Line", neckLine, clrRed);
    }

    Comment("Neck Line: " + DoubleToString(neckLine) + "\nDirection: " + (string)direction);

    if (direction && iClose(_Symbol, PERIOD_CURRENT, 1) > neckLine && !hasOpenPositions(false)) {
        Sell();
    }

    if (!direction && iClose(_Symbol, PERIOD_CURRENT, 1) < neckLine && !hasOpenPositions(true)) {
        Buy();
    }
}

bool IsBullish(int index) {
    return iClose(_Symbol, PERIOD_CURRENT, index) > iOpen(_Symbol, PERIOD_CURRENT, index);
}

bool IsBearish(int index) {
    return iClose(_Symbol, PERIOD_CURRENT, index) < iOpen(_Symbol, PERIOD_CURRENT, index);
}

bool GetNeckLine(double &neckLine, bool &direction) {
    if (IsBullish(3) && IsBearish(2) && IsBullish(1)) {
        neckLine = iOpen(_Symbol, PERIOD_CURRENT, 2);
        direction = true;
        return true;
    }

    if (IsBearish(3) && IsBullish(2) && IsBearish(1)) {
        neckLine = iOpen(_Symbol, PERIOD_CURRENT, 2);
        direction = false;
        return true;
    }

    return false;
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

bool hasOpenPositions(bool isBuy = true) {
    for (int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if (ticket > 0 && PositionSelectByTicket(ticket)) {
            if (PositionGetString(POSITION_SYMBOL) == _Symbol) {
                ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                if (isBuy && posType == POSITION_TYPE_BUY) {
                    return true;
                }
                if (!isBuy && posType == POSITION_TYPE_SELL) {
                    return true;
                }
            }
        }
    }
    return false;
}

void Buy() {
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double magnitude = iHigh(_Symbol, PERIOD_CURRENT, 1) - iLow(_Symbol, PERIOD_CURRENT, 1);

    double tp = entryPrice + magnitude;
    double sl = entryPrice - (magnitude * slMultiplier);
    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);

    if (ArraySize(volumes) == 0) {
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        AddToList(volumes, minVolume);
    }

    bool tradeSuccess = false;
    for (int i = 0; i < ArraySize(volumes); i++) {
        bool _tradeSuccess = Trade.Buy(volumes[i], _Symbol, 0, sl, tp);
        if (!tradeSuccess) {
            tradeSuccess = _tradeSuccess;
        }
    }
}

void Sell() {
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double magnitude = iHigh(_Symbol, PERIOD_CURRENT, 1) - iLow(_Symbol, PERIOD_CURRENT, 1);
    
    double tp = entryPrice - magnitude;
    double sl = entryPrice + (magnitude * slMultiplier);
    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);

    if (ArraySize(volumes) == 0) {
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        AddToList(volumes, minVolume);
    }

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
    
    // If risk amount is too small, just return empty array (will be handled by caller)
    double profitAtMinVolume = 0.0;
    if (!OrderCalcProfit(ORDER_TYPE_BUY, symbol, volumeMin, MathMin(entryPrice, stopLoss), MathMax(entryPrice, stopLoss), profitAtMinVolume)) {
        return; // Can't calculate profit
    }
    
    // If minimum lot size profit is already greater than risk amount, return empty
    // (caller will handle by using minimum lot)
    if (profitAtMinVolume >= riskAmount) {
        return;
    }
    
    while (totalProfit < riskAmount) {
        double volume = volumeMin;
        double profit = 0.0;
    
        while (OrderCalcProfit(ORDER_TYPE_BUY, symbol, volume, MathMin(entryPrice, stopLoss), MathMax(entryPrice, stopLoss), profit) && profit < (riskAmount - totalProfit) && volume < volumeMax) {
            volume += lotStep;
        }
        
        if (profit > (riskAmount - totalProfit)) {
            volume = volume - lotStep;
            // Ensure volume doesn't go below minimum
            volume = MathMax(volume, volumeMin);
        }

        // Ensure volume is at least minimum before adding
        if (volume >= volumeMin) {
            AddToList(volumes, MathMin(volumeMax, NormalizeDouble(volume, decimalPlaces)));
            totalProfit += profit;
        } else {
            // If volume is still below minimum, break to avoid infinite loop
            break;
        }
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
