# Ballerina Agent Library
This implements capabilities to use LLMs for executing user's natural language commands. 

## Conecpts 

- [Agent](/agent/agent.bal): Accepts the natural language commands to be executed based on registered actions 
- [Model](/agent/llm.bal): Used by agent to make decisions (e.g. GPT3, GPT4).
- [Action](/agent/action.bal): A function or a tool that can be registered to the agent
- [Loader](/agent/loader.bal): Used to load a set of actions at once easily for a specific Http client or using an OpenAPI specification

## Usage 

1. First build the library 
`bal pack`

2. Push to local repositor
`bal push --repository local`

3. Add the dependency to `Ballerina.toml` of the target package
```
[[dependency]]
org = "ballerinax"
name = "agent"
version = "0.1.0"
repository = "local"
```
