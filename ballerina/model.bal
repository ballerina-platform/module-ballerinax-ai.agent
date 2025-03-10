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

# Models types for Claude
@display {label: "Claude Model Names"}
public enum CLAUDE_MODEL_NAMES {
    CLAUDE_3_7_SONNET_20250219 = "claude-3-7-sonnet-20250219",
    CLAUDE_3_5_HAIKU_20241022 = "claude-3-5-haiku-20241022",
    CLAUDE_3_5_SONNET_20241022 = "claude-3-5-sonnet-20241022",
    CLAUDE_3_5_SONNET_20240620 = "claude-3-5-sonnet-20240620",
    CLAUDE_3_OPUS_20240229 = "claude-3-opus-20240229",
    CLAUDE_3_SONNET_20240229 = "claude-3-sonnet-20240229",
    CLAUDE_3_HAIKU_20240307 = "claude-3-haiku-20240307"
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
|};

# Claude API request message format
type ClaudeMessage record {|
    # Role of the participant in the conversation (e.g., "user" or "assistant")
    string role;
    # The message content
    string content;
|};

# Claude API response format
type ClaudeApiResponse record {|
    # Unique identifier for the response message
    string id;
    # The Claude model used for generating the response
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

# Content block in Claude API response
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

# Usage statistics in Claude API response
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

# Claude Tool definition
type ClaudeTool record {|
    # Name of the tool
    string name;
    # Description of the tool
    string description;
    # Input schema of the tool in JSON Schema format
    json input_schema;
|};

# Represents an extendable client for interacting with an AI model.
public type Model distinct isolated client object {
    isolated remote function chat(ChatMessage[] messages, ChatCompletionFunctions[] tools = [], string? stop = ())
        returns ChatAssistantMessage[]|LlmError;
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

# ClaudeModel is a client class that provides an interface for interacting with Claude language models.
public isolated client class ClaudeModel {
    *Model;
    private final http:Client claudeClient;
    private final string apiKey;
    private final string modelType;
    private final string apiVersion;
    private final int maxTokens;

    # Initializes the Claude model with the given connection configuration and model configuration.
    #
    # + apiKey - The Claude API key
    # + modelType - The Claude model name
    # + apiVersion - The Claude API version (e.g., "2023-06-01")  
    # + serviceUrl - The base URL of Claude API endpoint
    # + maxTokens - The upper limit for the number of tokens in the response generated by the model
    # + temperature - The temperature for controlling randomness in the model's output  
    # + connectionConfig - Additional HTTP connection configuration
    # + return - `nil` on successful initialization; otherwise, returns an `Error`
    public isolated function init(@display {label: "API Key"} string apiKey,
            @display {label: "Model Type"} CLAUDE_MODEL_NAMES modelType,
            @display {label: "API Version"} string apiVersion,
            @display {label: "Service URL"} string serviceUrl = CLAUDE_SERVICE_URL,
            @display {label: "Maximum Tokens"} int maxTokens = DEFAULT_MAX_TOKEN_COUNT,
            @display {label: "Temperature"} decimal temperature = DEFAULT_TEMPERATURE,
            @display {label: "Connection Configuration"} *ConnectionConfig connectionConfig) returns Error? {

        // Convert ConnectionConfig to http:ClientConfiguration
        http:ClientConfiguration claudeConfig = {
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

        http:Client|error httpClient = new http:Client(serviceUrl, claudeConfig);

        if (httpClient is error) {
            return error Error("Failed to initialize ClaudeModel", httpClient);
        }

        self.claudeClient = httpClient;
        self.apiKey = apiKey;
        self.modelType = modelType;
        self.apiVersion = apiVersion;
        self.maxTokens = maxTokens;
    }

    # Converts standard ChatMessage array to Claude's message format
    #
    # + messages - List of chat messages 
    # + return - return value description
    private isolated function mapToClaudeMessages(ChatMessage[] messages) returns ClaudeMessage[] {
        ClaudeMessage[] claudeMessages = [];

        foreach ChatMessage message in messages {
            if message is ChatUserMessage {
                claudeMessages.push({
                    role: USER,
                    content: message.content
                });
            } else if message is ChatSystemMessage {
                // Add a user message containing the system prompt
                claudeMessages.push({
                    role: USER,
                    content: string `<system>${message.content}</system>\n\n`
                });
            } else if message is ChatAssistantMessage && message.content is string {
                claudeMessages.push({
                    role: ASSISTANT,
                    content: message.content ?: ""
                });
            } else if message is ChatFunctionMessage && message.content is string {
                // Include function results as user messages with special formatting
                claudeMessages.push({
                    role: USER,
                    content: string `<function_results>\nFunction: ${message.name}\nOutput: ${message.content ?: ""}\n</function_results>`
                });
            }
        }
        return claudeMessages;
    }

    # Maps ChatCompletionFunctions to Claude's tool format
    #
    # + tools - Array of tool definitions
    # + return - Array of Claude tool definitions
    private isolated function mapToClaudeTools(ChatCompletionFunctions[] tools) returns ClaudeTool[] {
        ClaudeTool[] claudeTools = [];

        foreach ChatCompletionFunctions tool in tools {
            JsonInputSchema schema = tool.parameters ?: {'type: "object", properties: {}};

            // Create Claude tool with input_schema instead of parameters
            ClaudeTool claudeTool = {
                name: tool.name,
                description: tool.description,
                input_schema: schema
            };

            claudeTools.push(claudeTool);
        }

        return claudeTools;
    }

    # Uses Claude API to generate a response
    # + messages - List of chat messages 
    # + tools - Tool definitions to be used for the tool call
    # + stop - Stop sequence to stop the completion (not used in this implementation)
    # + return - Chat response or an error in case of failures
    isolated remote function chat(ChatMessage[] messages, ChatCompletionFunctions[] tools = [], string? stop = ())
        returns ChatAssistantMessage[]|LlmError {

        // Map messages to Claude format
        ClaudeMessage[] claudeMessages = self.mapToClaudeMessages(messages);

        // Prepare request payload
        map<json> requestPayload = {
            "model": self.modelType,
            "max_tokens": self.maxTokens,
            "messages": claudeMessages,
            "stop_sequences": stop
        };

        // If tools are provided, add them to the request
        if tools.length() > 0 {
            ClaudeTool[] claudeTools = self.mapToClaudeTools(tools);
            requestPayload["tools"] = claudeTools;
        }

        // Send request to Claude API with proper headers
        map<string> headers = {
            "x-api-key": self.apiKey,
            "anthropic-version": self.apiVersion,
            "content-type": "application/json"
        };

        ClaudeApiResponse|error claudeResponse = self.claudeClient->/messages.post(requestPayload, headers);

        if claudeResponse is error {
            return error LlmInvalidResponseError("Unexpected response format from Claude API", claudeResponse);
        }

        string responseText = "";
        FunctionCall[] functionCalls = [];

        ContentBlock[] contentBlocks = claudeResponse.content;

        foreach ContentBlock block in contentBlocks {
            string blockType = block.'type;
            if blockType == "tool_use" {
                string blockName = block.name ?: "";
                json inputJson = block?.input;
                functionCalls.push({
                    name: blockName,
                    arguments: inputJson.toJsonString()
                });
            } else if blockType == "text" {
                responseText = block.text ?: "";
            }
        }

        // Return response with function calls first, then text
        if functionCalls.length() > 0 {
            ChatAssistantMessage[] returnResponse = [];

            // First add each function call as a separate message
            foreach FunctionCall call in functionCalls {
                returnResponse.push({
                    role: ASSISTANT,
                    function_call: call
                });
            }

            // Then add the text response if it exists 
            if responseText != "" {
                returnResponse.push({
                    role: ASSISTANT,
                    content: responseText
                });
            }

            return returnResponse;
        } else {
            return [
                {
                    role: ASSISTANT,
                    content: responseText
                }
            ];
        }
    }
}
