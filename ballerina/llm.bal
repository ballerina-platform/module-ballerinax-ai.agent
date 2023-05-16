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

public type Gpt3ConnectionConfig text:ConnectionConfig;

public type ChatGptConnectionConfig chat:ConnectionConfig;

public type Gpt3ModelConfig readonly & record {|
    string model = GPT3_MODEL_NAME;
    decimal temperature = DEFAULT_TEMPERATURE;
    int max_tokens = DEFAULT_MAX_TOKEN_COUNT;
    never stop?;
    never prompt?;
|};

public type ChatGptModelConfig readonly & record {|
    string model = GPT3_5_MODEL_NAME;
    decimal temperature = DEFAULT_TEMPERATURE;
    never messages?;
    never stop?;
|};

public type ChatMessage chat:ChatCompletionRequestMessage;

public type PromptConstruct record {|
    string instruction;
    string query;
    string[] history;
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

    public isolated function init(Gpt3ConnectionConfig connectionConfig, Gpt3ModelConfig modelConfig = {}) returns error? {
        self.llmClient = check new (connectionConfig);
        self.modelConfig = modelConfig;
    }

    public isolated function complete(string prompt) returns string|error {
        text:CreateCompletionRequest modelConfig = {
            ...self.modelConfig,
            stop: OBSERVATION_KEY,
            prompt
        };
        text:CreateCompletionResponse response = check self.llmClient->/completions.post(modelConfig);
        return response.choices[0].text ?: error("Empty response from the model");
    }

    isolated function generate(PromptConstruct prompt) returns string|error {
        string thoughtHistory = "";
        thoughtHistory += <string>from string history in prompt.history
            select history + "\n";
        string promptStr = string `${prompt.instruction}

Question: ${prompt.query}
${thoughtHistory}${THOUGHT_KEY}`;

        return check self.complete(promptStr);

    }

}

public isolated class ChatGptModel {
    *LlmModel;
    final chat:Client llmClient;
    private final ChatGptModelConfig modelConfig;

    public isolated function init(ChatGptConnectionConfig connectionConfig, ChatGptModelConfig modelConfig = {}) returns error? {
        self.llmClient = check new (connectionConfig);
        self.modelConfig = modelConfig;
    }

    public isolated function chatComplete(ChatMessage[] messages) returns string|error {
        chat:CreateChatCompletionRequest modelConfig = {
            ...self.modelConfig,
            stop: OBSERVATION_KEY,
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
        string userMessage = "";
        if (prompt.history.length() == 0) {
            userMessage = prompt.query;
        }
        else {
            userMessage = string `${prompt.query}
            
This was your previous work (but I haven\'t seen any of it! I only see what you return as final answer):
`;
            userMessage += <string>from string history in prompt.history
                select history + "\n";
        }
        userMessage += ("\n" + THOUGHT_KEY);

        ChatMessage[] messages = [
            {
                role: SYSTEM_ROLE,
                content: prompt.instruction
            },
            {
                role: USER_ROLE,
                content: userMessage
            }
        ];
        return check self.chatComplete(messages);
    }
}
