## Overview
This module provides the functionality required to build ReAct agent using Large Language Models (LLMs).

## Prerequisites

Before using this module in your Ballerina application, complete the following:

* Create an [OpenAI account](https://beta.openai.com/signup/).
* Obtain an API key by following [these instructions](https://platform.openai.com/docs/api-reference/authentication).

Alternatively, it is possible to use an Azure OpenAI account by completing the following steps. 

- Create an [Azure](https://azure.microsoft.com/en-us/features/azure-portal/) account.
- Create an [Azure OpenAI resource](https://learn.microsoft.com/en-us/azure/cognitive-services/openai/how-to/create-resource).
- Obtain the tokens. Refer to the [Azure OpenAI Authentication](https://learn.microsoft.com/en-us/azure/cognitive-services/openai/reference#authentication) guide to learn how to generate and use tokens.

## Tool 

A tool refers to a single action used to retrieve, process, or manipulate data. It can be a function or an API call, which may require certain inputs following a specific input schema.

### Function as a Tool

When using a Ballerina function as a tool, the function should adhere to the following template:

```ballerina
isolated function functionName(record{} parameters) returns anydata|error {
    // function body 
}
```

In this template, `record parameters` represents a Ballerina record that contains the input parameters for the function. If the function doesn't require any inputs, it can be defined without any parameters. The function has the flexibility to return any data type or an error. It is important to note that the function needs to be an `isolated function` to ensure concurrency safety.

To define a tool using the above function, you can use the following syntax:

```ballerina
agent:Tool exampleTool = {
    name: "exampleTool", // used as an identifier 
    description: "defines the purpose of the function", // provides information about the behavior
    parameters: {
        // a JSON schema that defines the inputs to the function (if applicable)
    },
    caller: functionName // a pointer to the function
}
```

### HTTP Resource as a Tool

To use an API resource as a tool, an HTTP tool definition can be created as follows. 

```ballerina
agent:HttpTool httpResourceTool = {
    name: "exampleTool", // used as an identifier 
    description: "defines the purpose of the API resource", // provides information about the behavior
    path: "/path/resourceA/", // path to the resource
    method: agent:GET, // the HTTP request method (e.g., GET, POST, DELETE, PUT, etc.)
    parameters: {
        // map of query and path parameter definitions
    },
    requestBody: {
        mediaType: "application/json", // the media type of the request body (optional)
        schema: {
            properties: {}
            // a JSON schema defining the request body of the HTTP resource
        }
    }
};
```

### Tools from Interface Definition Languages (IDLs)

You can automatically extract tools from a valid [OpenAPI specification](https://swagger.io/specification/) (3.x) file using the `extractToolsFromOpenApiSpecFile` function, as demonstrated below:

```ballerina
string openApiPath = "<PATH TO THE JSON/YAML FILE>";
agent:HttpApiSpecification apiSpecification = check agent:extractToolsFromOpenApiSpecFile(openApiPath);
string? serviceUrl = apiSpecification.serviceUrl; // service url extracted from the spec
agent:HttpTool[] tools = apiSpecification.tools;
```

The file containing the OpenAPI specification should be in either JSON or YAML format. To load them using a `map<json>` field, use `extractToolsFromOpenApiJsonSpec` instead of the above. 

### Tool Input Schema

The tool utilizes a JSON schema to define the input schema. This schema specifies the expected structure of the Ballerina record required by the Ballerina function, as well as the parameters (query/path) and payload for an HTTP API call.

For example, the input schema for a Ballerina record can be defined as follows:

Ballerina record:
```ballerina
type SendEmailInput record {|
    string recipient = "<DEFAULT EMAIL>"; // should be an email address from the contacts
    string subject;
    string messageBody;
    string contentType?;
|};
```

JSON input schema: 
```ballerina
 agent:ObjectInputSchema schema = {
        'type: agent:OBJECT,
        properties: {
            recipient: {
                'type: agent:STRING, 
                description: "should be an email address from the contacts", 
                default: "<DEFAULT EMAIL>"
            },
            subject: {'type: agent:STRING},
            messageBody: {'type: agent:STRING},
            contentType: {'const: "text/plain"} // a constant value 
        }
};
```


## ToolKit
A Toolkit is a highly valuable asset when it comes to organizing a collection of tools that share common attributes. Not only does it provide organization, but it also offers the flexibility to extend and define new types of tools.

To illustrate this point, let's consider an HTTP service that encompasses multiple resources. Typically, these resources share the same service URL and client configurations. In such cases, utilizing an `HttpServiceToolKit` allows for the convenient grouping of all the `HttpTool` records associated with the resources of that specific service. 

Furthermore, the `HttpServiceToolKit` extends the definition of a `Tool` to encompass `HttpTool` specifics, effectively encapsulating HTTP-related details. By interpreting an `HttpTool` as a `Tool`, the `HttpServiceToolKit` eliminates the need for additional effort in writing separate Tools for HTTP services. This streamlined interpretation simplifies the development process and saves valuable time.

```ballerina
agent:HttpTool resource1 = {
    // defines resource 1
}

...

agent:HttpTool resourceN = {
    // defines resource N
}
agent:HttpServiceToolKit serviceAToolKit = check new (
    serviceUrl, 
    [resource1,...,resourceN], 
    httpClientConfigs, 
    httpHeaders
);
```

## Model

This is a large language model (LLM) instance. This module offers three types of LLM APIs: completion, chat, and function calling. Currently, the module includes the following LLMs. 

### Completion LLM APIs
- OpenAI GPT3
    ```ballerina
    agent:Gpt3Model model = check new ({auth: {token: "<OPENAI API KEY>"}});
    ```
- Azure OpenAI GPT3
    ```ballerina
    agent:AzureGpt3Model model = check new ({auth: {apiKey: "<AZURE OPENAI API KEY>"}},  serviceUrl, deploymentId, apiVersion);
    ```
### Chat and function calling LLM APIs
- OpenAI ChatGPT (GPT3.5 and GPT4)
    ```ballerina
    agent:ChatGptModel model = check new ({auth: {token: "<OPENAI API KEY>"}});
    ```
- Azure OpenAI ChatGPT (GPT3.5 and GPT4)
    ```ballerina
    agent:AzureChatGptModel model = check new ({auth: {apiKey: "<AZURE OPENAI API KEY>"}}, serviceUrl, deploymentId, apiVersion);
    ```


### Extending `LlmModel` for Custom Models
This module provides extended support for leveraging other LLMs through the extension of a suitable LLM API interface. To extend an LLM to support both chat and function calling APIs, the following example can be followed.

```ballerina
isolated class NewLlmModel {
    *agent:ChatLlmModel; // extends Chat API interface
    *agent:FunctionCallLlmModel; // extends FunctionCall API interface

    function init() returns error? {
        // initialize the connection with the new LLM
    }

    public isolated function chatComplete(agent:ChatMessage[] messages, string? stop = ()) returns string|agent:LlmError {
        // implement to call chat API of the new LLM
        // return the text content of the response
        return "<TEXT_CONTENT>";
    }

    public isolated function functionCall(agent:ChatMessage[] messages, agent:ChatCompletionFunctions[] functions, string? stop) returns string|agent:FunctionCall|agent:LlmError {
        // implement to call function call API of the new LLM
        // return the function call or the text content if the response is a chat response
        return {name: "FUNCTION_NAME", arguments: "FUNCTION_ARGUMENTS"};
    }
}
```

By extending `agent:ChatLlmModel` and `agent:FunctionCallLlmModel`, the `NewLlmModel` is implemented to utilize the chat and function calling APIs of a new LLM model seamlessly. To gain a comprehensive understanding of the capabilities of this module in connecting to various custom LLM APIs for executing different types of agents, you can refer to other built-in LLM models.

## Agent

The agent facilitates the execution of natural language (NL) commands by leveraging the reasoning and text generation capabilities of LLMs (Language Models). We have two types of Agents already in-built. 

### 1. Creation of Agents
#### a) ReAct Agent

This Agent is implemented based on the [ReAct framework](https://arxiv.org/pdf/2210.03629.pdf).

To create an `ReActAget`, you can use either `CompletionLlmModel` or `ChatCompletionLlmModel`.

```ballerina
agent:ChatGptModel model = check new ({auth: {token: "<OPENAI_TOKEN>"}});
(agent:Tool|agent:BaseToolKit)[] tools = [
    //tools and toolkits
];
agent:ReActAgent agent = check new (model, ...tools);
```

#### b) Function Calling Agent

This agent is implemented to use function calling APIs (e.g. [OpenAI Function Calls](https://openai.com/blog/function-calling-and-other-api-updates)).

Creating a `FunctionCall` agent is similar to the `ReActAgent`, but you can use only `FunctionCallLlmModel` with this type of agents. 

```ballerina
agent:ChatGptModel model = check new ({auth: {token: "<OPENAI_TOKEN>"}});
(agent:Tool|agent:BaseToolKit)[] tools = [
    //tools and toolkits
];
agent:FunctionCallAgent agent = check new (model, ...tools);
```

### 2. Extending `BaseAgent` to build Custom Agents

This module enables the extension of new types of agents by modifying the reasoning protocols. To define a new agent, the selectNextTool and parseLlmResponse methods should be implemented accordingly.

This module allows extending new type of Agents by modifying the reasoning protocols. To define a new Agent, `selectNextTool` and `parseLlmResponse` methods should be implemented accordingly. 

```ballerina
isolated class NewChatAgent {
    *agent:BaseAgent;
    public final agent:ChatLlmModel model; // define the type of model to be used chat agent
    public final agent:ToolStore toolStore;

    // defines the init function to initialize the agent
    public function init(agent:ChatLlmModel model, (agent:BaseToolKit|agent:Tool)... tools) returns error? {
        // initialize the agent with the given model and tools is mandatory
        self.model = model;
        self.toolStore = check new (...tools);
    }

    public isolated function selectNextTool(agent:ExecutionProgress progress) returns json|agent:LlmError {
        // define the logic to reason and select the next tool
        // returns the content from the LLM response, which can be parsed using the parseLlmResponse function
        return "<LLM_RESPONSE_CONTENT>";
    }

    public isolated function parseLlmResponse(json llmResponse) returns agent:LlmToolResponse|agent:LlmChatResponse|agent:LlmInvalidGenerationError {
        // defines the logic to parse the LLM response generated by the selectNextTool function
        // returns a LlmToolResponse if parsed response contains a tool
        // returns a LlmChatResponse if parsed response contains a chat response
        // returns a LlmInvalidGenerationError if the response is invalid
        return {name: "<TOOL_NAME", arguments: {"arg1": "value1", "arg2": "value2"}};
    }
}
```

### 3. Using Agents

#### a). `agent:run` for Batch Execution

The agent can be executed without interruptions using `agent:run`.

```ballerina
record {|(agent:ExecutionResult|agent:ExecutionError)[] steps; string answer?;|} run = agent:run(agent, "<NL COMMAND>", maxIter = 10);
```
It attempts to fully execute the given NL command and returns a record with the execution steps (whether a tool execution or an error) and the final answer to the question. 

#### b). `agent:Iterator` for `foreach` Execution

The agent can function as an iterator, delivering reasoning and observation from the tool at each step during the execution of the command.

```ballerina
agent:Iterator agentIterator = new (agent, query = "<NL COMMAND>");
foreach agent:ExecutionResult|agent:ExecutionError|agent:LlmChatResponse|error step in agentIterator {
    // logic goes here
    // can decide whether to continue/rollback/exit the loop based on returned record type and the observations during the execution
}
```

The `agent:Iterator` returns one of the record types defined in the example above, depending on the execution status.

#### c). `agent:Executor` for advanced use-cases

The `agent:Executor` offers enhanced flexibility for running agents with a two-step process of `reason()` and `act(json llmResponse)`. This separation allows developers to obtain user confirmations before executing actions based on the agent's reasoning. This feature is particularly valuable for verifying, validating, or refining the agent's reasoning by incorporating user intervention or feedback as new observations, which can be achieved using the `update(ExecutionStep step)` method of `agent:Executor`.

Additionally, this approach empowers users to manipulate the execution by modifying the query, history, or the context of the executor during the agent's execution. This capability becomes handy in situations where certain steps need to be excluded during execution (e.g., unsuccessful or outdated steps). Moreover, manual execution can be performed selectively, such as handling specific errors or acquiring user inputs. The `agent:Executor` allows you to customize the execution trace to suit your needs effectively.

```ballerina
agent:Executor agentExecutor = new (agent, query = "<NL COMMAND>");
while agentExecutor.hasNext() {
    json|error llmResponse = agentExecutor.reason(); // decide the next tool to execute
    if llmResponse is error {
        // reasoning fails due to LLM error. Handle appropriately
        break;
    }

    // based on the llmResponse users can take decisions here, but since it is still in raw format, processing is required
    agent:ExecutionResult|agent:LlmChatResponse|agent:ExecutionError result = agentExecutor.act(llmResponse); // execute the tool based on the reasoning
    if result is agent:ExecutionResult {
        // tool executed and returned a result
        // based on the tool result, can take decisions here
    } else if result is agent:LlmChatResponse {
        // execution completed with a chat response
    } else {
        // error during parsing the LLM response or invalid tool 
        // agent will retry automatically, if continue the execution
    }

    // can manipulate the `agentExecutor` at any point within this loop
    // dynamically changing the query, history or context given to the agent can be useful in advanced use cases
    // to get the current execution progress
    agent:ExecutionProgress progress = agentExecutor.progress;
    // modify the progress and replace the executor
    agentExecutor = new (agent, progress);
}
```

## Quickstart

Let's walk through the usage of the `ai.agent` library using [this sample](https://github.com/ballerina-platform/module-ballerinax-ai.agent/tree/main/examples/multi-type-tools). The example demonstrates the use of two types of tools:

- To send a Google email, we utilize the sendMessage function from the `ballerinax/googleapis.gmail` connector as a tool.
- `HttpTool` records are used to create and list WiFi accounts through the `GuestWiFi` HTTP service.
    - List available WiFi accounts:`GET /guest-wifi-accounts/{ownerEmail}`
    - Create a new WiFi account: `POST /guest-wifi-accounts`

By following the four steps below, we can easily configure and run an agent:

### Step 1 - Import Library
```ballerina
import wso2/ai.agent;
import ballerinax/googleapis.gmail;
```

### Step 2 - Defining Tools for the Agent

To begin, we need to define a `gmail->sendMessage` function as a tool. However, it's not possible to define a tool for a remote function directly without a wrapper function. If you attempt to do so, you won't be able to obtain the pointer for the remote function. Therefore, we start by creating the `sendEmail` function, which wraps the connector action `gmail->sendMessage`.


```ballerina
isolated function sendMail(record {|string senderEmail; gmail:MessageRequest messageRequest;|} input) returns string|error {
    gmail:Client gmail = check new ({auth: {token: gmailToken}});
    gmail:Message message = check gmail->/users/[input.senderEmail]/messages/send.post(input.messageRequest);
    return message.toString();
}
```

Now that we have the `sendEmail` function defined, we can proceed with creating the tool that utilizes this function. To define the `parameters` for the tool, we inspect the structure of the `gmail:MessageRequest` record and include only the necessary fields required for our task. Since the rest of the fields are not mandatory for the tool's execution, we can safely ignore them.

```ballerina
agent:Tool sendEmailTool = {
    name: "Send mail",
    description: "useful to send emails to a given recipient",
    parameters: {
        properties: {
            senderEmail: {'type: agent:STRING},
            messageRequest: {
                properties: {
                    to: {
                        items: {'type: agent:STRING}
                    },
                    subject: {'type: agent:STRING},
                    bodyInHtml: {
                        'type: agent:STRING,
                        format: "text/html"
                    }
                }
            }
        }
    },
    caller: sendMail
};
```

Next, define a `HttpTool` record for the resources of the GuestWiFi HTTP service. Then use `HttpServiceToolKit` to create a toolkit for that HTTP service. While creating the `HttpTool` record, there is no need to explicitly define `pathParameters` since the Agent can automatically extract them from the provided `path`.

```ballerina
agent:HttpTool listWifiHttpTool = {
    name: "List wifi",
    path: "/guest-wifi-accounts/{ownerEmail}",
    method: agent:GET,
    description: "useful to list the guest wifi accounts.",
    parameters: {
        ownerEmail: {
            location: agent:PATH,
            schema: {'type: agent:STRING}
        }
    }
};

agent:HttpTool createWifiHttpTool = {
    name: "Create wifi",
    path: "/guest-wifi-accounts",
    method: agent:POST,
    description: "useful to create a guest wifi account.",
    requestBody: {
        schema: {
            'type: agent:OBJECT,
            properties: {
                email: {'type: agent:STRING},
                username: {'type: agent:STRING},
                password: {'type: agent:STRING}
            }
        }
    }
};

agent:HttpServiceToolKit wifiServiceToolKit = check new (wifiServiceUrl, [listWifiHttpTool, createWifiHttpTool], {
    auth: {
        tokenUrl: wifiServiceTokenUrl,
        clientId: wifiServiceClientId,
        clientSecret: wifiServiceClientSecret
    }
});
```

Note that when creating the `HttpServiceToolKit` for the `GuestWiFi` service, we provide the service URL and authentication configurations to the `HttpServiceToolKit` initializer to establish the connection with the service.

### Step 3 - Create the Agent

To create the agent, we first need to initialize a LLM (e.g., `Gpt3Model`, `ChatGptModel`). In this example, we initialize the agent with the `ChatGptModel` model as follows:


```ballerina
agent:ChatGptModel model = check new ({auth: {token:  <OPENAI API KEY>}});
agent:FunctionCallAgent agent = check new (model, wifiServiceToolKit, sendEmailTool);
```

### Step 4 - Run the Agent

Now we can run the agent with NL commands from the user. Note that in this case, we use a query template and pass unknowns as interpolations to the `queryTemplate`.

```ballerina
string queryTemplate = string`create a new guest WiFi account for email ${wifiOwnerEmail} with user ${wifiUsername} and password ${wifiPassword}. Send the available list of WiFi accounts for that email to ${recipientEmail}`;
_ run = agent.run(agent, query);
```

## Output

Let's examine the output produced by the above example. Assuming the following natural language (NL) command is given to the agent:

NL Command: **"create a new guest WiFi account for email johnny@wso2.com with user guest123 and password john123. Send the available list of WiFi accounts for that email to alexa@wso2.com"**

The agent will proceed with multiple reasoning-action iterations as follows to execute the given command. 

1) Agent creates a new WiFi account for owner `johnny@wso2.com`:

    ``````
    Agent Iteration 1
    Action:
    ```
    {
        name: Create_wifi,
        arguments: {"requestBody":{"email":"johnny@wso2.com","username":"guest123","password":"john123"},"path":"/guest-wifi-accounts"}
    }
    ```
    Observation: {"code":201,"path":"/guest-wifi-accounts","headers":{"contentType":"text/plain","contentLength":35},"body":"Successfully added the wifi account"}
    ``````

2) Agent finds existing guest WiFi accounts under the owner `johnny@wso2.com`:

    ``````
    Agent Iteration 2
    Action:
    ```
    {
        name: List_wifi,
        arguments: {"parameters":{"ownerEmail":"johnny@wso2.com"},"path":"/guest-wifi-accounts/{ownerEmail}"}
    }
    ```
    Observation: {"code":200,"path":"/guest-wifi-accounts/johnny@wso2.com","headers":{"contentType":"application/json","contentLength":104},"body":"["guest123.guestOf.johnny","newGuest.guestOf.johnny"]"}
    ``````

3) Agent sends an email to `alexa@wso2.com` with the information about the existing accounts:

    In this step, the agent is responsible for generating the email subject and message body as well. The user provides only the recipient's email.
    
    ``````
    Agent Iteration 3
    Action:
    ```
    {
        name: Send_mail,
        arguments: {"messageRequest":{"to":["alexa@wso2.com"],"subject":"List of WiFi accounts","bodyInHtml":"Here is the list of available WiFi accounts for your email:<br><br>guest123.guestOf.johnny<br>newGuest.guestOf.johnny"},"senderEmail":"johnny@wso2.com"}
    }
    ```
    Observation: {"threadId":"1884d1bda3d2c286","id":"1884d1bda3d2c286","labelIds":["SENT"]}
    ``````

4) Agent concludes the task:

    ```
    Final Answer: Successfully created a new guest wifi account with username "guest123" and password "john123" for the email owner "johnny@wso2.com". The available wifi accounts for "johnny@wso2.com" are "guest123.guestOf.johnny" and "newGuest.guestOf.johnny", and this list has been sent to the specified recipient "alexa@wso2.com".
    ```

As a result, `alexa@wso2.com` will receive an email generated by the agent with the subject "Available WiFi List" and the message body "The available WiFi accounts for `johnny@wso2.com` are: guest123.guestOf.johnny, newGuest.guestOf.johnny".
