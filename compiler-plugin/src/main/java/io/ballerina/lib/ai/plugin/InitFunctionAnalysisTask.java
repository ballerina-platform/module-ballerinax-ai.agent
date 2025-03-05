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

import io.ballerina.compiler.api.symbols.FunctionSymbol;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.api.symbols.SymbolKind;
import io.ballerina.projects.ModuleId;
import io.ballerina.projects.plugins.AnalysisTask;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;

import java.util.Optional;
import java.util.Set;

/**
 * Analyzes a Ballerina module init function.
 */
class InitFunctionAnalysisTask implements AnalysisTask<SyntaxNodeAnalysisContext> {
    private static final String INIT_METHOD_NAME = "init";
    Set<ModuleId> modulesWithPredefinedInitMethods;

    public InitFunctionAnalysisTask(Set<ModuleId> modulesWithInitMethod) {
        this.modulesWithPredefinedInitMethods = modulesWithInitMethod;
    }

    @Override
    public void perform(SyntaxNodeAnalysisContext context) {
        Optional<Symbol> symbol = context.semanticModel().symbol(context.node());
        if (symbol.isEmpty()) {
            return;
        }
        if (symbol.get().kind() != SymbolKind.FUNCTION) {
            return;
        }
        FunctionSymbol functionSymbol = (FunctionSymbol) symbol.get();
        if (functionSymbol.getName().isEmpty() || !functionSymbol.getName().get().equals(INIT_METHOD_NAME)) {
            return;
        }
        modulesWithPredefinedInitMethods.add(context.documentId().moduleId());
    }
}
