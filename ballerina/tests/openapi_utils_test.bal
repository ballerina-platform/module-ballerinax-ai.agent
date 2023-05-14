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
        "/guest-wifi-accounts/{ownerEmail}",
        "/guest-wifi-accounts",
        "/guest-wifi-accounts/{ownerEmail}/{username}"
    ]);

}

@test:Config {}
function testParseOpenAPISpec2() {
    string openAISpecPath = "tests/resources/openai-spec.json";
    OpenApiSpec|error openAPISpec = parseOpenApiSpec(openAISpecPath);
    if openAPISpec is error {
        test:assertFail("OpenAPI spec is not parsed correctly");
    }

    test:assertEquals(openAPISpec.openapi, "3.0.0");
    test:assertTrue(openAPISpec.paths is Paths, "Paths are not parsed correctly");
    Paths paths = <Paths>openAPISpec.paths;
    test:assertEquals(paths.keys(), [
        "/engines",
        "/engines/{engine_id}",
        "/completions",
        "/chat/completions",
        "/edits",
        "/embeddings",
        "/engines/{engine_id}/search",
        "/files/{file_id}/content",
        "/answers",
        "/classifications",
        "/fine-tunes",
        "/fine-tunes/{fine_tune_id}",
        "/fine-tunes/{fine_tune_id}/cancel",
        "/fine-tunes/{fine_tune_id}/events",
        "/models",
        "/models/{model}",
        "/moderations"
    ]);

}

@test:Config {}
function testVisitorWithWifiOpenAPISpec() returns error? {
    string wifiSpecPath = "tests/resources/wifi-spec.json";
    OpenApiSpec openAPISchema = check parseOpenApiSpec(wifiSpecPath);
    OpenApiSpecVisitor visitor = new;
    ApiSpecification apiSpec = check visitor.visit(openAPISchema);

    HttpTool[] tools = [
        {
            name: "getGuestWifiAccountsOwneremail",
            description: "Get list of guest WiFi accounts of a given owner email address",
            method: GET,
            path: "/guest-wifi-accounts/{ownerEmail}",
            queryParams: (),
            requestBody: ()
        },
        {
            name: "postGuestWifiAccounts",
            description: "Create new guest WiFi account",
            method: "POST",
            path: "/guest-wifi-accounts",
            queryParams: (),
            requestBody: {
                allOf: [
                    {'type: "object", properties: {email: {'type: "string"}, username: {'type: "string"}}},
                    {'type: "object", properties: {password: {'type: "string"}}}
                ]
            }
        },
        {
            name: "deleteGuestWifiAccountsOwneremailUsername",
            description: "Delete a guest WiFi account",
            method: "DELETE",
            path: "/guest-wifi-accounts/{ownerEmail}/{username}",
            queryParams: (),
            requestBody: ()
        }
    ];
    test:assertEquals(apiSpec.tools, tools);
    test:assertEquals(apiSpec.serverUrl, "http://test-wifi-url.com");
}

@test:Config {}
function testVisitorWithOpenAISpec() returns error? {
    string wifiSpecPath = "tests/resources/openai-spec.json";
    ApiSpecification|error apiSpec = extractToolsFromOpenApiSpec(wifiSpecPath);

    if apiSpec is error {
        test:assertFail("Visitor fails with the error");
    }
    HttpTool[] tools = apiSpec.tools;

    test:assertEquals(tools.length(), 19);
    test:assertEquals(apiSpec.serverUrl, "https://api.openai.com/v1");

    foreach HttpTool tool in tools {
        if tool.name == "createCompletion" {
            test:assertEquals(tool,
            {
                name: "createCompletion",
                description: "Creates a completion for the provided prompt and parameters",
                method: POST,
                path: "/completions",
                "queryParams": (),
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
                    }
                }
            });
        }
        else if tool.name == "createChatCompletion" {
            test:assertEquals(tool, {
                name: "createChatCompletion",
                description: "Creates a completion for the chat message",
                method: POST,
                path: "/chat/completions",
                queryParams: (),
                requestBody: {
                    'type: "object",
                    properties: {
                        model: {'type: "string"},
                        messages: {
                            'type: "array",
                            items: {
                                'type: "object",
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
                    }
                }
            });
        }
    }
}
