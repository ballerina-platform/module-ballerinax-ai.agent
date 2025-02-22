// Copyright (c) 2023 WSO2 LLC (http://www.wso2.com).
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/regex;
import wso2/ai.agent;

configurable string openAIToken = ?;

type SearchParams record {|
    string query;
|};

type CalculatorParams record {|
    string expression;
|};

// create two mock tools 
isolated function searchToolMock(*SearchParams params) returns string {
    string query = params.query.trim().toLowerAscii();
    if regex:matches(query, ".*girlfriend.*") {
        return "Camila Morrone";

    } else if regex:matches(query, ".*age.*") {
        return "25 years";
    }
    else {
        return "Can't find. Stop!";
    }
}

isolated function calculatorToolMock(*CalculatorParams params) returns string {
    string expression = params.expression.trim();
    if expression == "25^0.43" {
        return "Answer: 3.991298452658078";
    } else {
        return "Can't compute. Some information is missing";
    }
}

const string DEFAULT_QUERY = "Who is Leo DiCaprio's girlfriend? What is her current age raised to the 0.43 power?";

public function main(string query = DEFAULT_QUERY) returns error? {
    agent:Tool searchTool = {
        name: "Search",
        description: " A search engine. Always use to look up for information.",
        parameters: {
            'properties: {
                "query": {
                    "type": "string",
                    "description": "The search query"
                }
            }
        },
        caller: searchToolMock
    };

    agent:Tool calculatorTool = {
        name: "Calculator",
        description: "Useful for when you need to answer questions about math.",
        parameters: {
            'properties: {
                "expression": {
                    "type": "string",
                    "description": "The expression to be evaluated"
                }
            }
        },
        caller: calculatorToolMock
    };

    agent:ChatGptModel model = check new ({auth: {token: openAIToken}});
    agent:FunctionCallAgent agent = check new (model, searchTool, calculatorTool);
    _ = agent:run(agent, query);
}
