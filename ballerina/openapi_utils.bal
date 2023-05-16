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

public type HttpApiSpecification record {|
    string serviceUrl?;
    HttpTool[] tools;
|};

public type AdditionInfoFlags record {|
    boolean extractDescrition = false;
    boolean extractDefault = false;
|};

public function extractToolsFromOpenApiSpec(string filePath, *AdditionInfoFlags additionInfoFlags) returns HttpApiSpecification & readonly|error {
    OpenApiSpec openApiSpec = check parseOpenApiSpec(filePath);
    OpenApiSpecVisitor visitor = new (additionInfoFlags);
    return check visitor.visit(openApiSpec).cloneReadOnly();
}

isolated function cleanXtagsFromJsonSpec(map<json>|json[] openAPISpec) {
    if openAPISpec is map<json> {
        foreach [string, json] [key, value] in openAPISpec.entries() {
            if key.startsWith("x-") {
                _ = openAPISpec.remove(key);
                continue;
            }
            if value is map<json>|json[] {
                _ = cleanXtagsFromJsonSpec(value);
            }
        }
        return;
    }
    foreach json element in openAPISpec {
        if element is map<json>|json[] {
            _ = cleanXtagsFromJsonSpec(element);
        }
    }
}

isolated function parseOpenApiSpec(string jsonPath) returns OpenApiSpec|error {
    map<json> fileJson = check io:fileReadJson(jsonPath).ensureType();
    cleanXtagsFromJsonSpec(fileJson);
    map<json> & readonly jsonSchema = check fileJson.cloneWithType();
    return jsonSchema.ensureType();
}

class OpenApiSpecVisitor {
    private map<ComponentType> referenceMap = {};
    private final HttpTool[] tools = [];
    private final AdditionInfoFlags additionalInfoFlags;

    function init(AdditionInfoFlags additionalInfoFlags = {}) {
        self.additionalInfoFlags = additionalInfoFlags.cloneReadOnly();
    }

    function visit(OpenApiSpec openApiSpec) returns HttpApiSpecification|error {
        if !openApiSpec.openapi.matches(re `3\.0\..`) {
            return error("Unsupported OpenAPI version. Supports specifications with version 3.0.x only.");
        }

        string? serviceUrl = self.visitServers(openApiSpec.servers);
        self.referenceMap = self.visitComponents(openApiSpec.components);

        Paths? paths = openApiSpec.paths;
        if paths !is () {
            check self.visitPaths(paths);
        }

        return {
            serviceUrl,
            tools: self.tools.cloneReadOnly()
        };
    }

    private function visitServers(Server[]? servers) returns string? {
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
        foreach [string, map<ComponentType|Reference>] [componentType, componentMap] in components.entries() {
            foreach [string, ComponentType|Reference] [componentName, component] in componentMap.entries() {
                string ref = string `#/${OPENAPI_COMPONENTS_KEY}/${componentType}/${componentName}`;
                referenceMap[ref] = component;
            }
        }
        return referenceMap;
    }

    private function visitPaths(Paths paths) returns error? {
        foreach [string, PathItem|Reference] [pathUrl, pathItem] in paths.entries() {
            if pathItem is Reference {
                check self.visitPathItem(check self.resolveReference(pathItem).ensureType(), pathUrl);
            } else {
                check self.visitPathItem(pathItem, pathUrl);
            }
        }
    }

    private function visitPathItem(PathItem pathItem, string pathUrl) returns error? {
        if pathItem.get is Operation {
            check self.visitOperation(<Operation>pathItem.get, pathUrl, GET);
        }
        if pathItem.post is Operation {
            check self.visitOperation(<Operation>pathItem.post, pathUrl, POST);
        }
        if pathItem.put is Operation {
            check self.visitOperation(<Operation>pathItem.put, pathUrl, PUT);
        }
        if pathItem.delete is Operation {
            check self.visitOperation(<Operation>pathItem.delete, pathUrl, DELETE);
        }
        if pathItem.options is Operation {
            check self.visitOperation(<Operation>pathItem.options, pathUrl, OPTIONS);
        }
        if pathItem.head is Operation {
            check self.visitOperation(<Operation>pathItem.head, pathUrl, HEAD);
        }
        if pathItem.patch is Operation {
            check self.visitOperation(<Operation>pathItem.patch, pathUrl, PATCH);
        }
        if pathItem.trace is Operation {
            return error("Http trace method is not supported");
        }
    }

    private function visitOperation(Operation operation, string path, HttpMethod method) returns error? {
        if operation.servers !is () {
            return error("Path-wise service URLs are not supported. Please use global server URL.");
        }
        string? description = operation.summary ?: operation.description;
        if description is () {
            return error(string `Summary or description is mandotory for paths. It is missing for ${path} and method ${method}`);
        }
        string? name = operation.operationId;
        if name is () {
            return error(string `OperationId is mandotory. It is missing for ${path} and method ${method}`);
        }

        // resolve queryParameters
        InputSchema? queryParams = ();
        (Parameter|Reference)[]? parameters = operation.parameters;
        if parameters is (Parameter|Reference)[] {
            queryParams = check self.visitParameters(parameters);
        }

        InputSchema? requestBody = ();
        RequestBody|Reference? requestBodySchema = operation.requestBody;
        if requestBodySchema is Reference {
            RequestBody resolvedRequestBody = check self.resolveReference(requestBodySchema).ensureType();
            requestBody = check self.visitRequestBody(resolvedRequestBody);
        } else if requestBodySchema is RequestBody {
            requestBody = check self.visitRequestBody(requestBodySchema);
        }

        self.tools.push({
            name,
            description,
            path,
            method,
            queryParams,
            requestBody
        });
    }

