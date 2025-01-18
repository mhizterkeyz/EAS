#include <Trade\Trade.mqh>

CTrade Trade;

input int TradingHour = 11;
input double RR = 5.0;
input double RiskAmount = 100.0;

string TradeComment = "THE WAITER";
datetime HourlyTracker;
datetime DailyTracker;
datetime WeeklyTracker;
bool canTradeThisWeek = true;
bool canTradeToday = true;
double startingBalance;

int OnInit() {
    startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);

    SendNotification(TradeComment + " Loaded!");

   return (INIT_SUCCEEDED);
}

void OnTick() {
    if (iTime(_Symbol, PERIOD_W1, 0) != WeeklyTracker) {
        WeeklyTracker = iTime(_Symbol, PERIOD_W1, 0);

        canTradeThisWeek = true;
    }

    if (canTradeThisWeek && iTime(_Symbol, PERIOD_D1, 0) != DailyTracker) {
        DailyTracker = iTime(_Symbol, PERIOD_D1, 0);
    
        canTradeToday = true;
    }

    // Balance Tracker;
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    if (currentBalance != startingBalance) {
        startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        // canTradeThisWeek = false;
    }

    if (canTradeThisWeek && iTime(_Symbol, PERIOD_H1, 0) != HourlyTracker) {
        HourlyTracker = iTime(_Symbol, PERIOD_H1, 0);

        if (IsInTradingWindow()) {
            canTradeToday = false;
            double high = iHigh(_Symbol, PERIOD_M5, 1);
            double low = iLow(_Symbol, PERIOD_M5, 1);

            if (iOpen(_Symbol, PERIOD_M5, 1) < iClose(_Symbol, PERIOD_M5, 1)) {
                double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                double sl = price - (high - low);
                double tp = price + RR * (price - sl);
                double volumes[];
                double risk = GetRisk();

                CalculateVolume(risk, price, sl, _Symbol, volumes);

                for (int i = 0; i < ArraySize(volumes); i++) {
                    double volume = volumes[i];
                    Trade.Buy(volume, _Symbol, price, sl, tp, TradeComment);
                }
            } else {
                double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double sl = price + (high - low);
                double tp = price - RR * (sl - price);
                double volumes[];
                double risk = GetRisk();

                CalculateVolume(risk, price, sl, _Symbol, volumes);

                for (int i = 0; i < ArraySize(volumes); i++) {
                    double volume = volumes[i];
                    Trade.Sell(volume, _Symbol, price, sl, tp, TradeComment);
                }
            }
        }
    }
}

bool IsInTradingWindow() {
    MqlDateTime currentTime;

    TimeToStruct(TimeGMT(), currentTime);

    return currentTime.hour == TradingHour;
}

double GetRisk() {
    return RiskAmount;
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
