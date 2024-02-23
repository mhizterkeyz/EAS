#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Variables                                                        |
//+------------------------------------------------------------------+
// input int openHour;
// input int closeHour;
// bool isTradeOpen = false;
double currentHigh = 0;
double currentLow = 10000.0;
double previousHigh = 0;
double previousLow = 0;
double otherPreviousHigh = 0;
double otherPreviousLow = 0;
int minimumRR = 1;

CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   return(INIT_SUCCEEDED);
 }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   
   if (currentTime.hour == 6 && currentTime.min == 0 && currentTime.sec == 0) {
      switchSwingPoints();

      if (PositionsTotal() < 1) {
         bool shouldBuy = previousHigh > otherPreviousHigh && currentPrice < previousHigh;
         bool shouldSell = previousLow < otherPreviousLow && currentPrice > previousLow;
         bool canTrade = !shouldBuy || !shouldSell;
         if (canTrade) {
            if (shouldSell) {
               double takeProfit = MathMin(currentPrice - (previousHigh - currentPrice) * minimumRR, previousLow);
               double ratio = (currentPrice - takeProfit) / (previousHigh - currentPrice);
               Print(MathAbs(NormalizeDouble(200/((currentPrice - previousHigh) * 1e5), 2)));
               if (ratio >= 2) {
                  trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, MathAbs(NormalizeDouble(200/((currentPrice - previousHigh) * 1e5), 2)), currentPrice, previousHigh, takeProfit);
               }
            } else {
               double takeProfit = MathMax(currentPrice + (currentPrice - previousLow) * minimumRR, previousHigh);
               double ratio = (takeProfit - currentPrice) / (currentPrice - previousLow);
               Print(MathAbs(NormalizeDouble(200/((currentPrice - previousLow) * 1e5), 2)));
               if (ratio >= 2) {
                  trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, MathAbs(NormalizeDouble(200/((currentPrice - previousLow) * 1e5), 2)), currentPrice, previousLow, takeProfit);
               }
            }
         }
      }
      currentHigh = currentPrice;
      currentLow = currentPrice;
   }

   currentHigh = MathMax(currentHigh, currentPrice);
   currentLow = MathMin(currentLow, currentPrice);
   
   // if (currentTime.hour >= openHour && !isTradeOpen) {
   //    trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, 1, SymbolInfoDouble(_Symbol, SYMBOL_BID), 0, 0);
   //    isTradeOpen = true;
   // }

 }

 
 void switchSwingPoints(){
   otherPreviousHigh = previousHigh;
   otherPreviousLow = previousLow;
   previousHigh = currentHigh;
   previousLow = currentLow;
 }
