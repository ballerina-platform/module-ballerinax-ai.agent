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

// model default parameters 
const GPT3_5_MODEL_NAME = "gpt-3.5-turbo";
const OBSERVATION_KEY = "Observation";
const DEFAULT_MAX_TOKEN_COUNT = 512;
const DEFAULT_TEMPERATURE = 0.7d;

// openapi
const OPENAPI_COMPONENTS_KEY = "components";
const OPENAPI_PATTERN_DATE = "yyyy-MM-dd";
const OPENAPI_PATTERN_DATE_TIME = "yyyy-MM-dd'T'HH:mm:ssZ";

// openai
const OPENAI_SERVICE_URL = "https://api.openai.com/v1";

// Anthropic
const ANTHROPIC_SERVICE_URL = "https://api.anthropic.com/v1";

// Mistral AI
const MISTRAL_AI_SERVICE_URL = "https://api.mistral.ai/v1";

//agent
const THOUGHT_KEY = "Thought:";
const BACKTICKS = "```";
const DEFAULT_MEMORY_ID = "memoryId";

final string:RegExp FINAL_ANSWER_REGEX = re `^final.?answer`;

const ACTION_KEY = "action";
const ACTION_NAME_KEY = "name";
const ACTION_ARGUEMENTS_KEY = "arguments";
final string:RegExp ACTION_INPUT_REGEX = re `^action.?input`;
const XML_NAMESPACE = "@xmlns";
const XML_CONTENT = "#content";
final string:RegExp XML_MEDIA = re `application/.*xml`;
