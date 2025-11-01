#include <Trade\Trade.mqh>

CTrade Trade;
input string InputSymbols = "XAUUSD"; // Symbols

string Symbols[];
string TradeComment = "New Guy";

struct CandleSignal {
    string symbol;       // Symbol being analyzed
    double open;         // Open price of the signal candle
    double exit;         // High price of the signal candle
    string signal;       // Signal type ("buy" or "sell")
    datetime signalTime; // Time when the signal was created
    datetime expiryTime;   // Time when the signal expires
};

// Array to store generated signals
CandleSignal SignalArray[];

// Array to store serials
string Serials[];

// Function to check if a signal already exists for a symbol
bool SignalExists(string symbol) {
    for (int i = 0; i < ArraySize(SignalArray); i++) {
        if (SignalArray[i].symbol == symbol) {
            return true;
        }
    }
    return false;
}

// Function to check if a serial already exists for a symbol
bool SerialExists(string serial) {
    for (int i = 0; i < ArraySize(Serials); i++) {
        if (Serials[i] == serial) {
            return true;
        }
    }
    return false;
}

// Function to remove signal
void RemoveSignal(CandleSignal &signal, int index) {
    // Delete trendlines when the signal is removed
    string openTrendlineName = signal.symbol + "_open_" + IntegerToString(signal.signalTime);
    string exitTrendlineName = signal.symbol + "_exit_" + IntegerToString(signal.signalTime);
    ObjectDelete(0, openTrendlineName);
    ObjectDelete(0, exitTrendlineName);

    // Remove the signal from the array
    ArrayRemove(SignalArray, index);
}

// Function to remove expired or invalid signals from the array
void RemoveExpiredSignals() {
    for (int i = ArraySize(SignalArray) - 1; i >= 0; i--) {
        CandleSignal signal = SignalArray[i];

        // Check if the signal has expired or if current price condition is met
        double currentBid = SymbolInfoDouble(signal.symbol, SYMBOL_BID);
        if (TimeCurrent() >= signal.expiryTime || 
            (signal.signal == "buy" && currentBid > signal.exit) ||
            (signal.signal == "sell" && currentBid < signal.exit)) {

            RemoveSignal(signal, i);
        }
    }
}

void DrawTrendline(const CandleSignal &signal) {
    // Define unique names for the trendlines based on symbol and signal time
    string openTrendlineName = signal.symbol + "_open_" + IntegerToString(signal.signalTime);
    string exitTrendlineName = signal.symbol + "_exit_" + IntegerToString(signal.signalTime);

    // Define start and end times for the trendlines (signal time to 12 hours later)
    datetime startTime = signal.signalTime;
    datetime endTime = startTime + 12 * 60 * 60; // 12 hours later

    // Determine the color based on the signal type
    color trendColor = (signal.signal == "buy") ? clrGreen : clrRed;

    // Create the trendline for the open price
    if (!ObjectCreate(0, openTrendlineName, OBJ_TREND, 0, startTime, signal.open, endTime, signal.open)) {
        Print("Failed to create open trendline for ", signal.symbol, ": ", GetLastError());
        return;
    }
    ObjectSetInteger(0, openTrendlineName, OBJPROP_COLOR, trendColor);
    ObjectSetInteger(0, openTrendlineName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, openTrendlineName, OBJPROP_RAY_RIGHT, false); // Limit the trendline to 12 hours

    // Create the trendline for the exit price
    if (!ObjectCreate(0, exitTrendlineName, OBJ_TREND, 0, startTime, signal.exit, endTime, signal.exit)) {
        Print("Failed to create exit trendline for ", signal.symbol, ": ", GetLastError());
        return;
    }
    ObjectSetInteger(0, exitTrendlineName, OBJPROP_COLOR, trendColor);
    ObjectSetInteger(0, exitTrendlineName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, exitTrendlineName, OBJPROP_RAY_RIGHT, false); // Limit the trendline to 12 hours
}

void ProcessSignals() {
    for (int i = 0; i < ArraySize(SignalArray); i++) {
        CandleSignal signal = SignalArray[i];
        double currentBid = SymbolInfoDouble(signal.symbol, SYMBOL_BID);

        if (signal.signal == "buy" && currentBid >= signal.open) {
            // Check conditions on the 5-minute candles
            double close2 = iClose(signal.symbol, PERIOD_M5, 2);
            double close1 = iClose(signal.symbol, PERIOD_M5, 1);
            double low0 = iLow(signal.symbol, PERIOD_M5, 0);

            // Check the conditions
            if (close2 < signal.open && close1 > signal.open && low0 < signal.open) {
                double entryPrice = SymbolInfoDouble(signal.symbol, SYMBOL_ASK);
                double singleRR = (signal.exit - entryPrice) / 5.0;
                double stopLoss = entryPrice - singleRR; // Stop loss calculation
                double takeProfit = signal.exit; // Take profit from the signal exit

                // Execute the buy order
                if (Trade.Sell(0.1, signal.symbol, SymbolInfoDouble(signal.symbol, SYMBOL_BID), takeProfit, stopLoss, TradeComment)) {
                    RemoveSignal(signal, i); // Remove the signal after trade
                    i--; // Adjust index after removal
                }
                // if (Trade.Buy(0.1, signal.symbol, entryPrice, stopLoss, takeProfit, TradeComment)) {
                //     RemoveSignal(signal, i); // Remove the signal after trade
                //     i--; // Adjust index after removal
                // }
            }
        } else if (signal.signal == "sell" && currentBid <= signal.open) {
            // Check conditions on the 5-minute candles
            double close2 = iClose(signal.symbol, PERIOD_M5, 2);
            double close1 = iClose(signal.symbol, PERIOD_M5, 1);
            double high0 = iHigh(signal.symbol, PERIOD_M5, 0);

            if (close2 > signal.open && close1 < signal.open && high0 > signal.open) {
                double entryPrice = currentBid;
                double singleRR = (entryPrice - signal.exit) / 5.0;
                double stopLoss = SymbolInfoDouble(signal.symbol, SYMBOL_ASK) + singleRR; // Stop loss calculation
                double takeProfit = signal.exit; // Take profit from the signal exit

                // Execute the buy order
                if (Trade.Buy(0.1, signal.symbol, SymbolInfoDouble(signal.symbol, SYMBOL_ASK), takeProfit, stopLoss, TradeComment)) {
                    RemoveSignal(signal, i); // Remove the signal after trade
                    i--; // Adjust index after removal
                }
                // if (Trade.Sell(0.1, signal.symbol, entryPrice, stopLoss, takeProfit, TradeComment)) {
                //     RemoveSignal(signal, i); // Remove the signal after trade
                //     i--; // Adjust index after removal
                // }
            }
        }
    }
}

