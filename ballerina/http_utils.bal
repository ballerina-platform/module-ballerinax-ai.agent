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

import ballerina/http;
import ballerina/lang.regexp;
import ballerina/mime;
import ballerina/url;
import ballerina/xmldata;

type QueryParamEncoding record {
    EncodingStyle style = FORM;
    boolean explode = true;
};

# Serialize the record according to the deepObject style.
#
# + parent - Parent record name
# + anyRecord - Record to be serialized
# + return - Serialized record as a string
isolated function getDeepObjectStyleRequest(string parent, record {} anyRecord) returns string {
    string[] recordArray = [];
    foreach [string, anydata] [key, value] in anyRecord.entries() {
        if value is PrimitiveType {
            recordArray.push(parent + "[" + key + "]" + "=" + getEncodedUri(value.toString()));
        } else if value is PrimitiveType[] {
            recordArray.push(getSerializedArray(parent + "[" + key + "]" + "[]", value, DEEPOBJECT, true));
        } else if value is record {} {
            string nextParent = parent + "[" + key + "]";
            recordArray.push(getDeepObjectStyleRequest(nextParent, value));
        } else if value is record {}[] {
            string nextParent = string `${parent}[${key}]`;
            recordArray.push(getSerializedRecordArray(nextParent, value, DEEPOBJECT));
        }
        recordArray.push("&");
    }
    _ = recordArray.pop();
    return string:'join("", ...recordArray);
}

# Serialize the record according to the form style.
#
# + parent - Parent record name
# + anyRecord - Record to be serialized
# + explode - Specifies whether arrays and objects should generate separate parameters
# + return - Serialized record as a string
isolated function getFormStyleRequest(string parent, record {} anyRecord, boolean explode = true) returns string {
    string[] recordArray = [];
    if explode {
        foreach [string, anydata] [key, value] in anyRecord.entries() {
            if value is PrimitiveType {
                recordArray.push(key, "=", getEncodedUri(value.toString()));
            } else if value is PrimitiveType[] {
                recordArray.push(getSerializedArray(key, value, explode = explode));
            } else if value is record {} {
                recordArray.push(getFormStyleRequest(parent, value, explode));
            }
            recordArray.push("&");
        }
        _ = recordArray.pop();
    } else {
        foreach [string, anydata] [key, value] in anyRecord.entries() {
            if (value is PrimitiveType) {
                recordArray.push(key, ",", getEncodedUri(value.toString()));
            } else if value is PrimitiveType[] {
                recordArray.push(getSerializedArray(key, value, explode = false));
            } else if value is record {} {
                recordArray.push(getFormStyleRequest(parent, value, explode));
            }
            recordArray.push(",");
        }
        _ = recordArray.pop();
    }
    return string:'join("", ...recordArray);
}

# Serialize arrays.
#
# + arrayName - Name of the field with arrays
# + anyArray - Array to be serialized
# + style - Defines how multiple values are delimited
# + explode - Specifies whether arrays and objects should generate separate parameters
# + return - Serialized array as a string
isolated function getSerializedArray(string arrayName, anydata[] anyArray, string style = "form", boolean explode = true) returns string {
    string key = arrayName;
    string[] arrayValues = [];
    if anyArray.length() > 0 {
        if style == FORM && !explode {
            arrayValues.push(key, "=");
            foreach anydata i in anyArray {
                arrayValues.push(getEncodedUri(i.toString()), ",");
            }
        } else if style == SPACEDELIMITED && !explode {
            arrayValues.push(key, "=");
            foreach anydata i in anyArray {
                arrayValues.push(getEncodedUri(i.toString()), "%20");
            }
        } else if style == PIPEDELIMITED && !explode {
            arrayValues.push(key, "=");
            foreach anydata i in anyArray {
                arrayValues.push(getEncodedUri(i.toString()), "|");
            }
        } else if style == DEEPOBJECT {
            foreach anydata i in anyArray {
                arrayValues.push(key, "[]", "=", getEncodedUri(i.toString()), "&");
            }
        } else {
            foreach anydata i in anyArray {
                arrayValues.push(key, "=", getEncodedUri(i.toString()), "&");
            }
        }
        _ = arrayValues.pop();
    }
    return string:'join("", ...arrayValues);
}

# Serialize the array of records according to the form style.
#
# + parent - Parent record name
# + value - Array of records to be serialized
# + style - Defines how multiple values are delimited
# + explode - Specifies whether arrays and objects should generate separate parameters
# + return - Serialized record as a string
isolated function getSerializedRecordArray(string parent, record {}[] value, string style = FORM, boolean explode = true) returns string {
    string[] serializedArray = [];
    if style == DEEPOBJECT {
        int arayIndex = 0;
        foreach var recordItem in value {
            serializedArray.push(getDeepObjectStyleRequest(parent + "[" + arayIndex.toString() + "]", recordItem), "&");
            arayIndex = arayIndex + 1;
        }
    } else {
        if !explode {
            serializedArray.push(parent, "=");
        }
        foreach var recordItem in value {
            serializedArray.push(getFormStyleRequest(parent, recordItem, explode), ",");
        }
    }
    _ = serializedArray.pop();
    return string:'join("", ...serializedArray);
}

