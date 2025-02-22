// Copyright (c) 2023 WSO2 LLC (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
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

# Primitive types supported by the Tool schemas.
public type PrimitiveType int|string|boolean|float|decimal;

# Defines a constant value field in the schema.
public type ConstantValueSchema record {|
    # The constant value.
    json 'const;
|};

# Defines a internal value field in the schema
public type InternalValueSchema record {|
    *ConstantValueSchema;
|};

# Defines a base input type schema.
public type BaseInputTypeSchema record {|
    # Input data type
    InputType 'type;
    # Description of the input
    string description?;
    # Default value of the input
    json default?;
    # Indicates whether the value can be null.
    boolean nullable?;
|};

# Defines a primitive input field in the schema.
public type PrimitiveInputSchema record {|
    *BaseInputTypeSchema;
    # Input data type. Should be one of `STRING`, `INTEGER`, `NUMBER`, or `BOOLEAN`.
    STRING|INTEGER|NUMBER|BOOLEAN 'type;
    # Format of the input. This is not applicable for `BOOLEAN` type.
    string format?;
    # Pattern of the input. This is only applicable for `STRING` type.
    string pattern?;
    # Enum values of the input. This is only applicable for `STRING` type.
    (PrimitiveType?)[] 'enum?;
    # Default value of the input
    PrimitiveType default?;
|};

# Defines an `anyOf` input field in the schema. Follows OpenAPI 3.x specification.
public type AnyOfInputSchema record {|
    # List of possible input types
    JsonSubSchema[] anyOf;
|};

# Defines an `allOf` input field in the schema. Follows OpenAPI 3.x specification.
public type AllOfInputSchema record {|
    # List of possible input types
    JsonSubSchema[] allOf;
|};

# Defines an `oneOf` input field in the schema. Follows OpenAPI 3.x specification.
public type OneOfInputSchema record {|
    # List of possible input types
    JsonSubSchema[] oneOf;
    # Indicates whether the value can be null.
    boolean nullable?;
|};

# Defines a `not` input field in the schema. Follows OpenAPI 3.x specification.
public type NotInputSchema record {|
    # Schema that is not accepted as an input
    JsonSubSchema not;
|};

# Defines an array input field in the schema.
public type ArrayInputSchema record {|
    *BaseInputTypeSchema;
    # Input data type. Should be `ARRAY`.
    ARRAY 'type = ARRAY;
    # Schema of the array items
    JsonSubSchema items;
    # Default value for the array
    json[] default?;
|};

# Defines an object input field in the schema.
public type ObjectInputSchema record {|
    *BaseInputTypeSchema;
    # Input data type. Should be `OBJECT`.
    OBJECT 'type = OBJECT;
    # List of required properties
    string[] required?;
    # Schema of the object properties
    map<JsonSubSchema> properties?;
|};

# Defines a json input schema
public type JsonInputSchema ObjectInputSchema|ArrayInputSchema|AnyOfInputSchema|OneOfInputSchema|AllOfInputSchema|NotInputSchema;

# Defines a json sub schema
public type JsonSubSchema JsonInputSchema|PrimitiveInputSchema|ConstantValueSchema;

// tool definitions ----------------------------
# Defines a tool. This is the only tool type directly understood by the agent. All other tool types are converted to this type using toolkits.
public type ToolConfig record {|
    # Name of the tool
    string name;
    # A description of the tool. This is used by the LLMs to understand the behavior of the tool.
    string description;
    # Input schema expected by the tool. If the tool doesn't expect any input, this should be null.
    JsonInputSchema? parameters = ();
    # Pointer to the function that should be called when the tool is invoked.
    FunctionTool caller;
|};

# Defines the configuration of the Tool annotation.
public type ToolAnnotationConfig record {|
    # The name of the tool. If not provided, defaults to the function pointer name.
    string name?;
    # A description of the tool. This is used by LLMs to understand the tool's behavior.  
    # If not provided, the doc comment used as the description.
    string description?;
    # The input schema expected by the tool. If the tool does not expect any input, this should be null.  
    # If not provided, the input schema is generated automatically. 
    ObjectInputSchema? parameters?;
|};

# Represents the annotation of a function tool.
public annotation ToolAnnotationConfig Tool on function;

# Represents a type alias for an isolated function, representing a function tool.
public type FunctionTool isolated function;
