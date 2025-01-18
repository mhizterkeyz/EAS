// Moving Average Crossover EA
#property copyright "Crossover EA"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

// Input parameters
input double lotSize = 0.01; // Lot Size Per Trade
input int FastMAPeriod = 10;   // Fast MA period
input int SlowMAPeriod = 50;   // Slow MA period
input ENUM_MA_METHOD MAType = MODE_SMA;   // Moving Average Type (Simple MA)
input double ProfitTarget = 0; // Profit target in currency
input double LossTarget = 0;   // Loss target in currency

// Global variables
int fastMA, slowMA;
CTrade Trade;
string TradeComment = "Crossover EA";

// Function to get the minimum lot size for the symbol
double GetMinimumLot() {
    return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
}

void CloseAllPositions() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == TradeComment) {
            Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
        }
    }
}

void CheckTargets() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == TradeComment) {
            double profit = PositionGetDouble(POSITION_PROFIT);
            if ((ProfitTarget > 0 && profit >= ProfitTarget) || (LossTarget > 0 && profit <= -LossTarget)) {
                Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
            }
        }
    }
}

int OnInit() {
    fastMA = iMA(_Symbol, 0, FastMAPeriod, 0, MAType, PRICE_CLOSE);
    slowMA = iMA(_Symbol, 0, SlowMAPeriod, 0, MAType, PRICE_CLOSE);

    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    // Free the indicator handles
    if (fastMA != INVALID_HANDLE) {
        IndicatorRelease(fastMA);
    }
    if (slowMA != INVALID_HANDLE) {
        IndicatorRelease(slowMA);
    }
}

// The main trading logic
void OnTick() {
    double fastMAArray[3];
    double slowMAArray[3];

    if (CopyBuffer(fastMA, 0, 0, 3, fastMAArray) < 3) return;
    if (CopyBuffer(slowMA, 0, 0, 3, slowMAArray) < 3) return;

    // Check profit and loss targets
    CheckTargets();

    // Crossover logic
    if (fastMAArray[1] >= slowMAArray[1] && fastMAArray[0] < slowMAArray[0] && !IsSymbolInUse(POSITION_TYPE_BUY)) { // Fast MA crosses above Slow MA
        CloseAllPositions(); // Close any existing positions
        Trade.Buy(lotSize, _Symbol, 0, 0, 0, TradeComment);
    } else if (fastMAArray[1] <= slowMAArray[1] && fastMAArray[0] > slowMAArray[0] && !IsSymbolInUse(POSITION_TYPE_SELL)) { // Fast MA crosses below Slow MA
        CloseAllPositions(); // Close any existing positions
        Trade.Sell(lotSize, _Symbol, 0, 0, 0, TradeComment);
    }
}

bool IsSymbolInUse(ENUM_POSITION_TYPE positionType) {
    for(int i = 0; i <= PositionsTotal(); i += 1) {
        if(PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == TradeComment && PositionGetInteger(POSITION_TYPE) == positionType) {
            return true; 
        }
    }

    return false;
}
