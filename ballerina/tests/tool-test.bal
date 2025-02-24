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
    });

}

@test:Config {}
function testExecuteSuccessfullOutput() {
    ToolConfig sendEmailTool = {
        name: "Send mail",
        description: "useful to send emails to a given recipient",
        parameters: {
            properties: {
                'input: {
                    properties: {
                        senderEmail: {'const: "ballerina@email.com"},
                        messageRequest: {
                            properties: {
                                to: {
                                    items: {'type: STRING}
                                },
                                subject: {'type: STRING},
                                body: {
                                    'type: STRING,
                                    format: "text/html"
                                }
                            }
                        }
                    }
                }
            }
        },
        caller: sendMail
    };
    LlmToolResponse sendMailInput = {
        name: "Send_mail",
        arguments: {
            input: {
                messageRequest: {
                    to: ["alica@wso2.com"],
                    subject: "Greetings Alica!",
                    body: "<h1>Hi Alica</h1><p>Welcome to ai.agent module Alica</p>"
                }
            }
        }
    };
    ToolStore|error toolStore = new (sendEmailTool);
    if toolStore is error {
        test:assertFail("failed to create tool store: " + toolStore.message());
    }
    ToolOutput|error output = toolStore.execute(sendMailInput);
    if output is error {
        test:assertFail("failed to execute tool: " + output.message());
    }
    if output.value is error {
        test:assertFail("tool execution output is an error");
    }
}

@test:Config {}
function testExecuteErrorOutput() {
    ToolConfig sendEmailTool = {
        name: "Send mail",
        description: "useful to send emails to a given recipient",
        parameters: {
            properties: {
                'input: {
                    properties: {
                        senderEmail: {'const: "test@email.com"},
                        messageRequest: {
                            properties: {
                                to: {
                                    items: {'type: STRING}
                                },
                                subject: {'type: STRING},
                                body: {
                                    'type: STRING,
                                    format: "text/html"
                                }
                            }
                        }
                    }
                }
            }
        },
        caller: sendMail
    };
    LlmToolResponse sendMailInput = {
        name: "Send_mail",
        arguments: {
            input: {
                messageRequest: {
                    to: ["alica@wso2.com"],
                    subject: "Greetings Alica!",
                    body: "<h1>Hi Alica</h1><p>Welcome to ai.agent module Alica</p>"
                }
            }
        }
    };
    ToolStore|error toolStore = new (sendEmailTool);
    if toolStore is error {
        test:assertFail("failed to create tool store: " + toolStore.message());
    }
    ToolOutput|error output = toolStore.execute(sendMailInput);
    if output is error {
        test:assertFail("failed to execute tool: " + output.message());
    }
    if output.value !is error {
        test:assertFail("tool execution output is not an error");
    }
}

@test:Config {}
function testExecutionError() {
    ToolConfig sendEmailTool = {
        name: "Send mail",
        description: "useful to send emails to a given recipient",
        parameters: {
            properties: {
                'input: {
                    properties: {
                        senderEmail: {'const: "ballerina@email.com"},
                        messageRequest: {
                            properties: {
                                to: {
                                    items: {'type: STRING}
                                },
                                subject: {'type: STRING},
                                body: {
                                    'type: STRING,
                                    format: "text/html"
                                }
                            }
                        }
                    }
                }
            }
        },
        caller: sendMail
    };
    LlmToolResponse sendMailInput = {
        name: "Send_mail",
        arguments: {
            input: {
                messageRequest: {
                    to: "alica@wso2.com", // errornous generation
                    subject: "Greetings Alica!",
                    body: "<h1>Hi Alica</h1><p>Welcome to ai.agent module Alica</p>"
                }
            }
        }
    };
    ToolStore|error toolStore = new (sendEmailTool);
    if toolStore is error {
        test:assertFail("failed to create tool store: " + toolStore.message());
    }
    ToolOutput|error output = toolStore.execute(sendMailInput);
    if output !is error {
        test:assertFail("tool execution should failed with erronous generation, yet it is succesfull");
    }
}

@test:Config {}
function testToolWithDefaultParameters() returns error? {
    ToolConfig testToolConfig = {
        name: "testTool",
        description: "testTool",
        parameters: {
            properties: {
                a: {'type: STRING},
                b: {'type: STRING},
                c: {'type: STRING}
            },
            required: ["a"]
        },
        caller: testTool
    };
    LlmToolResponse testToolInput = {
        name: "testTool",
        arguments: {
            a: "required",
            c: "override"
        }
    };
    ToolStore toolStore = check new (testToolConfig);
    ToolOutput output = check toolStore.execute(testToolInput);
    test:assertEquals(output.value, "required default-one override");
}
