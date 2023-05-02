// Copyright (c) 2023 WSO2 LLC (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;

public type HttpClientConfig http:ClientConfiguration;

public type BaseToolKit distinct object {
    ToolStore toolStore;
    function initializeToolKit(ToolStore store);
};

public class HttpToolKit {
    *BaseToolKit;
    private map<string|string[]> headers;
    private http:Client httpClient;

    public function init(string serviceUrl, HttpTool[] tools, HttpClientConfig clientConfig = {}, map<string|string[]> headers = {}) returns error? {
        self.toolStore = new;
        self.headers = headers;
        self.httpClient = check new (serviceUrl, clientConfig);
        check self.registerTools(...tools);
    }

    function initializeToolKit(ToolStore store) {
        store.mergeToolStore(self.toolStore);
        self.toolStore = store;
    }

    private function registerTools(HttpTool... httpTools) returns error? {
        InputSchema inputSchema;

        foreach HttpTool httpTool in httpTools {
            InputSchema? queryParams = httpTool.queryParams;
            InputSchema? requestBody = httpTool.requestBody;

            if (queryParams is JsonInputSchema && requestBody is SimpleInputSchema) ||
            (queryParams is SimpleInputSchema && requestBody is JsonInputSchema) {
                return error("Unsupported input schema combination. " +
                "Both `queryParams` and `requestBody` should be either `JsonInputSchema` or `SimpleInputSchema`");
            }

            if queryParams is JsonInputSchema || requestBody is JsonInputSchema {
                HttpJsonInputSchema jsonInputSchema = {
                    properties: {
                        path: {pattern: httpTool.path},
                        queryParams: <JsonInputSchema?>queryParams ?: (),
                        requestBody: <JsonInputSchema?>requestBody ?: ()
                    }
                };
                inputSchema = jsonInputSchema;
            } else {
                HttpSimpleInputSchema httpInputSchema = {
                    path: httpTool.path,
                    queryParams: <SimpleInputSchema?>queryParams ?: (),
                    requestBody: <SimpleInputSchema?>requestBody ?: ()
                };
                inputSchema = httpInputSchema;
            }

            function httpCaller = self.get;
            match httpTool.method {
                GET => {
                    // do nothing (default)
                }
                POST => {
                    httpCaller = self.post;

                }
                DELETE => {
                    httpCaller = self.delete;

                }
                PUT => {
                    httpCaller = self.put;

                }
                PATCH => {
                    httpCaller = self.patch;

                }
                HEAD => {
                    httpCaller = self.head;

                }
                OPTIONS => {
                    httpCaller = self.options;

                }
                _ => {
                    return error("invalid http type");
                }
            }

            Tool tool = {
                name: httpTool.name,
                description: httpTool.description,
                inputs: inputSchema,
                caller: httpCaller
            };
            check self.toolStore.registerTools(tool);
        }
    }

    private function get(*HttpInput httpInput) returns string|error {
        // TODO need a way to use query params. Waiting for an solution in discord channel.
        http:Response|http:ClientError getResult = self.httpClient->get(httpInput.path, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

    private function post(*HttpInput httpInput) returns string|error {
        // TODO need a way to use query params. Waiting for an solution in discord channel.
        http:Response|http:ClientError getResult = self.httpClient->post(httpInput.path, message = httpInput?.requestBody, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

    private function delete(*HttpInput httpInput) returns string|error {
        // TODO need a way to use query params. Waiting for an solution in discord channel.
        http:Response|http:ClientError getResult = self.httpClient->delete(httpInput.path, message = httpInput?.requestBody, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

    private function put(*HttpInput httpInput) returns string|error {
        // TODO need a way to use query params. Waiting for an solution in discord channel.
        http:Response|http:ClientError getResult = self.httpClient->put(httpInput.path, message = httpInput?.requestBody, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

    private function patch(*HttpInput httpInput) returns string|error {
        // TODO need a way to use query params. Waiting for an solution in discord channel.
        http:Response|http:ClientError getResult = self.httpClient->patch(httpInput.path, message = httpInput?.requestBody, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

    private function head(*HttpInput httpInput) returns string|error {
        // TODO need a way to use query params. Waiting for an solution in discord channel.
        http:Response|http:ClientError getResult = self.httpClient->head(httpInput.path, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

    private function options(*HttpInput httpInput) returns string|error {
        // TODO need a way to use query params. Waiting for an solution in discord channel.
        http:Response|http:ClientError getResult = self.httpClient->options(httpInput.path, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }
}

public class OpenAPIToolKit {
    *BaseToolKit;
    HttpToolKit httpToolKit;

    public function init(string filePath, string? serviceUrl = (), HttpClientConfig clientConfig = {}, map<string|string[]> headers = {}) returns error? {
        self.toolStore = new;
        OpenAPIParser parser = check new (filePath);

        string serverUrl;
        if serviceUrl is string {
            serverUrl = serviceUrl;
        } else {
            serverUrl = check parser.resolveServerURL();
        }

        HttpTool[] listResult = check parser.resolvePaths();
        self.httpToolKit = check new (serverUrl, listResult, clientConfig, headers);
    }

    function initializeToolKit(ToolStore store) {
        store.mergeToolStore(self.toolStore);
        self.toolStore = store;
        self.httpToolKit.initializeToolKit(store);
    }

}
