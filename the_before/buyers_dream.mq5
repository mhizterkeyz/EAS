#include <Trade\Trade.mqh>

CTrade Trade;
input string Symbols = "EURGBP,EURJPY,NZDJPY,USDJPY,XAUUSD,GBPJPY,AUDJPY,EURUSD,BTCUSD,GBPUSD,NZDUSD,EURCHF,AUDCHF,NZDCHF,EURNZD,GBPAUD,GBPCAD,EURCAD,GBPCHF,NZDCAD,AUDNZD,GBPNZD,CADCHF,AUDUSD";
input double RiskAmount = 10.0;
input double Target = 11000.0;

string TradeComment = "BuyersDream";
string _Symbols[];
datetime PreviousTimes[];

int OnInit() {
    SendNotification(TradeComment + " Loaded");

    StringSplit(Symbols, ',', _Symbols);
    ArrayResize(PreviousTimes, ArraySize(_Symbols));

    return(INIT_SUCCEEDED);
}

void OnTick() {
    if (AccountInfoDouble(ACCOUNT_EQUITY) >= Target) {
        CloseAllPositions();
        return;
    }

    for (int i = 0; i < ArraySize(_Symbols); i += 1) {
        string symbol = _Symbols[i];
        ENUM_TIMEFRAMES TF = PERIOD_M5;

        if (PreviousTimes[i] == iTime(symbol, TF, 0)) {
            continue;
        }

        double price = SymbolInfoDouble(symbol, SYMBOL_BID);
        bool skip = false;
        for (int i = 1; i < 3; i += 1) {
            if (iOpen(symbol, TF, i) < iClose(symbol, TF, i)) {
                skip = true;
                break;
            }
        }

        if (skip)
            continue;

        if (
            iOpen(symbol, TF, 0) < price ||
            iHigh(symbol, TF, 0) <= iOpen(symbol, TF, 1) ||
            iHigh(symbol, TF, 0) <= iClose(symbol, TF, 2)
        ) {
            continue;
        }

        PreviousTimes[i] = iTime(symbol, TF, 0);
        double entryPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double tp = entryPrice + 5.0 * (iHigh(symbol, TF, 0) - price);
        double sl = entryPrice - 0.2 * (tp - entryPrice);

        double volumes[];
        double risk = RiskAmount;

        CalculateVolume(risk, entryPrice, sl, symbol, volumes);

        for (int i = 0; i < ArraySize(volumes); i++) {
            double volume = volumes[i];
            Trade.Buy(volume, symbol, entryPrice, sl, tp, TradeComment);
        }
    }
}

void CloseAllPositions() {
    for (int i = 0; i <= PositionsTotal(); i += 1) {
        if (PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == TradeComment) {
          Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
        }
      }
}

void CalculateVolume(double riskAmount, double entryPrice, double stopLoss, string symbol, double &volumes[]) {
    double totalProfit = 0.0;
    double volumeMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double volumeMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    int decimalPlaces = GetDecimalPlaces(lotStep);
    double profitForMinLot = 0.0;

    if (!OrderCalcProfit(ORDER_TYPE_BUY, symbol, volumeMin, MathMin(entryPrice, stopLoss), MathMax(entryPrice, stopLoss), profitForMinLot)) {
        AddToList(volumes, volumeMin);
        return;
    }

    double volume = NormalizeDouble((riskAmount * volumeMin) / profitForMinLot, decimalPlaces);

    while (profitForMinLot * volume > riskAmount && volume > lotStep) {
        volume = NormalizeDouble(volume - lotStep, decimalPlaces);
    }

    if (volume > volumeMax) {
        int n = volume / volumeMax;
        for (int i = 0; i < n; i += 1) {
            volume = NormalizeDouble(volume - volumeMax, decimalPlaces);
            AddToList(volumes, volumeMax);
        }
    }

    if (volume > 0.0) {
        AddToList(volumes, volume);
    }
}

int GetDecimalPlaces (double number) {
    int decimalPlaces = 0;
    while (NormalizeDouble(number, decimalPlaces) != number && decimalPlaces < 15) {
        decimalPlaces++;
    }
    return decimalPlaces;
}

template<typename T>
void AddToList(T &list[], T item) {
    ArrayResize(list, ArraySize(list) + 1);
    list[ArraySize(list) - 1] = item;
}
