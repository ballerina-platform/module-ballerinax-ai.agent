// Copyright (c) 2023 WSO2 LLC (http://www.wso2.org) All Rights Reserved.

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
import nadheeshjihan/agent;

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

public function listGuestWifi(*WifiGetParams params) returns string|error {
    string path = string `/guest-wifi-accounts/${params.email}`;
    http:Response response = check wifiClient->get(path);
    return response.getTextPayload();
}

public function addGuestWifi(*WifiCreateParams params) returns string|error {
    string path = "/guest-wifi-accounts";
    json payload = params;
    http:Response response = check wifiClient->post(path, message = payload);
    return response.getTextPayload();
}

public function main() returns error? {
    string query = "create a new guest wifi with user newWifiacc and password abc123 and show available accounts. email is nad123new@wso2.com";

    // 1) Create the model (brain of the agent)
    agent:GPT3Model model = check new ({auth: {token: openAIToken}});

    // 2) Define functions as actions 
    agent:Action listwifi = {
        name: "List_Wifi",
        description: "useful to list the guest wifi accounts",
        inputs: {"email": "string"},
        caller: listGuestWifi
    };

    agent:Action addWifi = {
        name: "Add_Wifi",
        description: "useful to add a new guest wifi account",
        inputs: {"email": "string", "username": "string", "password": "string"},
        caller: addGuestWifi
    };

    // 2) Create the agent 
    agent:Agent agent = check new (model, listwifi, addWifi);

    // 3) Run the agent with user's query
    check agent.run(query);
}
