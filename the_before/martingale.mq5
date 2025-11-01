#include <Trade\Trade.mqh>

CTrade Trade;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
input double StartLotSize = 0.01; // Initial lot size
input double Multiplier = 2.0; // Martingale multiplier
input double StopSize = 50.0; // Stop loss in pips
input double RR = 2.0; // Risk-to-Reward ratio
input int MaxTrades = 5; // Maximum trades per cycle

input int AsianSessionStartHour = 0;  // Asian session start (GMT)
input int AsianSessionEndHour = 8;    // Asian session end (GMT)

// Variables
double entryPrice;
double stopLoss;
double takeProfit;
int tradeCount = 0;
bool newCycle = true;
string TradeComment = "Martingale";
double startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);

int OnInit() {
   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Check if it's Asian session                                      |
//+------------------------------------------------------------------+
bool IsAsianSession() {
   MqlDateTime timeStruct;

    TimeToStruct(TimeCurrent(), timeStruct);

    int currentHour = timeStruct.hour;

   return (currentHour >= AsianSessionStartHour && currentHour < AsianSessionEndHour);
}

//+------------------------------------------------------------------+
//| Indicators for Entry                                             |
//+------------------------------------------------------------------+
string CheckEntryConditions() {
    string entry = "";

    // Indicator arrays
    double slow[];
    double fast[];
    double rsiArr[];

   // Example Indicator 1: Moving Average
   int maSlow = iMA(Symbol(), PERIOD_M15, 50, 0, MODE_SMA, PRICE_CLOSE);
   int maFast = iMA(Symbol(), PERIOD_M15, 10, 0, MODE_SMA, PRICE_CLOSE);

   // Example Indicator 2: Relative Strength Index (RSI)
   int rsi = iRSI(Symbol(), PERIOD_M15, 14, PRICE_CLOSE);

   CopyBuffer(maSlow, 0, 0, 3, slow);
   CopyBuffer(maFast, 0, 0, 3, fast);
   CopyBuffer(rsi, 0, 0, 3, rsiArr);

   // Entry conditions
   if (fast[1] > slow[1] && rsiArr[1] < 30) entry = "buy";  // Buy Signal
   if (fast[1] < slow[1] && rsiArr[1] > 70) entry = "sell"; // Sell Signal

   return entry;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size for Martingale                                |
//+------------------------------------------------------------------+
double CalculateLotSize() {
   return StartLotSize * MathPow(Multiplier, tradeCount);
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss and Take Profit                              |
//+------------------------------------------------------------------+
void CalculateStopAndTakeProfit(bool isBuy) {
   if (isBuy) {
      stopLoss = entryPrice - StopSize * Point();
      takeProfit = entryPrice + (StopSize * RR * Point());
   } else {
      stopLoss = entryPrice + StopSize * Point();
      takeProfit = entryPrice - (StopSize * RR * Point());
   }
}

//+------------------------------------------------------------------+
//| Close All Trades at End of Asian Session                         |
//+------------------------------------------------------------------+
void CloseAllTrades() {
    for (int i = 0; i <= PositionsTotal(); i += 1) {
        if (PositionGetSymbol(i) != Symbol()) {
          Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
        }
      }
}

//+------------------------------------------------------------------+
//| Execute a Trade based on Signal                                  |
//+------------------------------------------------------------------+
void ExecuteTrade() {
   string entry = CheckEntryConditions();
   if (entry == "buy" || entry == "sell") {
   double lotSize = CalculateLotSize();
    bool isBuy = entry == "buy";
    entryPrice = isBuy ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);

    CalculateStopAndTakeProfit(isBuy);

    int ticket;
    if (isBuy) {
        ticket = Trade.Buy(lotSize, Symbol(), entryPrice, stopLoss, takeProfit, TradeComment);
    } else {
        ticket = Trade.Sell(lotSize, Symbol(), entryPrice, stopLoss, takeProfit, TradeComment);
    }

    if (ticket > 0) {
        tradeCount++;
        newCycle = (tradeCount >= MaxTrades);
        startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   if (!IsAsianSession()) {
      CloseAllTrades();
      newCycle = true;
      tradeCount = 0;
      startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      return;
   }

    if (PositionsTotal() < 1) {
        if (newCycle) {
            ExecuteTrade();
            newCycle = false;
        } else if (AccountInfoDouble(ACCOUNT_BALANCE) <= startingBalance) {
            ExecuteTrade();
        }
    }
}
