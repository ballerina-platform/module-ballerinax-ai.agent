import ballerina/test;

@test:Config {}
function testResolveSchema() {

    ObjectInputSchema inputSchema = {
        'type: OBJECT,
        required: ["queryParams", "path"],
        properties: {
            path: {
                'const: "customsearch/v1"
            },
            queryParams: {
                'type: OBJECT,
                properties: {
                    q: {
                        'type: STRING,
                        default: "AIzaSyAYFLQpxzp5XlQGkAR8URuBJGr9YiiZyIU"
                    },
                    cx: {
                        'type: STRING,
                        default: "d60e6379e9234405a"
                    },
                    key: {
                        'type: STRING,
                        description: "the search query"

                    }
                }
            }
        }
    };

    // map<AgentTool> toolMap = {};
    // Tool tool = {
    //     name: "Test tool",
    //     description: "Test tool description",
    //     inputSchema,
    //     caller: searchToolMock
    // };

    // registerTool(toolMap, [tool]);

    map<json>|json[]? resolvedSchema = resolveSchema(inputSchema);

    if resolvedSchema !is map<json> {
        test:assertFail("resolveSchema output is not a map<json>");
    }

    test:assertEquals(resolvedSchema, {
        path: "customsearch/v1",
        queryParams: {
            q: "AIzaSyAYFLQpxzp5XlQGkAR8URuBJGr9YiiZyIU",
            cx: "d60e6379e9234405a"
        }
    });

    test:assertEquals(inputSchema, {
        'type: OBJECT,
        required: ["queryParams"],
        properties: {
            queryParams: {
                'type: OBJECT,
                properties: {
                    q: {
                        'type: STRING
                    },
                    cx: {
                        'type: STRING
                    },
                    key: {
                        'type: STRING,
                        description: "the search query"

                    }
                }
            }
        }
    });

}
