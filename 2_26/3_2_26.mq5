// 3_2_26.mq5
#include <Trade\Trade.mqh>

CTrade Trade;

input double riskAmountPerTrade = 125; // Risk amount per trade
input double tpMultiplier = 3; // TP multiplier
input int MAGIC_NUMBER = 123456; // Magic number for trade identification
input bool useOneTradePerDay = true; // Limit to one trade per day
input bool useRandomStartWindow = true; // Only look for setups from random 2-5 AM (broker time)

string GetLastTradeDateGlobalName() {
    return "EALastTradeDate_" + IntegerToString(MAGIC_NUMBER);
}

datetime GetTodayDate() {
    return (datetime)StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
}

bool AlreadyTradedToday() {
    if (!useOneTradePerDay) return false;
    datetime today = GetTodayDate();
    if (!GlobalVariableCheck(GetLastTradeDateGlobalName())) return false;
    return (datetime)GlobalVariableGet(GetLastTradeDateGlobalName()) == today;
}

void SetLastTradeDateToToday() {
    GlobalVariableSet(GetLastTradeDateGlobalName(), (double)GetTodayDate());
}

datetime GetTodayRandomStartTime() {
    datetime today = GetTodayDate();
    MathSrand((int)today);
    // Random seconds from midnight: 2*3600 to (5*3600 - 1) so 02:00:00 to 04:59:59
    int secondsFromMidnight = 2 * 3600 + (MathRand() % (3 * 3600));
    return today + (datetime)secondsFromMidnight;
}

int OnInit() {
    Trade.SetExpertMagicNumber(MAGIC_NUMBER);
    return(INIT_SUCCEEDED);
}

bool IsBullish(int index) {
    return iClose(_Symbol, PERIOD_CURRENT, index) > iOpen(_Symbol, PERIOD_CURRENT, index);
}

bool IsBearish(int index) {
    return iClose(_Symbol, PERIOD_CURRENT, index) < iOpen(_Symbol, PERIOD_CURRENT, index);
}

int GetSignal() {
    int signal = 0;

    if (IsBearish(4) && IsBearish(3) && IsBullish(2) && IsBullish(1)) {
        signal = 1;
    }

    if (IsBullish(4) && IsBullish(3) && IsBearish(2) && IsBearish(1)) {
        signal = -1;
    }

    return signal;
}

void Buy() {
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double sl = MathMin(
        MathMin(iLow(_Symbol, PERIOD_CURRENT, 1), iLow(_Symbol, PERIOD_CURRENT, 2)),
        MathMin(iLow(_Symbol, PERIOD_CURRENT, 3), iLow(_Symbol, PERIOD_CURRENT, 4))
    );
    double tp = entryPrice + (entryPrice - sl) * tpMultiplier;
    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);

    if (ArraySize(volumes) == 0) {
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        AddToList(volumes, minVolume);
    }

    bool anyOpened = false;
    for (int i = 0; i < ArraySize(volumes); i++) {
        if (Trade.Buy(volumes[i], _Symbol, 0, sl, tp) && Trade.ResultRetcode() == TRADE_RETCODE_DONE)
            anyOpened = true;
    }
    if (anyOpened) SetLastTradeDateToToday();
}

void Sell() {
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double sl = MathMax(
        MathMax(iHigh(_Symbol, PERIOD_CURRENT, 1), iHigh(_Symbol, PERIOD_CURRENT, 2)),
        MathMax(iHigh(_Symbol, PERIOD_CURRENT, 3), iHigh(_Symbol, PERIOD_CURRENT, 4))
    );
    double tp = entryPrice - (sl - entryPrice) * tpMultiplier;
    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);

    if (ArraySize(volumes) == 0) {
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        AddToList(volumes, minVolume);
    }

    bool anyOpened = false;
    for (int i = 0; i < ArraySize(volumes); i++) {
        if (Trade.Sell(volumes[i], _Symbol, 0, sl, tp) && Trade.ResultRetcode() == TRADE_RETCODE_DONE)
            anyOpened = true;
    }
    if (anyOpened) SetLastTradeDateToToday();
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
    if (AlreadyTradedToday()) return;
    if (useRandomStartWindow && TimeCurrent() < GetTodayRandomStartTime()) return;

    if (GetSignal() == 1) {
        Buy();
    } else if (GetSignal() == -1) {
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