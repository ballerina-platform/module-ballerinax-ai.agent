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

import ai.agent.mistral;

import ballerina/http;
import ballerina/lang.regexp;
import ballerina/uuid;
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

# Model types for OpenAI
@display {label: "OpenAI Model Names"}
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

# Models types for Anthropic
@display {label: "Anthropic Model Names"}
public enum ANTHROPIC_MODEL_NAMES {
    CLAUDE_3_7_SONNET_20250219 = "claude-3-7-sonnet-20250219",
    CLAUDE_3_5_HAIKU_20241022 = "claude-3-5-haiku-20241022",
    CLAUDE_3_5_SONNET_20241022 = "claude-3-5-sonnet-20241022",
    CLAUDE_3_5_SONNET_20240620 = "claude-3-5-sonnet-20240620",
    CLAUDE_3_OPUS_20240229 = "claude-3-opus-20240229",
    CLAUDE_3_SONNET_20240229 = "claude-3-sonnet-20240229",
    CLAUDE_3_HAIKU_20240307 = "claude-3-haiku-20240307"
}

# Models types for Mistral AI
@display {label: "Mistral AI Model Names"}
public enum MISTRAL_AI_MODEL_NAMES {
    MINISTRAL_3B_2410 = "ministral-3b-2410",
    MINISTRAL_8B_2410 = "ministral-8b-2410",
    OPEN_MISTRAL_7B = "open-mistral-7b",
    OPEN_MISTRAL_NEMO = "open-mistral-nemo",
    OPEN_MIXTRAL_8X7B = "open-mixtral-8x7b",
    OPEN_MIXTRAL_8X22B = "open-mixtral-8x22b",
    MISTRAL_SMALL_2402 = "mistral-small-2402",
    MISTRAL_SMALL_2409 = "mistral-small-2409",
    MISTRAL_SMALL_2501 = "mistral-small-2501",
    MISTRAL_MEDIUM_2312 = "mistral-medium-2312",
    MISTRAL_LARGE_2402 = "mistral-large-2402",
    MISTRAL_LARGE_2407 = "mistral-large-2407",
    MISTRAL_LARGE_2411 = "mistral-large-2411",
    PIXTRAL_LARGE_2411 = "pixtral-large-2411",
    CODESTRAL_2405 = "codestral-2405",
    CODESTRAL_2501 = "codestral-2501",
    CODESTRAL_MAMBA_2407 = "codestral-mamba-2407",
    PIXTRAL_12B_2409 = "pixtral-12b-2409",
    MISTRAL_SABA_2502 = "mistral-saba-2502",
    MISTRAL_SMALL_MODEL = "mistral-small-latest",
    MISTRAL_MEDIUM_MODEL = "mistral-medium-latest",
    MISTRAL_LARGE_MODEL = "mistral-large-latest"
}

# Configurations for controlling the behaviours when communicating with a remote HTTP endpoint.
@display {label: "Connection Configuration"}
public type ConnectionConfig record {|

    # The HTTP version understood by the client
    @display {label: "HTTP Version"}
    http:HttpVersion httpVersion = http:HTTP_2_0;

    # Configurations related to HTTP/1.x protocol
    @display {label: "HTTP1 Settings"}
    http:ClientHttp1Settings http1Settings?;

    # Configurations related to HTTP/2 protocol
    @display {label: "HTTP2 Settings"}
    http:ClientHttp2Settings http2Settings?;

    # The maximum time to wait (in seconds) for a response before closing the connection
    @display {label: "Timeout"}
    decimal timeout = 60;

    # The choice of setting `forwarded`/`x-forwarded` header
    @display {label: "Forwarded"}
    string forwarded = "disable";

    # Configurations associated with request pooling
    @display {label: "Pool Configuration"}
    http:PoolConfiguration poolConfig?;

    # HTTP caching related configurations
    @display {label: "Cache Configuration"}
    http:CacheConfig cache?;

    # Specifies the way of handling compression (`accept-encoding`) header
    @display {label: "Compression"}
    http:Compression compression = http:COMPRESSION_AUTO;

    # Configurations associated with the behaviour of the Circuit Breaker
    @display {label: "Circuit Breaker Configuration"}
    http:CircuitBreakerConfig circuitBreaker?;

    # Configurations associated with retrying
    @display {label: "Retry Configuration"}
    http:RetryConfig retryConfig?;

    # Configurations associated with inbound response size limits
    @display {label: "Response Limit Configuration"}
    http:ResponseLimitConfigs responseLimits?;

    # SSL/TLS-related options
    @display {label: "Secure Socket Configuration"}
    http:ClientSecureSocket secureSocket?;

    # Proxy server related options
    @display {label: "Proxy Configuration"}
    http:ProxyConfig proxy?;

    # Enables the inbound payload validation functionality which provided by the constraint package. Enabled by default
    @display {label: "Payload Validation"}
    boolean validation = true;
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
    FunctionCall[]? toolCalls = ();
|};

