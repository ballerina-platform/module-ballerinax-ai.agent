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
import ballerinax/ai;

configurable string apiKey = ?;
configurable string deploymentId = ?;
configurable string apiVersion = ?;
configurable string serviceUrl = ?;

final ai:ModelProvider model = check new ai:AzureOpenAiProvider(serviceUrl, apiKey, deploymentId, apiVersion);
final ai:Agent agent = check new (
    systemPrompt = {
        role: "Math Tutor",
        instructions: "You are a school tutor assistant. " +
        "Provide answers to students' questions so they can compare their answers. " +
        "Use the tools when there is query related to math"
    },
    model = model,
    tools = [sum, mult, sqrt],
    verbose = true
);

@ai:AgentTool
isolated function sum(decimal a, decimal b) returns decimal => a + b;

@ai:AgentTool
isolated function mult(decimal a, decimal b) returns decimal => a * b;

@ai:AgentTool
isolated function sqrt(float a) returns float => a.sqrt();

service /api/v1 on new ai:Listener(9090) {
    resource function post chat(@http:Payload ai:ChatReqMessage request) returns ai:ChatRespMessage|error {
        string response = check agent->run(request.message, memoryId = request.sessionId);
        return {message: response};
    }
}
