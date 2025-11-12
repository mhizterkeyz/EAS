// 6_11_25.mq5
#include <Trade\Trade.mqh>
CTrade Trade;

input double dailyNumberOfTrades = 3; // Daily number of trades
input int bias = 0; // Bias, 0 = neutral, 1 = bullish, 2 = bearish
input double minimumTradeSize = 3; // Minimum trade size in points
input double tpMultiplier = 3; // TP multiplier
input double riskAmountPerTrade = 111; // Risk amount per trade
input int maxProfitTrades = 0; // Max profit trades per day (0 = unlimited)
input int maxLossTrades = 0; // Max loss trades per day (0 = unlimited)

double highestPoint;
double lowestPoint;
double startingBalance;
int tradesCount = 0;
double lastLowestPointTraded;
double lastHighestPointTraded;
int profitTradesCount = 0;
int lossTradesCount = 0;
ulong trackedTickets[]; // Track open positions to detect closures

int OnInit() {
    startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    highestPoint = DBL_MIN;
    lowestPoint = DBL_MAX;
    profitTradesCount = 0;
    lossTradesCount = 0;
    tradesCount = 0;
    lastLowestPointTraded = 0;
    lastHighestPointTraded = 0;
    ArrayResize(trackedTickets, 0);
    return(INIT_SUCCEEDED);
}

void OnTick() {
    // Check for closed positions and update profit/loss counters
    CheckClosedPositions();
    
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double diffBetweenCurrentPriceAndHighestPoint = highestPoint - currentPrice;
    double diffBetweenCurrentPriceAndLowestPoint = currentPrice - lowestPoint;
    
    Comment("CanBuy: " + (string)!hasOpenPositions(true) + "\nCanSell: " + (string)!hasOpenPositions(false) + "\ncanTrade: " + (string)canTrade() + "\nCurrent Risk: " + DoubleToString(riskAmountPerTrade, 2) + "\nDiff Between Current Price And Highest Point: " + DoubleToString(diffBetweenCurrentPriceAndHighestPoint) + "\nDiff Between Current Price And Lowest Point: " + DoubleToString(diffBetweenCurrentPriceAndLowestPoint) + "\nHighest Point: " + DoubleToString(highestPoint) + "\nLowest Point: " + DoubleToString(lowestPoint) + "\nMinimum Trade Size: " + DoubleToString(minimumTradeSize) + "\nProfit Trades: " + (string)profitTradesCount + "\nLoss Trades: " + (string)lossTradesCount);

    if (PositionsTotal() > 0) {
        return;
    }

    if (bias != 2 && diffBetweenCurrentPriceAndLowestPoint >= minimumTradeSize && !hasOpenPositions(true) && canTrade()) {
        Buy();
    }

    if (bias != 1 && diffBetweenCurrentPriceAndHighestPoint >= minimumTradeSize && !hasOpenPositions(false) && canTrade()) {
        Sell();
    }

    updateHighestAndLowestPoints();

    DrawHorizontalLine("Highest Point", highestPoint, clrGreen);
    DrawHorizontalLine("Lowest Point", lowestPoint, clrRed);
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

bool canTrade() {
    static datetime previousDay = iTime(Symbol(), PERIOD_D1, 0);
    datetime day = iTime(Symbol(), PERIOD_D1, 0);
    
    if (day != previousDay) {
        previousDay = iTime(Symbol(), PERIOD_D1, 0);
        startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        tradesCount = 0;
        profitTradesCount = 0;
        lossTradesCount = 0;
        lastLowestPointTraded = 0;
        lastHighestPointTraded = 0;
        ArrayResize(trackedTickets, 0);
    }

    // Check if max profit trades limit reached
    if (maxProfitTrades > 0 && profitTradesCount >= maxProfitTrades) {
        return false;
    }

    // Check if max loss trades limit reached
    if (maxLossTrades > 0 && lossTradesCount >= maxLossTrades) {
        return false;
    }

    if (tradesCount < dailyNumberOfTrades) {
        return true;
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

void Buy() {
    if (lastLowestPointTraded == lowestPoint) {
        return;
    }

    lastLowestPointTraded = lowestPoint;
    tradesCount++;
    
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    // Set TP and SL based on TP distance
    double tp = entryPrice + (minimumTradeSize * tpMultiplier);
    double sl = entryPrice - minimumTradeSize;
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
    if (lastHighestPointTraded == highestPoint) {
        return;
    }

    lastHighestPointTraded = highestPoint;
    tradesCount++;

    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    // Set TP and SL based on TP distance
    double tp = entryPrice - (minimumTradeSize * tpMultiplier);
    double sl = entryPrice + minimumTradeSize;
    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);
    
    // If risk amount is too small to calculate any volume, use minimum lot size
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

void RemoveFromList(ulong &list[], ulong item) {
    int size = ArraySize(list);
    for (int i = 0; i < size; i++) {
        if (list[i] == item) {
            // Move last element to this position
            if (i < size - 1) {
                list[i] = list[size - 1];
            }
            ArrayResize(list, size - 1);
            break;
        }
    }
}

// Check for closed positions and update profit/loss counters
void CheckClosedPositions() {
    // First, check tracked tickets - see if any positions closed
    for (int i = ArraySize(trackedTickets) - 1; i >= 0; i--) {
        ulong ticket = trackedTickets[i];
        
        // Check if position still exists
        if (!PositionSelectByTicket(ticket)) {
            // Position closed - check deal history for profit
            bool found = false;
            double dealProfit = 0.0;
            
            // Search deals in history for this position
            HistorySelect(0, TimeCurrent());
            int totalDeals = HistoryDealsTotal();
            
            // Position ID is the ticket number for positions
            ulong positionId = ticket;
            
            for (int j = 0; j < totalDeals; j++) {
                ulong dealTicket = HistoryDealGetTicket(j);
                if (dealTicket == 0) continue;
                
                // Check if this deal belongs to our position
                // Note: DEAL_POSITION_ID matches the position ticket
                if (HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == positionId) {
                    // DEAL_PROFIT already includes net profit (swap and commission accounted for)
                    dealProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                    found = true;
                }
            }
            
            // Remove from tracking
            RemoveFromList(trackedTickets, ticket);
            
            // Update profit/loss counters based on result
            if (found) {
                if (dealProfit > 0) {
                    profitTradesCount++;
                } else if (dealProfit < 0) {
                    lossTradesCount++;
                }
            }
        }
    }
    
    // Track any new positions that opened (scan all current positions for this symbol)
    for (int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if (ticket == 0) continue;
        
        // Only track positions for this symbol
        if (!PositionSelectByTicket(ticket)) continue;
        if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        // Check if we're already tracking this ticket
        bool alreadyTracked = false;
        for (int j = 0; j < ArraySize(trackedTickets); j++) {
            if (trackedTickets[j] == ticket) {
                alreadyTracked = true;
                break;
            }
        }
        
        if (!alreadyTracked) {
            AddToList(trackedTickets, ticket);
        }
    }
}
