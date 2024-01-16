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

import ballerina/io;
import ballerina/log;
import ballerina/yaml;
import ballerina/regex;

# Provides extracted tools and service URL from the OpenAPI specification.
public type HttpApiSpecification record {|
    # Extracted service URL from the OpenAPI specification if there is any
    string serviceUrl?;
    # Extracted Http tools from the OpenAPI specification
    HttpTool[] tools;
|};

# Defines additional information to be extracted from the OpenAPI specification.
public type AdditionInfoFlags record {|
    # Flag to extract description of parameters and schema attributes from the OpenAPI specification
    boolean extractDescription = false;
    # Flag to extract default values of parameters and schema attributes from the OpenAPI specification
    boolean extractDefault = false;
|};

# Extracts the Http tools from the given OpenAPI specification file.
#
# + filePath - Path to the OpenAPI specification file (should be JSON or YAML)
# + additionInfoFlags - Flags to extract additional information from the OpenAPI specification
# + return - A record with the list of extracted tools and the service URL (if available)
public isolated function extractToolsFromOpenApiSpecFile(string filePath, *AdditionInfoFlags additionInfoFlags) returns
HttpApiSpecification & readonly|error {
    map<json> openApiSpec;
    if filePath.endsWith(".yaml") || filePath.endsWith(".yml") {
        openApiSpec = check yaml:readFile(filePath).ensureType();
    }
    else if filePath.endsWith(".json") {
        openApiSpec = check io:fileReadJson(filePath).ensureType();
    }
    else {
        return error("Unsupported file type. Supported file types are .json, .yaml or .yml");
    }
    return extractToolsFromOpenApiJsonSpec(openApiSpec, additionInfoFlags);
}

# Extracts the Http tools from the given OpenAPI specification as a JSON 
#
# + openApiSpec - A valid OpenAPI specification in JSON format
# + additionInfoFlags - Flags to extract additional information from the OpenAPI specification
# + return - A record with the list of extracted tools and the service URL (if available)
public isolated function extractToolsFromOpenApiJsonSpec(map<json> openApiSpec, *AdditionInfoFlags additionInfoFlags) returns
HttpApiSpecification & readonly|error {
    OpenApiSpec spec = check parseOpenApiSpec(openApiSpec);
    OpenApiSpecVisitor visitor = new (additionInfoFlags);
    return check visitor.visit(spec).cloneReadOnly();
}

# Parses the given OpenAPI specification as a JSON to a OpenApiSpec object.
#
# + openApiSpec - A valid OpenAPI specification in JSON format
# + return - A OpenApiSpec object
public isolated function parseOpenApiSpec(map<json> openApiSpec) returns OpenApiSpec|UnsupportedOpenApiVersion|OpenApiParsingError {
    if !openApiSpec.hasKey("openapi") {
        return error UnsupportedOpenApiVersion("OpenAPI version is not specified in the specification.");
    }
    json version = openApiSpec.get("openapi");
    if version !is string || !version.matches(re `3\.0\..`) {
        return error UnsupportedOpenApiVersion("Unsupported OpenAPI version. Supports specifications with version 3.x.x only.");
    }
    OpenApiSpec|error parseSpec = openApiSpec.cloneWithType();
    if parseSpec is OpenApiSpec {
        return parseSpec;
    }
    return error OpenApiParsingError("Error while parsing the OpenAPI specification.", cause = parseSpec);
}

class OpenApiSpecVisitor {
    private map<ComponentType> referenceMap = {};
    private final HttpTool[] tools = [];
    private final AdditionInfoFlags additionalInfoFlags;

    isolated function init(AdditionInfoFlags additionalInfoFlags = {}) {
        self.additionalInfoFlags = additionalInfoFlags.cloneReadOnly();
    }

    isolated function visit(OpenApiSpec openApiSpec) returns HttpApiSpecification|error {
        string? serviceUrl = self.visitServers(openApiSpec.servers);
        self.referenceMap = self.visitComponents(openApiSpec.components);

        Paths? paths = openApiSpec.paths;
        error? parsingError = ();
        if paths !is () {
            parsingError = trap check self.visitPaths(paths);
        }
        if parsingError is () {
            return {
                serviceUrl,
                tools: self.tools.cloneReadOnly()
            };
        }
        if parsingError.message().includes("{ballerina}StackOverflow") {
            return error ParsingStackOverflowError("Parsing failed due to either a cyclic reference or the excessive length of the specification.", cause = parsingError);
        }
        return error OpenApiParsingError("Error while parsing the OpenAPI specification.", cause = parsingError);
    }

    private isolated function visitServers(Server[]? servers) returns string? {
        if servers is () || servers.length() < 1 {
            return ();
        }
        if servers.length() > 1 {
            log:printWarn("Multiple server urls are defined in the OpenAPI specification. If not specified, toolkit will use " + servers[0].url);
        }
        return servers[0].url;
    }

