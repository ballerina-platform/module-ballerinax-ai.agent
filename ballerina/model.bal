// Copyright (c) 2023 WSO2 LLC (http://www.wso2.com).
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

import ballerinax/azure.openai.chat as azure_chat;
import ballerinax/openai.chat;

// TODO: change the configs to extend the config record from the respective clients.
// requirs using never prompt?; never stop? to prevent setting those during initialization
// change once https://github.com/ballerina-platform/ballerina-lang/issues/32012 is fixed

# Roles for the chat messages.
public enum ROLE {
    SYSTEM = "system",
    USER = "user",
    ASSISTANT = "assistant",
    FUNCTION = "function"
}

# Chat model configurations.
public type ChatModelConfig readonly & record {|
    # Model type to be used for the completion. Default is `gpt-3.5-turbo`
    string model = GPT3_5_MODEL_NAME;
    # Temperature value to be used for the completion. Default is `0.7`.
    decimal temperature = DEFAULT_TEMPERATURE;
|};

# User chat message record.
public type ChatUserMessage record {|
    # Role of the message
    USER role;
    # Content of the message
    string content;
    # An optional name for the participant
    # Provides the model information to differentiate between participants of the same role
    string name?;
|};

# System chat message record.
public type ChatSystemMessage record {|
    # Role of the message
    SYSTEM role;
    # Content of the message
    string content;
    # An optional name for the participant
    # Provides the model information to differentiate between participants of the same role
    string name?;
|};

# Assistant chat message record.
public type ChatAssistantMessage record {|
    # Role of the message
    ASSISTANT role;
    # The contents of the assistant message
    # Required unless `tool_calls` or `function_call` is specified
    string? content = ();
    # An optional name for the participant
    # Provides the model information to differentiate between participants of the same role
    string name?;
    # The function calls generated by the model, such as function calls
    FunctionCall? function_call = ();
|};

# Function message record.
public type ChatFunctionMessage record {|
    # Role of the message
    FUNCTION role;
    # Content of the message
    string? content = ();
    # Name of the function when the message is a function call
    string name;
|};

public type ChatMessage ChatUserMessage|ChatSystemMessage|ChatAssistantMessage|ChatFunctionMessage;

# Function definitions for function calling API.
public type ChatCompletionFunctions record {|
    # Name of the function
    string name;
    # Description of the function
    string description;
    # Parameters of the function
    JsonInputSchema parameters?;
|};

# Function call record
public type FunctionCall record {|
    # Name of the function
    string name;
    # Arguments of the function
    string arguments;
|};

# Represents an extendable client for interacting with an AI model.
public type Model distinct isolated client object {
    isolated remote function chat(ChatMessage[] messages, ChatCompletionFunctions[] tools = [], string? stop = ())
        returns ChatAssistantMessage[]|LlmError;
};

public isolated client class OpenAiModel {
    *Model;
    final chat:Client llmClient;
    public final ChatModelConfig modelConfig;

    # Initializes the ChatGPT model with the given connection configuration and model configuration.
    #
    # + connectionConfig - Connection Configuration for OpenAI chat client
    # + modelConfig - Model Configuration for OpenAI chat client
    # + return - Error if the model initialization fails
    public isolated function init(chat:ConnectionConfig connectionConfig, ChatModelConfig modelConfig = {}) returns Error? {
        chat:Client|error llmClient = new (connectionConfig);
        if llmClient is error {
            return error Error("Failed to initialize OpenAiModel", llmClient);
        }
        self.llmClient = llmClient;
        self.modelConfig = modelConfig;
    }

    # Uses function call API to determine next function to be called
    #
    # + messages - List of chat messages 
    # + tools - Tool definitions to be used for the tool call
    # + stop - Stop sequence to stop the completion
    # + return - Function to be called, chat response or an error in-case of failures
    isolated remote function chat(ChatMessage[] messages, ChatCompletionFunctions[] tools, string? stop = ())
            returns ChatAssistantMessage[]|LlmError {
        chat:CreateChatCompletionRequest request = {...self.modelConfig, stop, messages};
        if tools.length() > 0 {
            request.functions = tools;
        }
        chat:CreateChatCompletionResponse|error response = self.llmClient->/chat/completions.post(request);
        if response is error {
            return error LlmConnectionError("Error while connecting to the model", response);
        }
        chat:CreateChatCompletionResponse_choices[] choices = response.choices;
        ChatAssistantMessage[] chatAssistantMessages = [];
        foreach chat:CreateChatCompletionResponse_choices choice in choices {
            chat:ChatCompletionResponseMessage? message = choice.message;
            string? content = message?.content;
            if content is string {
                chatAssistantMessages.push({role: ASSISTANT, content});
            }
            chat:ChatCompletionRequestAssistantMessage_function_call? function_call = message?.function_call;
            if function_call is chat:ChatCompletionRequestAssistantMessage_function_call {
                chatAssistantMessages.push({role: ASSISTANT, function_call: {name: function_call.name, arguments: function_call.arguments}});
            }
        }
        return chatAssistantMessages.length() > 0 ? chatAssistantMessages
            : error LlmInvalidResponseError("Empty response from the model when using function call API");
    }

}

