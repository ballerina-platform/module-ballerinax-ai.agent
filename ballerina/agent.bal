// Copyright (c) 2025 WSO2 LLC (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
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

# Represents the system prompt given to the agent.
@display {label: "System Prompt"}
public type SystemPrompt record {|

    # The role or responsibility assigned to the agent
    @display {label: "Role"}
    string role;

    # Specific instructions for the agent
    @display {label: "Instructions"}
    string instructions;

    string...;
|};

# Represents the different types of agents supported by the module.
@display {label: "Agent Type"}
public enum AgentType {
    # Represents a ReAct agent
    REACT_AGENT,
    # Represents a function call agent
    FUNCTION_CALL_AGENT
}

# Provides a set of configurations for the agent.
@display {label: "Agent Configuration"}
public type AgentConfiguration record {|

    # The system prompt assigned to the agent
    @display {label: "System Prompt"}
    SystemPrompt systemPrompt;

    # The model used by the agent
    @display {label: "Model"}
    Model model;

    # The tools available for the agent
    @display {label: "Tools"}
    (BaseToolKit|ToolConfig|FunctionTool)[] tools = [];

    # Type of the agent
    @display {label: "Agent Type"}
    AgentType agentType = FUNCTION_CALL_AGENT;

    # The maximum number of iterations the agent performs to complete the task
    @display {label: "Maximum Iterations"}
    int maxIter = 5;

    # Specifies whether verbose logging is enabled
    @display {label: "Verbose"}
    boolean verbose = false;

    # The memory manager used by the agent to store and manage conversation history
    @display {label: "Memory Manager"}
    MemoryManager memoryManager = new DefaultMessageWindowChatMemoryManager();
|};

# Represents an agent.
public isolated distinct client class Agent {
    private final BaseAgent agent;
    private final int maxIter;
    private final readonly & SystemPrompt systemPrompt;
    private final boolean verbose;

    # Initialize an Agent.
    #
    # + config - Configuration used to initialize an agent
    public isolated function init(@display {label: "Agent Configuration"} *AgentConfiguration config) returns Error? {
        self.maxIter = config.maxIter;
        self.verbose = config.verbose;
        self.systemPrompt = config.systemPrompt.cloneReadOnly();
        self.agent = config.agentType is REACT_AGENT ? check new ReActAgent(config.model, config.tools, config.memoryManager)
            : check new FunctionCallAgent(config.model, config.tools, config.memoryManager);
    }

    # Executes the agent for a given user query.
    #
    # + query - The natural language input provided to the agent
    # + memoryId - The ID associated with the agent memory
    # + return - The agent's response or an error
    isolated remote function run(@display {label: "Query"} string query, @display {label: "Memory ID"} string memoryId = DEFAULT_MEMORY_ID) returns string|Error {
        var result = self.agent->run(query, self.maxIter, getFomatedSystemPrompt(self.systemPrompt), self.verbose, memoryId);
        string? answer = result.answer;
        if answer is string {
            return answer;
        }
        check validateExecutionSteps(result.steps);
        return error MaxIterationExceededError("Maximum iteration limit exceeded while processing the query.",
            steps = result.steps);
    }
}

// Validates whether the execution steps contain only one memory error.
// If there is exactly one memory error, it is returned; otherwise, null is returned.
isolated function validateExecutionSteps((ExecutionResult|ExecutionError)[] steps) returns MemoryError? {
    if steps.length() != 1 {
        return;
    }
    ExecutionResult|ExecutionError step = steps.pop();
    if step is ExecutionError && step.'error is MemoryError {
        return <MemoryError>step.'error;
    }
}

isolated function getFomatedSystemPrompt(SystemPrompt systemPrompt) returns string {
    string additionalInstructions = "";
    foreach [string, string] [key, value] in systemPrompt.entries() {
        if key != "role" && key != "instructions" {
            additionalInstructions += "\n" + key + ":\n" + value + "\n";
        }
    }
    return string `You are an AI agent with the following responsibility: ${systemPrompt.role}` +
        "Please follow these instructions:" + "\n" + systemPrompt.instructions + "\n" + additionalInstructions;
}
