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
import ballerina/log;
import ballerina/io;

# Prompt construct record
public type QueryProgress record {|
    # Query to the prompt
    string query;
    # Execution history up to the current point
    ExecutionStep[] history = [];
    # Contextual instruction to the prompt
    map<json>|string context?;
|};

public type ExecutionStep record {|
    # Tool decided by the LLM during the reasoning
    ToolResponse action;
    # Observations produced by the tool during the execution
    anydata|error observation;
|};

public type NextTool record {|
    # Name of the tool to be performed
    string name;
    # Input to the tool
    map<json>? arguments = {};
|};

public type ToolResponse record {|
    NextTool|LlmInvalidGenerationError tool;
    json generated;
|};

type ChatResponse record {|
    # answer to the question
    string content;
|};

# Output from executing a tool
public type ToolOutput record {|
    # Output value the tool
    anydata|error value;
|};

type BaseAgent distinct isolated object {
    LlmModel model;
    ToolStore toolStore;

    # Use LLMs to decide the next tool/step.
    #
    # + progress - QueryProgress with the current query and execution history
    # + return - NextAction decided by the LLM or an error if call to the LLM fails
    isolated function decideNextTool(QueryProgress progress) returns ToolResponse|ChatResponse|LlmError;
};

public class AgentIterator {
    *object:Iterable;

    private final AgentExecutor executor;

    isolated function init(BaseAgent agent, string query, map<json>|string? context = ()) {
        self.executor = new (agent, query, context = context);
    }

    # Iterate over the agent's execution steps.
    # + return - a record with the execution step or an error if the agent failed
    public function iterator() returns object {
        public function next() returns record {|ExecutionStep|ChatResponse|error value;|}?;
    } {
        return self.executor;
    }
}

public class AgentExecutor {
    private boolean isCompleted = false;
    private final BaseAgent agent;
    private final ToolStore toolStore;
    QueryProgress progress;

    isolated function init(BaseAgent agent, string query, ExecutionStep[] history = [], map<json>|string? context = ()) {
        self.agent = agent;
        self.progress = {
            query: query,
            history: history,
            context: context
        };
        self.toolStore = agent.toolStore;
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
    public isolated function reason() returns ToolResponse|ChatResponse|TaskCompletedError|LlmError {
        if self.isCompleted {
            return error TaskCompletedError("Task is already completed. No more reasoning is needed.");
        }
        ToolResponse|ChatResponse respond = check self.agent.decideNextTool(self.progress);
        if respond is ChatResponse {
            self.isCompleted = true;

        }
        return respond;
    }

    # Execute the next step of the agent.
    #
    # + action - NextTool record to be executed by the agent or FinalResponse record if the task is completed (LlmInvalidGenerationError if the tool generated is not valid)
    # + return - Observations from the tool can be any|error|null
    public isolated function act(ToolResponse action) returns ToolOutput {
        ToolOutput observation;
        NextTool|LlmInvalidGenerationError tool = action.tool;

        // TODO Improve to use intructions from the error instead of generic error instructions 
        if tool is NextTool {
            ToolOutput|error output = self.toolStore.runTool(tool);
            if output is error {
                observation = {value: "Tool execution failed due to invalid inputs. Retry with correct inputs."};
            } else {
                observation = output;
            }
        }
        else {
            observation = {value: "Tool extraction failed due to invalid JSON_BLOB. Retry with correct JSON_BLOB."};
        }

        self.progress.history.push(
            {
            action,
            observation: observation.value
        });
        return observation;
    }

    # Update the agent with the latest exectuion step.
    #
    # + step - Latest step to be added to the history
    public isolated function update(ExecutionStep step) {
        ExecutionStep[] history = self.progress.history;
        history.push(step);
    }

    # Execute the next step of the agent.
    #
    # + return - A record with ExecutionStep or error 
    public isolated function next() returns record {|ExecutionStep|ChatResponse|error value;|}? {
        ToolResponse|ChatResponse|error action = self.reason();
        if action is ChatResponse|error {
            return {value: action};
        }
        return {
            value: {
                action,
                observation: self.act(action).value
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
# + maxIter - No. of max iterations that agent will run to execute the task  
# + context - Context values to be used by the agent to execute the task
# + verbose - If true, then print the reasoning steps
# + return - Returns the execution steps tracing the agent's reasoning and outputs from the tools
isolated function run(BaseAgent agent, string query, int maxIter = 5, string|map<json> context = {}, boolean verbose = true) returns record {|ExecutionStep[] steps; string answer?;|} {
    ExecutionStep[] steps = [];
    string? content = ();
    AgentIterator iterator = new (agent, query, context = context);
    int iter = 0;
    foreach ExecutionStep|ChatResponse|error step in iterator {
        if iter == maxIter {
            break;
        }
        if step is error {
            error? cause = step.cause();
            log:printError("Error occured while executing the agent", step, cause = cause !is () ? cause.toString() : "");
            break;
        }
        if step is ChatResponse {
            content = step.content;
            if verbose {
                io:println(string `${"\n\n"}Final Answer - ${step.content}${"\n\n"}`);
            }
            break;
        }
        iter += 1;
        if verbose {
            io:println(string `${"\n\n"}Agent Iteration - ${iter.toString()}`);
            NextTool|LlmInvalidGenerationError tool = step.action.tool;
            if tool is NextTool {

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
                string thought = step.action.generated.toString();
                io:println(string `LLM Generation Error: 
${"```"}
{
    message: ${tool.message()},
    cause: ${(cause is error ? cause.message() : "Unspecified")}${string `,${"\n"}    thought: ${thought}`}
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
        return "Tool didn't return anything. Probably it is successful. Can I verify using another tool?";
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
