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

# A client class for interacting with a chat service.
public isolated client class ChatClient {
    private final http:Client httpClient;

    # Initializes the `ChatClient` with the provided service URL and configuration.
    #
    # + serviceUrl - The base URL of the chat service.
    # + clientConfig - Configuration options for the chat client.
    # + return - An `error?` if the client initialization fails.
    public function init(string serviceUrl, *ChatClientConfiguration clientConfig) returns error? {
        http:ClientConfiguration clientConfigData = {...clientConfig};
        self.httpClient = check new(serviceUrl, clientConfigData);
    }

    # Handles incoming chat messages by sending a request to the chat service.
    #
    # + request - The chat request message to be sent.
    # + return - A `ChatRespMessage` containing the response from the chat service, or an `error` if the request fails.
    isolated remote function onChatMessage(ChatReqMessage request) returns ChatRespMessage|error {
        return self.httpClient->/chatMessage.post(request);
    }
}
