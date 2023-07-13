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

# Supported HTTP methods.
public enum HttpMethod {
    GET, POST, DELETE, PUT, PATCH, HEAD, OPTIONS
}

# Define parameter types for HTTP parameters.
public type ParameterType ConstantValueSchema|PrimitiveInputSchema|ArrayTypeParameterSchema;

# Defines a HTTP parameter schema for Array type parameters.
#
# + items - Array item type
# + default - Default value of the parameter
public type ArrayTypeParameterSchema record {|
    *ArrayInputSchema;
    PrimitiveInputSchema|ConstantValueSchema items;
    PrimitiveType[] default?;
|};

# Defines a HTTP parameter schema (can be query parameter or path parameters).
#
# + required - A list of mandatory parameters
# + properties - A map of parameter names and their types
public type ParameterSchema record {|
    string[] required?;
    map<ParameterType> properties;
|};

# Defines an HTTP tool. This is a special type of tool that can be used to invoke HTTP resources.
#
# + name - Name of the Http resource tool
# + description - Description of the Http resource tool used by the LLM
# + method - Http method type (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS)
# + path - Path of the Http resource
# + queryParameters - Query parameters definitions of the Http resource
# + pathParameters - Path parameter definitions of the Http resource
# + requestBody - Request body definition of the Http resource
public type HttpTool record {|
    string name;
    string description;
    HttpMethod method;
    string path;
    ParameterSchema queryParameters?;
    ParameterSchema pathParameters?;
    JsonInputSchema requestBody?;
|};

// input record definitions ----------------------------
# Defines an HTTP input record.
# + path - Path of the Http resource
# + queryParameters - Query parameters of the Http resource
# + pathParameters - Path parameters of the Http resource
# + requestBody - Request body of the Http resource
type HttpInput record {|
    string path;
    map<json> queryParameters?;
    map<json> pathParameters?;
    map<json> requestBody?;
|};

# Allows implmenting custom toolkits by extending this type. Toolkits can help to define new types of tools so that agent can understand them.
public type BaseToolKit distinct object {
    isolated function getTools() returns Tool[]|error;
};

# Provide definition to an HTTP header
public type HttpHeader readonly & record {|string|string[]...;|};

# Defines a HTTP tool kit. This is a special type of tool kit that can be used to invoke HTTP resources.
# Require to initialize the toolkit with the service url and http tools that are belongs to a singel API. 
public isolated class HttpServiceToolKit {
    *BaseToolKit;
    private final Tool[] & readonly tools;
    private final HttpHeader headers;
    private final http:Client httpClient;

    # Initializes the toolkit with the given service url and http tools.
    #
    # + serviceUrl - The url of the service to be called
    # + httpTools - The http tools to be initialized
    # + clientConfig - The http client configuration associated to the tools
    # + headers - The http headers to be used in the requests
    # + returns - error if the initialization fails
    public isolated function init(string serviceUrl, HttpTool[] httpTools, http:ClientConfiguration clientConfig = {}, HttpHeader headers = {}) returns error? {
        self.headers = headers.cloneReadOnly();
        self.httpClient = check new (serviceUrl, clientConfig);

        Tool[] tools = [];
        foreach HttpTool httpTool in httpTools {
            ParameterSchema? queryParameters = httpTool?.queryParameters;
            ParameterSchema? pathParameters = extractPathParams(httpTool.path, httpTool?.pathParameters);
            JsonInputSchema? requestBody = httpTool?.requestBody;

            map<JsonSubSchema> properties = {path: {'const: httpTool.path}};

            if queryParameters !is () {
                properties[QUERY_PARAM_KEY] = {
                    ...queryParameters
                };
            }

            if pathParameters !is () {
                properties[PATH_PARAM_KEY] = {
                    ...pathParameters
                };
            }

            if requestBody !is () {
                properties[REQUEST_BODY_KEY] = requestBody;
            }

            JsonInputSchema parameters = {
                properties
            };

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
                parameters,
                caller
            });

            self.tools = tools.cloneReadOnly();
        }
    }

    isolated function getTools() returns Tool[]|error => self.tools;

    private isolated function get(HttpInput httpInput) returns json|error {
        string path = check getPathWithParams(httpInput.path, httpInput?.pathParameters, httpInput?.queryParameters);
        log:printDebug(string `HTTP GET ${path} ${httpInput?.requestBody.toString()}`);
        http:Response getResult = check self.httpClient->get(path, headers = self.headers);
        return getResult.getTextPayload(); // TODO improve http:Client error response handling
    }

    private isolated function post(HttpInput httpInput) returns string|error {
        string path = check getPathWithParams(httpInput.path, httpInput?.pathParameters, httpInput?.queryParameters);
        log:printDebug(string `HTTP POST ${path} ${httpInput?.requestBody.toString()}`);
        http:Response postResult = check self.httpClient->post(path, message = httpInput?.requestBody, headers = self.headers);
        return postResult.getTextPayload();
    }

    private isolated function delete(HttpInput httpInput) returns string|error {
        string path = check getPathWithParams(httpInput.path, httpInput?.pathParameters, httpInput?.queryParameters);
        log:printDebug(string `HTTP DELETE ${path} ${httpInput?.requestBody.toString()}`);
        http:Response deleteResult = check self.httpClient->delete(path, message = httpInput?.requestBody, headers = self.headers);
        return deleteResult.getTextPayload();
    }

    private isolated function put(HttpInput httpInput) returns string|error {
        string path = check getPathWithParams(httpInput.path, httpInput?.pathParameters, httpInput?.queryParameters);
        log:printDebug(string `HTTP PUT ${path} ${httpInput?.requestBody.toString()}`);
        http:Response putResult = check self.httpClient->put(path, message = httpInput?.requestBody, headers = self.headers);
        return putResult.getTextPayload();
    }

    private isolated function patch(HttpInput httpInput) returns string|error {
        string path = check getPathWithParams(httpInput.path, httpInput?.pathParameters, httpInput?.queryParameters);
        log:printDebug(string `HTTP PATH ${path} ${httpInput?.requestBody.toString()}`);
        http:Response patchResult = check self.httpClient->patch(path, message = httpInput?.requestBody, headers = self.headers);
        return patchResult.getTextPayload();
    }

    private isolated function head(HttpInput httpInput) returns string|error {
        string path = check getPathWithParams(httpInput.path, httpInput?.pathParameters, httpInput?.queryParameters);
        log:printDebug(string `HTTP HEAD ${path} ${httpInput?.requestBody.toString()}`);
        http:Response headResult = check self.httpClient->head(path, headers = self.headers);
        return headResult.getTextPayload();
    }

    private isolated function options(HttpInput httpInput) returns string|error {
        string path = check getPathWithParams(httpInput.path, httpInput?.pathParameters, httpInput?.queryParameters);
        log:printDebug(string `HTTP OPTIONS ${path} ${httpInput?.requestBody.toString()}`);
        http:Response optionsResult = check self.httpClient->options(path, headers = self.headers);
        return optionsResult.getTextPayload();
    }
}

