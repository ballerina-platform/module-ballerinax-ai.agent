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

public type InputSchema record {
};

public type Tool record {|
    string name;
    string description;
    InputSchema? inputs = ();
    function caller;
|};

public type generatedOutput record {|
    string toolNames;
    string toolDescriptions;
|};

class ToolStore {
    map<Tool> tools;

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
    function runTool(string toolName, json? inputs) returns string|error {

        if !self.tools.hasKey(toolName) {
            log:printWarn("Failed to execute the unknown tool: " + toolName);
            return string `You don't have access to the ${TOOL_KEYWORD}: ${toolName}. Try a different approach`;
        }

        function caller = self.tools.get(toolName).caller;
        any|error observation;
        if inputs is null {
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
    function generateDescriptions() returns generatedOutput {
        string[] toolDescriptionList = [];
        string[] toolNameList = [];
        foreach Tool tool in self.tools {
            toolNameList.push(tool.name);
            toolDescriptionList.push(self.buildToolDescription(tool));
        }
        string toolDescriptions = string:'join("\n", ...toolDescriptionList);
        string toolNames = toolNameList.toString();
        return {toolNames: toolNames, toolDescriptions: toolDescriptions};
    }

    # Build description for an tool to generate prompts to the LLMs
    #
    # + tool - Tool requires prompt decription
    # + return - Prompt description generated for the tool
    private function buildToolDescription(Tool tool) returns string {
        if tool.inputs == null { // case for functions with zero parameters 
            return string `${tool.name}: ${tool.description}. Parameters should be empty {}`;
        }
        return string `${tool.name}: ${tool.description}. Parameters to this ${TOOL_KEYWORD} should be in the format of ${tool.inputs.toString()}`;
    }

    function mergeToolStore(ToolStore toolStore) {
        foreach Tool tool in toolStore.tools {
            self.tools[tool.name] = tool;
        }
    }
}
