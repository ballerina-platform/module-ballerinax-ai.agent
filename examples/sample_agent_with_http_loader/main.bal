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

import ballerinax/agent;

configurable string openAIToken = ?;
configurable string wifiAPIUrl = ?;
configurable string wifiTokenUrl = ?;
configurable string wifiClientId = ?;
configurable string wifiClientSecret = ?;

public function main() returns error? {
    string query = "create a new guest wifi with user newWifi and password abc123 and show available accounts. email is nad123new@wso2.com";

    // 1) Create the model (brain of the agent)
    agent:GPT3Model model = new (check new ({auth: {token: openAIToken}}), {model: "text-davinci-003"});
    // 2) Create the HttpLoader (easily load http actions for a given API   )
    agent:HttpLoader loader = check new (wifiAPIUrl, {
        auth: {
            tokenUrl: wifiTokenUrl,
            clientId: wifiClientId,
            clientSecret: wifiClientSecret
        }
    });
    // 3) Create the agent
    agent:Agent agent = check new (model, loader);

    // 4) Register the http actions to the Http loader
    agent:HttpAction listAction = {
        name: "List wifi",
        path: "/guest-wifi-accounts/{ownerEmail}",
        method: agent:GET,
        description: "useful to list the guest wifi accounts."
    };
    agent:HttpAction createAction = {
        name: "Create wifi",
        path: "/guest-wifi-accounts",
        method: agent:POST,
        description: "useful to create a guest wifi account.",
        requestBody: {
            "email": "string",
            "username": "string",
            "password": "string"
        }
    };
    check loader.registerActions(listAction, createAction);

    // 5) Run the agent to execute user's query
    check agent.run(query, maxIter = 5);
}
