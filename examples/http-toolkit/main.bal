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
import wso2/ai.agent;

configurable string openAIToken = ?;
configurable string wifiAPIUrl = ?;
configurable string wifiTokenUrl = ?;
configurable string wifiClientId = ?;
configurable string wifiClientSecret = ?;

const string DEFAULT_QUERY = "create a new guest wifi with user newWifi and password abc123 and show available accounts";

public function main(string query = DEFAULT_QUERY) returns error? {

    // 1) Register the http actions to the Http tookit
    agent:HttpTool listWifiTool = {
        name: "List wifi",
        path: "/guest-wifi-accounts/{ownerEmail}",
        method: agent:GET,
        description: "useful to list the guest wifi accounts.",
        parameters: {
            ownerEmail: {
                location: agent:PATH,
                schema: {
                    'type: "string"
                }
            }
        }
    };

    agent:HttpTool createWifiTool = {
        name: "Create wifi",
        path: "/guest-wifi-accounts",
        method: agent:POST,
        description: "useful to create a guest wifi account.",
        requestBody: {
            schema: {
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
            }
        }
    };

    agent:HttpServiceToolKit httpToolKit = check new (wifiAPIUrl, [listWifiTool, createWifiTool], {
        auth: {
            tokenUrl: wifiTokenUrl,
            clientId: wifiClientId,
            clientSecret: wifiClientSecret
        }
    });

    // 2) Create the model (brain of the agent)
    agent:ChatGptModel model = check new ({auth: {token: openAIToken}});
    // 3) Create the agent
    agent:FunctionCallAgent agent = check new (model, httpToolKit);
    // 4) Run the agent to execute user's query
    _ = agent:run(agent, query, maxIter = 5, context = "email is john@gmail.com");
}
