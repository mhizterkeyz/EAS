#include <Trade\Trade.mqh>

CTrade Trade;

input string Symbols = "EURGBP,EURJPY,NZDJPY,USDJPY,XAUUSD,GBPJPY,AUDJPY,EURUSD,BTCUSD,GBPUSD,NZDUSD,EURCHF,AUDCHF,NZDCHF,EURNZD,GBPAUD,GBPCAD,EURCAD,GBPCHF,NZDCAD,AUDNZD,GBPNZD,CADCHF,AUDUSD";
input double RiskAtHundredPercent = 1.0;
input double RiskAtNinetySevenPercent = 0.5;
input double RiskAtNinetyFivePercent = 0.25;
input double RR = 5.0;
input double SLMultiplier = 1;

string TradeComment = "Randomly";
string _Symbols[];
double startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);

int OnInit() {
    SendNotification(TradeComment + " Loaded");

    StringSplit(Symbols, ',', _Symbols);

    return(INIT_SUCCEEDED);
}

int tradingDays[];
int tradingHours[];
string tradingSignals[];
string selectedSymbols[];

bool initialized = false;
int currentTradeIndex = 0;
datetime previousTime;


void OnTick()
{
    if (iTime(_Symbol, PERIOD_H1, 0) != previousTime) {
        previousTime = iTime(_Symbol, PERIOD_H1, 0);
        MqlDateTime timeStruct;

        TimeToStruct(TimeCurrent(), timeStruct);

        int dayOfWeek = timeStruct.day_of_week;
        int currentHour = timeStruct.hour;

        if(dayOfWeek == 1 && !initialized)
        {
        
            GetDays(tradingDays);
            GetHours(tradingHours);
            GetSignals(tradingSignals);
            GetSymbols(selectedSymbols);

            Print("days ", StringifyIntArray(tradingDays));
            Print("hours ", StringifyIntArray(tradingHours));
            Print("signals ", StringifyArray(tradingSignals));
            Print("symbols ", StringifyArray(selectedSymbols));

            currentTradeIndex = 0;

            initialized = true;
        }

        if(dayOfWeek != 1 && initialized)
        {
            initialized = false;
        }

        bool isTradingDay = ArrayFind(tradingDays, dayOfWeek) >= 0;
        bool isTradingHour = ArrayFind(tradingHours, currentHour) >= 0;

        if(isTradingDay && isTradingHour && currentTradeIndex < 3)
        {
            string symbol = selectedSymbols[currentTradeIndex];
            string signal = tradingSignals[currentTradeIndex];

            if(signal == "buy")
            {
                Buy(symbol);
            }
            else if(signal == "sell")
            {
                Sell(symbol);
            }

            currentTradeIndex++;

            ArrayRemove(tradingHours, ArrayFind(tradingHours, currentHour), 1);
            ArrayRemove(tradingDays, ArrayFind(tradingDays, dayOfWeek), 1);

            Print("days ", StringifyIntArray(tradingDays));
            Print("hours ", StringifyIntArray(tradingHours));
        }
    }

    ManageTrades();
}

void ManageTrades() {
    for(int i = 0; i <= PositionsTotal(); i += 1) {
        string symbol = PositionGetSymbol(i);
        if(symbol != "" && PositionGetString(POSITION_COMMENT) == TradeComment) {
            bool isBuyTrade = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double stopLoss = PositionGetDouble(POSITION_SL);
            double takeProfit = PositionGetDouble(POSITION_TP);
            if (isBuyTrade) {
                double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
                double singleRR = (takeProfit - entryPrice)  / RR;
                double distance = currentPrice - stopLoss;
                if (distance >= singleRR * 2) {
                    Trade.PositionModify(PositionGetInteger(POSITION_TICKET), stopLoss + singleRR, takeProfit);
                }
            } else {
                double currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
                double singleRR = (entryPrice - takeProfit)  / RR;
                double distance = stopLoss - currentPrice;
                if (distance >= singleRR * 2) {
                    Trade.PositionModify(PositionGetInteger(POSITION_TICKET), stopLoss - singleRR, takeProfit);
                }
            }
        }
    }
}

string StringifyIntArray(int &arr[]) {
    string result = "[";
    int size = ArraySize(arr);
    
    for (int i = 0; i < size; i++)
    {
        result += IntegerToString(arr[i]);
        if (i < size - 1)
        {
            result += ", ";
        }
    }
    
    result += "]";

    return result;
}

string StringifyArray(string &arr[]) {
    string result = "[";
    int size = ArraySize(arr);
    
    for (int i = 0; i < size; i++)
    {
        result += arr[i];
        if (i < size - 1)
        {
            result += ", ";
        }
    }
    
    result += "]";

    return result;
}

void _Buy(string symbol) {
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double tp = GetStopLossPrice(symbol, "buy");
    double sl = price - RR * (tp - price);
    double volumes[];
    double risk = GetRisk();

    CalculateVolume(risk, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        Trade.Buy(volume, symbol, price, sl, tp, TradeComment);
    }
}

