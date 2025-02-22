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

import ballerina/jballerina.java;

isolated function getToolParameterTypes(FunctionTool functionPointer) returns map<typedesc<anydata>> {
    map<any> typedescriptors = getParameterTypes(functionPointer);
    map<typedesc<anydata>> anydataTypeDesc = {};
    foreach [string, any] [parmeterName, typedescriptor] in typedescriptors.entries() {
        if typedescriptor is typedesc<anydata> {
            anydataTypeDesc[parmeterName] = typedescriptor;
        }
    }
    return anydataTypeDesc;
}

isolated function getParameterTypes(FunctionTool functionPointer) returns map<any> = @java:Method {
    'class: "io.ballerina.lib.ai.Utils"
} external;

isolated function isMapType(typedesc<anydata> typedescVal) returns boolean = @java:Method {
    'class: "io.ballerina.lib.ai.Utils"
} external;

isolated function getFunctionName(FunctionTool toolFunction) returns string = @java:Method {
    'class: "io.ballerina.lib.ai.Utils"
} external;

isolated function getArgsWithDefaultValues(FunctionTool toolFunction, map<anydata> value)
returns map<anydata> = @java:Method {
    'class: "io.ballerina.lib.ai.Utils"
} external;
