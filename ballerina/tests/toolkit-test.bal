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

@test:Config {}
function testHttpToolKitInitialization() {
    string serviceURL = "http://test-wifi-url.com";
    HttpToolKit|error httpToolKit = new (serviceURL, tools, {auth: {token: "<API-TOKEN>"}}, {timeout: "10000"});
    test:assertTrue(httpToolKit is HttpToolKit, "HttpToolKit is not initialized due to an error");
    if httpToolKit is HttpToolKit {
        ToolInfo toolInfo = httpToolKit.toolStore.extractToolInfo();
        test:assertEquals(toolInfo.toolList, string `${tools[0].name}, ${tools[1].name}, ${tools[2].name}`);
        test:assertEquals(toolInfo.toolIntro,
            string `${tools[0].name}: {"description":"${tools[0].description}","inputSchema":{"path":"${tools[0].path}"}}
${tools[1].name}: {"description":"${tools[1].description}","inputSchema":{"path":"${tools[1].path}","requestBody":${tools[1].requestBody.toString()}}}
${tools[2].name}: {"description":"${tools[2].description}","inputSchema":{"required":["path"],"properties":{"path":{"type":"string","pattern":"${tools[2].path}"},"requestBody":${tools[2].requestBody.toString()}},"type":"object"}}`);
    }
}

@test:Config {}
function testOpenAPIToolKitInitialization() {
    string wifiSpecPath = "tests/resources/wifi-spec.json";
    string serviceURL = "http://test-wifi-url.com";

    OpenAPIToolKit|error openAPIToolKit = new (wifiSpecPath, serviceURL, {auth: {token: "<API-TOKEN>"}}, {timeout: "10000"});

    test:assertTrue(openAPIToolKit is OpenAPIToolKit, "OpenAPIToolKit is not initialized due to an error");
    if openAPIToolKit is OpenAPIToolKit {
        ToolInfo toolInfo = openAPIToolKit.toolStore.extractToolInfo();
        test:assertEquals(toolInfo.toolList, "getGuestWifiAccountsOwneremail, postGuestWifiAccounts, deleteGuestWifiAccountsOwneremailUsername");
        test:assertEquals(toolInfo.toolIntro,
            "getGuestWifiAccountsOwneremail: {\"description\":\"Get list of guest WiFi accounts of a given owner email address\",\"inputSchema\":{\"path\":\"/guest-wifi-accounts/{ownerEmail}\"}}\n" +
            "postGuestWifiAccounts: {\"description\":\"Create new guest WiFi account\",\"inputSchema\":{\"required\":[\"path\"],\"properties\":{\"path\":{\"type\":\"string\",\"pattern\":\"/guest-wifi-accounts\"},\"requestBody\":{" +
                "\"allOf\":[{\"type\":\"object\",\"properties\":{\"email\":{\"type\":\"string\"},\"username\":{\"type\":\"string\"}}},{\"type\":\"object\",\"properties\":{\"password\":{\"type\":\"string\"}}}]}},\"type\":\"object\"}}\n" +
            "deleteGuestWifiAccountsOwneremailUsername: {\"description\":\"Delete a guest WiFi account\",\"inputSchema\":{\"path\":\"/guest-wifi-accounts/{ownerEmail}/{username}\"}}");
    }
}
