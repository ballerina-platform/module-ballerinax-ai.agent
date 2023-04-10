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

public type Json record {|
    string|string[]|map<json>...;
|};

public type Headers record {|
    string|string[]...;
|};

public type Parameters record {|
    string|string[]...;
|};

public type HttpAction record {|
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

public type ActionLoader distinct object {
    ActionStore actionStore;
    function initializeLoader(ActionStore store);

};

public class HttpLoader {
    *ActionLoader;
    private Headers headers;
    private http:Client httpClient;

    public function init(string serviceUrl, HttpClientConfig clientConfig = {}, Headers headers = {}) returns error? {
        self.actionStore = new;
        self.headers = headers;
        self.httpClient = check new (serviceUrl, clientConfig);
    }

    function initializeLoader(ActionStore store) {
        store.mergeActionStore(self.actionStore);
        self.actionStore = store;
    }

    public function registerActions(HttpAction... httpActions) returns error? {
        foreach HttpAction httpAction in httpActions {
            HttpInput httpIn = {
                path: httpAction.path,
                queryParams: httpAction.queryParams
            };
            function httpCaller = self.get;
            match httpAction.method {
                GET => {
                    // do nothing (default)
                }
                POST => {
                    httpIn.payload = httpAction.requestBody;
                    httpCaller = self.post;

                }
                DELETE => {
                    httpIn.payload = httpAction.requestBody;
                    httpCaller = self.delete;

                }
                _ => {
                    return error("invalid http type");
                }
            }

            Action action = {
                name: httpAction.name,
                description: httpAction.description + ". Path parameters should be replaced with appropriate values",
                inputs: httpIn,
                caller: httpCaller
            };
            self.actionStore.registerActions(action);
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

public class OpenAPILoader {
    *ActionLoader;
    HttpLoader httpLoader;

    public function init(string filePath, string? serviceUrl = (), HttpClientConfig clientConfig = {}, Headers headers = {}) returns error? {
        self.actionStore = new;
        OpenAPIParser parser = check new (filePath);

        string serverUrl;
        if serviceUrl is string {
            serverUrl = serviceUrl;
        } else {
            serverUrl = check parser.resolveServerURL();
        }

        self.httpLoader = check new (serverUrl, clientConfig, headers);
        OpenAPIAction[] listResult = check parser.resolvePaths();
        check self.httpLoader.registerActions(...listResult);
    }

    function initializeLoader(ActionStore store) {
        store.mergeActionStore(self.actionStore);
        self.actionStore = store;
        self.httpLoader.initializeLoader(store);
    }

}
