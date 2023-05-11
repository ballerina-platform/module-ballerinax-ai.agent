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

function removeExtensions(json schema) {
    if schema is map<json> {
        foreach string key in schema.keys() {
            if key.startsWith("x-") {
                _ = schema.remove(key);
                continue;
            }
            _ = removeExtensions(schema[key]);
        }
    } else if schema is json[] {
        foreach json element in schema {
            _ = removeExtensions(element);
        }
    }
}

function parseOpenAPISpec(string jsonPath) returns OpenAPISpec|error {
    json fileJson = check io:fileReadJson(jsonPath);
    removeExtensions(fileJson);
    map<json> & readonly jsonSchema = check fileJson.cloneWithType();
    return jsonSchema.ensureType();
}

class OpenAPISpecVisitor {
    string? serverURL;
    HttpTool[] tools;
    private string currentPath;
    private HttpMethod? currentMethod;
    private map<ComponentType> referenceMap;
    private OpenAPISchemaKeyword includes;

    function init(OpenAPISchemaKeyword includes = {}) {
        // ask about comment : Can be initialized in-line in the fields itself.
        self.serverURL = ();
        self.currentPath = "";
        self.currentMethod = ();

        self.tools = [];
        self.referenceMap = {};
        self.includes = includes;
    }

    function visit(OpenAPISpec openAPISpec) returns error? {
        if !openAPISpec.openapi.matches(re `3\.0\..`) {
            return error("OpenAPI version is not supported. Supports specifications with version 3.0.x only.");
        }
        Server[]? servers = openAPISpec.servers;
        if servers !is () {
            check self.visitServers(servers);
        }
        Components? components = openAPISpec.components;
        if components !is () {
            check self.visitComponents(components);
        }
        Paths? paths = openAPISpec.paths;
        if paths !is () {
            check self.visitPaths(paths);
        }
    }

    private function visitServers(Server[] servers) returns error? {
        if servers.length() < 1 {
            return;
        }
        self.serverURL = check servers[0].url.ensureType();
        if servers.length() > 1 {
            log:printWarn("Multiple server urls are defined in the OpenAPI specification. If not specified, toolkit will use " + self.serverURL.toString());
        }
    }

    private function visitComponents(Components components) returns error? {
        foreach [string, map<ComponentType|Reference>?] componentTypeEntry in components.entries() {
            map<ComponentType|Reference>? componentMap = componentTypeEntry[1];
            if componentMap is () {
                continue;
            }
            foreach [string, ComponentType|Reference] componentEntry in componentMap.entries() {
                ComponentType|Reference component = componentEntry[1];
                string ref = string `#/components/${componentTypeEntry[0]}/${componentEntry[0]}`;
                self.referenceMap[ref] = component;
            }
        }
    }

    private function visitPaths(Paths paths) returns error? {
        foreach string pathURL in paths.keys() {
            PathItem pathItem;
            if paths.get(pathURL) is Reference {
                pathItem = check self.resolveReference(<Reference>paths.get(pathURL)).ensureType();
            } else {
                pathItem = check paths.get(pathURL).ensureType();
            }
            self.currentPath = pathURL;
            check self.visitPathItem(pathItem);
        }
    }

    private function visitPathItem(PathItem pathItem) returns error? {
        if pathItem.get is Operation {
            self.currentMethod = GET;
            check self.visitOperation(<Operation>pathItem.get);
        }
        if pathItem.post is Operation {
            self.currentMethod = POST;
            check self.visitOperation(<Operation>pathItem.post);
        }
        if pathItem.put is Operation {
            self.currentMethod = PUT;
            check self.visitOperation(<Operation>pathItem.put);
        }
        if pathItem.delete is Operation {
            self.currentMethod = DELETE;
            check self.visitOperation(<Operation>pathItem.delete);
        }
        if pathItem.options is Operation {
            self.currentMethod = OPTIONS;
            check self.visitOperation(<Operation>pathItem.options);
        }
        if pathItem.head is Operation {
            self.currentMethod = HEAD;
            check self.visitOperation(<Operation>pathItem.head);
        }
        if pathItem.patch is Operation {
            self.currentMethod = PATCH;
            check self.visitOperation(<Operation>pathItem.patch);
        }
        if pathItem.trace is Operation {
            return error("Http trace method is not supported");
        }
    }

