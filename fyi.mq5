#include <Trade\Trade.mqh>

CTrade Trade;
input string InputSymbols = "XAUUSD"; // Symbols

string Symbols[];

int OnInit() {
    StringSplit(InputSymbols, ',', Symbols);

    return(INIT_SUCCEEDED);
}

void DrawCandleBox(string symbol, ENUM_TIMEFRAMES timeFrame, int startIndex, color boxColor) {
    // Get the times, highs, and lows of the two consecutive candles
    datetime time1 = iTime(symbol, timeFrame, startIndex);
    datetime time2 = iTime(symbol, timeFrame, startIndex + 1);

    double high1 = iHigh(symbol, timeFrame, startIndex);
    double low1 = iLow(symbol, timeFrame, startIndex);

    double high2 = iHigh(symbol, timeFrame, startIndex + 1);
    double low2 = iLow(symbol, timeFrame, startIndex + 1);

    // Determine the coordinates of the rectangle
    double boxHigh = MathMax(high1, high2);
    double boxLow = MathMin(low1, low2);

    // Generate a unique name for the rectangle based on the symbol and start time
    string boxName = symbol + "_CandleBox_" + IntegerToString(time1);

    // Create the rectangle object
    if (!ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, time1, boxHigh, time2, boxLow)) {
        Print("Failed to create rectangle for candles: ", GetLastError());
        return;
    }

    // Set rectangle properties
    ObjectSetInteger(0, boxName, OBJPROP_COLOR, boxColor);
    ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, boxName, OBJPROP_BACK, true);    // Draw in background
    ObjectSetInteger(0, boxName, OBJPROP_RAY_RIGHT, false); // No right ray extension
    ObjectSetInteger(0, boxName, OBJPROP_SELECTABLE, false);
}

void OnTick() {
    for (int i = 0; i < ArraySize(Symbols); i += 1) {
        string symbol = Symbols[i];

        for (int i = 1; i < 8; i += 1) {
            // double points = SymbolInfoDouble(symbol, SYMBOL_POINT);
            // double spread = MathMax(SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID), 10.0 * points);

            bool isKeyLevel = iOpen(symbol, PERIOD_H4, i) > iClose(symbol, PERIOD_H4, i) != iOpen(symbol, PERIOD_H4, i + 1) > iClose(symbol, PERIOD_H4, i + 1);
            if (isKeyLevel) {
                DrawCandleBox(symbol, PERIOD_H4, i, clrRed);
            }
        }
    }
}
