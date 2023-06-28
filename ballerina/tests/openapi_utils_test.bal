import ballerina/test;

@test:Config {}
function testParseWifiOpenAPISpec() {
    string wifiSpecPath = "tests/resources/wifi-spec.json";
    OpenApiSpec|error openAPISpec = parseOpenApiSpec(wifiSpecPath);
    if openAPISpec is error {
        test:assertFail("OpenAPI spec is not parsed correctly");
    }

    test:assertEquals(openAPISpec.openapi, "3.0.1");
    test:assertTrue(openAPISpec.paths is Paths, "Paths are not parsed correctly");
    Paths paths = <Paths>openAPISpec.paths;
    test:assertEquals(paths.keys(), [
        "/guest-wifi-accounts",
        "/guest-wifi-accounts/{ownerEmail}/{username}",
        "/guest-wifi-accounts/{ownerEmail}"
    ]);

}

@test:Config {}
function testParseOpenAPISpec2() {
    string openAISpecPath = "tests/resources/openai-spec.json";
    OpenApiSpec|error openAPISpec = parseOpenApiSpec(openAISpecPath);
    if openAPISpec is error {
        test:assertFail("OpenAPI spec is not parsed correctly. Error: " + openAPISpec.toString());
    }

    test:assertEquals(openAPISpec.openapi, "3.0.0");
    test:assertTrue(openAPISpec.paths is Paths, "Paths are not parsed correctly");
    Paths paths = <Paths>openAPISpec.paths;
    test:assertEquals(paths.keys(), [
        "/fine-tunes/{fine_tune_id}/cancel",
        "/files/{file_id}/content",
        "/edits",
        "/models",
        "/chat/completions",
        "/fine-tunes/{fine_tune_id}",
        "/embeddings",
        "/answers",
        "/completions",
        "/engines/{engine_id}",
        "/moderations",
        "/fine-tunes/{fine_tune_id}/events",
        "/models/{model}",
        "/classifications",
        "/engines",
        "/fine-tunes",
        "/engines/{engine_id}/search"
    ]);

}

@test:Config {}
function testVisitorWithWifiOpenAPISpec() returns error? {
    string wifiSpecPath = "tests/resources/wifi-spec.json";
    OpenApiSpec openAPISchema = check parseOpenApiSpec(wifiSpecPath);
    OpenApiSpecVisitor visitor = new;
    HttpApiSpecification apiSpec = check visitor.visit(openAPISchema);

    HttpTool[] tools = [
        {
            name: "postGuestWifiAccounts",
            description: "Create new guest WiFi account",
            method: "POST",
            path: "/guest-wifi-accounts",
            requestBody: {
                allOf: [
                    {'type: "object", required: ["email", "username"], properties: {email: {'type: "string"}, username: {'type: "string"}}},
                    {'type: "object", required: ["password"], properties: {password: {'type: "string"}}}
                ]
            }
        },
        {
            name: "deleteGuestWifiAccountsOwneremailUsername",
            description: "Delete a guest WiFi account",
            method: "DELETE",
            path: "/guest-wifi-accounts/{ownerEmail}/{username}",
            pathParameters: {required: ["ownerEmail", "username"], properties: {ownerEmail: {'type: "string"}, username: {'type: "string"}}}
        },
        {
            name: "getGuestWifiAccountsOwneremail",
            description: "Get list of guest WiFi accounts of a given owner email address",
            method: GET,
            path: "/guest-wifi-accounts/{ownerEmail}",
            pathParameters: {required: ["ownerEmail"], properties: {ownerEmail: {'type: "string"}}}
        }
    ];
    test:assertEquals(apiSpec.tools, tools);
    test:assertEquals(apiSpec.serviceUrl, "http://test-wifi-url.com");
}

@test:Config {}
function testVisitorWithOpenAISpec() returns error? {
    string wifiSpecPath = "tests/resources/openai-spec.json";
    HttpApiSpecification|error apiSpec = extractToolsFromOpenApiSpec(wifiSpecPath);

    if apiSpec is error {
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
                        temperature: {'type: "float"},
                        top_p: {'type: "float"},
                        n: {'type: "integer"},
                        'stream: {'type: "boolean"},
                        logprobs: {'type: "integer"},
                        echo: {'type: "boolean"},
                        stop: {oneOf: [{'type: "string"}, {'type: "array", items: {'type: "string"}}]},
                        presence_penalty: {'type: "float"},
                        frequency_penalty: {'type: "float"},
                        best_of: {'type: "integer"},
                        logit_bias: {'type: "object", properties: {}},
                        user: {'type: "string"}
                    },
                    required: [
                        "model"
                    ]
                }

            });
        }
        else if tool.name == "createChatCompletion" {
            test:assertEquals(tool, {
                name: "createChatCompletion",
                description: "Creates a completion for the chat message",
                method: POST,
                path: "/chat/completions",
                requestBody: {
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
                        temperature: {'type: "float"},
                        top_p: {'type: "float"},
                        n: {'type: "integer"},
                        'stream: {'type: "boolean"},
                        stop: {"oneOf": [{'type: "string"}, {'type: "array", items: {'type: "string"}}]},
                        max_tokens: {'type: "integer"},
                        presence_penalty: {'type: "float"},
                        frequency_penalty: {'type: "float"},
                        logit_bias: {'type: "object", properties: {}},
                        user: {'type: "string"}
                    },
                    required: ["model", "messages"]
                }

            });
        }
    }
}
