// 4_2_26.mq5
#include <Trade\Trade.mqh>
CTrade Trade;

input double riskAmountPerTrade = 125; // Risk amount per trade
input double tpMultiplier = 3; // TP multiplier
input int MAGIC_NUMBER = 123456; // Magic number for trade identification


int OnInit() {
    Trade.SetExpertMagicNumber(MAGIC_NUMBER);
    return(INIT_SUCCEEDED);
}

bool IsBullish(int index, ENUM_TIMEFRAMES period = PERIOD_CURRENT) {
    return iClose(_Symbol, period, index) > iOpen(_Symbol, period, index);
}

bool IsBearish(int index, ENUM_TIMEFRAMES period = PERIOD_CURRENT) {
    return iClose(_Symbol, period, index) < iOpen(_Symbol, period, index);
}

int GetSignal() {
    int signal = 0;
    double currentClose = iClose(_Symbol, PERIOD_CURRENT, 0);

    if (IsBullish(1, PERIOD_D1)) {
        double height = iHigh(_Symbol, PERIOD_D1, 1) - iLow(_Symbol, PERIOD_D1, 1);
        double heightOfBody = MathAbs(iClose(_Symbol, PERIOD_D1, 1) - iOpen(_Symbol, PERIOD_D1, 1));
        if (heightOfBody <= height * 0.7) {
            double priceDistanceFromPreviousDayLow = currentClose - iLow(_Symbol, PERIOD_D1, 1);
            double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
            double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
            if (
                priceDistanceFromPreviousDayLow <= height * 0.7 &&
                currentHigh < height * 0.75 &&
                currentLow > height * 0.10
            ) {
                signal = 1;
            }
        }
    }

    if (IsBearish(1, PERIOD_D1)) {
        double height = iHigh(_Symbol, PERIOD_D1, 1) - iLow(_Symbol, PERIOD_D1, 1);
        double heightOfBody = MathAbs(iClose(_Symbol, PERIOD_D1, 1) - iOpen(_Symbol, PERIOD_D1, 1));
        if (heightOfBody <= height * 0.7) {
            double priceDistanceFromPreviousDayHigh = iHigh(_Symbol, PERIOD_D1, 1) - currentClose;
            double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
            double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
            if (
                priceDistanceFromPreviousDayHigh <= height * 0.7 &&
                currentLow > height * 0.25 &&
                currentHigh < height * 0.90
            ) {
                signal = -1;
            }
        }
    }

    return signal;
}

void Buy() {
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double sl = iLow(_Symbol, PERIOD_D1, 1);
    double tp = entryPrice + (entryPrice - sl) * tpMultiplier;
    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);

    if (ArraySize(volumes) == 0) {
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        AddToList(volumes, minVolume);
    }

    for (int i = 0; i < ArraySize(volumes); i++) {
        Trade.Buy(volumes[i], _Symbol, 0, sl, tp);
    }
}

void Sell() {
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double sl = iHigh(_Symbol, PERIOD_D1, 1);
    double tp = entryPrice - (sl - entryPrice) * tpMultiplier;
    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);

    if (ArraySize(volumes) == 0) {
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        AddToList(volumes, minVolume);
    }

    for (int i = 0; i < ArraySize(volumes); i++) {
        Trade.Sell(volumes[i], _Symbol, 0, sl, tp);
    }
}

bool HasOpenPositionForThisEA() {
    int total = PositionsTotal();
    for (int i = 0; i < total; i++) {
        // PositionGetTicket(i) also selects the position for PositionGet* calls
        ulong ticket = PositionGetTicket(i);
        if (ticket == 0)
            continue;
        long magic = PositionGetInteger(POSITION_MAGIC);
        string symbol = PositionGetString(POSITION_SYMBOL);
        if (magic == MAGIC_NUMBER && symbol == _Symbol)
            return true;
    }
    return false;
}

void OnTick() {
    if (HasOpenPositionForThisEA()) return;
    int signal = GetSignal();

    if (signal == 1) {
        Buy();
    } else if (signal == -1) {
        Sell();
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