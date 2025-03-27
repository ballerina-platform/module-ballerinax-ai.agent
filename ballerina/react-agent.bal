// Copyright (c) 2023 WSO2 LLC (http://www.wso2.com).
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
import ballerina/log;

type ToolInfo readonly & record {|
    string toolList;
    string toolIntro;
|};

# A ReAct Agent that uses ReAct prompt to answer questions by using tools.
public isolated client class ReActAgent {
    *BaseAgent;
    final string instructionPrompt;
    # ToolStore instance to store the tools used by the agent
    public final ToolStore toolStore;
    # LLM model instance to be used by the agent (Can be either CompletionLlmModel or ChatLlmModel)
    public final Model model;
    # The memory associated with the agent.
    public final MemoryManager memoryManager;

    # Initialize an Agent.
    #
    # + model - LLM model instance
    # + tools - Tools to be used by the agent
    public isolated function init(Model model, (BaseToolKit|ToolConfig|FunctionTool)[] tools,
            MemoryManager memoryManager = new DefaultMessageWindowChatMemoryManager()) returns Error? {
        self.toolStore = check new (...tools);
        self.model = model;
        self.memoryManager = memoryManager;
        self.instructionPrompt = constructReActPrompt(extractToolInfo(self.toolStore));
        log:printDebug("Instruction Prompt Generated Successfully", instructionPrompt = self.instructionPrompt);
    }

    # Parse the ReAct llm response and extract the tool to be executed.
    #
    # + llmResponse - Raw LLM response
    # + return - A record containing the tool decided by the LLM, chat response or an error if the response is invalid
    public isolated function parseLlmResponse(json llmResponse)
        returns LlmToolResponse|LlmChatResponse|LlmInvalidGenerationError =>
        parseReActLlmResponse(normalizeLlmResponse(llmResponse.toString()));

    # Use LLM to decide the next tool/step based on the ReAct prompting.
    #
    # + progress - Execution progress with the current query and execution history
    # + memoryId - The ID associated with the agent memory
    # + return - LLM response containing the tool or chat response (or an error if the call fails)
    public isolated function selectNextTool(ExecutionProgress progress, string memoryId = DEFAULT_MEMORY_ID) returns json|LlmError {
        ChatMessage[] messages = [];
        // include the history
        foreach ExecutionStep step in progress.history {
            LlmToolResponse|LlmChatResponse|LlmInvalidGenerationError parsedResponse = self.parseLlmResponse(step.llmResponse);
            if parsedResponse is LlmInvalidGenerationError {
                messages.push({role: ASSISTANT, content: step.llmResponse.toJsonString()});
            } else if parsedResponse is LlmChatResponse {
                messages.push({role: ASSISTANT, content: parsedResponse.content});
            } else {
                messages.push({
                    role: ASSISTANT,
                    toolCalls: [
                        {
                            name: parsedResponse.name,
                            arguments: parsedResponse.arguments.toJsonString(),
                            id: parsedResponse.id
                        }
                    ]
                },
                {
                    role: FUNCTION,
                    name: parsedResponse.name,
                    content: getObservationString(step.observation),
                    id: parsedResponse.id
                });
            }
        }

        Memory|MemoryError memory = self.memoryManager.getMemory(memoryId);
        ChatMessage[]|MemoryError additionalMessages = memory is Memory ? memory.get() : memory;
        if additionalMessages is error {
            log:printError("Failed to get chat messages from memory", additionalMessages);
        } else {
            messages.unshift(...additionalMessages);
        }
        return self.generate(messages);
    }

    # + messages - Chat history to be processed by the ReAct agent
    # + return - The processed chat history
    isolated function generate(ChatMessage[] messages) returns json|LlmError {
        ChatAssistantMessage assistantMessage = check self.model->chat(messages, stop = OBSERVATION_KEY);
        FunctionCall[]? toolCalls = assistantMessage?.toolCalls;
        return toolCalls is FunctionCall[] ? toolCalls[0] : assistantMessage?.content;
    }

    # Execute the agent for a given user's query.
    #
    # + query - Natural langauge commands to the agent  
    # + maxIter - No. of max iterations that agent will run to execute the task (default: 5)
    # + context - Context values to be used by the agent to execute the task
    # + verbose - If true, then print the reasoning steps (default: true)
    # + memoryId - The ID associated with the agent memory
    # + return - Returns the execution steps tracing the agent's reasoning and outputs from the tools
    isolated remote function run(string query, int maxIter = 5, string|map<json> context = {},
            boolean verbose = true, string memoryId = DEFAULT_MEMORY_ID)
        returns record {|(ExecutionResult|ExecutionError)[] steps; string answer?;|} {
        return run(self, query, maxIter, context, verbose, memoryId);
    }
}

