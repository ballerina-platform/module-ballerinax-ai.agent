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
import ballerinax/ai;

@test:Config {
    dataProvider: getTools
}
function validateGeneratedSchema(string functionName, ai:FunctionTool tool) returns error? {
    ai:ToolAnnotationConfig generatedConfig = check getToolConfig(tool);
    ai:ToolAnnotationConfig expectedConfig = check getExpectedToolConfig(functionName);
    test:assertEquals(generatedConfig, expectedConfig);
}

function getToolConfig(ai:FunctionTool tool) returns ai:ToolAnnotationConfig|error {
    typedesc<ai:FunctionTool> functionTypedesc = typeof tool;
    return functionTypedesc.@ai:Tool.ensureType();
}

function getExpectedToolConfig(string functionName) returns ai:ToolAnnotationConfig|error {
    json schema = check io:fileReadJson(string `./resources/expected-schemas/${functionName}.json`);
    return schema.cloneWithType();
}

function getTools() returns map<[string, ai:FunctionTool]> => {
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
