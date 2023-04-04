import ballerinax/openai.text;

type SearchParams record {|
    string query;
|};

type CalculatorParams record {|
    string expression;
|};

// create two mock actions 
function searchActionMock(*SearchParams params) returns string {
    string query = params.query.trim().toLowerAscii();
    if query.matches(re `.*girlfriend.*`) {
        return "Camila Morrone";

    } else if query.matches(re `.*age.*`) {
        return "25 years";
    }
    else {
        return "Can't find. Stop!";
    }
}

function calculatorActionMock(*CalculatorParams params) returns string {
    string expression = params.expression.trim();
    if (expression == "25^0.43") {
        return "Answer: 3.991298452658078";
    } else {
        return "Can't compute. Some information is missing";
    }
}

configurable string openAIToken = ?;

// agent is defined and used within the main function
public function main() returns error? {
    text:CreateCompletionRequest config = {
        model: "text-davinci-003",
        max_tokens: 256,
        stop: "Observation",
        temperature: 0.3
    };

    GPT3Model model = new (check new ({auth: {token: openAIToken}}), config);
    Agent agent = new (model);

    Action action1 = {
        name: "Search",
        description: " A search engine. Useful for when you need to answer questions about current events",
        inputs: {"query": "string search query"},
        caller: searchActionMock
    };

    Action action2 = {
        name: "Calculator",
        description: "Useful for when you need to answer questions about math.",
        inputs: {"expression": "string mathematical expression"},
        caller: calculatorActionMock
    };

    agent.registerActions(action1, action2);

    check agent.run("Who is Leo DiCaprio's girlfriend? What is her current age raised to the 0.43 power?");
}
