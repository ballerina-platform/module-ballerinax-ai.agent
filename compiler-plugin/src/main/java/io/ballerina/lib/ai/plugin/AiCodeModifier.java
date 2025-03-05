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

import io.ballerina.compiler.syntax.tree.SyntaxKind;
import io.ballerina.projects.DocumentId;
import io.ballerina.projects.ModuleId;
import io.ballerina.projects.plugins.CodeModifier;
import io.ballerina.projects.plugins.CodeModifierContext;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * Analyzes a Ballerina AI tools and report diagnostics, and generates json schema for tools.
 */
public class AiCodeModifier extends CodeModifier {
    private final Map<DocumentId, ModifierContext> modifierContextMap = new HashMap<>();
    private final Set<ModuleId> modulesWithPredefinedInitMethods = new HashSet<>();

    @Override
    public void init(CodeModifierContext codeModifierContext) {
        codeModifierContext.addSyntaxNodeAnalysisTask(new ToolAnnotationAnalysisTask(modifierContextMap),
                SyntaxKind.ANNOTATION);
        codeModifierContext.addSyntaxNodeAnalysisTask(new ModuleLevelAgentAnalysisTask(modifierContextMap),
                SyntaxKind.MODULE_VAR_DECL);
        codeModifierContext.addSyntaxNodeAnalysisTask(new InitFunctionAnalysisTask(modulesWithPredefinedInitMethods),
                SyntaxKind.FUNCTION_DEFINITION);
        codeModifierContext.addSourceModifierTask(new AiSourceModifier(modifierContextMap,
                modulesWithPredefinedInitMethods));
    }
}
