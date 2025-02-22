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

enum Status {
    ON,
    OFF
}

type User record {|
    string name;
    int age;
|};

# Tool description
# + param - parameter description
@ai:Tool
isolated function toolOne(string|int|float|decimal|boolean|byte|Status|User|json|map<json>|table<User> param) => ();

# Tool description
# + param - parameter description
@ai:Tool {}
isolated function toolTwo(string|int|float|decimal|boolean|byte|Status|User|json|map<json>|table<User> param) => ();

# Tool description
# + param - parameter description
@ai:Tool {

}
isolated function toolThree(string|int|float|decimal|boolean|byte|Status|User|json|map<json>|table<User> param) => ();

# Tool description
# + param - parameter description
@ai:Tool {
    name: "toolFourNewName"
}
isolated function toolFour(string|int|float|decimal|boolean|byte|Status|User|json|map<json>|table<User> param) => ();

# Tool description
# + param - parameter description
@ai:Tool {
    name: "toolFiveNewName",
    parameters: {
        properties: {
            param: {'type: "string"}
        },
        required: ["param"]
    }
}
isolated function toolFive(string|int|float|decimal|boolean|byte|Status|User|json|map<json>|table<User> param) => ();

@ai:Tool
isolated function toolWithAny(string name, any data) => ();
