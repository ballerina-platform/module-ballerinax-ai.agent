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

import ballerina/http;
import ballerinax/azure.openai.chat as azure_chat;
import ballerinax/openai.chat;
import ballerina/uuid;
import ballerina/lang.regexp;

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

public enum DEEPSEEK_MODEL {
    DEEPSEEK_CHAT = "deepseek-chat",
    DEEPSEEK_REASONER = "deepseek-reasoner"
}

# Models for the OpenAI chat
public enum OPEN_AI_MODEL_NAMES {
    O3_MINI = "o3-mini",
    O3_MINI_2025_01_31 = "o3-mini-2025-01-31",
    O1 = "o1",
    O1_2024_12_17 = "o1-2024-12-17",
    GPT_4O = "gpt-4o",
    GPT_4O_2024_11_20 = "gpt-4o-2024-11-20",
    GPT_4O_2024_08_06 = "gpt-4o-2024-08-06",
    GPT_4O_2024_05_13 = "gpt-4o-2024-05-13",
    GPT_4O_MINI = "gpt-4o-mini",
    GPT_4O_MINI_2024_07_18 = "gpt-4o-mini-2024-07-18",
    GPT_4_TURBO = "gpt-4-turbo",
    GPT_4_TURBO_2024_04_09 = "gpt-4-turbo-2024-04-09",
    GPT_4_0125_PREVIEW = "gpt-4-0125-preview",
    GPT_4_TURBO_PREVIEW = "gpt-4-turbo-preview",
    GPT_4_1106_PREVIEW = "gpt-4-1106-preview",
    GPT_4_VISION_PREVIEW = "gpt-4-vision-preview",
    GPT_4 = "gpt-4",
    GPT_4_0314 = "gpt-4-0314",
    GPT_4_0613 = "gpt-4-0613",
    GPT_4_32K = "gpt-4-32k",
    GPT_4_32K_0314 = "gpt-4-32k-0314",
    GPT_4_32K_0613 = "gpt-4-32k-0613",
    GPT_3_5_TURBO = "gpt-3.5-turbo",
    GPT_3_5_TURBO_16K = "gpt-3.5-turbo-16k",
    GPT_3_5_TURBO_0301 = "gpt-3.5-turbo-0301",
    GPT_3_5_TURBO_0613 = "gpt-3.5-turbo-0613",
    GPT_3_5_TURBO_1106 = "gpt-3.5-turbo-1106",
    GPT_3_5_TURBO_0125 = "gpt-3.5-turbo-0125",
    GPT_3_5_TURBO_16K_0613 = "gpt-3.5-turbo-16k-0613"
}

# Provides a set of configurations for controlling the behaviours when communicating with a remote HTTP endpoint.
public type ConnectionConfig record {|
    # The HTTP version understood by the client
    http:HttpVersion httpVersion = http:HTTP_2_0;
    # Configurations related to HTTP/1.x protocol
    http:ClientHttp1Settings http1Settings?;
    # Configurations related to HTTP/2 protocol
    http:ClientHttp2Settings http2Settings?;
    # The maximum time to wait (in seconds) for a response before closing the connection
    decimal timeout = 60;
    # The choice of setting `forwarded`/`x-forwarded` header
    string forwarded = "disable";
    # Configurations associated with request pooling
    http:PoolConfiguration poolConfig?;
    # HTTP caching related configurations
    http:CacheConfig cache?;
    # Specifies the way of handling compression (`accept-encoding`) header
    http:Compression compression = http:COMPRESSION_AUTO;
    # Configurations associated with the behaviour of the Circuit Breaker
    http:CircuitBreakerConfig circuitBreaker?;
    # Configurations associated with retrying
    http:RetryConfig retryConfig?;
    # Configurations associated with inbound response size limits
    http:ResponseLimitConfigs responseLimits?;
    # SSL/TLS-related options
    http:ClientSecureSocket secureSocket?;
    # Proxy server related options
    http:ProxyConfig proxy?;
    # Enables the inbound payload validation functionality which provided by the constraint package. Enabled by default
    boolean validation = true;
|};


public type DeepseekChatResponseFunction record {
    string name;
    string arguments;
};

type DeepseekChatResponseToolCall record {
    string id;
    string 'type;
    DeepseekChatResponseFunction 'function;
};

type DeepseekChatResponseMessage record {
    string role;
    string? content = ();
    DeepseekChatResponseToolCall[]? tool_calls = ();
};

type DeepseekChatResponseChoice record {
    DeepseekChatResponseMessage message;
};

