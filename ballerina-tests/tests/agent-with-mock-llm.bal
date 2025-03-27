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

import ballerina/lang.regexp;
import ballerinax/ai.agent;

isolated function getNumbers(string prompt) returns string[] {
    regexp:Span[] spans = re `-?\d+\.?\d*`.findAll(prompt);
    return spans.'map(span => span.substring());
}

isolated function getAnswer(string prompt) returns string {
    var result = re `.*(Answer is: .*)\n?`.findGroups(prompt);
    if result is () || result.length() <= 1 {
        return "Sorry! I don't know the answer";
    }
    var answer = result[1];
    return answer is () ? "Sorry! I don't know the answer" : answer.substring();
}

isolated function getDecimals(string[] numbers) returns decimal[] {
    decimal[] decimalVals = [];
    foreach var num in numbers {
        decimal|error decimalVal = decimal:fromString(num);
        decimalVals.push(decimalVal is decimal ? decimalVal : 0d);
    }
    return decimalVals;
}

isolated function getInt(string number) returns int {
    int|error intVal = int:fromString(number);
    return intVal is int ? intVal : 0;
}

type MockLlmToolCall record {|
    string action;
    json action_input;
|};

@agent:Tool
isolated function sum(decimal[] numbers) returns string {
    decimal total = 0;
    foreach decimal number in numbers {
        total += number;
    }
    return string `Answer is: ${total}`;
}

@agent:Tool
isolated function mutiply(int a, int b) returns string {
    return string `Answer is: ${a * b}`;
}

@agent:Tool
isolated function getEmails() returns stream<Mail, agent:Error?>|error? {
    return [{body: "Mail Body 1"}, {body: "Mail Body 2"}, {body: "Mail Body 3"}].toStream();
}

isolated client distinct class MockLlm {
    *agent:Model;

    isolated remote function chat(agent:ChatMessage[] messages, agent:ChatCompletionFunctions[] tools, string? stop)
        returns agent:ChatAssistantMessage|agent:LlmError {
        agent:ChatMessage lastMessage = messages.pop();
        string query = lastMessage is agent:ChatUserMessage|agent:ChatFunctionMessage ? lastMessage.content ?: "" : "";
        if query.includes("Mail Body") {
            MockLlmToolCall toolCall = {action: "Final answer", action_input: query};
            return getChatAssistantMessage(string `Answer is:  ${toolCall.toJsonString()})`);
        }
        if query.includes("Answer is:") {
            MockLlmToolCall toolCall = {action: "Final answer", action_input: getAnswer(query)};
            return getChatAssistantMessage(string `Answer is:  ${toolCall.toJsonString()})`);
        }
        if query.toLowerAscii().includes("mail") {
            MockLlmToolCall toolCall = {action: "getEmails", action_input: {}};
            return getChatAssistantMessage(string `I need to call the searchDoc tool. Action: ${toolCall.toJsonString()}`);
        }
        if query.toLowerAscii().includes("search") {
            regexp:Span? span = re `'.*'`.find(query);
            string searchQuery = span is () ? "No search query" : span.substring();
            MockLlmToolCall toolCall = {action: "searchDoc", action_input: {searchQuery}};
            return getChatAssistantMessage(string `I need to call the searchDoc tool. Action: ${toolCall.toJsonString()}`);
        }
        if query.toLowerAscii().includes("sum") || query.toLowerAscii().includes("add") {
            decimal[] numbers = getDecimals(getNumbers(query));
            MockLlmToolCall toolCall = {action: "sum", action_input: {numbers}};
            return getChatAssistantMessage(string `I need to call the sum tool. Action: ${toolCall.toJsonString()}`);
        }
        if query.toLowerAscii().includes("mult") || query.toLowerAscii().includes("prod") {
            string[] numbers = getNumbers(query);
            int a = getInt(numbers.shift());
            int b = getInt(numbers.shift());
            MockLlmToolCall toolCall = {action: "mutiply", action_input: {a, b}};
            return getChatAssistantMessage(string `I need to call the sum tool. Action: ${toolCall.toJsonString()}`);
        }
        return error agent:LlmError("I can't understand");
    }
}

isolated function getChatAssistantMessage(string content) returns agent:ChatAssistantMessage {
    return {role: agent:ASSISTANT, content};
}

final MockLlm model = new;
final agent:Agent agent = check new (model = model,
    systemPrompt = {role: "Math tutor", instructions: "Help the students with their questions."},
    tools = [sum, mutiply, new SearchToolKit(), getEmails], agentType = agent:REACT_AGENT
);

isolated class SearchToolKit {
    *agent:BaseToolKit;

    public isolated function getTools() returns agent:ToolConfig[] {
        return agent:getToolConfigs([self.searchDoc]);
    }

    @agent:Tool
    public isolated function searchDoc(string searchQuery) returns string {
        return string `Answer is: No result found on doc for ${searchQuery}`;
    }
}
