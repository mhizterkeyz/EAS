#include <Trade\Trade.mqh>

input double RiskAmount = 2.0; // Risk Per Trade
input double RR = 0.0; // Risk to reward per trade.
input bool UsePercent = true; // Treat risk amount as percent of account balance instead of amount
input int TradeCount = 3; // Trades per symbol per day
input bool BreakEven = true; // Break even trades
input double PercentagePerMonth = 10.0; // Profit target per month (percent)
input double PercentageLossPerMonth = 10.0; // Loss target per month (percent)


CTrade Trade;
string TradeComment = "I_AM_GOD";
int ADXHandles[];
int ATRHandles[];
int RSIHandles[];
int FiftyMAHandles[];
int HundredMAHandles[];
int TwoHundredMAHandles[];
datetime LastTimes[];
int TradeCounts[];
double PreviousHighs[];
double PreviousLows[];
ulong DealTickets[];
string SymbolArray[] = {
    "XAUUSD"
};
datetime PreviousDay = 0;
datetime PreviousMonth = 0;
double StartingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
double MonthTarget;
double LossTarget;
bool CanTrade = true;

int OnInit()
{
    MonthTarget = PercentagePerMonth / 100 * StartingBalance;
    LossTarget = PercentageLossPerMonth / 100 * StartingBalance;

    int count = ArraySize(SymbolArray);

    ArrayResize(ADXHandles, count);
    ArrayResize(ATRHandles, count);
    ArrayResize(RSIHandles, count);
    ArrayResize(FiftyMAHandles, count);
    ArrayResize(HundredMAHandles, count);
    ArrayResize(TwoHundredMAHandles, count);
    ArrayResize(LastTimes, count);
    ArrayResize(TradeCounts, count);
    ArrayResize(PreviousHighs, count);
    ArrayResize(PreviousLows, count);
    ArrayResize(DealTickets, count);

    for (int i = 0; i < count; i++)
    {
        string symbol = SymbolArray[i];

        ADXHandles[i] = iADX(symbol, PERIOD_CURRENT, 14);
        if (ADXHandles[i] == INVALID_HANDLE)
        {
            Print("Error initializing ADX for ", symbol);
            return INIT_FAILED;
        }

        ATRHandles[i] = iATR(symbol, PERIOD_CURRENT, 14);
        if (ATRHandles[i] == INVALID_HANDLE)
        {
            Print("Error initializing ATR for ", symbol);
            return INIT_FAILED;
        }

        RSIHandles[i] = iRSI(symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
        if (RSIHandles[i] == INVALID_HANDLE)
        {
            Print("Error initializing ATR for ", symbol);
            return INIT_FAILED;
        }

        FiftyMAHandles[i] = iMA(symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
        if (FiftyMAHandles[i] == INVALID_HANDLE)
        {
            Print("Error initializing 50 MA for ", symbol);
            return INIT_FAILED;
        }

        HundredMAHandles[i] = iMA(symbol, PERIOD_CURRENT, 100, 0, MODE_SMA, PRICE_CLOSE);
        if (HundredMAHandles[i] == INVALID_HANDLE)
        {
            Print("Error initializing 100 MA for ", symbol);
            return INIT_FAILED;
        }

        TwoHundredMAHandles[i] = iMA(symbol, PERIOD_CURRENT, 200, 0, MODE_SMA, PRICE_CLOSE);
        if (TwoHundredMAHandles[i] == INVALID_HANDLE)
        {
            Print("Error initializing 200 MA for ", symbol);
            return INIT_FAILED;
        }

        LastTimes[i] = 0;
        TradeCounts[i] = 0;
        PreviousLows[i] = 0.0;
        PreviousHighs[i] = 0.0;
        DealTickets[i] = 0;

    }

    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    for (int i = 0; i < ArraySize(SymbolArray); i++)
    {
        if (ADXHandles[i] != INVALID_HANDLE) IndicatorRelease(ADXHandles[i]);
        if (ATRHandles[i] != INVALID_HANDLE) IndicatorRelease(ATRHandles[i]);
        if (RSIHandles[i] != INVALID_HANDLE) IndicatorRelease(RSIHandles[i]);
        if (FiftyMAHandles[i] != INVALID_HANDLE) IndicatorRelease(ADXHandles[i]);
        if (HundredMAHandles[i] != INVALID_HANDLE) IndicatorRelease(ADXHandles[i]);
        if (TwoHundredMAHandles[i] != INVALID_HANDLE) IndicatorRelease(ADXHandles[i]);
    }
    
    Print("Indicators released. Deinitialization complete.");
}

double GetSLSize(int index)
{
    double atr_values[];


    CopyBuffer(ATRHandles[index], 0, 0, 1, atr_values);

    return atr_values[0];
}

int GetSignal(int index)
{
    double values[], plus_values[], minus_values[], fifty_values[], hundred_values[], two_hundred_values[], rsi_values[];

    CopyBuffer(ADXHandles[index], 0, 0, 1, values);
    CopyBuffer(ADXHandles[index], 1, 0, 1, plus_values);
    CopyBuffer(ADXHandles[index], 2, 0, 1, minus_values);
    CopyBuffer(RSIHandles[index], 0, 0, 1, rsi_values);
    CopyBuffer(FiftyMAHandles[index], 0, 0, 1, fifty_values);
    CopyBuffer(HundredMAHandles[index], 0, 0, 1, hundred_values);
    CopyBuffer(TwoHundredMAHandles[index], 0, 0, 1, two_hundred_values);

    if (values[0] >= 25 && values[0] <= 30)
    {
        if (plus_values[0] > minus_values[0] && rsi_values[0] <= 70) {
            double bidPrice = SymbolInfoDouble(SymbolArray[index], SYMBOL_BID);
            if (
                fifty_values[0] < hundred_values[0] &&
                bidPrice < fifty_values[0] // &&
                // hundred_values[0] > two_hundred_values[0]
            ) return 1;
        }
        
        if (minus_values[0] > plus_values[0] && rsi_values[0] >= 50) {
            double askPrice = SymbolInfoDouble(SymbolArray[index], SYMBOL_ASK);
            if (
                fifty_values[0] > hundred_values[0] &&
                askPrice > fifty_values[0] // &&
                // hundred_values[0] < two_hundred_values[0]
            ) return -1;
        }
    }

    return 0;
}

bool IsPositionOpen(ENUM_POSITION_TYPE type, string symbol) {
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetString(POSITION_COMMENT) == TradeComment && PositionGetInteger(POSITION_TYPE) == type && PositionGetString(POSITION_SYMBOL) == symbol)
            return true;
    }

    return false;
}

