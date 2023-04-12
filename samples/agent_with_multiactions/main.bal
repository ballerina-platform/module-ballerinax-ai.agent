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

import ballerinax/googleapis.gmail;
import nadheeshjihan/agent;

configurable string openAIToken = ?;
configurable string wifiAPIUrl = ?;
configurable string wifiTokenUrl = ?;
configurable string wifiClientId = ?;
configurable string wifiClientSecret = ?;
configurable string gmailToken = ?;

// define sendmail action as a function
function sendMail(*gmail:MessageRequest messageRequest) returns string|error {
    gmail:MessageRequest message = check messageRequest.cloneWithType();
    message["contentType"] = "text/plain";
    gmail:Client gmail = check new ({auth: {token: gmailToken}});
    gmail:Message|error sendMessage = gmail->sendMessage(message);
    if sendMessage is gmail:Message {
        return sendMessage.toString();
    }
    return "Error while sending the email" + sendMessage.message();
}

public function main(string wifiOwnerEmail, string wifiUsername, string wifiPassword, string recipientEmail) returns error? {

    string queryTemplate = string `create a new guest wifi account for email ${wifiOwnerEmail} with user ${wifiUsername} and password ${wifiPassword}. Send the avaialbe list of wifi accounts for that email to ${recipientEmail}`;

    agent:Action sendEmailAction = {
        name: "Send mail",
        description: "useful send emails to the recipients.",
        inputs: {
            "recipient": "string",
            "subject": "string",
            "messageBody": "string"
        },
        caller: sendMail
    };

    agent:HttpAction[] httpActions = [
        {
            name: "List wifi",
            path: "/guest-wifi-accounts/{ownerEmail}",
            method: agent:GET,
            description: "useful to list the guest wifi accounts."
        },
        {
            name: "Create wifi",
            path: "/guest-wifi-accounts",
            method: agent:POST,
            description: "useful to create a guest wifi account.",
            requestBody: {
                "email": "string",
                "username": "string",
                "password": "string"
            }
        }
    ];

    // 3) Create the HttpLoader (easily load http actions for a given API)
    agent:HttpClientConfig clientConfig = {
        auth: {
            tokenUrl: wifiTokenUrl,
            clientId: wifiClientId,
            clientSecret: wifiClientSecret
        }
    };
    agent:HttpActionLoader wifiApiAction = check new (wifiAPIUrl, httpActions, clientConfig);
    agent:GPT3Model model = check new ({auth: {token: openAIToken}});
    agent:Agent agent = check new (model, wifiApiAction, sendEmailAction);
    check agent.run(queryTemplate, maxIter = 5);
}
