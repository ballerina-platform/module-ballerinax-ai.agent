// Copyright (c) 2023, WSO2 LLC. (http://www.wso2.com). All Rights Reserved.

// This software is the property of WSO2 LLC. and its suppliers, if any.
// Dissemination of any information or reproduction of any material contained
// herein is strictly forbidden, unless permitted by WSO2 in accordance with
// the WSO2 Commercial License available at http://wso2.com/licenses.
// For specific language governing the permissions and limitations under
// this license, please see the license as well as any agreement you’ve
// entered into with WSO2 governing the purchase of this software and any

import ballerina/io;
import ballerina/regex;

public type LLMResponse record {|
    string action;
    json actionInput;
    string thought;
    boolean finalThought;
|};

# Agent implementation to perform actions with LLMs to add
# computational power and knowledge to the LLMs
public class Agent {

    private string prompt;
    private map<Action> actions;
    private LLMModel model;
    private ActionStore actionStore;

    # Initialize an Agent
    #
    # + model - LLM model instance
    public function init(LLMModel model) {
        self.prompt = "";
        self.actions = {};
        self.model = model;
        self.actionStore = new;
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
    # + query - user's query
    private function initializaPrompt(string query) {
        generatedOutput output = self.actionStore.generateDescriptions();
        string actionDescriptions = output.actionDescriptions;
        string actionNames = output.actionNames;

        string promptTemplate = string `
Answer the following questions as best you can without making any assumptions. You have access to the following ${ACTION_KEYWORD}s: 

${actionDescriptions}

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
    # + thoughts - thoughts by the model during the previous iterations
    # + observation - observations returned by the performed action
    private function buildNextPrompt(string thoughts, string observation) {

        self.prompt = string `${self.prompt} ${thoughts}
Observation: ${observation}
Thought:`;

    }

    # Use LLMs to decide the next action 
    # + return - decision by the LLM or an error if call to the LLM fails
    private function decideNextAction() returns string?|error {
        return self.model.complete(self.prompt);
    }

    # Parse the LLM response in string form to an LLMResponse record
    #
    # + rawResponse - string form LLM response including new action 
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
    # + query - natural langauge commands to the agent
    # + maxIter - no. of max iterations that agent will run to execute the task
    # + return - returns error, in case of a failure
    public function run(string query, int maxIter = 5) returns error? {
        self.initializaPrompt(query);
        io:println(self.prompt);

        int iter = 0;
        LLMResponse action;
        while maxIter > iter {

            string? response = check self.decideNextAction();
            if !(response is string) {
                io:println(string `Model returns invalid response: ${response.toString()}`);
                break;
            }
            string currentThought = response.toString().trim();

            io:println("\n\nReasoning iteration: " + (iter+1).toString());
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
