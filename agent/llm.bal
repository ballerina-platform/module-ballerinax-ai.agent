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

public type ConnectionConfig GPT3ConnectionConfig|ChatGPTConnectionConfig;

public type GPT3ModelConfig record {|
    *text:CreateCompletionRequest;
    string model = DEFAULT_MODEL_NAME;
    decimal? temperature = DEFAULT_TEMPERATURE;
    int? max_tokens = COMPLETION_TOKEN_MIN_LIMIT;
    string|string[]?? stop = OBSERVATION_KEY;
|};

public type ChatGPTModelConfig chat:CreateChatCompletionRequest;

public type ModelConfig GPT3ModelConfig|ChatGPTModelConfig;

# Extendable LLM model object that can be used for completion tasks
# Useful to initialize the agents 
# + llmClient - A remote client object to access LLM models
# + modelConfig - Required model configs to use do the completion
public type LLMModel distinct object {
    public LLMRemoteClient llmClient;
    public ModelConfig modelConfig;
    function complete(string query) returns string|error;
};

public class GPT3Model {
    *LLMModel;
    public GPT3ModelConfig modelConfig;

    public function init(GPT3ConnectionConfig connectionConfig, GPT3ModelConfig modelConfig = {}) returns error? {
        text:Client gpt3Client = check new (connectionConfig);
        self.llmClient = gpt3Client;
        modelConfig.stop = OBSERVATION_KEY;
        self.modelConfig = modelConfig;
    }

    function complete(string query) returns string|error {
        self.modelConfig.prompt = query;
        text:Client gpt3Client = check self.llmClient.ensureType();
        text:CreateCompletionResponse reponse = check gpt3Client->/completions.post(self.modelConfig);
        return reponse.choices[0].text ?: error("Empty response from the model");
    }
}
