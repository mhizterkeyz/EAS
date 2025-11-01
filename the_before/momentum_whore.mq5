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
input string Symbols = "XAUUSD,EURJPY,BTCUSD";

CTrade Trade;
string TradeComment = "MOMENTUM WHORE";
datetime PreviousTime;
string _Symbols[];


int OnInit() {
   SendNotification(TradeComment + " Loaded!");
   PreviousTime = iTime(_Symbol, TimeFrame, 0);
   StringSplit(Symbols, ',', _Symbols);
   return(INIT_SUCCEEDED);
}

void OnTick() {
    if (iTime(_Symbol, TimeFrame, 0) != PreviousTime) {
        PreviousTime = iTime(_Symbol, TimeFrame, 0);

        for (int i = 0; i < ArraySize(_Symbols); i++) {
            string symbol = _Symbols[i];
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

/**
 * Break even when it starts going your way (use current method with 100% (1 * x)) - maybe
 * As the next candle no b green, gedifuck out (if e close below your entry)
 * Reduce risk by 25% on SL hit
 */

void Buy(string symbol, MqlRates &momentumCandle) {
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double sl = price - (0.382 * (momentumCandle.high - momentumCandle.low));
    double tp = price + ((price - sl) * RR);
    double volumes[];
    double risk = GetRisk();
    SendNotification("Buy trade on "+symbol+" executed!");
    
    CalculateVolume(risk, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        SendNotification("Buy "+symbol+" "+DoubleToString(volume)+" TP: "+DoubleToString(tp)+" SL: "+DoubleToString(sl));
        Trade.Buy(volume, symbol, price, sl, tp, TradeComment);
    }
}

void Sell(string symbol, MqlRates &momentumCandle) {
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double sl = price + (0.382 * (momentumCandle.high - momentumCandle.low));
    double tp = price + ((price - sl) * RR);
    double volumes[];
    double risk = GetRisk();
    SendNotification("Sell trade on "+symbol+" executed!");
    
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
    bool isMomentumCandle = (lastCandle.high - lastCandle.low) >= (MomentumMultiplier * averageMomentum);
    long spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
    double points = SymbolInfoDouble(symbol, SYMBOL_POINT);
    bool candleHasSizeableBody = MathAbs(lastCandle.open - lastCandle.close) > spread * points * 70;
    if (isMomentumCandle && candleHasSizeableBody) {

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
    
        while (OrderCalcProfit(ORDER_TYPE_BUY, symbol, volume, MathMin(entryPrice, stopLoss), MathMax(entryPrice, stopLoss), profit) && profit < (riskAmount - totalProfit) && volume < volumeMax) {
            volume += lotStep;
        }
        
        if (profit > (riskAmount - totalProfit)) {
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

void ManageTrades() {
    for(int i = 0; i <= PositionsTotal(); i += 1) {
        if(PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == TradeComment) {
            double stopLoss = PositionGetDouble(POSITION_SL);
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            bool isBuyTrade = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
            string symbol = PositionGetString(POSITION_SYMBOL);
            double currentPrice = SymbolInfoDouble(symbol, isBuyTrade ? SYMBOL_BID : SYMBOL_ASK);
            bool is200PercentOfSL = MathAbs(currentPrice - entryPrice) >= 1 * MathAbs(stopLoss - entryPrice);
            bool isModified = (isBuyTrade && (stopLoss >= entryPrice)) || (!isBuyTrade && (stopLoss <= entryPrice));
            if (!isModified && is200PercentOfSL) {
                double newStopLoss = entryPrice + 0.25 * (currentPrice - entryPrice);
                double takeProfit = PositionGetDouble(POSITION_TP);
                long ticket = PositionGetInteger(POSITION_TICKET);

                Trade.PositionModify(ticket, newStopLoss, takeProfit);
            }
        }
    }
}
