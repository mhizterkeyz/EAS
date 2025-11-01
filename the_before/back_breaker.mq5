#include <Trade\Trade.mqh>

int h4SMA;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
    // Initialization code here
    h4SMA = iMA(_Symbol, PERIOD_H4, 20, 0, MODE_SMA, PRICE_CLOSE);

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Cleanup code here
    if (h4SMA != INVALID_HANDLE)
        IndicatorRelease(h4SMA);
}

bool IsBullish(int index, ENUM_TIMEFRAMES TF) {
    return iOpen(_Symbol, TF, index) < iClose(_Symbol, TF, index);
}

bool IsBearish(int index, ENUM_TIMEFRAMES TF) {
    return iOpen(_Symbol, TF, index) > iClose(_Symbol, TF, index);
}

void DrawNecklineRay(double neckLine, datetime time) {
    // Define a unique name for the neckline ray
    string objectName = "NecklineRay";

    // Delete the previous neckline ray if it exists
    if (ObjectFind(0, objectName) != -1) { // ObjectFind returns -1 if the object is not found
        ObjectDelete(0, objectName);
    }

    // Create a new horizontal ray line
    if (ObjectCreate(0, objectName, OBJ_HLINE, 0, time, neckLine)) {
        ObjectSetInteger(0, objectName, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, objectName, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 2);
        Print("Neckline drawn at price: ", neckLine, " and time: ", time);
    } else {
        Print("Failed to create neckline ray.");
    }
}

void OnTick() {
    static datetime last4Hour = 0;

    if (iTime(_Symbol, PERIOD_H4, 0) != last4Hour) {
        double maArray[1];

        if (CopyBuffer(h4SMA, 0, 0, 1, maArray) < 1) return;

        if (
            iClose(_Symbol, PERIOD_H4, 1) > maArray[0] &&
            IsBullish(2, PERIOD_H4) && 
            IsBearish(1, PERIOD_H4) &&
            iClose(_Symbol, PERIOD_H4, 2) == iOpen(_Symbol, PERIOD_H4, 1)
        ) {
            static double neckLine = iClose(_Symbol, PERIOD_H4, 2);
            static bool neckLineType = true;

            DrawNecklineRay(neckLine, iTime(_Symbol, PERIOD_H4, 2));
        }

        if (
            iClose(_Symbol, PERIOD_H4, 1) < maArray[0] &&
            IsBearish(2, PERIOD_H4) &&
            IsBullish(1, PERIOD_H4) && 
            iClose(_Symbol, PERIOD_H4, 2) == iOpen(_Symbol, PERIOD_H4, 1)
        ) {
            static double neckLine = iClose(_Symbol, PERIOD_H4, 2);
            static bool neckLineType = false;

            DrawNecklineRay(neckLine, iTime(_Symbol, PERIOD_H4, 2));
        }
    }
}
