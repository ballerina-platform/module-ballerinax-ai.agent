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

# Supported input types by the Tool schemas.
public enum InputType {
    STRING = "string",
    INTEGER = "integer",
    FLOAT = "float",
    BOOLEAN = "boolean",
    NUMBER = "number",
    OBJECT = "object",
    ARRAY = "array"
}

# Supported HTTP methods.
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

# Defines a constant value field in the schema.
#
# + const - The constant value.
public type ConstantValueSchema record {|

    json 'const;
|};

# Defines a base input type schema.
#
# + type - Input data type
# + description - Description of the input
# + default - Default value of the input
public type BaseInputTypeSchema record {|
    InputType 'type;
    string description?;
    json default?;
|};

# Defines a primitive input field in the schema.
#
# + type - Input data type. Should be one of STRING, INTEGER, NUMBER, FLOAT or BOOLEAN.
# + format - Format of the input. This is not applicable for BOOLEAN type.
# + pattern - Pattern of the input. This is only applicable for STRING type.
# + enum - Enum values of the input. This is only applicable for STRING type.
public type PrimitiveInputSchema record {|
    *BaseInputTypeSchema;
    STRING|INTEGER|NUMBER|FLOAT|BOOLEAN 'type;
    string format?;
    string pattern?;
    string[] 'enum?;
|};

# Defines an anyOf input field in the schema. Follows OpenAPI 3.x specification.
#
# + anyOf - List of possible input types
public type AnyOfInputSchema record {|
    ObjectInputSchema[] anyOf;
|};

# Defines an allOf input field in the schema. Follows OpenAPI 3.x specification.
#
# + allOf - List of possible input types
public type AllOfInputSchema record {|
    ObjectInputSchema[] allOf;
|};

# Defines an oneOf input field in the schema. Follows OpenAPI 3.x specification.
#
# + oneOf - List of possible input types
public type OneOfInputSchema record {|
    JsonSubSchema[] oneOf;
|};

# Defines a not input field in the schema. Follows OpenAPI 3.x specification.
#
# + not - Schema that is not accepted as an input
public type NotInputSchema record {|
    JsonSubSchema not;
|};

# Defines an array input field in the schema.
#
# + type - Input data type. Should be ARRAY.
# + items - Schema of the array items
# + default - Default value for the array
public type ArrayInputSchema record {|
    *BaseInputTypeSchema;
    ARRAY 'type = ARRAY;
    JsonSubSchema items;
    json[] default?;
|};

# Defines an object input field in the schema.
#
# + type - Input data type. Should be OBJECT.
# + required - List of required properties
# + properties - Schema of the object properties
public type ObjectInputSchema record {|
    *BaseInputTypeSchema;
    OBJECT 'type = OBJECT;
    string[] required?;
    map<JsonSubSchema> properties;
|};

# Defines a json input schema
public type JsonInputSchema ObjectInputSchema|ArrayInputSchema|AnyOfInputSchema|OneOfInputSchema|AllOfInputSchema|NotInputSchema;

# Defines a json sub schema
public type JsonSubSchema JsonInputSchema|PrimitiveInputSchema|ConstantValueSchema;

// tool definitions ----------------------------
# Defines a tool. This is the only tool type directly understood by the agent. All other tool types are converted to this type using toolkits.
#
# + name - Name of the tool
# + description - A description of the tool. This is used by the LLMs to understand the behavior of the tool.
# + inputSchema - Input schema expected by the tool. If the tool doesn't expect any input, this should be null.
# + caller - Pointer to the function that should be called when the tool is invoked.
public type Tool record {|
    string name;
    string description;
    JsonInputSchema? inputSchema = ();
    isolated function caller;
|};

# Defines an HTTP tool. This is a special type of tool that can be used to invoked  HTTP resources.
#
# + name - Name of the tool
# + description - A description of the tool. This is used by the LLMs to understand the behavior of the tool.
# + method - HTTP method of the resource. Should be one of GET, POST, DELETE, PUT, PATCH, HEAD or OPTIONS.
# + path - Path of the HTTP resource.
# + queryParams - Schema of the query parameters to the HTTP resource. Leave this empty if the resource doesn't expect any query parameters.
# + pathParams - Schema of the path parameters to the HTTP resource. Leave this empty if the resource doesn't expect any path parameters.
# + requestBody - Schema of the request body to the HTTP resource. Leave this empty if the resource doesn't expect any request body.
public type HttpTool record {|
    string name;
    string description;
    HttpMethod method;
    string path;
    JsonInputSchema queryParams?;
    JsonInputSchema pathParams?;
    JsonInputSchema requestBody?;
|};

