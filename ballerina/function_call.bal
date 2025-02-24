// Copyright (c) 2024 WSO2 LLC (http://www.wso2.com).
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

# Function call agent. 
# This agent uses OpenAI function call API to perform the tool selection.
public isolated distinct client class FunctionCallAgent {
    *BaseAgent;
    # Tool store to be used by the agent
    public final ToolStore toolStore;
    # LLM model instance (should be a function call model)
    public final FunctionCallLlmModel model;

    # Initialize an Agent.
    #
    # + model - LLM model instance
    # + tools - Tools to be used by the agent
    public isolated function init(FunctionCallLlmModel model, (BaseToolKit|ToolConfig|FunctionTool)... tools) returns error? {
        self.toolStore = check new (...tools);
        self.model = model;
    }

    # Parse the function calling API response and extract the tool to be executed.
    #
    # + llmResponse - Raw LLM response
    # + return - A record containing the tool decided by the LLM, chat response or an error if the response is invalid
    public isolated function parseLlmResponse(json llmResponse) returns LlmToolResponse|LlmChatResponse|LlmInvalidGenerationError {
        if llmResponse is string {
            return {content: llmResponse};
        }
        if llmResponse !is FunctionCall {
            return error LlmInvalidGenerationError("Invalid response", llmResponse = llmResponse);
        }
        string? name = llmResponse.name;
        if name is () {
            return error LlmInvalidGenerationError("Missing name", name = llmResponse.name, arguments = llmResponse.arguments);
        }
        string? stringArgs = llmResponse.arguments;
        map<json>|error? arguments = ();
        if stringArgs is string {
            arguments = stringArgs.fromJsonStringWithType();
        }
        if arguments is error {
            return error LlmInvalidGenerationError("Invalid arguments", arguments, name = llmResponse.name, arguments = stringArgs);
        }
        return {
            name,
            arguments
        };
    }

    # Use LLM to decide the next tool/step based on the function calling APIs.
    #
    # + progress - Execution progress with the current query and execution history
    # + return - LLM response containing the tool or chat response (or an error if the call fails)
    public isolated function selectNextTool(ExecutionProgress progress) returns json|LlmError {
        ChatMessage[] messages = createFunctionCallMessages(progress);
        return self.model.functionCall(messages,
        from AgentTool tool in self.toolStore.tools.toArray()
        select {
            name: tool.name,
            description: tool.description,
            parameters: tool.variables
        });
    }

    isolated remote function run(string query, int maxIter = 5, string|map<json> context = {}, boolean verbose = true) returns record {|(ExecutionResult|ExecutionError)[] steps; string answer?;|} {
        return run(self, query, maxIter, context, verbose);
    }
}

isolated function createFunctionCallMessages(ExecutionProgress progress) returns ChatMessage[] {
    // add the question
    ChatMessage[] messages = [
        {
            role: USER,
            content: progress.query
        }
    ];
    // add the context as the first message
    if progress.context !is () {
        messages.unshift({
            role: SYSTEM,
            content: string `You can use these information if needed: ${progress.context.toString()}`
        });
    }
    // include the history
    foreach ExecutionStep step in progress.history {
        FunctionCall|error functionCall = step.llmResponse.fromJsonWithType();
        if functionCall is error {
            panic error("Badly formated history for function call agent", llmResponse = step.llmResponse);
        }

        messages.push({
            role: ASSISTANT,
            function_call: functionCall
        },
        {
            role: FUNCTION,
            name: functionCall.name,
            content: getObservationString(step.observation)
        });
    }
    return messages;
}
