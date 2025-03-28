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

import ballerina/test;
import ballerinax/ai;

@test:Config {}
function testAgentChat() returns error? {
    ai:ChatClient chatClient = check new("http://localhost:9090/chatService");
    ai:ChatReqMessage req = {
        sessionId: "1",
        message: "Hello Ballerina!"
    };
    ai:ChatRespMessage resp = check chatClient->/chat.post(req);
    test:assertEquals(resp.message, "1: Hello Ballerina!", "Invalid response message");
}
