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

enum ParameterLocation {
    QUERY = "query", HEADER = "header", PATH = "path", COOKIE = "cookie"
}

enum ParameterStyle {
    FORM = "form",
    SIMPLE = "simple",
    MATRIX = "matrix",
    LABEL = "label",
    SPACE_DELIMITED = "spaceDelimited",
    PIPE_DELIMITED = "pipeDelimited",
    DEEP_OBJECT = "deepObject"
}

enum HeaderStyle {
    SIMPLE = "simple"
}

enum SecuritySchemeType {
    APIKEY = "apiKey", HTTP = "http", MUTUAL_TLS = "mutualTLS", OUATH2 = "oauth2", OPEN_ID_CONNECT = "openIdConnect"
}

enum SecuritySchemeLocation {
    QUERY = "query", HEADER = "header", COOKIE = "cookie"
}

type Info record {
    string title;
    string 'version;
};

type SecurityRequirement record {|
    string[]...;
|};

type SecurityScheme record {|
    SecuritySchemeType 'type;
    string description?;
    string name;
    SecuritySchemeLocation 'in;
    string scheme;
    string bearerFormat?;
    OAuthFlows flows;
    string openIdConnectUrl;
|};

type OAuthFlows record {|
    OAuthFlow implicit?;
    OAuthFlow password?;
    OAuthFlow clientCredentials?;
    OAuthFlow authorizationCode?;
|};

type OAuthFlow record {|
    string authorizationUrl?;
    string tokenUrl;
    string refreshUrl?;
    map<string> scopes;
|};

type ComponentType Schema|Response|Parameter|Example|RequestBody|Header|SecurityScheme|Link|Callback|PathItem;

type Components record {|
    map<Schema|Reference> schemas?;
    map<Response|Reference> responses?;
    map<Parameter|Reference> parameters?;
    map<Example|Reference> examples?;
    map<RequestBody|Reference> requestBodies?;
    map<Header|Reference> headers?;
    map<SecurityScheme|Reference> securitySchemes?;
    map<Link|Reference> links?;
    map<Callback|Reference> callbacks?;
    Paths pathItems?;
|};

type ServerVariable record {|
    string default;
    string[] 'enum?;
    string description?;
|};

type Server record {|
    string url;
    string description?;
    map<ServerVariable> variables?;
|};

type Paths record {|
    PathItem|Reference...;
|};

type PathItem record {|
    string \$ref?;
    string description?;
    string summary?;
    Operation get?;
    Operation post?;
    Operation put?;
    Operation delete?;
    Operation options?;
    Operation head?;
    Operation patch?;
    Operation trace?;
    Server[] servers?;
    Parameter[]|Reference[] parameters?;
|};

type Example record {|
    string summary?;
    string description?;
    any value?;
    string externalValue?;
|};

type Header record {|
    string required;
    string description?;
    string deprecated?;
    string allowEmptyValue?;
    HeaderStyle style?;
    boolean explode?;
    boolean allowReserved?;
    Schema schema?;
    any example?;
    map<Example|Reference> examples?;
    map<MediaType> content?;

|};

type Encoding record {|
    string contentType?;
    map<Header|Reference> headers?;
    string style?;
    boolean explode?;
    boolean allowReserved?;
|};

type MediaType record {|
    Schema schema;
    any example?;
    map<Example|Reference> examples?;
    map<Encoding> encoding?;

|};

type BaseSchema record {|
    string title?;
    string description?;
    anydata default?;
    boolean nullable?;
    boolean readOnly?;
    boolean writeOnly?;
    any example?;
    map<Example|Reference> examples?;
|};

type BaseTypeSchema record {|
    *BaseSchema;
    string 'type;
    string format?;
|};

type IntegerSchema record {|
    *BaseTypeSchema;
    INTEGER 'type = INTEGER;
    int minimum?;
    int maximum?;
    boolean exclusiveMinimum?;
    boolean exclusiveMaximum?;
    int multipleOf?;
|};