    private function visitRequestBody(RequestBody requestBody) returns JsonInputSchema|error {
        map<MediaType> content = requestBody.content;

        // check for json content
        if !content.hasKey(OPENAPI_JSON_CONTENT_KEY) {
            return error("Only json content is supported.");
        }
        Schema schema = content.get(OPENAPI_JSON_CONTENT_KEY).schema;
        return self.visitSchema(schema).ensureType();
    }

    private function visitParameters((Parameter|Reference)[] parameters) returns JsonInputSchema?|error {

        map<JsonSubSchema> properties = {};

        foreach Parameter|Reference param in parameters {
            Parameter resolvedParameter;
            if param is Reference {
                resolvedParameter = check self.resolveReference(param).ensureType();
            } else {
                resolvedParameter = param;
            }

            Schema? schema = resolvedParameter.schema;
            if resolvedParameter.'in == OPENAPI_QUERY_PARAM_LOC_KEY && schema !is () {
                string? style = resolvedParameter.style;
                boolean? explode = resolvedParameter.explode;
                if style !is () && style != OPENAPI_SUPPORTED_STYLE {
                    return error("Supported only the query parameters with style=" + OPENAPI_SUPPORTED_STYLE);
                }
                if explode !is () && !explode {
                    return error("Supported only the query parmaters with explode=true");
                }
                properties[resolvedParameter.name] = check self.visitSchema(schema);
            }
        }
        if properties.length() == 0 {
            return ();
        }
        return {properties};
    }

    private function resolveReference(Reference reference) returns ComponentType|error {
        if !self.referenceMap.hasKey(reference.\$ref) {
            return error("No component found for the reference: " + reference.\$ref);
        }
        ComponentType|Reference component = self.referenceMap.get(reference.\$ref);

        if component is Reference {
            return self.resolveReference(component);
        }
        return component;
    }

    private function visitSchema(Schema schema) returns JsonSubSchema|error {

        if schema is ObjectSchema {
            return self.visitObjectSchema(schema);
        }
        if schema is ArraySchema {
            return self.visitArraySchema(schema);
        }
        if schema is PrimitiveTypeSchema {
            return self.visitPrimitiveTypeSchema(schema);
        }
        if schema is AnyOfSchema {
            return self.visitAnyOfSchema(schema);
        }
        if schema is OneOfSchema {
            return self.visitOneOfSchema(schema);
        }
        if schema is AllOfSchema {
            return self.visitAllOfSchema(schema);
        }
        if schema is NotSchema {
            return self.visitNotSchema(schema);
        }

        Schema resolvedSchema = check self.resolveReference(<Reference>schema).ensureType();
        return check self.visitSchema(resolvedSchema);
    }

    private function visitObjectSchema(ObjectSchema schema) returns ObjectInputSchema|error {
        ObjectInputSchema objectSchema = {
            'type: OBJECT,
            properties: {}
        };

        if schema?.properties == () {
            return objectSchema;
        }

        map<Schema> properties = <map<Schema>>schema?.properties;
        if properties.length() == 0 {
            return objectSchema;
        }

        foreach [string, Schema] [propertyName, property] in properties.entries() {
            JsonSubSchema trimmedProperty = check self.visitSchema(property);
            objectSchema.properties[propertyName] = trimmedProperty;
        }
        return objectSchema;
    }

    private function visitArraySchema(ArraySchema schema) returns ArrayInputSchema|error {
        JsonSubSchema trimmedItems = check self.visitSchema(schema.items);
        return {
            'type: ARRAY,
            items: trimmedItems
        };
    }

    private function visitPrimitiveTypeSchema(PrimitiveTypeSchema schema) returns PrimitiveInputSchema {
        PrimitiveInputSchema inputSchmea = {
            'type: schema.'type
        };

        if self.additionalInfoFlags.extractDescrition {
            inputSchmea.description = schema.description;
        }
        if self.additionalInfoFlags.extractDefault {
            inputSchmea.default = schema?.default;
        }

        if schema is StringSchema {
            string? pattern = schema.pattern;
            string? format = schema.format;
            if format is string && pattern is () {
                if format == "date" {
                    pattern = OPENAPI_PATTER_DATE;
                }
                else if format == "date-time" {
                    pattern = OPENAPI_PATTER_DATE_TIME;
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

    private function visitAnyOfSchema(AnyOfSchema schema) returns AnyOfInputSchema|error {
        JsonSubSchema[] anyOf = from Schema element in schema.anyOf
            select check self.visitSchema(element);
        return {
            anyOf
        };
    }

    private function visitAllOfSchema(AllOfSchema schema) returns AllOfInputSchema|error {
        JsonSubSchema[] allOf = from Schema element in schema.allOf
            select check self.visitSchema(element);
        return {
            allOf
        };
    }

    private function visitOneOfSchema(OneOfSchema schema) returns OneOfInputSchema|error {
        JsonSubSchema[] oneOf = from Schema element in schema.oneOf
            select check self.visitSchema(element);
        return {
            oneOf
        };
    }

    private function visitNotSchema(NotSchema schema) returns NotInputSchema|error {
        return {
            not: check self.visitSchema(schema.not)
        };
    }
}

