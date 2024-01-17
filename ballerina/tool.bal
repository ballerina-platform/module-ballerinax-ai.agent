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
import ballerina/lang.regexp;
import ballerina/log;

public type AgentTool record {|
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
    final map<AgentTool> & readonly tools;

    # Register tools to the agent. 
    # These tools will be by the LLM to perform tasks.
    #
    # + tools - A list of tools that are available to the LLM
    # + return - An error if the tool is already registered
    isolated function init((BaseToolKit|Tool)... tools) returns error? {
        if tools.length() == 0 {
            return error("Initialization failed.", cause = "No tools provided to the agent.");
        }
        Tool[] toolList = [];
        foreach BaseToolKit|Tool tool in tools {
            if tool is BaseToolKit {
                Tool[] toolsFromToolKit = tool.getTools(); // TODO remove this after Ballerina fixes nullpointer exception
                toolList.push(...toolsFromToolKit);
            } else {
                toolList.push(tool);
            }
        }
        map<AgentTool & readonly> toolMap = {};
        check registerTool(toolMap, toolList);
        self.tools = toolMap.cloneReadOnly();
    }

    # execute the tool decided by the LLM.
    #
    # + action - Action object that contains the tool name and inputs
    # + return - ActionResult containing the results of the tool execution or an error if tool execution fails
    isolated function execute(SelectedTool action) returns ToolOutput|error {
        string name = action.name;
        map<json>? inputs = action.arguments;

        if !self.tools.hasKey(name) {
            return error ToolNotFoundError("Cannot find the tool.", toolName = name, instruction = string `Tool "${name}" does not exists. Use a tool from the list: ${self.extractToolInfo().toolList}`);
        }

        map<json>|error inputValues = mergeInputs(inputs, self.tools.get(name).constants);
        if inputValues is error {
            return error ToolInvalidInputError("Tool is provided with invalid inputs.", inputValues, toolName = name, inputs = inputs ?: (), instruction = string `Tool "${name}"  execution failed due to invalid inputs provided. Use the schema to provide inputs: ${self.tools.get(name).variables.toString()}`);
        }
        isolated function caller = self.tools.get(name).caller;
        any|error observation;
        do {
            if inputValues.length() == 0 {
                observation = trap check function:call(caller);
            } else {
                map<json> & readonly toolParams = inputValues.cloneReadOnly();
                observation = trap check function:call(caller, toolParams);
            }
        } on fail error e {
            return {value: e};
        }
        if observation is error && observation.message() == "{ballerina/lang.function}IncompatibleArguments" {
            return error ToolInvalidInputError("Tool is provided with invalid inputs.", observation, toolName = name, inputs = inputValues.length() == 0 ? {} : inputValues, instruction = string `Tool "${name}"  execution failed due to invalid inputs provided. Use the schema to provide inputs: ${self.tools.get(name).variables.toString()}`);
        }
        if observation is anydata|error {
            return {value: observation};
        }
        return error ToolInvaludOutputError("Tool returns an invalid output. Expected anydata or error.", outputType = typeof observation, toolName = name, inputs = inputValues.length() == 0 ? {} : inputValues);
    }

    # Generate descriptions for the tools registered.
    #
    # + return - Return a record with tool names and descriptions
    isolated function extractToolInfo() returns ToolInfo {
        string[] toolNameList = [];
        string[] toolIntroList = [];

        map<AgentTool> tools = self.tools;
        foreach AgentTool tool in tools {
            toolNameList.push(string `${tool.name}`);
            record {|string description; JsonInputSchema inputSchema?;|} toolDescription = {
                description: tool.description,
                inputSchema: tool.variables
            };
            toolIntroList.push(tool.name + ": " + toolDescription.toString());
        }
        return {
            toolList: string:'join(", ", ...toolNameList).trim(),
            toolIntro: string:'join("\n", ...toolIntroList).trim()
        };
    }
}

isolated function registerTool(map<AgentTool & readonly> toolMap, Tool[] tools) returns error? {
    foreach Tool tool in tools {
        string name = tool.name;
        if toolMap.hasKey(name) {
            return error("Duplicated tools. Tool name should be unique.", toolName = name);
        }
        if name.toLowerAscii().matches(FINAL_ANSWER_REGEX) {
            return error(string ` Tool name '${name}' is reserved for the 'Final answer'.`);
        }
        if !name.matches(re `^[a-zA-Z0-9_-]{1,64}$`) {
            log:printWarn(string `Tool name '${name}' contains invalid characters. Only alphanumeric, underscore and hyphen are allowed.`);
            if name.length() > 64 {
                name = name.substring(0, 64);
            }
            name = regexp:replaceAll(re `[^a-zA-Z0-9_-]`, name, "_");
        }

        JsonInputSchema? variables = check tool.parameters.cloneWithType();
        map<json> constants = {};

        if variables is JsonInputSchema {
            constants = resolveSchema(variables) ?: {};
        }

        AgentTool agentTool = {
            name,
            description: regexp:replaceAll(re `\n`, tool.description, " "),
            variables,
            constants,
            caller: tool.caller
        };
        toolMap[name] = agentTool.cloneReadOnly();
    }
}

isolated function resolveSchema(JsonInputSchema schema) returns map<json>? {
    // TODO fix when all values are removed as constant, to use null schema
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
                string tempKey = key; // TODO temporary reference to fix java null pointer issue
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
        } else {
            inputs[key] = value;
        }
    }
    return inputs;
}