# Get Encoded URI for a given value.
#
# + value - Value to be encoded
# + return - Encoded string
isolated function getEncodedUri(anydata value) returns string {
    string|error encoded = url:encode(value.toString(), "UTF8");
    if encoded is string {
        return encoded;
    }
    return value.toString();
}

# Generate query path with query parameter.
#
# + queryParam - Query parameter map
# + encodingMap - Details on serialization mechanism
# + return - Returns generated Path or error at failure of client initialization
isolated function getPathForQueryParam(map<anydata> queryParam, map<QueryParamEncoding> encodingMap = {}) returns string {
    string[] param = [];
    if queryParam.length() > 0 {
        param.push("?");
        foreach var [key, value] in queryParam.entries() {
            if value is () {
                _ = queryParam.remove(key);
                continue;
            }
            QueryParamEncoding encodingData = encodingMap.hasKey(key) ? encodingMap.get(key) : {};
            if value is PrimitiveType {
                param.push(key, "=", getEncodedUri(value.toString()));
            } else if value is PrimitiveType[] {
                param.push(getSerializedArray(key, value, encodingData.style, encodingData.explode));
            } else if value is record {} {
                if encodingData.style == DEEPOBJECT {
                    param.push(getDeepObjectStyleRequest(key, value));
                } else {
                    param.push(getFormStyleRequest(key, value, encodingData.explode));
                }
            } else {
                param.push(key, "=", value.toString());
            }
            param.push("&");
        }
        _ = param.pop();
    }
    string restOfPath = string:'join("", ...param);
    return restOfPath;
}

isolated function getSimpleStyleParams(string key, json parameterValue) returns string|UnsupportedSerializationError {
    if parameterValue is PrimitiveType {
        return parameterValue.toString();
    }
    if parameterValue is PrimitiveType[] {
        string[] arrayValues = from json param in parameterValue
            select param.toString();
        return string:'join(",", ...arrayValues);
    }
    if parameterValue is map<PrimitiveType> {
        string[] arrayValues = [];
        foreach [string, PrimitiveType] [paramKey, paramValue] in parameterValue.entries() {
            arrayValues.push(paramKey, paramValue.toString());
        }
        return string:'join(",", ...arrayValues);
    }
    return error UnsupportedSerializationError(string `Unsupported value for path paremeter serialization.`, pathParam = key, value = parameterValue);
}

isolated function getParamEncodedPath(HttpTool tool, map<json>? parameters) returns string|MissingHttpParameterError|UnsupportedSerializationError {
    // TODO handle special charactors :/?#[]@!$&'()*+,;=
    string pathWithParams = tool.path;
    map<ParameterSchema>? parameterSchemas = tool.parameters;
    if parameters !is () && parameterSchemas !is () {
        map<QueryParamEncoding> queryParamEncoding = {};
        map<json> queryParams = {};
        foreach [string, ParameterSchema] [paramName, paramSchema] in parameterSchemas.entries() {
            if paramSchema.location == PATH {
                if !parameters.hasKey(paramName) {
                    return error MissingHttpParameterError(string `Missing path paremter value in the generated set.`, path = tool.path, pathParam = paramName);
                }
                json parameterValue = parameters.get(paramName);
                string value = check getSimpleStyleParams(paramName, parameterValue);
                pathWithParams = regexp:replaceAll(re `\{${paramName}\}`, pathWithParams, value);
            } else {
                if parameters.hasKey(paramName) {
                    queryParams[paramName] = parameters.get(paramName);
                    queryParamEncoding[paramName] = {
                        style: paramSchema.style ?: FORM,
                        explode: paramSchema.explode ?: true
                    };
                }
            }
        }
        pathWithParams += getPathForQueryParam(queryParams, queryParamEncoding);
    }
    return pathWithParams;
}

isolated function extractResponsePayload(string path, http:Response response) returns HttpOutput|HttpResponseParsingError {
    int code = response.statusCode;
    int|error? contentLength = getContentLength(response);
    if contentLength is error {
        return error HttpResponseParsingError("Error occurred while extracting content length from the response.", contentLength);
    }
    if contentLength == 0 {
        return {
            code,
            path,
            headers: {contentLength}
        };
    }

    json|xml|error body;
    string contentType = response.getContentType();
    match regexp:split(re `;`, contentType)[0].trim() {
        mime:APPLICATION_JSON|mime:APPLICATION_XML|mime:TEXT_PLAIN|mime:TEXT_HTML|mime:TEXT_XML => {
            body = response.getTextPayload();
        }
        "" => {
            body = ();
        }
        _ => {
            body = "<Unsupported Content Type>";
        }
    }
    if body is error {
        return error HttpResponseParsingError("Error occurred while parsing the response payload.", body, contentType = contentType);
    }
    return {
        code,
        path,
        headers: {contentLength: contentLength > 0 ? contentLength : (), contentType},
        body
    };
}

