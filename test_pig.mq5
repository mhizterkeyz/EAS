#include <Trade\Trade.mqh>

input ENUM_TIMEFRAMES TimeFrame = PERIOD_M5;
input double SLAmount = 100;
input double TP = 10;

CTrade trade;
string tradeComment = "GOD ABEG";
double startingBalance;
bool busy = false;
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

int OnInit() {
   SendNotification(tradeComment + " Loaded!");
   startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   return(INIT_SUCCEEDED);
}

void OnTick() {
    Manage();
    if (!busy)
        for (int i = 0; i < ArraySize(symbols); i += 1) {
            string symbol = symbols[i];
            if (!IsSymbolInUse(symbol)) {
                string signal = CheckEntry(symbol, TimeFrame);

                if (signal == "buy")
                    Buy(symbol);
                
                if (signal == "sell")
                    Sell(symbol);
            }
        }
}

void Manage() {
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double delta = equity - startingBalance;
    if (delta >= TP || delta <= -1 * SLAmount) {
        CloseAllPositions();
        startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    }
}

void Buy(string symbol) {
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

    trade.Buy(volume, symbol, price, 0, 0, tradeComment);
}

void Sell(string symbol) {
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

    trade.Sell(volume, symbol, price, 0, 0, tradeComment);
}

string CheckEntry(string symbol, ENUM_TIMEFRAMES _timeframe) {
    MqlRates rates[];

    CopyRates(symbol, _timeframe, 1, 1, rates);
    ReverseArray(rates);

    string signal = "";
    double movingAverageArray[];
    int movingAverage = iMA(symbol, _timeframe, 20, 0, MODE_SMA, PRICE_CLOSE);

    CopyBuffer(movingAverage, 0, 1, 1, movingAverageArray);
    ReverseArray(movingAverageArray);

    if (rates[0].close > movingAverageArray[0])
            signal = "buy";

    if (rates[0].close < movingAverageArray[0])
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

bool IsSymbolInUse(string symbol) {
    for(int i = 0; i <= PositionsTotal(); i += 1) {
        if(PositionGetSymbol(i) == symbol && PositionGetString(POSITION_COMMENT) == tradeComment) {
            return true; 
        }
    }

    return false;
}

void CloseAllPositions() {
    busy = true;
    for (int i = 0; i <= PositionsTotal(); i += 1) {
        if (PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == tradeComment) {
            trade.PositionClose(PositionGetInteger(POSITION_TICKET));
        }
    }
    busy = false;
}
