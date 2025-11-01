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
int RR = 3;
bool tradePlaced = false; // Flag to indicate if a trade has been placed for the current big move
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
void OnTick()
{
    // Define symbol and timeframe
    string symbol = _Symbol;
    ENUM_TIMEFRAMES timeframe = PERIOD_H1;

    // Copy historical price data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copiedBars = CopyRates(symbol, timeframe, 0, 2, rates);
    if(copiedBars < 2)
    {
        // Not enough bars available
        Print("Not enough bars available for analysis");
        return;
    }

    // Calculate the length of the last two candles
    double lengthLastCandle = rates[0].high - rates[0].low;
    double lengthPreviousCandle = rates[1].high - rates[1].low;

    // Check if the last candle is three or more times the length of the previous candle
    if(lengthLastCandle >= 3 * lengthPreviousCandle)
    {
        // Determine the direction of the heavy move
        double closeLastCandle = rates[0].close;
        double closePreviousCandle = rates[1].close;
        
        if(closeLastCandle > closePreviousCandle)
        {
            // Place a buy trade if a trade hasn't been placed yet
            if(!tradePlaced)
            {
                double entryPrice = rates[0].low + 0.418 * lengthLastCandle; // Buy at the open price of the last candle
                double stopLoss = rates[1].low; // Set stop loss below the low of the previous candle
                double takeProfit = entryPrice + RR * (entryPrice - stopLoss); // 3 to 1 RR ratio

                bool ticket = trade.BuyLimit(MathAbs(NormalizeDouble(200/((entryPrice - stopLoss) * 1e5), 2)), entryPrice, symbol, stopLoss, takeProfit);
                if(ticket)
                {
                    Print("Buy order opened successfully with ticket ", ticket);
                    tradePlaced = true; // Set the flag to indicate that a trade has been placed
                }
                else
                {
                    Print("Failed to open buy order, error code ", GetLastError());
                }
            }
        }
        else if(closeLastCandle < closePreviousCandle)
        {
            // Place a sell trade if a trade hasn't been placed yet
            if(!tradePlaced)
            {
                double entryPrice = rates[0].high - 0.418 * lengthLastCandle; // Sell at the open price of the last candle
                double stopLoss = rates[1].high; // Set stop loss above the high of the previous candle
                double takeProfit = entryPrice - RR * (stopLoss - entryPrice); // 3 to 1 RR ratio

                bool ticket = trade.SellLimit(MathAbs(NormalizeDouble(200/((stopLoss - entryPrice) * 1e5), 2)), entryPrice, symbol, stopLoss, takeProfit);
                if(ticket)
                {
                    Print("Sell order opened successfully with ticket ", ticket);
                    tradePlaced = true; // Set the flag to indicate that a trade has been placed
                }
                else
                {
                    Print("Failed to open sell order, error code ", GetLastError());
                }
            }
        }
        else
        {
            Print("Last candle made a very big move but direction is unclear");
        }

    }
    else
    {
        // Reset the tradePlaced flag if the move is not big enough
        tradePlaced = false;
    }
}

