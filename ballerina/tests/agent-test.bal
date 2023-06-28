import ballerina/test;

Tool searchTool = {
    name: "Search",
    description: " A search engine. Useful for when you need to answer questions about current events",
    parameters: {
        properties: {
            query: {'type: "string", description: "The search query"}
        }
    },
    caller: searchToolMock
};

Tool calculatorTool = {
    name: "Calculator",
    description: "Useful for when you need to answer questions about math.",
    parameters: {
        properties: {
            expression: {'type: "string", description: "The mathematical expression to evaluate"}
        }
    },
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
        "toolIntro": string `Search: ${{"description": searchTool.description, "inputSchema": searchTool.parameters}.toString()}
Calculator: ${{"description": calculatorTool.description, "inputSchema": calculatorTool.parameters}.toString()}`
    };

    ToolStore store = agent.getToolStore();
    test:assertEquals(store.extractToolInfo(), toolInfo);
}

@test:Config {}
function testInitializedPrompt() returns error? {
    Agent agent = check new (model, searchTool, calculatorTool);

    string query = "Who is Leo DiCaprio's girlfriend? What is her current age raised to the 0.43 power?";
    AgentExecutor agentExecutor = agent.getExecutor(query);

    ToolInfo toolInfo = agent.getToolStore().extractToolInfo();

    string instruction = "Answer the following questions without making assumptions. You have access to the following tools. If needed, you can use them multiple times for repeated tasks:\n\n" +
        toolInfo.toolIntro + "\n\n" +
        "ALWAYS use the following format for each question:\n\n" +
        "Question: [Insert the question you need to answer]\n" +
        "Thought: [Consider your approach and plan accordingly]\n" +
        "Action: [Select a single tool from the provided list and use the following format within backticks. This field is mandatory after 'Thought'.]\n" +
        "```\n" +
        "{\n" +
        "  \"tool\": \"[Insert the tool you are using from the given options: [" + toolInfo.toolList + "]\",\n" +
        "  \"tool_input\": \"[Insert the JSON input record to the tool following the 'inputSchema' with the specified types. Required properties are mandatory.]\"\n" +
        "}\n" +
        "```\n" +
        "Observation: [Describe the result of the action]\n" +
        "... (Repeat the Thought/Action/Observation pattern as needed)\n" +
        "Thought: [Summarize your understanding of the final answer]\n" +
        "Final Answer: [Provide the final answer to the original input question. Begin with 'Final Answer:']\n\n" +
        "Let's get started!";

    test:assertEquals(agentExecutor.getPromptConstruct().instruction, instruction);
}

@test:Config {}
function testAgentExecutorRun() returns error? {
    Agent agent = check new (model, searchTool, calculatorTool);
    string query = "Who is Leo DiCaprio's girlfriend? What is her current age raised to the 0.43 power?";
    AgentExecutor agentExecutor = agent.getExecutor(query);

    record {|ExecutionStep|error value;|}? result = agentExecutor.next();
    if result is () {
        test:assertFail("AgentExecutor.next returns an null during first iteration");
    }
    ExecutionStep|error output = result.value;
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

