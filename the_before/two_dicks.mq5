#include <Trade\Trade.mqh>

input string Symbols = "EURCHF";
input double RR = 2;
input double RiskAmount = 100;
input ENUM_TIMEFRAMES HigherTF = PERIOD_H4;
input ENUM_TIMEFRAMES LowerTF = PERIOD_H1;

CTrade Trade;
string TradeComment = "TWO DICKS";
string _Symbols[];double FibMultiplier = 0.5;
string signals[];

int OnInit() {
   SendNotification(TradeComment + " Loaded!");
   StringSplit(Symbols, ',', _Symbols);
   return(INIT_SUCCEEDED);
}

void OnTick() {
        for (int i = 0; i < ArraySize(_Symbols); i += 1) {
            string symbol = _Symbols[i];
            MqlRates rates[];

            CopyRates(symbol, HigherTF, 0, 3, rates);

            string signal = GetSignal(symbol, rates);
            if (signal == "buy" && !IsSymbolInUse(symbol, POSITION_TYPE_BUY)) {
                Buy(symbol, LowerTF);
            }
            
            if (signal == "sell" && !IsSymbolInUse(symbol, POSITION_TYPE_SELL)) {
                Sell(symbol, LowerTF);
            }

        }
}

string FormatDateTime(datetime time) {
  MqlDateTime currentTime;
  TimeToStruct(TimeGMT(), currentTime);

  return StringFormat("%02d/%02d/%02d %02d", currentTime.year, currentTime.mon, currentTime.day, currentTime.hour);
}

void Buy(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates lastCandle = GetLastCandle(symbol, timeframe);
    string signal = "Buy " + symbol + " " + FormatDateTime(lastCandle.time);
    if (!IsSignalCalled(signal)) {
        AddToList(signals, signal);
        SendNotification("Buy Potential on " + symbol);
    }
    // double sl = price - (FibMultiplier * (lastCandle.close - lastCandle.open));
    // double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    // double tp = price + (price - sl) * RR;
    // double volumes[];
    // double risk = GetRisk();

    // CalculateVolume(risk, price, sl, symbol, volumes);

    // for (int i = 0; i < ArraySize(volumes); i++) {
    //     double volume = volumes[i];
    //     Trade.Buy(volume, symbol, price, sl, tp, TradeComment);
    // }
}

void Sell(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates lastCandle = GetLastCandle(symbol, timeframe);
    string signal = "Sell " + symbol + " " + FormatDateTime(lastCandle.time);
    if (!IsSignalCalled(signal)) {
        AddToList(signals, signal);
        SendNotification("Sell Potential on " + symbol);
    }
    // MqlRates lastCandle = GetLastCandle(symbol, timeframe);
    // double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    // double sl = price + (FibMultiplier * (lastCandle.open - lastCandle.close));
    // double tp = price - (sl - price) * RR;
    // double volumes[];
    // double risk = GetRisk();

    // CalculateVolume(risk, price, sl, symbol, volumes);

    // for (int i = 0; i < ArraySize(volumes); i++) {
    //     double volume = volumes[i];
    //     Trade.Sell(volume, symbol, price, sl, tp, TradeComment);
    // }
}

double GetRisk() {
    return RiskAmount;
}

MqlRates GetLastCandle(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates rates[];

    CopyRates(symbol, timeframe, 1, 1, rates);

    return rates[0];
}

string GetSignal(string symbol, MqlRates &candles[]) {
    string signal = "NA";

    if (ArraySize(candles) == 3) {
        MqlRates firstCandle = candles[0];
        MqlRates secondCandle = candles[1];
        MqlRates thirdCandle = candles[2];

        if (GetDirection(firstCandle) != GetDirection(secondCandle) && GetDirection(secondCandle) != GetDirection(thirdCandle)) {
            double points = SymbolInfoDouble(symbol, SYMBOL_POINT);
            double allowance = 50 * points;
            double isBuying = GetDirection(thirdCandle);
            double lowerTFOpen = iOpen(symbol, LowerTF, 1);
            double lowerTFClose = iClose(symbol, LowerTF, 1);

            if (MathAbs(firstCandle.open - secondCandle.close) <= allowance) {
                double neckLine = isBuying ? MathMax(firstCandle.open, secondCandle.close) : MathMin(firstCandle.open, secondCandle.close);

                if (isBuying && lowerTFClose > neckLine && lowerTFOpen < neckLine) {
                    signal = "buy";
                }

                if (!isBuying && lowerTFClose < neckLine && lowerTFOpen > neckLine) {
                    signal = "sell";
                }
            }

            if (MathAbs(firstCandle.close - secondCandle.open) <= allowance) {
                double neckLine = isBuying ? MathMax(firstCandle.close, secondCandle.open) : MathMin(firstCandle.close, secondCandle.open);

                if (isBuying && lowerTFClose > neckLine && lowerTFOpen < neckLine) {
                    signal = "buy";
                }

                if (!isBuying && lowerTFClose < neckLine && lowerTFOpen > neckLine) {
                    signal = "sell";
                }
            }
        }
    }

    return signal;
}

bool GetDirection(MqlRates &candle) {
    return candle.open < candle.close;
}

bool IsSymbolInUse(string symbol, ENUM_POSITION_TYPE positionType) {
    for(int i = 0; i <= PositionsTotal(); i += 1) {
        if(PositionGetSymbol(i) == symbol && PositionGetString(POSITION_COMMENT) == TradeComment && PositionGetInteger(POSITION_TYPE) == positionType) {
            return true; 
        }
    }

    return false;
}

void CalculateVolume(double riskAmount, double entryPrice, double stopLoss, string symbol, double &volumes[]) {
    double totalProfit = 0.0;
    double volumeMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double volumeMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    int decimalPlaces = GetDecimalPlaces(lotStep);
    int maxIterations = 1000;
    int iterations = 0;
    
    while (totalProfit < riskAmount && iterations < maxIterations) {
        double volume = volumeMin;
        double profit = 0.0;
        int _maxIterations = 1000;
        int _iterations = 0;

    
        while (OrderCalcProfit(ORDER_TYPE_BUY, symbol, volume, MathMin(entryPrice, stopLoss), MathMax(entryPrice, stopLoss), profit) && profit < (riskAmount - totalProfit) && volume < volumeMax && _iterations < _maxIterations) {
            volume += lotStep;
            _iterations += 1;
        }
        
        if (profit > (riskAmount - totalProfit)) {
            volume = volume - lotStep;
        }

        AddToList(volumes, MathMin(volumeMax, NormalizeDouble(volume, decimalPlaces)));
        totalProfit += profit;
        iterations += 1;
    }
}

int GetDecimalPlaces (double number) {
    int decimalPlaces = 0;
    while (NormalizeDouble(number, decimalPlaces) != number && decimalPlaces < 15) {
        decimalPlaces += 1;
    }

    return decimalPlaces;
}

template<typename T>
void AddToList(T &list[], T item) {
    ArrayResize(list, ArraySize(list) + 1);
    list[ArraySize(list) - 1] = item;
}

bool IsSignalCalled(string signal)
  {
    for (int i = ArraySize(signals) - 1; i >= 0; i--)
    {
      if (signals[i] == signal)
        return true;
    }
    return false;
  }
