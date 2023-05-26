# Ballerina AI Agent Module Examples: Agent with Different Types of Tools

## Overview

This example demonstrates how to use combinations of tool types with the Agent. 
- To send a Google email, we utilize the sendMessage function from the `ballerinax/googleapis.gmail` connector as a tool.
- HttpTools are used to create and list WiFi accounts through the `GuestWifi` HTTP service.
    - List available WiFi accounts:`GET /guest-wifi-accounts/{ownerEmail}`
    - Create a new WiFi account: `POST /guest-wifi-accounts`


## Setup Example
This example requires connecting to a WiFi service. We have added a mock WiFi in the [service](/examples/setup/) directory. You can run this service and provide the URL to the mock WiFi service and the authentication credentials (if applicable) via Config.toml to try out the example. 

## Prerequisites

### 1. Deploy Mock WiFi service
Deploy the mock WiFi service in a cloud platform (e.g. [Choreo](https://wso2.com/choreo/)) or locally. The source is available at [service](/examples/setup/). 

### 2. Get an OpenAI token
- Create an [OpenAI account](https://beta.openai.com/signup/).
- Obtain an API key by following [these instructions](https://platform.openai.com/docs/api-reference/authentication).

### 3. Get a Google API token
- Create a [Google account](https://accounts.google.com/signup/v2/webcreateaccount?utm_source=ga-ob-search&utm_medium=google-account&flowName=GlifWebSignIn&flowEntry=SignUp). (If you already have one, you can use that.)
- Obtain tokens following [this guide](https://developers.google.com/identity/protocols/oauth2).

### 3. Setting the configuration variables

In the `Config.toml`  file, set the configuration variables to correspond to the WiFi service deployed and the OpenAI API token. 
- `openAIToken`: OpenAI API token to connect to GPT3/ChatGPT APIs.
- `wifiAPIUrl`: service URL to the mock WiFi service.
- `wifiTokenUrl`: token URL of the WiFi auth token endpoint
- `wifiClientId`: client ID of the client authentication for WiFi service
- `wifiClientSecret`: client secret of the client authentication for WiFi service
- `gmailToken`: Google API access token

## Run the example

Run the example with the natural language command. 

```
bal run -- <NL_COMMAND>
```


