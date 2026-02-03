// 18_11_25.mq5
#include <Trade\Trade.mqh>

CTrade Trade;

input double riskAmountPerTrade = 200; // Risk amount per trade
input double distanceFromNeckLineToPlaceOrder = 20; // Distance from neck line to place order in points
input double tpMultiplier = 1.5; // TP multiplier
input int MAGIC_NUMBER = 123456; // Magic number for trade identification

int OnInit() {
    Trade.SetExpertMagicNumber(MAGIC_NUMBER);
    return(INIT_SUCCEEDED);
}

void OnTick() {
    static double firstBuyNeckLine = 0;
    static double firstSellNeckLine = 0;
    if (firstBuyNeckLine == 0) {
        LoadFirstNeckLines(firstBuyNeckLine, firstSellNeckLine);
    }
    static double buyNeckLine = firstBuyNeckLine;
    static double sellNeckLine = firstSellNeckLine;
    static double lastUsedBuyNeckLine = 0;
    static double lastUsedSellNeckLine = 0;
    static bool buyNeckLineUsed = false;
    static bool sellNeckLineUsed = false;
    
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double diffBetweenCurrentPriceAndBuyNeckLine = buyNeckLine - currentPrice;
    double diffBetweenCurrentPriceAndSellNeckLine = currentPrice - sellNeckLine;

    GetNeckLines(buyNeckLine, sellNeckLine, buyNeckLineUsed, sellNeckLineUsed);
    
    // Reset used flags if neck lines have changed
    if (buyNeckLine > 0 && buyNeckLine != lastUsedBuyNeckLine) {
        buyNeckLineUsed = false;
        lastUsedBuyNeckLine = buyNeckLine;
    }
    
    if (sellNeckLine > 0 && sellNeckLine != lastUsedSellNeckLine) {
        sellNeckLineUsed = false;
        lastUsedSellNeckLine = sellNeckLine;
    }
    
    DrawHorizontalLine("buyNeckLine", buyNeckLine, clrGreen);
    DrawHorizontalLine("sellNeckLine", sellNeckLine, clrRed);

    Comment(
        "Buy Neck Line: " + DoubleToString(buyNeckLine)
        +"\nSell Neck Line: " + DoubleToString(sellNeckLine)
        +"\nDiff Between Current Price And Buy Neck Line: " + DoubleToString(diffBetweenCurrentPriceAndBuyNeckLine)
        +"\nDiff Between Current Price And Sell Neck Line: " + DoubleToString(diffBetweenCurrentPriceAndSellNeckLine)
    );
    
    if (PositionsTotal() > 0) {
        ManageTrade();
        return;
    }

    if (
        buyNeckLine > 0 &&
        diffBetweenCurrentPriceAndBuyNeckLine >= distanceFromNeckLineToPlaceOrder &&
        !hasOpenPositions(false) &&
        !buyNeckLineUsed
    ) {
        Sell(buyNeckLine);
        buyNeckLineUsed = true;
    }

    if (
        sellNeckLine > 0 &&
        diffBetweenCurrentPriceAndSellNeckLine >= distanceFromNeckLineToPlaceOrder &&
        !hasOpenPositions(true) &&
        !sellNeckLineUsed
    ) {
        Buy(sellNeckLine);
        sellNeckLineUsed = true;
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

void Buy(double sellNeckLine) {
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double sl = sellNeckLine;
    double tp = entryPrice + (entryPrice - sl) * tpMultiplier;

    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);

    if (ArraySize(volumes) == 0) {
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        AddToList(volumes, minVolume);
    }

    Trade.SetExpertMagicNumber(MAGIC_NUMBER);
    for (int i = 0; i < ArraySize(volumes); i++) {
        Trade.Buy(volumes[i], _Symbol, 0, sl, tp);
    }
}

void Sell(double buyNeckLine) {
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double sl = buyNeckLine;
    double tp = entryPrice - (sl - entryPrice) * tpMultiplier;

    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);

    if (ArraySize(volumes) == 0) {
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        AddToList(volumes, minVolume);
    }

    Trade.SetExpertMagicNumber(MAGIC_NUMBER);
    for (int i = 0; i < ArraySize(volumes); i++) {
        Trade.Sell(volumes[i], _Symbol, 0, sl, tp);
    }
}

bool IsBullish(int index) {
    return iClose(_Symbol, PERIOD_CURRENT, index) > iOpen(_Symbol, PERIOD_CURRENT, index);
}

bool IsBearish(int index) {
    return iClose(_Symbol, PERIOD_CURRENT, index) < iOpen(_Symbol, PERIOD_CURRENT, index);
}

