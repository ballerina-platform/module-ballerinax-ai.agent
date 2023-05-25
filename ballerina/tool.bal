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
import ballerina/regex;
import ballerina/log;

type ToolNotFoundError distinct error;

type ToolInvalidInputError distinct error;

type AgentTool record {|
    string name;
    string description;
    JsonInputSchema variables?;
    map<json> constants = {};
    isolated function caller;
|};

type ToolInfo readonly & record {|
    string toolList;
    string toolIntro;
|};

isolated class ToolStore {
    private final map<AgentTool> & readonly tools;

    # Register tools to the agent. 
    # These tools will be by the LLM to perform tasks.
    #
    # + tools - A list of tools that are available to the LLM
    # + return - An error if the tool is already registered
    isolated function init(Tool[] tools) returns error? {
        map<AgentTool & readonly> toolMap = {};
        check registerTool(toolMap, tools);
        self.tools = toolMap.cloneReadOnly();
    }

    # execute the tool decided by the LLM.
    #
    # + toolName - Name of the tool to be executed
    # + inputs - Variable inputs to the tool
    # + return - Result of the tool execution or an error if tool execution fails
    isolated function runTool(string toolName, map<json>? inputs) returns any|error {
        if !self.tools.hasKey(toolName) {
            return error ToolNotFoundError(string `Can't find the tool '${toolName}'. Provide a valid toolName`);
        }

        isolated function caller = self.tools.get(toolName).caller;
        map<json>|error inputValues = mergeInputs(inputs, self.tools.get(toolName).constants);
        if inputValues is error {
            return error ToolInvalidInputError(string `Tool '${toolName}' is provide with invalid inputs: ${(inputs ?: {}).toString()}`);
        }

        any|error observation;
        if inputValues.length() == 0 {
            observation = trap check function:call(caller);
        } else {
            map<json> & readonly toolParams = inputValues.cloneReadOnly();
            observation = trap check function:call(caller, toolParams);
        }
        if observation is error {
            log:printWarn(string `Tool '${toolName}' is provide with invalid inputs: ${inputValues.toString()}`);
            return error ToolInvalidInputError(string `Tool '${toolName}' is provide with invalid inputs: ${(inputs ?: {}).toString()}`);
        }
        return observation;
    }

    # Generate descriptions for the tools registered.
    # 
    # + return - Return a record with tool names and descriptions
    isolated function extractToolInfo() returns ToolInfo {
        string[] toolNameList = [];
        string[] toolIntroList = [];

        map<AgentTool> tools = self.tools;
        foreach AgentTool tool in tools {
            toolNameList.push(tool.name);
            record {|string description; JsonInputSchema inputSchema?;|} toolDescription = {
                description: tool.description,
                inputSchema: tool.variables
            };
            toolIntroList.push(tool.name + ": " + toolDescription.toString());
        }
        return {
            toolList: string:'join(", ", ...toolNameList),
            toolIntro: string:'join("\n", ...toolIntroList)
        };
    }
}

isolated function registerTool(map<AgentTool & readonly> toolMap, Tool[] tools) returns error? {
    foreach Tool tool in tools {
        if toolMap.hasKey(tool.name) {
            return error(string `Duplicated tools. Tool '${tool.name}' is already registered.`);
        }

        JsonInputSchema? variables = check tool.inputSchema.cloneWithType();
        map<json> constants = {};

        if variables is JsonInputSchema {
            constants = resolveSchema(variables) ?: {};
        }

        AgentTool agentTool = {
            name: tool.name,
            description: regex:replaceAll(tool.description, "\n", " "),
            variables: variables,
            constants: constants,
            caller: tool.caller
        };
        toolMap[tool.name] = agentTool.cloneReadOnly();
    }
}

isolated function resolveSchema(JsonInputSchema schema) returns map<json>? {
    if schema is ObjectInputSchema {
        map<json> values = {};
        foreach [string, JsonSubSchema] [key, subSchema] in schema.properties.entries() {
            json returnedValue = ();
            if subSchema is ArrayInputSchema {
                returnedValue = subSchema?.default;
            }
            else if subSchema is PrimitiveInputSchema {
                returnedValue = subSchema?.default;
            }
            else if subSchema is ConstantValueSchema {
                string tempKey = key; // temporary reference to fix java null pointer issue
                returnedValue = subSchema.'const;
                _ = schema.properties.remove(tempKey);
                string[]? required = schema.required;
                if required !is () {
                    schema.required = from string requiredKey in required
                        where requiredKey != tempKey
                        select requiredKey;
                }
            } else {
                returnedValue = resolveSchema(subSchema);
            }
            if returnedValue !is () {
                values[key] = returnedValue;
            }
        }
        if values.length() > 0 {
            return values;
        }
        return ();
    }
    // skip anyof, oneof, allof, not
    return ();
}

isolated function mergeInputs(map<json>? inputs, map<json> constants) returns map<json> {
    if inputs is () {
        return constants;
    }

    foreach [string, json] [key, value] in constants.entries() {
        if inputs.hasKey(key) {
            json inputValue = inputs[key];
            if inputValue is map<json> && value is map<json> {
                inputs[key] = mergeInputs(inputValue, value);
            }
        }
        else {
            inputs[key] = value;
        }
    }
    return inputs;
}
