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

import ballerinax/azure.openai.chat as azure_chat;
import ballerinax/azure.openai.text as azure_text;
import ballerinax/openai.chat;
import ballerinax/openai.text;

// TODO: change the configs to extend the config record from the respective clients.
// requirs using never prompt?; never stop? to prevent setting those during initialization
// change once https://github.com/ballerina-platform/ballerina-lang/issues/32012 is fixed

# Completion model configurations.
public type CompletionModelConfig readonly & record {|
    # Model type to be used for the completion. Default is `davinci`.
    string model = GPT3_MODEL_NAME;
    # Temperature value to be used for the completion. Default is `0.7`.
    decimal temperature = DEFAULT_TEMPERATURE;
    # Maximum number of tokens to be generated for the completion. Default is `512`.
    int max_tokens = DEFAULT_MAX_TOKEN_COUNT;
|};

# Roles for the chat messages.
public enum ROLE {
    SYSTEM_ROLE = "system",
    USER_ROLE = "user"
}

# Chat message record
public type ChatMessage record {|
    # Role of the message
    ROLE role;
    # Content of the message
    string content;
|};

# Chat model configurations.
public type ChatModelConfig readonly & record {|
    # Model type to be used for the completion. Default is `gpt-3.5-turbo`
    string model = GPT3_5_MODEL_NAME;
    # Temperature value to be used for the completion. Default is `0.7`.
    decimal temperature = DEFAULT_TEMPERATURE;
|};

type PromptConstruct record {|
    string instruction;
    string query;
    ExecutionStep[] history;
|};

# Extendable LLM model object that can be used for completion tasks.
# Useful to initialize the agents.
public type LlmModel distinct isolated object {
    isolated function generate(PromptConstruct prompt) returns string|error;
};

public type CompletionLlmModel distinct isolated object {
    *LlmModel;
    CompletionModelConfig modelConfig;
    public isolated function complete(string prompt, string? stop = ()) returns string|error;
};

public type ChatLlmModel distinct isolated object {
    *LlmModel;
    ChatModelConfig modelConfig;
    public isolated function chatComplete(ChatMessage[] messages, string? stop = ()) returns string|error;
};

public isolated class Gpt3Model {
    *CompletionLlmModel;
    final text:Client llmClient;
    final CompletionModelConfig modelConfig;

    # Initializes the GPT-3 model with the given connection configuration and model configuration.
    #
    # + connectionConfig - Connection Configuration for OpenAI text client 
    # + modelConfig - Model Configuration for OpenAI text client
    # + return - Error if the model initialization fails
    public isolated function init(text:ConnectionConfig connectionConfig, CompletionModelConfig modelConfig = {}) returns error? {
        self.llmClient = check new (connectionConfig);
        self.modelConfig = modelConfig;
    }

    # Completes the given prompt using the GPT3 model.
    #
    # + prompt - Prompt to be completed
    # + stop - Stop sequence to stop the completion
    # + return - Completed prompt or error if the completion fails
    public isolated function complete(string prompt, string? stop = ()) returns string|error {
        text:CreateCompletionResponse response = check self.llmClient->/completions.post({
            ...self.modelConfig,
            stop,
            prompt
        });
        return response.choices[0].text ?: error("Empty response from the model");
    }

    isolated function generate(PromptConstruct prompt) returns string|error {
        return check self.complete(createCompletionPrompt(prompt), stop = OBSERVATION_KEY);
    }
}

public isolated class AzureGpt3Model {
    *CompletionLlmModel;
    final azure_text:Client llmClient;
    final CompletionModelConfig modelConfig;
    private final string deploymentId;
    private final string apiVersion;

    # Initializes the GPT-3 model with the given connection configuration and model configuration.
    #
    # + connectionConfig - Connection Configuration for Azure OpenAI text client
    # + serviceUrl - Service URL for Azure OpenAI service
    # + deploymentId - Deployment ID for Azure OpenAI model instance
    # + apiVersion - API version for Azure OpenAI model instance
    # + modelConfig - Model Configuration for Azure OpenAI text client
    # + return - Error if the model initialization fails
    public isolated function init(azure_text:ConnectionConfig connectionConfig, string serviceUrl, string deploymentId,
            string apiVersion, CompletionModelConfig modelConfig = {}) returns error? {
        self.llmClient = check new (connectionConfig, serviceUrl);
        self.modelConfig = modelConfig;
        self.deploymentId = deploymentId;
        self.apiVersion = apiVersion;
    }

    # Completes the given prompt using the GPT3 model.
    #
    # + prompt - Prompt to be completed
    # + stop - Stop sequence to stop the completion
    # + return - Completed prompt or error if the completion fails
    public isolated function complete(string prompt, string? stop = ()) returns string|error {
        azure_text:Inline_response_200 response = check self.llmClient->/deployments/[self.deploymentId]/completions.post(self.apiVersion, {
            ...self.modelConfig,
            stop,
            prompt
        });
        return response.choices[0].text ?: error("Empty response from the model");
    }

    isolated function generate(PromptConstruct prompt) returns string|error {
        return check self.complete(createCompletionPrompt(prompt), stop = OBSERVATION_KEY);
    }
}

