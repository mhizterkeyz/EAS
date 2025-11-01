#include <Trade\Trade.mqh>

CTrade Trade;

struct VirtualStop {
   double entryPrice;
   double stopLoss;
   double takeProfit;
   string exitOn;
   ulong ticket;
   string symbol;
};

VirtualStop VirtualStops[];
int MovingAverageHandle;

int OnInit() {
    MovingAverageHandle = iMA(_Symbol, Period(), 20, 0, MODE_SMA, PRICE_CLOSE);

   return(INIT_SUCCEEDED);
}

void OnTick() {
    Comment("Current trend: " +(string)GetTrend());
}

void CheckAndHandleVirtualStops() {
   double currentPrice;

   for (int i = ArraySize(VirtualStops) - 1; i >= 0; i--) {
      VirtualStop stop = VirtualStops[i];
      currentPrice = (stop.exitOn == "bid") ? SymbolInfoDouble(stop.symbol, SYMBOL_BID) : SymbolInfoDouble(stop.symbol, SYMBOL_ASK);

      if (PositionSelectByTicket(stop.ticket)) {
        long positionType = PositionGetInteger(POSITION_TYPE);
         bool shouldClose = false;

         if (positionType == POSITION_TYPE_BUY) {
            if (currentPrice >= stop.takeProfit || currentPrice <= stop.stopLoss)
               shouldClose = true;
         } else if (positionType == POSITION_TYPE_SELL) {
            if (currentPrice <= stop.takeProfit || currentPrice >= stop.stopLoss)
               shouldClose = true;
         }

         if (shouldClose) {
            if (ClosePositionByTicket(stop.ticket)) {
               ArrayRemove(VirtualStops, i);
            }
         }
      }
   }
}

bool ClosePositionByTicket(ulong ticket) {
   return Trade.PositionClose(ticket);
}

void ArrayRemove(VirtualStop &array[], int index) {
   for (int i = index; i < ArraySize(array) - 1; i++)
      array[i] = array[i + 1];

   ArrayResize(array, ArraySize(array) - 1);
}

int GetTrend() {

    int trend = 0;
    double movingAverageArray[];

    CopyBuffer(MovingAverageHandle, 0, 1, 500, movingAverageArray);

    for (int i = ArraySize(movingAverageArray) - 2; i > 0; i -= 1) {
        if (movingAverageArray[i] > movingAverageArray[i - 1]) {
            trend += 1;
        } else {
            trend -= 1;
        }
    }

    return trend;
}
