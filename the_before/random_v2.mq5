#include <Trade\Trade.mqh>

CTrade Trade;

input double lotSize = 0.01; // Lot size

string TradeComment = "Randomly";
int tradeSec = MathRand() % 60;
datetime lastTradeTime = 0;

int OnInit() {
    return(INIT_SUCCEEDED);
}

void OnTick() {
    TradeManagement();
    long spread = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
    MqlDateTime timeStruct;

    Comment("Spread: " + (string)spread);
    TimeToStruct(TimeCurrent(), timeStruct);

    int currentSec = timeStruct.sec;

    if (
        spread <= 30 &&
        (PositionsTotal() < 1 || (int)(TimeCurrent() - lastTradeTime) >= 60 * 10) &&
        currentSec == tradeSec
    ) {
        if (iOpen(Symbol(), PERIOD_M1, 0) < SymbolInfoDouble(Symbol(),SYMBOL_BID)) {
            Trade.Buy(lotSize, Symbol(), SymbolInfoDouble(Symbol(),SYMBOL_ASK), 0, 0, TradeComment);
        } else {
            Trade.Sell(lotSize, Symbol(), SymbolInfoDouble(Symbol(),SYMBOL_BID), 0, 0, TradeComment);
        }

        lastTradeTime = TimeCurrent();
        tradeSec = MathRand() % 60;
    }
}

void TradeManagement() {
    for(int i = 0; i <= PositionsTotal(); i += 1) {
        string symbol = PositionGetSymbol(i);
        if(symbol == Symbol() && PositionGetString(POSITION_COMMENT) == TradeComment) {
            bool isBuyTrade = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double ask = SymbolInfoDouble(symbol, SYMBOL_BID);
            double bid = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double profit = PositionGetDouble(POSITION_PROFIT);
            double volume = PositionGetDouble(POSITION_VOLUME);
            if (isBuyTrade) {
                if ((entryPrice - ask > 270 * Point()) || profit >= 6 * volume) {
                    Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
                }
            } else {
                if (profit >= 6 * volume || (bid - entryPrice > 270 * Point())) {
                    Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
                }
            }
        }
    }
}