    private isolated function visitComponents(Components? components) returns map<ComponentType> {
        if components is () {
            return {};
        }
        map<ComponentType> referenceMap = {};
        foreach [string, anydata] [componentType, componentMap] in components.entries() {
            if componentMap !is map<ComponentType|Reference> {
                continue;
            }
            foreach [string, ComponentType|Reference] [componentName, component] in componentMap.entries() {
                string ref = string `#/${OPENAPI_COMPONENTS_KEY}/${componentType}/${componentName}`;
                referenceMap[ref] = component;
            }
        }
        return referenceMap;
    }

    private isolated function visitPaths(Paths paths) returns error? {
        foreach [string, PathItem|Reference] [pathUrl, pathItem] in paths.entries() {
            if pathItem is Reference {
                check self.visitPathItem(pathUrl, check self.visitReference(pathItem).ensureType());
            } else if pathItem is PathItem {
                check self.visitPathItem(pathUrl, pathItem);
            } else {
                return error("Unsupported path item type.", 'type = typeof pathItem);
            }
        }
    }

    private isolated function visitPathItem(string pathUrl, PathItem pathItem) returns error? {
        HttpMethod[] supportedMethods = [GET, POST, PUT, DELETE, OPTIONS, HEAD, PATCH];
        foreach HttpMethod httpMethod in supportedMethods {
            string method = httpMethod.toLowerAscii();
            if !pathItem.hasKey(method) {
                continue;
            }
            anydata operation = pathItem.get(method);
            if operation is Operation {
                check self.visitOperation(pathUrl, httpMethod, operation);
            }
        }
    }

    private isolated function visitOperation(string path, HttpMethod method, Operation operation) returns error? {
        string? description = operation.description ?: operation.summary;
        if description is () {
            return error IncompleteSpecificationError(string `A summary or description is mandatory for API paths. But it is missing for the resource "[${method}]:${path}"`);
        }
        string? name = operation.operationId;
        if name is () {
            return error(string `OperationId is mandotory for API paths. But, tt is missing for the resource "[${method}]:${path}"`);
        }

        // resolve parameters
        map<ParameterSchema>? parameters = check self.visitParameters(operation.parameters);

        RequestBodySchema? requestBody = ();
        RequestBody|Reference? requestBodySchema = operation.requestBody;
        if requestBodySchema is Reference {
            RequestBody resolvedRequestBody = check self.visitReference(requestBodySchema).ensureType();
            requestBody = check self.visitRequestBody(resolvedRequestBody);
        } else if requestBodySchema is RequestBody {
            requestBody = check self.visitRequestBody(requestBodySchema);
        }

        self.tools.push({
            name,
            description,
            path,
            method,
            parameters,
            requestBody
        });
    }

    private isolated function visitContent(map<MediaType> content) returns record {|string mediaType; Schema schema;|}|error {
        // check for json content
        foreach [string, MediaType] [key, value] in content.entries() {
            if key.trim().matches(re `(application/.*json|application/.*xml|text/.*plain|\*/\*)`) {
                return {
                    mediaType: key,
                    schema: value.schema
                };
            }
        }
        return error UnsupportedMediaTypeError("Only json or xml or text content  is supported.", availableContentTypes = content.keys());
    }

    private isolated function visitRequestBody(RequestBody requestBody) returns RequestBodySchema|error {
        map<MediaType> content = requestBody.content;
        string mediaType;
        Schema schema;
        {mediaType, schema} = check self.visitContent(content);
        return {mediaType, schema: check self.visitSchema(schema, "")};
    }

    private isolated function visitParameters((Parameter|Reference)[]? parameters) returns map<ParameterSchema>?|error {
        if parameters is () || parameters.length() == 0 {
            return ();
        }
        map<ParameterSchema> parameterSchemas = {};

        foreach Parameter|Reference param in parameters {
            Parameter resolvedParameter;
            if param is Reference {
                resolvedParameter = check self.visitReference(param).ensureType();
            } else if param is Parameter {
                resolvedParameter = param;
            } else {
                continue;
            }

            ParameterLocation location = resolvedParameter.'in;
            if location !is PATH|QUERY {
                continue;
            }

            string name = resolvedParameter.name;
            EncodingStyle? style = resolvedParameter.style;
            boolean? explode = resolvedParameter.explode;
            if location is PATH && (style is LABEL|MATRIX || explode == true) {
                return error UnsupportedSerializationError("Only simple style parameters are supported for path parameters at this time.", 'parameter = name);
            }

            Schema? schema;
            string? mediaType = ();
            map<MediaType>? content = resolvedParameter.content;
            if content is () {
                schema = resolvedParameter.schema;
            }
            else {
                {mediaType, schema} = check self.visitContent(content);
            }
            if schema is () {
                return error InvalidParameterDefinition("Resource paramters should have either a schema or a content.", 'parameter = name);
            }

            parameterSchemas[name] = {
                location,
                mediaType,
                schema: check self.visitSchema(schema, ""),
                style,
                explode,
                required: resolvedParameter.required,
                description: resolvedParameter.description,
                allowEmptyValue: resolvedParameter.allowEmptyValue,
                nullable: resolvedParameter.nullable
            };
        }
        return parameterSchemas;
    }

    private isolated function visitReference(Reference reference) returns [ComponentType, string]|InvalidReferenceError {
        if !self.referenceMap.hasKey(reference.\$ref) {
            return error InvalidReferenceError("Missing component object for the given reference", reference = reference.\$ref);
        }
        ComponentType|Reference component = self.referenceMap.get(reference.\$ref);

        string[] refList = regex:split(reference.\$ref, "/");
        string refName = refList[refList.length() - 1];
        if component is Reference {
            return self.visitReference(component);
        }
        return [component, refName];
    }

    private isolated function visitSchema(Schema schema, string refName) returns JsonSubSchema|error {
        if schema is ObjectSchema {
            return self.visitObjectSchema(schema, refName);
        }
        if schema is ArraySchema {
            return self.visitArraySchema(schema, refName);
        }
        if schema is PrimitiveTypeSchema {
            return self.visitPrimitiveTypeSchema(schema, refName);
        }
        if schema is AnyOfSchema {
            return self.visitAnyOfSchema(schema, refName);
        }
        if schema is OneOfSchema {
            return self.visitOneOfSchema(schema, refName);
        }
        if schema is AllOfSchema {
            return self.visitAllOfSchema(schema, refName);
        }
        if schema is NotSchema {
            return self.visitNotSchema(schema, refName);
        }
        [ComponentType, string] [resolvedSchema, resolvedRefName] = check self.visitReference(<Reference>schema);
        Schema ensuredResolvedSchema = check resolvedSchema.ensureType();
        return check self.visitSchema(ensuredResolvedSchema, resolvedRefName);
    }

    private isolated function visitObjectSchema(ObjectSchema schema, string refName) returns ObjectInputSchema|error {
        ObjectInputSchema objectSchema = {
            'type: OBJECT,
            properties: {},
            refName: refName,
            'xml: schema.'xml
        };

        if schema?.properties == () {
            return objectSchema;
        }

        map<Schema> properties = <map<Schema>>schema?.properties;
        if properties.length() == 0 {
            return objectSchema;
        }

        foreach [string, Schema] [propertyName, property] in properties.entries() {
            objectSchema.properties[propertyName] = check self.visitSchema(property, "");
        }
        boolean|string[]? required = schema?.required;
        if required is string[] {
            objectSchema.required = required;
        }
        if schema?.'xml?.name is string {
            objectSchema.'xml.name = schema?.'xml?.name;
        }
        return objectSchema;
    }

    private isolated function visitArraySchema(ArraySchema schema, string refName) returns ArrayInputSchema|error {
        return {
            'type: ARRAY,
            items: check self.visitSchema(schema.items, ""),
            refName: refName,
            'xml: schema.'xml
        };
    }

    private isolated function visitPrimitiveTypeSchema(PrimitiveTypeSchema schema, string refName) returns PrimitiveInputSchema|error {
        PrimitiveInputSchema inputSchmea = {
            'type: schema.'type,
            'xml: schema.'xml,
            refName: refName
        };

        if self.additionalInfoFlags.extractDescription {
            inputSchmea.description = schema.description;
        }
        if self.additionalInfoFlags.extractDefault {
            inputSchmea.default = check schema?.default.ensureType();
        }

        if schema is StringSchema {
            string? pattern = schema.pattern;
            string? format = schema.format;
            if pattern is () && format is string {
                if format == "date" {
                    pattern = OPENAPI_PATTERN_DATE;
                }
                else if format == "date-time" {
                    pattern = OPENAPI_PATTERN_DATE_TIME;
                }
            }

            inputSchmea.format = format;
            inputSchmea.pattern = pattern;
            inputSchmea.'enum = schema.'enum;
        }
        if schema is NumberSchema {
            inputSchmea.'type = FLOAT;
        }
        return inputSchmea;
    }

    private isolated function visitAnyOfSchema(AnyOfSchema schema, string refName) returns AnyOfInputSchema|error {
        JsonSubSchema[] anyOf = from Schema element in schema.anyOf
            select check self.visitSchema(element, "").ensureType();
        return {
            anyOf
        };
    }

    private isolated function visitAllOfSchema(AllOfSchema schema, string refName) returns AllOfInputSchema|error {
        JsonSubSchema[] allOf = from Schema element in schema.allOf
            select check self.visitSchema(element, "").ensureType();
        return {
            allOf
        };
    }

    private isolated function visitOneOfSchema(OneOfSchema schema, string refName) returns OneOfInputSchema|error {
        JsonSubSchema[] oneOf = from Schema element in schema.oneOf
            select check self.visitSchema(element, "");
        return {
            oneOf
        };
    }

    private isolated function visitNotSchema(NotSchema schema, string refName) returns NotInputSchema|error {
        return {
            not: check self.visitSchema(schema.not, "")
        };
    }
}
