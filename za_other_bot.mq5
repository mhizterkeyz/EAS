#include <Trade\Trade.mqh>

CTrade Trade;
input ulong MAGIC_NUMBER = 123456; // Define a unique magic number
input double RR = 3; // Risk-to-reward

int OnInit()
{
    return INIT_SUCCEEDED;
}

double GetMA(int period) {
    double maBuffer[];
    if (CopyBuffer(iMA(_Symbol, PERIOD_CURRENT, period, 0, MODE_SMA, PRICE_CLOSE), 0, 1, 1, maBuffer) > 0) {
        return maBuffer[0];
    }
    return 0;
}

void OnTick()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    if (bid > GetMA(50) && PositionsTotalByMagic() < 1)
    {
        double sl = MathMin(MathMin(GetMA(50), GetMA(100)), GetMA(200));
        double tp = bid + (bid - sl) * RR;
        Trade.SetExpertMagicNumber(MAGIC_NUMBER); // Set the magic number
        Trade.Buy(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), _Symbol, 0, sl, tp, "Buy Order");
    }

    if (ask < GetMA(50) && PositionsTotalByMagic() < 1)
    {
        double sl = MathMax(MathMax(GetMA(50), GetMA(100)), GetMA(200));
        double tp = ask - (sl - ask) * RR;
        Trade.SetExpertMagicNumber(MAGIC_NUMBER); // Set the magic number
        Trade.Sell(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), _Symbol, 0, sl, tp, "Sell Order");
    }

    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (PositionSelectByTicket(PositionGetTicket(i)) && PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
        {
            double newSL;
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                newSL = MathMin(MathMin(GetMA(50), GetMA(100)), GetMA(200));
                if (newSL > PositionGetDouble(POSITION_SL))
                {
                    Trade.PositionModify(PositionGetTicket(i), newSL, PositionGetDouble(POSITION_TP));
                }
            }
            else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
                newSL = MathMax(MathMax(GetMA(50), GetMA(100)), GetMA(200));
                if (newSL < PositionGetDouble(POSITION_SL))
                {
                    Trade.PositionModify(PositionGetTicket(i), newSL, PositionGetDouble(POSITION_TP));
                }
            }
        }
    }
}

int PositionsTotalByMagic()
{
    int total = 0;
    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (PositionSelectByTicket(PositionGetTicket(i)) && PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
        {
            total++;
        }
    }
    return total;
}