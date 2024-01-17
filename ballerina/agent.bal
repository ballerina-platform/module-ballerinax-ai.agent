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

# Execution progress record
public type ExecutionProgress record {|
    # Question to the agent
    string query;
    # Execution history up to the current action
    ExecutionStep[] history = [];
    # Contextual instruction that can be used by the agent during the execution
    map<json>|string context?;
|};

# Execution step information
public type ExecutionStep record {|
    # Tool decided by the LLM during the reasoning
    LlmToolResponse toolResponse;
    # Observations produced by the tool during the execution
    anydata|error observation;
|};

# An LLM response containing the selected tool to be executed
public type LlmToolResponse record {|
    # Next tool to be executed
    SelectedTool|LlmInvalidGenerationError tool;
    # Raw LLM generated output
    json llmResponse;
|};

# An chat response by the LLM
public type LlmChatResponse record {|
    # A text response to the question
    string content;
|};

# Tool selected by LLM to be performed by the agent
public type SelectedTool record {|
    # Name of the tool to selected
    string name;
    # Input to the tool
    map<json>? arguments = {};
|};

# Output from executing an action
public type ToolOutput record {|
    # Output value the tool
    anydata|error value;
|};

public type BaseAgent distinct isolated object {
    LlmModel model;
    ToolStore toolStore;

    # Use LLMs to decide the next tool/step.
    #
    # + progress - QueryProgress with the current query and execution history
    # + return - NextAction decided by the LLM or an error if call to the LLM fails
    isolated function selectNextTool(ExecutionProgress progress) returns LlmToolResponse|LlmChatResponse|LlmError;
};

# An iterator to iterate over agent's execution
public class AgentIterator {
    *object:Iterable;
    private final AgentExecutor executor;

    # Initialize the iterator with the agent and the query.
    #
    # + agent - Agent instance to be executed
    # + query - Natural language query to be executed by the agent
    # + context - Contextual information to be used by the agent during the execution
    public isolated function init(BaseAgent agent, string query, map<json>|string? context = ()) {
        self.executor = new (agent, query, context = context);
    }

    # Iterate over the agent's execution steps.
    # + return - a record with the execution step or an error if the agent failed
    public function iterator() returns object {
        public function next() returns record {|ExecutionStep|LlmChatResponse|error value;|}?;
    } {
        return self.executor;
    }
}

# An executor to perform step-by-step execution of the agent.
public class AgentExecutor {
    private boolean isCompleted = false;
    private final BaseAgent agent;
    # Contains the current execution progress for the agent and the query
    public ExecutionProgress progress;

    # Initialize the executor with the agent and the query.
    #
    # + agent - Agent instance to be executed
    # + query - Natural language query to be executed by the agent
    # + history - Execution history of the agent (This is used to continue an execution paused without completing)
    # + context - Contextual information to be used by the agent during the execution
    public isolated function init(BaseAgent agent, string query, ExecutionStep[] history = [], map<json>|string? context = ()) {
        self.agent = agent;
        self.progress = {
            query,
            history,
            context
        };
    }

    # Checks whether agent has more steps to execute.
    #
    # + return - True if agent has more steps to execute, false otherwise
    public isolated function hasNext() returns boolean {
        return !self.isCompleted;
    }

    # Reason the next step of the agent.
    #
    # + return - Thought to be executed by the agent or an error if the reasoning failed
    public isolated function reason() returns LlmToolResponse|LlmChatResponse|TaskCompletedError|LlmError {
        if self.isCompleted {
            return error TaskCompletedError("Task is already completed. No more reasoning is needed.");
        }
        LlmToolResponse|LlmChatResponse respond = check self.agent.selectNextTool(self.progress);
        if respond is LlmChatResponse {
            self.isCompleted = true;
        }
        return respond;
    }

