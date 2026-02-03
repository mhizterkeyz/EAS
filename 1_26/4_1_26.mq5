// 4_1_26.mq5
#include <Trade\Trade.mqh>
CTrade Trade;


input int MAGIC_NUMBER = 123456;
input double SIZE = 20;
input double tpMultiplier = 3;
input double RiskAmount = 4000.0; // Risk amount per trade

bool Bias;

int OnInit()
{
    Bias = MathRand() % 2 == 0;

    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
    if (!HasOpenPosition()) {
        if (WasLastTradeLoss()) {
            Bias = !Bias;
        }
        if (Bias) {
            Buy();
        } else {
            Sell();
        }
    } else {
        ManageTrade();
    }
}

void Buy() {
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double sl = entryPrice - SIZE;
    double tp = entryPrice + (entryPrice - sl) * tpMultiplier;
    
    double volumes[];
    CalculateVolume(RiskAmount, entryPrice, sl, _Symbol, volumes);
    
    if (ArraySize(volumes) == 0) {
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        AddToList(volumes, minVolume);
    }
    
    Trade.SetExpertMagicNumber(MAGIC_NUMBER);
    for (int i = 0; i < ArraySize(volumes); i++) {
        Trade.Buy(volumes[i], _Symbol, 0, sl, tp);
    }
}

void Sell() {
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double sl = entryPrice + SIZE;
    double tp = entryPrice - (sl - entryPrice) * tpMultiplier;
    
    double volumes[];
    CalculateVolume(RiskAmount, entryPrice, sl, _Symbol, volumes);
    
    if (ArraySize(volumes) == 0) {
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        AddToList(volumes, minVolume);
    }
    
    Trade.SetExpertMagicNumber(MAGIC_NUMBER);
    for (int i = 0; i < ArraySize(volumes); i++) {
        Trade.Sell(volumes[i], _Symbol, 0, sl, tp);
    }
}

bool HasOpenPosition() {
    for (int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if (ticket > 0 && PositionSelectByTicket(ticket)) {
            if (PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER) {
                return true;
            }
        }
    }
    return false;
}

bool WasLastTradeLoss() {
    // Select history for the last day to find the most recent closed position
    datetime endTime = TimeCurrent();
    datetime startTime = endTime - PeriodSeconds(PERIOD_D1);
    
    if (!HistorySelect(startTime, endTime)) {
        return false; // No history available, assume not a loss (keep current bias)
    }
    
    // Find the most recent closed deal with our magic number
    ulong lastTicket = 0;
    datetime lastCloseTime = 0;
    
    for (int i = HistoryDealsTotal() - 1; i >= 0; i--) {
        ulong ticket = HistoryDealGetTicket(i);
        if (ticket == 0) continue;
        
        if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != MAGIC_NUMBER) continue;
        if (HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
        
        ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
        if (dealEntry != DEAL_ENTRY_OUT) continue; // Only look at exit deals
        
        datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
        if (dealTime > lastCloseTime) {
            lastCloseTime = dealTime;
            lastTicket = ticket;
        }
    }
    
    if (lastTicket == 0) {
        return false; // No closed trades found, assume not a loss
    }
    
    // Get the position ticket from the deal
    ulong positionTicket = HistoryDealGetInteger(lastTicket, DEAL_POSITION_ID);
    
    // Calculate total profit for this position
    double totalProfit = 0;
    for (int i = HistoryDealsTotal() - 1; i >= 0; i--) {
        ulong ticket = HistoryDealGetTicket(i);
        if (ticket == 0) continue;
        
        if (HistoryDealGetInteger(ticket, DEAL_POSITION_ID) == positionTicket) {
            totalProfit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
            totalProfit += HistoryDealGetDouble(ticket, DEAL_SWAP);
            totalProfit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        }
    }
    
    return totalProfit < 0; // Return true if total profit is negative (loss)
}

