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

// define llm client types
public type GPT3Client text:Client;

public type ChatGPTClient chat:Client;

public type LLMRemoteClient GPT3Client|ChatGPTClient;

public type GPT3Config record {|
    *text:CreateCompletionRequest;
    decimal? temperature = DEFAULT_TEMPERATURE;
    int? max_tokens = COMPLETION_TOKEN_MIN_LIMIT;
    string|string[]?? stop = OBSERVATION_KEY;
|};

public type ChatGPTConfig chat:CreateChatCompletionRequest;

public type ClientConfig GPT3Config|ChatGPTConfig;

# Extendable LLM model object that can be used for completion tasks
# Useful to initialize the agents 
# + llmClient - A remote client object to access LLM models
# + config - Required client/model configs to use the client
public type LLMModel distinct object {
    public LLMRemoteClient llmClient;
    public ClientConfig config;
    function complete(string query) returns string|error;
};

public class GPT3Model {
    *LLMModel;
    public GPT3Config config;

    public function init(GPT3Client gpt3Client, GPT3Config config) {
        self.llmClient = gpt3Client;
        config.stop = OBSERVATION_KEY;
        self.config = config;

    }

    function complete(string query) returns string|error {
        self.config.prompt = query;
        text:Client gpt3Client = check self.llmClient.ensureType();
        text:CreateCompletionResponse reponse = check gpt3Client->/completions.post(self.config);
        return reponse.choices[0].text ?: error("Empty response from the model");
    }
}
