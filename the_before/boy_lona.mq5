#include <Trade\Trade.mqh>

CTrade Trade;

input double RiskAmount = 20.0;

string TradeComment = "Boy Lona";
double startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
bool canTrade = true;
datetime previousDay;

int OnInit() {
    return(INIT_SUCCEEDED);
}

void OnTick() {
    Comment("Starting Balance: " + DoubleToString(startingBalance));
    if (iTime(_Symbol, PERIOD_D1, 0) != previousDay)
    {
        previousDay = iTime(_Symbol, PERIOD_M1, 0);
        startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    }

    if (PositionsTotal() < 1)
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        canTrade = balance <= startingBalance;

        if (canTrade) {
            MqlRates candles[];

            CopyRates(_Symbol, PERIOD_M1, 1, 3, candles);

            if (
                // first candle is bullish
                candles[0].open < candles[0].close &&
                // second candle is bullish
                candles[1].open < candles[1].close &&
                // third candle is bullish
                candles[2].open < candles[2].close &&
                // first candle closes where second opens
                candles[0].close == candles[1].open &&
                // second candle closes where thrid opens
                candles[1].close == candles[2].open &&
                // third candle low is below open of second
                candles[2].low < candles[1].open &&
                // third candle open > second candle open
                candles[2].open > candles[1].open
            )
            {
                double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                double points = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                double sl = price - 50.0 * points;
                double tp = price + 5.0 * (price - sl);
                double volumes[];

                Print("Price: ", price);
                
                CalculateVolume(RiskAmount, price, sl, _Symbol, volumes);

                for (int i = 0; i < ArraySize(volumes); i++) {
                    double volume = volumes[i];
                    Trade.Buy(volume, _Symbol, price, sl, tp, TradeComment);
                }
                startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
            }
        }
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
        decimalPlaces++;
    }
    return decimalPlaces;
}

template<typename T>
void AddToList(T &list[], T item) {
    ArrayResize(list, ArraySize(list) + 1);
    list[ArraySize(list) - 1] = item;
}