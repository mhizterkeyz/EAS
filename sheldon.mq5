#include <Trade\Trade.mqh>

// Input parameters
input ENUM_TIMEFRAMES TimeFrame = PERIOD_M5;     // Trading timeframe
input int SMAPeriod = 20;                        // SMA period
input double RiskAmount = 100;                   // Risk amount per trade
input double RR = 20;                             // Risk to reward ratio
input bool EnableLogging = true;                 // Enable error logging
input int MaxTrades = 10;                         // Maximum number of trades

// Global variables
CTrade Trade;
string TradeComment = "SMA_STRATEGY";
datetime PreviousTime;
double previousClose = 0; // Variable to store the previous close
int currentTradeCount = 0; // Counter for the number of trades
int lastMonth = 0; // Variable to store the last month
double initialBalance = 0; // Track the initial balance
bool tpHitThisMonth = false; // Track if TP has been hit this month

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit() {
    SendNotification(TradeComment + " Loaded!");
    PreviousTime = iTime(_Symbol, TimeFrame, 0);
    previousClose = iClose(_Symbol, TimeFrame, 1); // Initialize previous close
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick() {
    // Check if the month has changed
    MqlDateTime currentTime;
    TimeToStruct(TimeCurrent(), currentTime);
    int currentMonth = currentTime.mon;

    if (currentMonth != lastMonth) {
        currentTradeCount = 0; // Reset trade count
        lastMonth = currentMonth; // Update last month
        initialBalance = AccountInfoDouble(ACCOUNT_BALANCE); // Reset initial balance
        tpHitThisMonth = false; // Reset TP hit status for the new month
    }

    if (tpHitThisMonth) {
        return; // Stop trading if TP has been hit this month
    }

    if(iTime(_Symbol, TimeFrame, 0) != PreviousTime) {
        PreviousTime = iTime(_Symbol, TimeFrame, 0);
        CheckForTrade();
    }

    // Manage existing trades
    // ManageTrades();

    // Check if the balance has increased
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    if (currentBalance > initialBalance) {
        tpHitThisMonth = true; // Set the flag if TP is hit
        LogMessage("Take profit hit - stopping trades for this month");
        SendNotification("Take profit hit - stopping trades for this month");
    }
}

//+------------------------------------------------------------------+
//| Check for trade signals based on SMA crossover                    |
//+------------------------------------------------------------------+
void CheckForTrade() {
    // Check if there are any open positions or if max trades reached
    if (PositionsTotal() > 0 || currentTradeCount >= MaxTrades) {
        return; // Exit if there are open positions or max trades reached
    }

    // Create a handle for the SMA indicator
    int smaHandle = iMA(_Symbol, TimeFrame, SMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
    double smaValue[];
    
    // Copy the latest SMA value into the buffer
    if (CopyBuffer(smaHandle, 0, 0, 1, smaValue) <= 0) {
        LogMessage("Failed to copy SMA data. Error: " + IntegerToString(GetLastError()));
        return; // Exit if copying failed
    }

    double currentClose = iClose(_Symbol, TimeFrame, 1); // Use the previous candle's close
    
    // Check for crossover
    if (previousClose < smaValue[0] && currentClose > smaValue[0]) {
        PlaceBuyOrder(currentClose, smaValue[0]);
    } else if (previousClose > smaValue[0] && currentClose < smaValue[0]) {
        PlaceSellOrder(currentClose, smaValue[0]);
    }

    // Update previous close for the next tick
    previousClose = currentClose; // Update to the current candle's close for the next tick
}

//+------------------------------------------------------------------+
//| Place buy order                                                   |
//+------------------------------------------------------------------+
void PlaceBuyOrder(double currentClose, double smaValue) {
    double stopLoss = currentClose - (currentClose - iLow(_Symbol, TimeFrame, 1)) / 2;
    double takeProfit = currentClose + (currentClose - stopLoss) * RR;

    double volumes[]; // Array to hold calculated volumes
    CalculateVolume(RiskAmount, currentClose, stopLoss, _Symbol, volumes); // Call the updated CalculateVolume

    // Place orders for each volume calculated
    bool orderSuccessful = false;
    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        if (!Trade.Buy(volume, _Symbol, currentClose, stopLoss, takeProfit, TradeComment)) {
            LogMessage("Buy order failed. Error: " + IntegerToString(GetLastError()));
        } else {
            LogMessage("Buy order placed: Volume=" + DoubleToString(volume, 2) + 
                        ", Entry=" + DoubleToString(currentClose, _Digits));
            orderSuccessful = true;
        }
    }

    if (orderSuccessful) {
        currentTradeCount++; // Increment trade count
        initialBalance = AccountInfoDouble(ACCOUNT_BALANCE); // Set initial balance on trade
    }
}

//+------------------------------------------------------------------+
//| Place sell order                                                  |
//+------------------------------------------------------------------+
void PlaceSellOrder(double currentClose, double smaValue) {
    double stopLoss = currentClose + (iHigh(_Symbol, TimeFrame, 1) - currentClose) / 2;
    double takeProfit = currentClose - (stopLoss - currentClose) * RR;

    double volumes[]; // Array to hold calculated volumes
    CalculateVolume(RiskAmount, currentClose, stopLoss, _Symbol, volumes); // Call the updated CalculateVolume

    // Place orders for each volume calculated
    bool orderSuccessful = false;
    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        if (!Trade.Sell(volume, _Symbol, currentClose, stopLoss, takeProfit, TradeComment)) {
            LogMessage("Sell order failed. Error: " + IntegerToString(GetLastError()));
        } else {
            LogMessage("Sell order placed: Volume=" + DoubleToString(volume, 2) + 
                        ", Entry=" + DoubleToString(currentClose, _Digits));
            orderSuccessful = true;
        }
    }

    if (orderSuccessful) {
        currentTradeCount++; // Increment trade count
        initialBalance = AccountInfoDouble(ACCOUNT_BALANCE); // Set initial balance on trade
    }
}

