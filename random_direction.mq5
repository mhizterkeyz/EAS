#include <Trade\Trade.mqh>

// Input parameters
input int TimeToCheck = 60;          // Time to check positions (in minutes)
input double MaxLoss = -1000.0;      // Maximum allowed loss
input double ProfitTarget = 1000.0;  // Profit target
input double LotSize = 0.01;         // Position size

// Global variables
CTrade Trade;
datetime NextTradeTime;
bool EATerminated = false;
string TradeComment = "Random Direction EA";
double startingBalance;

// Define structures to hold pending actions
struct PendingClose {
    ulong ticket;
};

struct PendingTrade {
    ENUM_ORDER_TYPE type;
};

// Arrays to store pending actions
PendingClose pendingCloses[];
PendingTrade pendingTrades[];

int OnInit() {
    // Place initial random trade on startup
    if (PositionsTotal() == 0) {
        PlaceRandomTrade();
    }
    startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    NextTradeTime = TimeCurrent() + TimeToCheck * 60;
    return(INIT_SUCCEEDED);
}

void OnTick() {
    if (EATerminated) return;
    
    // Check total equity relative to starting balance
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double totalPnL = currentEquity - startingBalance;
    
    // Check for max loss or profit target
    if (totalPnL <= MaxLoss || totalPnL >= ProfitTarget) {
        CloseAllPositions();
        EATerminated = true;
        SendNotification(TradeComment + " terminated due to " + 
            (totalPnL <= MaxLoss ? "max loss" : "profit target") + " reached");
        return;
    }
    
    // Check if it's time for a new trade
    if (TimeCurrent() >= NextTradeTime) {
        // Clear previous pending actions
        ArrayResize(pendingCloses, 0);
        ArrayResize(pendingTrades, 0);
        
        bool allBuysNegative = true;
        bool allSellsNegative = true;
        bool anyBuyProfit = false;
        bool anySellProfit = false;
        
        // First pass - analyze profitability
        for (int i = 0; i < PositionsTotal(); i++) {
            if (PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == TradeComment) {
                double positionProfit = PositionGetDouble(POSITION_PROFIT);
                bool isBuyPosition = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
                
                if (isBuyPosition) {
                    if (positionProfit >= 0) {
                        allBuysNegative = false;
                        anyBuyProfit = true;
                    }
                } else {
                    if (positionProfit >= 0) {
                        allSellsNegative = false;
                        anySellProfit = true;
                    }
                }
            }
        }
        
        // Second pass - collect actions
        for (int i = 0; i < PositionsTotal(); i++) {
            if (PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == TradeComment) {
                bool isBuyPosition = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
                
                // Add position to close list if all positions of that type are negative
                if ((isBuyPosition && allBuysNegative) || (!isBuyPosition && allSellsNegative)) {
                    PendingClose close;
                    close.ticket = PositionGetInteger(POSITION_TICKET);
                    ArrayResize(pendingCloses, ArraySize(pendingCloses) + 1);
                    pendingCloses[ArraySize(pendingCloses) - 1] = close;
                }
            }
        }
        
        // Add one new trade if there's profit in that direction
        if (anyBuyProfit && ArraySize(pendingTrades) == 0) {
            PendingTrade trade;
            trade.type = ORDER_TYPE_BUY;
            ArrayResize(pendingTrades, 1);
            pendingTrades[0] = trade;
        } else if (anySellProfit && ArraySize(pendingTrades) == 0) {
            PendingTrade trade;
            trade.type = ORDER_TYPE_SELL;
            ArrayResize(pendingTrades, 1);
            pendingTrades[0] = trade;
        }
        
        // Execute all pending closes first
        bool closedAnyPositions = false;
        ENUM_POSITION_TYPE lastClosedType = POSITION_TYPE_BUY; // Default value

        for (int i = 0; i < ArraySize(pendingCloses); i++) {
            if (Trade.PositionClose(pendingCloses[i].ticket)) {
                closedAnyPositions = true;
                // Store the type of position we just closed
                if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                    lastClosedType = POSITION_TYPE_BUY;
                } else {
                    lastClosedType = POSITION_TYPE_SELL;
                }
            }
        }

        // Open one position in opposite direction if we closed any positions
        if (closedAnyPositions) {
            if (lastClosedType == POSITION_TYPE_BUY) {
                Trade.Sell(LotSize, _Symbol, 0, 0, 0, TradeComment);
            } else {
                Trade.Buy(LotSize, _Symbol, 0, 0, 0, TradeComment);
            }
        }

        // Execute pending trade (if any) - only if we didn't close any positions
        if (!closedAnyPositions && ArraySize(pendingTrades) > 0) {
            if (pendingTrades[0].type == ORDER_TYPE_BUY) {
                Trade.Buy(LotSize, _Symbol, 0, 0, 0, TradeComment);
            } else {
                Trade.Sell(LotSize, _Symbol, 0, 0, 0, TradeComment);
            }
        }
        
        // Update next trade time
        NextTradeTime = TimeCurrent() + TimeToCheck * 60;
    }
}

void PlaceRandomTrade() {
    bool isBuy = MathRand() % 2 == 0;
    
    if (isBuy) {
        Trade.Buy(LotSize, _Symbol, 0, 0, 0, TradeComment);
    } else {
        Trade.Sell(LotSize, _Symbol, 0, 0, 0, TradeComment);
    }
}

void CloseAllPositions() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == TradeComment) {
            Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
        }
    }
}