public isolated function getContentLength(http:Response response) returns int|error? {
    string|error contentLengthHeader = response.getHeader(mime:CONTENT_LENGTH);
    if contentLengthHeader is error || contentLengthHeader == "" {
        return;
    }
    return int:fromString(contentLengthHeader);
}

isolated function convertJsonToXml(HttpInput httpInput) returns xml|error {
    JsonSubSchema? schema = httpInput.tool.requestBody?.schema;
    map<json>? requestBody = httpInput.requestBody;
    json output = {};
    if schema is JsonSubSchema && requestBody is map<json> {
        [json, string] [outputBody, childName] = check visitSchema(schema, requestBody, "root");
        output = {[childName] : outputBody};
        xml? xmlData = check xmldata:fromJson(output);
        if xmlData is xml {
            return xmlData;
        }
    }
    return error InvalidParameterDefinition("Error occurred while converting json to xml.");
}

isolated function visitSchema(JsonSubSchema schema, map<json>|json requestBody, string name) returns [json, string]|error {
    if schema is ObjectInputSchema {
        return visitObjectInputSchema(schema, requestBody, name);
    }
    if schema is ArrayInputSchema {
        return visitArrayInputSchema(schema, requestBody, name);
    }
    if schema is PrimitiveInputSchema {
        return visitPrimitiveTypeInputSchema(schema, requestBody, name);
    }
    if schema is AnyOfInputSchema {
        return visitAnyOfInputSchema(schema, requestBody, name);
    }
    if schema is OneOfInputSchema {
        return visitOneOfInputSchema(schema, requestBody, name);
    }
    if schema is AllOfInputSchema {
        return visitAllOfInputSchema(schema, requestBody, name);
    }
    if schema is NotInputSchema {
        return visitNotInputSchema(schema, requestBody, name);
    }
    return error(string `Unsupported schema type found.${schema.toString()}`);
}

isolated function visitObjectInputSchema(ObjectInputSchema schema, json requestBody, string parentName) returns [json, string]|error {
    map<json> output = {};
    string? childName = schema?.'xml?.name;
    string? refName = schema?.refName;
    boolean? outerXmlAttribute = schema?.'xml?.attribute;
    string modifiedParentName = parentName;
    string? xmlNamespace = schema?.'xml?.namespace;
    string? xmlPrefix = schema?.'xml?.prefix;
    if xmlNamespace is string && xmlPrefix is string {
        output["@xmlns:" + xmlPrefix] = xmlNamespace;
    } else if xmlNamespace is string {
        output["@xmlns"] = xmlNamespace;
    }
    if xmlPrefix is string {
        if childName is string {
            childName = xmlPrefix + ":" + childName;
        } else if refName is string && refName != "" {
            refName = xmlPrefix + ":" + refName;
        } else {
            modifiedParentName = xmlPrefix + ":" + modifiedParentName;
        }
    }
    if outerXmlAttribute is boolean && outerXmlAttribute {
        if childName is string {
            childName = "@" + childName;
        } else if refName is string && refName != "" {
            refName = "@" + refName;
        } else {
            modifiedParentName = "@" + modifiedParentName;
        }
    }
    map<JsonSubSchema> properties = <map<JsonSubSchema>>schema?.properties;
    if properties.length() == 0 {
        if childName is string {
            return [output, childName];
        } else if refName is string && refName != "" {
            return [output, refName];
        } else {
            return [output, modifiedParentName];
        }
    }

    foreach [string, JsonSubSchema] [propertyName, property] in properties.entries() {
        map<json> requestBodyMap = <map<json>>requestBody;
        json child = requestBodyMap[propertyName];
        [json, string] [outputBody, xmlName] = check visitSchema(property, child, propertyName);
        output[xmlName] = outputBody;
    }
    if childName is string {
        return [output, childName];
    } else if refName is string {
        return [output, refName];
    } else {
        return [output, modifiedParentName];
    }
}

