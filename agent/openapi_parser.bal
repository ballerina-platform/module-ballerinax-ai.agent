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

import ballerina/regex;
import ballerina/io;

type OpenAPIAction record {|
    *HttpAction;
|};

class OpenAPIParser {
    map<json> specification;
    map<json> components;

    function init(string filePath) returns error? {
        self.specification = check io:fileReadJson(filePath).ensureType();

        if self.specification.hasKey(OPENAPI_COMPONENTS_KEY) {
            self.components = check self.specification.get(OPENAPI_COMPONENTS_KEY).ensureType();
        } else {
            self.components = {};
        }
        check self.verfiyOpenAPIVersion();

    }

    function resolvePaths() returns OpenAPIAction[]|error {
        if !self.specification.hasKey(OPENAPI_PATHS_KEY) {
            return error("No paths are defined in the OpenAPI specification.");
        }

        OpenAPIAction[] pathActions = [];
        map<json> paths = check self.specification.get(OPENAPI_PATHS_KEY).ensureType();
        foreach string path in paths.keys() {
            map<json> pathItems = check paths.get(path).ensureType();
            foreach string method in pathItems.keys() {
                HttpMethod httpMethod = check self.resolveHttpMethod(method);
                map<json> httpMethodItem = check pathItems.get(method).ensureType();

                string name = check httpMethodItem.get(OPENAPI_OPERATION_ID_KEY).ensureType();
                string description = check httpMethodItem.get(OPENAPI_SUMMERY_KEY).ensureType();

                // TODO extract only query parameters 
                // json[] parameters = check httpMethodItem.get(OPENAPI_PARAMETERS_KEY).ensureType();

                json requestBody = {};
                if httpMethodItem.hasKey(OPENAPI_REQUEST_BODY_KEY) {
                    requestBody = check self.resolveRequestBody(check httpMethodItem.get(OPENAPI_REQUEST_BODY_KEY).ensureType());
                }

                OpenAPIAction pathAction = {
                    name: name,
                    description: description,
                    path: path,
                    method: httpMethod,
                    requestBody: requestBody
                };
                pathActions.push(pathAction);

            }
        }
        return pathActions;
    }

