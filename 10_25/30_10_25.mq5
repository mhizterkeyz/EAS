// 30_10_25.mq5
#include <Trade\Trade.mqh>

CTrade Trade;

struct TrackedSL {
	ulong ticket;
	string symbol;
	double originalSL;
	ENUM_POSITION_TYPE type;
};

TrackedSL trackedSLs[];

// Helper: find index of ticket in tracked array
int FindTrackedIndexByTicket(ulong ticket)
{
	for (int i = 0; i < ArraySize(trackedSLs); i++)
	{
		if (trackedSLs[i].ticket == ticket)
			return i;
	}
	return -1;
}

// Helper: remove tracked item by index (keeps array compact)
void RemoveTrackedByIndex(int index)
{
	int last = ArraySize(trackedSLs) - 1;
	if (index < 0 || index > last)
		return;
	if (index != last)
		trackedSLs[index] = trackedSLs[last];
	ArrayResize(trackedSLs, last);
}

// Enumerate open positions, capture original SLs (do not remove), store per-ticket mapping
void SyncPositionsAndCaptureOriginalSLs()
{
	for (int i = PositionsTotal() - 1; i >= 0; i--)
	{
		if (!PositionSelect(i))
			continue;

		string symbol = PositionGetString(POSITION_SYMBOL);
		double sl = PositionGetDouble(POSITION_SL);
		double tp = PositionGetDouble(POSITION_TP);
		ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
		ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

		// If already tracked, skip
		if (FindTrackedIndexByTicket(ticket) != -1)
			continue;

		// Only act when a hard SL exists
		if (sl > 0.0)
		{
			// Store mapping by ticket
			int newSize = ArraySize(trackedSLs) + 1;
			ArrayResize(trackedSLs, newSize);
			trackedSLs[newSize - 1].ticket = ticket;
			trackedSLs[newSize - 1].symbol = symbol;
			trackedSLs[newSize - 1].originalSL = sl;
			trackedSLs[newSize - 1].type = type;
		}
	}
}

// Adjust broker SL intrabar to avoid triggering until bar close confirms; revert when safe
void AdjustTrackedSLsIntrabar()
{
	for (int i = ArraySize(trackedSLs) - 1; i >= 0; i--)
	{
		ulong ticket = trackedSLs[i].ticket;
		string symbol = trackedSLs[i].symbol;
		double originalSL = trackedSLs[i].originalSL;
		ENUM_POSITION_TYPE type = trackedSLs[i].type;

		if (!PositionSelectByTicket(ticket))
		{
			RemoveTrackedByIndex(i);
			continue;
		}

		double brokerSL = PositionGetDouble(POSITION_SL);
		double tp = PositionGetDouble(POSITION_TP);
		double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
		double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
		double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
		double buffer = 2.0 * point; // small buffer to stay away from trigger

		// Only manage if there's an SL (should be, since we tracked it)
		if (brokerSL <= 0.0)
			continue;

		bool needModify = false;
		double newSL = brokerSL;

		if (type == POSITION_TYPE_BUY)
		{
			// Prevent SL hit intrabar: if price at/under original SL, move SL slightly below current Bid
			if (bid <= originalSL)
			{
				newSL = MathMin(originalSL, bid - buffer);
				if (newSL < brokerSL - (0.1 * point))
					needModify = true;
			}
			// If price moved back above original SL and SL is below original, restore to original
			else if (bid > originalSL && brokerSL < originalSL - (0.1 * point))
			{
				newSL = originalSL;
				needModify = true;
			}
		}
		else if (type == POSITION_TYPE_SELL)
		{
			// Prevent SL hit intrabar: if price at/above original SL, move SL slightly above current Ask
			if (ask >= originalSL)
			{
				newSL = MathMax(originalSL, ask + buffer);
				if (newSL > brokerSL + (0.1 * point))
					needModify = true;
			}
			// If price moved back below original SL and SL is above original, restore to original
			else if (ask < originalSL && brokerSL > originalSL + (0.1 * point))
			{
				newSL = originalSL;
				needModify = true;
			}
		}

		if (needModify)
		{
			if (!Trade.PositionModify(symbol, newSL, tp))
			{
				Print("Failed to adjust SL for ticket ", (string)ticket, " on ", symbol, ": ", _LastError);
			}
		}
	}
}

// Check mapped SLs on bar close; close positions that violate the rule and cleanup missing ones
void CloseTrackedOnBarClose()
{
	for (int i = ArraySize(trackedSLs) - 1; i >= 0; i--)
	{
		ulong ticket = trackedSLs[i].ticket;
		string symbol = trackedSLs[i].symbol;
		double originalSL = trackedSLs[i].originalSL;
		ENUM_POSITION_TYPE type = trackedSLs[i].type;

		// If position no longer exists, drop the record
		if (!PositionSelectByTicket(ticket))
		{
			RemoveTrackedByIndex(i);
			continue;
		}

		// Use last closed candle close on the symbol's current timeframe
		double lastClose = iClose(symbol, PERIOD_CURRENT, 1);
		if (lastClose == 0.0)
			continue;

		bool shouldClose = false;
		if (type == POSITION_TYPE_SELL)
		{
			// For SELL, close if close > SL
			shouldClose = (lastClose > originalSL);
		}
		else if (type == POSITION_TYPE_BUY)
		{
			// For BUY, close if close < SL
			shouldClose = (lastClose < originalSL);
		}

		if (shouldClose)
		{
			if (!Trade.PositionClose(symbol))
			{
				Print("Failed to close position by ticket ", (string)ticket, " on ", symbol, ": ", _LastError);
			}
			// Whether close succeeded or not, if position is gone we remove record
			if (!PositionSelectByTicket(ticket))
			{
				RemoveTrackedByIndex(i);
			}
		}
	}
}

// Run checks once per bar for each symbol represented in positions
bool ShouldProcessNewBar()
{
	static datetime lastBarTime = 0;
	datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
	if (currentBarTime != lastBarTime)
	{
		lastBarTime = currentBarTime;
		return true;
	}
	return false;
}

int OnInit()
{
	ArrayResize(trackedSLs, 0);
	return (INIT_SUCCEEDED);
}

void OnTick()
{
	// Capture any newly-set SLs (do not remove)
	SyncPositionsAndCaptureOriginalSLs();

	// Intrabar: adjust SL to avoid trigger; revert if price retreats
	AdjustTrackedSLsIntrabar();

	// Only evaluate the close condition on new bar close logic
	if (ShouldProcessNewBar())
		CloseTrackedOnBarClose();

	// Cleanup tracked entries whose positions disappeared
	for (int i = ArraySize(trackedSLs) - 1; i >= 0; i--)
	{
		if (!PositionSelectByTicket(trackedSLs[i].ticket))
			RemoveTrackedByIndex(i);
	}
}


