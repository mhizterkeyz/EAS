//+------------------------------------------------------------------+
//|                                                  PsychologicalLevels|
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                       http://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>

//+------------------------------------------------------------------+
//| Expert variables                                                 |
//+------------------------------------------------------------------+
input double levelsSize = 100;
input double stopSize = 100.0;
input double RR = 0.5;
input double riskPercent = 2.0;
input double partialAndBreakEvenAt = 50.0;
bool hasTouchedOrCrossed = false;
double psychologicalLevels[], higherLevel, currentLevel, lowerLevel, point = SymbolInfoDouble(_Symbol, SYMBOL_POINT), step;
int sellAdvice = 0, buyAdvice = 0, rejections = 0;
int hlCount = 50;
ulong g_PositionsPartialed[];
datetime previousTime;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  // Get symbol properties
  double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  double hundredPipPoint = point * levelsSize * 10.0;
  double nearestPrice = MathFloor(price / hundredPipPoint) * hundredPipPoint;

  ArrayResize(psychologicalLevels, hlCount * 2);

  // Calculate psychological levels
  step = levelsSize * 10.0 * point;

  // Draw horizontal lines for psychological levels
  for (int i = -hlCount; i < hlCount; i++)
  {
    double level = nearestPrice + i * step;

    ObjectCreate(0, "PsychologicalLevel_" + IntegerToString(i), OBJ_HLINE, 0, 0, level);
    ObjectSetInteger(0, "PsychologicalLevel_" + IntegerToString(i), OBJPROP_COLOR, clrLightGray);
    psychologicalLevels[i + hlCount] = level;
  }

  // Initialize previous candle data
  previousTime = 0;

  return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  // Remove horizontal lines
  for (int i = 0; i < 10; i++)
  {
    ObjectDelete(0, "PsychologicalLevel_" + IntegerToString(i));
  }
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
  // Check if there's a new candle
  if (iTime(_Symbol, PERIOD_CURRENT, 0) != previousTime)
  {
    // Update previous candle data
    previousTime = iTime(_Symbol, PERIOD_CURRENT, 0);

    MqlRates rates[];

    CopyRates(_Symbol, PERIOD_CURRENT, 1, 2, rates);

    for (int i = -hlCount; i < hlCount; i++)
    {
      double level = psychologicalLevels[i + hlCount];
      bool resisting = rates[1].close <= level && rates[1].open <= level && rates[1].high >= level;
      bool supporting = rates[1].open >= level && rates[1].close >= level && rates[1].low <= level;
      if (resisting)
      {
        sellAdvice = MathMax(3, sellAdvice + 3);
      }
      if (supporting)
      {
        buyAdvice = MathMax(3, buyAdvice + 3);
      }
      hasTouchedOrCrossed = resisting || supporting;
      if (hasTouchedOrCrossed)
      {
        if (level != currentLevel)
        {
          rejections = 0;
        }
        if (resisting)
        {
          rejections--;
        }
        if (supporting)
        {
          rejections++;
        }
        higherLevel = psychologicalLevels[i + hlCount + 1];
        currentLevel = level;
        lowerLevel = psychologicalLevels[i + hlCount - 1];
        break;
      }
    }

    // Check for engulfing candle at psychological levels
    if (hasTouchedOrCrossed || buyAdvice >= 1 || sellAdvice >= 1 || MathAbs(rejections) >= 3)
    {
      int isEngulfing = IsEngulfingCandle();
      long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if (rejections >= 3 && IsEngulfingCandle() == 1)
      {
        if (!IsTradeOpen(POSITION_TYPE_BUY))
        {
          // trade.PositionClose(_Symbol);
          double balance = AccountInfoDouble(ACCOUNT_BALANCE);
          double risk = riskPercent / 100 * balance;
          double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
          double stopLoss = currentLevel - stopSize * 10 * point;
          if (entryPrice - currentLevel >= 0.4 * step)
          {
            stopLoss = currentLevel;
          }
          double takeProfit = MathMax(higherLevel, entryPrice + RR * (entryPrice - stopLoss));
          trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, MathAbs(NormalizeDouble(risk / ((entryPrice - stopLoss) / point), 2)), entryPrice, stopLoss, takeProfit);
        }
        buyAdvice = 0;
        rejections = 0;
      }
      else if (rejections <= -3 && IsEngulfingCandle() == -1)
      {
        if (!IsTradeOpen(POSITION_TYPE_SELL))
        {
          // trade.PositionClose(_Symbol);
          double balance = AccountInfoDouble(ACCOUNT_BALANCE);
          double risk = riskPercent / 100 * balance;
          double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
          double stopLoss = currentLevel + stopSize * 10 * point;
          if (currentLevel - entryPrice >= 0.4 * step)
          {
            stopLoss = currentLevel;
          }
          double takeProfit = MathMin(lowerLevel, entryPrice - RR * (stopLoss - entryPrice)) + spread * point;
          trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, MathAbs(NormalizeDouble(risk / ((entryPrice - stopLoss) / point), 2)), entryPrice, stopLoss, takeProfit);
        }
        sellAdvice = 0;
        rejections = 0;
      }
      else
      {
        hasTouchedOrCrossed = false;
      }
    }
    buyAdvice--;
    sellAdvice--;
  }

  ClosePartialAndBreakEven();
}

