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
import ballerina/regex;

# Parsed response from the LLM
#
# + tool - Name of the tool to be performed
# + tool_input - Input to the tool
# + isCompleted - Whether the task is completed
type NextAction record {|
    string tool;
    map<json> tool_input = {};
    boolean isCompleted = false;
|};

type ExectutorOutput record {|
    string thought;
    string observation?;
|};

public class AgentExectutor {
    private Agent agent;
    private PromptConstruct prompt;

    function init(Agent agent, PromptConstruct prompt) {
        self.prompt = prompt;
        self.agent = agent;
    }

    # Build the prompts during each decision iterations 
    #
    # + thoughts - Thoughts by the model during the previous iterations
    # + observation - Observations returned by the performed tool
    # + return - Error, in case of a failure
    private function updatePromptHistory(string thoughts, string observation) returns error? {
        PromptConstruct? prompt = self.prompt;
        if prompt is () {
            return error("Prompt is not initialized");
        }

        prompt.history.push(
            string `${thoughts}
Observation: ${observation.trim()}`
        );

    }

    # Use LLMs to decide the next tool 
    # + return - Decision by the LLM or an error if call to the LLM fails
    private function decideNextTool() returns string|error {
        return self.agent.getLLMModel()._generate(<PromptConstruct>self.prompt);
    }

    # Parse the LLM response in string form to an LLMResponse record
    #
    # + llmResponse - String form LLM response including new tool 
    # + return - LLMResponse record or an error if the parsing failed
    private function parseLLMResponse(string llmResponse) returns NextAction|error {
        if (llmResponse.includes("Final Answer")) {
            return {
                tool: "complete",
                isCompleted: true
            };
        }
        string[] content = regex:split(llmResponse + "<endtoken>", "```");
        if content.length() < 3 {
            return error("No proper tool definition found in the LLM response: \n`" + llmResponse + "`");
        }
        NextAction|error nextAction = content[1].fromJsonStringWithType();
        if nextAction is error {
            return error(string `Error while extracting actions from LLM response. ${nextAction.toString()}`);
        }
        return nextAction;
    }

    public function next() returns ExectutorOutput|error {

        string thoughts = check self.decideNextTool();

        string formattedThoughts = thoughts.trim();
        if !formattedThoughts.startsWith("Thought:") {
            formattedThoughts = string `Thought: ${formattedThoughts}`;
        }

        io:println(formattedThoughts);

        NextAction selectedTool = check self.parseLLMResponse(formattedThoughts);
        if selectedTool.isCompleted {
            return {thought: formattedThoughts};
        }
        string observation = check self.agent.getToolStore().runTool(selectedTool.tool, selectedTool.tool_input);
        check self.updatePromptHistory(formattedThoughts, observation);

        io:println(observation);
        return {thought: formattedThoughts, observation: observation};
    }

    function getPromptConstruct() returns PromptConstruct {
        return self.prompt;
    }
}

# Agent implementation to perform tools with LLMs to add computational power and knowledge to the LLMs
public class Agent {

    private LLMModel model;
    private ToolStore toolStore;

    # Initialize an Agent
    #
    # + model - LLM model instance
    # + toolLoader - ToolLoader instance to load tools from (optional)
    public function init(LLMModel model, (BaseToolKit|Tool)... tools) returns error? {
        if tools.length() == 0 {
            return error("No tools provided to the agent");
        }
        self.model = model;
        self.toolStore = new;
        foreach BaseToolKit|Tool tool in tools {
            if (tool is BaseToolKit) {
                self.registerLoaders(<BaseToolKit>tool);
            } else {
                check self.toolStore.registerTools(<Tool>tool);
            }
        }
    }

    private function registerLoaders(BaseToolKit... loaders) {
        loaders.forEach(function(BaseToolKit loader) {
            loader.initializeToolKit(self.toolStore);
        });
    }

    # Initialize the prompt during a single run for a given user query
    #
    # + query - User's query  
    # + context - Context information to be used by the LLM
    # + return - PromptConstruct record or an error if the initialization failed
    private function initializaPrompt(string query, json context) returns PromptConstruct {
        ToolInfo output = self.toolStore.extractToolInfo();
        string blacktick = "`";
        string toolDescriptions = output.toolIntro;
        string toolNames = output.toolList;
        string contextInfo = "";
        if context != {} {
            contextInfo = string `
You can also use the following information: 
${context.toString()}
`;
        }

        string instruction =
string `Answer the following questions as best you can without making any assumptions. You have access to the following tools:

${toolDescriptions.trim()}
${contextInfo}
Use a JSON blob with the following format to define the action and input.

${blacktick}${blacktick}${blacktick}
{
  "tool": the tool to take, should be one of [${toolNames}]",
  "tool_input": JSON input record to the tool
}
${blacktick}${blacktick}${blacktick}

ALWAYS use the following format:

Question: the input question you must answer
Thought: you should always think about what to do
Action:
${blacktick}${blacktick}${blacktick}
$JSON_BLOB only for a SINGLE tool (Do NOT return a list of multiple tools)
${blacktick}${blacktick}${blacktick}
Observation: the result of the action
... (this Thought/Action/Observation can repeat N times)
Thought: I now know the final answer
Final Answer: the final answer to the original input question

Begin! Reminder to use the EXACT types as specified in JSON "inputSchema" to generate input records.`;

        return {
            instruction: instruction.trim(),
            query: query.trim(),
            history: []
        };
    }

    public function createAgentExecutor(string query, json context = {}) returns AgentExectutor {
        io:println(self.initializaPrompt(query, context));
        return new (self, self.initializaPrompt(query, context));
    }

    # Execute the agent for a given user's query
    #
    # + query - Natural langauge commands to the agent  
    # + maxIter - No. of max iterations that agent will run to execute the task  
    # + context - Context values to be used by the agent to execute the task
    # + return - Returns error, in case of a failure
    public function run(string query, int maxIter = 5, json context = {}) returns error? {
        AgentExectutor executor = self.createAgentExecutor(query, context);
        int iter = 0;
        while maxIter > iter {
            iter += 1;
            io:println("\n\nReasoning iteration: " + (iter).toString());
            ExectutorOutput nextResult = check executor.next();

            if nextResult?.observation is () {
                // io:println(nextResult.thought);
                break;
            }
        }
    }

    function getLLMModel() returns LLMModel {
        return self.model;
    }

    function getToolStore() returns ToolStore {
        return self.toolStore;
    }

}