public isolated class ChatGptModel {
    *ChatLlmModel;
    final chat:Client llmClient;
    final ChatModelConfig modelConfig;

    # Initializes the ChatGPT model with the given connection configuration and model configuration.
    #
    # + connectionConfig - Connection Configuration for OpenAI chat client
    # + modelConfig - Model Configuration for OpenAI chat client
    # + return - Error if the model initialization fails
    public isolated function init(chat:ConnectionConfig connectionConfig, ChatModelConfig modelConfig = {}) returns error? {
        self.llmClient = check new (connectionConfig);
        self.modelConfig = modelConfig;
    }

    # Completes the given prompt using the ChatGPT model.
    #
    # + messages - Messages to be completed
    # + stop - Stop sequence to stop the completion
    # + return - Completed message or error if the completion fails
    public isolated function chatComplete(ChatMessage[] messages, string? stop = ()) returns string|error {
        chat:CreateChatCompletionResponse response = check self.llmClient->/chat/completions.post({
            ...self.modelConfig,
            stop,
            messages
        });
        chat:ChatCompletionResponseMessage? message = response.choices[0].message;
        string? content = message?.content;
        return content ?: error("Empty response from the model");
    }

    isolated function generate(PromptConstruct prompt) returns string|error {
        ChatMessage[] messages = createChatPrompt(prompt);
        return check self.chatComplete(messages, stop = OBSERVATION_KEY);
    }
}

public isolated class AzureChatGptModel {
    *ChatLlmModel;
    final azure_chat:Client llmClient;
    final ChatModelConfig modelConfig;
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
            string apiVersion, ChatModelConfig modelConfig) returns error? {
        self.llmClient = check new (connectionConfig, serviceUrl);
        self.modelConfig = modelConfig;
        self.deploymentId = deploymentId;
        self.apiVersion = apiVersion;
    }

    # Completes the given prompt using the ChatGPT model.
    #
    # + messages - Messages to be completed
    # + stop - Stop sequence to stop the completion
    # + return - Completed message or error if the completion fails
    public isolated function chatComplete(ChatMessage[] messages, string? stop = ()) returns string|error {
        azure_chat:Inline_response_200 response = check self.llmClient->/deployments/[self.deploymentId]/chat/completions.post(self.apiVersion, {
            ...self.modelConfig,
            stop,
            messages
        });
        chat:ChatCompletionResponseMessage? message = response.choices[0].message;
        string? content = message?.content;
        return content ?: error("Empty response from the model");
    }

    isolated function generate(PromptConstruct prompt) returns string|error {
        ChatMessage[] messages = createChatPrompt(prompt);
        return check self.chatComplete(messages, stop = OBSERVATION_KEY);
    }
}

isolated function createCompletionPrompt(PromptConstruct prompt) returns string => string
`${prompt.instruction}${"\n\n"}Question: ${prompt.query}${"\n"}${constructHistoryPrompt(prompt.history)}${THOUGHT_KEY}`;

isolated function createChatPrompt(PromptConstruct prompt) returns ChatMessage[] {
    string userMessage = "";
    if prompt.history.length() == 0 {
        userMessage = prompt.query;
    }
    else {
        userMessage = string `${prompt.query}${"\n\n"}This was your previous work (but I haven\'t seen any of it! I only see what you return as final answer):${"\n"}`;
        userMessage += constructHistoryPrompt(prompt.history);
    }
    userMessage += ("\n" + THOUGHT_KEY);
    return [
        {
            role: SYSTEM_ROLE,
            content: prompt.instruction
        },
        {
            role: USER_ROLE,
            content: userMessage
        }
    ];
}