// Function to add a new signal to the array
void AddSignal(CandleSignal &signal) {
    ArrayResize(SignalArray, ArraySize(SignalArray) + 1);
    SignalArray[ArraySize(SignalArray) - 1] = signal;

    DrawTrendline(signal);
}

// Function to add a new serial to the array
void AddSerial(string serial) {
    ArrayResize(Serials, ArraySize(Serials) + 1);
    Serials[ArraySize(Serials) - 1] = serial;
}

string GetSignalSerial(string symbol, ENUM_TIMEFRAMES timeFrame) {
    string serial = "";

    for (int i = 2; i > 0; i -= 1) {
        serial += symbol + (string)iHigh(symbol, timeFrame, i) + (string)iLow(symbol, timeFrame, i) + (string)iTime(symbol, timeFrame, i);
    }

    return serial;
}

void CheckForSignal(string symbol, ENUM_TIMEFRAMES timeFrame) {
    if (iOpen(symbol, timeFrame, 1) > iClose(symbol, timeFrame, 1) != iOpen(symbol, timeFrame, 2) > iClose(symbol, timeFrame, 2)) {
        datetime expiry = TimeCurrent() + ((timeFrame == PERIOD_H1) ? 60 * 60 : 4 * 60 * 60); // Set expiry based on timeframe
        string serial = GetSignalSerial(symbol, timeFrame);

        if (SerialExists(serial)) {
            return;
        }

        if (iOpen(symbol, timeFrame, 1) > iClose(symbol, timeFrame, 1)) {
            // Check if the body is less than or equal to half the size of the upper wick
            double candleBody = iOpen(symbol, timeFrame, 1) - iClose(symbol, timeFrame, 1);
            double upperWick = iHigh(symbol, timeFrame, 1) - iOpen(symbol, timeFrame, 1);
            if (2 * candleBody <= upperWick) {
                CandleSignal signal;
                signal.symbol = symbol;
                signal.open = iOpen(symbol, timeFrame, 1);
                signal.exit = iHigh(symbol, timeFrame, 1);
                signal.signal = "buy";
                signal.signalTime = TimeCurrent(); // Set the signal creation time
                signal.expiryTime = expiry;
                AddSignal(signal); // Add signal to the array
                AddSerial(serial);
            }
        } else {
            // Check if the body is less than or equal to half the size of the lower wick
            double candleBody = iClose(symbol, timeFrame, 1) - iOpen(symbol, timeFrame, 1);
            double lowerWick = iOpen(symbol, timeFrame, 1) - iLow(symbol, timeFrame, 1);
            if (2 * candleBody <= lowerWick) {
                CandleSignal signal;
                signal.symbol = symbol;
                signal.open = iOpen(symbol, timeFrame, 1);
                signal.exit = iLow(symbol, timeFrame, 1);
                signal.signal = "sell";
                signal.signalTime = TimeCurrent(); // Set the signal creation time
                signal.expiryTime = expiry;
                AddSignal(signal); // Add signal to the array
                AddSerial(serial);
            }
        }
    }
}

int OnInit() {
    StringSplit(InputSymbols, ',', Symbols);

    return(INIT_SUCCEEDED);
}

void OnTick() {
    RemoveExpiredSignals();
    ProcessSignals();

    for (int i = 0; i < ArraySize(Symbols); i += 1) {
        string symbol = Symbols[i];

         // Skip processing if a signal already exists for this symbol
        if (IsSymbolInUse(symbol) || SignalExists(symbol)) {
            continue;
        }

        ENUM_TIMEFRAMES timeFrames[] = {
            PERIOD_H1,
            PERIOD_H4
        };
        for (int j = 0; j < ArraySize(timeFrames); j += 1) {
            ENUM_TIMEFRAMES timeFrame = timeFrames[j];
            CheckForSignal(symbol, timeFrame);    
        }
    }
}

bool IsSymbolInUse(string symbol) {
    for(int i = 0; i <= PositionsTotal(); i += 1) {
        if(PositionGetSymbol(i) == symbol && PositionGetString(POSITION_COMMENT) == TradeComment) {
            return true; 
        }
    }

    for(int j = 0; j < OrdersTotal(); j += 1) {
        if(OrderGetTicket(j) && OrderGetString(ORDER_SYMBOL) == symbol && OrderGetString(ORDER_COMMENT) == TradeComment) {
            return true;
        }
    }

    return false;
}
