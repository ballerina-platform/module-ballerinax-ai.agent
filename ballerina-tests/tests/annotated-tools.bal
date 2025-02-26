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

import ballerinax/ai.agent;

@agent:Tool
isolated function toolWithString(string param) => ();

@agent:Tool
isolated function toolWithInt(int param) => ();

@agent:Tool
isolated function toolWithFloat(float param) => ();

@agent:Tool
isolated function toolWithDecimal(decimal param) => ();

@agent:Tool
isolated function toolWithByte(byte param) => ();

@agent:Tool
isolated function toolWithBoolean(boolean param) => ();

@agent:Tool
isolated function toolWithJson(json param) => ();

@agent:Tool
isolated function toolWithJsonMap(map<json> param) => ();

@agent:Tool
isolated function toolWithStringArray(string[] param) => ();

@agent:Tool
isolated function toolWithByteArray(byte[] param) => ();

@agent:Tool
isolated function toolWithRecord(User user) => ();

@agent:Tool
isolated function toolWithTable(table<User> users) => ();

@agent:Tool
isolated function toolWithEnum(Status staus) => ();

// The generated schema should not have `param` as required field
@agent:Tool
isolated function toolWithDefaultParam(string param = "default") => ();

@agent:Tool
isolated function toolWithUnion(string|int|float|decimal|boolean|byte|Status|User|json|map<json>|table<User> param) => ();

@agent:Tool
isolated function toolWithTypeAlias(Data data) => ();

@agent:Tool
isolated function toolWithIncludedRecord(*Person person) => ();

@agent:Tool
isolated function toolWithMultipleParams(int a, string b, decimal c, float d, User e,
        table<User> f, User[] g, Data h = ()) => ();

# Tool description 
# + person - First parameter description
# + salary - Second parameter description
@agent:Tool
isolated function toolWithDocumentation(Person person, decimal salary) => ();

# Tool description 
# + person - First parameter description
# + salary - Second parameter description
@agent:Tool {
    name: "overriddenFunctionName"
}
isolated function toolWithOverriddenFunctionName(Person person, decimal salary) => ();

# Tool description 
# + person - First parameter description
# + salary - Second parameter description
@agent:Tool {
    description: "overridden description"
}
isolated function toolWithOverriddenDescription(Person person, decimal salary) => ();

# Tool description 
# + person - First parameter description
# + salary - Second parameter description
@agent:Tool {
    parameters: {
        properties: {
            person: {'type: "string"}
        },
        required: ["person"]
    }
}
isolated function toolWithOverriddenParameterSchema(Person person, decimal salary) => ();

# Tool description 
# + person - First parameter description
# + salary - Second parameter description
@agent:Tool {
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
