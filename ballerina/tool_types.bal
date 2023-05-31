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
    map<json> pathParams?;
    map<json> requestBody?;
|};

// input schema definitions ----------------------------
public type SimpleInputSchema record {|
    never 'type?; // avoid ambiguity with ArrayInputSchema and ObjectInputSchema
    string|SimpleInputSchema|SimpleInputSchema[]...;
|};

public type ConstantValueSchema record {|
    json 'const;
|};

public type BaseInputTypeSchema record {|
    InputType 'type;
    string description?;
    json default?;
|};

public type PrimitiveInputSchema record {|
    *BaseInputTypeSchema;
    STRING|INTEGER|NUMBER|FLOAT|BOOLEAN 'type;
    string format?;
    string pattern?;
    string[] 'enum?;
|};

public type AnyOfInputSchema record {|
    ObjectInputSchema[] anyOf;
|};

public type AllOfInputSchema record {|
    ObjectInputSchema[] allOf;
|};

public type OneOfInputSchema record {|
    JsonSubSchema[] oneOf;
|};

public type NotInputSchema record {|
    JsonSubSchema not;
|};

public type ArrayInputSchema record {|
    *BaseInputTypeSchema;
    ARRAY 'type = ARRAY;
    JsonSubSchema items;
    json[] default?;
|};

public type ObjectInputSchema record {|
    *BaseInputTypeSchema;
    OBJECT 'type = OBJECT;
    string[] required?;
    map<JsonSubSchema> properties;
|};

public type JsonInputSchema ObjectInputSchema|ArrayInputSchema|AnyOfInputSchema|OneOfInputSchema|AllOfInputSchema|NotInputSchema;

public type JsonSubSchema JsonInputSchema|PrimitiveInputSchema|ConstantValueSchema;

// tool definitions ----------------------------
public type Tool record {|
    string name;
    string description;
    JsonInputSchema? inputSchema = ();
    isolated function caller;
|};

public type HttpTool record {|
    string name;
    string description;
    HttpMethod method;
    string path;
    JsonInputSchema queryParams?;
    JsonInputSchema pathParams?;
    JsonInputSchema requestBody?;
|};