    private function resolveReference(Reference reference) returns ComponentType|error {
        if !self.referenceMap.hasKey(reference.\$ref) {
            return error("No component found to resolve the reference: " + reference.\$ref);
        }
        ComponentType|Reference component = self.referenceMap.get(reference.\$ref);
        while component is Reference {
            component = check self.resolveReference(component);
        }
        return component;
    }

    private function visitOperation(Operation operation) returns error? {
        if operation.servers !is () {
            return error("Path-wise service URLs are not supported");
        }
        string? description = operation.summary ?: operation.description;
        if description is () {
            return error(string `Summary or Description is mandotory for paths. It is missing for ${self.currentPath} and method ${self.currentMethod.toString()}`);
        }
        string? name = operation.operationId;
        if name is () {
            return error(string `OperationId is mandotory. It is missing for ${self.currentPath} and method ${self.currentMethod.toString()}`);
        }

        // resolve queryParameters
        InputSchema? queryParams = ();
        (Parameter|Reference)[]? parameters = operation.parameters;
        if parameters is (Parameter|Reference)[] {
            queryParams = check self.visitParameters(parameters);
        }

        InputSchema? jsonRequestBody = ();
        RequestBody|Reference? requestBody = operation.requestBody;
        if requestBody is Reference {
            RequestBody resolvedRequestBody = check self.resolveReference(requestBody).ensureType();
            jsonRequestBody = check self.visitRequestBody(resolvedRequestBody);
        } else if requestBody is RequestBody {
            jsonRequestBody = check self.visitRequestBody(requestBody);
        }

        self.tools.push({
            name,
            description,
            path: self.currentPath,
            method: <HttpMethod>self.currentMethod,
            queryParams,
            requestBody: jsonRequestBody
        });
    }

    function visitRequestBody(RequestBody requestBody) returns JsonInputSchema|error {
        map<MediaType> content = requestBody.content;

        // check for json content
        if !content.hasKey(OPENAPI_JSON_CONTENT_KEY) {
            return error("Only json content is supported.");
        }
        Schema schema = content.get(OPENAPI_JSON_CONTENT_KEY).schema;
        return self.visitSchema(schema).ensureType();
    }

    function visitParameters((Parameter|Reference)[] parameters) returns JsonInputSchema?|error {

        map<SubSchema> properties = {};

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

    function visitSchema(Schema schema) returns SubSchema|error {

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

    function visitObjectSchema(ObjectSchema schema) returns ObjectInputSchema|error {
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

        foreach string propertyName in properties.keys() {
            SubSchema trimmedProperty = check self.visitSchema(properties.get(propertyName));
            objectSchema.properties[propertyName] = trimmedProperty;
        }
        return objectSchema;
    }

    function visitArraySchema(ArraySchema schema) returns ArrayInputSchema|error {
        SubSchema trimmedItems = check self.visitSchema(schema.items);
        return {
            'type: ARRAY,
            items: trimmedItems
        };
    }

    function visitPrimitiveTypeSchema(PrimitiveTypeSchema schema) returns PrimitiveInputSchema {
        PrimitiveInputSchema inputSchmea = {
            'type: schema.'type
        };

        if self.includes.description {
            inputSchmea.description = schema.description;
        }
        if self.includes.default {
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

    function visitAnyOfSchema(AnyOfSchema schema) returns AnyOfInputSchema|error {
        SubSchema[] anyOf = from Schema element in schema.anyOf
            select check self.visitSchema(element);
        return {
            anyOf
        };
    }

    function visitAllOfSchema(AllOfSchema schema) returns AllOfInputSchema|error {
        SubSchema[] allOf = from Schema element in schema.allOf
            select check self.visitSchema(element);
        return {
            allOf
        };
    }

    function visitOneOfSchema(OneOfSchema schema) returns OneOfInputSchema|error {
        SubSchema[] oneOf = from Schema element in schema.oneOf
            select check self.visitSchema(element);
        return {
            oneOf
        };
    }

    function visitNotSchema(NotSchema schema) returns NotInputSchema|error {
        return {
            not: check self.visitSchema(schema.not)
        };
    }
}

