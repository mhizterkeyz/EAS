//16_11_25.mq5
#include <Trade\Trade.mqh>

CTrade Trade;

// General Inputs
input double riskAmountPerTrade = 200; // Risk amount per trade

// Strategy 1 Inputs
input double strategy1SlMultiplier = 3.3; // SL multiplier for strategy 1

// Strategy 2 Inputs
input double distanceFromNeckLineToPlaceOrder = 30; // Distance from neck line to place order in points
input double distanceFromNecLineToEnter = 10; // Distance from neck line to enter order in points
input double strategy2SlMultiplier = 3.3; // SL multiplier for strategy 2
input double strategy2Bias = 0; // Bias, 0 = neutral, 1 = bullish, 2 = bearish


int OnInit() {
    return(INIT_SUCCEEDED);
}

bool IsBullish(int index) {
    return iClose(_Symbol, PERIOD_CURRENT, index) > iOpen(_Symbol, PERIOD_CURRENT, index);
}

bool IsBearish(int index) {
    return iClose(_Symbol, PERIOD_CURRENT, index) < iOpen(_Symbol, PERIOD_CURRENT, index);
}

void GetNeckLines(double &buyNeckLine, double &sellNeckLine) {

    // - Buy Neck Line
    //  - 2 bullish, 1 bearish, 3 open and close below close of 2
    if (
        IsBullish(2) &&
        IsBearish(1) &&
        MathMax(iClose(_Symbol, PERIOD_CURRENT, 3), iOpen(_Symbol, PERIOD_CURRENT, 3)) < iClose(_Symbol, PERIOD_CURRENT, 2)
    ) {
        buyNeckLine = iClose(_Symbol, PERIOD_CURRENT, 2);
    }

    // - Sell Neck Line
    //  - 2 bearish, 1 bullish, 3 open and close above open of 2
    if (
        IsBearish(2) &&
        IsBullish(1) &&
        MathMin(iClose(_Symbol, PERIOD_CURRENT, 3), iOpen(_Symbol, PERIOD_CURRENT, 3)) > iClose(_Symbol, PERIOD_CURRENT, 2)
    ) {
        sellNeckLine = iClose(_Symbol, PERIOD_CURRENT, 2);
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

bool hasPendingOrders(bool isBuy = true) {
    for (int i = 0; i < OrdersTotal(); i++) {
        ulong ticket = OrderGetTicket(i);
        if (ticket > 0 && OrderSelect(ticket)) {
            if (OrderGetString(ORDER_SYMBOL) == _Symbol) {
                ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                if (isBuy && (orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_STOP_LIMIT)) {
                    return true;
                }
                if (!isBuy && (orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL_STOP || orderType == ORDER_TYPE_SELL_STOP_LIMIT)) {
                    return true;
                }
            }
        }
    }
    return false;
}

void Buy() {
    double entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double tp = MathMax(iClose(_Symbol, PERIOD_CURRENT, 2), iOpen(_Symbol, PERIOD_CURRENT, 1));
    double sl = entryPrice - (tp - entryPrice) * strategy1SlMultiplier;

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
    double tp = MathMin(iClose(_Symbol, PERIOD_CURRENT, 2), iOpen(_Symbol, PERIOD_CURRENT, 1));
    double sl = entryPrice + (entryPrice - tp) * strategy1SlMultiplier;

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

void OnTickStrategy1() {
    static double buyNeckLine;
    static double sellNeckLine;
    static int lossCount = 0;
    static ulong lastCheckedDealTicket = 0;
    
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double diffBetweenCurrentPriceAndBuyNeckLine = currentPrice - buyNeckLine;
    double diffBetweenCurrentPriceAndSellNeckLine = currentPrice - sellNeckLine;

    // Check for new closed deals and count consecutive losses
    if (HistorySelect(0, TimeCurrent())) {
        int totalDeals = HistoryDealsTotal();
        for (int i = 0; i < totalDeals; i++) {
            ulong dealTicket = HistoryDealGetTicket(i);
            if (dealTicket > 0 && dealTicket > lastCheckedDealTicket) {
                if (HistoryDealGetString(dealTicket, DEAL_SYMBOL) == _Symbol) {
                    ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
                    // Only count closing deals (DEAL_ENTRY_OUT)
                    if (dealEntry == DEAL_ENTRY_OUT) {
                        double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                        double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
                        double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                        double totalProfit = profit + swap + commission;
                        
                        // Reset count on win, increment on loss
                        if (totalProfit > 0) {
                            lossCount = 0; // Reset consecutive loss count on win
                        } else if (totalProfit < 0) {
                            lossCount++; // Increment consecutive loss count
                        }
                    }
                }
                lastCheckedDealTicket = dealTicket;
            }
        }
    }

    GetNeckLines(buyNeckLine, sellNeckLine);

    if (iHigh(_Symbol, PERIOD_CURRENT, 0) >= buyNeckLine) {
        buyNeckLine = 0;
    }

    if (iLow(_Symbol, PERIOD_CURRENT, 0) <= sellNeckLine) {
        sellNeckLine = 0;
    }
    
    DrawHorizontalLine("buyNeckLine", buyNeckLine, clrGreen);
    DrawHorizontalLine("sellNeckLine", sellNeckLine, clrRed);

    Comment(
        "Strategy1"
        +"\nBuy Neck Line: " + DoubleToString(buyNeckLine)
        +"\nSell Neck Line: " + DoubleToString(sellNeckLine)
        +"\nDiff Between Current Price And Buy Neck Line: " + DoubleToString(diffBetweenCurrentPriceAndBuyNeckLine)
        +"\nDiff Between Current Price And Sell Neck Line: " + DoubleToString(diffBetweenCurrentPriceAndSellNeckLine)
        +"\nConsecutive Loss Count: " + IntegerToString(lossCount)
    );

    static datetime lastTime = iTime(Symbol(), PERIOD_CURRENT, 0);
    if (lastTime == iTime(Symbol(), PERIOD_CURRENT, 0)) {
        return;
    }

    lastTime = iTime(Symbol(), PERIOD_CURRENT, 0);

    if (diffBetweenCurrentPriceAndBuyNeckLine >= 3) {
        Buy();
    } 
    
    if (diffBetweenCurrentPriceAndSellNeckLine >= 3) {
        Sell();
    }
}

void BuyStop(double buyNeckLine) {
    double entryPrice = buyNeckLine - distanceFromNecLineToEnter;
    double tp = buyNeckLine;
    double sl = entryPrice - (tp - entryPrice) * strategy2SlMultiplier;

    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);

    if (ArraySize(volumes) == 0) {
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        AddToList(volumes, minVolume);
    }

    // Calculate end of day expiry
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    dt.hour = 23;
    dt.min = 59;
    dt.sec = 59;
    datetime expiry = StructToTime(dt);

    for (int i = 0; i < ArraySize(volumes); i++) {
        Trade.BuyStop(volumes[i], entryPrice, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiry);
    }
}

void SellStop(double sellNeckLine) {
    double entryPrice = sellNeckLine + distanceFromNecLineToEnter;
    double tp = sellNeckLine;
    double sl = entryPrice + (entryPrice - tp) * strategy2SlMultiplier;

    double volumes[];
    CalculateVolume(riskAmountPerTrade, entryPrice, sl, _Symbol, volumes);

    if (ArraySize(volumes) == 0) {
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        AddToList(volumes, minVolume);
    }

    // Calculate end of day expiry
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    dt.hour = 23;
    dt.min = 59;
    dt.sec = 59;
    datetime expiry = StructToTime(dt);

    for (int i = 0; i < ArraySize(volumes); i++) {
        Trade.SellStop(volumes[i], entryPrice, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiry);
    }
}

void OnTickStrategy2() {
    static double buyNeckLine;
    static double sellNeckLine;
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double diffBetweenCurrentPriceAndBuyNeckLine = buyNeckLine - currentPrice;
    double diffBetweenCurrentPriceAndSellNeckLine = currentPrice - sellNeckLine;

    GetNeckLines(buyNeckLine, sellNeckLine);

    DrawHorizontalLine("buyNeckLine", buyNeckLine, clrGreen);
    DrawHorizontalLine("sellNeckLine", sellNeckLine, clrRed);

    Comment(
        "Strategy2"
        +"\nBuy Neck Line: " + DoubleToString(buyNeckLine)
        +"\nSell Neck Line: " + DoubleToString(sellNeckLine)
        +"\nDiff Between Current Price And Buy Neck Line: " + DoubleToString(diffBetweenCurrentPriceAndBuyNeckLine)
        +"\nDiff Between Current Price And Sell Neck Line: " + DoubleToString(diffBetweenCurrentPriceAndSellNeckLine)
    );

    if (
        buyNeckLine > 0 && 
        diffBetweenCurrentPriceAndBuyNeckLine >= distanceFromNeckLineToPlaceOrder && 
        !hasPendingOrders(true) &&
        !hasOpenPositions(true) &&
        strategy2Bias != 2
    ) {
        BuyStop(buyNeckLine);
    } 
    
    if (
        sellNeckLine > 0 && 
        diffBetweenCurrentPriceAndSellNeckLine >= distanceFromNeckLineToPlaceOrder && 
        !hasPendingOrders(false) &&
        !hasOpenPositions(false) &&
        strategy2Bias != 1
    ) {
        SellStop(sellNeckLine);
    }
}


void OnTick() {
    // OnTickStrategy1();
    OnTickStrategy2();
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

