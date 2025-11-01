#include <Trade\Trade.mqh>

CTrade Trade;

int OnInit()
{
   Print("Tick time average recorder initialized.");
   return INIT_SUCCEEDED;
}

datetime lastTickTime = 0;
double tickTimeDiffs[20];
int tickIndex = 0;

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Get the current tick time
   datetime currentTickTime = TimeCurrent();
   
   // Calculate the time difference if it's not the first tick
   if (lastTickTime > 0)
   {
      // Calculate time difference between ticks
      double timeDiff = (currentTickTime - lastTickTime);
      
      // Store time difference in array
      tickTimeDiffs[tickIndex] = timeDiff;
      tickIndex++;
      
      // Reset index when array reaches 20 entries
      if (tickIndex >= 20)
      {
         tickIndex = 0;
         double avgTime = CalculateAverage(tickTimeDiffs);
         Comment("Average tick time: " + DoubleToString(avgTime));
      }
   }
   
   // Update last tick time
   lastTickTime = currentTickTime;
}

//+------------------------------------------------------------------+
//| Function to calculate average time of ticks                      |
//+------------------------------------------------------------------+
double CalculateAverage(double &arr[])
{
   double sum = 0;
   int count = ArraySize(arr);
   
   for (int i = 0; i < count; i++)
      sum += arr[i];
   
   return sum / count;
}
