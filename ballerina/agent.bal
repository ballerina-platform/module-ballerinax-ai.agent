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
import ballerina/log;
import ballerina/regex;

type LLMInputParseError distinct error;

# Parsed response from the LLM
#
# + tool - Name of the tool to be performed
# + tool_input - Input to the tool
# + isCompleted - Whether the task is completed
type NextTool record {|
    string tool;
    map<json> tool_input = {};
    boolean isCompleted = false;
|};

public type ExecutorOutput record {|
    string thought;
    any|error observation?;
|};

public class AgentIterator {
    *object:Iterable;

    private AgentExecutor executor;

    isolated function init(Agent agent, PromptConstruct prompt) {
        self.executor = new (agent, prompt);
    }

    public function iterator() returns object {
        public function next() returns record {|ExecutorOutput value;|}?;
    } {
        return self.executor;
    }

}

public class AgentExecutor {
    private LlmModel model;
    private ToolStore toolStore;
    private PromptConstruct prompt;
    private boolean isCompleted;

    public isolated function init(Agent agent, PromptConstruct prompt) {
        self.prompt = prompt;
        self.model = agent.getLLMModel();
        self.toolStore = agent.getToolStore();
        self.isCompleted = false;
    }

    # Build the prompts during each decision iterations 
    #
    # + thought - Thought by the model during the previous iterations
    # + observation - Observation returned by the performed tool
    private isolated function updatePromptHistory(string thought, any|error observation) {
        string observationString;
        if observation is error {
            observationString = observation.toString();
        } else {
            observationString = observation.toString();
        }
        self.prompt.history.push(string `${thought}${"\n"}Observation: ${observationString.trim()}`);
    }

    # Use LLMs to decide the next tool 
    # + return - Decision by the LLM or an error if call to the LLM fails
    private isolated function decideNextTool() returns string|error =>
        self.model.generate(self.prompt);

    # Parse the LLM response in string form to an LLMResponse record
    #
    # + llmResponse - String form LLM response including new tool 
    # + return - LLMResponse record or an error if the parsing failed
    private isolated function parseLlmOutput(string llmResponse) returns NextTool|LLMInputParseError {
        if llmResponse.includes(FINAL_ANSWER_KEY) {
            return {
                tool: "complete",
                isCompleted: true
            };
        }

        string[] content = regex:split(llmResponse + "<endtoken>", "```");
        if content.length() < 3 {
            log:printError("Unexpected LLM response is given: \n`" + llmResponse + "`");
            return error LLMInputParseError("Error: Unable to extract the tool due to the invalid generation. Can you use the specified format?");
        }

        NextTool|error nextTool = content[1].fromJsonStringWithType();
        if nextTool is error {
            log:printError(string `Error while extracting actions from LLM response. ${nextTool.toString()}`);
            return error LLMInputParseError("Error: Provide with an invalid `action` JSON blob. Can you follow the specified format?");
        }
        return nextTool;
    }

    public isolated function next() returns record {|ExecutorOutput value;|}? {
        if self.isCompleted {
            return ();
        }

        string|error decision = self.decideNextTool();
        if decision is error {
            log:printError("Error while communicating to LLM. Task is terminated due to: " + decision.toString());
            self.isCompleted = true;
            return ();
        }

        string thought = string `${THOUGHT_KEY} ${decision.trim()}`;
        NextTool|LLMInputParseError nextTool = self.parseLlmOutput(thought);

        if nextTool is LLMInputParseError {
            return {value: {thought, observation: nextTool}};
        }

        if nextTool.isCompleted {
            self.isCompleted = true;
            return {value: {thought}};
        }

        any|error observation = self.toolStore.runTool(nextTool.tool, nextTool.tool_input);
        if observation is ToolNotFoundError {
            observation = string `Tool "${nextTool.tool}" doesn't exists. Can you use one from the list of tools specified?`;
        }
        else if observation is ToolInvalidInputError {
            observation = string `Tool "${nextTool.tool}" failed due to invalid input. Can you use the specified format in "inputSchema"?`;
        }

        self.updatePromptHistory(thought, observation);
        return {value: {thought, observation}};
    }

    isolated function getPromptConstruct() returns PromptConstruct {
        return self.prompt;
    }
}

