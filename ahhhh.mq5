#include <Trade\Trade.mqh>

CTrade Trade;

input ENUM_TIMEFRAMES LowerTF = PERIOD_M5;
input ENUM_TIMEFRAMES HigherTF = PERIOD_H4;
input double RiskAmount = 100;
input double SLAllowancePoints = 500;
input double RR = 5;
string Symbol = _Symbol;
string TradeComment = "AHHHHHHHH";
datetime PreviousTime;
string UsedFVGs[];

int OnInit() {
    SendNotification(TradeComment + " Loaded!");

   return (INIT_SUCCEEDED);
}

void OnTick() {
    if (iTime(_Symbol, LowerTF, 0) != PreviousTime) {
        PreviousTime = iTime(_Symbol, LowerTF, 0);
        
        string serializedFVG;

        if (LastCandleIsEngulfing() && IsRejectingFromFVG(serializedFVG) && !HasSerializedFVG(serializedFVG)) {
            bool direction = GetDirection();

            Print("serializedFVG: ", serializedFVG);

            if (direction && !IsSymbolInUse(POSITION_TYPE_BUY)) {
                AddToList(UsedFVGs, serializedFVG);
                Buy();
            } 

            if (!direction && !IsSymbolInUse(POSITION_TYPE_SELL)) {
                AddToList(UsedFVGs, serializedFVG);
                Sell();
            }
        }
    }
}

string SerializeCandles(MqlRates &candles[]) {
    string val = "";

    for (int i = 0; i < ArraySize(candles); i += 1) {
        val += TimeToString(candles[i].time, TIME_DATE|TIME_SECONDS);
    }

    return val;
}

bool GetDirection() {
    return iOpen(Symbol, LowerTF, 1) < iClose(Symbol, LowerTF, 1);
}

MqlRates GetRejectingCandle() {
    MqlRates candles[];
    MqlRates rejectingCandle;

    CopyRates(Symbol, LowerTF, 1, 2, candles);

    if (GetDirection()) {
        rejectingCandle = candles[0].low < candles[1].low ? candles[0] : candles[1];
    } else  {
        rejectingCandle = candles[0].high < candles[1].high ? candles[0] : candles[1];
    }

    return rejectingCandle;
}

bool IsRejectingFromFVG(string &serializedFVG) {
    bool isBullish = GetDirection();
    MqlRates higherTFCandles[];
    MqlRates rejectingCandle = GetRejectingCandle();

    // DrawEngulfing(rejectingCandle.high, rejectingCandle.low, rejectingCandle.time, isBullish);

    CopyRates(Symbol, HigherTF, 1, 336, higherTFCandles);

    double lowestBody = DBL_MAX, highestBody = DBL_MIN;

    for (int i = ArraySize(higherTFCandles) - 1; i >= 0; i--) {
        MqlRates lastCandle = higherTFCandles[i];
        MqlRates _candles[];

        CopyRatesToSubArray(higherTFCandles, _candles, i, 3);

        lowestBody = MathMin(lowestBody, MathMin(lastCandle.open, lastCandle.close));
        highestBody = MathMax(highestBody, MathMax(lastCandle.open, lastCandle.close));
        serializedFVG = SerializeCandles(_candles);

        if (
            IsFVG(
                _candles,
                isBullish,
                lowestBody,
                highestBody
            )
        ) {
            if( 
                (isBullish && rejectingCandle.low <= lastCandle.high && rejectingCandle.high > lastCandle.high) ||
                (!isBullish && rejectingCandle.high >= lastCandle.low && rejectingCandle.low < lastCandle.low)
            ) {
                return true;
            }
        }
    }

    return false;
}

bool IsFVG(MqlRates &candles[], bool direction, double lowestBody, double highestBody) {
    if (ArraySize(candles) >= 3) {
        MqlRates firstCandle = candles[0];
        MqlRates secondCandle = candles[1];
        MqlRates thirdCandle = candles[2];
        if (thirdCandle.high < lowestBody || thirdCandle.low > highestBody) {
            if (direction) {
                bool isFVG = firstCandle.low > thirdCandle.high && 
                    MathAbs(secondCandle.open - secondCandle.close) > firstCandle.low - thirdCandle.high;

                    if (isFVG) {
                        DrawFVG(firstCandle.low, thirdCandle.high, thirdCandle.time, direction);
                    }

                    return isFVG;
            } else {
                bool isFVG = firstCandle.high < thirdCandle.low && 
                    MathAbs(secondCandle.open - secondCandle.close) >  thirdCandle.low - firstCandle.high;

                    if (isFVG) {
                        DrawFVG(firstCandle.high, thirdCandle.low, thirdCandle.time, direction);
                    }

                    return isFVG;
            }
        }
    }

    return false;
}

