// Copyright (c) 2023, WSO2 LLC. (http://www.wso2.com). All Rights Reserved.

// This software is the property of WSO2 LLC. and its suppliers, if any.
// Dissemination of any information or reproduction of any material contained
// herein is strictly forbidden, unless permitted by WSO2 in accordance with
// the WSO2 Commercial License available at http://wso2.com/licenses.
// For specific language governing the permissions and limitations under
// this license, please see the license as well as any agreement you’ve
// entered into with WSO2 governing the purchase of this software and any

import ballerinax/openai.text;
import ballerinax/openai.chat;

// define llm client types
public type GPT3Client text:Client;

public type ChatGPTClient chat:Client;

public type LLMRemoteClient GPT3Client|ChatGPTClient;

// define config types
type GPT3Config text:CreateCompletionRequest;

type ChatGPTConfig chat:CreateChatCompletionRequest;

public type ClientConfig GPT3Config|ChatGPTConfig;

# Extendable LLM model object that can be used for completion tasks
# Useful to initialize the agents 
# + llmClient - can be a remote client object to access LLM models
# + config - required client/model configs to use the client
public type LLMModel distinct object {
    public LLMRemoteClient llmClient;
    public ClientConfig config;
    function complete(string query) returns string|error;
};

class GPT3Model {
    *LLMModel;

    public function init(GPT3Client gpt3Client, GPT3Config config) {
        self.llmClient = gpt3Client;
        self.config = config;
    }

    function complete(string query) returns string|error {
        GPT3Config prompt = check self.config.cloneWithType();

        prompt.stop = OBSERVATION_KEY;
        if prompt.temperature == 1d {
            prompt.temperature = DEFAULT_TEMPERATURE;
        }

        int max_tokens = prompt.max_tokens ?: 0;
        prompt.max_tokens = int:max(max_tokens, COMPLETION_TOKEN_MIN_LIMIT);
        prompt.prompt = query;

        text:Client gpt3Client = check self.llmClient.ensureType();
        text:CreateCompletionResponse reponse = check gpt3Client->/completions.post(prompt);
        return reponse.choices[0].text ?: error("Empty response from the model");
    }
}
