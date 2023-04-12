// // Copyright (c) 2023 WSO2 LLC (http://www.wso2.org) All Rights Reserved.

// // WSO2 Inc. licenses this file to you under the Apache License,
// // Version 2.0 (the "License"); you may not use this file except
// // in compliance with the License.
// // You may obtain a copy of the License at

// // http://www.apache.org/licenses/LICENSE-2.0

// // Unless required by applicable law or agreed to in writing,
// // software distributed under the License is distributed on an
// // "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// // KIND, either express or implied.  See the License for the
// // specific language governing permissions and limitations
// // under the License.

// import ballerinax/googleapis.gmail;

// configurable string openAIToken = ?;
// configurable string wifiAPIUrl = ?;
// configurable string wifiTokenUrl = ?;
// configurable string wifiClientId = ?;
// configurable string wifiClientSecret = ?;
// configurable string gmailToken = ?;

// function sendMail(*gmail:MessageRequest messageRequest) returns string|error {
//     gmail:MessageRequest message = check messageRequest.cloneWithType();
//     message["contentType"] = "text/plain";
//     gmail:Client gmail = check new ({auth: {token: gmailToken}});
//     gmail:Message|error sendMessage = gmail->sendMessage(message);
//     if sendMessage is gmail:Message {
//         return sendMessage.toString();
//     }
//     return "Error while sending the email. " + sendMessage.message();
// }

// public function main() returns error? {

//     string query = "create a new guest wifi account for email nad@gmail.com with user newWifi123 and password pass123. send the avaialbe list of wifi accounts for that email to nadheesh@wso2.com";

//     // 1) Create the model (brain of the agent)
//     GPT3Model model = check new ({auth: {token: openAIToken}});

//     // 2) Register the http actions to the Http loader
//     Action sendEmailAction = {
//         name: "Send mail",
//         description: "useful send emails to the recipients.",
//         inputs: {
//             "recipient": "string",
//             "subject": "string",
//             "messageBody": "string"
//         },
//         caller: sendMail
//     };

//     HttpAction[] httpActions = [
//         {
//             name: "List wifi",
//             path: "/guest-wifi-accounts/{ownerEmail}",
//             method: GET,
//             description: "useful to list the guest wifi accounts."
//         },
//         {
//             name: "Create wifi",
//             path: "/guest-wifi-accounts",
//             method: POST,
//             description: "useful to create a guest wifi account.",
//             requestBody: {
//                 "email": "string",
//                 "username": "string",
//                 "password": "string"
//             }
//         }
//     ];

//     // 3) Create the HttpLoader (easily load http actions for a given API)
//     HttpClientConfig clientConfig = {
//         auth: {
//             tokenUrl: wifiTokenUrl,
//             clientId: wifiClientId,
//             clientSecret: wifiClientSecret
//         }
//     };
//     HttpActionLoader wifiApiLoader = check new (wifiAPIUrl, httpActions, clientConfig);

//     // 3) Create the agent  
//     Agent agent = check new (model, wifiApiLoader, sendEmailAction);

//     // 5) Run the agent to execute user's query
//     check agent.run(query, maxIter = 5);

//     // string msg = check sendMail({
//     //     recipient: "nadheesh@wso2.com",
//     //     subject: "Test mail",
//     //     messageBody: "this is message body" 
//     // });
//     // io:println(msg);
// }
