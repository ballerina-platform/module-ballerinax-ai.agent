import ballerina/http;
import ballerina/io;
service / on new http:Listener(9090) {
    resource function post v1/chat/completions(map<json> payload) returns ChatCompletionResponse|http:BadRequest {
        io:println("Payload chat: ", payload);
        AssistantMessage message = {
            role: "assistant",
            toolCalls: null,
            content: "Test message received! How can I assist you today?",
            prefix: false
        };

        ChatCompletionChoice choice = {
            finishReason: "stop",
            index: 0,
            message: message
        };

        // Mock response
        ChatCompletionResponse response = {
            id: "cmpl-e5cc70bb28c444948073e77776eb30ef",
            model: "gpt-4o-mini-2024-07-18",
            'object: "chat.completion",
            usage: {completionTokens: 16, promptTokens: 34, totalTokens: 50},
            choices: [
                choice
            ],
            created: 1702256327
        };
        return response;
    }
};
