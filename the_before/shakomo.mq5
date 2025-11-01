#include <Trade\Trade.mqh>

// Struct for virtual stop management
struct VirtualStop {
   double entryPrice;
   double stopLoss;
   double takeProfit;
   string exitOn;
   ulong ticket;
   string symbol;
   string slLineName;
   string tpLineName;
   datetime openTime;
};

// Input parameters
input double StopSize = 50.0;        // Stop size in points
input double TotalCapital = 1000.0;  // Total allowed capital

// Global variables
CTrade Trade;
VirtualStop VirtualStops[];
double dailyRiskAmount;
int tradeTimes[];
bool tradesExecuted[];  // Track which time slots have been traded
datetime lastDayChecked = 0;
string TradeComment = "Random10x";
bool tpHitToday = false;

int OnInit() {
    dailyRiskAmount = TotalCapital / 10;
    GenerateTradeTimes();
    return(INIT_SUCCEEDED);
}

void OnTick() {
    // Check for new day
    MqlDateTime now;
    TimeToStruct(TimeCurrent(), now);
    datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", now.year, now.mon, now.day));
    
    if (today != lastDayChecked) {
        lastDayChecked = today;
        GenerateTradeTimes();
        tpHitToday = false;  // Reset TP flag for new day
    }
    
    // Manage virtual stops
    CheckVirtualStops();
    
    // Check if we can trade
    if (PositionsTotal() > 0 || tpHitToday) {  // Add tpHitToday check
        return;
    }
    
    int timeIndex;
    if (IsTradeTime(timeIndex)) {
        PlaceRandomTrade();
        tradesExecuted[timeIndex] = true;
    }
}

void GenerateTradeTimes() {
    ArrayResize(tradeTimes, 10);
    ArrayResize(tradesExecuted, 10);
    for(int i = 0; i < 10; i++) {
        tradeTimes[i] = (int)MathRand() % 1440; // Random minute in the day
        tradesExecuted[i] = false;  // Reset execution status
    }
    ArraySort(tradeTimes);
}

bool IsTradeTime(int &timeIndex) {
    MqlDateTime now;
    TimeToStruct(TimeCurrent(), now);
    int currentMinute = now.hour * 60 + now.min;
    
    for(int i = 0; i < ArraySize(tradeTimes); i++) {
        if(currentMinute == tradeTimes[i] && !tradesExecuted[i]) {
            timeIndex = i;
            return true;
        }
    }
    timeIndex = -1;
    return false;
}

void PlaceRandomTrade() {
    bool isBuy = MathRand() % 2 == 0;
    double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double stopLoss = isBuy ? price - StopSize * Point() : price + StopSize * Point();
    double takeProfit = isBuy ? price + StopSize * Point() * 10 : price - StopSize * Point() * 10;
    
    double volume = CalculatePositionSize(dailyRiskAmount, price, stopLoss);
    
    if(isBuy) {
        if(Trade.Buy(volume, _Symbol, price, 0, 0, TradeComment)) {
            AddVirtualStop(price, stopLoss, takeProfit, "bid", Trade.ResultOrder(), _Symbol);
        }
    } else {
        if(Trade.Sell(volume, _Symbol, price, 0, 0, TradeComment)) {
            AddVirtualStop(price, stopLoss, takeProfit, "ask", Trade.ResultOrder(), _Symbol);
        }
    }
}

