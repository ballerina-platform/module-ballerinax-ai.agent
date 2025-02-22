// Copyright (c) 2023 WSO2 LLC (http://www.wso2.com).
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
import ballerina/http;
import wso2/ai.agent;

configurable string openAIToken = ?;
configurable string wifiAPIUrl = ?;
configurable string wifiTokenUrl = ?;
configurable string wifiClientId = ?;
configurable string wifiClientSecret = ?;

public type WifiGetParams record {|
    string email;
|};

public type WifiCreateParams record {|
    *WifiGetParams;
    string username;
    string password;
|};

final http:Client wifiClient = check new (wifiAPIUrl, {
    auth: {
        tokenUrl: wifiTokenUrl,
        clientId: wifiClientId,
        clientSecret: wifiClientSecret
    }
});

public isolated function listGuestWifi(WifiGetParams params) returns json|error {
    return check wifiClient->/guest\-wifi\-accounts/[params.email];
}

public isolated function addGuestWifi(WifiCreateParams params) returns string|error {
    return check wifiClient->/guest\-wifi\-accounts.post(params);
}

const string DEFAULT_QUERY = "create a new guest wifi with user guestJohn and password abc123 and show available accounts";

public function main(string query = DEFAULT_QUERY) returns error? {

    // 1) Create the model (brain of the agent)
    agent:ChatGptModel model = check new ({auth: {token: openAIToken}});

    // 2) Define functions as tools 
    agent:Tool listwifi = {
        name: "List_Wifi",
        description: "useful to list the guest wifi accounts",
        parameters: {
            properties: {
                email: {
                    'type: "string"
                }
            }
        },
        caller: listGuestWifi
    };

    agent:Tool addWifi = {
        name: "Add_Wifi",
        description: "useful to add a new guest wifi account",
        parameters: {
            properties: {
                email: {
                    'type: "string"
                },
                username: {
                    'type: "string"
                },
                password: {
                    'type: "string"
                }
            }
        },
        caller: addGuestWifi
    };

    // 2) Create the agent 
    agent:ReActAgent agent = check new (model, listwifi, addWifi);

    // 3) Run the agent with user's query
    _ = agent:run(agent, query, context = {"email": "alex@wso2.com"});
}