type DeepSeekChatCompletionResponse record {
    string id;
    DeepseekChatResponseChoice[] choices;
};

type DeepseekChatSystemMessage record {|
    string content;
    string role = "system";
|};

type DeepseekChatAssistantMessage record {
    string? content = ();
    string role = "assistant";
    DeepseekChatResponseToolCall[]? tool_calls = ();
};

type DeepseekChatToolMessage record {|
    string content;
    string role = "tool";
    string tool_call_id;
|};

type DeepseekChatUserMessage record {|
    string content;
    string role = "user";
|};

type DeepSeekChatRequestMessages DeepseekChatSystemMessage|DeepseekChatUserMessage|DeepseekChatAssistantMessage|DeepseekChatToolMessage;
type DeepseekFunction record {|
    string name;
    string description;
    JsonInputSchema parameters?;
|};

type DeepseekTool record {|
    string 'type = "function";
    DeepseekFunction 'function;
|};

type DeepSeekChatCompletionRequest record {|
    DeepSeekChatRequestMessages[] messages;
    DEEPSEEK_MODEL model;
    int? max_tokens;
    string|string[]? stop=();
    int? temperature = 1;
    DeepseekTool[]? tools=();
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

    string id?;
|};

# Chat message record.
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

    string id?;
|};

# Represents an extendable client for interacting with an AI model.
public type Model distinct isolated client object {
    isolated remote function chat(ChatMessage[] messages, ChatCompletionFunctions[] tools = [], string? stop = ())
        returns ChatAssistantMessage[]|LlmError;
};