void Buy(string symbol) {
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double sl = GetStopLossPrice(symbol, "buy");
    double tp = price + RR * (price - sl);
    double volumes[];
    double risk = GetRisk();

    CalculateVolume(risk, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        Trade.Buy(volume, symbol, price, sl, tp, TradeComment);
    }
}

void _Sell(string symbol) {
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double tp = GetStopLossPrice(symbol, "sell");
    double sl = price + RR * (price - tp);
    double volumes[];
    double risk = GetRisk();

    CalculateVolume(risk, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        Trade.Sell(volume, symbol, price, sl, tp, TradeComment);
    }
}

void Sell(string symbol) {
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double sl = GetStopLossPrice(symbol, "sell");
    double tp = price - RR * (sl - price);
    double volumes[];
    double risk = GetRisk();

    CalculateVolume(risk, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        Trade.Sell(volume, symbol, price, sl, tp, TradeComment);
    }
}

double GetRisk() {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double percentage = balance / startingBalance * 100;
    double risk = NormalizeDouble(RiskAtHundredPercent / 100 * startingBalance, 2);

    if (percentage >= 95 && percentage < 97)
        risk = NormalizeDouble(RiskAtNinetySevenPercent / 100 * startingBalance, 2);
    if (percentage < 95)
        risk = NormalizeDouble(RiskAtNinetyFivePercent / 100 * startingBalance, 2);
    return risk;
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
        decimalPlaces++;
    }
    return decimalPlaces;
}

template<typename T>
void AddToList(T &list[], T item) {
    ArrayResize(list, ArraySize(list) + 1);
    list[ArraySize(list) - 1] = item;
}

double _GetStopLossPrice(string symbol, string signal)
{
    double totalHeight = 0.0;
    int count = 10;
    double currentPrice = SymbolInfoDouble(symbol, signal == "buy" ? SYMBOL_ASK : SYMBOL_BID);

    for (int i = 0; i < count; i++)
    {
        double highPrice = iHigh(symbol, PERIOD_H1, i);
        double lowPrice = iLow(symbol, PERIOD_H1, i);

        double candleHeight = highPrice - lowPrice;

        totalHeight += candleHeight;
    }

    double averageHeight = 2 * (totalHeight / count);
    
    return signal == "buy" ? currentPrice + averageHeight : currentPrice - averageHeight;
}

double GetStopLossPrice(string symbol, string signal)
{
    double totalHeight = 0.0;
    int count = 10;
    double currentPrice = SymbolInfoDouble(symbol, signal == "buy" ? SYMBOL_ASK : SYMBOL_BID);

    for (int i = 0; i < count; i++)
    {
        double highPrice = iHigh(symbol, PERIOD_H1, i);
        double lowPrice = iLow(symbol, PERIOD_H1, i);

        double candleHeight = highPrice - lowPrice;

        totalHeight += candleHeight;
    }

    double averageHeight = SLMultiplier * (totalHeight / count);
    
    return signal == "buy" ? currentPrice - averageHeight : currentPrice + averageHeight;
}

int ArrayFind(int &arr[], int val)
{
    for (int i = 0; i < ArraySize(arr); i += 1)
    {
        if (arr[i] == val) {
            return i;
        }
    }

    return -1;
}

void GetDays(int &days[])
{
    int availableDays[] = {1, 2, 3, 4, 5};

    ArrayResize(days, 3);

    for(int i = 0; i < 3; i++)
    {
        int index = MathRand() % (5 - i);
        days[i] = availableDays[index];

        for(int j = index; j < 4 - i; j++)
        {
            availableDays[j] = availableDays[j + 1];
        }
    }
}

void GetHours(int &hours[])
{
    int availableHours[] = {9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19};

    ArrayResize(hours, 3);

    for(int i = 0; i < 3; i++)
    {
        int index = MathRand() % (11 - i);
        hours[i] = availableHours[index];

        for(int j = index; j < 10 - i; j++)
        {
            availableHours[j] = availableHours[j + 1];
        }
    }
}

void GetSymbols(string &symbols[])
{
    int totalSymbols = ArraySize(_Symbols);

    if(totalSymbols < 3)
    {
        Print("Not enough symbols to select 3 unique ones.");
        return;
    }

    ArrayResize(symbols, 3);

    string availableSymbols[];
    ArrayResize(availableSymbols, totalSymbols);

    ArrayCopy(availableSymbols, _Symbols);

    for(int i = 0; i < 3; i++)
    {
        int index = MathRand() % (totalSymbols - i);
        symbols[i] = availableSymbols[index];

        for(int j = index; j < (totalSymbols - 1 - i); j++)
        {
            availableSymbols[j] = availableSymbols[j + 1];
        }
    }
}

void GetSignals(string &signals[])
{
    // string signalOptions[] = {"buy", "sell"};

    ArrayResize(signals, 3);

    for(int i = 0; i < 3; i++)
    {
        // int index = MathRand() % 2;
        signals[i] = "buy";
    }
}
