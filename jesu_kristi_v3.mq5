#include <Trade\Trade.mqh>

input ENUM_TIMEFRAMES TimeFrame = PERIOD_M5;
input double RiskAmount = 10;
input double RR = 3;
input int TradingDaysStart = 1;
input int TradingDaysEnd = 5;
input int TradingHoursStart = 6;
input int TradingHoursEnd = 20;
input double TargetAmount = 50;
input bool StopAtTargetHit = true;
input bool TakeTradeOnInit = false;

bool canTrade = true;
datetime previousTime;
CTrade trade;
string tradeComment = "JESU KRISTI V3 DERIV";
double startingBalance;
string symbols[] = {
    "XAUUSD",
    "AUDNZD",
    "AUDUSD",
    "USDCHF",
    "USDCAD",
    "EURJPY",
    "NZDJPY",
    "GBPJPY",
    "EURNZD",
    "GBPNZD",
};
double SLPercent = 0.1;

int OnInit() {
   startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   if (!TakeTradeOnInit)
      previousTime = iTime(_Symbol, TimeFrame, 0);

   SendNotification(tradeComment + " Loaded!");

   return(INIT_SUCCEEDED);
 }

void OnTick() {
    if (canTrade) {
        ManageBalance();

        if (iTime(_Symbol, TimeFrame, 0) != previousTime) {
            previousTime = iTime(_Symbol, TimeFrame, 0);

            SendNotification(tradeComment + " Health Notif!");

            if (IsInTradingWindow()) {
                for (int i = 0; i < ArraySize(symbols); i += 1) {
                    if (CanTrade()) {
                        string symbol = symbols[i];
                        string signal = CheckEntry(symbol, TimeFrame);

                        if (signal == "buy" && !IsSymbolInUse(symbol)) {
                            Buy(symbol, TimeFrame);
                        }

                        if (signal == "sell" && !IsSymbolInUse(symbol)) {
                            Sell(symbol, TimeFrame);
                        }
                    }
                }
            }

        }
    }
}

// void Buy(string symbol, ENUM_TIMEFRAMES timeframe) {
//     MqlRates rates[];

//     CopyRates(symbol, timeframe, 0, 3, rates);

//     double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
//     double price = SymbolInfoDouble(symbol, SYMBOL_BID);
//     double sl = price - (MathMax(rates[0].high, MathMax(rates[1].high, rates[2].high)) - MathMin(rates[0].low, MathMin(rates[1].low, rates[2].low))) * SLPercent;
//     double tp = price + ((price - sl) * RR);
//     double volumes[];
    
//     CalculateVolume(RiskAmount, price, sl, symbol, volumes);

//     for (int i = 0; i < ArraySize(volumes); i += 1) {
//         trade.Sell(volumes[i], symbol, price, tp, sl, tradeComment);
//     }
// }

// void Sell(string symbol, ENUM_TIMEFRAMES timeframe) {
//     MqlRates rates[];

//     CopyRates(symbol, timeframe, 0, 3, rates);

//     double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
//     double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
//     double sl = price + (MathMax(rates[0].high, MathMax(rates[1].high, rates[2].high)) - MathMin(rates[0].low, MathMin(rates[1].low, rates[2].low))) * SLPercent;
//     double tp = price + ((price - sl) * RR);
//     double volumes[];
    
//     CalculateVolume(RiskAmount, price, sl, symbol, volumes);

//     for (int i = 0; i < ArraySize(volumes); i += 1) {
//         trade.Buy(volumes[i], symbol, price, tp, sl, tradeComment);
//     }
// }

void Buy(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates rates[];

    CopyRates(symbol, timeframe, 0, 3, rates);

    double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double sl = price - (MathMax(rates[0].high, MathMax(rates[1].high, rates[2].high)) - MathMin(rates[0].low, MathMin(rates[1].low, rates[2].low))) * SLPercent;
    double tp = price + ((price - sl) * RR);
    double volumes[];
    
    CalculateVolume(RiskAmount, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i += 1) {
        trade.Buy(volumes[i], symbol, price, sl, tp, tradeComment);
    }
}

void Sell(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates rates[];

    CopyRates(symbol, timeframe, 0, 3, rates);

    double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double sl = price + (MathMax(rates[0].high, MathMax(rates[1].high, rates[2].high)) - MathMin(rates[0].low, MathMin(rates[1].low, rates[2].low))) * SLPercent;
    double tp = price + ((price - sl) * RR);
    double volumes[];
    
    CalculateVolume(RiskAmount, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i += 1) {
        trade.Sell(volumes[i], symbol, price, sl, tp, tradeComment);
    }
}

