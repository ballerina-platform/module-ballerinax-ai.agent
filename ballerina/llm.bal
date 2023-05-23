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

import ballerinax/openai.text;
import ballerinax/openai.chat;
import ballerinax/azure.openai.text as azure_text;

public type Gpt3ModelConfig readonly & record {|
    // text:CreateCompletionRequest should be included when the bug is fixed
    string model = GPT3_MODEL_NAME;
    decimal temperature = DEFAULT_TEMPERATURE;
    int max_tokens = DEFAULT_MAX_TOKEN_COUNT;
    never stop?;
    never prompt?;
|};

public type AzureGpt3ModelConfig readonly & record {|
    // azure_text:Deploymentid_completions_body should be included when the bug is fixed
    string model = GPT3_MODEL_NAME;
    decimal temperature = DEFAULT_TEMPERATURE;
    int max_tokens = DEFAULT_MAX_TOKEN_COUNT;
    never stop?;
    never prompt?;
|};

public type ChatGptModelConfig readonly & record {|
    // chat:CreateChatCompletionRequest should be included when the bug is fixed
    string model = GPT3_5_MODEL_NAME;
    decimal temperature = DEFAULT_TEMPERATURE;
    never messages?;
    never stop?;
|};

public type PromptConstruct record {|
    string instruction;
    string query;
    ExecutionStep[] history;
|};

# Extendable LLM model object that can be used for completion tasks
# Useful to initialize the agents 
public type LlmModel distinct isolated object {
    isolated function generate(PromptConstruct prompt) returns string|error;
};

public isolated class Gpt3Model {
    *LlmModel;
    final text:Client llmClient;
    private final Gpt3ModelConfig modelConfig;

    public isolated function init(text:ConnectionConfig connectionConfig, Gpt3ModelConfig modelConfig = {}) returns error? {
        self.llmClient = check new (connectionConfig);
        self.modelConfig = modelConfig;
    }

    public isolated function complete(string prompt, string? stop = ()) returns string|error {
        text:CreateCompletionRequest modelConfig = {
            ...self.modelConfig,
            stop,
            prompt
        };
        text:CreateCompletionResponse response = check self.llmClient->/completions.post(modelConfig);
        return response.choices[0].text ?: error("Empty response from the model");
    }

    isolated function generate(PromptConstruct prompt) returns string|error {
        return check self.complete(createCompletionPrompt(prompt), stop = OBSERVATION_KEY);
    }
}

public isolated class AzureGpt3Model {
    *LlmModel;
    final azure_text:Client llmClient;
    private final AzureGpt3ModelConfig modelConfig;
    private final string deploymentId;
    private final string apiVersion;

    public isolated function init(azure_text:ConnectionConfig connectionConfig, string serviceUrl, string deploymentId,
            string apiVersion, AzureGpt3ModelConfig modelConfig = {}) returns error? {
        self.llmClient = check new (connectionConfig, serviceUrl);
        self.modelConfig = modelConfig;
        self.deploymentId = deploymentId;
        self.apiVersion = apiVersion;
    }

    public isolated function complete(string prompt, string? stop = ()) returns string|error {
        azure_text:Deploymentid_completions_body modelConfig = {
            ...self.modelConfig,
            stop,
            prompt
        };
        azure_text:Inline_response_200 response = check self.llmClient->/deployments/[self.deploymentId]/completions.post(self.apiVersion, modelConfig);
        return response.choices[0].text ?: error("Empty response from the model");
    }

    isolated function generate(PromptConstruct prompt) returns string|error {
        return check self.complete(createCompletionPrompt(prompt), stop = OBSERVATION_KEY);
    }
}

public isolated class ChatGptModel {
    *LlmModel;
    final chat:Client llmClient;
    private final ChatGptModelConfig modelConfig;

    public isolated function init(chat:ConnectionConfig connectionConfig, ChatGptModelConfig modelConfig = {}) returns error? {
        self.llmClient = check new (connectionConfig);
        self.modelConfig = modelConfig;
    }

    public isolated function chatComplete(chat:ChatCompletionRequestMessage[] messages, string? stop = ()) returns string|error {
        chat:CreateChatCompletionRequest modelConfig = {
            ...self.modelConfig,
            stop,
            messages
        };
        chat:CreateChatCompletionResponse response = check self.llmClient->/chat/completions.post(modelConfig);
        chat:ChatCompletionResponseMessage? message = response.choices[0].message;
        if message is () {
            return error("Empty response from the model");
        }
        return message.content;
    }

    isolated function generate(PromptConstruct prompt) returns string|error {
        chat:ChatCompletionRequestMessage[] messages = self.createPrompt(prompt);
        return check self.chatComplete(messages, stop = OBSERVATION_KEY);
    }

    private isolated function createPrompt(PromptConstruct prompt) returns chat:ChatCompletionRequestMessage[] {
        string userMessage = "";
        if (prompt.history.length() == 0) {
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
}

isolated function createCompletionPrompt(PromptConstruct prompt) returns string {
    return string `${prompt.instruction}

Question: ${prompt.query}
${constructHistoryPrompt(prompt.history)}${THOUGHT_KEY}`;
}
