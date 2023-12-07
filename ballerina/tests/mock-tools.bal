import ballerina/lang.regexp;

type SearchParams record {|
    string query;
|};

type CalculatorParams record {|
    string expression;
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

public client class MockLLM {

    isolated function generate(PromptConstruct prompt) returns string|error {
        if prompt.query == "Who is Leo DiCaprio's girlfriend? What is her current age raised to the 0.43 power?" {
            if prompt.history.length() == 0 {
                return "I should use a search engine to find out who Leo DiCaprio's girlfriend is, and then use a calculator to calculate her current age raised to the 0.43 power." +
                "Action:" +
                "```" +
                "{" +
                    "\"tool\": \"Search\"," +
                    "\"tool_input\": {" +
                        "\"query\": \"Leo DiCaprio girlfriend\"" +
                    "}" +
                "}" +
                "```";
            } else if prompt.history.length() == 1 {
                return " I need to find out Camila Morrone's age" +
                "Action:" +
                "```" +
                "{" +
                    "\"tool\": \"Search\"," +
                    "\"tool_input\": {" +
                        "\"query\": \"Camila Morrone age\"" +
                    "}" +
                "}" +
                "```";

            } else if prompt.history.length() == 2 {
                return " I now need to calculate the age raised to the 0.43 power" +
                "Action:" +
                "```" +
                "{" +
                    "\"tool\": \"Calculator\"," +
                    "\"tool_input\": {" +
                        "\"expression\": \"25 ^ 0.43\"" +
                    "}" +
                "}" +
                "```";
            }

        }

        return error("Unexpected prompt to MockLLM");

    }
}
