/*
 * Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.lib.ai.plugin.diagnostics;

/**
 * Compilation error messages used in Ballerina AI package compiler plugin.
 */
public enum DiagnosticMessage {
    ERROR_101("failed to generate the parameter schema definition for the function ''{0}''." +
            " Specify the parameter schema manually using the `@ai:Tool` annotation's parameter field."),
    ERROR_102("the function ''{0}'' has a parameter ''{1}'' that is not a subtype of `anydata`." +
            " Only `anydata` types are allowed in a tool."),
    ERROR_103("the function ''{0}'' has a parameter ''{1}'' that includes the type xml," +
            " either as its type or within its fields, which is not supported by the tool."),
    ERROR_104("the return type of the function ''{0}'' is not a subtype of `anydata|error`." +
            " The tool must return a value of type `anydata`.");

    private final String message;

    DiagnosticMessage(String message) {
        this.message = message;
    }

    public String getMessage() {
        return this.message;
    }
}
