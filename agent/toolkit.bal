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

public enum HttpMethod {
    GET, POST, DELETE
}

public type Headers record {|
    string|string[]...;
|};

public type Parameters record {|
    string|string[]...;
|};

public type HttpTool record {|
    string name;
    string description;
    string path;
    HttpMethod method;
    Parameters queryParams = {};
    json requestBody = {};
|};

type HttpInput record {
    *InputSchema;
    string path;
    Parameters queryParams?;
    Headers headers?;
    json payload = {};
};

public type BaseToolKit distinct object {
    ToolStore toolStore;
    function initializeToolKit(ToolStore store);
};

public class HttpToolKit {
    *BaseToolKit;
    private Headers headers;
    private http:Client httpClient;

    public function init(string serviceUrl, HttpTool[] tools, HttpClientConfig clientConfig = {}, Headers headers = {}) returns error? {
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
        foreach HttpTool httpTool in httpTools {
            HttpInput httpIn = {
                path: httpTool.path,
                queryParams: httpTool.queryParams
            };
            function httpCaller = self.get;
            match httpTool.method {
                GET => {
                    // do nothing (default)
                }
                POST => {
                    httpIn.payload = httpTool.requestBody;
                    httpCaller = self.post;

                }
                DELETE => {
                    httpIn.payload = httpTool.requestBody;
                    httpCaller = self.delete;

                }
                _ => {
                    return error("invalid http type");
                }
            }

            Tool tool = {
                name: httpTool.name,
                description: httpTool.description + ". Path parameters should be replaced with appropriate values",
                inputs: httpIn,
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
        http:Response|http:ClientError getResult = self.httpClient->post(httpInput.path, message = httpInput.payload, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

    private function delete(*HttpInput httpInput) returns string|error {
        // TODO need a way to use query params. Waiting for an solution in discord channel.
        http:Response|http:ClientError getResult = self.httpClient->post(httpInput.path, message = httpInput.payload, headers = self.headers);
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

    public function init(string filePath, string? serviceUrl = (), HttpClientConfig clientConfig = {}, Headers headers = {}) returns error? {
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
