#include <Trade\Trade.mqh>

input int TradingHoursStart = 18;  // Start hour for trading window
input int TradingHoursEnd = 4;     // End hour for trading window
input double MaxAllowedSpread = 50.0;  // Maximum allowed spread to enter trades (in points)
input double LotSize = 0.01;  // Position Size Per Trade

CTrade Trade;
string TradeComment = "ABOBI";

int OnInit()
{
    // Initialization code here
    return(INIT_SUCCEEDED);
}

bool hasValidSpread(double maxAllowedSpread)
{
    long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

    return spread <= maxAllowedSpread;
}

bool inTradingWindow(int startHour, int endHour)
{
    MqlDateTime currentTime;
    TimeToStruct(TimeGMT(), currentTime);

    // Check if the current time is within the trading window
    if (startHour < TradingHoursEnd) {
        return currentTime.hour >= startHour && currentTime.hour <= endHour;
    } else {
        return currentTime.hour >= startHour || currentTime.hour <= endHour;
    }
}

bool hasOpenPosition(ENUM_POSITION_TYPE positionType)
{
    for (int i = 0; i < PositionsTotal(); i++) {
        if (PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_TYPE) == positionType && PositionGetString(POSITION_COMMENT) == TradeComment) {
            return true;
        }
    }
    return false;
}

void TradeManager() {
    for (int i = 0; i < PositionsTotal(); i++) {
        if (PositionGetSymbol(i) == _Symbol && PositionGetString(POSITION_COMMENT) == TradeComment) {
            bool isBuyPosition = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
            double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);

            if (
                (
                    isBuyPosition &&
                    ((bidPrice >= entryPrice + 10 * _Point) || (askPrice <= entryPrice - 50 * _Point))
                ) ||
                !inTradingWindow(TradingHoursStart, TradingHoursEnd)
            ) {
                Trade.PositionClose(PositionGetInteger(POSITION_IDENTIFIER));
            }

            if (
                (
                    !isBuyPosition &&
                    ((askPrice <= entryPrice - 10 * _Point) || (bidPrice >= entryPrice + 50 * _Point))
                ) ||
                !inTradingWindow(TradingHoursStart, TradingHoursEnd)
            ) {
                Trade.PositionClose(PositionGetInteger(POSITION_IDENTIFIER));
            }
        }
    }
}

void OnTick()
{
    if (hasValidSpread(MaxAllowedSpread) && inTradingWindow(TradingHoursStart, TradingHoursEnd)) {
        if (!hasOpenPosition(POSITION_TYPE_BUY)) {
            // Enter a buy trade
            Trade.Buy(LotSize, _Symbol, 0, 0, 0, TradeComment);
        }

        if (!hasOpenPosition(POSITION_TYPE_SELL)) {
            // Enter a sell trade
            Trade.Sell(LotSize, _Symbol, 0, 0, 0, TradeComment);
        }
    }

    TradeManager();
}
