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

import ballerina/log;

type ToolDescription record {
    string description;
    InputSchema inputSchema?;
};

public type ToolInfo record {|
    string toolList;
    string toolIntro;
|};

class ToolStore {
    private map<Tool> tools;

    function init() {
        self.tools = {};
    }

    # Register tools to the agent. 
    # These tools will be by the LLM to perform tasks 
    #
    # + tools - A list of tools that are available to the LLM
    # + return - An error if the tool is already registered
    function registerTools(Tool... tools) returns error? {
        foreach Tool tool in tools {
            if self.tools.hasKey(tool.name) {
                return error(string `Duplicated tools. Tool '${tool.name}' is already registered.`);
            }
            self.tools[tool.name] = tool;
        }
    }

    # execute the tool decided by the LLM
    #
    # + toolName - Name of the tool to be executed
    # + inputs - Inputs to the tool
    # + return - Result of the tool execution or an error if tool execution fails
    function runTool(string toolName, map<json>? inputs) returns string|error {

        if !self.tools.hasKey(toolName) {
            log:printWarn("Failed to execute the unknown tool: " + toolName);
            return string `You don't have access to the ${TOOL_KEYWORD}: ${toolName}. Try a different approach`;
        }

        function caller = self.tools.get(toolName).caller;
        any|error observation;
        if inputs is null || inputs.length() == 0 {
            observation = function:call(caller);
        } else {
            map<json> & readonly toolParams = check inputs.fromJsonWithType();
            if toolParams.length() > 0 {
                observation = function:call(caller, toolParams);
            } else {
                observation = function:call(caller);
            }
        }

        if observation is error {
            return observation.message();
        }
        return observation.toString();
    }

    # Generate descriptions for the tools registered
    # + return - Return a record with tool names and descriptions
    function extractToolInfo() returns ToolInfo {
        string[] toolNameList = [];
        string[] toolIntroList = [];
        foreach Tool tool in self.tools {
            toolNameList.push(tool.name);

            ToolDescription toolDescription = {
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

    function mergeToolStore(ToolStore toolStore) {
        foreach Tool tool in toolStore.tools {
            self.tools[tool.name] = tool;
        }
    }
}
