// 10_2_26.mq5
#include <Trade\Trade.mqh>
CTrade Trade;

input double riskAmountPerTrade = 0.3; // Risk amount per trade
input double tpMultiplier = 1; // TP multiplier (base RR; adds +1 per loss since last win)
input int MAGIC_NUMBER = 123456; // Magic number for trade identification
input int MAX_LOSSES_PER_DAY = 5; // Maximum losses per day
input double MAX_MULTIPLIER = 1.5; // Maximum multiplier for the RR to risk ratio

double dailyStartBalance;
int lossesSinceLastWin = 0;
int lossesToday = 0;           // reset each day; day is done after 5 losses
ulong lastProcessedDealTicket = 0;
double g_effectiveTPMultiplier = 1; // used by Buy/Sell: tpMultiplier + lossesSinceLastWin

int OnInit() {
    Trade.SetExpertMagicNumber(MAGIC_NUMBER);
    dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    return(INIT_SUCCEEDED);
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

void Buy() {
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double sl = iLow(_Symbol, PERIOD_CURRENT, 1);
    if (sl >= entryPrice) return; // SL must be below entry for a buy
    long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minDist = stopsLevel * _Point;
    if (entryPrice - sl < minDist) {
        sl = entryPrice - minDist;
        sl = NormalizeDouble(sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
        Print("Buy: SL set to broker minimum distance (", DoubleToString(sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)), ")");
    }

    double tp = entryPrice + (entryPrice - sl) * MathMin(g_effectiveTPMultiplier, MAX_MULTIPLIER);
    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        Trade.Buy(volumes[i], _Symbol, 0, sl, tp);
    }
}

void Sell() {
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double sl = iHigh(_Symbol, PERIOD_CURRENT, 1);
    if (sl <= entryPrice) return; // SL must be above entry for a sell
    long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minDist = stopsLevel * _Point;
    if (sl - entryPrice < minDist) {
        sl = entryPrice + minDist;
        sl = NormalizeDouble(sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
        Print("Sell: SL set to broker minimum distance (", DoubleToString(sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)), ")");
    }

    double tp = entryPrice - (sl - entryPrice) * MathMin(g_effectiveTPMultiplier, MAX_MULTIPLIER);
    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        Trade.Sell(volumes[i], _Symbol, 0, sl, tp);
    }
}

void UpdateLossCountOnPositionClose() {
    // Find the most recent closing deal for this EA (symbol + magic)
    if (!HistorySelect(TimeCurrent() - 86400, TimeCurrent())) return;
    int total = HistoryDealsTotal();
    for (int i = total - 1; i >= 0; i--) {
        ulong ticket = HistoryDealGetTicket(i);
        if (ticket == 0) continue;
        if (HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
        if (HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
        if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != MAGIC_NUMBER) continue;
        if (ticket == lastProcessedDealTicket) break;
        lastProcessedDealTicket = ticket;
        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        if (profit < 0) {
            lossesSinceLastWin++;
            lossesToday++;
            Print("Loss #", lossesSinceLastWin, " since last win. Losses today: ", lossesToday, ". Next trade RR = ", tpMultiplier, " + ", lossesSinceLastWin, " = ", (tpMultiplier + lossesSinceLastWin));
            if (lossesToday >= MAX_LOSSES_PER_DAY) Print("Day done: ", MAX_LOSSES_PER_DAY, " losses today. No more trades until next day.");
        } else {
            lossesSinceLastWin = 0;
            Print("Win. Loss count reset to 0. Next trade RR = ", tpMultiplier);
        }
        break;
    }
}

void OnTick() {
    static bool hadPositionLastTick = false;
    bool hasPos = HasOpenPositionForThisEA();
    if (hadPositionLastTick && !hasPos)
        UpdateLossCountOnPositionClose();
    hadPositionLastTick = hasPos;

    static datetime currentTime = iTime(_Symbol, PERIOD_D1, 0);
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    if (currentTime != iTime(_Symbol, PERIOD_D1, 0)) {
        dailyStartBalance = currentBalance;
        currentTime = iTime(_Symbol, PERIOD_D1, 0);
        lossesToday = 0; // new day, reset daily loss count only
        // lossesSinceLastWin is NOT reset here — RR carries over to next day until there's a win
    }

    if ((currentBalance - dailyStartBalance) >= riskAmountPerTrade) {
        return;
    }

    if (lossesToday >= 5) return; // day done after 5 losses

    if (hasPos) return;

    static datetime lastTimeChecked = iTime(_Symbol, PERIOD_CURRENT, 0);
    if (lastTimeChecked == iTime(_Symbol, PERIOD_CURRENT, 0)) {
        return;
    }
    lastTimeChecked = iTime(_Symbol, PERIOD_CURRENT, 0);

    g_effectiveTPMultiplier = tpMultiplier + (double)lossesSinceLastWin;
    bool lastCandleWasBullish = iClose(_Symbol, PERIOD_CURRENT, 1) > iOpen(_Symbol, PERIOD_CURRENT, 1);

    if (lastCandleWasBullish) {
        Buy();
    } else {
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