void CheckVirtualStops() {
    double currentPrice;
    MqlDateTime now, openTime;
    TimeToStruct(TimeCurrent(), now);
    datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", now.year, now.mon, now.day));
    
    for(int i = ArraySize(VirtualStops) - 1; i >= 0; i--) {
        VirtualStop stop = VirtualStops[i];
        currentPrice = (stop.exitOn == "bid") ? 
            SymbolInfoDouble(stop.symbol, SYMBOL_BID) : 
            SymbolInfoDouble(stop.symbol, SYMBOL_ASK);
            
        if(PositionSelectByTicket(stop.ticket)) {
            long positionType = PositionGetInteger(POSITION_TYPE);
            bool shouldClose = false;
            bool isTpHit = false;
            
            if(positionType == POSITION_TYPE_BUY) {
                if(currentPrice >= stop.takeProfit) {
                    shouldClose = true;
                    isTpHit = true;
                }
                else if(currentPrice <= stop.stopLoss) {
                    shouldClose = true;
                }
            } else if(positionType == POSITION_TYPE_SELL) {
                if(currentPrice <= stop.takeProfit) {
                    shouldClose = true;
                    isTpHit = true;
                }
                else if(currentPrice >= stop.stopLoss) {
                    shouldClose = true;
                }
            }
            
            if(shouldClose) {
                if(ClosePosition(stop.ticket)) {
                    DeleteStopLines(stop);
                    
                    // Check if TP hit was same day as open
                    if(isTpHit) {
                        TimeToStruct(stop.openTime, openTime);
                        datetime openDay = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", 
                            openTime.year, openTime.mon, openTime.day));
                            
                        if(openDay == today) {
                            tpHitToday = true;
                            Print("Take profit hit on same-day trade - stopping trades for today");
                        }
                    }
                    
                    ArrayRemove(VirtualStops, i);
                }
            }
        }
    }
}

void AddVirtualStop(double entryPrice, double stopLoss, double takeProfit, string exitOn, ulong ticket, string symbol) {
    VirtualStop stop;
    stop.entryPrice = entryPrice;
    stop.stopLoss = stopLoss;
    stop.takeProfit = takeProfit;
    stop.exitOn = exitOn;
    stop.ticket = ticket;
    stop.symbol = symbol;
    stop.openTime = TimeCurrent();
    
    DrawStopLines(stop);
    
    ArrayResize(VirtualStops, ArraySize(VirtualStops) + 1);
    VirtualStops[ArraySize(VirtualStops) - 1] = stop;
}

bool ClosePosition(ulong ticket) {
    return Trade.PositionClose(ticket);
}

void ArrayRemove(VirtualStop &array[], int index) {
    for(int i = index; i < ArraySize(array) - 1; i++)
        array[i] = array[i + 1];
    ArrayResize(array, ArraySize(array) - 1);
}

double CalculatePositionSize(double riskAmount, double entryPrice, double stopLoss) {
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    double slDistance = MathAbs(entryPrice - stopLoss);
    double tickCount = slDistance / tickSize;
    double ticksValue = tickCount * tickValue;
    
    double volume = NormalizeDouble(riskAmount / ticksValue, 2);
    volume = MathFloor(volume / lotStep) * lotStep;
    
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    volume = MathMax(minVolume, MathMin(maxVolume, volume));
    
    return volume;
}

void DrawStopLines(VirtualStop &stop) {
    stop.slLineName = "SL_" + (string)stop.ticket;
    stop.tpLineName = "TP_" + (string)stop.ticket;
    
    ObjectCreate(0, stop.slLineName, OBJ_HLINE, 0, 0, stop.stopLoss);
    ObjectSetInteger(0, stop.slLineName, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, stop.slLineName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, stop.slLineName, OBJPROP_WIDTH, 1);
    
    ObjectCreate(0, stop.tpLineName, OBJ_HLINE, 0, 0, stop.takeProfit);
    ObjectSetInteger(0, stop.tpLineName, OBJPROP_COLOR, clrGreen);
    ObjectSetInteger(0, stop.tpLineName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, stop.tpLineName, OBJPROP_WIDTH, 1);
}

void DeleteStopLines(VirtualStop &stop) {
    ObjectDelete(0, stop.slLineName);
    ObjectDelete(0, stop.tpLineName);
}

void OnDeinit(const int reason) {
    for(int i = ArraySize(VirtualStops) - 1; i >= 0; i--) {
        DeleteStopLines(VirtualStops[i]);
    }
}
