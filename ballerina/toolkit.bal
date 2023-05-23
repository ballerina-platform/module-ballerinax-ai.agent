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
import ballerina/log;
import ballerina/regex;

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
            InputSchema? pathParams = httpTool?.pathParams;
            InputSchema? requestBody = httpTool?.requestBody;

            if (requestBody !is () && requestBody.length() == 0)
            || (queryParams !is () && queryParams.length() == 0)
            || (pathParams !is () && pathParams.length() == 0) {
                return error("Invalid requestBody or queryParameter or pathParameter schemas. Empty records are not allowed, use null instead.");
            }

            if !(queryParams is SimpleInputSchema? && requestBody is SimpleInputSchema? && pathParams is SimpleInputSchema?) &&
            !(queryParams is JsonInputSchema? && requestBody is JsonInputSchema? && pathParams is JsonInputSchema?)
            {
                return error("Unsupported input schema combination. " +
                "Both `queryParams` and `requestBody` should be either `JsonInputSchema` or `SimpleInputSchema`");
            }

            InputSchema inputSchema;
            if queryParams is JsonInputSchema || requestBody is JsonInputSchema || pathParams is JsonInputSchema {
                map<JsonSubSchema> properties = {path: {'const: httpTool.path}};
                string[] required = [PATH_KEY];
                inputSchema = {properties, required};
                if queryParams is JsonInputSchema {
                    properties[QUERY_PARAM_KEY] = queryParams;
                    required.push(QUERY_PARAM_KEY);
                }
                if requestBody is JsonInputSchema {
                    properties[REQUEST_BODY_KEY] = requestBody;
                    required.push(REQUEST_BODY_KEY);
                }
                if pathParams is JsonInputSchema {
                    properties[PATH_PARAM_KEY] = pathParams;
                    required.push(PATH_PARAM_KEY);
                }
            }
            else {
                inputSchema = {"path": httpTool.path};
                if queryParams is SimpleInputSchema {
                    inputSchema[QUERY_PARAM_KEY] = queryParams;
                }
                if requestBody is SimpleInputSchema {
                    inputSchema[REQUEST_BODY_KEY] = requestBody;
                }
                if pathParams is SimpleInputSchema {
                    inputSchema[PATH_PARAM_KEY] = pathParams;
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

    private isolated function get(HttpInput httpInput) returns json|error {
        string path = check getPathWithParams(httpInput.path, httpInput?.queryParams, httpInput?.pathParams);
        log:printDebug(string `HTTP GET ${path} ${httpInput?.requestBody.toString()}`);
        http:Response getResult = check self.httpClient->get(path, headers = self.headers);
        return getResult.getTextPayload(); // TODO improve http:Client error response handling
    }

    private isolated function post(HttpInput httpInput) returns string|error {
        string path = check getPathWithParams(httpInput.path, httpInput?.queryParams, httpInput?.pathParams);
        log:printDebug(string `HTTP POST ${path} ${httpInput?.requestBody.toString()}`);
        http:Response postResult = check self.httpClient->post(path, message = httpInput?.requestBody, headers = self.headers);
        return postResult.getTextPayload();
    }

    private isolated function delete(HttpInput httpInput) returns string|error {
        string path = check getPathWithParams(httpInput.path, httpInput?.queryParams, httpInput?.pathParams);
        log:printDebug(string `HTTP DELETE ${path} ${httpInput?.requestBody.toString()}`);
        http:Response deleteResult = check self.httpClient->delete(path, message = httpInput?.requestBody, headers = self.headers);
        return deleteResult.getTextPayload();
    }

    private isolated function put(HttpInput httpInput) returns string|error {
        string path = check getPathWithParams(httpInput.path, httpInput?.queryParams, httpInput?.pathParams);
        log:printDebug(string `HTTP PUT ${path} ${httpInput?.requestBody.toString()}`);
        http:Response putResult = check self.httpClient->put(path, message = httpInput?.requestBody, headers = self.headers);
        return putResult.getTextPayload();
    }

    private isolated function patch(HttpInput httpInput) returns string|error {
        string path = check getPathWithParams(httpInput.path, httpInput?.queryParams, httpInput?.pathParams);
        log:printDebug(string `HTTP PATH ${path} ${httpInput?.requestBody.toString()}`);
        http:Response patchResult = check self.httpClient->patch(path, message = httpInput?.requestBody, headers = self.headers);
        return patchResult.getTextPayload();
    }

    private isolated function head(HttpInput httpInput) returns string|error {
        string path = check getPathWithParams(httpInput.path, httpInput?.queryParams, httpInput?.pathParams);
        log:printDebug(string `HTTP HEAD ${path} ${httpInput?.requestBody.toString()}`);
        http:Response headResult = check self.httpClient->head(path, headers = self.headers);
        return headResult.getTextPayload();
    }

    private isolated function options(HttpInput httpInput) returns string|error {
        string path = check getPathWithParams(httpInput.path, httpInput?.queryParams, httpInput?.pathParams);
        log:printDebug(string `HTTP OPTIONS ${path} ${httpInput?.requestBody.toString()}`);
        http:Response optionsResult = check self.httpClient->options(path, headers = self.headers);
        return optionsResult.getTextPayload();
    }
}

isolated function getPathWithParams(string path, map<json>? queryParams, map<json>? pathParams) returns string|error {
    string pathWithParams = path;
    if pathParams is map<json> {
        foreach [string, json] [key, value] in pathParams.entries() {
            string _key = key; // temp added due to null pointer issue
            json _value = value; // temp added due to null pointer issue
            if _value is string {
                pathWithParams = regex:replaceAll(pathWithParams, string `\{${_key}\}`, _value);
            } else {
                return error(string `Unsupported path parameter value: ${value.toString()} for key ${key}`);
            }
        }
    }
    if queryParams is () {
        return pathWithParams;
    }

    string query = "?";
    foreach [string, json] [key, value] in queryParams.entries() {
        if value is string {
            query += string `${key}=${value}&`;
        } else if value is string[] {
            // can't use query expressions due to bug in ballerina
            foreach string element in value {
                query += string `${key}=${element}&`;
            }
        } else {
            return error(string `Unsupported query parameter value: ${value.toString()} for key ${key}`);
        }
    }
    return pathWithParams + query.substring(0, query.length() - 1);
}
