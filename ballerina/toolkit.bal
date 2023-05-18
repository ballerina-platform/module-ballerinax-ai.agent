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

# allows implmenting custom toolkits by extending this type
public type BaseToolKit distinct object {
    isolated function getTools() returns Tool[]|error;
};

public type HttpHeader readonly & record {|string|string[]...;|};

public isolated class HttpServiceToolKit {
    *BaseToolKit;
    private final Tool[] & readonly tools;
    private final HttpHeader headers;
    private final http:Client httpClient;

    public isolated function init(string serviceUrl, HttpTool[] httpTools, http:ClientConfiguration clientConfig = {}, HttpHeader headers = {}) returns error? {
        self.headers = headers.cloneReadOnly();
        self.httpClient = check new (serviceUrl, clientConfig);

        Tool[] tools = [];
        foreach HttpTool httpTool in httpTools {
            InputSchema? queryParams = httpTool?.queryParams;
            InputSchema? requestBody = httpTool?.requestBody;

            if (requestBody !is () && requestBody.length() == 0) || (queryParams !is () && queryParams.length() == 0) {
                return error("Invalid requestBody or queryParameter schemas. Empty records are not allowed, use null instead.");
            }

            if (queryParams is JsonInputSchema && requestBody is SimpleInputSchema) || (queryParams is SimpleInputSchema && requestBody is JsonInputSchema) {
                return error("Unsupported input schema combination. " +
                "Both `queryParams` and `requestBody` should be either `JsonInputSchema` or `SimpleInputSchema`");
            }

            InputSchema inputSchema;
            if queryParams is JsonInputSchema? && requestBody is JsonInputSchema? {
                map<JsonSubSchema> properties = {path: {'type: STRING, pattern: httpTool.path}};
                inputSchema = {properties};
                if queryParams is JsonSubSchema {
                    properties[QUERY_PARAM_KEY] = queryParams;
                }
                if requestBody is JsonSubSchema {
                    properties[REQUEST_BODY_KEY] = requestBody;
                }
            } else {
                inputSchema = {"path": httpTool.path};
                if queryParams is SimpleInputSchema {
                    inputSchema[QUERY_PARAM_KEY] = queryParams;
                }
                if requestBody is SimpleInputSchema {
                    inputSchema[REQUEST_BODY_KEY] = requestBody;
                }
            }

            isolated function caller = self.get;
            match httpTool.method {
                GET => { // do nothing (default)
                }
                POST => {
                    caller = self.post;
                }
                DELETE => {
                    caller = self.delete;
                }
                PUT => {
                    caller = self.put;
                }
                PATCH => {
                    caller = self.patch;
                }
                HEAD => {
                    caller = self.head;
                }
                OPTIONS => {
                    caller = self.options;
                }
                _ => {
                    return error("invalid http type: " + httpTool.method.toString());
                }
            }
            tools.push({
                name: httpTool.name,
                description: httpTool.description,
                inputSchema,
                caller
            });

            self.tools = tools.cloneReadOnly();
        }
    }

    isolated function getTools() returns Tool[]|error {
        return self.tools;
    }

    private isolated function get(HttpInput httpInput) returns string|error {
        string path = check getPathWithQueryParams(httpInput.path, httpInput?.queryParams);
        http:Response getResult = check self.httpClient->get(path, headers = self.headers);
        return getResult.getTextPayload();
    }

    private isolated function post(HttpInput httpInput) returns string|error {
        string path = check getPathWithQueryParams(httpInput.path, httpInput?.queryParams);
        http:Response postResult = check self.httpClient->post(path, message = httpInput?.requestBody, headers = self.headers);
        return postResult.getTextPayload();
    }

    private isolated function delete(HttpInput httpInput) returns string|error {
        string path = check getPathWithQueryParams(httpInput.path, httpInput?.queryParams);
        http:Response deleteResult = check self.httpClient->delete(path, message = httpInput?.requestBody, headers = self.headers);
        return deleteResult.getTextPayload();
    }

    private isolated function put(HttpInput httpInput) returns string|error {
        string path = check getPathWithQueryParams(httpInput.path, httpInput?.queryParams);
        http:Response putResult = check self.httpClient->put(path, message = httpInput?.requestBody, headers = self.headers);
        return putResult.getTextPayload();
    }

    private isolated function patch(HttpInput httpInput) returns string|error {
        string path = check getPathWithQueryParams(httpInput.path, httpInput?.queryParams);
        http:Response patchResult = check self.httpClient->patch(path, message = httpInput?.requestBody, headers = self.headers);
        return patchResult.getTextPayload();
    }

    private isolated function head(HttpInput httpInput) returns string|error {
        string path = check getPathWithQueryParams(httpInput.path, httpInput?.queryParams);
        http:Response headResult = check self.httpClient->head(path, headers = self.headers);
        return headResult.getTextPayload();
    }

    private isolated function options(HttpInput httpInput) returns string|error {
        string path = check getPathWithQueryParams(httpInput.path, httpInput?.queryParams);
        http:Response optionsResult = check self.httpClient->options(path, headers = self.headers);
        return optionsResult.getTextPayload();
    }
}

isolated function getPathWithQueryParams(string path, map<json>? queryParams) returns string|error {
    if queryParams is () {
        return path;
    }

    string query = "?";
    foreach [string, json] [key, value] in queryParams.entries() {
        if value is string {
            query += string `${key}=${value}&`;
        } else if value is string[] {
            foreach string element in value {
                query += string `${key}=${element}&`;
            }
        } else {
            return error(string `Unsupported query parameter value: ${value.toString()} for key ${key}`);
        }
    }
    return path + query.substring(0, query.length() - 1);
}
