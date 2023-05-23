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
import ballerinax/ai.agent;
import ballerina/io;

configurable string openAIToken = ?;
configurable string wifiAPIUrl = ?;
configurable string wifiTokenUrl = ?;
configurable string wifiClientId = ?;
configurable string wifiClientSecret = ?;
configurable string gmailToken = ?;

// define send mail tool as a function
isolated function sendMail(*gmail:MessageRequest messageRequest) returns string|error {
    gmail:MessageRequest message = check messageRequest.cloneWithType();
    message["contentType"] = "text/plain";
    gmail:Client gmail = check new ({auth: {token: gmailToken}});
    gmail:Message|error sendMessage = gmail->sendMessage(message);
    if sendMessage is gmail:Message {
        return sendMessage.toString();
    }
    return "Error while sending the email" + sendMessage.message();
}

const string DEFAULT_QUERY = "create a new wifi account with user newGuest and password jh123. " +
"Send the available list of wifi accounts for that email to alica@wso2.com";

public function main(string query = DEFAULT_QUERY) returns error? {

    agent:Tool sendEmailTool = {
        name: "Send mail",
        description: "useful send emails to the recipients.",
        inputSchema: {
            'type: agent:OBJECT,
            properties: {
                recipient: {'type: agent:STRING},
                subject: {'type: agent:STRING},
                messageBody: {'type: agent:STRING}
            }
        },
        caller: sendMail
    };

    agent:HttpTool[] httpTools = [
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
                'type: agent:OBJECT,
                properties: {
                    email: {'type: agent:STRING},
                    username: {'type: agent:STRING},
                    password: {'type: agent:STRING}
                }
            }
        }
    ];

    // Create the Http toolkit (easily load http tools for a given API) 
    agent:HttpServiceToolKit wifiApiToolKit = check new (wifiAPIUrl, httpTools, {
        auth: {
            tokenUrl: wifiTokenUrl,
            clientId: wifiClientId,
            clientSecret: wifiClientSecret
        }
    });

    agent:ChatGptModel model = check new ({auth: {token: openAIToken}});
    agent:Agent agent = check new (model, wifiApiToolKit, sendEmailTool);

    // Execute the query using agent iterator
    int iter = 0;
    foreach agent:ExecutionStep result in agent.getIterator(query, context = {"userEmail": "johnny@wso2.com"}) {
        io:println(result.thought);
        any|error observation = result?.observation;
        if observation !is () {
            io:print("Observation: ");
            io:println(observation);
        }
        iter += 1;
        if iter == 5 {
            break;
        }
    }
}