bool CalculateVolume(const double riskAmount, const double entryPrice, const double stopLoss, const string symbol, double &volumes[]) {
    // Validate input parameters
    if (riskAmount <= 0 || entryPrice <= 0 || symbol == "") {
        Print("Error: Invalid input parameters for volume calculation");
        return false;
    }

    // Retrieve symbol trading constraints
    double volumeMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double volumeMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

    // Validate symbol information
    if (volumeMax <= 0 || lotStep <= 0) {
        Print("Error: Unable to retrieve valid symbol volume constraints");
        return false;
    }

    // Calculate point difference
    double entryPointPrice = MathMin(entryPrice, stopLoss);
    double stopPointPrice = MathMax(entryPrice, stopLoss);
    double pointDifference = MathAbs(entryPointPrice - stopPointPrice);

    // Prevent division by zero
    if (pointDifference == 0) {
        Print("Error: Entry and stop loss prices are identical");
        return false;
    }

    // Reset output array
    ArrayFree(volumes);

    double totalProfit = 0.0;
    int decimalPlaces = GetDecimalPlaces(lotStep);
    int iterationCount = 0;
    
    while (totalProfit < riskAmount) {
        double volume = volumeMin;
        double currentProfit = 0.0;
        
        // Find optimal volume that approaches but doesn't exceed risk amount
        while (true) {
            // Check for potential OrderCalcProfit errors
            if (!OrderCalcProfit(ORDER_TYPE_BUY, symbol, volume, entryPointPrice, stopPointPrice, currentProfit)) {
                Print("Error calculating profit for volume: ", volume);
                break;
            }

            // Check if current volume exceeds remaining risk or max volume
            if (currentProfit > (riskAmount - totalProfit) || volume >= volumeMax) {
                // Step back to previous volume if we've gone too far
                volume = MathMax(volumeMin, volume - lotStep);
                break;
            }

            // Increment volume by lot step
            volume = NormalizeDouble(volume + lotStep, decimalPlaces);
        }

        // Verify profit and volume before adding
        if (currentProfit > 0 && volume >= volumeMin) {
            AddToList(volumes, volume);
            totalProfit += currentProfit;
        } else {
            // If we can't find a suitable volume, exit to prevent infinite loop
            break;
        }

        // Safeguard against potential infinite loop
        iterationCount++;
        if (iterationCount > 100) {
            Print("Warning: Maximum iteration limit reached");
            break;
        }
    }

    return ArraySize(volumes) > 0;
}

