// 18_11_25.mq5
#include <Trade\Trade.mqh>

CTrade Trade;

input double riskAmountPerTrade = 200; // Risk amount per trade
input double distanceFromNeckLineToPlaceOrder = 20; // Distance from neck line to place order in points
input double tpMultiplier = 1.5; // TP multiplier

int OnInit() {
    return(INIT_SUCCEEDED);
}

void OnTick() {
    static double buyNeckLine = 0;
    static double sellNeckLine = 0;
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
