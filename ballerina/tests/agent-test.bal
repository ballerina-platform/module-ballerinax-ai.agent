import ballerina/test;
import ballerina/io;

Tool searchTool = {
    name: "Search",
    description: " A search engine. Useful for when you need to answer questions about current events",
    inputs: {"query": "string"},
    caller: searchToolMock
};

Tool calculatorTool = {
    name: "Calculator",
    description: "Useful for when you need to answer questions about math.",
    inputs: {"expression": "string mathematical expression"},
    caller: calculatorToolMock
};

GPT3Model model = test:mock(GPT3Model, new MockLLM());

@test:Config {}
function testAgentInitialization() {
    Agent|error agent = new (model, searchTool, calculatorTool);
    test:assertTrue(agent is Agent, "Agent creation is unsuccessful");

    ToolInfo toolInfo = {
        toolList: string `${searchTool.name}, ${calculatorTool.name}`,
        "toolIntro": string `Search: ${{"description": searchTool.description, "inputSchema": searchTool.inputs}.toString()}
Calculator: ${{"description": calculatorTool.description, "inputSchema": calculatorTool.inputs}.toString()}`
    };

    if agent is Agent {
        ToolStore store = agent.getToolStore();
        io:println(store.extractToolInfo());
        test:assertEquals(store.extractToolInfo(), toolInfo);
    }
}

@test:Config {}
function testInitializedPrompt() returns error? {
    Agent agent = check new (model, searchTool, calculatorTool);

    string query = "Who is Leo DiCaprio's girlfriend? What is her current age raised to the 0.43 power?";
    AgentExectutor agentExecutor = agent.createAgentExecutor(query);

    ToolInfo toolInfo = agent.getToolStore().extractToolInfo();
    PromptConstruct prompt = {
        instruction: "Answer the following questions as best you can without making any assumptions. You have access to the following tools:\n\n" +
        toolInfo.toolIntro + "\n\n" +
        "Use a JSON blob with the following format to define the action and input.\n\n" +
        "```\n" +
        "{\n" +
        "  \"tool\": the tool to take, should be one of [" + toolInfo.toolList + "]\",\n" +
        "  \"tool_input\": JSON input record to the tool\n" +
        "}\n" +
        "```\n\n" +
        "ALWAYS use the following format:\n\n" +
        "Question: the input question you must answer\n" +
        "Thought: you should always think about what to do\n" +
        "Action:\n" +
        "```\n$JSON_BLOB only for a SINGLE tool (Do NOT return a list of multiple tools)\n```\n" +
        "Observation: the result of the action\n" +
        "... (this Thought/Action/Observation can repeat N times)\n" +
        "Thought: I now know the final answer\n" +
        "Final Answer: the final answer to the original input question\n\n" +
        "Begin! Reminder to use the EXACT types as specified in JSON \"inputSchema\" to generate input records.",
        query: query,
        history: []
    };
    test:assertEquals(agentExecutor.getPromptConstruct(), prompt);
}

@test:Config {}
function testAgentExecutorRun() returns error? {
    Agent agent = check new (model, searchTool, calculatorTool);
    string query = "Who is Leo DiCaprio's girlfriend? What is her current age raised to the 0.43 power?";
    AgentExectutor agentExecutor = agent.createAgentExecutor(query);

    ExectutorOutput|error results = agentExecutor.next();
    test:assertTrue(results is ExectutorOutput, "AgentExecutor.next returns an error during first iteration");
    if results is ExectutorOutput {
        test:assertEquals(results.observation, "Camila Morrone");
    }

    results = agentExecutor.next();
    test:assertTrue(results is ExectutorOutput, "AgentExecutor.next returns an error during second iteration");
    if results is ExectutorOutput {
        test:assertEquals(results.observation, "25 years");
    }

    results = agentExecutor.next();
    test:assertTrue(results is ExectutorOutput, "AgentExecutor.next returns an error during third iteration");
    if results is ExectutorOutput {
        test:assertEquals(results.observation, "Answer: 3.991298452658078");
    }

}

