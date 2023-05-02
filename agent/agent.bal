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

# Agent implementation to perform tools with LLMs to add computational power and knowledge to the LLMs
public class Agent {

    private string prompt;
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
        self.prompt = "";
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
    private function initializaPrompt(string query) {
        ToolInfo output = self.toolStore.extractToolInfo();
        string blacktick = "`";
        string toolDescriptions = output.toolIntro;
        string toolNames = output.toolList;

        string instruction = "Answer the following questions as best you can without making any assumptions. " +
        "You have access to the following tools. Use the JSON `inputSchema` to generate the input records";

        string formatInstruction =
string ` Use a JSON blob with the following format to define the action and input. Do NOT return a list of multiple actions, the $JSON_BLOB should only contain a SINGLE action.

${blacktick}${blacktick}${blacktick}
{
  "tool": the tool to take, should be one of [${toolNames}]",
  "tool_input": the input to the tool 
}
${blacktick}${blacktick}${blacktick}

ALWAYS use the following format:

Question: the input question you must answer
Thought: you should always think about what to do
Action:
${blacktick}${blacktick}${blacktick}
$JSON_BLOB
${blacktick}${blacktick}${blacktick}
Observation: the result of the action
... (this Thought/Action/Observation can repeat N times)
Thought: I now know the final answer
Final Answer: the final answer to the original input question

Begin!`;

        string promptTemplate = string `
${instruction}:

${toolDescriptions.trim()}

${formatInstruction.trim()}

Question: ${query.trim()}
Thought:`;

        self.prompt = promptTemplate.trim(); // reset the prompt during each run
    }

    # Build the prompts during each decision iterations 
    #
    # + thoughts - Thoughts by the model during the previous iterations
    # + observation - Observations returned by the performed tool
    private function buildNextPrompt(string thoughts, string observation) {

        self.prompt = string `${self.prompt} ${thoughts}
Observation: ${observation}
Thought:`;

    }
    # Use LLMs to decide the next tool 
    # + return - Decision by the LLM or an error if call to the LLM fails
    private function decideNextTool() returns string?|error {
        return self.model.complete(self.prompt);
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
        string[] content = regex:split(llmResponse, "```");
        NextAction|error nextAction = content[1].fromJsonStringWithType();
        if nextAction is error {
            return error(string `Error while extracting actions from LLM response. ${nextAction.toString()}`);
        }
        return nextAction;
    }

    # Execute the agent for a given user's query
    #
    # + query - Natural langauge commands to the agent
    # + maxIter - No. of max iterations that agent will run to execute the task
    # + return - Returns error, in case of a failure
    public function run(string query, int maxIter = 5) returns error? {
        self.initializaPrompt(query);
        io:println(self.prompt);
        int iter = 0;
        NextAction selectedTool;
        while maxIter > iter {
            // io:println(self.prompt);
            string? response = check self.decideNextTool();
            if !(response is string) {
                io:println(string `Model returns invalid response: ${response.toString()}`);
                break;
            }
            string currentThought = response.toString().trim();

            io:println("\n\nReasoning iteration: " + (iter + 1).toString());
            io:println("Thought: " + currentThought);

            selectedTool = check self.parseLLMResponse(currentThought);
            if selectedTool.isCompleted {
                break;
            }

            string currentObservation = check self.toolStore.runTool(selectedTool.tool, selectedTool.tool_input);
            self.buildNextPrompt(currentThought, currentObservation);
            iter = iter + 1;

            io:println("Observation: " + currentObservation);
        }
    }
}
