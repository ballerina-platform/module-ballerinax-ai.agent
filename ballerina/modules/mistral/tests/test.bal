import ballerina/os;
import ballerina/test;
import ballerina/io;


configurable boolean isLiveServer = os:getEnv("IS_LIVE_SERVER") == "true";
configurable string token = isLiveServer ? os:getEnv("MISTRAL_API_KEY") : "test";
final string mockServiceUrl = "http://localhost:9090";
final Client mistralAiClient = check initClient();

function initClient() returns Client|error {
    if isLiveServer {
        return new ({auth: {token}});
    }
    return new ({auth: {token}}, mockServiceUrl);
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
isolated function testChatCompletion() returns error? {

    UserMessage userMessage = {
        role: "user",
        content: "This is a test message"
    };

    ChatCompletionRequest chatRequest = {
        messages:  [userMessage],
        model: "mistral-small-latest"
    };

    io:println("Sending chat completion request: ", chatRequest);

    ChatCompletionResponse response = check mistralAiClient->/v1/chat/completions.post(chatRequest);
    io:println("Server response: ",response);
    ChatCompletionChoice[]? choices = response.choices;
    if choices is ChatCompletionChoice[] {
        AssistantMessage? message = choices[0].message;
        string|ContentChunk[]? content = message?.content;
        test:assertEquals(content, "Test message received! How can I assist you today?");
    }
    
    // test:assertTrue(response.choices.length() > 0, msg = "Expected at least one completion choice");
    // string? content = response.choices[0].message.content;
    // test:assertTrue(content !is (), msg = "Expected content in the completion response");
}