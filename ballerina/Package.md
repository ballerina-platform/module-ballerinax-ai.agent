## Overview
This module provides the functionality required to build ReAct Agent using Large Language Models (LLMs).

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

### Function as a tool

When using a Ballerina function as a tool, the function should adhere to the following template:

```ballerina
isolated function functionName(record parameters) returns anydata|error {
    // function body 
}
```

In this template, `record parameters` represents a Ballerina record that contains the input parameters for the function. If the function doesn't require any inputs, it can be defined without any parameters. The function has the flexibility to return any data type or an error. It is important to note that the function needs to be an `isolated function` to ensure concurrency safety.

To define a tool using the above function, you can use the following syntax:

```ballerina
agent:Tool exampleTool = {
    name: "exampleTool", // used as an identifier 
    description: "defines the purpose of the function", // provides information about the behavior
    inputSchema: {
        // a JSON schema that defines the inputs to the function (if applicable)
    },
    caller: functionName // a pointer to the function
}
```

### HTTP resource as a Tool

To use an API resource as a tool, an HTTP tool definition can be created as follows. 

```ballerina
agent:HttpTool httpResourceTool = {
    name: "exampleTool", // used as an identifier 
    description: "defines the purpose of the API resource", // provides information about the behavior
    path: "/path/resourceA/" // path to the resource
    method: "get" // the HTTP request method (e.g., GET, POST, DELETE, PUT, etc.)
    queryParams: {
        // a JSON schema defining the query parameters of the HTTP resource
    }
    pathParams: {
        // a JSON schema defining path parameters of the HTTP resource
    }
    requestBody: {
        // a JSON schema defining the request body of the HTTP resource
    }
}
```

### Tools from Interface Definition Languages (IDLs)