isolated function normalizeLlmResponse(string llmResponse) returns string {
    string normalizedResponse = llmResponse.trim();
    if !normalizedResponse.includes(BACKTICKS) {
        if normalizedResponse.startsWith("{") && normalizedResponse.endsWith("}") {
            normalizedResponse = string `${BACKTICKS}${normalizedResponse}${BACKTICKS}`;
        } else {
            int? jsonStart = normalizedResponse.indexOf("{");
            int? jsonEnd = normalizedResponse.lastIndexOf("}");
            if jsonStart is int && jsonEnd is int {
                normalizedResponse = string `${BACKTICKS}${normalizedResponse.substring(jsonStart, jsonEnd + 1)}${BACKTICKS}`;
            }
        }
    }
    normalizedResponse = regexp:replace(re `${BACKTICKS}json`, normalizedResponse, BACKTICKS); // replace ```json  
    normalizedResponse = regexp:replaceAll(re `"\{\}"`, normalizedResponse, "{}"); // replace "{}"
    return normalizedResponse;
}

isolated function parseReActLlmResponse(string llmResponse) returns LlmToolResponse|LlmChatResponse|LlmInvalidGenerationError {
    string[] content = regexp:split(re `${BACKTICKS}`, llmResponse + "<endtoken>");
    if content.length() < 3 {
        log:printWarn("Unexpected LLM response is given", llmResponse = llmResponse);
        return error LlmInvalidGenerationError("Unable to extract the tool due to invalid generation", llmResponse = llmResponse, instruction = "Tool execution failed due to invalid generation.");
    }

    map<json>|error jsonResponse = content[1].fromJsonStringWithType();
    if jsonResponse is error {
        log:printWarn("Invalid JSON is given as the action.", jsonResponse);
        return error LlmInvalidGenerationError("Invalid JSON is given as the action.", jsonResponse, llmResponse = llmResponse, instruction = "Tool execution failed due to an invalid 'Action' JSON_BLOB.");
    }

    map<json> jsonAction = {};
    foreach [string, json] [key, value] in jsonResponse.entries() {
        if key.toLowerAscii() == ACTION_KEY {
            jsonAction[ACTION_NAME_KEY] = value;
        } else if key.toLowerAscii().matches(ACTION_INPUT_REGEX) {
            jsonAction[ACTION_ARGUEMENTS_KEY] = value;
        }
    }
    json input = jsonAction[ACTION_ARGUEMENTS_KEY];
    if jsonAction[ACTION_NAME_KEY].toString().toLowerAscii().matches(FINAL_ANSWER_REGEX) && input is string {
        return {
            content: input
        };
    }
    LlmToolResponse|error tool = jsonAction.fromJsonWithType();
    if tool is error {
        log:printError("Error while extracting action name and inputs from LLM response.", tool, llmResponse = llmResponse);
        return error LlmInvalidGenerationError("Generated 'Action' JSON_BLOB contains invalid action name or inputs.", tool, llmResponse = llmResponse, instruction = "Tool execution failed due to an invalid schema for 'Action' JSON_BLOB.");
    }

    return {
        name: tool.name,
        arguments: tool.arguments
    };
}

isolated function constructHistoryPrompt(ExecutionStep[] history) returns string {
    string historyPrompt = "";
    foreach ExecutionStep step in history {
        string observationStr = getObservationString(step.observation);
        string llmResponseStr = step.llmResponse.toString();
        historyPrompt += string `${llmResponseStr}${"\n"}${OBSERVATION_KEY}: ${observationStr}${"\n"}`;
    }
    return historyPrompt;
}

# Generate descriptions for the tools registered.
#
# + toolStore - ToolStore instance
# + return - Return a record with tool names and descriptions
isolated function extractToolInfo(ToolStore toolStore) returns ToolInfo {
    string[] toolNameList = [];
    string[] toolIntroList = [];
    foreach AgentTool tool in toolStore.tools {
        toolNameList.push(string `${tool.name}`);
        record {|string description; JsonInputSchema inputSchema?;|} toolDescription = {
            description: tool.description,
            inputSchema: tool.variables
        };
        toolIntroList.push(string `${tool.name}: ${toolDescription.toString()}`);
    }
    return {
        toolList: string:'join(", ", ...toolNameList).trim(),
        toolIntro: string:'join("\n", ...toolIntroList).trim()
    };
}

isolated function constructReActPrompt(ToolInfo toolInfo) returns string => string `System: Respond to the human as helpfully and accurately as possible. You have access to the following tools:

${toolInfo.toolIntro}

Use a json blob to specify a tool by providing an action key (tool name) and an action_input key (tool input).

Valid "action" values: "Final Answer" or ${toolInfo.toolList}

Provide only ONE action per $JSON_BLOB, as shown:

${BACKTICKS}
{
  "action": $TOOL_NAME,
  "action_input": $INPUT_JSON
}
${BACKTICKS}

Follow this format:

Question: input question to answer
Thought: consider previous and subsequent steps
Action:
${BACKTICKS}
$JSON_BLOB
${BACKTICKS}
Observation: action result
... (repeat Thought/Action/Observation N times)
Thought: I know what to respond
Action:
${BACKTICKS}
{
  "action": "Final Answer",
  "action_input": "Final response to human"
}
${BACKTICKS}

Begin! Reminder to ALWAYS respond with a valid json blob of a single action. Use tools if necessary. Respond directly if appropriate. Format is Action:${BACKTICKS}$JSON_BLOB${BACKTICKS}then Observation:.`;
