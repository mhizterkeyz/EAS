#include <Trade\Trade.mqh>

// Global variables
int movingAverage;
CTrade Trade;
string TradeComment = "Party Animal";

int OnInit() {
    movingAverage = iMA(_Symbol, 0, 20, 0, MODE_SMA, PRICE_CLOSE);

    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    // Free the indicator handle
    if (movingAverage != INVALID_HANDLE) {
        IndicatorRelease(movingAverage);
    }
}

void OnTick() {
    

    static datetime lastTime = 0;

    if (iTime(_Symbol, PERIOD_M1, 0) != lastTime) {
        lastTime = iTime(_Symbol, PERIOD_M1, 0);
    
        for (int i = 0; i < PositionsTotal(); i += 1) {
            if (PositionGetSymbol(i) == _Symbol && PositionGetString(POSITION_COMMENT) == TradeComment) {
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                if (currentPrice > openPrice) {
                    Trade.PositionClose(PositionGetTicket(i));
                    continue;
                }

                if (iHigh(_Symbol, PERIOD_M1, 1) >= iHigh(_Symbol, PERIOD_M1, 2)) {
                    Trade.PositionClose(PositionGetTicket(i));
                    continue;
                }

                double profit = PositionGetDouble(POSITION_PROFIT);
                if (profit >= 1.0) {
                    Trade.PositionClose(PositionGetTicket(i));
                    continue;
                }

                // double highOfPreviousCandle = iHigh(_Symbol, PERIOD_M1, 3);
                // Trade.PositionModify(PositionGetTicket(i), highOfPreviousCandle, 0);
            }
        }
    }

    if (Period() == PERIOD_H4) {
        static bool printed = false;
        if (!printed) {
            Print("We are in the right tf");
            printed = true;
        }
        double maArray[1];

        if (CopyBuffer(movingAverage, 0, 0, 1, maArray) < 1) return;

        double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if (currentBid < maArray[0]) {
            bool isBullish = iClose(_Symbol, PERIOD_M1, 1) > iOpen(_Symbol, PERIOD_M1, 1);
            if (isBullish && PositionsTotal() < 1) {
                double lotSize = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                Trade.Sell(lotSize, _Symbol, 0, 0, 0, TradeComment);
            }
        }
    } else {
        Print("Wrong tf daddy");
    }

}
