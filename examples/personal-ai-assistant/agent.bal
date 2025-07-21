// Copyright (c) 2025 WSO2 LLC (http://www.wso2.com).
// WSO2 LLC. licenses this file to you under the Apache License,
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

import ballerinax/ai;
import ballerinax/googleapis.calendar;
import ballerinax/googleapis.gmail;

configurable string googleRefreshToken = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string refreshUrl = ?;

configurable string openAiApiKey = ?;

configurable string userName = ?;
configurable string userEmail = ?;

final gmail:Client gmailClient = check new gmail:Client(config = {
    auth: {refreshToken: googleRefreshToken, clientId, clientSecret, refreshUrl}
});

final calendar:Client calendarClient = check new (config = {
    auth: {clientId, clientSecret, refreshToken: googleRefreshToken, refreshUrl}
});

@ai:AgentTool
isolated function readEmails() returns gmail:Message[]|error {
    gmail:ListMessagesResponse messageList = check gmailClient->/users/me/messages(q = "label:INBOX is:unread");
    gmail:Message[] messages = messageList.messages ?: [];
    gmail:Message[] completeMessages = [];
    foreach gmail:Message message in messages {
        gmail:Message completeMsg = check gmailClient->/users/me/messages/[message.id](format = "full");
        completeMessages.push(completeMsg);
    }
    return completeMessages;
}

@ai:AgentTool
isolated function sendEmail(string[] to, string subject, string body) returns gmail:Message|error {
    gmail:MessageRequest requestMessage = {to, subject, bodyInText: body};
    return gmailClient->/users/me/messages/send.post(requestMessage);
}

@ai:AgentTool
isolated function getCalanderEvents() returns stream<calendar:Event, error?>|error {
    return calendarClient->getEvents(userEmail);
}

@ai:AgentTool
isolated function createCalanderEvent(calendar:InputEvent event) returns calendar:Event|error {
    return calendarClient->createEvent(userEmail, event);
}

ai:SystemPrompt systemPrompt = {
    role: "Personal AI Assistant",
    instructions: string `You are Nova, an intelligent personal AI assistant designed to help '${userName}' stay organized and efficient.
Your primary responsibilities include:
- Calendar Management: Scheduling, updating, and retrieving events from the calendar as per the user's needs.
- Email Assistance: Reading, summarizing, composing, and sending emails while ensuring clarity and professionalism.
- Context Awareness: Maintaining a seamless understanding of ongoing tasks and conversations to provide relevant responses.
- Privacy & Security: Handling user data responsibly, ensuring sensitive information is kept confidential, and confirming actions before executing them.
Guidelines:
- Respond in a natural, friendly, and professional tone.
- Always confirm before making changes to the user's calendar or sending emails.
- Provide concise summaries when retrieving information unless the user requests details.
- Prioritize clarity, efficiency, and user convenience in all tasks.`
};

final ai:OpenAiProvider openAiModel = check new (openAiApiKey, modelType = ai:GPT_4O);
final ai:Agent personalAiAssistantAgent = check new (
    systemPrompt = systemPrompt,
    model = openAiModel,
    tools = [readEmails, sendEmail, getCalanderEvents, createCalanderEvent],
    memory = new ai:MessageWindowChatMemory(20)
);