void LoadFirstNeckLines(double &buyNeckLine, double &sellNeckLine) {
    buyNeckLine = 0;
    sellNeckLine = 0;
    
    // Loop from current candle (index 0) backwards
    for (int i = 0; i < Bars(_Symbol, PERIOD_CURRENT) - 3; i++) {
        // Check for Buy Neck Line: candle at i+2 is bullish, i+1 is bearish, 
        // and max(close(i+3), open(i+3)) < close(i+2)
        if (buyNeckLine == 0 && 
            IsBullish(i + 2) && 
            IsBearish(i + 1) &&
            MathMax(iClose(_Symbol, PERIOD_CURRENT, i + 3), iOpen(_Symbol, PERIOD_CURRENT, i + 3)) < iClose(_Symbol, PERIOD_CURRENT, i + 2)) {
            buyNeckLine = iClose(_Symbol, PERIOD_CURRENT, i + 2);
        }
        
        // Check for Sell Neck Line: candle at i+2 is bearish, i+1 is bullish,
        // and min(close(i+3), open(i+3)) > close(i+2)
        if (sellNeckLine == 0 && 
            IsBearish(i + 2) && 
            IsBullish(i + 1) &&
            MathMin(iClose(_Symbol, PERIOD_CURRENT, i + 3), iOpen(_Symbol, PERIOD_CURRENT, i + 3)) > iClose(_Symbol, PERIOD_CURRENT, i + 2)) {
            sellNeckLine = iClose(_Symbol, PERIOD_CURRENT, i + 2);
        }
        
        // Stop if both necklines are found
        if (buyNeckLine > 0 && sellNeckLine > 0) {
            break;
        }
    }
}

void GetNeckLines(double &buyNeckLine, double &sellNeckLine, bool &buyNeckLineUsed, bool &sellNeckLineUsed) {

    // - Buy Neck Line
    //  - 2 bullish, 1 bearish, 3 open and close below close of 2
    if (
        IsBullish(2) &&
        IsBearish(1) &&
        MathMax(iClose(_Symbol, PERIOD_CURRENT, 3), iOpen(_Symbol, PERIOD_CURRENT, 3)) < iClose(_Symbol, PERIOD_CURRENT, 2)
    ) {
        if (
            buyNeckLine == 0 ||
            buyNeckLineUsed ||
            iClose(_Symbol, PERIOD_CURRENT, 2) - buyNeckLine > 0 ||
            buyNeckLine - iClose(_Symbol, PERIOD_CURRENT, 2) > distanceFromNeckLineToPlaceOrder
        ) {
            buyNeckLine = iClose(_Symbol, PERIOD_CURRENT, 2);
        }
    }

    // - Sell Neck Line
    //  - 2 bearish, 1 bullish, 3 open and close above open of 2
    if (
        IsBearish(2) &&
        IsBullish(1) &&
        MathMin(iClose(_Symbol, PERIOD_CURRENT, 3), iOpen(_Symbol, PERIOD_CURRENT, 3)) > iClose(_Symbol, PERIOD_CURRENT, 2)
    ) {
        if (
            sellNeckLine == 0 ||
            sellNeckLineUsed ||
            sellNeckLine - iClose(_Symbol, PERIOD_CURRENT, 2) > 0 ||
            iClose(_Symbol, PERIOD_CURRENT, 2) - sellNeckLine > distanceFromNeckLineToPlaceOrder
        ) {
            sellNeckLine = iClose(_Symbol, PERIOD_CURRENT, 2);
        }
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

void ManageTrade() {
    static ulong trackedTickets[];
    static bool marker1Hit[];
    static bool marker2Hit[];
    static bool marker3Hit[];
    static bool marker4Hit[];
    static double originalEntry[];
    static double originalVolume[];
    static double originalSL[];
    static ENUM_POSITION_TYPE positionType[];
    
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    
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
                    originalSL[validCount] = originalSL[i];
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
        ArrayResize(originalSL, validCount);
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
            ArrayResize(originalSL, newSize);
            ArrayResize(positionType, newSize);
            
            trackIndex = newSize - 1;
            trackedTickets[trackIndex] = ticket;
            originalEntry[trackIndex] = PositionGetDouble(POSITION_PRICE_OPEN);
            originalVolume[trackIndex] = PositionGetDouble(POSITION_VOLUME);
            originalSL[trackIndex] = PositionGetDouble(POSITION_SL);
            positionType[trackIndex] = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            marker1Hit[trackIndex] = false;
            marker2Hit[trackIndex] = false;
            marker3Hit[trackIndex] = false;
            marker4Hit[trackIndex] = false;
        }
        
        // Manage this position
        double entry = originalEntry[trackIndex];
        double sl = originalSL[trackIndex];
        double slDistance = MathAbs(entry - sl); // Calculate SL distance dynamically
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
