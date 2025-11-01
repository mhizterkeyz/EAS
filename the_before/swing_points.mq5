input int MinDistanceInPoints = 500; // Minimum Distance of Swing Points in points

color HighLineColor = clrGreen; // Color for swing highs
color LowLineColor = clrRed;    // Color for swing lows
int SwingPointCount = 10;

// Number of candles to check before and after (set to 1 for two-candle span)
#define SPAN 2

int OnInit() {
   return(INIT_SUCCEEDED);
}

void OnTick() {
   IdentifySwingPoints();
}

void IdentifyLatestSwingPoints() {
   int barIndex = SPAN;
   int totalBars = Bars(_Symbol, Period());

   // Find the latest swing high
   int latestHighIndex = -1;
   for (int i = barIndex; i < totalBars - SPAN; i++) {
      if (IsSwingHigh(i)) {
         latestHighIndex = i;
         break;
      }
   }

   // Find the latest swing low
   int latestLowIndex = -1;
   for (int i = barIndex; i < totalBars - SPAN; i++) {
      if (IsSwingLow(i)) {
         latestLowIndex = i;
         break;
      }
   }

   // Validate the swing points
   if (latestHighIndex != -1 && latestLowIndex != -1) {
      double highPrice = iHigh(_Symbol, Period(), latestHighIndex);
      double lowPrice = iLow(_Symbol, Period(), latestLowIndex);

      double distance = MathAbs(highPrice - lowPrice);

      if (distance >= MinDistanceInPoints * Point()) {
         // Draw the lines
         DrawHorizontalLine(latestHighIndex, HighLineColor, "LatestSwingHigh_");
         DrawHorizontalLine(latestLowIndex, LowLineColor, "LatestSwingLow_");
      }
   }
}

bool IsSwingHigh(int index) {
   double currentHigh = iHigh(_Symbol, Period(), index);

   // Check surrounding candles
   for (int j = 1; j <= SPAN; j++) 
   {
      if (iHigh(_Symbol, Period(), index - j) >= currentHigh || iHigh(_Symbol, Period(), index + j) >= currentHigh) {
         return false;
      }
   }

   return true;
}

bool IsSwingLow(int index) {
   double currentLow = iLow(_Symbol, Period(), index);

   // Check surrounding candles
   for (int j = 1; j <= SPAN; j++) 
   {
      if (iLow(_Symbol, Period(), index - j) <= currentLow || iLow(_Symbol, Period(), index + j) <= currentLow) 
      {
         return false;
      }
   }
   return true;
}

void DrawHorizontalLine(int index, color lineColor, string prefix) {
   string lineName = prefix + (string)iTime(_Symbol, Period(), index);
   double price = (prefix == "SwingHigh_") ? iHigh(_Symbol, Period(), index) : iLow(_Symbol, Period(), index);
   datetime startTime = iTime(_Symbol, Period(), index + SPAN);
   datetime endTime = iTime(_Symbol, Period(), index - SPAN);

   if (!ObjectCreate(0, lineName, OBJ_TREND, 0, startTime, price, endTime, price)) 
   {
      Print("Failed to create horizontal line: ", GetLastError());
      return;
   }

   // Set properties for the line
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, lineName, OBJPROP_RAY, false);
}