void ManageTrade() {
    static ulong trackedTickets[];
    static bool marker1Hit[];
    static bool marker2Hit[];
    static bool marker3Hit[];
    static bool marker4Hit[];
    static double originalEntry[];
    static double originalVolume[];
    static ENUM_POSITION_TYPE positionType[];
    
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double slDistance = SIZE;
    
    // First, clean up closed positions from tracking arrays
    int validCount = 0;
    for (int i = 0; i < ArraySize(trackedTickets); i++) {
        if (PositionSelectByTicket(trackedTickets[i])) {
            if (PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER) {
                // Keep this position in tracking
                if (validCount != i) {
                    trackedTickets[validCount] = trackedTickets[i];
                    marker1Hit[validCount] = marker1Hit[i];
                    marker2Hit[validCount] = marker2Hit[i];
                    marker3Hit[validCount] = marker3Hit[i];
                    marker4Hit[validCount] = marker4Hit[i];
                    originalEntry[validCount] = originalEntry[i];
                    originalVolume[validCount] = originalVolume[i];
                    positionType[validCount] = positionType[i];
                }
                validCount++;
            }
        }
    }
    
    // Resize arrays to remove closed positions
    if (validCount < ArraySize(trackedTickets)) {
        ArrayResize(trackedTickets, validCount);
        ArrayResize(marker1Hit, validCount);
        ArrayResize(marker2Hit, validCount);
        ArrayResize(marker3Hit, validCount);
        ArrayResize(marker4Hit, validCount);
        ArrayResize(originalEntry, validCount);
        ArrayResize(originalVolume, validCount);
        ArrayResize(positionType, validCount);
    }
    
    // Process all open positions with the magic number
    for (int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if (ticket == 0 || !PositionSelectByTicket(ticket)) continue;
        if (PositionGetInteger(POSITION_MAGIC) != MAGIC_NUMBER) continue;
        
        // Find or add this ticket to tracking
        int trackIndex = -1;
        for (int j = 0; j < ArraySize(trackedTickets); j++) {
            if (trackedTickets[j] == ticket) {
                trackIndex = j;
                break;
            }
        }
        
        // If not tracked, add it
        if (trackIndex == -1) {
            int newSize = ArraySize(trackedTickets) + 1;
            ArrayResize(trackedTickets, newSize);
            ArrayResize(marker1Hit, newSize);
            ArrayResize(marker2Hit, newSize);
            ArrayResize(marker3Hit, newSize);
            ArrayResize(marker4Hit, newSize);
            ArrayResize(originalEntry, newSize);
            ArrayResize(originalVolume, newSize);
            ArrayResize(positionType, newSize);
            
            trackIndex = newSize - 1;
            trackedTickets[trackIndex] = ticket;
            originalEntry[trackIndex] = PositionGetDouble(POSITION_PRICE_OPEN);
            originalVolume[trackIndex] = PositionGetDouble(POSITION_VOLUME);
            positionType[trackIndex] = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            marker1Hit[trackIndex] = false;
            marker2Hit[trackIndex] = false;
            marker3Hit[trackIndex] = false;
            marker4Hit[trackIndex] = false;
        }
        
        // Manage this position
        double entry = originalEntry[trackIndex];
        double origVol = originalVolume[trackIndex];
        double closeVolume = origVol * 0.25; // 25% of original volume
        ENUM_POSITION_TYPE posType = positionType[trackIndex];
        
        double marker1, marker2, marker3, marker4;
        
        if (posType == POSITION_TYPE_BUY) {
            // For buy: SL is below entry, markers are between entry and SL
            marker1 = entry - slDistance * 0.25;
            marker2 = entry - slDistance * 0.50;
            marker3 = entry - slDistance * 0.75;
            marker4 = entry - slDistance * 1.00;
            
            // Check if price has hit markers (price moving down towards SL)
            if (!marker1Hit[trackIndex] && currentPrice <= marker1) {
                Trade.PositionClosePartial(ticket, closeVolume);
                marker1Hit[trackIndex] = true;
            } else if (!marker2Hit[trackIndex] && currentPrice <= marker2) {
                Trade.PositionClosePartial(ticket, closeVolume);
                marker2Hit[trackIndex] = true;
            } else if (!marker3Hit[trackIndex] && currentPrice <= marker3) {
                Trade.PositionClosePartial(ticket, closeVolume);
                marker3Hit[trackIndex] = true;
            } else if (!marker4Hit[trackIndex] && currentPrice <= marker4) {
                Trade.PositionClosePartial(ticket, closeVolume);
                marker4Hit[trackIndex] = true;
            }
        } else if (posType == POSITION_TYPE_SELL) {
            // For sell: SL is above entry, markers are between entry and SL
            marker1 = entry + slDistance * 0.25;
            marker2 = entry + slDistance * 0.50;
            marker3 = entry + slDistance * 0.75;
            marker4 = entry + slDistance * 1.00;
            
            // Check if price has hit markers (price moving up towards SL)
            if (!marker1Hit[trackIndex] && currentPrice >= marker1) {
                Trade.PositionClosePartial(ticket, closeVolume);
                marker1Hit[trackIndex] = true;
            } else if (!marker2Hit[trackIndex] && currentPrice >= marker2) {
                Trade.PositionClosePartial(ticket, closeVolume);
                marker2Hit[trackIndex] = true;
            } else if (!marker3Hit[trackIndex] && currentPrice >= marker3) {
                Trade.PositionClosePartial(ticket, closeVolume);
                marker3Hit[trackIndex] = true;
            } else if (!marker4Hit[trackIndex] && currentPrice >= marker4) {
                Trade.PositionClosePartial(ticket, closeVolume);
                marker4Hit[trackIndex] = true;
            }
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