// Utility function to add to dynamic array
void AddToList(double &arr[], double value) {
    int size = ArraySize(arr);
    ArrayResize(arr, size + 1);
    arr[size] = value;
}

// Determine decimal places for precise volume normalization
int GetDecimalPlaces(double value) {
    int places = 0;
    while (MathMod(value * MathPow(10, places), 1) != 0 && places < 8) {
        places++;
    }
    return places;
}

double GetRisk() {
    if (UsePercent) {
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        return (RiskAmount / 100.0) * accountBalance;
    }

    return RiskAmount;
}

int GetSymbolIndex(string symbol)
{
    for (int i = 0; i < ArraySize(SymbolArray); i++) {
        if (symbol == SymbolArray[i]) return i;
    }

    return -1;
}

void ManageTrade() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (!PositionSelectByTicket(PositionGetTicket(i)) || PositionGetString(POSITION_COMMENT) != TradeComment) {
            continue;
        }
        
        bool isBuyPosition = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentStopLoss = PositionGetDouble(POSITION_SL);
        if (
            (isBuyPosition && entryPrice <= currentStopLoss) ||
            (!isBuyPosition && entryPrice >= currentStopLoss)
        ) continue;
        
        string symbol = PositionGetString(POSITION_SYMBOL);
        double bidPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
        double takeProfit = PositionGetDouble(POSITION_TP);
        
        
        if (
            isBuyPosition &&
            (bidPrice - entryPrice) / (takeProfit - entryPrice) >= 0.4
        )
        {
            double newStopLoss = entryPrice + 0.1 * (takeProfit - entryPrice);

            Trade.PositionModify(PositionGetTicket(i), newStopLoss, PositionGetDouble(POSITION_TP));
            continue;
        }
        
        double askPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
        
        if (
            !isBuyPosition &&
            (entryPrice - askPrice) / (entryPrice - takeProfit) >= 0.4
        )
        {
            double newStopLoss = entryPrice - 0.1 * (entryPrice - takeProfit);

            Trade.PositionModify(PositionGetTicket(i), newStopLoss, PositionGetDouble(POSITION_TP));
            continue;
        }
    }
}

int GetLastTradeResult(string symbol)
{
    return 0;
    datetime fromDate = 0;
    datetime toDate = TimeCurrent();

    if(HistorySelect(fromDate, toDate))
    {
        int totalDeals = HistoryDealsTotal();
        for(int i = totalDeals - 1; i >= 0; i--)
        {
            ulong dealTicket = HistoryDealGetTicket(i);
            string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
            ENUM_DEAL_REASON dealReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(dealTicket, DEAL_REASON);
            ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);

            if(dealSymbol == symbol)
            {
                if(dealReason == DEAL_REASON_SL)
                {
                    int index = GetSymbolIndex(symbol);
                    if (DealTickets[index] == dealTicket) return 0;

                    DealTickets[index] = dealTicket;
                    if(dealType == DEAL_TYPE_SELL) return 1;
                    if(dealType == DEAL_TYPE_BUY) return -1;
                }
                break;
            }
        }
    }
    return 0;
}

