## Overview

This module provides APIs for building AI agents using Large Language Models (LLMs).

AI agents use LLMs to process natural language inputs, generate responses, and make decisions based on given instructions. These agents can be designed for various tasks, such as answering questions, automating workflows, or interacting with external systems.

## Prerequisites

Before using this module in your Ballerina application, first you must select your LLM provider and obtain the nessary configuration to engage the LLM. Currenlty the module supports the following LLM Providers and You can obtain the nessary configuration by using the folllowing intrusctons

### OpenAI Provider

- Create an [OpenAI account](https://beta.openai.com/signup/).
- Obtain an API key by following [these instructions](https://platform.openai.com/docs/api-reference/authentication).

### Azure OpenAI Provider

- Create an [Azure](https://azure.microsoft.com/en-us/features/azure-portal/) account.
- Create an [Azure OpenAI resource](https://learn.microsoft.com/en-us/azure/cognitive-services/openai/how-to/create-resource).
- Obtain the tokens. Refer to the [Azure OpenAI Authentication](https://learn.microsoft.com/en-us/azure/cognitive-services/openai/reference#authentication) guide to learn how to generate and use tokens.

### Anthropic Provider

- Create an [Anthropic account](https://www.anthropic.com/signup).
- Obtain an API key by following [these instructions](https://docs.anthropic.com/en/api/getting-started).

### MistralAI Provider

- Create a [Mistral account](https://console.mistral.ai/).
- Obtain an API key by following [these instructions](https://docs.mistral.ai/getting-started/quickstart/#account-setup)

### Ollama Provider

- Install [Ollama](https://ollama.com) on your system.
- Download the required LLM models using the Ollama CLI.
- Ensure the Ollama service is running before making API requests.
- Refer to the [Ollama documentation](https://github.com/ollama/ollama/blob/main/docs/modelfile.md#parameter) for additional configuration details.

## Quickstart

To use the `ai` module in your Ballerina application, update the `.bal` file as follows:

### Step 1: Import the module

Import the `ai` module.

```ballerina
import ballerinax/ai;
```

### Step 2: Define the System Prompt

A system prompt guides the AI's behavior, tone, and response style, defining its role and interaction with users.

```ballerina
ai:SystemPrompt systemPrompt = {
    role: "Math Tutor",
    instructions: string `You are a helpful math tutor. Explain concepts clearly with examples and provide step-by-step solutions.`
};
```

### Step 3: Define the Model Provider

The `ai` module supports multiple LLM providers. Here's how to define the OpenAI provider:

```ballerina
final ai:OpenAiProvider openAiModel = check new ("openAiApiKey", modelType = ai:GPT_4O);
```

### Step 4: Define the tools

An agent tool extends the AI's abilities beyond text-based responses, enabling interaction with external systems or dynamic tasks. Define tools as shown below:

```ballerina
# Returns the sum of two numbers
# + a - first number
# + b - second number
# + return - sum of the numbers
@ai:AgentTool
isolated function sum(int a, int b) returns int => a + b;

@ai:AgentTool
isolated function mult(int a, int b) returns int => a * b;
```

Constraints for defining tools:

1. The function must be marked `isolated`.
2. Parameters should be a subtype of `anydata`.
3. The tool should return a subtype of `anydata|http:Response|stream<anydata, error>|error`.
4. Tool documentation enhances LLM performance but is optional.

### Step 5: Define the Memory

The `ai` module manages memory for individual user sessions using the `Memory`. By default, agents are configured with a memory that has a predefined capacity. To create a stateless agent, set the `memory` to `()` when defining the agent. Additionally, you can customize the memory capacity or provide your own memory implementation. Here's how to initialize the default memory with a new capacity:

```ballerina
final ai:Memory memory = new ai:MessageWindowChatMemory(20);
```

### Step 6: Define the Agent

Create a Ballerina AI agent using the configurations created earlier:

```ballerina
final ai:Agent mathTutorAgent = check new (
    systemPrompt = systemPrompt,
    model = openAiModel,
    tools = [sum, mult], // Pass array of function pointers annotated with @ai:AgentTool
    memory = memory
);
```

### Step 7: Invoke the Agent

Finally, invoke the agent by calling the `run` method:

```ballerina
mathTutorAgent->run("What is 8 + 9 multiplied by 10", sessionId = "student-one");
```

If using the agent with a single session, you can omit the `sessionId` parameter.

## Examples

The `ai` module provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/ballerina-platform/module-ballerinax-ai.agent/tree/main/examples/), covering the following use cases:

1. [Personal AI Assistant](https://github.com/ballerina-platform/module-ballerinax-ai.agent/tree/main/examples/personal-ai-assistant) - Demonstrates how to implement a personal AI assistant using Ballerina AI module along with Google Calendar and Gmail integrations
