#include <Trade\Trade.mqh>

CTrade Trade;

// Input parameters
input double MaxLossUSD = 100.0;     // Maximum allowed loss per trade in USD
input double ProfitTargetUSD = 50.0;  // Initial profit target in USD
input string TradeComment = "Loss Recovery EA";

// Global variables
double lastLoss = 0.0;
double currentProfitTarget;

int OnInit() {
    currentProfitTarget = ProfitTargetUSD;
    
    // Place initial trade with minimum lot size
    if (PositionsTotal() == 0) {
        PlaceInitialTrade();
    }
    
    return(INIT_SUCCEEDED);
}

void OnTick() {
    if (PositionsTotal() == 0) {
        PlaceInitialTrade();
        return;
    }
    
    ManageOpenPosition();
}

void PlaceInitialTrade() {
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    Trade.Sell(minVolume, _Symbol, price, 0, 0, TradeComment);
}

void ManageOpenPosition() {
    for (int i = 0; i < PositionsTotal(); i++) {
        if (PositionGetSymbol(i) != _Symbol || PositionGetString(POSITION_COMMENT) != TradeComment) 
            continue;
            
        double positionProfit = PositionGetDouble(POSITION_PROFIT);
        
        // Check for max loss
        if (positionProfit <= -MaxLossUSD) {
            if (Trade.PositionClose(PositionGetInteger(POSITION_TICKET))) {
                lastLoss -= positionProfit;
                currentProfitTarget += MathAbs(positionProfit);
                Print("Position closed at loss: ", lastLoss, " New profit target: ", currentProfitTarget);
            }
            continue;
        }
        
        // Check for profit target
        if (positionProfit >= currentProfitTarget) {
            if (Trade.PositionClose(PositionGetInteger(POSITION_TICKET))) {
                lastLoss = 0;  // Reset last loss as we've recovered
                currentProfitTarget = ProfitTargetUSD;  // Reset profit target
                Print("Position closed at profit target: ", positionProfit);
            }
            continue;
        }
    }
}
