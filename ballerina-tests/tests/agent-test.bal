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
import ballerinax/ai.agent;

@test:Config
function testAgentToolExecution() returns error? {
    // Currenlty we can't initilize the agent at the module level
    // due to the following issue: https://github.com/ballerina-platform/ballerina-lang/issues/33594
    agent:Agent agent = check new (model = model,
        systemPrompt = {role: "Math tutor", instructions: "Help the students with their questions."},
        tools = [sum, mutiply], agentType = agent:REACT_AGENT
    );
    string result = check agent->run("What is the sum of the following numbers 78 90 45 23 8?");
    test:assertEquals(result, "Answer is: 244.0");

    result = check agent->run("What is the product of 78 and 90?");
    test:assertEquals(result, "Answer is: 7020");
}
