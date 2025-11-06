// 4_11_25.mq5
#include <Trade\Trade.mqh>

CTrade Trade;

input double tradeSize = 1000; // Trade size in points
input double riskAmountPerTrade = 1350; // Risk amount per trade
input double dailyNumberOfTrades = 9; // Daily number of trades
input int bias = 0; // Bias, 0 = neutral, 1 = bullish, 2 = bearish
input double slMultiplier = 3.3; // SL multiplier
input double dailyMaxConsecutiveLosses = 1; // Max consecutive losses in a day

double tradesCount = 0;
int consecutiveLosses = 0;

int OnInit() {
    return(INIT_SUCCEEDED);
}

void OnTick() {
    // Check for closed positions and update consecutive losses
    checkClosedPositions();
    
    bool canTrade = canTrade();
    bool hasOpenPositions = hasOpenPositions();

    Comment("canTrade: " + (string)canTrade + "\nhasOpenPositions: " + (string)hasOpenPositions + "\ntradesCount: " + (string)tradesCount + "\nconsecutiveLosses: " + (string)consecutiveLosses + "\nbias: " + (string)bias);

    if (hasOpenPositions) {
        return;
    }

    if (!canTrade) {
        return;
    }

    if (bias != 2) {
        Buy();
    } else if (bias != 1) {
        Sell();
    }
}

bool hasOpenPositions() {

    for (int i = 0; i < PositionsTotal(); i++) {
        if (PositionGetSymbol(i) == _Symbol) {
            return true;
        }
    }

    return false;
}

bool canTrade() {
    static datetime previousDay = iTime(Symbol(), PERIOD_D1, 0);
    datetime day = iTime(Symbol(), PERIOD_D1, 0);
    
    if (day != previousDay) {
        previousDay = iTime(Symbol(), PERIOD_D1, 0);
        tradesCount = 0;
        consecutiveLosses = 0;
    }

    // Check if max consecutive losses reached
    if (consecutiveLosses >= dailyMaxConsecutiveLosses) {
        return false;
    }

    if (tradesCount < dailyNumberOfTrades) {
        return true;
    }

    return false;
}

void checkClosedPositions() {
    static bool wasPositionOpen = false;
    
    // Check current state
    bool hasOpen = false;
    for (int i = 0; i < PositionsTotal(); i++) {
        if (PositionGetSymbol(i) == _Symbol) {
            hasOpen = true;
            break;
        }
    }
    
    // If position just closed (was open, now closed)
    if (wasPositionOpen && !hasOpen) {
        // Check the most recent closed deals for this symbol
        datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);
        datetime dayEnd = dayStart + PeriodSeconds(PERIOD_D1);
        
        if (HistorySelect(dayStart, dayEnd)) {
            double totalProfit = 0.0;
            int totalDeals = HistoryDealsTotal();
            
            // Get deals from the most recent position closure (last few deals should be from our closed position)
            // We'll check deals from the end backwards to find the most recent closure
            datetime lastDealTime = 0;
            for (int i = totalDeals - 1; i >= 0; i--) {
                ulong dealTicket = HistoryDealGetTicket(i);
                if (dealTicket == 0) continue;
                
                if (HistoryDealGetString(dealTicket, DEAL_SYMBOL) == _Symbol) {
                    datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                    ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
                    
                    // If this is an entry deal (opening), we've found the start of a position
                    // If this is an exit deal (closing), add its profit
                    if (dealEntry == DEAL_ENTRY_OUT) {
                        double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                        totalProfit += dealProfit;
                        if (lastDealTime == 0) {
                            lastDealTime = dealTime;
                        }
                    } else if (dealEntry == DEAL_ENTRY_IN && lastDealTime > 0 && dealTime < lastDealTime) {
                        // We've gone back to the opening of this position, stop
                        break;
                    }
                }
            }
            
            // Update consecutive losses counter based on the closed position
            if (totalProfit < 0) {
                consecutiveLosses++;
            } else if (totalProfit > 0) {
                // Reset on profit
                consecutiveLosses = 0;
            }
        }
    }
    
    wasPositionOpen = hasOpen;
}

void Buy() {
    tradesCount++;
    
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double tpDistance = tradeSize;
    double tp = entryPrice + tpDistance;
    double sl = entryPrice - (tpDistance * slMultiplier);
    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);

    // If risk amount is too small to calculate any volume, use minimum lot size
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
    tradesCount++;

    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double tpDistance = tradeSize;
    double tp = entryPrice - tpDistance;
    double sl = entryPrice + (tpDistance * slMultiplier);
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
