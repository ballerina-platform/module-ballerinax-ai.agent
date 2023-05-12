# module-ballerinax-ai.agent
Ballerina ReAct type Agent module using Large language models (LLMs)

This repo contains the followings.

1) [Ballerina Agent implementation](ballerina/README.md)
2) Examples to demostrate the common [usage of the agent](examples/README.md)

## Installation 

We have already pushed the `ai.agent` latest version to Ballerina central under the organization `ballerinax`. This package can be pulled using the following command.

`bal pull ballerinax/agent`

## Usage

We will explain the usage of the agent using [this sample](examples/multi-type-tools/main.bal). In this example, we will use two types of actions.
- A Gmail `sendMessage` action defined as a function (Function as actions)
- HTTP client actions to communicate with the `GuestWifi` API (HTTP actions)
    - List available wifi accounts: `GET /guest-wifi-accounts/{ownerEmail}`
    - Create a new wifi account: `POST /guest-wifi-accounts`

### Step 1: Preparation (Wrapping Gmail `sendMessage` action as a function)

We can't register a remote function directly to the agent as a tool. We should use the following template to define functions as tools to the agent. Although, a function can return `any` data type, it is prefered to return a `string` value from a tool. 

```
function functionName(*RecordType functionParams) returns any|error {
    // function body
}
```

Using the above template, we create a new function that takes record type `gmail:MessageRequest` and returns the reponse as a string as shown below.

```
function sendMail(*gmail:MessageRequest messageRequest) returns string|error {
    gmail:MessageRequest message = check messageRequest.cloneWithType();
    message["contentType"] = "text/plain";
    gmail:Client gmail = check new ({auth: {token: gmailToken}});
    gmail:Message sendMessage = check gmail->sendMessage(message);
    return sendMessage.toString();
}
```

### Step 2: Defining Tools for the Agent

First define the `sendMail` **function as a tool**.

```
agent:Tool sendEmailTool = {
        name: "Send mail",
        description: "useful send emails to the recipients.",
        inputs: {
            "recipient": "string",
            "subject": "string",
            "messageBody": "string"
        },
        caller: sendMail
    };
```

Now define the HTTP tools for the `GuestWifi` API.

```
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
            "email": "string",
            "username": "string",
            "password": "string"
        }
    }
];
```
Let's use `HttpToolKit` to group the HTTP tools for a the Wifi client. `HttpToolKit` can take the `serviceURL` and `HttpClientConfig` as parameters to initialize a HTTP client to communicate with the relevent API.

```
// auth configs to WifiService
agent:HttpClientConfig clientConfig = {
    auth: {
        tokenUrl: wifiTokenUrl,
        clientId: wifiClientId,
        clientSecret: wifiClientSecret
    }
};
agent:HttpToolKit wifiApiToolKit = check new (wifiAPIUrl, httpTools, clientConfig);
```

### Step 3: Create the Agent

Agent require initialzing a model (e.g. GPT3, GPT4) first. Agent takes the model and multiple actions and action loaders as inputs.

```
agent:Agent agent = check new (LLMModel model, (ToolKit|Tool)... tools);
```

We can initialize the agent as follows with the GPT3 model. To initialize the `GPT3Model`, we need to provide OpenAI API key `openAIToken`. We can set the `modelConfig` parameter to change the model name (`default:text-davinci-003`) or other hyperparameters such as `temperature`, `max_tokens` etc.

```
agent:GPT3Model model = check new ({auth: {token: openAIToken}});
agent:Agent agent = check new (model, wifiApiToolKit, sendEmailTool);
```

### Step 4: Run the agent

Now we can run the agent with user's natural language commands. Notice that in this case, we use a query template, and we pass unknowns to the `queryTemplate` as args (for a job) or query parameters or a payload (for a API/service). 

```
string queryTemplate = string`create a new guest wifi account for email ${wifiOwnerEmail} with user ${wifiUsername} and password ${wifiPassword}. Send the avaialbe list of wifi accounts for that email to ${recipientEmail}`;

check agent.run(queryTemplate, maxIter = 5);
```

## Output

Let us go through output produced by the above example. Assume the following natural langauge (NL) command to the agent,

NL Command : `create a new guest wifi account for email john@gmail.com with user guest123 and password john123. Send the available list of wifi accounts for that email to alexa@gmail.com`

Agent will proceed with multiple reasoning-action interations following [ReAct Framework](https://arxiv.org/pdf/2210.03629.pdf).

1) Agent creates a new wifi account for owner `john@gmail.com`

```
Reasoning iteration: 1
Thought: I need to use the tools available to create the guest wifi account and send an email with the list of wifi accounts.
Tool: Create wifi
Tool Input: {"path":"/guest-wifi-accounts","queryParams":{},"payload":{"email":"john@gmail.com","username":"guest123","password":"john123"}}
Observation: Successfully added the wifi account
```

2) Agent finds exisiting guest wifi accounts under the owner `john@gmail.com`

```
Reasoning iteration: 2
Thought: I need to use the list wifi tool to get the list of wifi accounts for the specified email
Tool: List wifi
Tool Input: {"path":"/guest-wifi-accounts/john@gmail.com","queryParams":{},"payload":{}}
Observation: ["guest123.guestOf.john", "alice.guestOf.john", "elon.guestOf.john"]
```

3) Agent send a mail to `alexa@gmail.com` with the information about existing accounts

In this step, agent is responsible for generating the mail as well (We only provide the recipient's email).
```
Reasoning iteration: 3
Thought: I need to use the send mail tool to send the list of wifi accounts to the specified email
Tool: Send mail
Tool Input: {"recipient":"alexa@gmail.com","subject":"Guest wifi accounts","messageBody":"The list of guest wifi accounts for email john@gmail.com is: guest123.guestOf.john, alice.guestOf.john, elon.guestOf.john"}
Observation: {"threadId":"1876ff92e17a7f0d","id":"1876ff92e17a7f0d","labelIds":["SENT"]}
```

4) Agent concludes the task

```
Reasoning iteration: 4
Thought: I now know the final answer
Final Answer: The guest wifi account for email john@gmail.com with user guest123 and password john123 has been created and an email with the list of wifi accounts has been sent to alexa@gmail.com.
```

As the final outcome, `alexa@gmail.com` will receive an email generated by the agent with the subject `Guest wifi accounts` and the message body `The list of guest wifi accounts for email john@gmail.com is: guest123.guestOf.john, alice.guestOf.john, elon.guestOf.john`. 