    # Execute the next step of the agent.
    #
    # + toolResponse - LLM tool response containing the tool to be executed and the raw LLM output
    # + return - Observations from the tool can be any|error|null
    public isolated function act(LlmToolResponse toolResponse) returns ToolOutput {
        ToolOutput observation;
        SelectedTool|LlmInvalidGenerationError tool = toolResponse.tool;

        // TODO Improve to use intructions from the error instead of generic error instructions 
        if tool is SelectedTool {
            ToolOutput|error output = self.agent.toolStore.execute(tool);
            if output is ToolNotFoundError {
                observation = {value: "Tool is not found. Please check the tool name and retry."};
            } else if output is ToolInvalidInputError {
                observation = {value: "Tool execution failed due to invalid inputs. Retry with correct inputs."};
            } else if output is error {
                observation = {value: "Tool execution failed. Retry with correct inputs."};
            } else {
                observation = output;
            }
        }
        else {
            observation = {value: "Tool extraction failed due to invalid JSON_BLOB. Retry with correct JSON_BLOB."};
        }
        // update the execution history with the latest step
        self.update({
            toolResponse,
            observation: observation.value
        });
        return observation;
    }

    # Update the agent with an execution step.
    #
    # + step - Latest step to be added to the history
    public isolated function update(ExecutionStep step) {
        self.progress.history.push(step);
    }

    # Execute the next step of the agent.
    #
    # + return - A record with ExecutionStep or error 
    public isolated function next() returns record {|ExecutionStep|LlmChatResponse|error value;|}? {
        LlmToolResponse|LlmChatResponse|error toolResponse = self.reason();
        if toolResponse is LlmChatResponse|error {
            return {value: toolResponse};
        }
        return {
            value: {
                toolResponse,
                observation: self.act(toolResponse).value
            }
        };
    }

    # Allow retrieving the execution history during previous steps.
    #
    # + return - Execution history of the agent (A list of ExecutionStep)
    public isolated function getExecutionHistory() returns ExecutionStep[] {
        return self.progress.history;
    }
}

# Execute the agent for a given user's query.
#
# + agent - Agent to be executed
# + query - Natural langauge commands to the agent  
# + maxIter - No. of max iterations that agent will run to execute the task (default: 5)
# + context - Context values to be used by the agent to execute the task
# + verbose - If true, then print the reasoning steps (default: true)
# + return - Returns the execution steps tracing the agent's reasoning and outputs from the tools
public isolated function run(BaseAgent agent, string query, int maxIter = 5, string|map<json> context = {}, boolean verbose = true) returns record {|ExecutionStep[] steps; string answer?;|} {
    ExecutionStep[] steps = [];
    string? content = ();
    AgentIterator iterator = new (agent, query, context = context);
    int iter = 0;
    foreach ExecutionStep|LlmChatResponse|error step in iterator {
        if iter == maxIter {
            break;
        }
        if step is error {
            error? cause = step.cause();
            log:printError("Error occured while executing the agent", step, cause = cause !is () ? cause.toString() : "");
            break;
        }
        if step is LlmChatResponse {
            content = step.content;
            if verbose {
                io:println(string `${"\n\n"}Final Answer: ${step.content}${"\n\n"}`);
            }
            break;
        }
        iter += 1;
        if verbose {
            io:println(string `${"\n\n"}Agent Iteration ${iter.toString()}`);
            SelectedTool|LlmInvalidGenerationError tool = step.toolResponse.tool;
            if tool is SelectedTool {

                io:println(string `Action:
${"```"}
{
    name: ${tool.name},
    arguments: ${(tool.arguments ?: "None").toString()}}
}
${"```"}`);
                anydata|error observation = step?.observation;
                if observation is error {
                    io:println(string `Observation (Error): ${observation.toString()}`);
                } else if observation !is () {
                    io:println(string `Observation: ${observation.toString()}`);
                }
            } else {
                error? cause = tool.cause();
                string llmResponse = step.toolResponse.llmResponse.toString();
                io:println(string `LLM Generation Error: 
${"```"}
{
    message: ${tool.message()},
    cause: ${(cause is error ? cause.message() : "Unspecified")},
    llmResponse: ${llmResponse}
}
${"```"}`);
            }
        }
        steps.push(step);
    }
    return {steps, answer: content};
}

isolated function getObservationString(anydata|error observation) returns string {
    if observation is () {
        return "Tool didn't return anything. Probably it is successful. Should we verify using another tool?";
    } else if observation is error {
        record {|string message; string cause?;|} errorInfo = {
            message: observation.message().trim()
        };
        error? cause = observation.cause();
        if cause is error {
            errorInfo.cause = cause.message().trim();
        }
        return "Error occured while trying to execute the tool: " + errorInfo.toString();
    } else {
        return observation.toString().trim();
    }
}
