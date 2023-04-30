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
# + toolInput - Input to the tool
# + thought - Thought by the LLM
# + finalThought - If the thought is the final one
public type LLMResponse record {|
    string tool;
    json toolInput;
    string thought;
    boolean finalThought;
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
        generatedOutput output = self.toolStore.generateDescriptions();
        string toolDescriptions = output.toolDescriptions;
        string toolNames = output.toolNames;

        string promptTemplate = string `
Answer the following questions as best you can without making any assumptions. You have access to the following ${TOOL_KEYWORD}s: 

${toolDescriptions}

Use the following format:
Question: the input question you must answer
Thought: you should always think about what to do
Tool: the tool to take, should be one of ${toolNames}.
Tool Input: the input to the tool
Observation: the result of the tool
... (this Thought/Tool/Tool Input/Observation can repeat N times)
Thought: I now know the final answer
Final Answer: the final answer to the original input question

Begin!

Question: ${query}
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
    # + rawResponse - String form LLM response including new tool 
    # + return - LLMResponse record or an error if the parsing failed
    private function parseLLMResponse(string rawResponse) returns LLMResponse|error {
        string replaceChar = "=";
        string splitChar = ":";
        string[] content = regex:split(rawResponse, "\n");
        string thought = content[0].trim();
        if content.length() == FINAL_THOUGHT_LINE_COUNT {
            return {
                thought: thought,
                tool: content[1].trim(),
                toolInput: null,
                finalThought: true
            };
        }
        if content.length() == REGULAR_THOUGHT_LINE_COUNT {
            json toolInput = check regex:split(regex:replace(content[2], splitChar, replaceChar), replaceChar).pop().fromJsonString();
            return {
                thought: thought,
                tool: regex:split(content[1], splitChar).pop().trim(),
                toolInput: toolInput,
                finalThought: false
            };
        }
        return error(string `Error while parsing LLM response: ${rawResponse}`);
    }

    # Execute the agent for a given user's query
    #
    # + query - Natural langauge commands to the agent
    # + maxIter - No. of max iterations that agent will run to execute the task
    # + return - Returns error, in case of a failure
    public function run(string query, int maxIter = 5) returns error? {
        self.initializaPrompt(query);
        int iter = 0;
        LLMResponse tool;
        while maxIter > iter {
            string? response = check self.decideNextTool();
            if !(response is string) {
                io:println(string `Model returns invalid response: ${response.toString()}`);
                break;
            }
            string currentThought = response.toString().trim();

            io:println("\n\nReasoning iteration: " + (iter + 1).toString());
            io:println("Thought: " + currentThought);

            tool = check self.parseLLMResponse(currentThought);
            if tool.finalThought {
                break;
            }

            string currentObservation = check self.toolStore.runTool(tool.tool, tool.toolInput);
            self.buildNextPrompt(currentThought, currentObservation);
            iter = iter + 1;

            io:println("Observation: " + currentObservation);
        }
    }
}
