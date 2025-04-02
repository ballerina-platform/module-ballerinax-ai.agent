import ballerina/io;
import ballerina/lang.regexp;

type SearchParams record {|
    string query;
|};

type CalculatorParams record {|
    string expression;
|};

type MessageRequest record {|
    string[] to;
    string subject;
    string body;
|};

// create two mock tools 
isolated function searchToolMock(*SearchParams params) returns string {
    string query = params.query.trim().toLowerAscii();
    if regexp:isFullMatch(re `.*girlfriend.*`, query) {
        return "Camila Morrone";

    } else if regexp:isFullMatch(re `.*age.*`, query) {
        return "25 years";
    }
    else {
        return "Can't find. Stop!";
    }
}

isolated function calculatorToolMock(*CalculatorParams params) returns string {
    string expression = params.expression.trim();
    if (expression == "25 ^ 0.43") {
        return "Answer: 3.991298452658078";
    } else {
        return "Can't compute. Some information is missing";
    }
}

isolated function sendMail(record {|string senderEmail; MessageRequest messageRequest;|} 'input) returns string|error {
    if 'input.senderEmail == "test@email.com" {
        return error("Invalid sender email");
    } else {
        return "Mail sent successfully";
    }
}

public client class MockLLM {
    isolated remote function chat(ChatMessage[] messages, ChatCompletionFunctions[] tools, string? stop)
        returns ChatAssistantMessage|LlmError {
        ChatMessage lastMessage = messages.pop();
        string prompt = lastMessage is ChatUserMessage ? lastMessage.content : "";
        if prompt.includes("Who is Leo DiCaprio's girlfriend? What is her current age raised to the 0.43 power?") {
            int queryLevel = regexp:findAll(re `observation`, prompt.toLowerAscii()).length();
            io:println(queryLevel, prompt);
            string content = check getChatAssistantMessageContent(queryLevel);
            return {role: ASSISTANT, content};
        }
        return error LlmError("Unexpected prompt to MockLLM");
    }
}

isolated function getChatAssistantMessageContent(int queryLevel) returns string|LlmError {
    match queryLevel {
        3 => {
            return "I should use a search engine to find out who Leo DiCaprio's girlfriend is, and then use a calculator to calculate her current age raised to the 0.43 power." +
                "Action:" +
                "```" +
                "{" +
                    "\"action\": \"Search\"," +
                    "\"action_input\": {" +
                        "\"params\": {" +
                            "\"query\": \"Leo DiCaprio girlfriend\"" +
                        "}" +
                    "}" +
                "}" +
                "```";
        }
        4 => {
            return " I need to find out Camila Morrone's age" +
                "Action:" +
                "```" +
                "{" +
                    "\"action\": \"Search\"," +
                    "\"action_input\": {" +
                        "\"params\": {" +
                            "\"query\": \"Camila Morrone age\"" +
                        "}" +
                    "}" +
                "}" +
                "```";

        }
        5 => {
            {
                return " I now need to calculate the age raised to the 0.43 power" +
                "Action:" +
                "```" +
                "{" +
                    "\"action\": \"Calculator\"," +
                    "\"action_input\": {" +
                        "\"params\": {" +
                            "\"expression\": \"25 ^ 0.43\"" +
                        "}" +
                    "}" +
                "}" +
                "```";
            }
        }
    }
    return error LlmError("Unexpected prompt to MockLLM");
}

isolated function testTool(string a, string b = "default-one", string c = "default-two") returns string {
    return string `${a} ${b} ${c}`;
}

isolated function testToolPanic(string data) returns string {
    error e = error(data);
    panic (e);
}
