// 16_10_25.mq5
#include <Trade\Trade.mqh>

CTrade Trade;

input double TP_SIZE = 1071.0; // TP size in points

double CurrentNeckLine = DBL_MIN;

int OnInit() {
    return(INIT_SUCCEEDED);
}

void OnTick() {
    if (PositionsTotal() > 0) {
        return;
    }

    MarkNeckLine();

    Comment("Distance from neck line: " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID) - CurrentNeckLine));

    if (PriceIsSufficientDistanceFromNeckLine()) {
        Buy();
    }
}

void Buy() {
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = entryPrice - TP_SIZE * 3.3;
    double tp = CurrentNeckLine;

    Trade.Buy(0.01, _Symbol, entryPrice, sl, tp);
}

bool IsBullish(int index) {
    return iClose(_Symbol, PERIOD_CURRENT, index) > iOpen(Symbol(), PERIOD_CURRENT, index);
}

double GetNeckLine() {
    if (IsBullish(1) && IsBullish(2)) {
        return iClose(_Symbol, PERIOD_CURRENT, 1);
    }

    return DBL_MIN;
}

void MarkNeckLine() {
    if (PositionsTotal() > 0) {
        return;
    }

     double neckLine = GetNeckLine();
    if (neckLine > DBL_MIN) {
        CurrentNeckLine = neckLine;
        DrawHorizontalLine("NeckLine", CurrentNeckLine, clrGreen);
    }
}

bool PriceIsSufficientDistanceFromNeckLine() {
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double distanceFromNeckLine = currentPrice - CurrentNeckLine;
    return CurrentNeckLine > DBL_MIN && distanceFromNeckLine >= TP_SIZE;
}

void DrawHorizontalLine(string name, double price, color lineColor) {
    if (ObjectFind(0, name) == -1) {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    } else {
        ObjectMove(0, name, 0, 0, price);
    }
}
