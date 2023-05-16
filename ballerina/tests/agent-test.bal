import ballerina/test;

Tool searchTool = {
    name: "Search",
    description: " A search engine. Useful for when you need to answer questions about current events",
    inputSchema: {"query": "string"},
    caller: searchToolMock
};

Tool calculatorTool = {
    name: "Calculator",
    description: "Useful for when you need to answer questions about math.",
    inputSchema: {"expression": "string mathematical expression"},
    caller: calculatorToolMock
};

Gpt3Model model = test:mock(Gpt3Model, new MockLLM());

@test:Config {}
function testAgentInitialization() {
    Agent|error agent = new (model, searchTool, calculatorTool);
    if agent is error {
        test:assertFail("Agent creation is unsuccessful");
    }

    ToolInfo toolInfo = {
        toolList: string `${searchTool.name}, ${calculatorTool.name}`,
        "toolIntro": string `Search: ${{"description": searchTool.description, "inputSchema": searchTool.inputSchema}.toString()}
Calculator: ${{"description": calculatorTool.description, "inputSchema": calculatorTool.inputSchema}.toString()}`
    };

    ToolStore store = agent.getToolStore();
    test:assertEquals(store.extractToolInfo(), toolInfo);
}

@test:Config {}
function testInitializedPrompt() returns error? {
    Agent agent = check new (model, searchTool, calculatorTool);

    string query = "Who is Leo DiCaprio's girlfriend? What is her current age raised to the 0.43 power?";
    AgentExecutor agentExecutor = agent.createAgentExecutor(query);

    ToolInfo toolInfo = agent.getToolStore().extractToolInfo();

    string instruction = "Answer the following questions as best you can without making any assumptions. You have access to the following tools:\n\n" +
        toolInfo.toolIntro + "\n\n" +
        "ALWAYS use the following format:\n\n" +
        "Question: the input question you must answer\n" +
        "Thought: you should always think about what to do\n" +
        "Action: always should be a single tool using the following format within backticks\n" +
        "```\n" +
        "{\n" +
        "  \"tool\": the tool to take, should be one of [" + toolInfo.toolList + "]\",\n" +
        "  \"tool_input\": JSON input record to the tool following \"inputSchema\"\n" +
        "}\n" +
        "```\n" +
        "Observation: the result of the action\n" +
        "... (this Thought/Action/Observation can repeat N times)\n" +
        "Thought: I now know the final answer\n" +
        "Final Answer: the final answer to the original input question\n\n" +
        "Begin!";
    test:assertEquals(agentExecutor.getPromptConstruct().instruction, instruction);
}

@test:Config {}
function testAgentExecutorRun() returns error? {
    Agent agent = check new (model, searchTool, calculatorTool);
    string query = "Who is Leo DiCaprio's girlfriend? What is her current age raised to the 0.43 power?";
    AgentExecutor agentExecutor = agent.createAgentExecutor(query);

    record {|ExecutionStep value;|}? result = agentExecutor.next();
    if result is () {
        test:assertFail("AgentExecutor.next returns an null during first iteration");
    }
    ExecutionStep output = result.value;
    test:assertEquals(output?.observation, "Camila Morrone");

    result = agentExecutor.next();
    if result is () {
        test:assertFail("AgentExecutor.next returns an null during second iteration");
    }
    output = result.value;
    test:assertEquals(output?.observation, "25 years");

    result = agentExecutor.next();
    if result is () {
        test:assertFail("AgentExecutor.next returns an null during third iteration");
    }
    output = result.value;
    test:assertEquals(output?.observation, "Answer: 3.991298452658078");
}

@test:Config {}
function testConstructHistoryPrompt() {
    ExecutionStep[] history = [
        {
            thought: string `Thought: I need to use the "Create wifi" tool to create a new guest wifi account with the given username and password. 
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
            thought: string `Thought: Next, I need to use the "List wifi" tool to get the available list of wifi accounts for the given email.
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
            thought: string `Thought: Finally, I need to use the "Send mail" tool to send the list of available wifi accounts to the given email address.
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

