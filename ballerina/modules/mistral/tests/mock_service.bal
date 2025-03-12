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

import ballerina/http;

service / on new http:Listener(9090) {
    resource function post chat/completions(map<json> payload) returns ChatCompletionResponse {
        AssistantMessage message = {
            role: "assistant",
            toolCalls: (),
            content: "Test message received! How can I assist you today?",
            prefix: false
        };

        ChatCompletionChoice choice = {
            finishReason: "stop",
            index: 0,
            message: message
        };

        return {
            id: "cmpl-e5cc70bb28c444948073e77776eb30ef",
            model: "gpt-4o-mini-2024-07-18",
            'object: "chat.completion",
            usage: {completionTokens: 16, promptTokens: 34, totalTokens: 50},
            choices: [
                choice
            ],
            created: 1702256327
        };
    }
};
