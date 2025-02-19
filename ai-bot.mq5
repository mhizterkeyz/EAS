// Function to send a POST request to OpenAI API
string PostRequest(string url, string headers, string body) {
    char postData[];
    ArrayResize(postData, StringLen(body) + 1);
    StringToCharArray(body, postData);

    char result[];  // Allocate buffer for response
    string responseHeaders;
    int timeout = 5000;

    Print("method: ", "POST", " url: ", url, " headers: ", headers, " timeout: ", timeout, " body: ", body);
    
    // Make the web request
    int res = WebRequest("POST", url, headers, timeout, postData, result, responseHeaders);
    if (res == -1) {
        Print("WebRequest failed: ", GetLastError());
        Print("Response Headers: ", responseHeaders);
        return "";
    }

    // Debug: Print the full response and headers
    Print("Response Body: ", CharArrayToString(result));
    Print("Response Headers: ", responseHeaders);

    return CharArrayToString(result);
}

// Convert MqlRates array to JSON string
string ConvertRatesToJSON(MqlRates &rates[], int count) {
    string json = "[";
    for (int i = 0; i < count; i++) {
        json += "{";
        json += "\"time\":" + IntegerToString(rates[i].time) + ",";
        json += "\"open\":" + DoubleToString(rates[i].open) + ",";
        json += "\"high\":" + DoubleToString(rates[i].high) + ",";
        json += "\"low\":" + DoubleToString(rates[i].low) + ",";
        json += "\"close\":" + DoubleToString(rates[i].close) + ",";
        json += "\"volume\":" + IntegerToString(rates[i].tick_volume);
        json += "}";
        if (i < count - 1) {
            json += ",";
        }
    }
    json += "]";
    return json;
}

// Extract "Buy" or "Sell" from API response
string ParseResponse(string response) {
    if (response == "") {
        Print("Empty response from API");
        return "";
    }

    int actionPos = StringFind(response, "\"content\":\"");
    if (actionPos == -1) {
        Print("Action not found in response");
        return "";
    }

    actionPos += 10; // Move past the "content":" part
    int endPos = StringFind(response, "\"", actionPos);
    if (endPos == -1) {
        return "";
    }

    string action = StringSubstr(response, actionPos, endPos - actionPos);
    if (action == "Buy" || action == "Sell") {
        return action;
    }

    return "";
}

// Main function to get an action from ChatGPT
string GetActionFromChatGPT(MqlRates &rates[], int count) {
    string url = "https://webhook.site/a4ef631b-7dd4-4b0c-9086-2f4e10f2fab7";  // Correct OpenAI API endpoint
    
    string system = "Analyze the given price data, which is for "+_Symbol+" 1 hour time frame for the past 10 days, and return either 'Action: Buy' or 'Actions: Sell' or no action depending on the result of your analysis. Also add SL: <price> and TP: <price> when you have an action. Use everything you know on technical analysis that applies to give a signal with very high probability and also add a Probability: <percentage> response. Remember, the goal is to tell me whether to buy or sell with TP and SL price and probability or whether there's no trade opportunity at this time. See if you can squeeze a 1:4 RR in there, but if you can't without making the stop loss too tight or making the trade take longer than a regular intraday trade, then anything 1:1 RR and above is fine too.";
    
    string body = "{\"model\": \"gpt-4o-mini\", \"messages\": [{\"role\": \"system\", \"content\": \""+system+"\"}, {\"role\": \"user\", \"content\": " + ConvertRatesToJSON(rates, count) + "}] }";
    
    string headers = "Content-Type: application/json\r\n"
                     "Authorization: Bearer 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\r\n";  // Replace with actual API key

    // Call the API and get the response
    string response = PostRequest(url, headers, body);
    Print("Response from ChatGPT: ", response);
    
    return ParseResponse(response);
}

int OnInit() {
    MqlRates rates[];
    int copied = CopyRates(Symbol(), PERIOD_H1, TimeCurrent() - 240 * 60 * 60, TimeCurrent(), rates);
    if (copied > 0) {
        string action = GetActionFromChatGPT(rates, copied);
        Print("Action from ChatGPT: ", action);
    } else {
        Print("Failed to copy rates");
    }
    return INIT_SUCCEEDED;
}
