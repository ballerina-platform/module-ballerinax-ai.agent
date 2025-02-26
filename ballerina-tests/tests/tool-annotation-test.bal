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

import ballerina/io;
import ballerina/test;
import ballerinax/ai.agent;

@test:Config {
    dataProvider: getTools
}
function validateGeneratedSchema(string functionName, agent:FunctionTool tool) returns error? {
    agent:ToolAnnotationConfig generatedConfig = check getToolConfig(tool);
    agent:ToolAnnotationConfig expectedConfig = check getExpectedToolConfig(functionName);
    test:assertEquals(generatedConfig, expectedConfig);
}

function getToolConfig(agent:FunctionTool tool) returns agent:ToolAnnotationConfig|error {
    typedesc<agent:FunctionTool> functionTypedesc = typeof tool;
    return functionTypedesc.@agent:Tool.ensureType();
}

function getExpectedToolConfig(string functionName) returns agent:ToolAnnotationConfig|error {
    json schema = check io:fileReadJson(string `./resources/expected-schemas/${functionName}.json`);
    return schema.cloneWithType();
}

function getTools() returns map<[string, agent:FunctionTool]> => {
    toolWithString: ["toolWithString", toolWithString],
    toolWithInt: ["toolWithInt", toolWithInt],
    toolWithFloat: ["toolWithFloat", toolWithFloat],
    toolWithDecimal: ["toolWithDecimal", toolWithDecimal],
    toolWithByte: ["toolWithByte", toolWithByte],
    toolWithBoolean: ["toolWithBoolean", toolWithBoolean],
    toolWithJson: ["toolWithJson", toolWithJson],
    toolWithJsonMap: ["toolWithJsonMap", toolWithJsonMap],
    toolWithStringArray: ["toolWithStringArray", toolWithStringArray],
    toolWithByteArray: ["toolWithByteArray", toolWithByteArray],
    toolWithRecord: ["toolWithRecord", toolWithRecord],
    toolWithTable: ["toolWithTable", toolWithTable],
    toolWithEnum: ["toolWithEnum", toolWithEnum],
    toolWithDefaultParam: ["toolWithDefaultParam", toolWithDefaultParam],
    toolWithUnion: ["toolWithUnion", toolWithUnion],
    toolWithTypeAlias: ["toolWithTypeAlias", toolWithTypeAlias],
    toolWithIncludedRecord: ["toolWithIncludedRecord", toolWithIncludedRecord],
    toolWithMultipleParams: ["toolWithMultipleParams", toolWithMultipleParams],
    toolWithDocumentation: ["toolWithDocumentation", toolWithDocumentation],
    toolWithOverriddenFunctionName: ["toolWithOverriddenFunctionName", toolWithOverriddenFunctionName],
    toolWithOverriddenDescription: ["toolWithOverriddenDescription", toolWithOverriddenDescription],
    toolWithOverriddenParameterSchema: ["toolWithOverriddenParameterSchema", toolWithOverriddenParameterSchema],
    toolWithOverriddenConfig: ["toolWithOverriddenConfig", toolWithOverriddenConfig]
};
