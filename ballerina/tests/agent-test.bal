import ballerina/test;

ToolConfig searchTool = {
    name: "Search",
    description: " A search engine. Useful for when you need to answer questions about current events",
    parameters: {
        properties: {
            params: {
                properties: {
                    query: {'type: "string", description: "The search query"}
                }
            }
        }
    },
    caller: searchToolMock
};

ToolConfig calculatorTool = {
    name: "Calculator",
    description: "Useful for when you need to answer questions about math.",
    parameters: {
        properties: {
            params: {
                properties: {
                    expression: {'type: "string", description: "The mathematical expression to evaluate"}
                }
            }
        }
    },
    caller: calculatorToolMock
};

Gpt3Model model = test:mock(Gpt3Model, new MockLLM());

@test:Config {}
function testReActAgentInitialization() {
    ReActAgent|error agent = new (model, searchTool, calculatorTool);
    if agent is error {
        test:assertFail("Agent creation is unsuccessful");
    }

    ToolInfo toolInfo = {
        toolList: string `${searchTool.name}, ${calculatorTool.name}`,
        "toolIntro": string `Search: ${{"description": searchTool.description, "inputSchema": searchTool.parameters}.toString()}
Calculator: ${{"description": calculatorTool.description, "inputSchema": calculatorTool.parameters}.toString()}`
    };

    test:assertEquals(extractToolInfo(agent.toolStore), toolInfo);
}

@test:Config {}
function testInitializedPrompt() returns error? {
    ReActAgent agent = check new (model, searchTool, calculatorTool);

    string ExpectedPrompt = string `System: Respond to the human as helpfully and accurately as possible. You have access to the following tools:

Search: {"description":" A search engine. Useful for when you need to answer questions about current events","inputSchema":{"type":"object","properties":{"params":{"type":"object","properties":{"query":{"type":"string","description":"The search query"}}}}}}
Calculator: {"description":"Useful for when you need to answer questions about math.","inputSchema":{"type":"object","properties":{"params":{"type":"object","properties":{"expression":{"type":"string","description":"The mathematical expression to evaluate"}}}}}}

Use a json blob to specify a tool by providing an action key (tool name) and an action_input key (tool input).

Valid "action" values: "Final Answer" or Search, Calculator

Provide only ONE action per $JSON_BLOB, as shown:

${"```"}
{
  "action": $TOOL_NAME,
  "action_input": $INPUT_JSON
}
${"```"}

Follow this format:

Question: input question to answer
Thought: consider previous and subsequent steps
Action:
${"```"}
$JSON_BLOB
${"```"}
Observation: action result
... (repeat Thought/Action/Observation N times)
Thought: I know what to respond
Action:
${"```"}
{
  "action": "Final Answer",
  "action_input": "Final response to human"
}
${"```"}

Begin! Reminder to ALWAYS respond with a valid json blob of a single action. Use tools if necessary. Respond directly if appropriate. Format is Action:${"```"}$JSON_BLOB${"```"}then Observation:.`;

    test:assertEquals(agent.instructionPrompt, ExpectedPrompt);
}

@test:Config {}
function testAgentExecutorRun() returns error? {
    ReActAgent agent = check new (model, searchTool, calculatorTool);
    string query = "Who is Leo DiCaprio's girlfriend? What is her current age raised to the 0.43 power?";
    Executor agentExecutor = new (agent, query = query);
    record {|ExecutionResult|LlmChatResponse|ExecutionError|error value;|}? result = agentExecutor.next();
    if result is () {
        test:assertFail("AgentExecutor.next returns an null during first iteration");
    }
    ExecutionResult|LlmChatResponse|ExecutionError|error output = result.value;
    if output is error {
        test:assertFail("AgentExecutor.next returns an error during first iteration");
    }
    test:assertEquals(output?.observation, "Camila Morrone");

    result = agentExecutor.next();
    if result is () {
        test:assertFail("AgentExecutor.next returns an null during second iteration");
    }
    output = result.value;
    if output is error {
        test:assertFail("AgentExecutor.next returns an error during second iteration");
    }
    test:assertEquals(output?.observation, "25 years");

    result = agentExecutor.next();
    if result is () {
        test:assertFail("AgentExecutor.next returns an null during third iteration");
    }
    output = result.value;
    if output is error {
        test:assertFail("AgentExecutor.next returns an error during third iteration");
    }
    test:assertEquals(output?.observation, "Answer: 3.991298452658078");
}

@test:Config {}
function testConstructHistoryPrompt() {
    ExecutionStep[] history = [
        {
            llmResponse: string `Thought: I need to use the "Create wifi" tool to create a new guest wifi account with the given username and password. 
Action:
{
  "tool": "Create wifi",
  "tool_input": {
    "path": "/guest-wifi-accounts",
    "requestBody": {
      "email": "johnny@wso2.com",
      "username": "newGuest",
      "password": "jh123"
    }
  }
}`,
            observation: "Successfully added the wifi account"
        },
        {

            llmResponse: string `Thought: Next, I need to use the "List wifi" tool to get the available list of wifi accounts for the given email.
Action:
{
  "tool": "List wifi",
  "tool_input": {
    "path": "/guest-wifi-accounts/johnny@wso2.com"
  }
}`,
            observation: ["freeWifi.guestOf.johnny", "newGuest.guestOf.johnny"]
        },
        {
            llmResponse: string `Thought: Finally, I need to use the "Send mail" tool to send the list of available wifi accounts to the given email address.
Action:
{
  "tool": "Send mail",
  "tool_input": {
    "recipient": "alica@wso2.com",
    "subject": "Available Wifi Accounts",
    "messageBody": "Here are the available wifi accounts: ['newGuest.guestOf.johnny','newGuest.guestOf.johnny']"
  }
}`,
            observation: error("Error while sending the email(ballerinax/googleapis.gmail)GmailError")
        }
    ];

    string thoughtHistory = constructHistoryPrompt(history);
    test:assertEquals(thoughtHistory, string `Thought: I need to use the "Create wifi" tool to create a new guest wifi account with the given username and password. 
Action:
{
  "tool": "Create wifi",
  "tool_input": {
    "path": "/guest-wifi-accounts",
    "requestBody": {
      "email": "johnny@wso2.com",
      "username": "newGuest",
      "password": "jh123"
    }
  }
}
Observation: Successfully added the wifi account
Thought: Next, I need to use the "List wifi" tool to get the available list of wifi accounts for the given email.
Action:
{
  "tool": "List wifi",
  "tool_input": {
    "path": "/guest-wifi-accounts/johnny@wso2.com"
  }
}
Observation: ["freeWifi.guestOf.johnny","newGuest.guestOf.johnny"]
Thought: Finally, I need to use the "Send mail" tool to send the list of available wifi accounts to the given email address.
Action:
{
  "tool": "Send mail",
  "tool_input": {
    "recipient": "alica@wso2.com",
    "subject": "Available Wifi Accounts",
    "messageBody": "Here are the available wifi accounts: ['newGuest.guestOf.johnny','newGuest.guestOf.johnny']"
  }
}
Observation: Error occured while trying to execute the tool: {"message":"Error while sending the email(ballerinax/googleapis.gmail)GmailError"}
`);

}

@test:Config {}
function testParseLlmReponse() returns error? {
    string llmResponse = string `I know what to respond
Action:
${"```"}
{
  "action": "Final Answer",
  "action_input": "The guest wifi account guestJohn with password abc123 has been successfully created. There are currently no other available wifi accounts."
}
${"```"}`;

    LlmToolResponse|LlmChatResponse parsedResult = check parseReActLlmResponse(llmResponse);
    if parsedResult is LlmToolResponse {
        test:assertFail("Parsed result should be a ChatResponse");
    }
    test:assertEquals(parsedResult.content, "The guest wifi account guestJohn with password abc123 has been successfully created. There are currently no other available wifi accounts.");
}

@test:Config {}
function testParseLlmReponse2() returns error? {
    string llmResponse = string `The pets available for adoption are:
1. Lion 1 (ID: 7)
2. Lion 2 (ID: 8)
3. Lion 3 (ID: 9)
4. Собака (ID: 11)
5. O~e~kd/!qA4.yfkZJ|)q6c9%kv,/_qL JNObVwE$v48lk4{2hN#V?SCb/{M9ad4N7S4m&$|=!*PG"e#H#${"`"}wwC1;| (ID: -1414197701106907177)
6. 5;x[EY^~6t'.26qSk(7NSPwDTP7oD@TZNQov0=s[?/Kz\6vx^6*'FFHaKp+Gvq-i":bB=;5qG:QK8!!uV/]xYJ&nk~b"lO3!EoQGEY0p-%*|,=c;!oPw7+Rt?EjQrQ;Lu4R:?${"`"}goAU1KPjC*CqkU.{7UNm^(L13wPUpL*Zwa*KST${"`"}>s, (ID: -3408360315760843390)
7. My Pet (ID: 0)
8. Winter (ID: 1122)
9. New name for my pet 1212 (ID: 108333023)
10. doggie (ID: -34)
11. Dog 224 (ID: 224)
12. New name for my pet 1212 (ID: 1016156941)

Action:
${"```"}
{
  "action": "Final Answer",
  "action_input": "The pets available for adoption are: Lion 1 (ID: 7), Lion 2 (ID: 8), Lion 3 (ID: 9), Собака (ID: 11), O~e~kd/!qA4.yfkZJ|)q6c9%kv,/_qL JNObVwE$v48lk4{2hN#V?SCb/{M9ad4N7S4m&$|=!*PG\"e#H#${"`"}wwC1;| (ID: -1414197701106907177), 5;x[EY^~6t'.26qSk(7NSPwDTP7oD@TZNQov0=s[?/Kz\\6vx^6*'FFHaKp+Gvq-i\":bB=;5qG:QK8!!uV/]xYJ&nk~b\"lO3!EoQGEY0p-%*|,=c;!oPw7+Rt?EjQrQ;Lu4R:?${"`"}goAU1KPjC*CqkU.{7UNm^(L13wPUpL*Zwa*KST${"`"}>s, (ID: -3408360315760843390), My Pet (ID: 0), Winter (ID: 1122), New name for my pet 1212 (ID: 108333023), doggie (ID: -34), Dog 224 (ID: 224), and New name for my pet 1212 (ID: 1016156941)."
}
${"```"}`;

    LlmToolResponse|LlmChatResponse parsedResult = check parseReActLlmResponse(llmResponse);
    if parsedResult is LlmToolResponse {
        test:assertFail("Parsed result should be a ChatResponse");
    }
}
