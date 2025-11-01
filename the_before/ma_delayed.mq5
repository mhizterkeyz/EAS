#include <Trade\Trade.mqh>

// Input parameters
input ENUM_TIMEFRAMES TimeFrame = PERIOD_H1;     // Trading timeframe
input int StopSize = 50;                         // Stop size in points
input int MAFastPeriod = 10;                     // Fast MA period
input int MASlowPeriod = 20;                     // Slow MA period
input double RiskAmount = 100;                   // Risk amount per trade
input double RR = 10;                            // Risk to reward ratio
input double MaxLotSize = 1.0;                   // Maximum lot size per order
input double MaxSpread = 20;                     // Maximum allowed spread in points
input int MaxConcurrentTrades = 5;               // Maximum concurrent trades allowed
input bool EnableLogging = true;                 // Enable error logging

// Global variables
CTrade Trade;
datetime PreviousTime;
string TradeComment = "MA_DELAYED";
int fastHandle = INVALID_HANDLE;
int slowHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit() {
    // Initialize trade settings
    Trade.SetDeviationInPoints(10);
    Trade.SetTypeFilling(ORDER_FILLING_FOK);
    Trade.SetExpertMagicNumber(123456);
    
    SendNotification(TradeComment + " Loaded!");
    PreviousTime = iTime(_Symbol, TimeFrame, 0);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    if(fastHandle != INVALID_HANDLE) IndicatorRelease(fastHandle);
    if(slowHandle != INVALID_HANDLE) IndicatorRelease(slowHandle);
    LogMessage("EA deinitialized. Reason: " + IntegerToString(reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick() {
    if(iTime(_Symbol, TimeFrame, 0) != PreviousTime) {
        PreviousTime = iTime(_Symbol, TimeFrame, 0);
        
        if(!IsSymbolInUse(_Symbol) && CanTrade()) {
            string signal = CheckCrossover();
            
            if(signal == "buy")
                PlaceBuyOrder();
            else if(signal == "sell")
                PlaceSellOrder();
        }
    }
    
    CheckAndCloseOrders();
}

//+------------------------------------------------------------------+
//| Check for MA crossover                                            |
//+------------------------------------------------------------------+
string CheckCrossover() {
    if(fastHandle == INVALID_HANDLE) {
        fastHandle = iMA(_Symbol, TimeFrame, MAFastPeriod, 0, MODE_SMA, PRICE_CLOSE);
        if(fastHandle == INVALID_HANDLE) {
            LogMessage("Failed to create fast MA handle");
            return "";
        }
    }
    
    if(slowHandle == INVALID_HANDLE) {
        slowHandle = iMA(_Symbol, TimeFrame, MASlowPeriod, 0, MODE_SMA, PRICE_CLOSE);
        if(slowHandle == INVALID_HANDLE) {
            LogMessage("Failed to create slow MA handle");
            return "";
        }
    }
    
    double fastMA[], slowMA[];
    ArraySetAsSeries(fastMA, true);
    ArraySetAsSeries(slowMA, true);
    
    if(CopyBuffer(fastHandle, 0, 0, 3, fastMA) != 3 || 
       CopyBuffer(slowHandle, 0, 0, 3, slowMA) != 3) {
        LogMessage("Failed to copy MA data");
        return "";
    }
    
    string signal = "";
    if(fastMA[1] > slowMA[1] && fastMA[2] <= slowMA[2])
        signal = "buy";
    else if(fastMA[1] < slowMA[1] && fastMA[2] >= slowMA[2])
        signal = "sell";
    
    return signal;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                             |
//+------------------------------------------------------------------+
void CalculateVolume(double riskAmount, double entryPrice, double stopLoss, string symbol, double &volumes[]) {
    double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    // Calculate pip value
    double pipValue = tickValue * (pointSize / tickSize);
    
    // Calculate stop loss in points
    double stopPoints = MathAbs(entryPrice - stopLoss) / pointSize;
    
    // Calculate total volume
    double totalVolume = (riskAmount / (stopPoints * pipValue));
    
    // Adjust for maximum lot size
    int numOrders = (int)MathCeil(totalVolume / MaxLotSize);
    double volumePerOrder = totalVolume / numOrders;
    
    // Round to nearest lot step
    volumePerOrder = MathFloor(volumePerOrder / lotStep) * lotStep;
    
    // Ensure volume is within limits
    volumePerOrder = MathMax(minLot, MathMin(maxLot, volumePerOrder));
    
    // Resize array and fill with volumes
    ArrayResize(volumes, numOrders);
    for(int i = 0; i < numOrders; i++) {
        volumes[i] = volumePerOrder;
    }
}

//+------------------------------------------------------------------+
//| Place buy stop order                                              |
//+------------------------------------------------------------------+
void PlaceBuyOrder() {
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double points = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double entryPrice = currentPrice - (2 * StopSize * points);
    double stopLoss = entryPrice - (StopSize * points);
    double takeProfit = entryPrice + (RR * (entryPrice - stopLoss));
    
    double volumes[];
    CalculateVolume(RiskAmount, entryPrice, stopLoss, _Symbol, volumes);
    
    for(int i = 0; i < ArraySize(volumes); i++) {
        if(!Trade.BuyLimit(volumes[i], entryPrice, _Symbol, stopLoss, takeProfit, 0, 0, TradeComment)) {
            LogMessage("Buy order failed. Error: " + IntegerToString(GetLastError()));
            continue;
        }
        LogMessage("Buy order placed: Volume=" + DoubleToString(volumes[i], 2) + 
                  ", Entry=" + DoubleToString(entryPrice, _Digits));
    }
}

//+------------------------------------------------------------------+
//| Place sell stop order                                             |
//+------------------------------------------------------------------+
void PlaceSellOrder() {
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double points = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double entryPrice = currentPrice + (2 * StopSize * points);
    double stopLoss = entryPrice + (StopSize * points);
    double takeProfit = entryPrice - (RR * (stopLoss - entryPrice));
    
    double volumes[];
    CalculateVolume(RiskAmount, entryPrice, stopLoss, _Symbol, volumes);
    
    for(int i = 0; i < ArraySize(volumes); i++) {
        if(!Trade.SellLimit(volumes[i], entryPrice, _Symbol, stopLoss, takeProfit, 0, 0, TradeComment)) {
            LogMessage("Sell order failed. Error: " + IntegerToString(GetLastError()));
            continue;
        }
        LogMessage("Sell order placed: Volume=" + DoubleToString(volumes[i], 2) + 
                  ", Entry=" + DoubleToString(entryPrice, _Digits));
    }
}

//+------------------------------------------------------------------+
//| Check if symbol is already in use                                 |
//+------------------------------------------------------------------+
bool IsSymbolInUse(string symbol) {
    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderGetString(ORDER_SYMBOL) == symbol && OrderGetString(ORDER_COMMENT) == TradeComment)
            return true;
    }
    
    for (int i = 0; i < PositionsTotal(); i++) {
        if (PositionGetString(POSITION_SYMBOL) == symbol && PositionGetString(POSITION_COMMENT) == TradeComment)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check and close orders if price goes past TP or SL                |
//+------------------------------------------------------------------+
void CheckAndCloseOrders() {
    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i) && OrderGetString(ORDER_COMMENT) == TradeComment) {
            double currentPrice = OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT ? 
                                SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                                SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
            double orderTP = OrderGetDouble(ORDER_TP);
            double orderSL = OrderGetDouble(ORDER_SL);
            
            bool shouldDelete = false;
            
            // Check if price has gone past entry price in wrong direction
            if ((OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT && currentPrice < orderPrice - (StopSize * _Point)) ||
                (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT && currentPrice > orderPrice + (StopSize * _Point))) {
                shouldDelete = true;
                LogMessage("Order deleted - price moved away from entry");
            }
            
            // Check if price has gone past TP or SL levels
            if (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT) {
                if (currentPrice >= orderTP || currentPrice <= orderSL) {
                    shouldDelete = true;
                    LogMessage("Order deleted - price crossed TP/SL without triggering");
                }
            } else if (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT) {
                if (currentPrice <= orderTP || currentPrice >= orderSL) {
                    shouldDelete = true;
                    LogMessage("Order deleted - price crossed TP/SL without triggering");
                }
            }
            
            if (shouldDelete) {
                Trade.OrderDelete(OrderGetInteger(ORDER_TICKET));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Log message to file and terminal                                   |
//+------------------------------------------------------------------+
void LogMessage(string message) {
    if(!EnableLogging) return;
    
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
    string logMessage = timestamp + " | " + message;
    
    Print(logMessage);
    int handle = FileOpen("MA_Delayed_Log.txt", FILE_WRITE|FILE_READ|FILE_TXT|FILE_SHARE_READ|FILE_SHARE_WRITE);
    if(handle != INVALID_HANDLE) {
        FileSeek(handle, 0, SEEK_END);
        FileWriteString(handle, logMessage + "\n");
        FileClose(handle);
    }
}

//+------------------------------------------------------------------+
//| Check if new trades are allowed                                    |
//+------------------------------------------------------------------+
bool CanTrade() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double currentSpread = ask - bid;
    if(currentSpread > MaxSpread * SymbolInfoDouble(_Symbol, SYMBOL_POINT)) {
        LogMessage("Spread too high: " + DoubleToString(currentSpread, 1));
        return false;
    }
    
    int totalTrades = 0;
    for(int i = 0; i < OrdersTotal(); i++) {
        if(OrderSelect(i) && OrderGetString(ORDER_COMMENT) == TradeComment)
            totalTrades++;
    }
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionSelectByTicket(PositionGetTicket(i)) && 
           PositionGetString(POSITION_COMMENT) == TradeComment)
            totalTrades++;
    }
    
    if(totalTrades >= MaxConcurrentTrades) {
        LogMessage("Maximum concurrent trades reached: " + IntegerToString(totalTrades));
        return false;
    }
    
    return true;
}
