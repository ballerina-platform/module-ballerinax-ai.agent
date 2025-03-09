// Copyright (c) 2025 WSO2 LLC (http://www.wso2.com).
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

import ballerina/data.jsondata;
import ballerina/http;

# Represents the model parameters for Ollama text generation.
# These parameters control the behavior and output of the model.
public type OllamaModelParameters record {|
    # Enable Mirostat sampling for controlling perplexity.  
    # - `0` = disabled  
    # - `1` = Mirostat  
    # - `2` = Mirostat 2.0  
    0|1|2 mirostat = 0;

    # Influences how quickly the algorithm responds to feedback from the generated text.  
    # A lower value results in slower adjustments, while a higher value makes the model more responsive.  
    @jsondata:Name {value: "mirostat_eta"}
    float mirostatEta = 0.1;

    # Controls the balance between coherence and diversity of the output.  
    # A lower value results in more focused and coherent text.  
    @jsondata:Name {value: "mirostat_tau"}
    float mirostatTau = 5.0;

    # Sets the size of the context window used to generate the next token.  
    @jsondata:Name {value: "num_ctx"}
    int numCtx = 2048;

    # Sets how far back the model should look to prevent repetition.  
    # - `0` = disabled  
    # - `-1` = num_ctx  
    @jsondata:Name {value: "repeat_last_n"}
    int repeatLastN = 64;

    # Sets how strongly to penalize repetitions.  
    # A higher value (e.g., `1.5`) will penalize repetitions more strongly,  
    # while a lower value (e.g., `0.9`) will be more lenient.  
    @jsondata:Name {value: "repeat_penalty"}
    float repeatPenalty = 1.1;

    # Controls the creativity of the model's responses.  
    # A higher value makes the output more diverse, while a lower value makes it more focused.  
    float temperature = 0.8;

    # Sets the random number seed for deterministic text generation.  
    # A specific value ensures the same output for identical prompts.  
    int seed = 0;

    # Maximum number of tokens to generate.  
    # `-1` allows infinite generation.  
    @jsondata:Name {value: "num_predict"}
    int numPredict = -1;

    # Controls randomness by selecting the top-k most likely next words.  
    # A higher value (e.g., `100`) increases diversity,  
    # while a lower value (e.g., `10`) makes responses more conservative.  
    @jsondata:Name {value: "top_k"}
    int topK = 40;

    # Controls randomness by considering the cumulative probability of choices.  
    # A higher value (e.g., `0.95`) increases diversity,  
    # while a lower value (e.g., `0.5`) makes responses more conservative.  
    @jsondata:Name {value: "top_p"}
    float topP = 0.9;

    # Ensures a balance between quality and variety.  
    # Filters out low-probability tokens relative to the highest probability token.  
    @jsondata:Name {value: "min_p"}
    float minP = 0.0;
|};

type OllamaResponse record {
    string model;
    OllamaMessage message;
};

type OllamaMessage record {
    string role;
    string content;
    OllamaToolCall[] tool_calls?;
};

type OllamaToolCall record {
    OllamaFunction 'function;
};

type OllamaFunction record {
    string name;
    map<json> arguments;
};

const OLLAMA_TOOL_ROLE = "tool";
const OLLAMA_FUNCTION_TYPE = "function";

public isolated client class OllamaModel {
    *Model;
    private final http:Client ollamaClient;
    private final string modelType;
    private final readonly & map<json> modleParameters;

    public isolated function init(string serviceUrl, string modelType, *OllamaModelParameters modleParameters,
            *ConnectionConfig connectionConfig) returns Error? {
        http:ClientConfiguration clientConfig = {...connectionConfig};
        http:Client|error ollamaClient = new (serviceUrl, clientConfig);
        if ollamaClient is error {
            return error Error("Error while connecting to the model", ollamaClient);
        }
        self.modleParameters = check getModelParameterMap(modleParameters);
        self.ollamaClient = ollamaClient;
        self.modelType = modelType;
    }

    isolated remote function chat(ChatMessage[] messages, ChatCompletionFunctions[] tools = [], string? stop = ())
        returns ChatAssistantMessage[]|LlmError {
        // Ollama chat completion API reference: https://github.com/ollama/ollama/blob/main/docs/api.md#generate-a-chat-completion
        json requestPayload = self.prepareRequestPayload(messages, tools, stop);
        OllamaResponse|error response = self.ollamaClient->/api/chat.post(requestPayload);
        if response is error {
            return error LlmConnectionError("Error while connecting to ollama", response);
        }
        return self.mapOllamaResponseToAssistantMessages(response);
    }

    private isolated function prepareRequestPayload(ChatMessage[] messages, ChatCompletionFunctions[] tools, string? stop)
        returns json {
        json[] transformedMessages = messages.'map(isolated function(ChatMessage message) returns json {
            if message is ChatFunctionMessage {
                return {role: OLLAMA_TOOL_ROLE, content: message?.content};
            }
            return message;
        });

        map<json> options = self.modleParameters.clone();
        options["stop"] = stop;

        return {
            model: self.modelType,
            messages: transformedMessages,
            'stream: false,
            tools: tools.'map(tool => {'type: OLLAMA_FUNCTION_TYPE, 'function: tool}),
            options
        };
    }

    private isolated function mapOllamaResponseToAssistantMessages(OllamaResponse response)
        returns ChatAssistantMessage[] {
        OllamaToolCall[]? toolCalls = response.message?.tool_calls;
        if toolCalls is OllamaToolCall[] {
            return self.mapToolCallsToAssistantMessages(toolCalls);
        }
        return [{role: ASSISTANT, content: response.message.content}];
    }

    private isolated function mapToolCallsToAssistantMessages(OllamaToolCall[] toolCalls)
        returns ChatAssistantMessage[] {
        return from OllamaToolCall toolCall in toolCalls
            select {
                role: ASSISTANT,
                function_call: {
                    name: toolCall.'function.name,
                    arguments: toolCall.'function.arguments.toJsonString()
                }
            };
    }
}

isolated function getModelParameterMap(OllamaModelParameters modleParameters) returns readonly & map<json>|Error {
    do {
        json options = jsondata:toJson(modleParameters);
        map<json> & readonly readonlyOptions = check options.cloneWithType();
        return readonlyOptions;
    } on fail error e {
        return error Error("Error while processing model parameters", e);
    }
}