# OpenAiModel is a client class that provides an interface for interacting with OpenAI language models.
public isolated client class OpenAiModel {
    *Model;
    final chat:Client llmClient;
    private final string modelType;

    # Initializes the OpenAI model with the given connection configuration and model configuration.
    #
    # + apiKey - The authentication API key for OpenAI chat  
    # + modelType - The OpenAI model name as constant from OPEN_AI_MODEL_NAMES enum  
    # + serviceUrl - The base URL for the OpenAI service endpoint  
    # + maxToken - The maximum number of tokens to generate in the response  
    # + temperature - The temperature for controlling randomness in the model's output  
    # + connectionConfig - Connection Configuration for OpenAI chat client
    # + return - Error if the model initialization fails
    public isolated function init(string apiKey, OPEN_AI_MODEL_NAMES modelType, string serviceUrl = OPENAI_SERVICE_URL,
            int maxToken = DEFAULT_MAX_TOKEN_COUNT, decimal temperature = DEFAULT_TEMPERATURE, *ConnectionConfig connectionConfig) returns Error? {
        chat:ClientHttp1Settings?|error http1Settings = connectionConfig?.http1Settings.cloneWithType();
        if http1Settings is error {
            return error Error("Failed to clone http1Settings", http1Settings);
        }
        chat:ConnectionConfig openAiConfig = {
            auth: {
                token: apiKey
            },
            httpVersion: connectionConfig.httpVersion,
            http1Settings: http1Settings,
            http2Settings: connectionConfig.http2Settings,
            timeout: connectionConfig.timeout,
            forwarded: connectionConfig.forwarded,
            poolConfig: connectionConfig.poolConfig,
            cache: connectionConfig.cache,
            compression: connectionConfig.compression,
            circuitBreaker: connectionConfig.circuitBreaker,
            retryConfig: connectionConfig.retryConfig,
            responseLimits: connectionConfig.responseLimits,
            secureSocket: connectionConfig.secureSocket,
            proxy: connectionConfig.proxy,
            validation: connectionConfig.validation
        };
        chat:Client|error llmClient = new (openAiConfig);
        if llmClient is error {
            return error Error("Failed to initialize OpenAiModel", llmClient);
        }
        self.llmClient = llmClient;
        self.modelType = modelType;
    }

    # Uses function call API to determine next function to be called
    #
    # + messages - List of chat messages 
    # + tools - Tool definitions to be used for the tool call
    # + stop - Stop sequence to stop the completion
    # + return - Function to be called, chat response or an error in-case of failures
    isolated remote function chat(ChatMessage[] messages, ChatCompletionFunctions[] tools, string? stop = ())
        returns ChatAssistantMessage[]|LlmError {
        chat:CreateChatCompletionRequest request = {model: self.modelType, stop, messages};
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

# AzureOpenAiModel is a client class that provides an interface for interacting with Azure-hosted OpenAI language models.
public isolated client class AzureOpenAiModel {
    *Model;
    final azure_chat:Client llmClient;
    private final string deploymentId;
    private final string apiVersion;

    # Initializes the Azure OpenAI model with the given connection configuration and model configuration.
    #
    # + serviceUrl - The base URL for the Azure OpenAI service endpoint  
    # + apiKey - The authentication API key for Azure OpenAI services  
    # + deploymentId - The deployment identifier for the specific model deployment in Azure  
    # + apiVersion - The Azure OpenAI API version to use for requests (e.g., "2023-05-15")  
    # + maxToken - The maximum number of tokens to generate in the response  
    # + temperature - The temperature for controlling randomness in the model's output  
    # + connectionConfig - Optional connection configuration parameters (defaults to basic auth with apiKey)
    # + return - Error if the model initialization fails
    public isolated function init(string serviceUrl, string apiKey, string deploymentId, string apiVersion,
            int maxToken = DEFAULT_MAX_TOKEN_COUNT, decimal temperature = DEFAULT_TEMPERATURE,
            *ConnectionConfig connectionConfig) returns Error? {

        azure_chat:ClientHttp1Settings?|error http1Settings = connectionConfig?.http1Settings.cloneWithType();
        if http1Settings is error {
            return error Error("Failed to clone http1Settings", http1Settings);
        }
        // Merge your local connection config with the required auth config
        azure_chat:ConnectionConfig azureAiConfig = {
            auth: {apiKey},
            httpVersion: connectionConfig.httpVersion,
            http1Settings: http1Settings,
            http2Settings: connectionConfig.http2Settings,
            timeout: connectionConfig.timeout,
            forwarded: connectionConfig.forwarded,
            poolConfig: connectionConfig.poolConfig,
            cache: connectionConfig.cache,
            compression: connectionConfig.compression,
            circuitBreaker: connectionConfig.circuitBreaker,
            retryConfig: connectionConfig.retryConfig,
            responseLimits: connectionConfig.responseLimits,
            secureSocket: connectionConfig.secureSocket,
            proxy: connectionConfig.proxy,
            validation: connectionConfig.validation
        };
        azure_chat:Client|error llmClient = new (azureAiConfig, serviceUrl);
        if llmClient is error {
            return error Error("Failed to initialize AzureOpenAiModel", llmClient);
        }
        self.llmClient = llmClient;
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
        azure_chat:CreateChatCompletionRequest request = {stop, messages};
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


public isolated client class DeepseekModel {
    *Model;
    private final http:Client deepseekClient;
    private final int maxTokens;
    private final DEEPSEEK_MODEL model; 

    public isolated function init(string apiKey, DEEPSEEK_MODEL model, int maxTokens=DEFAULT_MAX_TOKEN_COUNT, decimal temperateure = DEFAULT_TEMPERATURE, string serviceUrl= DEEPSEEK_SERVICE_URL ,*ConnectionConfig connectionConfig) returns Error?{
        
        http:ClientConfiguration deepseekConfig  = {
            auth: {
                token: apiKey
            },
            httpVersion: connectionConfig.httpVersion,
            http1Settings: connectionConfig.http1Settings ?: {},
            http2Settings: connectionConfig?.http2Settings ?: {},
            timeout: connectionConfig.timeout,
            forwarded: connectionConfig.forwarded,
            poolConfig: connectionConfig?.poolConfig,
            cache: connectionConfig?.cache ?: {},
            compression: connectionConfig.compression,
            circuitBreaker: connectionConfig?.circuitBreaker,
            retryConfig: connectionConfig?.retryConfig,
            responseLimits: connectionConfig?.responseLimits ?: {},
            secureSocket: connectionConfig?.secureSocket,
            proxy: connectionConfig?.proxy,
            validation: connectionConfig.validation
        };

        http:Client|error httpClient = new http:Client(serviceUrl, deepseekConfig);    

        if (httpClient is error) {
            return error Error("Failed to initialize Deepseek client", httpClient);
        }

        self.maxTokens = maxTokens;
        self.model = model;
        self.deepseekClient = httpClient;
    }

    isolated remote function chat(ChatMessage[] messages, ChatCompletionFunctions[] tools, string? stop = ()) returns ChatAssistantMessage[]|LlmError {
        DeepSeekChatRequestMessages[] deepseekPayloadMessages = [];
        
        foreach ChatMessage message in messages {
            if message is ChatUserMessage {
                DeepseekChatUserMessage|error deepseekUserMessage =  message.cloneWithType();
                if deepseekUserMessage is error {
                    return error LlmError("Failed to convert user message to MistralMessage", deepseekUserMessage);
                }
                deepseekPayloadMessages.push(deepseekUserMessage);
            } else if message is ChatSystemMessage {
                DeepseekChatSystemMessage|error deepseekSysteMessage = message.cloneWithType();
                if deepseekSysteMessage is error {
                    return error LlmError("Failed to convert user message to MistralMessage", deepseekSysteMessage);
                } 
                deepseekPayloadMessages.push(deepseekSysteMessage);
            } else if message is ChatAssistantMessage {
                DeepseekChatResponseFunction functionCall = {
                    name: message.function_call is FunctionCall ? message.function_call?.name ?: "" : "",
                    arguments: message.function_call is FunctionCall ? message.function_call?.arguments ?: "" : ""
                };

                DeepseekChatResponseToolCall[] tool_calls = [{'function: functionCall, id:message.function_call?.id ?: self.generateToolId(), 'type: "function"}];
                DeepseekChatAssistantMessage deepseekAssistantMessage = {
                    role: "assistant",
                    content: message.content,
                    tool_calls: tool_calls
                };

                // DeepseekChatAssistantMessage deepseekAssistantMessage = {
                //     role: "assistant"
                // };
                // if message.content is string {
                //     deepseekAssistantMessage.content = message.content;
                // } else {
                //     deepseekAssistantMessage.content = string `{name: ${message?.function_call?.name ?: ""}, arguments: ${message?.function_call?.arguments ?: ""}}`;
                // }
                deepseekPayloadMessages.push(deepseekAssistantMessage);
            } else if message is ChatFunctionMessage {
                DeepseekChatToolMessage deepseekToolMessage = {
                    role: "tool",
                    content: message?.content ?: "",
                    tool_call_id: message.id ?: self.generateToolId()
                };
                deepseekPayloadMessages.push(deepseekToolMessage);
            }
        }

       
        DeepSeekChatCompletionRequest request = {
            // messages: from var message in messages 
            //     select message.role == "function" ? 
            //         {role: "tool", content: message.content, "tool_call_id": (<ChatFunctionMessage>message).id ?: "hsdfbc"} : 
            //         {role: message.role, content: message.content},
            messages:deepseekPayloadMessages,
            model: self.model,
            max_tokens: self.maxTokens,
            stop: stop
        };


        //io:println("Request: ", request);

        if tools.length() > 0 {
            DeepseekFunction[] deepseekFunctions = [];
            foreach ChatCompletionFunctions toolFunction in tools {
                DeepseekFunction deepseekFunction = {
                    name: toolFunction.name,
                    description: toolFunction.description,
                    parameters: toolFunction.parameters ?: {}
                };
                deepseekFunctions.push(deepseekFunction);
            }

            DeepseekTool[] deepseekTools = [];
            foreach DeepseekFunction deepseekFunction in deepseekFunctions {
                DeepseekTool deepseekTool = {'function: deepseekFunction};
                deepseekTools.push(deepseekTool);
            }
            request.tools = deepseekTools;
        }

        DeepSeekChatCompletionResponse|error response = self.deepseekClient->/chat/completions.post(request);
        if response is error{
            return error LlmConnectionError("Error while connecting to the model", response);
        }

        DeepseekChatResponseChoice[] choices = response.choices;
        
        ChatAssistantMessage[] chatAssistantMessages = [];
        foreach DeepseekChatResponseChoice choice in choices {
            DeepseekChatResponseMessage message = choice.message;
            string? content = message?.content;
            if content is string && content != "" {
                chatAssistantMessages.push({role: ASSISTANT, content:content});
                break;
            }
            DeepseekChatResponseToolCall[]? toolCalls = message?.tool_calls;
            if toolCalls !is () {
                foreach DeepseekChatResponseToolCall toolCall in toolCalls {
                    chatAssistantMessages.push({role: ASSISTANT, function_call: {name: toolCall.'function.name, id: toolCall.id, arguments: toolCall.'function.arguments.toString()}});
                }
            }
            break;
        }
        return chatAssistantMessages.length() > 0 ? chatAssistantMessages
            : error LlmInvalidResponseError("Empty response from the model when using function call API");
    }

    private isolated function generateToolId() returns string {
        string randomToolID = "";
        string randomId = uuid:createRandomUuid();
        regexp:RegExp alphanumericPattern = re `[a-zA-Z0-9]`;
        int iterationCount = 0;

        foreach string character in randomId {
            if (alphanumericPattern.isFullMatch(character)) {
                randomToolID = randomToolID + character;
                iterationCount = iterationCount + 1;
            }
            if (iterationCount == 9) {
                break;
            }
        }
        return randomToolID;
    }
}