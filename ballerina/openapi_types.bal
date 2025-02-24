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

public enum ParameterLocation {
    QUERY = "query", HEADER = "header", PATH = "path", COOKIE = "cookie"
}

public enum EncodingStyle {
    FORM = "form",
    SIMPLE = "simple",
    MATRIX = "matrix",
    LABEL = "label",
    SPACEDELIMITED = "spaceDelimited",
    PIPEDELIMITED = "pipeDelimited",
    DEEPOBJECT = "deepObject"
}

public enum HeaderStyle {
    SIMPLE = "simple"
}

type ComponentType Schema|Response|Parameter|RequestBody|Header|PathItem;

# Map of component objects.
public type Components record {
    # A map of reusable schemas for different data types
    map<Schema|Reference> schemas?;
    # A map of reusable response objects 
    map<Response|Reference> responses?;
    # A map of reusable parameter objects
    map<Parameter|Reference> parameters?;
    # A map of reusable request body objects
    map<RequestBody|Reference> requestBodies?;
    # A map of reusable header objects
    map<Header|Reference> headers?;
    # A map of PathItem objects
    map<PathItem|Reference> pathItems?;
};

# Server information object.
public type Server record {
    # A URL to the target host
    string url;
    # An optional string describing the host designated by the URL
    string description?;
};

# Map of pathItem objects.
public type Paths record {|
    PathItem|Reference...;
|};

# Describes a single path item.
public type PathItem record {
    # Description of the path item
    string description?;
    # Summary of the path item
    string summary?;
    # GET operation
    Operation get?;
    # POST operation
    Operation post?;
    # PUT operation
    Operation put?;
    # DELETE operation
    Operation delete?;
    # OPTIONS operation
    Operation options?;
    # HEAD operation
    Operation head?;
    # PATCH operation
    Operation patch?;
    # TRACE operation
    Operation trace?;
    # Server information for the path
    Server[] servers?;
    # A list of parameters that are applicable for all the operations described under this path item
    (Parameter|Reference)[] parameters?;
    # Not allowed $ref
    never \$ref?;
};

# Describes HTTP headers.
public type Header record {
    # Whether this header parameter is mandatory
    boolean required?;
    # A brief description of the header parameter
    string description?;
    # Whether empty value is allowed
    string allowEmptyValue?;
    # Describes how a specific property value will be serialized depending on its type
    HeaderStyle style?;
    # When this is true, property values of type array or object generate separate parameters for each value of the array, or key-value-pair of the map
    boolean explode?;
    # Schema of the header parameter
    Schema schema?;
    # Content of the header parameter
    map<MediaType> content?;
    # Not allowed $ref
    never \$ref?;
};

# Describes a encoding definition applied to a schema property.
public type Encoding record {
    # Describes how a specific property value will be serialized depending on its type
    string style?;
    # When this is true, property values of type array or object generate separate parameters for each value of the array, or key-value-pair of the map
    boolean explode?;
    # The Content-Type for encoding a specific property
    string contentType?;
    # A map allowing additional information to be provided as headers
    map<Header|Reference> headers?;
};

# Defines media type of a parameter, response body or header.
public type MediaType record {
    # Schema of the content
    Schema schema = {};
    # Encoding of the content
    map<Encoding> encoding?;
};

# Base schema object.
public type BaseSchema record {
    # Description of the schema
    string description?;
    # Default value of the schema
    json default?;
    # Whether the value is nullable
    boolean nullable?;
    # Xml schema
    XmlSchema 'xml?;
    # Not allowed $ref property
    never \$ref?;
};

# Base type schema object.
public type BaseTypeSchema record {
    *BaseSchema;
    # Type of the schema
    string 'type;
    # Not allowed anyOf
    never anyOf?;
    # Not allowed oneOf
    never oneOf?;
    # Not allowed allOf
    never allOf?;
    # Not allowed not
    never not?;

};

# Base primitive type schema object.
public type BasePrimitiveTypeSchema record {
    *BaseTypeSchema;
    # Can not have properties in a primitive type schema
    never properties?;
    # Can not have items in a primitive type schema
    never items?;
};

# Integer schema object.
public type IntegerSchema record {
    *BasePrimitiveTypeSchema;
    # Type of the integer schema
    INTEGER 'type;
    # Format of the value
    string format?;
    # Minimum value of the integer value
    int minimum?;
    # Maximum value of the integer value
    int maximum?;
    # Whether the minimum value is exclusive
    boolean exclusiveMinimum?;
    # Whether the maximum value is exclusive
    boolean exclusiveMaximum?;
    # Multiplier of the integer value
    int multipleOf?;
};

# Number schema object.
public type NumberSchema record {
    *BasePrimitiveTypeSchema;
    # Type of the number schema
    NUMBER|FLOAT 'type;
    # Format of the value
    string format?;
    # Minimum value of the number value
    int|float minimum?;
    # Maximum value of the number value
    int|float maximum?;
    # Whether the minimum value is exclusive
    boolean exclusiveMinimum?;
    # Whether the maximum value is exclusive
    boolean exclusiveMaximum?;
    # Multiplier of the number value
    int|float multipleOf?;
};

# String schema object.
public type StringSchema record {|
    *BasePrimitiveTypeSchema;
    # Type of the string schema
    STRING 'type = STRING;
    # Format of the string
    string format?;
    # Minimum length of the string value
    int minLength?;
    # Maximum length of the string value
    int maxLength?;
    # Regular expression pattern of the string value
    string pattern?;
    # Enum values of the string value
    (PrimitiveType?)[] 'enum?;
|};