    function verfiyOpenAPIVersion() returns error? {
        if !self.specification.hasKey(OPENAPI_KEY) {
            return error("OpenAPI version is unknown.");
        }

        string 'version = check self.specification.get(OPENAPI_KEY);
        if !'version.matches(re `3\.0\..`) {
            return error("OpenAPI version is not supported. Supports specifications with version 3.0.x only.");
        }
    }

    function resolveServerURL() returns string|error {
        if self.specification.hasKey(OPENAPI_SERVER_KEY) {
            return error("Servers key is missing in OpenAPI specification.");
        }

        json[] servers = check self.specification.get(OPENAPI_SERVER_KEY).ensureType();
        if servers.length() < 1 {
            return error("Server url isn't specified in the OpenAPI specification or during the initialization.");
        }

        if servers.length() > 1 {
            return error("Multiple server urls are defined in the OpenAPI specification.");
        }
        string serverURL = check servers[0].url.ensureType();
        return serverURL;
    }

    function resolveOpenAPIObject(map<json> properties) returns map<json>|error {
        map<json> schema = {};
        map<json> property;
        string propertyType;

        foreach var propertyName in properties.keys() {
            property = check properties.get(propertyName).ensureType();

            if !property.hasKey(OPENAPI_TYPE_KEY) {
                schema[propertyName] = check self.resolveOpenAPISchema(property);
                continue;
            }
            propertyType = check property.get(OPENAPI_TYPE_KEY).ensureType();

            match propertyType {
                OPENAPI_OBJECT_TYPE => {
                    json objectRecord = check self.resolveOpenAPISchema(property);
                    schema[propertyName] = objectRecord;
                }
                OPENAPI_ARRAY_TYPE => {
                    map<json> items = check property.get(OPENAPI_ITEMS_KEY).ensureType();
                    if !items.hasKey(OPENAPI_TYPE_KEY) || items.get(OPENAPI_TYPE_KEY) == OPENAPI_OBJECT_TYPE {
                        schema[propertyName] = [check self.resolveOpenAPISchema(items)];
                    } else {
                        json itemType = items.get(OPENAPI_TYPE_KEY);
                        schema[propertyName] = itemType.toString() + "[]";
                    }

                }
                _ => {
                    // if property.hasKey(OPENAPI_DEFAULT_VALUE_KEY) {
                    //     string defaultValue = property.get(OPENAPI_DEFAULT_VALUE_KEY).toString();
                    //     propertyType += "?default=" + defaultValue;
                    // }
                    schema[propertyName] = propertyType;
                }
            }
        }
        return schema;
    }

    function resolveOpenAPISchema(map<json> openAPISchema) returns json|error {
        if openAPISchema.hasKey(OPENAPI_PROPERTIES_KEY) {
            map<json> objectSchema = check openAPISchema.get(OPENAPI_PROPERTIES_KEY).ensureType();
            return self.resolveOpenAPIObject(objectSchema);
        }
        if openAPISchema.hasKey(OPENAPI_REF_KEY) {
            string reference = check openAPISchema.get(OPENAPI_REF_KEY).ensureType();
            map<json> referenceSchema = check self.resolveSchemaReference(reference);
            json subSchema = check self.resolveOpenAPISchema(referenceSchema);
            return subSchema;
        }
        if openAPISchema.hasKey(OPENAPI_ANY_OF_KEY) {
            return error("'AnyOf' key is not supported.");
        }
        if openAPISchema.hasKey(OPENAPI_ALL_OF_KEY) {
            json schema = {};
            json[] allOfSchemas = check openAPISchema.get(OPENAPI_ALL_OF_KEY).ensureType();
            foreach json allOfSchema in allOfSchemas {
                json subSchema = check self.resolveOpenAPISchema(check allOfSchema.ensureType());
                schema = check schema.mergeJson(subSchema).ensureType();
            }
            return schema;
        }
        if openAPISchema.hasKey(OPENAPI_ONE_OF_KEY) {
            string[] unionTypes = [];
            json[] oneOfRecords = check openAPISchema.get(OPENAPI_ONE_OF_KEY).ensureType();
            foreach json oneOfJson in oneOfRecords {
                map<json> oneOfRecord = check oneOfJson.ensureType();
                string oneOfType = check oneOfRecord.get(OPENAPI_TYPE_KEY).ensureType();
                match oneOfType {
                    OPENAPI_OBJECT_TYPE => {
                        return error("'OneOf' key is not supported of 'object' type properties.");
                    }
                    OPENAPI_ARRAY_TYPE => {
                        map<json> items = check oneOfRecord.get(OPENAPI_ITEMS_KEY).ensureType();
                        if !items.hasKey(OPENAPI_TYPE_KEY) || items.get(OPENAPI_TYPE_KEY) == OPENAPI_OBJECT_TYPE {
                            return error("'OneOf' key is not supported of 'object' type properties.");
                        } else {
                            json itemType = items.get(OPENAPI_TYPE_KEY);
                            unionTypes.push(itemType.toString() + "[]");
                        }
                    }
                    _ => {
                        unionTypes.push(oneOfType);
                    }
                }

            }
            return "|".join(...unionTypes);
        }
        if openAPISchema.hasKey(OPENAPI_NOT_KEY) {
            return error("'not' key is not supported.");
        }
        return {};
    }

    function resolveSchemaReference(string referencePath) returns map<json>|error {
        string[] refPaths = regex:split(referencePath, "/");
        map<json> refSchema = self.components;
        foreach string refPath in refPaths {
            if refPath == "#" || refPath.equalsIgnoreCaseAscii(OPENAPI_COMPONENTS_KEY) {
                continue;
            }
            refSchema = check refSchema.get(refPath).ensureType();
        }
        return refSchema;
    }

    function resolveHttpMethod(string httpMethod) returns HttpMethod|error {
        match httpMethod.toUpperAscii() {
            GET => {
                return GET;
            }
            POST => {
                return POST;
            }
            DELETE => {
                return DELETE;
            }
            _ => {
                return error("Invalid or unsupported HTTP method : " + httpMethod);
            }
        }
    }

    function resolveRequestBody(map<json> requestBody) returns json|error {
        map<json> content = check requestBody.get(OPENAPI_CONTENT_KEY).ensureType();
        // check for json content
        if !content.hasKey(OPENAPI_JSON_CONTENT_KEY) {
            return error("Only json content is supported.");
        }

        map<json> jsonContent = check content.get(OPENAPI_JSON_CONTENT_KEY).ensureType();
        map<json> schema = check jsonContent.get(OPENAPI_SCHEMA_KEY).ensureType();
        return check self.resolveOpenAPISchema(schema);
    }

}

