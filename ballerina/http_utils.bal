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

import ballerina/http;
import ballerina/lang.regexp;
import ballerina/log;
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
    if contentLength == 0 || code == 204 || code == 205 {
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

isolated function getContentLength(http:Response response) returns int|error? {
    string|error contentLengthHeader = response.getHeader(mime:CONTENT_LENGTH);
    if contentLengthHeader is error || contentLengthHeader == "" {
        return;
    }
    return int:fromString(contentLengthHeader);
}

isolated function getRequestMessage(string? mediaType, HttpInput httpInput) returns json|xml|error {
    json|xml message;
    if mediaType is string && mediaType.matches(XML_MEDIA) {
        message = check xmldata:fromJson(httpInput?.requestBody);
    } else {
        message = httpInput?.requestBody;
    }
    return message;
}

isolated function getHttpParameters(map<HttpTool> httpTools, string httpMethod, HttpInput httpInput, boolean writeOperation) returns HttpParameters|error {
    HttpTool httpTool = httpTools.get(string `${httpInput.path.toString()}:${httpMethod}`);
    string path = check getParamEncodedPath(httpTool, httpInput?.parameters);
    log:printDebug(string `HTTP ${httpMethod} ${path} ${httpInput?.requestBody.toString()}`);
    if httpInput?.requestBody is () {
        return {path: path, message: ()};
    }
    json|xml message = check getRequestMessage(httpTool.requestBody?.mediaType, httpInput);
    return {path: path, message: message};
}