void CalculateVolume(double riskAmount, double entryPrice, double stopLoss, string symbol, double &volumes[]) {
    double volumeMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double volumeMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double profitForMinLot = 0.0;

    // Check profit for minimum lot size
    if (!OrderCalcProfit(ORDER_TYPE_BUY, symbol, volumeMin, MathMin(entryPrice, stopLoss), MathMax(entryPrice, stopLoss), profitForMinLot)) {
        AddToList(volumes, volumeMin);
        return; // Exit if profit calculation fails
    }

    // Calculate initial volume
    double volume = NormalizeDouble((riskAmount * volumeMin) / profitForMinLot, GetDecimalPlaces(lotStep));

    // Adjust volume to stay within risk and step constraints
    int maxIterations = 1000; 
    int iterations = 0;
    while (profitForMinLot * volume > riskAmount && volume > lotStep) {
        volume = NormalizeDouble(volume - lotStep, GetDecimalPlaces(lotStep));
        if (++iterations >= maxIterations) {
            Print("Warning: Exceeded maximum iterations in volume adjustment.");
            break;
        }
    }

    // Add valid volumes to the array
    while (volume >= volumeMin) {
        AddToList(volumes, MathMin(volume, volumeMax));
        volume = NormalizeDouble(volume - volumeMax, GetDecimalPlaces(lotStep));
    }
}

template<typename T>
void AddToList(T &list[], T item) {
    ArrayResize(list, ArraySize(list) + 1);
    list[ArraySize(list) - 1] = item;
}

int GetDecimalPlaces(double number) {
    double epsilon = 1e-15; 
    int decimalPlaces = 0;
    while (MathAbs(NormalizeDouble(number, decimalPlaces) - number) > epsilon && decimalPlaces < 15) {
        decimalPlaces++;
    }
    return decimalPlaces;
}


//+------------------------------------------------------------------+
//| Log message to file and terminal                                   |
//+------------------------------------------------------------------+
void LogMessage(string message) {
    if(!EnableLogging) return;
    
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
    string logMessage = timestamp + " | " + message;
    
    Print(logMessage);
    int handle = FileOpen("SMA_Strategy_Log.txt", FILE_WRITE|FILE_READ|FILE_TXT|FILE_SHARE_READ|FILE_SHARE_WRITE);
    if(handle != INVALID_HANDLE) {
        FileSeek(handle, 0, SEEK_END);
        FileWriteString(handle, logMessage + "\n");
        FileClose(handle);
    }
}

//+------------------------------------------------------------------+
//| Manage existing trades                                            |
//+------------------------------------------------------------------+
void ManageTrades() {
    for (int i = 0; i < PositionsTotal(); i++) {
        if (PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == TradeComment) {
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double stopLoss = PositionGetDouble(POSITION_SL);
            double takeProfit = PositionGetDouble(POSITION_TP);
            bool isBuyTrade = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
            double currentPrice = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), isBuyTrade ? SYMBOL_BID : SYMBOL_ASK);
            double riskRewardRatio = (takeProfit - entryPrice) / (entryPrice - stopLoss);

            // Move SL into profit if the position reaches 1:1 risk-to-reward ratio
            if (riskRewardRatio >= 2.0) {
                double newStopLoss = entryPrice; // Move SL to entry price (break-even)
                long ticket = PositionGetInteger(POSITION_TICKET);
                if (Trade.PositionModify(ticket, newStopLoss, takeProfit)) {
                    LogMessage("Stop loss moved to break-even for position: " + (string)ticket);
                } else {
                    LogMessage("Failed to move stop loss. Error: " + IntegerToString(GetLastError()));
                }
            }
        }
    }
}