# Boolean schema object.
public type BooleanSchema record {
    *BasePrimitiveTypeSchema;
    # Type of the boolean schema
    BOOLEAN 'type;
};

# Primitive type schema object.
public type PrimitiveTypeSchema IntegerSchema|NumberSchema|StringSchema|BooleanSchema;

# Array schema object.
public type ArraySchema record {
    *BaseTypeSchema;
    # Type of the array schema
    ARRAY 'type = ARRAY;
    # Whether the array items are unique
    boolean uniqueItems?;
    # Schema of the array items 
    Schema items;
    # Minimum number of items in the array
    int minItems?;
    # Maximum number of items in the array
    int maxItems?;
    # Not allowed properties
    never properties?;
};

# Discriminator object.
public type Discriminator record {
    # Name of the property that specifies the type
    string propertyName;
    # Mapping of the property values to schema names
    map<string> mapping?;
};

# One of schema object.
public type OneOfSchema record {
    *BaseSchema;
    # List of schemas that should match
    Schema[] oneOf;
    # Discriminator
    Discriminator discriminator?;
};

# All of schema object.
public type AllOfSchema record {
    *BaseSchema;
    # List of schemas that should match
    Schema[] allOf;
};

# Any of schema object.
public type AnyOfSchema record {
    *BaseSchema;
    # List of schemas that should match
    Schema[] anyOf;
    # Discriminator
    Discriminator discriminator?;
};

# Not schema object.
public type NotSchema record {
    *BaseSchema;
    # Schema that should not match
    Schema not;
};

# Defines an bbject schema with type is specified and properties are optional.
public type ObjectSchemaType1 record {
    *BaseTypeSchema;
    # Type of the object schema
    OBJECT 'type;
    # Minimum number of properties in the object
    int minProperties?;
    # Maximum number of properties in the object
    int maxProperties?;
    # List of required properties
    boolean|string[] required?;
    # List of properties
    map<Schema> properties?; // properties are optional for open-ended objects
    # Additional properties
    boolean|Schema additionalProperties?;
    # Discriminator
    Discriminator discriminator?;
    # Not allowed items. Distinction between array and object
    never items?;
};

# Defines an object schema with the properties defined and type is unspecified.
public type ObjectSchemaType2 record {
    *ObjectSchemaType1;
    # To match when type is not specified, but properties are specified
    never 'type?;
    # List of properties
    map<Schema> properties;
};

# Defines an object schema.
public type ObjectSchema ObjectSchemaType1|ObjectSchemaType2;

public type XmlSchema record {|
    # Replaces the name of the element/attribute used for the described schema property.
    string name?;
    # The URI of the namespace definition.
    string namespace?;
    # The prefix to be used for the name.
    string prefix?;
    # Declares whether the property definition translates to an attribute instead of an element.
    boolean attribute?;
    # May be used only for an array definition.
    boolean wrapped?;
|};

# Defines a reference object.
public type Reference record {
    # Reference to a component
    string \$ref;
    # Short description of the target component
    string summary?;
    # Xml schema
    XmlSchema 'xml?;
    # Detailed description of the target component
    string description?;
};

# Defines a OpenAPI schema.
public type Schema PrimitiveTypeSchema|ArraySchema|ObjectSchema|OneOfSchema|AllOfSchema|AnyOfSchema|NotSchema|Reference;

# Describes a single request body.
public type RequestBody record {
    # A brief description of the request body. This could contain examples of use.
    string description?;
    # The content of the request body. 
    map<MediaType> content;
    # Whether the request body is mandatory in the request.
    boolean required?;
};

# Describes a single API operation on a path.
public type Operation record {
    # A list of tags for API documentation control
    string[] tags?;
    # A short summary of what the operation does
    string summary?;
    # A description explanation of the operation behavior
    string description?;
    # Operation ID for referencing the operation
    string operationId?;
    # A list of parameters that are applicable for this operation
    (Parameter|Reference)[] parameters?;
    # The request body applicable for this operation
    RequestBody|Reference requestBody?;
    # The list of possible responses as they are returned from executing this operation
    map<Response|Reference> responses?;
};

# Describes the responses from an API Operation.
public type Responses record {|
    # Default response for the API Operation
    Response|Reference default?;
    Response|Reference...;
|};

# Describes a single response from an API Operation.
public type Response record {
    # A short description of the response
    string description?;
    # A map containing schema of the response headers
    map<Header|Reference> headers?;
    # A map containing the structure of the response body
    map<MediaType> content?;
    # Not allowed $ref
    never \$ref?;
};

# Describes a single operation parameter.
public type Parameter record {
    # Name of the parameter
    string name;
    # The location of the parameter
    ParameterLocation 'in;
    # Whether the parameter is mandatory
    boolean required?;
    # A brief description of the parameter
    string description?;
    # Whether empty value is allowed
    boolean allowEmptyValue?;
    # Describes how a specific property value will be serialized depending on its type
    EncodingStyle style?;
    # When this is true, property values of type array or object generate separate parameters for each value of the array, or key-value-pair of the map
    boolean explode?;
    # Schema of the parameter
    Schema schema?;
    # Content of the parameter
    map<MediaType> content?;
    # Null value is allowed
    boolean nullable?;
};

# OpenAPI Specification 3.1.0
public type OpenApiSpec record {
    # OpenAPI version
    string openapi;
    # Server information
    Server[] servers?;
    # Server resource definitions
    Paths paths?;
    # Reference objects
    Components components?;
};
