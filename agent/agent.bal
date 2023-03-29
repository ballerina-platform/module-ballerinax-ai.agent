import ballerina/io;
import ballerina/regex;
import ballerinax/openai.text;

public type Parameters record {};

public type Action record {|
    string name;
    string description;
    Parameters params;
    function func;
|};

public type ReasonedAction record {|
    string action;
    json actionInput;
    string thought;
    boolean finalThought;
|}; 

public class Agent {

    private string query;
    private map<Action> actions;
    private string prompt;
    private LLM llm;

    public function init() returns error? {
        self.query = "";
        self.actions = {};
        self.llm = check new();
        self.prompt = "";
    }

    public function registerActions(Action... actions){
        foreach Action action in actions {
            self.actions[action.name]=action;
        }
    }

    private function buildActionDescription(Action action) returns string{
        return string`${action.name}: ${action.description}. Parameters to this tool should be in the format of ${action.params.toString()}`;
    }

    private function initializaPrompt(){
        string[] toolDescriptionList = [];
        string[] toolNameList = [];
        foreach Action action in self.actions {
            toolNameList.push(action.name);
            toolDescriptionList.push(self.buildActionDescription(action));
        }
        string toolDescriptions = string:'join("\n", ...toolDescriptionList);
        string toolNames = toolNameList.toString();
        
        string promptTemplate = string`
Answer the following questions as best you can. You have access to the following tools: 

${toolDescriptions}

Use the following format:
Question: the input question you must answer
Thought: you should always think about what to do
Action: the action to take, should be one of ${toolNames}
Action Input: the input to the action
Observation: the result of the action
... (this Thought/Action/Action Input/Observation can repeat N times)
Thought: I now know the final answer
Final Answer: the final answer to the original input question

Begin!

${self.query}
Thought:`;

        self.prompt = promptTemplate.trim();
    }


    public function buildNextPrompt(string thoughts, string observation){
        
        self.prompt = string`${self.prompt} ${thoughts}
Observation: ${observation}
Thought:`;

    }

    
    public function decideNextAction() returns string?|error{
        text:Client gpt3 = self.llm.getClient();
        
        // io:println(self.prompt);
        text:CreateCompletionRequest textPrompt = {
            prompt: self.prompt,
            model: "text-davinci-003",
            max_tokens: 256,
            stop: "Observation", 
            temperature: 0.3
        };

        text:CreateCompletionResponse reponse = check gpt3->/completions.post(textPrompt);

        return reponse.choices[0].text;
        
    }

    private function parseAction(string action) returns ReasonedAction|error{
        string[] content = regex:split(action, "\n");
        if content.length() == 2{
            return {thought: content[0].trim(), 
                action: content[1].trim(),
                actionInput: null,
                finalThought: true
            };
        }
        if content.length() == 3{
            json actionInput = check regex:split(regex:replace(content[2], ":", "="), "=").pop().fromJsonString();
        return {thought: content[0].trim(), 
                action: regex:split(content[1], ":").pop().trim(),
                actionInput: actionInput,
                finalThought: false
            };
            
        }
        
        io:println(string`Invalid response from LLM: ${action}`);
        return error(string`Invalid response from LLM: ${action}`);

    }

    private function executeAction(ReasonedAction reasonedAction) returns string|error{
        
        if !(self.actions.hasKey(reasonedAction.action)){
            return error(string`Found undefined action: ${reasonedAction.action}`);
        }
        Action action =  self.actions.get(reasonedAction.action);

        map<json> & readonly actionInput = check reasonedAction.actionInput.fromJsonWithType();

        any|error observation;
        if actionInput.length() > 0 {
            observation = function:call(action.func, actionInput);
        } else {
            observation = function:call(action.func);
        }

        if (observation is error){
            return observation.message();
        }
        return observation.toString();

    }

    public function run(string query, int maxIter = 3) returns error?{
        self.query = query;
        self.initializaPrompt();

        int iter = 0;
        ReasonedAction action;
        while maxIter > iter {
            
            string? thoughts = check self.decideNextAction();
            if !(thoughts is string){
                io:println(string`Model returns invalid response: ${thoughts.toString()}`);
                break;
            }
            string thoughtStr = thoughts.toString().trim();
            io:println("Thought: " + thoughtStr);

            action = check self.parseAction(thoughtStr);

            if action.finalThought{
                io:println(regex:split(thoughtStr, "\n")[1]);
                break;
            }
            string observation = check self.executeAction(action);
            self.buildNextPrompt(thoughtStr, observation);

            io:println("Observation:" + observation);
            io:println("\n ---------- \n\n");
            iter = iter - 1;
        }

    }


}

type SearchParams record {|
    string query;       
|};


type CalculatorParams record {|
    string expression;       
|};

function searchFunc (*SearchParams params) returns string{
    string query = params.query.trim().toLowerAscii();
    if query.matches(re `.*girlfriend.*`){
        return "Camila Morrone";

    } else if query.matches(re `.*age.*`) {
        return "25 years";
    }
    else {
        return "Can't find. Stop!";
    }
}

function calculatorFunc (*CalculatorParams params) returns string{
    string expression = params.expression.trim();
    if (expression == "25^0.43"){
        return "Answer: 3.991298452658078";
    } else {
        return "Can't compute. Try computing by yourself";
    }
    
}



// public function main() returns error? {
//     Agent agent = check new();   

//     Action action1 = {
//         name : "Search",
//         description : " A search engine. Useful for when you need to answer questions about current events",
//         params: {"query": "string"},
//         func : searchFunc
//     };

//     Action action2 = {
//         name : "Calculator",
//         description : "Useful for when you need to answer questions about math",
//         params: {"expression": "string"},
//         func : calculatorFunc
//     };

//     agent.registerActions(action1, action2);

//     // any|error res = function:call(action2.func, "abc");

//     // io:println(res);


//     // io:println(agent.buildPrompt());
//     error? run = agent.run("Who is Leo DiCaprio's girlfriend? What is her current age raised to the 0.43 power?");
//     if run is error {
        
//     }

// }

// function execute(function (string) returns string func, string abc) returns string {
//         return func(abc);
// }


