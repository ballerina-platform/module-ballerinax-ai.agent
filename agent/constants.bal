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

// model default parameters 
const string DEFAULT_MODEL_NAME = "text-davinci-003";
const string OBSERVATION_KEY = "Observation";
const int COMPLETION_TOKEN_MIN_LIMIT = 128;
const decimal DEFAULT_TEMPERATURE = 0.7;

// counters 
const int FINAL_THOUGHT_LINE_COUNT = 2;
const int REGULAR_THOUGHT_LINE_COUNT = 3;

// keywords 
const string ACTION_KEYWORD = "tool";

// openapi
const string OPENAPI_KEY = "openapi";
const string OPENAPI_SERVER_KEY = "servers";
const string OPENAPI_PATHS_KEY = "paths";
const string OPENAPI_COMPONENTS_KEY = "components";
const string OPENAPI_SUMMERY_KEY = "summary";
const string OPENAPI_OPERATION_ID_KEY = "operationId";
const string OPENAPI_REQUEST_BODY_KEY = "requestBody";
const string OPENAPI_CONTENT_KEY = "content";
const string OPENAPI_JSON_CONTENT_KEY = "application/json";
const string OPENAPI_SCHEMA_KEY = "schema";
const string OPENAPI_REF_KEY = "$ref";
const string OPENAPI_ONE_OF_KEY = "oneOf";
const string OPENAPI_ALL_OF_KEY = "allOf";
const string OPENAPI_ANY_OF_KEY = "anyOf";
const string OPENAPI_NOT_KEY = "not";
const string OPENAPI_TYPE_KEY = "type";
const string OPENAPI_PROPERTIES_KEY = "properties";
const string OPENAPI_ITEMS_KEY = "items";
const string OPENAPI_OBJECT_TYPE = "object";
const string OPENAPI_ARRAY_TYPE = "array";
const string OPENAPI_DEFAULT_VALUE_KEY = "default";

