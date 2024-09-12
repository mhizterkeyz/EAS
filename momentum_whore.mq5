#include <Trade\Trade.mqh>

struct Signal {
  MqlRates lastCandle;
  string type;
  bool successful;
};

input ENUM_TIMEFRAMES TimeFrame = PERIOD_H1;
input int AverageLookupCount = 10;
input int MomentumMultiplier = 2;
input double RR = 3;
input double RiskAmount = 100;

CTrade Trade;
string TradeComment = "MOMENTUM WHORE";
datetime PreviousTime;
string Symbols[] = {
   "XAUUSD",
   "EURJPY",
   "BTCUSD"
};


int OnInit() {
   SendNotification(TradeComment + " Loaded!");
   PreviousTime = iTime(_Symbol, TimeFrame, 0);
   return(INIT_SUCCEEDED);
}

void OnTick() {
    if (iTime(_Symbol, TimeFrame, 0) != PreviousTime) {
        PreviousTime = iTime(_Symbol, TimeFrame, 0);

        for (int i = 0; i < ArraySize(Symbols); i++) {
            string symbol = Symbols[i];
            if (!IsSymbolInUse(symbol)) {
                Signal signal = GetSignal(symbol, TimeFrame);
                if (signal.successful) {
                    if (signal.type == "buy")
                        Buy(symbol, signal.lastCandle);
                    // if (signal.type == "sell")
                    //     Sell(symbol, signal.lastCandle);
                }
            }
        }
    }
}

void Buy(string symbol, MqlRates &momentumCandle) {
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double sl = price - (0.382 * (momentumCandle.high - momentumCandle.low));
    double tp = price + ((price - sl) * RR);
    double volumes[];
    double risk = GetRisk();
    
    CalculateVolume(risk, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        Trade.Buy(volume, symbol, price, sl, tp, TradeComment);
    }
}

void Sell(string symbol, MqlRates &momentumCandle) {
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double sl = price + (0.382 * (momentumCandle.high - momentumCandle.low));
    double tp = price + ((price - sl) * RR);
    double volumes[];
    double risk = GetRisk();
    
    CalculateVolume(risk, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        Trade.Sell(volume, symbol, price, sl, tp, TradeComment);
    }
}

double GetRisk() {
    return RiskAmount;
}

Signal GetSignal(string symbol, ENUM_TIMEFRAMES timeframe) {
    Signal signal;
    MqlRates rates[];

    CopyRates(symbol, timeframe, 1, 1, rates);
    
    MqlRates lastCandle = rates[0];
    double averageMomentum = GetAverageMomentum(symbol, timeframe);
    signal.successful = false;
    if ((lastCandle.high - lastCandle.low) >= (MomentumMultiplier * averageMomentum)) {

        signal.lastCandle = lastCandle;
        signal.type = lastCandle.open > lastCandle.close ? "sell" : "buy";
        signal.successful = true;
    }

    return signal;
}

double GetAverageMomentum(string symbol, ENUM_TIMEFRAMES timeframe) {
    MqlRates rates[];

    CopyRates(symbol, timeframe, 2, AverageLookupCount, rates);

    double totalMomentum = 0;

    for (int i = 0; i < ArraySize(rates); i++) {
        MqlRates rate = rates[i];

        totalMomentum += (rate.high - rate.low);
    }

    return totalMomentum / ArraySize(rates);
}

bool IsSymbolInUse(string symbol) {
    for(int i = 0; i <= PositionsTotal(); i += 1) {
        if(PositionGetSymbol(i) == symbol && PositionGetString(POSITION_COMMENT) == TradeComment) {
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
    
    while (totalProfit < riskAmount) {
        double volume = volumeMin;
        double profit = 0.0;
    
        while (OrderCalcProfit(ORDER_TYPE_BUY, symbol, volume, MathMin(entryPrice, stopLoss), MathMax(entryPrice, stopLoss), profit) && profit < riskAmount && volume < volumeMax) {
            volume += lotStep;
        }
        
        if (profit > riskAmount) {
            volume = volume - lotStep;
        }

        AddToList(volumes, MathMin(volumeMax, NormalizeDouble(volume, decimalPlaces)));
        totalProfit += profit;
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
void AddToList(T &list[], T item)
  {
    ArrayResize(list, ArraySize(list) + 1);
    list[ArraySize(list) - 1] = item;
  }