string CheckEntry(string symbol, ENUM_TIMEFRAMES _timeframe) {
    MqlRates rates[];

    CopyRates(symbol, _timeframe, 0, 3, rates);
    ReverseArray(rates);

    string signal = "";
    double movingAverageArray[];
    int movingAverage = iMA(symbol, _timeframe, 20, 0, MODE_SMA, PRICE_CLOSE);

    CopyBuffer(movingAverage, 0, 0, 3, movingAverageArray);
    ReverseArray(movingAverageArray);

    if (rates[1].close > movingAverageArray[1])
        if (rates[2].close < movingAverageArray[2])
            signal = "buy";

    if (rates[1].close < movingAverageArray[1])
        if (rates[2].close > movingAverageArray[2])
            signal = "sell";

    return signal;
}

template<typename T>
void ReverseArray(T &rates[]) {
    int start = 0;
    int end = ArraySize(rates) - 1;
    T temp;

    while (start < end)
    {
        temp = rates[start];
        rates[start] = rates[end];
        rates[end] = temp;

        start++;
        end--;
    }
}

void CalculateVolume(double riskAmount, double entryPrice, double stopLoss, string symbol, double &volumes[]) {
    double totalProfit = 0.0;
    double volumeMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double volumeMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    int decimalPlaces = GetDecimalPlaces(lotStep);
    int maxIterations = 1000;
    int iterations = 0;
    
    while (totalProfit < riskAmount && iterations < maxIterations) {
        double volume = volumeMin;
        double profit = 0.0;
        int _maxIterations = 1000;
        int _iterations = 0;

    
        while (OrderCalcProfit(ORDER_TYPE_BUY, symbol, volume, MathMin(entryPrice, stopLoss), MathMax(entryPrice, stopLoss), profit) && profit < (riskAmount - totalProfit) && volume < volumeMax && _iterations < _maxIterations) {
            volume += lotStep;
            _iterations += 1;
        }
        
        if (profit > (riskAmount - totalProfit)) {
            volume = volume - lotStep;
        }

        AddToList(volumes, MathMin(volumeMax, NormalizeDouble(volume, decimalPlaces)));
        totalProfit += profit;
        iterations += 1;
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

void CloseAllPositions() {
    for (int i = 0; i <= PositionsTotal(); i += 1) {
        if (PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == tradeComment) {
            trade.PositionClose(PositionGetInteger(POSITION_TICKET));
        }
    }
    if (_PositionsTotal() > 0) {
        CloseAllPositions();
    }
}

int _PositionsTotal() {
    int count = 0;
    for (int i = 0; i <= PositionsTotal(); i += 1) {
        if (PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == tradeComment) {
            count += 1;
        }
    }

    return count;
}


bool IsInTradingWindow() {
    MqlDateTime currentTime;
    TimeToStruct(TimeGMT(), currentTime);

    return currentTime.day_of_week >= TradingDaysStart && currentTime.day_of_week <= TradingDaysEnd && currentTime.hour >= TradingHoursStart && currentTime.hour <= TradingHoursEnd;
}

bool IsSymbolInUse(string symbol) {
    return false;
    for(int i = 0; i <= PositionsTotal(); i += 1)
    {
        if(PositionGetSymbol(i) == symbol && PositionGetString(POSITION_COMMENT) == tradeComment)
            {
            return true; 
            }
    }

    for(int j = 0; j < OrdersTotal(); j += 1)
    {
        if(OrderGetTicket(j) && OrderGetString(ORDER_SYMBOL) == symbol && OrderGetString(ORDER_COMMENT) == tradeComment)
            {
            return true;
            }
    }

    return false;
}

void ManageBalance() {
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    if (equity - startingBalance >= TargetAmount) {
        CloseAllPositions();
        startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        SendNotification(tradeComment + " Target Hit!");
        if (StopAtTargetHit) {
            canTrade = false;
        }
    }
}

int GetRandomNumber(int maxNumber) {
    MathSrand(GetTickCount());

    return 1 + MathRand() % maxNumber;
}

int delay = 0;
bool CanTrade() {
    // if (delay <= 0) {
        
    //     delay = ArraySize(symbols) * GetRandomNumber(10);

    //     return true;
    // }

    // delay -= 1;
    return MathRand() % 2 == 0;
}