You can automatically extract tools from a valid  [OpenAPI specification](https://swagger.io/specification/) (3.x) using the `extractToolsFromOpenApiSpec` function, as demonstrated below:

```ballerina
string openApiPath = "<PATH TO THE JSON FILE>"
agent:HttpTool[] tools = extractToolsFromOpenApiSpec(openApiPath)
```

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
 agent:InputSchema schema = {
        'type: agent:OBJECT,
        properties: {
            recipient: {'type: agent:STRING, description: "should be an email address from the contacts", default: "<DEFAULT EMAIL>"},
            subject: {'type: agent:STRING},
            messageBody: {'type: agent:STRING},
            contentType: {'const: "text/plain"} // constant value 
        }
}
```


## ToolKit
A Toolkit is a highly valuable asset when it comes to organizing a collection of tools that share common attributes. Not only does it provide organization, but it also offers the flexibility to extend and define new types of tools.

To illustrate this point, let's consider an HTTP service that encompasses multiple resources. Typically, these resources share the same service URL and client configurations. In such cases, utilizing an `HttpServiceToolKit` allows for the convenient grouping of all the `HttpTools` associated with the resources of that specific service. 

Furthermore, the `HttpServiceToolKit` extends the definition of a `Tool` to encompass `HttpTool` specifics, effectively encapsulating HTTP-related details. By interpreting an `HttpTool` as a `Tool`, the `HttpServiceToolKit` eliminates the need for additional effort in writing separate Tools for HTTP services. This streamlined interpretation simplifies the development process and saves valuable time.

```ballerina
agent:HttpTool resource1 = {
    // defines resource 1
}

....

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

This is a large language model (LLM) instance. Currently, Agent module has support for the following LLM APIs. 

1) OpenAI GPT3 

    ```ballerina
    agent:Gpt3Model model = check new ({auth: {token: <OPENAI API KEY>}});

    ```
2) OpenAI ChatGPT (e.g. GPT3.5, GPT4)
    ```ballerina
    agent:ChatGptModel model = check new ({auth: {token: <OPENAI API KEY>}});

    ```
3) Azure OpenAI GPT3
    ```ballerina
    agent:AzureGpt3Model model = check new ({auth: {token: <AZURE OPENAI API KEY>}}, string serviceUrl, string deploymentId, string apiVersion);
    ```

## Agent

The Agent facilitates the execution of natural language (NL) commands by leveraging the reasoning and text generation capabilities of LLMs (Language Models). It follows the [ReAct framework](https://arxiv.org/pdf/2210.03629.pdf):

To create an Agent, you need an LLM model and a set of Tool (or ToolKit) definitions.


```ballerina
agent:Agent agent = check new (LLMModel model, (ToolKit|Tool)... tools);
```

There are multiple ways to utilize the Agent.

### Agent.run() for batch execution

The Agent can be executed without interruptions using `Agent.run()`. It attempts to fully execute the given NL command and returns the results at each step.

```ballerina
agent:ExecutionStep[] execution = agent.run("<NL COMMAND>", maxIter = 10);
```

### AgentIterator for foreach execution

The Agent can also act as an iterator, providing reasoning and output from the tool at each step while executing the command.

```ballerina
agent:AgentIterator agentIterator = agent.getIterator("<NL COMMAND>");
foreach agent:ExecutionStep step in agentIterator{
    // logic goes here
    // can decide whether to continue/rollback/exit the loop based on the observation from the tool
}
```

### AgentExecutor for streaming execution 
The Agent can be executed as a stream using AgentExecutor. This allows more flexibility in controlling the agent's execution. AgentExecutor can take previous execution steps as input to resume a task that was partially executed.

This approach is useful in scenarios where you need to remove specific steps during execution (e.g., unsuccessful or older steps). It also allows for manual execution in certain cases (e.g., handling specific errors or obtaining user inputs). You can manipulate the execution trace as required using AgentExecutor.

```ballerina
string QUERY = "<NL COMMAND>";
agent:AgentExecutor agentExecutor = agent.getExecutor(QUERY);
agent:ExecutionStep[] trace = [];
while(agentExecutor.hasNext()){
    agent:ExecutionStep step = check agentExecutor.nextStep();
    any|error observation = step?.observation;
    if observation is error {
        // handle the error using a tool
        // push manually to trace the execution steps of the manually performed actions if needed
        // clean the traces if needed
        agentExecutor = agent.getExecutor(QUERY, trace);
        continue;
    }
    trace.push(step);
}
```

## Quickstart

Let's walk through the usage of the `ai.agent` library using [this sample](examples/multi-type-tools/main.bal). The example demonstrates the use of two types of tools:

- To send a Google email, we utilize the sendMessage function from the `ballerinax/googleapis.gmail` connector as a tool.
- HttpTools are used to create and list WiFi accounts through the `GuestWifi` HTTP service.
    - List available WiFi accounts:`GET /guest-wifi-accounts/{ownerEmail}`
    - Create a new WiFi account: `POST /guest-wifi-accounts`

Follow the steps below to create a simple sample:

### Step 1 - Import library
    import ballerinax/ai.agent;
    import ballerinax/googleapis.gmail;
       
### Step 2 - Preparation Gmail `gmail->sendMessage` tool as a function (optional)

First, we need to wrap the connector actions using another function since Ballerina doesn't allow invoking remote function pointers directly. Here, we create the `sendEmail` function that wraps the connector action.


```ballerina
isolated function sendEmail(gmail:MessageRequest messageRequest) returns string|error {
    gmail:Client gmail = check new ({auth: {token: gmailToken}});
    gmail:Message|error sendMessage = gmail->sendMessage(messageRequest);
    if sendMessage is gmail:Message {
        return sendMessage.toString();
    }
    return "Error while sending the email" + sendMessage.message();
}
```


### Step 3 - Defining Tools for the Agent

First, define `sendMail` function as a tool.

```ballerina
agent:Tool sendEmailTool = {
    name: "Send mail",
    description: "useful to send emails to a given recipient",
    inputSchema: {
        properties: {
            recipient: {'type: agent:STRING},
            subject: {'type: agent:STRING},
            messageBody: {'type: agent:STRING},
            contentType: {'const: "text/plain"}
        }
    },
    caller: sendMail
};
```

Next, create `HttpTools` for the resources of the GuestWifi HTTP service. Then use `HttpServiceToolKit` to create a toolkit for that HTTP service.

```ballerina
agent:HttpTool listWifiHttpTool = {
    name: "List wifi",
    path: "/guest-wifi-accounts/{ownerEmail}",
    method: agent:GET,
    description: "useful to list the guest wifi accounts."
};

agent:HttpTool createWifiHttpTool = {
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
};   

agent:HttpServiceToolKit wifiServiceToolKit = check new (wifiServiceUrl, [listWifiHttpTool, createWifiHttpTool], {
    auth: {
        tokenUrl: wifiServiceTokenUrl,
        clientId: wifiServiceClientId,
        clientSecret: wifiServiceClientSecret
    }
});
```

Note that when creating the `HttpServiceToolKit` for the `GuestWifi` service, we provide the service URL and authentication configurations to the `HttpServiceToolKit` initializer to establish the connection with the service

### Step 4 - Create the Agent

To create the Agent, we first need to initialize a model (e.g., GPT3, GPT4). In this example, we initialize the agent with the `ChatGptModel` model as follows:

<!-- To initialize the `GPT3Model`, we need to provide OpenAI API key `openAIToken`. We can set the `modelConfig` parameter to change the model name (`default:text-davinci-003`) or other hyperparameters such as `temperature`, `max_tokens` etc. -->


```ballerina
agent:ChatGptModel model = check new ({auth: {token:  <OPENAI API KEY>}});
agent:Agent agent = check new (model, wifiServiceToolKit, sendEmailTool);
```

### Step 5 - Run the agent

Now we can run the agent with NL commands from the user. Note that in this case, we use a query template and pass unknowns as interpolations to the `queryTemplate`.

```ballerina
string queryTemplate = string`create a new guest WiFi account for email ${wifiOwnerEmail} with user ${wifiUsername} and password ${wifiPassword}. Send the available list of WiFi accounts for that email to ${recipientEmail}`;

agent:ExecutionStep[] run = agent.run(query);
```

## Output

Let's examine the output produced by the above example. Assuming the following natural language (NL) command given to the agent:

NL Command: `create a new guest WiFi account for email johnny@gmail.com with user guest123 and password john123. Send the available list of WiFi accounts for that email to alexa@gmail.com`

The agent will proceed with multiple reasoning-action iterations following the [ReAct Framework](https://arxiv.org/pdf/2210.03629.pdf).

1) Agent creates a new WiFi account for owner `johnny@gmail.com`:

    <pre>
    Reasoning iteration: 1
    Thought: We need to create a new guest WiFi account with the given username and password, and then list the available WiFi accounts for the email owner and send it to a specified recipient. 
    Action: 
    ```
    {
    "tool": "Create wifi",
    "tool_input": {
        "requestBody": {
        "email": "johnny@wso2.com",
        "username": "guest123",
        "password": "john123"
        }
    }
    }
    ````
    Observation: Successfully added the wifi account
    </pre>

2) Agent finds existing guest WiFi accounts under the owner `johnny@gmail.com`:

    <pre>
    Reasoning iteration: 2
    Thought: Now we need to list the available WiFi accounts for the email owner and send it to a specified recipient.
    Action:
    ```
    {
    "tool": "List wifi",
    "tool_input": {
        "path": "/guest-wifi-accounts/johnny@wso2.com"
    }
    }
    ```
Observation: ["guest123.guestOf.johnny","newGuest.guestOf.johnny"]
</pre>

3) Agent sends an email to `alexa@gmail.com` with the information about the existing accounts:

    In this step, the agent is responsible for generating the email subject and message body as well. The user provides only the recipient's email.
    
    <pre>
    Reasoning iteration: 3
    Thought: Finally, we need to send the available wifi list to the specified recipient.
    Action:
    ```
    {
    "tool": "Send mail",
    "tool_input": {
        "recipient": "alexa@wso2.com",
        "subject": "Available Wifi List",
        "messageBody": "The available wifi accounts for johnny@wso2.com are: guest123.guestOf.johnny, newGuest.guestOf.johnny"
    }
    }
    ```
    Observation: {"threadId":"1884d1bda3d2c286","id":"1884d1bda3d2c286","labelIds":["SENT"]}
    </pre>

4) Agent concludes the task:

    ```
    Reasoning iteration: 4
    Thought: I now know the final answer
    Final Answer: Successfully created a new guest wifi account with username "guest123" and password "john123" for the email owner "johnny@wso2.com". The available wifi accounts for "johnny@wso2.com" are "guest123.guestOf.johnny" and "newGuest.guestOf.johnny", and this list has been sent to the specified recipient "alexa@wso2.com".
    ```

As a result, alexa@gmail.com will receive an email generated by the agent with the subject "Available WiFi List" and the message body "The available WiFi accounts for johnny@wso2.com are: guest123.guestOf.johnny, newGuest.guestOf.johnny".


