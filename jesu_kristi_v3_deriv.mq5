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
  "Volatility 10 Index",
  "Volatility 50 Index",
  "Volatility 75 Index",
  "Volatility 100 (1s) Index",
  "Volatility 250 (1s) Index",
  "Boom 500 Index",
  "Boom 1000 Index",
  "Crash 500 Index",
  "Crash 1000 Index",
  "Range Break 200 Index",
  "DEX 600 DOWN Index",
  "DEX 900 DOWN Index",
  "Drift Switch Index 20",
};

int OnInit() {
   SendNotification(tradeComment + " Loaded!");
   startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if (!TakeTradeOnInit)
      previousTime = iTime(_Symbol, TimeFrame, 0);
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

void Buy(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates rates[];

    CopyRates(symbol, timeframe, 0, 3, rates);

    double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double sl = MathMin(rates[0].low, MathMin(rates[1].low, rates[2].low));
    double tp = price + ((price - sl) * RR);
    double volumes[];
    
    CalculateVolume(RiskAmount, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        trade.Buy(volume, symbol, price, sl, tp, tradeComment);
    }
}

void Sell(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates rates[];

    CopyRates(symbol, timeframe, 0, 3, rates);

    double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double sl = MathMax(rates[0].high, MathMax(rates[1].high, rates[2].high));
    double tp = price + ((price - sl) * RR);
    double volumes[];
    
    CalculateVolume(RiskAmount, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        trade.Sell(volume, symbol, price, sl, tp, tradeComment);
    }
}

bool GetEngulfingCandle(string symbol, ENUM_TIMEFRAMES timeframe, bool dir, MqlRates &res) {
    MqlRates rates[];

    CopyRates(symbol, timeframe, 1, 10, rates);

    int length = ArraySize(rates);

    for (int i = 0; i < length; i += 1) {
        if (i + 1 >= length) break;
        res = rates[i + 1];
        if (IsEngulfing(res, rates[i], dir)) return true;
    }

    return false;
}

bool IsEngulfing(MqlRates &currentCandle, MqlRates &prvCandle, bool type)
  {
    return currentCandle.high > prvCandle.high &&
        currentCandle.low < prvCandle.low &&
        Direction(currentCandle) == type &&
        MathMax(currentCandle.open, currentCandle.close) > MathMax(prvCandle.open, prvCandle.close) &&
        MathMin(currentCandle.open, currentCandle.close) < MathMin(prvCandle.open, prvCandle.close);
  }

bool Direction(MqlRates &rate)
  {
    return rate.close > rate.open;
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
    
    while (totalProfit < riskAmount) {
        double volume = volumeMin;
        double profit = 0.0;
    
        while (OrderCalcProfit(ORDER_TYPE_BUY, symbol, volume, MathMin(entryPrice, stopLoss), MathMax(entryPrice, stopLoss), profit) && profit < (riskAmount - totalProfit) && volume < volumeMax) {
            volume += lotStep;
        }
        
        if (profit > (riskAmount - totalProfit)) {
            volume = volume - lotStep;
        }

        AddToList(volumes, MathMin(volumeMax, NormalizeDouble(volume, decimalPlaces)));
        totalProfit += profit;
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
void AddToList(T &list[], T item)
  {
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
