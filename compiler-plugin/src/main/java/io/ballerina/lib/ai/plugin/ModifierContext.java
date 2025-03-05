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

package io.ballerina.lib.ai.plugin;

import io.ballerina.compiler.syntax.tree.AnnotationNode;
import io.ballerina.compiler.syntax.tree.ModuleVariableDeclarationNode;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * Maintains a mapping between annotation nodes and their configurations.
 */
class ModifierContext {
    private final Map<AnnotationNode, ToolAnnotationConfig> annotationConfigMap = new HashMap<>();
    private final Set<ModuleVariableDeclarationNode> moduleLevelAgentDeclaration = new HashSet<>();

    void add(ModuleVariableDeclarationNode node) {
        moduleLevelAgentDeclaration.add(node);
    }

    void add(AnnotationNode node, ToolAnnotationConfig config) {
        annotationConfigMap.put(node, config);
    }

    Map<AnnotationNode, ToolAnnotationConfig> getAnnotationConfigMap() {
        return annotationConfigMap;
    }

    Set<ModuleVariableDeclarationNode> getModuleLevelAgentDeclarations() {
        return moduleLevelAgentDeclaration;
    }
}

record ToolAnnotationConfig(
        String name,
        String description,
        String parameterSchema) {

    public static final String NAME_FIELD_NAME = "name";
    public static final String DESCRIPTION_FIELD_NAME = "description";
    public static final String PARAMETERS_FIELD_NAME = "parameters";

    public String get(String field) {
        return switch (field) {
            case NAME_FIELD_NAME -> name();
            case DESCRIPTION_FIELD_NAME -> description();
            case PARAMETERS_FIELD_NAME -> parameterSchema();
            default -> null;
        };
    }
}