# Agent implementation to perform tools with LLMs to add computational power and knowledge to the LLMs
public isolated class Agent {

    private final LlmModel model;
    private final ToolStore toolStore;

    # Initialize an Agent
    #
    # + model - LLM model instance
    # + toolLoader - ToolLoader instance to load tools from (optional)
    public isolated function init(LlmModel model, (BaseToolKit|Tool)... tools) returns error? {
        if tools.length() == 0 {
            return error("No tools provided to the agent");
        }
        self.model = model;
        self.toolStore = new;
        foreach BaseToolKit|Tool tool in tools {
            if tool is BaseToolKit {
                check self.toolStore.registerTools(...check tool.getTools());
            } else {
                check self.toolStore.registerTools(tool);
            }
        }
    }

    # Initialize the prompt during a single run for a given user query
    #
    # + query - User's query  
    # + context - Context information to be used by the LLM
    # + return - PromptConstruct record or an error if the initialization failed
    private isolated function initializaPrompt(string query, string|map<json> context = {}) returns PromptConstruct {
        ToolInfo output = self.toolStore.extractToolInfo();
        string toolDescriptions = output.toolIntro;
        string toolNames = output.toolList;
        string contextInfo = "";
        if context != {} {
            contextInfo = string `
You can also use the following information: 
${context.toString()}
`;
        }
        string instruction = constructPrompt(toolNames, toolDescriptions, contextInfo);
        return {
            instruction,
            query: query.trim(),
            history: []
        };
    }

    public isolated function createAgentExecutor(string query, string|map<json> context = {}) returns AgentExecutor {
        return new (self, self.initializaPrompt(query, context));
    }

    public isolated function iterator(string query, string|map<json> context = {}) returns AgentIterator {
        return new (self, self.initializaPrompt(query, context));
    }

    # Execute the agent for a given user's query
    #
    # + query - Natural langauge commands to the agent  
    # + maxIter - No. of max iterations that agent will run to execute the task  
    # + context - Context values to be used by the agent to execute the task
    # + verbose - If true, then print the reasoning steps
    # + return - Returns error, in case of a failure
    public isolated function run(string query, int maxIter = 5, string|map<json> context = {}, boolean verbose = true) returns ExecutorOutput[] {
        ExecutorOutput[] exectutorResults = [];
        AgentIterator iterator = self.iterator(query, context);
        int iter = 0;
        foreach ExecutorOutput output in iterator {
            iter += 1;
            exectutorResults.push(output);

            if verbose {
                io:println("\n\nReasoning iteration: " + (iter).toString());
                io:println(output.thought);
                any|error observation = output?.observation;
                if observation is error {
                    io:println("Observation (Error): " + observation.toString());
                } else {
                    io:println("Observation: " + observation.toString());
                }
            }
            if iter == maxIter {
                break;
            }
        }
        return exectutorResults;
    }

    isolated function getLLMModel() returns LlmModel {
        return self.model;
    }

    isolated function getToolStore() returns ToolStore {
        return self.toolStore;
    }

}

isolated function constructPrompt(string toolNames, string toolDescriptions, string contextInfo) returns string {
    return string `Answer the following questions as best you can without making any assumptions. You have access to the following tools:

${toolDescriptions.trim()}
${contextInfo}
Use a JSON blob with the following format to define the action and input.

${BACKTICK}${BACKTICK}${BACKTICK}
{
  "tool": the tool to take, should be one of [${toolNames}]",
  "tool_input": JSON input record to the tool
}
${BACKTICK}${BACKTICK}${BACKTICK}

ALWAYS use the following format:

Question: the input question you must answer
Thought: you should always think about what to do
Action:
${BACKTICK}${BACKTICK}${BACKTICK}
$JSON_BLOB only for a SINGLE tool (Do NOT return a list of multiple tools)
${BACKTICK}${BACKTICK}${BACKTICK}
Observation: the result of the action
... (this Thought/Action/Observation can repeat N times)
Thought: I now know the final answer
Final Answer: the final answer to the original input question

Begin! Reminder to use the EXACT types as specified in JSON "inputSchema" to generate input records. Do NOT add any additional fields to the input record.`;
}
