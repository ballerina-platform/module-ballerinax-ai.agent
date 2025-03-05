import ballerina/io;
import ballerina/test;

@test:Config {}
function testExtractToolsFromWifiOpenAPISpec() returns error? {
    string wifiSpecPath = "tests/resources/openapi/wifi-spec.json";
    map<json> openApiSpec = check io:fileReadJson(wifiSpecPath).ensureType();
    HttpApiSpecification apiSpec = check extractToolsFromOpenApiJsonSpec(openApiSpec);

    HttpTool[] tools = [
        {
            name: "postGuestWifiAccounts",
            description: "Create new guest WiFi account",
            method: "POST",
            path: "/guest-wifi-accounts",
            requestBody: {
                mediaType: "application/json",
                schema:
                    {
                    allOf: [
                        {'type: "object", required: ["email", "username"], properties: {email: {'type: "string"}, username: {'type: "string"}}},
                        {'type: "object", required: ["password"], properties: {password: {'type: "string"}}}
                    ]
                }
            }
        },
        {
            name: "deleteGuestWifiAccountsOwneremailUsername",
            description: "Delete a guest WiFi account",
            method: "DELETE",
            path: "/guest-wifi-accounts/{ownerEmail}/{username}",
            parameters: {
                ownerEmail: {
                    location: PATH,
                    required: true,
                    description: "Email address of the owner of the guest WiFi accounts",
                    style: "simple",
                    explode: false,
                    schema: {'type: "string"}
                },
                username: {
                    location: PATH,
                    required: true,
                    description: "Username of the guest WiFi account to be deleted",
                    style: "simple",
                    explode: false,
                    schema: {'type: "string"}
                }

            }
        },
        {
            name: "getGuestWifiAccountsOwneremail",
            description: "Get list of guest WiFi accounts of a given owner email address",
            method: GET,
            path: "/guest-wifi-accounts/{ownerEmail}",
            parameters: {
                ownerEmail: {
                    location: PATH,
                    required: true,
                    description: "Email address of the owner of the guest WiFi accounts",
                    style: "simple",
                    explode: false,
                    schema: {'type: "string"}
                }

            }
        }
    ];
    test:assertEquals(apiSpec.tools, tools);
    test:assertEquals(apiSpec.serviceUrl, "http://test-wifi-url.com");

}

@test:Config {}
function testExtractToolsFromWifiOpenAPISpecYAMLFile() returns error? {
    string wifiSpecPath = "tests/resources/openapi/wifi-spec.yaml";
    HttpApiSpecification apiSpec = check extractToolsFromOpenApiSpecFile(wifiSpecPath);

    HttpTool[] tools = [
        {
            name: "postGuestWifiAccounts",
            description: "Create new guest WiFi account",
            method: "POST",
            path: "/guest-wifi-accounts",
            requestBody: {
                mediaType: "application/json",
                schema:
                    {
                    allOf: [
                        {'type: "object", required: ["email", "username"], properties: {email: {'type: "string"}, username: {'type: "string"}}},
                        {'type: "object", required: ["password"], properties: {password: {'type: "string"}}}
                    ]
                }
            }
        },
        {
            name: "deleteGuestWifiAccountsOwneremailUsername",
            description: "Delete a guest WiFi account",
            method: "DELETE",
            path: "/guest-wifi-accounts/{ownerEmail}/{username}",
            parameters: {
                ownerEmail: {
                    location: PATH,
                    required: true,
                    description: "Email address of the owner of the guest WiFi accounts",
                    style: "simple",
                    explode: false,
                    schema: {'type: "string"}
                },
                username: {
                    location: PATH,
                    required: true,
                    description: "Username of the guest WiFi account to be deleted",
                    style: "simple",
                    explode: false,
                    schema: {'type: "string"}
                }
            }
        },
        {
            name: "getGuestWifiAccountsOwneremail",
            description: "Get list of guest WiFi accounts of a given owner email address",
            method: GET,
            path: "/guest-wifi-accounts/{ownerEmail}",
            parameters: {
                ownerEmail: {
                    location: PATH,
                    required: true,
                    description: "Email address of the owner of the guest WiFi accounts",
                    style: "simple",
                    explode: false,
                    schema: {'type: "string"}
                }
            }
        }
    ];
    test:assertEquals(apiSpec.tools, tools);
    test:assertEquals(apiSpec.serviceUrl, "http://test-wifi-url.com");
}

@test:Config {}
function testExtractToolsFromWifiOpenAPISpecJSONFile() returns error? {
    string wifiSpecPath = "tests/resources/openapi/wifi-spec.json";
    HttpApiSpecification apiSpec = check extractToolsFromOpenApiSpecFile(wifiSpecPath);

    HttpTool[] tools = [
        {
            name: "postGuestWifiAccounts",
            description: "Create new guest WiFi account",
            method: "POST",
            path: "/guest-wifi-accounts",
            requestBody: {
                mediaType: "application/json",
                schema:
                    {
                    allOf: [
                        {'type: "object", required: ["email", "username"], properties: {email: {'type: "string"}, username: {'type: "string"}}},
                        {'type: "object", required: ["password"], properties: {password: {'type: "string"}}}
                    ]
                }
            }
        },
        {
            name: "deleteGuestWifiAccountsOwneremailUsername",
            description: "Delete a guest WiFi account",
            method: "DELETE",
            path: "/guest-wifi-accounts/{ownerEmail}/{username}",
            parameters: {
                ownerEmail: {
                    location: PATH,
                    required: true,
                    description: "Email address of the owner of the guest WiFi accounts",
                    style: "simple",
                    explode: false,
                    schema: {'type: "string"}
                },
                username: {
                    location: PATH,
                    required: true,
                    description: "Username of the guest WiFi account to be deleted",
                    style: "simple",
                    explode: false,
                    schema: {'type: "string"}
                }
            }
        },
        {
            name: "getGuestWifiAccountsOwneremail",
            description: "Get list of guest WiFi accounts of a given owner email address",
            method: GET,
            path: "/guest-wifi-accounts/{ownerEmail}",
            parameters: {
                ownerEmail: {
                    location: PATH,
                    required: true,
                    description: "Email address of the owner of the guest WiFi accounts",
                    style: "simple",
                    explode: false,
                    schema: {'type: "string"}
                }
            }
        }
    ];
    test:assertEquals(apiSpec.tools, tools);
    test:assertEquals(apiSpec.serviceUrl, "http://test-wifi-url.com");
}

@test:Config {}
function testExtractToolsFromOpenAPISpecJSONFile2() returns error? {
    string wifiSpecPath = "tests/resources/openapi/openai-spec.json";
    HttpApiSpecification|Error apiSpec = extractToolsFromOpenApiSpecFile(wifiSpecPath);

    if apiSpec is Error {
        test:assertFail("Visitor fails with the error");
    }
    HttpTool[] tools = apiSpec.tools;

    test:assertEquals(tools.length(), 19);
    test:assertEquals(apiSpec.serviceUrl, "https://api.openai.com/v1");

    foreach HttpTool tool in tools {
        if tool.name == "createCompletion" {
            test:assertEquals(tool,
            {
                name: "createCompletion",
                description: "Creates a completion for the provided prompt and parameters",
                method: POST,
                path: "/completions",
                requestBody: {
                    mediaType: "application/json",
                    schema: {
                        'type: "object",
                        properties:
                        {
                            model: {'type: "string"},
                            prompt: {
                                oneOf: [
                                    {'type: "string"},
                                    {'type: "array", items: {'type: "string"}},
                                    {'type: "array", items: {'type: "integer"}},
                                    {
                                        'type: "array",
                                        items: {
                                            'type: "array",
                                            items: {'type: "integer"}
                                        }
                                    }
                                ]
                            },
                            suffix: {'type: "string"},
                            max_tokens: {'type: "integer"},
                            temperature: {'type: "number"},
                            top_p: {'type: "number"},
                            n: {'type: "integer"},
                            'stream: {'type: "boolean"},
                            logprobs: {'type: "integer"},
                            echo: {'type: "boolean"},
                            stop: {oneOf: [{'type: "string"}, {'type: "array", items: {'type: "string"}}]},
                            presence_penalty: {'type: "number"},
                            frequency_penalty: {'type: "number"},
                            best_of: {'type: "integer"},
                            logit_bias: {'type: "object", properties: {}},
                            user: {'type: "string"}
                        },
                        required: [
                            "model"
                        ]
                    }
                }
            });
        } else if tool.name == "createChatCompletion" {
            test:assertEquals(tool, {
                name: "createChatCompletion",
                description: "Creates a completion for the chat message",
                method: POST,
                path: "/chat/completions",
                requestBody: {
                    mediaType: "application/json",
                    schema: {
                        'type: "object",
                        properties: {
                            model: {'type: "string"},
                            messages: {
                                'type: "array",
                                items: {
                                    'type: "object",
                                    required: ["role", "content"],
                                    properties: {role: {'type: "string", 'enum: ["system", "user", "assistant"]}, content: {'type: "string"}, name: {'type: "string"}}
                                }
                            },
                            temperature: {'type: "number"},
                            top_p: {'type: "number"},
                            n: {'type: "integer"},
                            'stream: {'type: "boolean"},
                            stop: {"oneOf": [{'type: "string"}, {'type: "array", items: {'type: "string"}}]},
                            max_tokens: {'type: "integer"},
                            presence_penalty: {'type: "number"},
                            frequency_penalty: {'type: "number"},
                            logit_bias: {'type: "object", properties: {}},
                            user: {'type: "string"}
                        },
                        required: ["model", "messages"]
                    }
                }
            });
        }
    }
}

@test:Config {}
function testExtractToolsFromOpenAPISpecJSONFile3() returns error? {
    string wifiSpecPath = "tests/resources/openapi/openai-spec-with-xml-schema.json";
    HttpApiSpecification|Error apiSpec = extractToolsFromOpenApiSpecFile(wifiSpecPath);

    if apiSpec is Error {
        test:assertFail("Visitor fails with the error");
    }
    HttpTool[] tools = apiSpec.tools;

    test:assertEquals(tools.length(), 19);
    test:assertEquals(apiSpec.serviceUrl, "https://api.openai.com/v1");

    foreach HttpTool tool in tools {
        if tool.name == "createCompletion" {
            test:assertEquals(tool,
            {
                "name": "createCompletion",
                "description": "Creates a completion for the provided prompt and parameters",
                "method": "POST",
                "path": "/completions",
                "requestBody": {
                    "mediaType": "application/xml",
                    "schema": {
                        "type": "object",
                        "properties": {
                            "CreateCompletionRequest": {
                                "type": "object",
                                "required": [
                                    "model"
                                ],
                                "properties": {
                                    "model": {
                                        "type": "string"
                                    },
                                    "prompt": {
                                        "oneOf": [
                                            {
                                                "type": "string"
                                            },
                                            {
                                                "type": "array",
                                                "items": {
                                                    "type": "string"
                                                }
                                            },
                                            {
                                                "type": "array",
                                                "items": {
                                                    "type": "integer"
                                                }
                                            },
                                            {
                                                "type": "array",
                                                "items": {
                                                    "type": "array",
                                                    "items": {
                                                        "type": "integer"
                                                    }
                                                }
                                            }
                                        ]
                                    },
                                    "suffix": {
                                        "type": "string"
                                    },
                                    "@maxTokens": {
                                        "type": "integer"
                                    },
                                    "temperature": {
                                        "type": "number"
                                    },
                                    "top_p": {
                                        "type": "number"
                                    },
                                    "n": {
                                        "type": "integer"
                                    },
                                    "stream": {
                                        "type": "boolean"
                                    },
                                    "lgp:logprobs": {
                                        "type": "object",
                                        "properties": {
                                            "@xmlns:lgp": {
                                                "const": "http://openai.com/docs/1.0/parameters"
                                            },
                                            "#content": {
                                                "type": "integer"
                                            }
                                        }
                                    },
                                    "echo": {
                                        "type": "boolean"
                                    },
                                    "stop": {
                                        "oneOf": [
                                            {
                                                "type": "string"
                                            },
                                            {
                                                "type": "array",
                                                "items": {
                                                    "type": "string"
                                                }
                                            }
                                        ]
                                    },
                                    "presence_penalty": {
                                        "type": "number"
                                    },
                                    "frequency_penalty": {
                                        "type": "number"
                                    },
                                    "best_of": {
                                        "type": "integer"
                                    },
                                    "logit_bias": {
                                        "type": "object",
                                        "properties": {}
                                    },
                                    "user": {
                                        "type": "string"
                                    }
                                }
                            }
                        }
                    }
                }
            });
        } else if tool.name == "createChatCompletion" {
            test:assertEquals(tool, {
                "name": "createChatCompletion",
                "description": "Creates a completion for the chat message",
                "method": "POST",
                "path": "/chat/completions",
                "requestBody": {
                    "mediaType": "application/xml",
                    "schema": {
                        "type": "object",
                        "properties": {
                            "CreateChatCompletionRequest": {
                                "type": "object",
                                "required": [
                                    "model",
                                    "messages"
                                ],
                                "properties": {
                                    "model": {
                                        "type": "string"
                                    },
                                    "messages": {
                                        "type": "object",
                                        "properties": {
                                            "message": {
                                                "type": "array",
                                                "items": {
                                                    "type": "object",
                                                    "required": [
                                                        "role",
                                                        "content"
                                                    ],
                                                    "properties": {
                                                        "role": {
                                                            "type": "string",
                                                            "enum": [
                                                                "system",
                                                                "user",
                                                                "assistant"
                                                            ]
                                                        },
                                                        "content": {
                                                            "type": "string"
                                                        },
                                                        "name": {
                                                            "type": "string"
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    },
                                    "@temperature": {
                                        "type": "number"
                                    },
                                    "top:top_p": {
                                        "type": "object",
                                        "properties": {
                                            "@xmlns:top": {
                                                "const": "http://openai.com/docs/1.0/parameters"
                                            },
                                            "#content": {
                                                "type": "number"
                                            }
                                        }
                                    },
                                    "n": {
                                        "type": "integer"
                                    },
                                    "stream": {
                                        "type": "boolean"
                                    },
                                    "stop": {
                                        "oneOf": [
                                            {
                                                "type": "string"
                                            },
                                            {
                                                "type": "array",
                                                "items": {
                                                    "type": "string"
                                                }
                                            }
                                        ]
                                    },
                                    "max_tokens": {
                                        "type": "integer"
                                    },
                                    "presence_penalty": {
                                        "type": "number"
                                    },
                                    "frequency_penalty": {
                                        "type": "number"
                                    },
                                    "logit_bias": {
                                        "type": "object",
                                        "properties": {}
                                    },
                                    "user": {
                                        "type": "string"
                                    }
                                }
                            }
                        }
                    }
                }
            });
        }
    }
}
