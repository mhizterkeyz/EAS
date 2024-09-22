#include <Trade\Trade.mqh>

input int TradingHoursStart = 11;
input int TradingHoursEnd = 19;
input double RiskAmount = 100;
input double RR = 5;
input double SpreadMultiplier = 20;

string TradeComment = "ABOBI";
CTrade Trade;


int OnInit() {
   SendNotification(TradeComment + " Loaded!");

   return(INIT_SUCCEEDED);
}

void OnTick() {
    ManageTrades();
    string symbol = _Symbol;
    if (!IsSymbolInUse(symbol) && IsInTradingWindow()) {
        Buy(symbol);
        Sell(symbol);
    }
}

void Buy(string symbol) {
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    long spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
    double points = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double sl = price - spread * points * SpreadMultiplier;
    double tp = price + ((price - sl) * RR);
    double volumes[];
    double risk = GetRisk();
    
    CalculateVolume(risk, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        Trade.Buy(volume, symbol, price, sl, tp, TradeComment);
    }
}

void Sell(string symbol) {
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    long spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
    double points = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double sl = price + spread * points * SpreadMultiplier;
    double tp = price + ((price - sl) * RR);
    double volumes[];
    double risk = GetRisk();
    
    CalculateVolume(risk, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        Trade.Sell(volume, symbol, price, sl, tp, TradeComment);
    }
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
void AddToList(T &list[], T item) {
    ArrayResize(list, ArraySize(list) + 1);
    list[ArraySize(list) - 1] = item;
}

bool IsSymbolInUse(string symbol) {
    for(int i = 0; i <= PositionsTotal(); i += 1) {
        if(PositionGetSymbol(i) == symbol && PositionGetString(POSITION_COMMENT) == TradeComment) {
            return true; 
        }
    }

    return false;
}

bool IsInTradingWindow() {
    MqlDateTime currentTime;
    TimeToStruct(TimeGMT(), currentTime);

    return currentTime.hour >= TradingHoursStart && currentTime.hour <= TradingHoursEnd;
}

void ManageTrades() {
    for(int i = 0; i <= PositionsTotal(); i += 1) {
        if(PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == TradeComment) {
            double profit = PositionGetDouble(POSITION_PROFIT);
            bool isBuyTrade = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double stopLoss = PositionGetDouble(POSITION_SL);
            if (profit > GetRisk() && ((isBuyTrade && stopLoss < entryPrice) || (!isBuyTrade && stopLoss > entryPrice))) {
                string symbol = PositionGetString(POSITION_SYMBOL);
                double currentPrice = SymbolInfoDouble(symbol, isBuyTrade ? SYMBOL_BID : SYMBOL_ASK);
                double takeProfit = PositionGetDouble(POSITION_TP);

                Trade.PositionModify(PositionGetInteger(POSITION_TICKET), entryPrice + 0.5 * (currentPrice - entryPrice), takeProfit);
            }
        }
    }
}