isolated function pathParameterSerialization(PrimitiveType|PrimitiveType[] value) returns string {
    // implements only the default serialization (style:simple and explode:false)
    if value is PrimitiveType {
        return value.toString();
    }
    string result = value.toString();
    return result.substring(1, result.length() - 1);
}

isolated function queryParameterSerialization(string key, PrimitiveType|PrimitiveType[] value) returns string {
    // implements only the default serialization (style=form and explode=false)
    if value is PrimitiveType {
        return string `${key}=${value}`;
    }
    string result = <string>from PrimitiveType element in value
        select string `${key}=${element}&`;
    return result.substring(0, result.length() - 1);

}

isolated function extractParamValue(string key, json parameterValue) returns PrimitiveType|PrimitiveType[]|error {
    if parameterValue is PrimitiveType {
        return parameterValue;
    }
    if parameterValue !is json[] {
        return error(string `Unsupported HTTP parameter value. Expected primitive type or array type, but found '${parameterValue.toString()}' for key '${key}'`);
    }
    PrimitiveType[] arrayValues = [];
    foreach json element in parameterValue {
        if element is PrimitiveType {
            arrayValues.push(element);
        } else {
            return error(string `Unsupported value for array type HTTP parameter. Expected primitive type, but found '${element.toString()}' for key '${key}'`);
        }
    }
    return arrayValues;
}

isolated function getPathWithParams(string path, map<json>? pathParameters, map<json>? queryParameters) returns string|error {
    string pathWithParams = path;

    if pathParameters !is () {
        foreach [string, json] [parameterKey, parameterValue] in pathParameters.entries() {
            string key = parameterKey; // TODO: remove later. temp added due to null pointer issue
            PrimitiveType|PrimitiveType[] value = check extractParamValue(key, parameterValue);
            if pathWithParams.includes(string `{${key}}`) { // this is a path parameter
                pathWithParams = regex:replaceAll(pathWithParams, string `\{${key}\}`, pathParameterSerialization(value));
            } else {
                return error(string `Path parameter ${key} is not defined in the path ${path}`);
            }
        }
    }
    if queryParameters is () {
        return pathWithParams;
    }
    string query = "?";
    foreach [string, json] [parameterKey, parameterValue] in queryParameters.entries() {
        string key = parameterKey; // TODO: remove later. temp added due to null pointer issue
        PrimitiveType|PrimitiveType[] value = check extractParamValue(key, parameterValue);
        query += string `${queryParameterSerialization(key, value)}&`;
    }
    pathWithParams = pathWithParams + query.substring(0, query.length() - 1);
    return pathWithParams;
}

isolated function extractPathParams(string path, ParameterSchema? pathParameters = ()) returns ParameterSchema? {
    regex:Match[] pathParams = regex:searchAll(path, "\\{(\\w*?)\\}");
    if pathParams.length() == 0 {
        if pathParameters is () {
            return ();
        }
        return {
            required: pathParameters.properties.keys(),
            properties: pathParameters.properties
        };
    }

    map<ParameterType> extractedParameters = map from regex:Match param in pathParams
        select [param.matched.substring(1, param.matched.length() - 1), {'type: STRING}]; // mandotory parameters by default

    if pathParameters !is () {
        foreach [string, ParameterType] param in pathParameters.properties.entries() {
            extractedParameters[param[0]] = param[1];
        }
    }
    return {
        required: extractedParameters.keys(),
        properties: extractedParameters
    };
}