void OnTick() {
    if (BreakEven) ManageTrade();

    if (PreviousMonth != iTime(Symbol(), PERIOD_MN1, 0))
    {
        PreviousMonth = iTime(Symbol(), PERIOD_MN1, 0);
        StartingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        MonthTarget = PercentagePerMonth / 100 * StartingBalance;
        LossTarget = PercentageLossPerMonth / 100 * StartingBalance;
        CanTrade = true;
    }
    
    if (!CanTrade) return;
    
    if (
        AccountInfoDouble(ACCOUNT_BALANCE) - StartingBalance >= MonthTarget ||
        StartingBalance - AccountInfoDouble(ACCOUNT_BALANCE) >= LossTarget
    )
    {
        CanTrade = false;
        return;
    }

    if (PreviousDay != iTime(Symbol(), PERIOD_D1, 0))
    {
        PreviousDay = iTime(Symbol(), PERIOD_D1, 0);
        for (int i = 0; i < ArraySize(TradeCounts); i += 1)
        {
            TradeCounts[i] = 0;
        }
    }

    for (int i = 0; i < ArraySize(SymbolArray); i++)
    {
        string symbol = SymbolArray[i];
        if (LastTimes[i] == iTime(symbol, PERIOD_CURRENT, 0)) continue;
        
        LastTimes[i] = iTime(symbol, PERIOD_CURRENT, 0);

        Print("previous low ", PreviousLows[i]);
        if (
            PreviousHighs[i] != 0.0 &&
            PreviousHighs[i] < SymbolInfoDouble(symbol, SYMBOL_BID)
        ) PreviousHighs[i] = 0.0;

        if (
            PreviousLows[i] != 0.0 &&
            PreviousLows[i] > SymbolInfoDouble(symbol, SYMBOL_BID)
        ) PreviousLows[i] = 0.0;

        int signal = GetSignal(i);
        if (
            (signal == 1 && PreviousHighs[i] != 0.0) ||
            (signal == -1 && PreviousLows[i] != 0.0)
        ) continue;

        int lastResult = GetLastTradeResult(symbol);

        Print(symbol, " last result ", lastResult);

        if (lastResult == 1) {
            int k = 2; // Start from the 2nd past candle to allow left-side comparison
            double high;

            while(true)
            {
                double currentHigh = iHigh(symbol, PERIOD_CURRENT, k);

                // Check if the high is greater than two candles to the left and right
                if(
                    currentHigh > iHigh(symbol, PERIOD_CURRENT, k - 1) &&
                    currentHigh > iHigh(symbol, PERIOD_CURRENT, k - 2) &&
                    currentHigh > iHigh(symbol, PERIOD_CURRENT, k + 1) &&
                    currentHigh > iHigh(symbol, PERIOD_CURRENT, k + 2)
                )
                {
                    high = currentHigh; // Store the swing high
                    break; // Exit loop once we find a valid swing high
                }

                k++; // Move further back
            }

            PreviousHighs[i] = high;
            continue;
        }

        if (lastResult == -1) {
            int k = 2; // Start from the 2nd past candle to allow left-side comparison
            double low;

            while(true)
            {
                double currentLow = iLow(symbol, PERIOD_CURRENT, k);

                // Check if the low is lower than two candles to the left and right
                if(
                    currentLow < iLow(symbol, PERIOD_CURRENT, k - 1) &&
                    currentLow < iLow(symbol, PERIOD_CURRENT, k - 2) &&
                    currentLow < iLow(symbol, PERIOD_CURRENT, k + 1) &&
                    currentLow < iLow(symbol, PERIOD_CURRENT, k + 2)
                )
                {
                    low = currentLow; // Store the swing low
                    break; // Exit loop once we find a valid swing low
                }

                k++; // Move further back
            }

            PreviousLows[i] = low;
            continue;
        }
        
        bool hasNoOpenTrade = !IsPositionOpen(POSITION_TYPE_BUY, symbol) && !IsPositionOpen(POSITION_TYPE_SELL, symbol);
        bool canTrade = TradeCounts[i] <= TradeCount;


        if (signal == 1 && hasNoOpenTrade && canTrade) {
            double entryPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double stopLoss = entryPrice - GetSLSize(i) * 3;
            double takeProfit = RR > 0 ? entryPrice + RR * MathAbs(entryPrice - stopLoss) : 0;
            double volumes[];

            CalculateVolume(GetRisk(), entryPrice, stopLoss, symbol, volumes);

            bool tradeEntered = false;

            for (int j = 0; j < ArraySize(volumes); j += 1) {
                double volume = volumes[j];
                if (Trade.Buy(volume, symbol, 0, stopLoss, takeProfit, TradeComment)) {
                    tradeEntered = true;
                }
            }
            if (tradeEntered) {
                SendNotification(TradeComment + " took a buy trade on " + symbol);
                TradeCounts[i] += 1;
            }
        }

        if (signal == -1 && hasNoOpenTrade && canTrade) {
            double entryPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
            double stopLoss = entryPrice + GetSLSize(i) * 3;
            double takeProfit = RR > 0 ? entryPrice - RR * MathAbs(entryPrice - stopLoss) : 0;
            double volumes[];

            CalculateVolume(GetRisk(), entryPrice, stopLoss, symbol, volumes);

            bool tradeEntered = false;

            for (int j = 0; j < ArraySize(volumes); j += 1) {
                double volume = volumes[j];
                if (Trade.Sell(volume, symbol, 0, stopLoss, takeProfit, TradeComment)) {
                    tradeEntered = true;
                }
            }
            if (tradeEntered) {
                SendNotification(TradeComment + " took a sell trade on " + symbol);
                TradeCounts[i] += 1;
            }
        }
    }
}