bool HasSerializedFVG(string serializedFVG) {
    for (int i = 0; i < ArraySize(UsedFVGs); i += 1) {
        if (UsedFVGs[i] == serializedFVG) {
            return true;
        }
    }

    return false;
}

bool LastCandleIsEngulfing() {
    MqlRates candles[];

    CopyRates(Symbol, LowerTF, 1, 2, candles);

    MqlRates firstCandle = candles[0];
    MqlRates secondCandle = candles[1];

    bool isEngulfing = MathMax(secondCandle.open, secondCandle.close) >= MathMax(firstCandle.open, firstCandle.close) &&
        MathMin(secondCandle.open, secondCandle.close) <= MathMin(firstCandle.open, firstCandle.close);

    return isEngulfing;
}

void CopyRatesToSubArray(MqlRates &sourceArray[], MqlRates &subArray[], int startIndex, int count) {

    ArrayResize(subArray, count);

    for (int i = 0; i < count; i++) {
        subArray[i] = sourceArray[MathMax(startIndex - i, 0)];
    }
}

// void DrawEngulfing(double price1, double price2, datetime startTime, bool direction) {
//     string objectName = DoubleToString(price1) + "_engulfing";
//     datetime endTime = startTime + 30  * 60;

//     double priceLow = MathMin(price1, price2);
//     double priceHigh = MathMax(price1, price2);

//     RectangleCreate(0, objectName, 0, startTime, priceHigh, endTime, priceLow, direction ? clrGreen : clrRed);
// }

void DrawFVG(double price1, double price2, datetime startTime, bool direction) {
    string objectName = DoubleToString(price1) + "_fvg";
    datetime endTime = TimeCurrent();

    double priceLow = MathMin(price1, price2);
    double priceHigh = MathMax(price1, price2);

    RectangleCreate(0, objectName, 0, startTime, priceHigh, endTime, priceLow, direction ? clrGreen : clrRed);
}

bool RectangleCreate(const long            chart_ID=0,        // chart's ID
                     const string          name="Rectangle",  // rectangle name
                     const int             sub_window=0,      // subwindow index 
                     datetime              time1=0,           // first point time
                     double                price1=0,          // first point price
                     datetime              time2=0,           // second point time
                     double                price2=0,          // second point price
                     const color           clr=clrRed,        // rectangle color
                     const ENUM_LINE_STYLE style=STYLE_SOLID, // style of rectangle lines
                     const int             width=1,           // width of rectangle lines
                     const bool            fill=false,        // filling rectangle with color
                     const bool            back=false,        // in the background
                     const bool            selection=true,    // highlight to move
                     const bool            hidden=false,       // hidden in the object list
                     const long            z_order=0)         // priority for mouse click
  {
   ResetLastError();
//--- create a rectangle by the given coordinates
   if(!ObjectCreate(chart_ID,name,OBJ_RECTANGLE,sub_window,time1,price1,time2,price2))
     {
      Print(__FUNCTION__,
            ": failed to create a rectangle! Error code = ",GetLastError());
      return(false);
     }
//--- set rectangle color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set the style of rectangle lines
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
//--- set width of the rectangle lines
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);
//--- enable (true) or disable (false) the mode of filling the rectangle
   ObjectSetInteger(chart_ID,name,OBJPROP_FILL,fill);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of highlighting the rectangle for moving
//--- when creating a graphical object using ObjectCreate function, the object cannot be
//--- highlighted and moved by default. Inside this method, selection parameter
//--- is true by default making it possible to highlight and move the object
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }

double GetRisk() {
    return RiskAmount;
}

void Buy() {
    string symbol = Symbol;
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    MqlRates rejectionCandle = GetRejectingCandle();
    double points = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double sl = rejectionCandle.low - (SLAllowancePoints * points);
    double tp = price + (price - sl) * RR;
    double volumes[];
    double risk = GetRisk();

    CalculateVolume(risk, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        Trade.Buy(volume, symbol, price, sl, tp, TradeComment);
    }
}

void Sell() {
    string symbol = Symbol;
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    MqlRates rejectionCandle = GetRejectingCandle();
    double points = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double sl = rejectionCandle.high + (SLAllowancePoints * points);
    double tp = price + (price - sl) * RR;
    double volumes[];
    double risk = GetRisk();

    CalculateVolume(risk, price, sl, symbol, volumes);

    for (int i = 0; i < ArraySize(volumes); i++) {
        double volume = volumes[i];
        Trade.Sell(volume, symbol, price, sl, tp, TradeComment);
    }
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

bool IsSymbolInUse(ENUM_POSITION_TYPE positionType) {
    for(int i = 0; i <= PositionsTotal(); i += 1) {
        if(PositionGetSymbol(i) == Symbol && PositionGetString(POSITION_COMMENT) == TradeComment && PositionGetInteger(POSITION_TYPE) == positionType) {
            return true; 
        }
    }

    return false;
}
