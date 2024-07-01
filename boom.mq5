//+------------------------------------------------------------------+
//|                                                 jesus_kristi.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>


datetime previousTime;
CTrade trade;
string tradeComment = "Dirty December";
double riskPercent = 1.0;
double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    if (iTime(_Symbol, PERIOD_M1, 0) != previousTime)
    {
        // Update previous candle data
        previousTime = iTime(_Symbol, PERIOD_M1, 0);

        // CloseAllPositions();

        MqlRates rates[];

        CopyRates(_Symbol, PERIOD_M1, 1, 1, rates);

        MqlRates rate = rates[0];
        bool isBullish = rate.open < rate.close;
        bool isFlat = (isBullish && rate.close == rate.high) || (!isBullish && rate.close == rate.low);

        if (isFlat)
          {
            if (isBullish)
              {
                double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double sl = rate.low;
                double volume = GetVolume(price, sl);
                double tp = price + (2 * (price - sl));
                trade.Sell(volume, _Symbol, price, tp, sl, tradeComment);
              }
            else
              {
                double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                double sl = rate.high;
                double volume = GetVolume(price, sl);
                double tp = price + (2 * (price - sl));
                trade.Buy(volume, _Symbol, price, tp, sl, tradeComment);
              }
          }
    }
  }

void CloseAllPositions()
  {
    for (int i = 0; i <= PositionsTotal(); i += 1)
      {
        if (PositionGetSymbol(i) == _Symbol && PositionGetString(POSITION_COMMENT) == tradeComment && PositionGetDouble(POSITION_PROFIT) > 0) {
          trade.PositionClose(PositionGetInteger(POSITION_TICKET));
        }
      }
  }

double GetVolume(double price, double sl)
  {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk = riskPercent / 100 * balance;
    
    return MathAbs(NormalizeDouble(risk / ((price - sl) / point), 2));
  }