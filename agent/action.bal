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

import ballerina/log;

public type InputSchema record {
};

public type Action record {|
    string name;
    string description;
    InputSchema? inputs = ();
    function caller;
|};

public type generatedOutput record {|
    string actionNames;
    string actionDescriptions;
|};

class ActionStore {
    map<Action> actions;
    string actionInstructions;

    function init() {
        self.actions = {};
        self.actionInstructions = "";
    }

    # Register actions to the agent. 
    # These actions will be by the LLM to perform tasks 
    #
    # + actions - A list of actions that are available to the LLM
    function registerActions(Action... actions) {
        foreach Action action in actions {
            self.actions[action.name] = action;
        }
    }

    # execute the action decided by the LLM
    #
    # + actionName - Name of the action to be executed
    # + inputs - Inputs to the action
    # + return - Result of the action execution or an error if action execution fails
    function executeAction(string actionName, json? inputs) returns string|error {

        if !self.actions.hasKey(actionName) {
            log:printWarn("Failed to execute the unknown action: " + actionName);
            return string `You don't have access to the ${ACTION_KEYWORD}: ${actionName}. Try a different approach`;
        }

        function caller = self.actions.get(actionName).caller;
        any|error observation;
        if inputs is null {
            observation = function:call(caller);
        } else {
            map<json> & readonly actionParams = check inputs.fromJsonWithType();
            if actionParams.length() > 0 {
                observation = function:call(caller, actionParams);
            } else {
                observation = function:call(caller);
            }
        }

        if observation is error {
            return observation.message();
        }
        return observation.toString();
    }

    # Generate descriptions for the actions registered
    # + return - Return a record with action names and descriptions
    function generateDescriptions() returns generatedOutput {
        string[] actionDescriptionList = [];
        string[] actionNameList = [];
        foreach Action action in self.actions {
            actionNameList.push(action.name);
            actionDescriptionList.push(self.buildActionDescription(action));
        }
        string actionDescriptions = string:'join("\n", ...actionDescriptionList);
        string actionNames = actionNameList.toString();
        return {actionNames: actionNames, actionDescriptions: actionDescriptions};
    }

    # Build description for an action to generate prompts to the LLMs
    #
    # + action - Action requires prompt decription
    # + return - Prompt description generated for the action
    private function buildActionDescription(Action action) returns string {
        if action.inputs == null { // case for functions with zero parameters 
            return string `${action.name}: ${action.description}. Parameters should be empty {}`;
        }
        return string `${action.name}: ${action.description}. Parameters to this ${ACTION_KEYWORD} should be in the format of ${action.inputs.toString()}`;
    }

    function mergeActionStore(ActionStore actionStore) {
        foreach Action action in actionStore.actions {
            self.actions[action.name] = action;
        }
    }
}
