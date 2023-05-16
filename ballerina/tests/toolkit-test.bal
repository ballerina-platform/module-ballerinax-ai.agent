import ballerina/test;

HttpTool[] tools = [
    {
        name: "httpGet",
        path: "/example-get/{pathParam}",
        method: GET,
        description: "test HTTP GET tool"
    },
    {
        name: "httpPostWithSimpleSchema",
        path: "/example-post",
        method: POST,
        description: "test HTTP POST tool with simple schema",
        requestBody: {
            "attribute1": STRING,
            "attribute2": INTEGER,
            "attribute3": "string[]"
        }
    },
    {
        name: "httpDeleteWithComplexSchema",
        path: "/example-delete",
        method: DELETE,
        description: "test HTTP DELETE tool with complex schema",
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
                suffix: {'type: "string"}
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
    HttpServiceToolKit|error httpToolKit = new (serviceURL, tools, {auth: {token: "<API-TOKEN>"}}, {"timeout": "10000"});
    if httpToolKit is error {
        test:assertFail("HttpToolKit is not initialized due to an error");
    }
    Tool[]|error tools = httpToolKit.getTools();
    if tools is error {
        test:assertFail("Error occurred while getting tools from HttpToolKit");
    }
    test:assertEquals(tools.length(), 3);

    test:assertEquals(tools[0].name, "httpGet");
    test:assertEquals(tools[0].description, "test HTTP GET tool");
    test:assertEquals(tools[0].inputSchema, {
        'type: "object",
        properties: {
            path: {
                'type: "string",
                pattern: "/example-get/{pathParam}"
            }
        }
    });

    test:assertEquals(tools[1].name, "httpPostWithSimpleSchema");
    test:assertEquals(tools[1].description, "test HTTP POST tool with simple schema");
    test:assertEquals(tools[1].inputSchema, {
        path: "/example-post",
        requestBody: {
            attribute1: "string",
            attribute2: "integer",
            attribute3: "string[]"
        }
    });

    test:assertEquals(tools[2].name, "httpDeleteWithComplexSchema");
    test:assertEquals(tools[2].description, "test HTTP DELETE tool with complex schema");
    test:assertEquals(tools[2].inputSchema, {
        'type: "object",
        properties: {
            path: {
                'type: "string",
                pattern: "/example-delete"
            },
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
                    suffix: {'type: "string"}
                }
            }
        }
    });

}