# Function message record.
public type ChatFunctionMessage record {|
    # Role of the message
    FUNCTION role;
    # Content of the message
    string? content = ();
    # Name of the function when the message is a function call
    string name;
    # Identifier for the tool call
    string id?;
|};

# Chat message record.
public type ChatMessage ChatUserMessage|ChatSystemMessage|ChatAssistantMessage|ChatFunctionMessage;

# Mistral message record.
type MistralMessages mistral:AssistantMessage|mistral:SystemMessage|mistral:UserMessage|mistral:ToolMessage;

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
    # Identifier for the tool call
    string id?;
|};

# Anthropic API request message format
type AnthropicMessage record {|
    # Role of the participant in the conversation (e.g., "user" or "assistant")
    string role;
    # The message content
    string content;
|};

# Anthropic API response format
type AnthropicApiResponse record {|
    # Unique identifier for the response message
    string id;
    # The Anthropic model used for generating the response
    string model;
    # The type of the response (e.g., "message")
    string 'type;
    # Array of content blocks containing the response text and media
    ContentBlock[] content;
    # Role of the message sender (typically "assistant")
    string role;
    # Reason why the generation stopped (e.g., "end_turn", "max_tokens")
    string stop_reason;
    # The sequence that caused generation to stop, if applicable
    string? stop_sequence;
    # Token usage statistics for the request and response
    Usage usage;
|};

# Content block in Anthropic API response
type ContentBlock record {|
    # The type of content (e.g., "text" or "tool_use")
    string 'type;
    # The actual text content (for text type)
    string text?;
    # Tool use information (for tool_use type)
    string id?;
    # Name of the tool being used
    string name?;
    # Input parameters for the tool
    json input?;
|};

# Usage statistics in Anthropic API response
type Usage record {|
    # Number of tokens in the input messages
    int input_tokens;
    # Number of tokens in the generated response
    int output_tokens;
    # Number of input tokens used for cache creation, if applicable
    int? cache_creation_input_tokens = ();
    # Number of input tokens read from cache, if applicable
    int? cache_read_input_tokens = ();
|};

# Anthropic Tool definition
type AnthropicTool record {|
    # Name of the tool
    string name;
    # Description of the tool
    string description;
    # Input schema of the tool in JSON Schema format
    json input_schema;
|};

# Represents an extendable client for interacting with an AI model.
public type Model distinct isolated client object {
    # Sends a chat request to the model with the given messages and tools.
    # + messages - List of chat messages 
    # + tools - Tool definitions to be used for the tool call
    # + stop - Stop sequence to stop the completion
    # + return - Function to be called, chat response or an error in-case of failures
    isolated remote function chat(ChatMessage[] messages, ChatCompletionFunctions[] tools = [], string? stop = ())
        returns ChatAssistantMessage|LlmError;
};

