// Copyright (c) 2023 WSO2 LLC (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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

type ToolNotFoundError distinct error;

type ToolInvalidInputError distinct error;

type ToolInfo readonly & record {|
    string toolList;
    string toolIntro;
|};

isolated class ToolStore {
    private final map<Tool & readonly> tools = {};

    # Register tools to the agent. 
    # These tools will be by the LLM to perform tasks 
    #
    # + tools - A list of tools that are available to the LLM
    # + return - An error if the tool is already registered
    isolated function registerTools(Tool... tools) returns error? {
        lock {
            foreach Tool tool in tools.cloneReadOnly() {
                if self.tools.hasKey(tool.name) {
                    return error(string `Duplicated tools. Tool '${tool.name}' is already registered.`);
                }
                self.tools[tool.name] = tool;
            }
        }
    }

    # execute the tool decided by the LLM
    #
    # + toolName - Name of the tool to be executed
    # + inputs - Inputs to the tool
    # + return - Result of the tool execution or an error if tool execution fails
    isolated function runTool(string toolName, map<json>? inputs) returns any|error {
        isolated function caller;
        lock {
            if !self.tools.hasKey(toolName) {
                return error ToolNotFoundError(string `Can't find the tool '${toolName}'. Provide a valid toolName`);
            }
            caller = self.tools.get(toolName).caller;
        }
        any|error observation;
        if inputs is () || inputs.length() == 0 {
            observation = trap check function:call(caller);
        } else {
            map<json> & readonly toolParams = inputs.cloneReadOnly();
            observation = trap check function:call(caller, toolParams);
        }
        if observation is error {
            return error ToolInvalidInputError(string `Tool '${toolName}' is provide with invalid inputs: ${(inputs ?: {}).toString()}`);
        }
        return observation;
    }

    # Generate descriptions for the tools registered
    # + return - Return a record with tool names and descriptions
    isolated function extractToolInfo() returns ToolInfo {
        string[] toolNameList = [];
        string[] toolIntroList = [];

        map<Tool> tools;
        lock {
            tools = self.tools.cloneReadOnly();
        }
        foreach Tool tool in tools {
            toolNameList.push(tool.name);
            record {|string description; InputSchema inputSchema?;|} toolDescription = {
                description: tool.description,
                inputSchema: tool.inputs
            };
            toolIntroList.push(tool.name + ": " + toolDescription.toString());
        }
        return {
            toolList: string:'join(", ", ...toolNameList),
            toolIntro: string:'join("\n", ...toolIntroList)
        };
    }

    isolated function mergeToolStore(ToolStore toolStore) {
        lock {
            foreach Tool tool in toolStore.tools {
                self.tools[tool.name] = tool;
            }
        }
    }
}
