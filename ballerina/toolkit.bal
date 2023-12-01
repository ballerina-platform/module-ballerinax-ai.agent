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

public type ParameterSchema record {|
    # A brief description of the parameter
    string description?;
    # Whether empty value is allowed
    boolean allowEmptyValue?;
    # Describes how a specific property value will be serialized depending on its type.
    EncodingStyle style?;
    # When this is true, property values of type array or object generate separate parameters for each value of the array, or key-value-pair of the map.
    boolean explode?;
    # Null value is allowed
    boolean nullable?;
    # Content type of the schema
    string mediaType?;
    # Parameter schema
    JsonSubSchema schema;
|};

# Defines a HTTP parameter schema (can be query parameter or path parameters).
public type Parameters record {|
    # A list of mandatory parameters
    string[] required?;
    # A map of parameter names and their types
    map<ParameterSchema> schemas;
|};

# Defines an HTTP tool. This is a special type of tool that can be used to invoke HTTP resources.
public type HttpTool record {|
    # Name of the Http resource tool
    string name;
    # Description of the Http resource tool used by the LLM
    string description;
    # Http method type (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS)
    HttpMethod method;
    # Path of the Http resource
    string path;
    # Query parameters definitions of the Http resource
    Parameters queryParameters?;
    # Path parameter definitions of the Http resource
    Parameters pathParameters?;
    # Request body definition of the Http resource
    RequestBodySchema requestBody?;
|};

public type RequestBodySchema record {|
    # A brief description of the request body
    string description?;
    # Content type of the request body
    string mediaType?;
    # Request body schema
    JsonSubSchema schema;
|};

type HttpToolJsonSchema record {|
    *ObjectInputSchema;
    record {|
        ConstantValueSchema tool;
        JsonSubSchema queryParameters?;
        JsonSubSchema pathParameters?;
        JsonSubSchema requestBody?;
    |} properties;
|};

// input record definitions ----------------------------
# Defines an HTTP input record.
type HttpInput record {|
    # Http tool record
    HttpTool tool;
    # Query parameters of the Http resource
    map<json> queryParameters?;
    # Path parameters of the Http resource
    map<json> pathParameters?;
    # Request body of the Http resource
    map<json> requestBody?;
|};

# Defines an HTTP output record for requests.
public type HttpOutput record {|
    # HTTP status code of the response
    int code;
    # HTTP path url with encoded paramteres
    string path;
    # Response headers 
    record {|
        # Content type of the response
        string contentType?;
        # Content length of the response
        int contentLength?;
    |} headers;
    # Response payload
    json|xml body?;
|};

# Allows implmenting custom toolkits by extending this type. Toolkits can help to define new types of tools so that agent can understand them.
public type BaseToolKit distinct object {
    # Useful to retrieve the Tools extracted from the Toolkit.
    # + return - An array of Tools
    public isolated function getTools() returns Tool[];
};

