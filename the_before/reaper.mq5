#include <Trade\Trade.mqh>

CTrade Trade;

input double Target = 250;

string TradeComment = "REAPER";
double startingBalance;

int OnInit() {
    startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);

    SendNotification(TradeComment + " Loaded!");

   return (INIT_SUCCEEDED);
}

void OnTick() {
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    if (equity - startingBalance >= Target) {
        for (int i = 0; i < PositionsTotal() * 10; i += 1) {
            if (PositionGetSymbol(i) != "") {
                Trade.PositionClose(PositionGetInteger(POSITION_TICKET));
            }
        }
        
        SendNotification("Congrats broski! Target hit.");
    }
}