isolated function visitArrayInputSchema(ArrayInputSchema schema, json requestBody, string parentName) returns [json, string]|error {
    map<json> output = {};
    string? outerChildName = schema?.'xml?.name;
    string? outerRefName = schema?.refName;
    string modifiedParentName = parentName;
    boolean? outerXmlAttribute = schema?.'xml?.attribute;
    string? xmlNamespace = schema?.'xml?.namespace;
    string? xmlPrefix = schema?.'xml?.prefix;
    if xmlNamespace is string && xmlPrefix is string {
        output["@xmlns:" + xmlPrefix] = xmlNamespace;
    } else if xmlNamespace is string {
        output["@xmlns"] = xmlNamespace;
    }
    if xmlPrefix is string {
        if outerChildName is string {
            outerChildName = xmlPrefix + ":" + outerChildName;
        } else if outerRefName is string && outerRefName != "" {
            outerRefName = xmlPrefix + ":" + outerRefName;
        } else {
            modifiedParentName = xmlPrefix + ":" + modifiedParentName;
        }
    }
    if outerXmlAttribute is boolean && outerXmlAttribute {
        if outerChildName is string {
            outerChildName = "@" + outerChildName;
        } else if outerRefName is string && outerRefName != "" {
            outerRefName = "@" + outerRefName;
        } else {
            modifiedParentName = "@" + modifiedParentName;
        }
    }
    string? childName = schema?.items.'xml?.name;
    string? refName = schema?.items?.refName;
    json outputBody = {};
    boolean? wrapped = schema?.'xml?.wrapped;
    json[] inputArray = check requestBody.ensureType();
    json[] outputArray = [];
    foreach var item in inputArray {
        [outputBody, _] = check visitSchema(schema?.items, item, parentName);
        outputArray.push(outputBody);
    }
    if wrapped is boolean && wrapped {
        if childName is string {
            // output = {[childName] : outputArray};
            output[childName] = outputArray;
        } else if refName is string && refName != "" {
            // output = {[refName] : outputArray};
            output[refName] = outputArray;
        } else {
            // output = {[parentName] : outputArray};
            output[parentName] = outputArray;
        }
    } else {
        output["#content"] = outputArray;
    }
    if outerChildName is string {
        return [output, outerChildName];
    } else if outerRefName is string && outerRefName != "" {
        return [output, outerRefName];
    } else {
        return [output, modifiedParentName];
    }
}

isolated function visitPrimitiveTypeInputSchema(PrimitiveInputSchema schema, json requestBody, string parentName) returns [json, string]|error {
    string? childName = schema?.'xml?.name;
    string? refName = schema?.refName;
    string modifiedParentName = parentName;
    boolean? xmlAttribute = schema?.'xml?.attribute;
    string? xmlNamespace = schema?.'xml?.namespace;
    string? xmlPrefix = schema?.'xml?.prefix;
    map<json> output = {};
    if xmlNamespace is string && xmlPrefix is string {
        output["@xmlns:" + xmlPrefix] = xmlNamespace;
        output["#content"] = requestBody;
    } else if xmlNamespace is string {
        output["@xmlns"] = xmlNamespace;
        output["#content"] = requestBody;
    }
    if xmlPrefix is string {
        if childName is string {
            childName = xmlPrefix + ":" + childName;
        } else if refName is string && refName != "" {
            refName = xmlPrefix + ":" + refName;
        } else {
            modifiedParentName = xmlPrefix + ":" + modifiedParentName;
        }
    }
    if xmlAttribute is boolean && xmlAttribute {
        if childName is string {
            childName = "@" + childName;
        } else if refName is string && refName != "" {
            refName = "@" + refName;
        } else {
            modifiedParentName = "@" + modifiedParentName;
        }
    }
    if childName is string {
        if xmlNamespace is string {
            return [output, childName];
        }
        return [requestBody, childName];
    } else if refName is string && refName != "" {
        if xmlNamespace is string {
            return [output, refName];
        }
        return [requestBody, refName];
    } else {
        if xmlNamespace is string {
            return [output, modifiedParentName];
        }
        return [requestBody, modifiedParentName];
    }
}

isolated function visitAnyOfInputSchema(AnyOfInputSchema schema, json requestBody, string parentName) returns [json, string]|error {
    json[] anyOf = from JsonSubSchema element in schema.anyOf
        select check visitSchema(element, requestBody, parentName).ensureType();
    return [anyOf, parentName];
}

isolated function visitAllOfInputSchema(AllOfInputSchema schema, json requestBody, string parentName) returns [json, string]|error {
    json[] allOf = from JsonSubSchema element in schema.allOf
        select check visitSchema(element, requestBody, parentName).ensureType();
    return [allOf, parentName];
}

isolated function visitOneOfInputSchema(OneOfInputSchema schema, json requestBody, string parentName) returns [json, string]|error {
    json[] oneOf = from JsonSubSchema element in schema.oneOf
        select check visitSchema(element, requestBody, parentName).ensureType();
    return [oneOf, parentName];
}

isolated function visitNotInputSchema(NotInputSchema schema, json requestBody, string parentName) returns [json, string]|error {
    json not = check visitSchema(schema.not, requestBody, parentName).ensureType();
    return [not, parentName];
}
