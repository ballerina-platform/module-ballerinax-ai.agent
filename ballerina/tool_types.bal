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

public enum InputType {
    STRING = "string",
    INTEGER = "integer",
    FLOAT = "float",
    BOOLEAN = "boolean",
    NUMBER = "number",
    OBJECT = "object",
    ARRAY = "array"
}

public enum HttpMethod {
    GET, POST, DELETE, PUT, PATCH, HEAD, OPTIONS
}

// input record definitions ----------------------------
type HttpInput record {|
    string path;
    map<json> queryParams?;
    map<json> requestBody?;
|};

// input schema definitions ----------------------------
public type SimpleInputSchema record {|
    never 'type?; // avoid ambiguity with ArrayInputSchema and ObjectInputSchema
    string|SimpleInputSchema|SimpleInputSchema[]...;
|};

public type PrimitiveInputSchema record {|
    InputType 'type;
    string format?;
    string pattern?;
    string description?;
    anydata default?;
    string[] 'enum?;
|};

public type AnyOfInputSchema record {|
    JsonSubSchema[] anyOf;
|};

public type AllOfInputSchema record {|
    JsonSubSchema[] allOf;
|};

public type OneOfInputSchema record {|
    JsonSubSchema[] oneOf;
|};

public type NotInputSchema record {|
    JsonSubSchema not;
|};

public type ArrayInputSchema record {|
    ARRAY 'type = ARRAY;
    JsonSubSchema items;
|};

public type ObjectInputSchema record {|
    OBJECT 'type = OBJECT;
    string[] required?;
    map<JsonSubSchema> properties;
|};

public type JsonInputSchema ObjectInputSchema|ArrayInputSchema|AnyOfInputSchema|OneOfInputSchema|AllOfInputSchema|NotInputSchema;

public type JsonSubSchema JsonInputSchema|PrimitiveInputSchema;

public type InputSchema SimpleInputSchema|JsonInputSchema;

// tool definitions ----------------------------
public type Tool record {|
    string name;
    string description;
    InputSchema? inputSchema = ();
    isolated function caller;
|};

public type HttpTool record {|
    string name;
    string description;
    HttpMethod method;
    string path;
    InputSchema? queryParams = ();
    InputSchema? requestBody = ();
|};

