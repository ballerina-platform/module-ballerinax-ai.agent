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

# Defines allowed LLM client types
public type LLMRemoteClient text:Client|chat:Client;

public type GPT3ConnectionConfig text:ConnectionConfig;

public type ChatGPTConnectionConfig chat:ConnectionConfig;

public type GPT3ModelConfig record {|
    *text:CreateCompletionRequest;
    string model = GPT3_MODEL_NAME;
    decimal? temperature = DEFAULT_TEMPERATURE;
    int? max_tokens = DEFAULT_MAX_TOKEN_COUNT;
    string|string[]?? stop = OBSERVATION_KEY;
|};

public type ChatGPTModelConfig record {|
    *chat:CreateChatCompletionRequest;
    string model = GPT3_5_MODEL_NAME;
    decimal? temperature = DEFAULT_TEMPERATURE;
    string|string[]?? stop = OBSERVATION_KEY;
    chat:ChatCompletionRequestMessage[] messages = [];
|};

public type ChatMessage chat:ChatCompletionRequestMessage;

type History record {|
    string thought;
    string observation;
|};

type PromptConstruct record {|
    string instruction;
    string query;
    History[] history;
|};

public type ModelConfig GPT3ModelConfig|ChatGPTModelConfig;

# Extendable LLM model object that can be used for completion tasks
# Useful to initialize the agents 
# + llmClient - A remote client object to access LLM models
# + modelConfig - Required model configs to use do the completion
public type LLMModel distinct object {
    LLMRemoteClient llmClient;
    ModelConfig modelConfig;
    function _generate(PromptConstruct prompt) returns string|error;
    // function initializePrompt(s)
};

public class GPT3Model {
    *LLMModel;
    text:Client llmClient;
    GPT3ModelConfig modelConfig;

    public function init(GPT3ConnectionConfig connectionConfig, GPT3ModelConfig modelConfig = {}) returns error? {
        self.llmClient = check new (connectionConfig);
        modelConfig.stop = OBSERVATION_KEY;
        self.modelConfig = modelConfig;
    }

    function complete(string prompt) returns string|error {
        self.modelConfig.prompt = prompt;
        text:CreateCompletionResponse response = check self.llmClient->/completions.post(self.modelConfig);
        return response.choices[0].text ?: error("Empty response from the model");
    }

    function _generate(PromptConstruct prompt) returns string|error {
        string thoughtHistory = "";
        foreach History history in prompt.history {
            thoughtHistory += string `Thought: ${history.thought}
Observation: ${history.observation}
`;
        }
        string promptStr = string `${prompt.instruction}

Question: ${prompt.query}
${thoughtHistory}Thought:`;

        return check self.complete(promptStr);

    }

}

public class ChatGPTModel {
    *LLMModel;
    chat:Client llmClient;
    ChatGPTModelConfig modelConfig;

    public function init(ChatGPTConnectionConfig connectionConfig, ChatGPTModelConfig modelConfig = {}) returns error? {
        self.llmClient = check new (connectionConfig);
        modelConfig.stop = OBSERVATION_KEY;
        self.modelConfig = modelConfig;
    }

    function chatComplete(ChatMessage[] messages) returns string|error {
        self.modelConfig.messages = messages;
        chat:CreateChatCompletionResponse response = check self.llmClient->/chat/completions.post(self.modelConfig);
        chat:ChatCompletionResponseMessage? message = response.choices[0].message;
        if message is () {
            return error("Empty response from the model");
        }
        return message.content;
    }

    function _generate(PromptConstruct prompt) returns string|error {
        string userMessage = "";
        if (prompt.history.length() == 0) {
            userMessage = prompt.query;
        }
        else {
            userMessage = string `${prompt.query}
            
This was your previous work (but I haven\'t seen any of it! I only see what you return as final answer):
            `;

            foreach History history in prompt.history {
                userMessage += string `
${history.thought}} 
Observation: ${history.observation}
Thought:`;
            }

        }

        ChatMessage[] messages = [
            {
                role: "system",
                content: prompt.instruction
            },
            {
                role: "user",
                content: userMessage
            }
        ];
        return check self.chatComplete(messages);
    }
}