// Function to check for engulfing candlestick pattern
int IsEngulfingCandle()
{
  MqlRates prevBar[];

  if (CopyRates(_Symbol, PERIOD_CURRENT, 1, 2, prevBar) != 2)
  {
    Print("Error: Unable to copy price data!");
    return 0;
  }

  MqlRates recentBar = prevBar[1];
  MqlRates olderBar = prevBar[0];
  bool isEngulfing = recentBar.low < olderBar.low && recentBar.high > olderBar.high && MathAbs(recentBar.open - recentBar.close) >= 100 * point;

  // Check for bullish engulfing candle
  if (recentBar.open < recentBar.close && isEngulfing)
    return 1;

  // Check for bearish engulfing candle
  if (recentBar.open > recentBar.close && isEngulfing)
    return -1;

  return 0;
}

bool IsTradeOpen(ENUM_POSITION_TYPE orderType)
{
  for (int i = 0; i < PositionsTotal(); i++)
  {
    if (PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_TYPE) == orderType)
    {
      return true; // Found an open trade of the specified type
    }
  }

  return false; // No open trade of the specified type found
}

void ClosePartialAndBreakEven()
{
  // Iterate through all open positions
  for (int i = 0; i < PositionsTotal(); i++)
  {
    // Select the position by its index
    if (PositionGetSymbol(i) != _Symbol)
    {
      Print("Error selecting position: ", GetLastError());
      continue; // Skip to the next position if selection fails
    }

    // Check if the position is profitable
    double profit = PositionGetDouble(POSITION_PROFIT);
    double takeProfit = PositionGetDouble(POSITION_TP);
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double volume = PositionGetDouble(POSITION_VOLUME);
    double potentialProfit = volume * MathAbs(entryPrice - takeProfit) / point;
    ulong ticket = PositionGetInteger(POSITION_TICKET);
    double percent = partialAndBreakEvenAt / 100;

    if (IsPositionPartialed(ticket))
    {
      Print("Position ", ticket, " has already had partials taken");
      continue; // Skip to the next position
    }

    if (profit >= percent * potentialProfit)
    {
      // Close 75% of the position
      if (!trade.PositionClosePartial(ticket, NormalizeDouble(volume * percent, 2)))
      {
        Print("Error closing partial position: ", GetLastError());
        continue; // Skip to the next position if closing fails
      }

      // Set stop loss to breakeven
      if (!trade.PositionModify(ticket, entryPrice, takeProfit + point * 1))
      {
        Print("Error setting stop loss to breakeven: ", GetLastError());
        continue; // Skip to the next position if modification fails
      }
      // Add the position to the list of positions with partials taken
      AddPositionToPartialedList(ticket);

      Print("Closed partial position and set stop loss to breakeven for position ", PositionGetInteger(POSITION_TICKET));
    }
  }
}

// Function to check if a position has already had partials taken
bool IsPositionPartialed(ulong ticket)
{
  for (int i = 0; i < ArraySize(g_PositionsPartialed); i++)
  {
    if (g_PositionsPartialed[i] == ticket)
      return true;
  }
  return false;
}

// Function to add a position to the list of positions with partials taken
void AddPositionToPartialedList(ulong ticket)
{
  ArrayResize(g_PositionsPartialed, ArraySize(g_PositionsPartialed) + 1);
  g_PositionsPartialed[ArraySize(g_PositionsPartialed) - 1] = ticket;
}
