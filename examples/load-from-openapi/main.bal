// Copyright (c) 2023 WSO2 LLC (http://www.wso2.com).
//
// WSO2 Inc. licenses this file to you under the Apache License,
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
import wso2/ai.agent;

configurable string wifiAPIUrl = ?;
configurable string wifiTokenUrl = ?;
configurable string wifiClientId = ?;
configurable string wifiClientSecret = ?;

configurable string apiKey = ?;
configurable string deploymentId = ?;
configurable string apiVersion = ?;
configurable string serviceUrl = ?;

const string OPENAPI_PATH = "openapi.json";

const string DEFAULT_QUERY = "create a new guest wifi with user openAPIwifi and password abc123 and show available accounts";

public function main(string openAPIPath = OPENAPI_PATH, string query = DEFAULT_QUERY) returns error? {

    // 1) Create the model (brain of the agent)
    agent:AzureChatGptModel model = check new ({auth: {apiKey}}, serviceUrl, deploymentId, apiVersion);

    // 2) Extract tools from openAPI specification
    final agent:HttpApiSpecification apiSpecification = check agent:extractToolsFromOpenApiSpecFile(openAPIPath);

    // 3) Createn httpToolKit with the extract tools from openAPI specification
    agent:HttpServiceToolKit toolKit = check new (wifiAPIUrl, apiSpecification.tools, {
        auth: {
            tokenUrl: wifiTokenUrl,
            clientId: wifiClientId,
            clientSecret: wifiClientSecret
        }
    });

    // 3) Create the agent
    agent:ReActAgent agent = check new (model, toolKit);

    // 4) Execute the user's query
    _ = agent:run(agent, query, context = {"email": "johnw@gmail.com"});

}
