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

import ballerinax/ai;

@ai:Tool
isolated function toolWithString(string param) => ();

@ai:Tool
isolated function toolWithInt(int param) => ();

@ai:Tool
isolated function toolWithFloat(float param) => ();

@ai:Tool
isolated function toolWithDecimal(decimal param) => ();

@ai:Tool
isolated function toolWithByte(byte param) => ();

@ai:Tool
isolated function toolWithBoolean(boolean param) => ();

@ai:Tool
isolated function toolWithJson(json param) => ();

@ai:Tool
isolated function toolWithJsonMap(map<json> param) => ();

@ai:Tool
isolated function toolWithStringArray(string[] param) => ();

@ai:Tool
isolated function toolWithByteArray(byte[] param) => ();

@ai:Tool
isolated function toolWithRecord(User user) => ();

@ai:Tool
isolated function toolWithTable(table<User> users) => ();

@ai:Tool
isolated function toolWithEnum(Status staus) => ();

// The generated schema should not have `param` as required field
@ai:Tool
isolated function toolWithDefaultParam(string param = "default") => ();

@ai:Tool
isolated function toolWithUnion(string|int|float|decimal|boolean|byte|Status|User|json|map<json>|table<User> param) => ();

@ai:Tool
isolated function toolWithTypeAlias(Data data) => ();

@ai:Tool
isolated function toolWithIncludedRecord(*Person person) => ();

@ai:Tool
isolated function toolWithMultipleParams(int a, string b, decimal c, float d, User e,
        table<User> f, User[] g, Data h = ()) => ();

# Tool descriptoin 
# + person - First parameter description
# + salary - Second parameter description
@ai:Tool
isolated function toolWithDocumentation(Person person, decimal salary) => ();

# Tool descriptoin 
# + person - First parameter description
# + salary - Second parameter description
@ai:Tool {
    name: "overriddenFunctionName"
}
isolated function toolWithOverriddenFunctionName(Person person, decimal salary) => ();

# Tool descriptoin 
# + person - First parameter description
# + salary - Second parameter description
@ai:Tool {
    description: "overridden description"
}
isolated function toolWithOverriddenDescription(Person person, decimal salary) => ();

# Tool descriptoin 
# + person - First parameter description
# + salary - Second parameter description
@ai:Tool {
    parameters: {
        properties: {
            person: {'type: "string"}
        },
        required: ["person"]
    }
}
isolated function toolWithOverriddenParameterSchema(Person person, decimal salary) => ();

# Tool descriptoin 
# + person - First parameter description
# + salary - Second parameter description
@ai:Tool {
    parameters: {
        properties: {
            person: {'type: "string"}
        },
        required: ["person"]
    },
    name: "overriddenName",
    description: "overridden description"
}
isolated function toolWithOverriddenConfig(Person person, decimal salary) => ();
