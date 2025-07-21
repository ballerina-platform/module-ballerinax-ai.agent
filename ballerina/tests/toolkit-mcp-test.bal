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
    McpToolKit mcpToolKit = check new (serverUrl = "http://localhost:3000/mcp", info = {name: "Greeting", version: ""});
    ToolConfig[] tools = mcpToolKit.getTools();
    test:assertEquals(tools.length(), 2);
    test:assertEquals(tools[0].name, "single-greeting");

    LlmToolResponse toolInput = {
        name: "single-greeting",
        arguments: {
            "greetName": "John"
        }
    };
    ToolStore toolStore = check new (mcpToolKit);
    ToolOutput output = check toolStore.execute(toolInput);
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

@test:Config {
    groups: ["mcp"]
}
function testMcpToolKitWithPermittedTools() returns error? {
    McpToolKit mcpToolKit = check new (
        serverUrl = "http://localhost:3000/mcp",
        permittedTools = ["single-greeting"],
        info = {name: "Greeting", version: ""}
    );
    ToolConfig[] tools = mcpToolKit.getTools();
    test:assertEquals(tools.length(), 1);
    test:assertEquals(tools[0].name, "single-greeting");

    LlmToolResponse toolInput = {
        name: "single-greeting",
        arguments: {
            "greetName": "John"
        }
    };
    ToolStore toolStore = check new (mcpToolKit);
    ToolOutput output = check toolStore.execute(toolInput);
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

@test:Config {
    groups: ["mcp", "error"]
}
function testMcpToolKitWithInvalidUrl() returns error? {
    McpToolKit|error mcpToolKit = new (serverUrl = "http://invalid-url:3000", info = {name: "Greeting", version: ""});
    test:assertTrue(mcpToolKit is error);
    if mcpToolKit is error {
        test:assertEquals(mcpToolKit.message(), "Failed to initialize the MCP client");
    }
}
