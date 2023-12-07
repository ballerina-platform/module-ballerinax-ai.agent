// Copyright (c) 2023 WSO2 LLC (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/io;
import ballerina/lang.value;
import ballerina/lang.regexp;
import ballerina/log;

# Parsed response from the LLM.
type NextTool record {|
    # Name of the tool to be performed
    string tool;
    # Input to the tool
    map<json> tool_input = {};
    # Whether the task is completed
    boolean isCompleted = false;
|};

# Prompt to be given to the LLM.
public type ExecutionStep record {|
    # Thought produced by the LLM during the reasoning
    string thought;
    # Observations produced by the tool during the execution
    any|error observation?;
|};

public class AgentIterator {
    *object:Iterable;

    private AgentExecutor executor;

    isolated function init(Agent agent, string query, string|map<json> context = {}) {
        self.executor = new (agent, query, context = context);
    }

    # Iterate over the agent's execution steps.
    # + return - a record with the execution step or an error if the agent failed
    public function iterator() returns object {
        public function next() returns record {|ExecutionStep|error value;|}?;
    } {
        return self.executor;
    }
}

public class AgentExecutor {
    private LlmModel model;
    private ToolStore toolStore;
    private boolean isCompleted;
    PromptConstruct prompt;

    isolated function init(Agent agent, string query, ExecutionStep[] previousSteps = [], string|map<json> context = {}) {
        string instruction = agent.getInstructionPrompt();
        if context != {} {
            instruction = string `${instruction}${"\n"}You can use these information if needed: ${context.toString()}$`;
        }
        log:printDebug("Instruction Prompt: \n" + instruction);
        self.prompt = {
            query: query,
            history: previousSteps,
            instruction
        };
        self.model = agent.getLlmModel();
        self.toolStore = agent.getToolStore();
        self.isCompleted = false;
    }

    # Checks whether agent has more steps to execute.
    #
    # + return - True if agent has more steps to execute, false otherwise
    public isolated function hasNext() returns boolean {
        return !self.isCompleted;
    }

    # Use LLMs to decide the next tool.
    # + return - Decision by the LLM or an error if call to the LLM fails
    private isolated function decideNextTool() returns string|error =>
        self.model.generate(self.prompt);

