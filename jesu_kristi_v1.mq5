#include <Trade\Trade.mqh>

struct OrderParams {
  double volume;
  double price;
  double tp;
  double sl;
};

input double RiskAmount = 10;
input double RR = 5;
input ENUM_TIMEFRAMES TimeFrame = PERIOD_H1;

datetime previousTime;
CTrade trade;
string tradeComment = "JESU KRISTI V2";
string symbols[] = {
    // "XAUUSD",
//   "NZDUSD",
//    "NZDJPY",
//    "EURJPY",
//    "USDJPY",
//    "AUDJPY",
//    "CHFJPY",
//    "AUDUSD",
//    "CADJPY", 
//    "GBPJPY",
//    "BTCUSD",
//    "EURNZD",
//    "GBPNZD",
   "EURGBP",
//    "GBPCAD"
};

int OnInit() {
    return(INIT_SUCCEEDED);
}

void OnTick() {
    if (iTime(_Symbol, TimeFrame, 0) != previousTime) {
        previousTime = iTime(_Symbol, TimeFrame, 0);

        for (int i = 0; i < ArraySize(symbols); i += 1) {
            string symbol = symbols[i];

            if (!IsSymbolInUse(symbol)) {
                MqlRates rates[];

                if (IsBearishEngulfing(symbol, TimeFrame, rates)) {
                    Buy(symbol, rates[1]);
                }

                if (IsBullishEngulfing(symbol, TimeFrame, rates)) {
                    Sell(symbol, rates[1]);
                }
            }
        }
    }
}

void Buy(string symbol, MqlRates &rate) {
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double sl = price + ((price - rate.high) * 2);
    double tp = price + ((price - sl) * 0.1);
    double volume = CalculateVolume(RiskAmount, price, sl, symbol);

    trade.Buy(volume, symbol, price, sl, tp, tradeComment);
}

void _Buy(string symbol, MqlRates &rate) {
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double sl = rate.low;
    double tp = price + ((price - sl) * RR);
    double volume = CalculateVolume(RiskAmount, price, sl, symbol);

    trade.Buy(volume, symbol, price, sl, tp, tradeComment);
}

void Sell(string symbol, MqlRates &rate) {
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double sl = price + ((price - rate.low) * 2);
    double tp = price + ((price - sl) * 0.1);
    double volume = CalculateVolume(RiskAmount, price, sl, symbol);

    trade.Sell(volume, symbol, price, sl, tp, tradeComment);
}

void _Sell(string symbol, MqlRates &rate) {
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double sl = rate.high;
    double tp = price + ((price - sl) * RR);
    double volume = CalculateVolume(RiskAmount, price, sl, symbol);

    trade.Sell(volume, symbol, price, sl, tp, tradeComment);
}

bool IsBullishEngulfing(string symbol, ENUM_TIMEFRAMES timeframe, MqlRates &rates[]) {
    CopyRates(symbol, timeframe, 1, 2, rates);

    MqlRates firstCandle = rates[0];
    MqlRates secondCandle = rates[1];
    double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);

    // return firstCandle.high - firstCandle.low >= 100 * pointSize &&
      return  firstCandle.open > firstCandle.close &&
        secondCandle.close > secondCandle.open &&
        firstCandle.high < secondCandle.high &&
        secondCandle.low < firstCandle.low &&
        firstCandle.open < secondCandle.close &&
        secondCandle.open < firstCandle.close;
}

bool IsBearishEngulfing(string symbol, ENUM_TIMEFRAMES timeframe, MqlRates &rates[]) {
    CopyRates(symbol, timeframe, 1, 2, rates);

    MqlRates firstCandle = rates[0];
    MqlRates secondCandle = rates[1];
    double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);

    // return firstCandle.high - firstCandle.low >= 100 * pointSize &&
       return firstCandle.close > firstCandle.open &&
        secondCandle.open > secondCandle.close &&
        firstCandle.high < secondCandle.high &&
        secondCandle.low < firstCandle.low &&
        firstCandle.close < secondCandle.open &&
        secondCandle.close < firstCandle.open;
}

bool IsSymbolInUse(string symbol) {
    for(int i = 0; i <= PositionsTotal(); i += 1)
    {
        if(PositionGetSymbol(i) == symbol && PositionGetString(POSITION_COMMENT) == tradeComment)
            {
            return true; 
            }
    }

    for(int j = 0; j < OrdersTotal(); j += 1)
    {
        if(OrderGetTicket(j) && OrderGetString(ORDER_SYMBOL) == symbol && OrderGetString(ORDER_COMMENT) == tradeComment)
            {
            return true;
            }
    }

    return false;
}

double CalculateVolume(double riskAmount, double entryPrice, double stopLoss, string symbol) {
    double volumeMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double volumeMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double volume = volumeMin;
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double profit = 0.0;
    int decimalPlaces = GetDecimalPlaces(lotStep);

    int counter = 0;
    while (OrderCalcProfit(ORDER_TYPE_BUY, symbol, volume, MathMin(entryPrice, stopLoss), MathMax(entryPrice, stopLoss), profit) && profit < riskAmount && volume < volumeMax) {
        volume += lotStep;
    }

    if (profit > riskAmount) {
        volume = volume - lotStep;
    }

    return MathMin(volumeMax, MathMax(NormalizeDouble(volume, decimalPlaces), volumeMin));
}

int GetDecimalPlaces (double number) {
    int decimalPlaces = 0;
    while (NormalizeDouble(number, decimalPlaces) != number && decimalPlaces < 15) {
        decimalPlaces += 1;
    }
    

    return decimalPlaces;
}
