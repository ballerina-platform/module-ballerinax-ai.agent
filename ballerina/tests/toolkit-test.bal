import ballerina/test;

HttpTool[] httpTools = [
    {
        name: "httpGet",
        path: "/example-get/{pathParam}",
        method: GET,
        description: "test HTTP GET tool",
        parameters: {
            pathParam: {
                location: PATH,
                schema: {
                    'type: STRING
                }
            }
        }
    },
    {
        name: "httpPostWithSimpleSchema",
        path: "/example-post",
        method: POST,
        description: "test HTTP POST tool with simple schema",
        requestBody: {
            schema: {
                properties: {
                    attribute1: {'type: STRING},
                    attribute2: {'type: INTEGER},
                    attribute3: {'type: "array", items: {'type: STRING}}
                }
            }
        }
    },
    {
        name: "httpDeleteWithComplexSchema",
        path: "/example-delete",
        method: DELETE,
        description: "test HTTP DELETE tool with complex schema",
        requestBody: {
            schema:
                {
                'type: "object",
                properties:
                {
                    model: {'type: "string", default: "davinci"},
                    prompt: {
                        oneOf: [
                            {'type: "string", default: "test"},
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
                    suffix: {'type: "string"}
                }
            }
        }
    },
    {
        name: "testDefaultWithNull",
        path: "/example-delete",
        method: DELETE,
        description: "test HTTP DELETE tool with complex schema",
        requestBody: {
            schema: {
                'type: "object",
                properties:
                {
                    model: {'type: "string"},
                    prompt: {
                        oneOf: [
                            {'type: "string", default: ()},
                            {'type: "array", items: {'type: "string"}},
                            {'type: "array", items: {'type: "integer"}},
                            {
                                'type: "array",
                                items: {
                                    'type: "array",
                                    items: {'type: "integer", default: ()}
                                }
                            }
                        ]
                    },
                    suffix: {'type: "string"}
                }
            }
        }
    }
];

isolated function getMock(HttpInput input) returns string|error {
    return "";
}

@test:Config {}
function testHttpToolKitInitialization() {
    string serviceURL = "http://test-wifi-url.com";
    HttpServiceToolKit|error httpToolKit = new (serviceURL, httpTools, {auth: {token: "<API-TOKEN>"}}, {"timeout": "10000"});
    if httpToolKit is error {
        test:assertFail("HttpToolKit is not initialized due to an error");
    }
    ToolConfig[]|error tools = httpToolKit.getTools();
    if tools is error {
        test:assertFail("Error occurred while getting tools from HttpToolKit");
    }
    test:assertEquals(tools.length(), 4);

    test:assertEquals(tools[0].name, "httpGet");
    test:assertEquals(tools[0].description, "test HTTP GET tool");
    map<json> expectedToolSchema = {
        'type: "object",
        required: ["httpInput"],
        properties: {
            httpInput: {
                properties: {
                    path: {'const: "/example-get/{pathParam}"},
                    parameters: {
                        'type: "object",
                        required: ["pathParam"],
                        properties: {"pathParam": {'type: "string"}}
                    }
                },
                'type: "object"
            }
        }
    };
    test:assertEquals(tools[0].parameters, expectedToolSchema);

    test:assertEquals(tools[1].name, "httpPostWithSimpleSchema");
    test:assertEquals(tools[1].description, "test HTTP POST tool with simple schema");
    expectedToolSchema = {
        'type: "object",
        required: ["httpInput"],
        properties: {
            httpInput: {
                properties: {
                    path: {'const: "/example-post"},
                    requestBody: {
                        'type: "object",
                        properties: {
                            attribute1: {'type: "string"},
                            attribute2: {'type: "integer"},
                            attribute3: {'type: "array", items: {'type: "string"}}
                        }
                    }
                },
                'type: "object"
            }
        }
    };
    test:assertEquals(tools[1].parameters, expectedToolSchema);

    test:assertEquals(tools[2].name, "httpDeleteWithComplexSchema");
    test:assertEquals(tools[2].description, "test HTTP DELETE tool with complex schema");
    expectedToolSchema = {
        'type: "object",
        required: ["httpInput"],
        properties: {
            httpInput: {
                properties: {
                    path: {'const: "/example-delete"},
                    requestBody: {
                        'type: "object",
                        properties: {
                            model: {'type: "string", "default": "davinci"},
                            prompt: {
                                oneOf: [
                                    {'type: "string", "default": "test"},
                                    {'type: "array", items: {'type: "string"}},
                                    {'type: "array", items: {'type: "integer"}},
                                    {'type: "array", items: {'type: "array", items: {'type: "integer"}}}
                                ]
                            },
                            suffix: {'type: "string"}
                        }
                    }
                },
                'type: "object"
            }
        }
    };
    test:assertEquals(tools[2].parameters, expectedToolSchema);

    test:assertEquals(tools[3].name, "testDefaultWithNull");
    test:assertEquals(tools[3].description, "test HTTP DELETE tool with complex schema");
    expectedToolSchema = {
        'type: "object",
        required: ["httpInput"],
        properties: {
            httpInput: {
                properties: {
                    path: {'const: "/example-delete"},
                    requestBody: {
                        'type: "object",
                        properties: {
                            model: {'type: "string"},
                            prompt: {
                                oneOf: [
                                    {'type: "string"},
                                    {'type: "array", items: {'type: "string"}},
                                    {'type: "array", items: {'type: "integer"}},
                                    {'type: "array", items: {'type: "array", items: {'type: "integer"}}}
                                ]
                            },
                            suffix: {'type: "string"}
                        }
                    }
                },
                'type: "object"
            }
        }
    };
    test:assertEquals(tools[3].parameters, expectedToolSchema);
}
