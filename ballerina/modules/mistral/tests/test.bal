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

import ballerina/os;
import ballerina/test;

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
        messages: [userMessage],
        model: "mistral-small-latest"
    };

    ChatCompletionResponse response = check mistralAiClient->/chat/completions.post(chatRequest);
    ChatCompletionChoice[]? choices = response.choices;
    if choices is ChatCompletionChoice[] {
        AssistantMessage? message = choices[0].message;
        string|ContentChunk[]? content = message?.content;
        test:assertEquals(content, "Test message received! How can I assist you today?");
    }
}