# OpenAiModel is a client class that provides an interface for interacting with OpenAI language models.
public isolated client class OpenAiModel {
    *Model;
    private final chat:Client llmClient;
    private final string modelType;

    # Initializes the OpenAI model with the given connection configuration and model configuration.
    #
    # + apiKey - The OpenAI API key
    # + modelType - The OpenAI model name
    # + serviceUrl - The base URL of OpenAI API endpoint
    # + maxTokens - The upper limit for the number of tokens in the response generated by the model
    # + temperature - The temperature for controlling randomness in the model's output  
    # + connectionConfig - Additional HTTP connection configuration
    # + return - `nil` on successful initialization; otherwise, returns an `Error`
    public isolated function init(@display {label: "API Key"} string apiKey,
            @display {label: "Model Type"} OPEN_AI_MODEL_NAMES modelType,
            @display {label: "Service URL"} string serviceUrl = OPENAI_SERVICE_URL,
            @display {label: "Maximum Tokens"} int maxTokens = DEFAULT_MAX_TOKEN_COUNT,
            @display {label: "Temperature"} decimal temperature = DEFAULT_TEMPERATURE,
            @display {label: "Connection Configuration"} *ConnectionConfig connectionConfig) returns Error? {
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

    # Sends a chat request to the OpenAI model with the given messages and tools.
    #
    # + messages - List of chat messages 
    # + tools - Tool definitions to be used for the tool call
    # + stop - Stop sequence to stop the completion
    # + return - Function to be called, chat response or an error in-case of failures
    isolated remote function chat(ChatMessage[] messages, ChatCompletionFunctions[] tools, string? stop = ())
        returns ChatAssistantMessage|LlmError {
        chat:CreateChatCompletionRequest request = {
            stop,
            model: self.modelType,
            messages: self.mapToChatCompletionRequestMessage(messages)
        };
        if tools.length() > 0 {
            request.functions = tools;
        }
        chat:CreateChatCompletionResponse|error response = self.llmClient->/chat/completions.post(request);
        if response is error {
            return error LlmConnectionError("Error while connecting to the model", response);
        }
        chat:CreateChatCompletionResponse_choices[] choices = response.choices;
        if choices.length() == 0 {
            return error LlmInvalidResponseError("Empty response from the model when using function call API");
        }
        chat:ChatCompletionResponseMessage? message = choices[0].message;
        ChatAssistantMessage chatAssistantMessage = {role: ASSISTANT, content: message?.content};
        chat:ChatCompletionRequestAssistantMessage_function_call? function_call = message?.function_call;
        if function_call is chat:ChatCompletionRequestAssistantMessage_function_call {
            chatAssistantMessage.toolCalls = [{name: function_call.name, arguments: function_call.arguments}];
        }
        return chatAssistantMessage;
    }

    private isolated function mapToChatCompletionRequestMessage(ChatMessage[] messages)
        returns chat:ChatCompletionRequestMessage[] {
        chat:ChatCompletionRequestMessage[] chatCompletionRequestMessages = [];
        foreach ChatMessage message in messages {
            if message is ChatAssistantMessage {
                chat:ChatCompletionRequestAssistantMessage assistantMessage = {role: ASSISTANT};
                FunctionCall[]? toolCalls = message.toolCalls;
                if toolCalls is FunctionCall[] {
                    assistantMessage.function_call = toolCalls[0];
                }
                if message?.content is string {
                    assistantMessage.content = message?.content;
                }
                chatCompletionRequestMessages.push(assistantMessage);
            } else {
                chatCompletionRequestMessages.push(message);
            }
        }
        return chatCompletionRequestMessages;
    }
}

# AzureOpenAiModel is a client class that provides an interface for interacting with Azure-hosted OpenAI language models.
public isolated client class AzureOpenAiModel {
    *Model;
    private final azure_chat:Client llmClient;
    private final string deploymentId;
    private final string apiVersion;

    # Initializes the Azure OpenAI model with the given connection configuration and model configuration.
    #
    # + serviceUrl - The base URL of Azure OpenAI API endpoint
    # + apiKey - The Azure OpenAI API key
    # + deploymentId - The deployment identifier for the specific model deployment in Azure  
    # + apiVersion - The Azure OpenAI API version (e.g., "2023-07-01-preview")
    # + maxTokens - The upper limit for the number of tokens in the response generated by the model
    # + temperature - The temperature for controlling randomness in the model's output  
    # + connectionConfig - Additional HTTP connection configuration
    # + return - `nil` on successful initialization; otherwise, returns an `Error`
    public isolated function init(@display {label: "Service URL"} string serviceUrl,
            @display {label: "API Key"} string apiKey,
            @display {label: "Deployment ID"} string deploymentId,
            @display {label: "API Version"} string apiVersion,
            @display {label: "Maximum Tokens"} int maxTokens = DEFAULT_MAX_TOKEN_COUNT,
            @display {label: "Temperature"} decimal temperature = DEFAULT_TEMPERATURE,
            @display {label: "Connection Configuration"} *ConnectionConfig connectionConfig) returns Error? {

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

    # Sends a chat request to the OpenAI model with the given messages and tools.
    #
    # + messages - List of chat messages 
    # + tools - Tool definitions to be used for the tool call
    # + stop - Stop sequence to stop the completion
    # + return - Function to be called, chat response or an error in-case of failures
    isolated remote function chat(ChatMessage[] messages, ChatCompletionFunctions[] tools, string? stop = ())
        returns ChatAssistantMessage|LlmError {
        azure_chat:CreateChatCompletionRequest request = {stop, messages: self.mapToChatCompletionRequestMessage(messages)};
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

        if choices is () || choices.length() == 0 {
            return error LlmInvalidResponseError("Empty response from the model when using function call API");
        }
        azure_chat:ChatCompletionResponseMessage? message = choices[0].message;
        ChatAssistantMessage chatAssistantMessage = {role: ASSISTANT, content: message?.content};
        azure_chat:ChatCompletionFunctionCall? function_call = message?.function_call;
        if function_call is chat:ChatCompletionRequestAssistantMessage_function_call {
            chatAssistantMessage.toolCalls = [{name: function_call.name, arguments: function_call.arguments}];
        }
        return chatAssistantMessage;
    }

    private isolated function mapToChatCompletionRequestMessage(ChatMessage[] messages)
        returns azure_chat:ChatCompletionRequestMessage[] {
        azure_chat:ChatCompletionRequestMessage[] chatCompletionRequestMessages = [];
        foreach ChatMessage message in messages {
            if message is ChatAssistantMessage {
                azure_chat:ChatCompletionRequestMessage assistantMessage = {role: ASSISTANT};
                FunctionCall[]? toolCalls = message.toolCalls;
                if toolCalls is FunctionCall[] {
                    assistantMessage["function_call"] = toolCalls[0];
                }
                if message?.content is string {
                    assistantMessage["content"] = message?.content;
                }
                chatCompletionRequestMessages.push(assistantMessage);
            } else {
                chatCompletionRequestMessages.push(message);
            }
        }
        return chatCompletionRequestMessages;
    }
}

# AnthropicModel is a client class that provides an interface for interacting with Anthropic language models.
public isolated client class AnthropicModel {
    *Model;
    private final http:Client AnthropicClient;
    private final string apiKey;
    private final string modelType;
    private final string apiVersion;
    private final int maxTokens;

    # Initializes the Anthropic model with the given connection configuration and model configuration.
    #
    # + apiKey - The Anthropic API key
    # + modelType - The Anthropic model name
    # + apiVersion - The Anthropic API version (e.g., "2023-06-01")  
    # + serviceUrl - The base URL of Anthropic API endpoint
    # + maxTokens - The upper limit for the number of tokens in the response generated by the model
    # + temperature - The temperature for controlling randomness in the model's output  
    # + connectionConfig - Additional HTTP connection configuration
    # + return - `nil` on successful initialization; otherwise, returns an `Error`
    public isolated function init(@display {label: "API Key"} string apiKey,
            @display {label: "Model Type"} ANTHROPIC_MODEL_NAMES modelType,
            @display {label: "API Version"} string apiVersion,
            @display {label: "Service URL"} string serviceUrl = ANTHROPIC_SERVICE_URL,
            @display {label: "Maximum Tokens"} int maxTokens = DEFAULT_MAX_TOKEN_COUNT,
            @display {label: "Temperature"} decimal temperature = DEFAULT_TEMPERATURE,
            @display {label: "Connection Configuration"} *ConnectionConfig connectionConfig) returns Error? {

        // Convert ConnectionConfig to http:ClientConfiguration
        http:ClientConfiguration anthropicConfig = {
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

        http:Client|error httpClient = new http:Client(serviceUrl, anthropicConfig);

        if (httpClient is error) {
            return error Error("Failed to initialize Anthropic Model", httpClient);
        }

        self.AnthropicClient = httpClient;
        self.apiKey = apiKey;
        self.modelType = modelType;
        self.apiVersion = apiVersion;
        self.maxTokens = maxTokens;
    }

    # Converts standard ChatMessage array to Anthropic's message format
    #
    # + messages - List of chat messages 
    # + return - return value description
    private isolated function mapToAnthropicMessages(ChatMessage[] messages) returns AnthropicMessage[] {
        AnthropicMessage[] anthropicMessages = [];

        foreach ChatMessage message in messages {
            if message is ChatUserMessage {
                anthropicMessages.push({
                    role: USER,
                    content: message.content
                });
            } else if message is ChatSystemMessage {
                // Add a user message containing the system prompt
                anthropicMessages.push({
                    role: USER,
                    content: string `<system>${message.content}</system>\n\n`
                });
            } else if message is ChatAssistantMessage && message.content is string {
                anthropicMessages.push({
                    role: ASSISTANT,
                    content: message.content ?: ""
                });
            } else if message is ChatFunctionMessage && message.content is string {
                // Include function results as user messages with special formatting
                anthropicMessages.push({
                    role: USER,
                    content: string `<function_results>\nFunction: ${message.name}\nOutput: ${message.content ?: ""}\n</function_results>`
                });
            }
        }
        return anthropicMessages;
    }

    # Maps ChatCompletionFunctions to Anthropic's tool format
    #
    # + tools - Array of tool definitions
    # + return - Array of Anthropic tool definitions
    private isolated function mapToAnthropicTools(ChatCompletionFunctions[] tools) returns AnthropicTool[] {
        AnthropicTool[] anthropicTools = [];

        foreach ChatCompletionFunctions tool in tools {
            JsonInputSchema schema = tool.parameters ?: {'type: "object", properties: {}};

            // Create Anthropic tool with input_schema instead of parameters
            AnthropicTool AnthropicTool = {
                name: tool.name,
                description: tool.description,
                input_schema: schema
            };

            anthropicTools.push(AnthropicTool);
        }

        return anthropicTools;
    }

    # Uses Anthropic API to generate a response
    # + messages - List of chat messages 
    # + tools - Tool definitions to be used for the tool call
    # + stop - Stop sequence to stop the completion (not used in this implementation)
    # + return - Chat response or an error in case of failures
    isolated remote function chat(ChatMessage[] messages, ChatCompletionFunctions[] tools = [], string? stop = ())
        returns ChatAssistantMessage|LlmError {

        // Map messages to Anthropic format
        AnthropicMessage[] anthropicMessages = self.mapToAnthropicMessages(messages);

        // Prepare request payload
        map<json> requestPayload = {
            "model": self.modelType,
            "max_tokens": self.maxTokens,
            "messages": anthropicMessages
        };

        if stop is string {
            requestPayload["stop_sequences"] = [stop];
        }

        // If tools are provided, add them to the request
        if tools.length() > 0 {
            requestPayload["tools"] = self.mapToAnthropicTools(tools);
        }

        // Send request to Anthropic API with proper headers
        map<string> headers = {
            "x-api-key": self.apiKey,
            "anthropic-version": self.apiVersion,
            "content-type": "application/json"
        };

        AnthropicApiResponse|error anthropicResponse = self.AnthropicClient->/messages.post(requestPayload, headers);
        if anthropicResponse is error {
            return error LlmInvalidResponseError("Unexpected response format from Anthropic API", anthropicResponse);
        }

        string? content = ();
        FunctionCall[] toolCalls = [];
        foreach ContentBlock block in anthropicResponse.content {
            string blockType = block.'type;
            if blockType == "tool_use" {
                string blockName = block.name ?: "";
                json inputJson = block?.input;
                toolCalls.push({
                    name: blockName,
                    arguments: inputJson.toJsonString()
                });
            } else if blockType == "text" {
                content = block.text;
            }
        }
        return {role: ASSISTANT, toolCalls: toolCalls == [] ? () : toolCalls, content};
    }
}

# MistralAiModel is a client class that provides an interface for interacting with Mistral AI language models.
public isolated client class MistralAiModel {
    *Model;
    private final mistral:Client llmClient;
    private final string modelType;
    private final string apiKey;

    # # Initializes the Mistral AI model with the given connection configuration and model configuration.
    #
    # + apiKey - The Mistral AI API key
    # + modelType - The Mistral AI model name
    # + serviceUrl - The base URL of Mistral AI API endpoint
    # + maxTokens - The upper limit for the number of tokens in the response generated by the model
    # + temperature - The temperature for controlling randomness in the model's output
    # + connectionConfig - Additional HTTP connection configuration
    # + return - `nil` on successful initialization; otherwise, returns an `Error`
    public isolated function init(@display {label: "API Key"} string apiKey,
            @display {label: "Model Type"} MISTRAL_AI_MODEL_NAMES modelType,
            @display {label: "Service URL"} string serviceUrl = MISTRAL_AI_SERVICE_URL,
            @display {label: "Maximum Tokens"} int maxTokens = DEFAULT_MAX_TOKEN_COUNT,
            @display {label: "Temperature"} decimal temperature = DEFAULT_TEMPERATURE,
            @display {label: "Connection Configuration"} *ConnectionConfig connectionConfig
    ) returns Error? {

        mistral:ConnectionConfig mistralConfig = {
            auth: {token: apiKey},
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

        mistral:Client|error llmClient = new (mistralConfig);
        if llmClient is error {
            return error Error("Failed to initialize MistralAiModel", llmClient);
        }

        self.llmClient = llmClient;
        self.modelType = modelType;
        self.apiKey = apiKey;
    }

    # Uses function call API to determine next function to be called
    #
    # + messages - List of chat messages 
    # + tools - Tool definitions to be used for the tool call
    # + stop - Stop sequence to stop the completion
    # + return - Returns an array of ChatAssistantMessage or an LlmError in case of failures
    isolated remote function chat(ChatMessage[] messages, ChatCompletionFunctions[] tools, string? stop = ())
        returns ChatAssistantMessage|LlmError {
        MistralMessages[] mistralMessages = self.mapToMistralMessageRecords(messages);
        mistral:ChatCompletionRequest request = {model: self.modelType, stop, messages: mistralMessages};

        if tools.length() > 0 {
            mistral:Function[] mistralFunctions = [];
            foreach ChatCompletionFunctions toolFunction in tools {
                mistral:Function mistralFunction = {
                    name: toolFunction.name,
                    description: toolFunction.description,
                    strict: false,
                    parameters: toolFunction.parameters ?: {}
                };
                mistralFunctions.push(mistralFunction);
            }

            mistral:Tool[] mistralTools = [];
            foreach mistral:Function mistralfunction in mistralFunctions {
                mistral:Tool mistralTool = {'function: mistralfunction};
                mistralTools.push(mistralTool);
            }
            request.tools = mistralTools;
        }

        mistral:ChatCompletionResponse|error response = self.llmClient->/chat/completions.post(request);
        if response is error {
            return error LlmConnectionError("Error while connecting to the model", response);
        }
        return self.getAssistantMessage(response);
    }

    # Generates a random tool ID.
    #
    # + return - A random tool ID string
    private isolated function generateToolId() returns string {
        string randomToolId = "";
        string randomId = uuid:createRandomUuid();
        regexp:RegExp alphanumericPattern = re `[a-zA-Z0-9]`;
        int iterationCount = 0;

        foreach string character in randomId {
            if alphanumericPattern.isFullMatch(character) {
                randomToolId = randomToolId + character;
                iterationCount = iterationCount + 1;
            }
            if iterationCount == 9 {
                break;
            }
        }
        return randomToolId;
    }

    # Maps an array of `ChatMessage` records to corresponding Mistral message records.
    #
    # + messages - Array of chat messages to be converted
    # + return - An `LlmError` or an array of Mistral message records
    private isolated function mapToMistralMessageRecords(ChatMessage[] messages) returns MistralMessages[] {
        MistralMessages[] mistralMessages = [];
        foreach ChatMessage message in messages {
            if message is ChatUserMessage {
                mistral:UserMessage userMessage = {role: USER, content: message.content};
                mistralMessages.push(userMessage);
            } else if message is ChatSystemMessage {
                mistral:SystemMessage systemMessage = {role: SYSTEM, content: message.content};
                mistralMessages.push(systemMessage);
            } else if message is ChatAssistantMessage {
                FunctionCall[]? toolCalls = message.toolCalls;
                mistral:AssistantMessage mistralAssistantMessage = {role: ASSISTANT, content: message.content};
                if toolCalls is FunctionCall[] {
                    mistral:FunctionCall functionCall = {name: toolCalls[0].name, arguments: toolCalls[0].arguments};
                    mistral:ToolCall[] toolCall = [{'function: functionCall, id: toolCalls[0]?.id ?: self.generateToolId()}];
                    mistralAssistantMessage.toolCalls = toolCall;
                }
                mistralMessages.push(mistralAssistantMessage);
            } else if message is ChatFunctionMessage {
                mistral:ToolMessage mistralToolMessage = {
                    role: "tool",
                    content: message.content,
                    toolCallId: message.id ?: self.generateToolId()
                };
                mistralMessages.push(mistralToolMessage);
            }
        }
        return mistralMessages;
    }

    # Extracts assistant messages from a Mistral chat completion response.
    #
    # + response - The response from LLM
    # + return - An array of ChatAssistantMessage records
    private isolated function getAssistantMessage(mistral:ChatCompletionResponse response)
        returns ChatAssistantMessage|LlmError {
        mistral:ChatCompletionChoice[]? choices = response.choices;
        if choices is () || choices.length() == 0 {
            return error LlmInvalidResponseError("Empty response from the model when using function call API");
        }
        mistral:AssistantMessage message = choices[0].message;
        string|mistral:ContentChunk[]? content = message?.content;
        if content is mistral:TextChunk[]|mistral:DocumentURLChunk[]|mistral:ReferenceChunk[] {
            return error LlmError("Unsupported content type", cause = content);
        }
        string? stringContent = ();
        if content is string && content.length() > 0 {
            stringContent = content;
        } else if content is mistral:TextChunk[] {
            stringContent = string:'join("", ...content.'map(chunk => chunk.text));
        }

        mistral:ToolCall[]? toolCalls = message?.toolCalls;
        if toolCalls is () {
            return {role: ASSISTANT, content: stringContent};
        }
        FunctionCall[] functionCalls = [];
        foreach mistral:ToolCall toolcall in toolCalls {
            functionCalls.push({
                name: toolcall.'function.name,
                id: toolcall.id,
                arguments: toolcall.'function.arguments.toString()
            });
        }
        return {role: ASSISTANT, toolCalls: functionCalls, content: stringContent};
    }
}
