#include <Trade\Trade.mqh>

CTrade Trade;

input double maximumTradeSize = 30; // Maximum trade size in points
input double minimumTradeSize = 10; // Minimum trade size in points
input double riskAmountPerTrade = 200; // Risk amount per trade
input double dailyNumberOfTrades = 3; // Daily number of trades
input int bias = 0; // Bias, 0 = neutral, 1 = bullish, 2 = bearish
input int winsToRecover = 3; // Number of successful trades before doubling risk


double startingBalance;
double highestPoint;
double lowestPoint;
int tradesCount = 0;
double lastPointTraded;

// Dynamic risk management variables
double originalRiskAmount;
double currentRiskAmount;
int consecutiveWins = 0;
ulong trackedTickets[]; // Track open positions to detect closures

int OnInit() {
    startingBalance = startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    highestPoint = DBL_MIN;
    lowestPoint = DBL_MAX;
    
    // Initialize risk management
    originalRiskAmount = riskAmountPerTrade;
    currentRiskAmount = riskAmountPerTrade;
    consecutiveWins = 0;
    ArrayResize(trackedTickets, 0);

    return(INIT_SUCCEEDED);
}

void OnTick() {
    // Check for closed positions and adjust risk accordingly
    CheckClosedPositions();
    
    Comment("hasOpenPositions: " + (string)hasOpenPositions() + "\ncanTrade: " + (string)canTrade() + "\nCurrent Risk: " + DoubleToString(currentRiskAmount, 2) + "\nConsecutive Wins: " + (string)consecutiveWins);

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
    
    if (day != previousDay) {
        previousDay = iTime(Symbol(), PERIOD_D1, 0);
        startingBalance = startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        tradesCount = 0;
        // Don't reset risk on new day - continue with adjusted risk

        return true;
    }

    if (tradesCount < dailyNumberOfTrades) {
        // Allow trading regardless of balance (dynamic risk handles losses)
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
    // Calculate TP distance from entry, clamped between min and max
    double tpDistance = highestPoint - entryPrice;
    tpDistance = MathMax(tpDistance, minimumTradeSize);  // At least minimum
    tpDistance = MathMin(tpDistance, maximumTradeSize);  // At most maximum
    
    // Set TP and SL based on TP distance
    double tp = entryPrice + tpDistance;
    double sl = entryPrice - (tpDistance * 3);  // SL is 3x TP distance below entry
    double volumes[];
    CalculateVolume(currentRiskAmount, entryPrice, sl, _Symbol, volumes);

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
    if (lastPointTraded == lowestPoint) {
        return;
    }

    lastPointTraded = lowestPoint;
    tradesCount++;

    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    // Calculate TP distance from entry, clamped between min and max
    double tpDistance = entryPrice - lowestPoint;
    tpDistance = MathMax(tpDistance, minimumTradeSize);  // At least minimum
    tpDistance = MathMin(tpDistance, maximumTradeSize);  // At most maximum
    
    // Set TP and SL based on TP distance
    double tp = entryPrice - tpDistance;
    double sl = entryPrice + (tpDistance * 3);  // SL is 3x TP distance above entry
    double volumes[];
    CalculateVolume(currentRiskAmount, entryPrice, sl, _Symbol, volumes);
    
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

// Helper to remove item from array by value
void RemoveFromList(ulong &list[], ulong value) {
    int size = ArraySize(list);
    for (int i = 0; i < size; i++) {
        if (list[i] == value) {
            // Swap with last element and resize
            if (i < size - 1) {
                list[i] = list[size - 1];
            }
            ArrayResize(list, size - 1);
            return;
        }
    }
}

// Check for closed positions and adjust risk accordingly
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
            
            // Adjust risk based on result
            if (found) {
                if (dealProfit > 0) {
                    HandleWin();
                } else if (dealProfit < 0) {
                    HandleLoss();
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

// Handle win - increment consecutive wins and potentially double risk
void HandleWin() {
    consecutiveWins++;
    
    if (consecutiveWins >= winsToRecover) {
        // Double the risk, but cap at original
        double newRisk = currentRiskAmount * 2.0;
        currentRiskAmount = MathMin(newRisk, originalRiskAmount);
        consecutiveWins = 0; // Reset counter
        Print("Win recorded. Risk doubled to ", DoubleToString(currentRiskAmount, 2), " (capped at ", DoubleToString(originalRiskAmount, 2), ")");
    } else {
        Print("Win recorded. Consecutive wins: ", consecutiveWins, "/", winsToRecover);
    }
}

// Handle loss - halve the risk amount
void HandleLoss() {
    consecutiveWins = 0; // Reset consecutive wins
    currentRiskAmount = currentRiskAmount / 2.0;
    Print("Loss recorded. Risk halved to ", DoubleToString(currentRiskAmount, 2));
}
