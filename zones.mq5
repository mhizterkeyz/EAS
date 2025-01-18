#include <Trade\Trade.mqh>

CTrade Trade;

input int TradingHoursStart = 7; // Start hour of trading
input int TradingHoursEnd = 19;  // End hour of trading
input double zoneSize = 60; // Size of zones in points
input double tradeVolume = 0.01; // Lotsize per trade

string TradeComment = "ZaZoneZone";
double upperZone;
double currentZone;
double lowerZone;

int OnInit() {
    SetZones();

    return(INIT_SUCCEEDED);
}

void OnTick() {
    ManageTrades();

    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if (price >= upperZone || price <= lowerZone) {
        SetZones();
    }
}

void ManageTrades() {
    for(int i = 0; i <= PositionsTotal(); i += 1) {
        if(PositionGetSymbol(i) != "" && PositionGetString(POSITION_COMMENT) == TradeComment) {
            double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            bool isBuyTrade = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
            if (
                isBuyTrade &&
                (
                    price <= currentZone - ((currentZone - lowerZone) / 2) ||
                    price >= upperZone
                )
            ) {
                Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
            }

            if (
                !isBuyTrade &&
                (
                    price >= currentZone + ((upperZone - currentZone) / 2) ||
                    price <= lowerZone
                )
            ) {
                Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
            }
        }
    }
}

string CheckEntry() {
    string entry = "";
    int i = 1;
    while(iHigh(_Symbol, PERIOD_M1, i) < upperZone && iLow(_Symbol, PERIOD_M1, i) > lowerZone) {
        i += 1;
    }

    if (iHigh(_Symbol, PERIOD_M1, i) >= upperZone) {
        entry = "sell";
    }

    if (iLow(_Symbol, PERIOD_M1, i) <= lowerZone) {
        entry = "buy";
    }

    return entry; 
}

bool IsInTradingWindow() {
    MqlDateTime currentTime;
    TimeToStruct(TimeGMT(), currentTime);

    return currentTime.hour >= TradingHoursStart && currentTime.hour <= TradingHoursEnd;
}

void SetZones() {
    double points = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    currentZone = price;
    upperZone = currentZone + (zoneSize * points);
    lowerZone = currentZone - (zoneSize * points);

    if (IsInTradingWindow()) {
        string entry = CheckEntry();

        if (entry == "buy") {
            Trade.Buy(tradeVolume, _Symbol, price, 0, upperZone, TradeComment);
        }

        if (entry == "sell") {
            Trade.Sell(tradeVolume, _Symbol, price, 0, lowerZone, TradeComment);
        }
    }

    DrawHorizontalLines(upperZone, currentZone, lowerZone);
}

void DrawHorizontalLines(double price1, double price2, double price3, color lineColor = clrRed, int lineWidth = 1)
{
    // Array to hold the prices
    double prices[] = {price1, price2, price3};
    
    // Loop through the prices and create horizontal lines
    for (int i = 0; i < ArraySize(prices); i++)
    {
        // Generate a unique name for each line
        string lineName = "ZonesHorizontalLine_" + (string)i;
        
        // Create the line object
        if (!ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, prices[i]))
        {
            Print("Failed to create horizontal line for price ", prices[i], ": ", GetLastError());
            continue;
        }
        
        // Set the line's properties
        ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);   // Line color
        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, lineWidth);  // Line width
        ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);// Line style
        ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, true);  // Allow selection
        ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);  // No extension to the right
    }
}
