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

            if (queryParams is JsonInputSchema && (requestBody is SimpleInputSchema && requestBody != {})) ||
            ((queryParams is SimpleInputSchema && queryParams != {}) && requestBody is JsonInputSchema) {
                return error("Unsupported input schema combination. " +
                "Both `queryParams` and `requestBody` should be either `JsonInputSchema` or `SimpleInputSchema`");
            }

            if queryParams == {} {
                queryParams = ();
            }
            if requestBody == {} {
                requestBody = ();
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
        map<json>? queryParams = httpInput?.queryParams;
        string path = httpInput.path;
        if queryParams !is () {
            path += check buildQueryURL(queryParams);
        }
        http:Response|http:ClientError getResult = self.httpClient->get(path, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

    private function post(*HttpInput httpInput) returns string|error {
        map<json>? queryParams = httpInput?.queryParams;
        string path = httpInput.path;
        if queryParams !is () {
            path += check buildQueryURL(queryParams);
        }
        http:Response|http:ClientError getResult = self.httpClient->post(path, message = httpInput?.requestBody, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

    private function delete(*HttpInput httpInput) returns string|error {
        map<json>? queryParams = httpInput?.queryParams;
        string path = httpInput.path;
        if queryParams !is () {
            path += check buildQueryURL(queryParams);
        }
        http:Response|http:ClientError getResult = self.httpClient->delete(path, message = httpInput?.requestBody, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

    private function put(*HttpInput httpInput) returns string|error {
        map<json>? queryParams = httpInput?.queryParams;
        string path = httpInput.path;
        if queryParams !is () {
            path += check buildQueryURL(queryParams);
        }
        http:Response|http:ClientError getResult = self.httpClient->put(path, message = httpInput?.requestBody, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

    private function patch(*HttpInput httpInput) returns string|error {
        map<json>? queryParams = httpInput?.queryParams;
        string path = httpInput.path;
        if queryParams !is () {
            path += check buildQueryURL(queryParams);
        }
        http:Response|http:ClientError getResult = self.httpClient->patch(path, message = httpInput?.requestBody, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

    private function head(*HttpInput httpInput) returns string|error {
        map<json>? queryParams = httpInput?.queryParams;
        string path = httpInput.path;
        if queryParams !is () {
            path += check buildQueryURL(queryParams);
        }
        http:Response|http:ClientError getResult = self.httpClient->head(path, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

    private function options(*HttpInput httpInput) returns string|error {
        map<json>? queryParams = httpInput?.queryParams;
        string path = httpInput.path;
        if queryParams !is () {
            path += check buildQueryURL(queryParams);
        }
        http:Response|http:ClientError getResult = self.httpClient->options(path, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }
}

function buildQueryURL(map<json> queryparams) returns string|error {
    string query = "?";
    foreach [string, json] param in queryparams.entries() {
        string key = param[0];
        json value = param[1];
        if value is string {
            query += string `${key}=${value}&`;
        } else if value is string[] {
            query += <string>from string element in value
                select key + "=" + element + "&";
        } else {
            return error(string `Unsupported query parameter value: ${value.toString()} for key ${key}`);
        }
    }
    return query.substring(0, query.length() - 1);
}

public class OpenAPIToolKit {
    *BaseToolKit;
    private HttpToolKit httpToolKit;

    public function init(string filePath, string? serviceUrl = (), HttpClientConfig clientConfig = {}, map<string|string[]> headers = {}) returns error? {
        OpenAPISpec openAPISchema = check parseOpenAPISpec(filePath);
        OpenAPISpecVisitor visitor = new;
        check visitor.visit(openAPISchema);

        string serverUrl;
        if serviceUrl is string {
            serverUrl = serviceUrl;
        } else {
            if visitor.serverURL is string {
                serverUrl = <string>visitor.serverURL;
            } else {
                return error("server url is not provided");
            }
        }
        HttpTool[] listResult = visitor.tools;
        self.httpToolKit = check new (serverUrl, listResult, clientConfig, headers);
        self.toolStore = self.httpToolKit.toolStore;

    }

    function initializeToolKit(ToolStore store) {
        store.mergeToolStore(self.toolStore);
        self.toolStore = store;
        self.httpToolKit.initializeToolKit(store);
    }

}