public isolated client class AzureOpenAiModel {
    *Model;
    final azure_chat:Client llmClient;
    public final ChatModelConfig modelConfig;
    private final string deploymentId;
    private final string apiVersion;

    # Initializes the ChatGPT model with the given connection configuration and model configuration.
    #
    # + connectionConfig - Connection Configuration for OpenAI chat client
    # + serviceUrl - Service URL for Azure OpenAI service
    # + deploymentId - Deployment ID for Azure OpenAI model instance
    # + apiVersion - API version for Azure OpenAI model instance
    # + modelConfig - Model Configuration for OpenAI chat client
    # + return - Error if the model initialization fails
    public isolated function init(azure_chat:ConnectionConfig connectionConfig, string serviceUrl, string deploymentId,
            string apiVersion, ChatModelConfig modelConfig = {}) returns Error? {
        azure_chat:Client|error llmClient = new (connectionConfig, serviceUrl);
        if llmClient is error {
            return error Error("Failed to initialize AzureOpenAiModel", llmClient);
        }
        self.llmClient = llmClient;
        self.modelConfig = modelConfig;
        self.deploymentId = deploymentId;
        self.apiVersion = apiVersion;
    }

    # Uses function call API to determine next function to be called
    #
    # + messages - List of chat messages 
    # + tools - Tool definitions to be used for the tool call
    # + stop - Stop sequence to stop the completion
    # + return - Function to be called, chat response or an error in-case of failures
    isolated remote function chat(ChatMessage[] messages, ChatCompletionFunctions[] tools, string? stop = ()) returns ChatAssistantMessage[]|LlmError {
        azure_chat:CreateChatCompletionRequest request = {...self.modelConfig, stop, messages};
        if tools.length() > 0 {
            request.functions = tools;
        }
        azure_chat:CreateChatCompletionResponse|error response =
            self.llmClient->/deployments/[self.deploymentId]/chat/completions.post(self.apiVersion, request);
        if response is error {
            return error LlmConnectionError("Error while connecting to the model", response);
        }

        record {|
            azure_chat:ChatCompletionResponseMessage message?;
            azure_chat:ContentFilterChoiceResults content_filter_results?;
            int index?;
            string finish_reason?;
            anydata...;
        |}[]? choices = response.choices;

        LlmInvalidResponseError invalidResponseError = error LlmInvalidResponseError("Empty response from the model when using function call API");
        if choices is () {
            return invalidResponseError;
        }
        ChatAssistantMessage[] chatAssistantMessages = [];
        foreach var choice in choices {
            azure_chat:ChatCompletionResponseMessage? message = choice.message;
            string? content = message?.content;
            if content is string {
                // check whether the model response is text
                chatAssistantMessages.push({role: ASSISTANT, content});
            }
            azure_chat:ChatCompletionFunctionCall? function_call = message?.function_call;
            if function_call is chat:ChatCompletionRequestAssistantMessage_function_call {
                chatAssistantMessages.push({role: ASSISTANT, function_call: {name: function_call.name, arguments: function_call.arguments}});
            }
        }
        return chatAssistantMessages.length() > 0 ? chatAssistantMessages
            : invalidResponseError;
    }
}
