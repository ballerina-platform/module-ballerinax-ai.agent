// Copyright (c) 2024 WSO2 LLC (http://www.wso2.org) All Rights Reserved.
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

# Function call agent. 
# This agent uses OpenAI function call API to perform the tool selection.
public isolated class FunctionCallAgent {
    *BaseAgent;
    final ToolStore toolStore;
    final FunctionCallLlm model;

    # Initialize an Agent.
    #
    # + model - LLM model instance
    # + tools - Tools to be used by the agent
    public isolated function init(FunctionCallLlm model, (BaseToolKit|Tool)... tools) returns error? {
        self.toolStore = check new (...tools);
        self.model = model;
    }

    isolated function parseLlmResponse(json llmResponse) returns LlmToolResponse|LlmChatResponse|LlmInvalidGenerationError {
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

    isolated function selectNextTool(ExecutionProgress progress) returns json|LlmError {
        ChatMessage[] messages = createFunctionCallMessages(progress);
        return self.model.functionaCall(messages,
        from AgentTool tool in self.toolStore.tools.toArray()
        select {
            name: tool.name,
            description: tool.description,
            parameters: tool.variables
        });
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
        }, {
            role: FUNCTION,
            name: functionCall.name,
            content: getObservationString(step.observation)
        });
    }
    return messages;
}