type NumberSchema record {|
    *BaseTypeSchema;
    NUMBER|FLOAT 'type = NUMBER;
    int|float minimum?;
    int|float maximum?;
    boolean exclusiveMinimum?;
    boolean exclusiveMaximum?;
    int|float multipleOf?;
|};

type StringSchema record {|
    *BaseTypeSchema;
    STRING 'type = STRING;
    int minLength?;
    int maxLength?;
    string pattern?;
    string format?;
    string[] 'enum?;
|};

type BooleanSchema record {|
    BOOLEAN 'type = BOOLEAN;
    *BaseTypeSchema;
|};

type PrimitiveTypeSchema IntegerSchema|NumberSchema|StringSchema|BooleanSchema;

type ArraySchema record {|
    *BaseSchema;
    ARRAY 'type = ARRAY;
    boolean uniqueItems?;
    Schema items;
    int minItems?;
    int maxItems?;
    // boolean contains?;
|};

type Discriminator record {|
    string propertyName;
    map<string> mapping?;
|};

type OneOfSchema record {|
    *BaseSchema;
    Schema[] oneOf;
    Discriminator discriminator?;
    map<Schema> mapping?;
|};

type AllOfSchema record {|
    *BaseSchema;
    Schema[] allOf;
|};

type AnyOfSchema record {|
    *BaseSchema;
    Schema[] anyOf;
    Discriminator discriminator?;
|};

type NotSchema record {|
    *BaseSchema;
    Schema not;
|};

type ObjectSchema record {|
    *BaseSchema;
    OBJECT 'type?;
    int minProperties?;
    int maxProperties?;
    boolean|string[] required?;
    map<Schema> properties?; // properties are optional for open-ended objects
    boolean|Schema additionalProperties?;
    Discriminator discriminator?;
    boolean deprecated?;
    boolean externalDocs?;
|};

type Reference record {|
    string \$ref;
    string summary?;
    string description?;
|};

type Schema PrimitiveTypeSchema|ArraySchema|ObjectSchema|OneOfSchema|AllOfSchema|AnyOfSchema|NotSchema|Reference;

type RequestBody record {|
    string description?;
    map<MediaType> content;
    boolean required?;
|};

type Operation record {|
    string[] tags?;
    string summary?;
    string description?;
    ExternalDocumentation externalDocs?;
    string operationId?;
    (Parameter|Reference)[] parameters?;
    RequestBody|Reference requestBody?;
    map<Response|Reference> responses?;
    map<Callback|Reference> callbacks?;
    boolean deprecated?;
    SecurityRequirement[] security?;
    Server[] servers?;

|};

type Callback record {|
    Paths pathItems;
|};

type Responses record {|
    Response|Reference default?;
    Response|Reference...;
|};

type Response record {|
    string description;
    map<Header|Reference> headers?;
    map<MediaType> content?;
    map<Link|Reference> links?;
|};

type Link record {|
    string operationRef?;
    string operationId?;
    map<any> parameters?;
    any requestBody?;
    string description?;
    Server server?;
|};

type ExternalDocumentation record {|
    string description?;
    string url;
|};

type Parameter record {|
    string name;
    ParameterLocation 'in;
    boolean required;
    string description?;
    boolean deprecated?;
    boolean allowEmptyValue?;
    ParameterStyle style?;
    boolean explode?;
    boolean allowReserved?;
    Schema schema?;
    any example?;
    map<Example|Reference> examples?;
    map<MediaType> content?;
|};

type Tag record {|
    string name;
    string description?;
    ExternalDocumentation externalDocs?;
|};

type OpenAPISpec record {|
    string openapi;
    Info info;
    string jsonSchemaDialect?;
    Server[] servers?;
    Paths paths?;
    map<PathItem|Reference> webhooks?;
    Components components?;
    SecurityRequirement[] security?;
    Tag[] tags?;
    ExternalDocumentation externalDocs?;
|};
