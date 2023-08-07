import ballerina/test;
import ballerina/io;

@test:Config {}
function testExtractToolsFromWifiOpenAPISpec() returns error? {
    string wifiSpecPath = "tests/resources/wifi-spec.json";
    map<json> openApiSpec = check io:fileReadJson(wifiSpecPath).ensureType();
    HttpApiSpecification apiSpec = check extractToolsFromOpenApiJsonSpec(openApiSpec);

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
function testExtractToolsFromWifiOpenAPISpecYAMLFile() returns error? {
    string wifiSpecPath = "tests/resources/wifi-spec.yaml";
    HttpApiSpecification apiSpec = check extractToolsFromOpenApiSpecFile(wifiSpecPath);

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
function testExtractToolsFromWifiOpenAPISpecJSONFile() returns error? {
    string wifiSpecPath = "tests/resources/wifi-spec.json";
    HttpApiSpecification apiSpec = check extractToolsFromOpenApiSpecFile(wifiSpecPath);

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
function testExtractToolsFromOpenAPISpecJSONFile2() returns error? {
    string wifiSpecPath = "tests/resources/openai-spec.json";
    HttpApiSpecification|error apiSpec = extractToolsFromOpenApiSpecFile(wifiSpecPath);

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

@test:Config {}
function testParameterSchema() returns error? {
    OpenApiSpecVisitor visitor = new;

    JsonSubSchema stringParameterSchema = {'type: "string", description: "Name of the person"};
    JsonSubSchema integerParameterSchema = {'type: "integer", description: "Age of the person"};

    JsonSubSchema arrayParameterSchema = {
        items: stringParameterSchema
    };

    JsonSubSchema objectParameterSchema = {
        properties:
        {
            name: stringParameterSchema,
            age: integerParameterSchema
        }
    };

    JsonSubSchema arrayParameterSchemaWithObjItems = {
        items: objectParameterSchema
    };

    ParameterType|error verifiedParameterType = visitor.verifyParameterType(stringParameterSchema);
    if verifiedParameterType !is PrimitiveInputSchema {
        test:assertFail("Parameter type is not verified correctly");
    }
    test:assertEquals(verifiedParameterType, stringParameterSchema);

    verifiedParameterType = visitor.verifyParameterType(arrayParameterSchema);
    if verifiedParameterType !is ArrayTypeParameterSchema {
        test:assertFail("Parameter type is not verified correctly");
    }
    test:assertEquals(verifiedParameterType, arrayParameterSchema);

    verifiedParameterType = visitor.verifyParameterType(objectParameterSchema);
    if verifiedParameterType !is error {
        test:assertFail("Parameter type is not verified correctly");
    }
    test:assertEquals(verifiedParameterType.detail(), {cause: "Expected only `PrimitiveType` or array type, but found: typedesc ai.agent:ObjectInputSchema"});

    verifiedParameterType = visitor.verifyParameterType(arrayParameterSchemaWithObjItems);
    if verifiedParameterType !is error {
        test:assertFail("Parameter type is not verified correctly");
    }
    test:assertEquals(verifiedParameterType.detail(), {cause: "Expected only `PrimitiveType` values for array type parameters, but found: typedesc ai.agent:ObjectInputSchema"});

}
