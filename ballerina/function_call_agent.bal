// import ballerina/log;

public isolated class FunctionCallAgent {
    *BaseAgent;
    final ToolStore toolStore;
    final FunctionCallLlm model;

    # Initialize an Agent.
    #
    # + model - LLM model instance
    # + tools - Tools to be used by the agent
    public isolated function init(FunctionCallLlm model, (BaseToolKit|Tool)... tools) returns error? {
        self.toolStore = check new (...tools);
        self.model = model;
    }

    isolated function decideNextTool(QueryProgress progress) returns ToolResponse|ChatResponse|LlmError {
        ChatMessage[] messages = createFunctionCallMessages(progress);
        FunctionCall|string|error response = self.model.functionaCall(messages, self.toolStore.tools.toArray());
        if response is error {
            return error LlmConnectionError("Error while function call generation", response);
        }
        if response is string {
            return {content: response};
        }
        string? name = response.name;
        if name is () {
            return {tool: error LlmInvalidGenerationError("Missing name", name = response.name, arguments = response.arguments), generated: response.toJson()};
        }
        string? stringArgs = response.arguments;
        map<json>|error? arguments = ();
        if stringArgs is string {
            arguments = stringArgs.fromJsonStringWithType();
        }
        if arguments is error {
            return {tool: error LlmInvalidGenerationError("Invalid arguments", arguments, name = response.name, arguments = stringArgs), generated: response.toJson()};
        }
        return {
            tool: {
                name,
                arguments
            },
            generated: {
                "name": name,
                "arguments": stringArgs
            }
        };

    }
}

isolated function createFunctionCallMessages(QueryProgress progress) returns ChatMessage[] {
    // add the question
    ChatMessage[] messages = [
        {
            role: USER,
            content: progress.query
        }
    ];
    // add the context as the first message
    if progress.context !is () {
        messages.unshift({
            role: SYSTEM,
            content: string `You can use these information if needed: ${progress.context.toString()}`
        });
    }
    // include the history
    foreach ExecutionStep step in progress.history {
        FunctionCall|error functionCall = step.action.generated.fromJsonWithType();
        if functionCall is error {
            panic error("Badly formated history for function call agent", generated = step.action.generated);
        }
        messages.push({
            role: ASSISTANT,
            function_call: functionCall
        }, {
            role: FUNCTION,
            name: functionCall.name,
            content: getObservationString(step.observation)
        });
    }
    return messages;
}
