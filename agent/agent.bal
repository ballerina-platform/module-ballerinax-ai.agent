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
# + action - Name of the action to be performed
# + actionInput - Input to the action
# + thought - Thought by the LLM
# + finalThought - If the thought is the final one
public type LLMResponse record {|
    string action;
    json actionInput;
    string thought;
    boolean finalThought;
|};

# Agent implementation to perform actions with LLMs to add computational power and knowledge to the LLMs
public class Agent {

    private string prompt;
    private LLMModel model;
    private ActionStore actionStore;

    # Initialize an Agent
    #
    # + model - LLM model instance
    # + actionLoader - ActionLoader instance to load actions from (optional)
    public function init(LLMModel model, ActionLoader... actionLoader) returns error? {
        self.prompt = "";
        self.model = model;
        self.actionStore = new;
        if actionLoader.length() > 0 {
            self.registerLoaders(...actionLoader);
        }
    }

    private function registerLoaders(ActionLoader... loaders) {
        loaders.forEach(function(ActionLoader loader) {
            loader.initializeLoader(self.actionStore);
        });
    }

    # Register actions to the agent. 
    # These actions will be by the LLM to perform tasks 
    #
    # + actions - A list of actions that are available to the LLM
    public function registerActions(Action... actions) {
        self.actionStore.registerActions(...actions);
    }

    # Initialize the prompt during a single run for a given user query
    #
    # + query - User's query
    private function initializaPrompt(string query) {
        generatedOutput output = self.actionStore.generateDescriptions();
        string actionDescriptions = output.actionDescriptions;
        string actionNames = output.actionNames;

        string promptTemplate = string `
Answer the following questions as best you can without making any assumptions. You have access to the following ${ACTION_KEYWORD}s: 

${actionDescriptions}
${self.actionStore.actionInstructions}

Use the following format:
Question: the input question you must answer
Thought: you should always think about what to do
Action: the action to take, should be one of ${actionNames}.
Action Input: the input to the action
Observation: the result of the action
... (this Thought/Action/Action Input/Observation can repeat N times)
Thought: I now know the final answer
Final Answer: the final answer to the original input question

Begin!

${query}
Thought:`;

        self.prompt = promptTemplate.trim(); // reset the prompt during each run
    }

    # Build the prompts during each decision iterations 
    #
    # + thoughts - Thoughts by the model during the previous iterations
    # + observation - Observations returned by the performed action
    private function buildNextPrompt(string thoughts, string observation) {

        self.prompt = string `${self.prompt} ${thoughts}
Observation: ${observation}
Thought:`;

    }

    # Use LLMs to decide the next action 
    # + return - Decision by the LLM or an error if call to the LLM fails
    private function decideNextAction() returns string?|error {
        return self.model.complete(self.prompt);
    }

    # Parse the LLM response in string form to an LLMResponse record
    #
    # + rawResponse - String form LLM response including new action 
    # + return - LLMResponse record or an error if the parsing failed
    private function parseLLMResponse(string rawResponse) returns LLMResponse|error {
        string replaceChar = "=";
        string splitChar = ":";
        string[] content = regex:split(rawResponse, "\n");
        string thought = content[0].trim();
        if content.length() == FINAL_THOUGHT_LINE_COUNT {
            return {
                thought: thought,
                action: content[1].trim(),
                actionInput: null,
                finalThought: true
            };
        }
        if content.length() == REGULAR_THOUGHT_LINE_COUNT {
            json actionInput = check regex:split(regex:replace(content[2], splitChar, replaceChar), replaceChar).pop().fromJsonString();
            return {
                thought: thought,
                action: regex:split(content[1], splitChar).pop().trim(),
                actionInput: actionInput,
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
        LLMResponse action;
        while maxIter > iter {
            string? response = check self.decideNextAction();
            if !(response is string) {
                io:println(string `Model returns invalid response: ${response.toString()}`);
                break;
            }
            string currentThought = response.toString().trim();

            io:println("\n\nReasoning iteration: " + (iter + 1).toString());
            io:println("Thought: " + currentThought);

            action = check self.parseLLMResponse(currentThought);
            if action.finalThought {
                break;
            }

            string currentObservation = check self.actionStore.executeAction(action.action, action.actionInput);
            self.buildNextPrompt(currentThought, currentObservation);
            iter = iter + 1;

            io:println("Observation: " + currentObservation);
        }
    }
}