# Defines a HTTP tool kit. This is a special type of tool kit that can be used to invoke HTTP resources.
# Require to initialize the toolkit with the service url and http tools that are belongs to a single API. 
public isolated class HttpServiceToolKit {
    *BaseToolKit;
    private final Tool[] & readonly tools;
    private final map<string|string[]> & readonly headers;
    private final http:Client httpClient;
    private final map<HttpTool> httpTools = {};

    # Initializes the toolkit with the given service url and http tools.
    #
    # + serviceUrl - The url of the service to be called
    # + httpTools - The http tools to be initialized
    # + clientConfig - The http client configuration associated to the tools
    # + headers - The http headers to be used in the requests
    # + returns - error if the initialization fails
    public isolated function init(string serviceUrl, HttpTool[] httpTools, http:ClientConfiguration clientConfig = {}, map<string|string[]> headers = {}) returns error? {
        self.headers = headers.cloneReadOnly();
        self.httpClient = check new (serviceUrl, clientConfig);

        Tool[] tools = [];
        foreach HttpTool httpTool in httpTools {
            self.httpTools[httpTool.name] = httpTool;

            Parameters? queryParameters = httpTool?.queryParameters;
            Parameters? pathParameters = extractPathParams(httpTool.path, httpTool?.pathParameters);
            RequestBodySchema? requestBody = httpTool?.requestBody;

            HttpToolJsonSchema parameters = {
                properties: {
                    tool: {'const: httpTool},
                    queryParameters: queryParameters is () ? () : {
                            required: queryParameters.required,
                            properties: map from [string, ParameterSchema] [name, 'parameter] in queryParameters.schemas.entries()
                                select [name, 'parameter.schema]
                        },
                    pathParameters: pathParameters is () ? () : {
                            required: pathParameters.required,
                            properties: map from [string, ParameterSchema] [name, 'parameter] in pathParameters.schemas.entries()
                                select [name, 'parameter.schema]
                        },
                    requestBody: requestBody is () ? () : requestBody.schema
                }
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

    # Useful to retrieve the Tools extracted from the HttpTools.
    # + return - An array of Tools corresponding to the HttpTools
    public isolated function getTools() returns Tool[] => self.tools;

    private isolated function get(HttpInput httpInput) returns HttpOutput|error {
        string path = check getParamEncodedPath(httpInput.tool, httpInput?.pathParameters, httpInput?.queryParameters);
        log:printDebug(string `HTTP GET ${path} ${httpInput?.requestBody.toString()}`);
        http:Response getResult = check self.httpClient->get(path, headers = self.headers);
        return extractResponsePayload(path, getResult);
    }

    private isolated function post(HttpInput httpInput) returns HttpOutput|error {
        string path = check getParamEncodedPath(httpInput.tool, httpInput?.pathParameters, httpInput?.queryParameters);
        log:printDebug(string `HTTP POST ${path} ${httpInput?.requestBody.toString()}`);
        http:Response postResult = check self.httpClient->post(path, message = httpInput?.requestBody, headers = self.headers);
        return extractResponsePayload(path, postResult);
    }

    private isolated function delete(HttpInput httpInput) returns HttpOutput|error {
        string path = check getParamEncodedPath(httpInput.tool, httpInput?.pathParameters, httpInput?.queryParameters);
        log:printDebug(string `HTTP DELETE ${path} ${httpInput?.requestBody.toString()}`);
        http:Response deleteResult = check self.httpClient->delete(path, message = httpInput?.requestBody, headers = self.headers);
        return extractResponsePayload(path, deleteResult);
    }

    private isolated function put(HttpInput httpInput) returns HttpOutput|error {
        string path = check getParamEncodedPath(httpInput.tool, httpInput?.pathParameters, httpInput?.queryParameters);
        log:printDebug(string `HTTP PUT ${path} ${httpInput?.requestBody.toString()}`);
        http:Response putResult = check self.httpClient->put(path, message = httpInput?.requestBody, headers = self.headers);
        return extractResponsePayload(path, putResult);
    }

    private isolated function patch(HttpInput httpInput) returns HttpOutput|error {
        string path = check getParamEncodedPath(httpInput.tool, httpInput?.pathParameters, httpInput?.queryParameters);
        log:printDebug(string `HTTP PATH ${path} ${httpInput?.requestBody.toString()}`);
        http:Response patchResult = check self.httpClient->patch(path, message = httpInput?.requestBody, headers = self.headers);
        return extractResponsePayload(path, patchResult);
    }

    private isolated function head(HttpInput httpInput) returns HttpOutput|error {
        string path = check getParamEncodedPath(httpInput.tool, httpInput?.pathParameters, httpInput?.queryParameters);
        log:printDebug(string `HTTP HEAD ${path} ${httpInput?.requestBody.toString()}`);
        http:Response headResult = check self.httpClient->head(path, headers = self.headers);
        return extractResponsePayload(path, headResult);
    }

    private isolated function options(HttpInput httpInput) returns HttpOutput|error {
        string path = check getParamEncodedPath(httpInput.tool, httpInput?.pathParameters, httpInput?.queryParameters);
        log:printDebug(string `HTTP OPTIONS ${path} ${httpInput?.requestBody.toString()}`);
        http:Response optionsResult = check self.httpClient->options(path, headers = self.headers);
        return extractResponsePayload(path, optionsResult);
    }
}

isolated function extractPathParams(string path, Parameters? parameters = ()) returns Parameters? {
    regex:Match[] pathParams = regex:searchAll(path, "\\{(\\w*?)\\}");
    if pathParams.length() == 0 {
        return parameters;
    }
    map<ParameterSchema> extractedParams = map from regex:Match 'parameter in pathParams
        let var name = 'parameter.matched
        select [name.substring(1, name.length() - 1), {schema: {'type: STRING}}]; // mandotory parameters by default

    if parameters !is () {
        foreach [string, ParameterSchema] [name, 'parameter] in parameters.schemas.entries() {
            extractedParams[name] = 'parameter;
        }
    }
    return {
        required: extractedParams.keys(),
        schemas: extractedParams
    };
}
