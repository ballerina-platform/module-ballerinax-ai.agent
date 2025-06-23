// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.com).
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

@test:Config {
    groups: ["mcp"]
}
function testMcpToolKit() returns error? {
    McpToolkit mcpToolKit = check new (serverUrl = "http://localhost:3000/mcp", clientInfo = {name: "Greeting", version: ""});
    ToolConfig[]|error tools = mcpToolKit.getTools();
    if tools is error {
        test:assertFail("Error occurred while getting tools from HttpToolKit");
    }
    test:assertEquals(tools.length(), 2);
    test:assertEquals(tools[0].name, "single-greeting");

    LlmToolResponse mcpInput = {
        name: "single-greeting",
        arguments: {
            params: {
                name: "single-greeting",
                arguments: {
                    "greetName": "John"
                }
            }
        }
    };
    ToolStore toolStore = check new (mcpToolKit);
    ToolOutput output = check toolStore.execute(mcpInput);
    if output.value is error {
        test:assertFail("tool execution output is an error");
    }
    json expectedResult = {
        "content":[
            {
                "type":"text",
                "text":"Hey John! Welcome to Ballerina!"
            }
        ]
    };
    test:assertEquals((check output.value).toJson(), expectedResult);
}
