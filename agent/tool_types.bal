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

public enum PrimitiveInputType {
    STRING = "string",
    INTEGER = "integer",
    FLOAT = "float",
    BOOLEAN = "boolean",
    NUMBER = "number"
}

public enum ComplexInputType {
    OBJECT = "object",
    ARRAY = "array"
}

public enum HttpMethod {
    GET, POST, DELETE, PUT, PATCH, HEAD, OPTIONS
}

// input record definitions ----------------------------
type HttpInput record {|
    string path;
    json queryParams?;
    json requestBody?;
|};

// input schema definitions ----------------------------
public type SimpleInputSchema record {|
    PrimitiveInputType 'type?; // avoid ambiguity with ArrayInputSchema and ObjectInputSchema
    string|SimpleInputSchema|SimpleInputSchema[]...;
|};

public type PrimitiveInputSchema record {|
    PrimitiveInputType 'type;
    string format?;
    string pattern?;
|};

public type AnyOfInputSchema record {|
    SubSchema[] anyOf;
|};

public type AllOfInputSchema record {|
    SubSchema[] allOf;
|};

public type OneOfInputSchema record {|
    SubSchema[] oneOf;
|};

public type NotInputSchema record {|
    SubSchema not;
|};

public type ArrayInputSchema record {|
    ARRAY 'type = ARRAY;
    SubSchema items;
|};

public type ObjectInputSchema record {|
    OBJECT 'type = OBJECT;
    string[] required?;
    map<SubSchema> properties;
|};

public type JsonInputSchema ObjectInputSchema|ArrayInputSchema|AnyOfInputSchema|OneOfInputSchema|AllOfInputSchema|NotInputSchema;

public type SubSchema JsonInputSchema|PrimitiveInputSchema;

type HttpPathSchema record {|
    STRING 'type = STRING;
    string pattern;
|};

type HttpPropertiesSchema record {|
    HttpPathSchema path;
    JsonInputSchema queryParams?;
    JsonInputSchema requestBody?;
|};

public type InputSchema SimpleInputSchema|JsonInputSchema;

type HttpJsonInputSchema record {|
    *ObjectInputSchema;
    string[] required = ["path"];
    HttpPropertiesSchema properties;
|};

type HttpSimpleInputSchema record {|
    string path;
    SimpleInputSchema queryParams?;
    SimpleInputSchema requestBody?;
|};

// tool definitions ----------------------------
public type Tool record {|
    string name;
    string description;
    InputSchema? inputs = ();
    function caller;
|};

public type HttpTool record {|
    // *HttpInputSchema;
    string name;
    string description;
    HttpMethod method;
    string path;
    InputSchema? queryParams = ();
    InputSchema? requestBody = ();
|};