    # Parse the LLM response in string form to an LLMResponse record.
    #
    # + llmResponse - String form LLM response including new tool 
    # + return - LLMResponse record or an error if the parsing failed
    private isolated function parseLlmOutput(string llmResponse) returns NextTool|LlmActionParseError {
        if llmResponse.toLowerAscii().includes(FINAL_ANSWER_KEY) {
            return {
                tool: "complete",
                isCompleted: true
            };
        }
        string[] content = regexp:split(re `${"```"}`, llmResponse + "<endtoken>");
        if content.length() < 3 {
            log:printWarn("Unexpected LLM response is given", llmResponse = llmResponse);
            return error LlmActionParseError("Unable to extract the tool due to invalid generation", llmResponse = llmResponse, instruction = "Tool execution failed due to invalid generation. Regenerate following the given format.");
        }
        NextTool|error nextTool = content[1].fromJsonStringWithType();
        if nextTool is error {
            log:printWarn("Unexpected JSON schema is given as the action.", nextTool);
            return error LlmActionParseError("Unexpected JSON schema is given as the action.", nextTool, llmResponse = llmResponse, instruction = "Generated JSON blob is incorrect. Regenerate following the given format.");
        }
        return nextTool;
    }

    # Reason the next step of the agent.
    #
    # + return - Thought to be executed by the agent or an error if the reasoning failed
    public isolated function reason() returns string|TaskTerminationError|LlmGenerationError {
        if self.isCompleted {
            return error TaskTerminationError("Task is already completed. No more reasoning is needed.");
        }
        string|error decision = self.decideNextTool();
        if decision is error {
            return error LlmGenerationError("Error while communicating to LLM.", decision);
        }
        return string `${THOUGHT_KEY} ${normalizeLlmResponse(decision)}`;
    }

    # Execute the next step of the agent.
    #
    # + thought - Thought to be executed by the agent
    # + return - Observations from the tool can be any|error|null
    public isolated function act(string thought) returns any|error {
        NextTool|LlmActionParseError nextTool = self.parseLlmOutput(thought);
        if nextTool is LlmActionParseError {
            map<value:Cloneable> detail = nextTool.detail();
            return detail.hasKey(ERROR_INSTRUCTION_KEY) ? detail.get(ERROR_INSTRUCTION_KEY) : "Tool execution failed due to invalid generation. Regenerate following the given format.";
        }
        if nextTool.isCompleted {
            self.isCompleted = true;
            return ();
        }
        any|error observation = self.toolStore.runTool(nextTool.tool, nextTool.tool_input);
        if observation is ToolNotFoundError || observation is ToolInvalidInputError {
            map<value:Cloneable> detail = observation.detail();
            observation = detail.hasKey(ERROR_INSTRUCTION_KEY) ? detail.get(ERROR_INSTRUCTION_KEY) : "Tool execution failed due to invalid generation. Regenerate following the given format.";
        } else if observation is () { // whether tool return any value or error 
            observation = string `Tool '${nextTool.tool}' didn't return any values or errors. Verify whether it was successful.`;
        }
        self.update({thought, observation});
        return observation;
    }

    # Update the agent with the latest exectuion step.
    #
    # + step - Latest step to be added to the history
    public isolated function update(ExecutionStep step) {
        ExecutionStep[] history = self.prompt.history;
        if history.length() > 0 {
            ExecutionStep lastStep = history[history.length() - 1];
            if lastStep.thought == step.thought {
                log:printWarn("Step with the same thought already exists. Updating the only observations for that step.");
                lastStep.observation = step?.observation;
                return;
            }
        }
        history.push(step);
    }

    # Execute the next step of the agent.
    #
    # + return - A record with ExecutionStep or error 
    public isolated function next() returns record {|ExecutionStep|error value;|}? {
        if self.isCompleted {
            return ();
        }
        string|error thought = self.reason();
        if thought is error {
            self.isCompleted = true;
            return {value: thought};
        }
        any|error observation = self.act(thought);
        return {value: {thought, observation}};
    }

    # Allow retrieving the execution history during previous steps.
    #
    # + return - Execution history of the agent (A list of ExecutionStep)
    public isolated function getExecutionHistory() returns ExecutionStep[] {
        return self.prompt.history;
    }
}

# ReAct Agent implementation to execute actions with LLMs.
public isolated class Agent {

    private final LlmModel model;
    private final ToolStore toolStore;
    private final string instructionPrompt;

    # Initialize an Agent.
    #
    # + model - LLM model instance
    # + toolLoader - ToolLoader instance to load tools from (optional)
    public isolated function init(LlmModel model, (BaseToolKit|Tool)... tools) returns error? {
        if tools.length() == 0 {
            return error("No tools provided to the agent");
        }
        self.model = model;
        Tool[] toolList = [];
        foreach BaseToolKit|Tool tool in tools {
            if tool is BaseToolKit {
                Tool[] toolsFromToolKit = tool.getTools(); // needed this due to nullpointer exception in ballerina
                toolList.push(...toolsFromToolKit);
            } else {
                toolList.push(tool);
            }
        }
        self.toolStore = check new (toolList);
        ToolInfo toolInfo = self.toolStore.extractToolInfo();
        self.instructionPrompt = constructPrompt(toolInfo.toolList, toolInfo.toolIntro);
    }

    # Initialize the agent executor for a given query. 
    # Agent executor is useful for streaming-like execution of the agent or to make use of reason-act interface of the agent.
    #
    # + query - User's query
    # + previousSteps - Execution steps perviously taken by the agent for the query given
    # + context - Context information to be used by the LLM
    # + return - AgentExecutor instance
    public isolated function getExecutor(string query, ExecutionStep[] previousSteps = [], string|map<json> context = {}) returns AgentExecutor {
        return new (self, query, previousSteps, context = context);
    }

    # Initialize the agent iterator for a given query.
    # Agent executor is useful for foreach execution of the agent.
    #
    # + query - User's query
    # + context - Context information to be used by the LLM
    # + return - AgentIterator instance
    public isolated function getIterator(string query, string|map<json> context = {}) returns AgentIterator {
        return new (self, query, context);
    }

    # Execute the agent for a given user's query.
    #
    # + query - Natural langauge commands to the agent  
    # + maxIter - No. of max iterations that agent will run to execute the task  
    # + context - Context values to be used by the agent to execute the task
    # + verbose - If true, then print the reasoning steps
    # + return - Returns the execution steps tracing the agent's reasoning and outputs from the tools
    public isolated function run(string query, int maxIter = 5, string|map<json> context = {}, boolean verbose = true) returns ExecutionStep[] {
        ExecutionStep[] exectutorResults = [];
        AgentIterator iterator = self.getIterator(query, context = context);
        int iter = 0;
        foreach ExecutionStep|error step in iterator {
            if step is error {
                log:printError("Error occured while executing the agent: " + step.toString());
                break;
            }
            iter += 1;
            exectutorResults.push(step);

            if verbose {
                io:println("\n\nReasoning iteration: " + (iter).toString());
                io:println(step.thought);
                any|error observation = step?.observation;
                if observation is error {
                    io:println("Observation (Error): " + observation.toString());
                } else if observation !is () {
                    io:println("Observation: " + observation.toString());
                }
            }
            if iter == maxIter {
                break;
            }
        }
        return exectutorResults;
    }
    isolated function getLlmModel() returns LlmModel => self.model;

    isolated function getToolStore() returns ToolStore => self.toolStore;

    isolated function getInstructionPrompt() returns string => self.instructionPrompt;

}

isolated function constructPrompt(string toolList, string toolIntro) returns string {
    return string `Answer the following questions without making assumptions. You have access to the following tools. If needed, you can use them multiple times for repeated tasks:

${toolIntro.trim()}

ALWAYS use the following format for each question:

Question: [The input question you must answer]
Thought: [You should always think about what to do]
Action: [Select a single tool from the provided list and use the following format within backticks. This field is mandatory after 'Thought'.]
${BACKTICK}${BACKTICK}${BACKTICK}
{
  "tool": "[Insert the tool you are using from the given options: [${toolList}]",
  "tool_input": "[Insert the JSON input record to the tool following the 'inputSchema' with the specified types. Required properties are mandatory.]"
}
${BACKTICK}${BACKTICK}${BACKTICK}
Observation: [Describe the result of the action]
... (this Thought/Action/Observation can repeat N times)
Thought: [Summarize your understanding of the final answer]
Final Answer: [Provide the final answer to the original input question]

Let's get started!`;
}

isolated function constructHistoryPrompt(ExecutionStep[] history) returns string {
    string historyPrompt = "";
    foreach ExecutionStep step in history {
        string observationStr;
        any|error observation = step?.observation;
        if observation is () {
            observationStr = "Tool didn't return anything. Probably it is successful. Can I verify using another tool?";
        } else if observation is error {
            record {|string message; string cause?;|} errorInfo = {
                message: observation.message().trim()
            };
            error? cause = observation.cause();
            if cause is error {
                errorInfo.cause = cause.message().trim();
            }
            observationStr = "Error occured while trying to execute the tool: " + errorInfo.toString();
        } else {
            observationStr = observation.toString().trim();
        }
        historyPrompt += string `${step.thought}${"\n"}Observation: ${observationStr}${"\n"}`;
    }
    return historyPrompt;
}

isolated function normalizeLlmResponse(string llmResponse) returns string {
    string thought = llmResponse.trim();
    if !thought.includes("```") {
        if thought.startsWith("{") && thought.endsWith("}") {
            thought = string `${"```"}${thought}${"```"}`;
        } else {
            int? jsonStart = thought.indexOf("{");
            int? jsonEnd = thought.lastIndexOf("}");
            if jsonStart is int && jsonEnd is int {
                thought = string `${"```"}${thought.substring(jsonStart, jsonEnd + 1)}${"```"}`;
            }
        }
    }
    thought = regexp:replace(re `${"```"}json`, thought, "```"); // replace ```json  
    thought = regexp:replaceAll(re `"\{\}"`, thought, "{}"); // replace "{}"
    thought = regexp:replaceAll(re `\\"`, thought, "\""); // replace \"
    return thought;
}
