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

import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.api.symbols.SymbolKind;
import io.ballerina.compiler.syntax.tree.IdentifierToken;
import io.ballerina.compiler.syntax.tree.ImportDeclarationNode;
import io.ballerina.compiler.syntax.tree.ImportOrgNameNode;
import io.ballerina.compiler.syntax.tree.ModulePartNode;
import io.ballerina.compiler.syntax.tree.ModuleVariableDeclarationNode;
import io.ballerina.compiler.syntax.tree.Node;
import io.ballerina.compiler.syntax.tree.QualifiedNameReferenceNode;
import io.ballerina.compiler.syntax.tree.SeparatedNodeList;
import io.ballerina.compiler.syntax.tree.SyntaxKind;
import io.ballerina.compiler.syntax.tree.Token;
import io.ballerina.compiler.syntax.tree.TypeDescriptorNode;
import io.ballerina.projects.DocumentId;
import io.ballerina.projects.plugins.AnalysisTask;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;

import java.util.Map;
import java.util.Optional;

import static io.ballerina.lib.ai.plugin.Utils.BALLERINAX_ORG;

/**
 * Analyzes a Ballerina AI Agent defined at module level.
 */
class ModuleLevelAgentAnalysisTask implements AnalysisTask<SyntaxNodeAnalysisContext> {
    private static final String AGENT_CLASS_NAME = "Agent";
    private static final String AGENT_MODULE_NAME = "agent";
    private static final String AI_MODULE_NAME = "ai";
    private final Map<DocumentId, ModifierContext> modifierContextMap;

    public ModuleLevelAgentAnalysisTask(Map<DocumentId, ModifierContext> modifierContextMap) {
        this.modifierContextMap = modifierContextMap;
    }

    @Override
    public void perform(SyntaxNodeAnalysisContext context) {
        Optional<Symbol> symbol = context.semanticModel().symbol(context.node());
        if (symbol.isEmpty() || symbol.get().kind() != SymbolKind.VARIABLE) {
            return;
        }

        ModuleVariableDeclarationNode moduleVariableDeclarationNode = (ModuleVariableDeclarationNode) context.node();
        TypeDescriptorNode typeDescriptorNode = moduleVariableDeclarationNode.typedBindingPattern().typeDescriptor();
        if (typeDescriptorNode.kind() != SyntaxKind.QUALIFIED_NAME_REFERENCE) {
            return;
        }
        QualifiedNameReferenceNode nameReferenceNode = (QualifiedNameReferenceNode) typeDescriptorNode;
        IdentifierToken identifier = nameReferenceNode.identifier();
        Token modulePrefix = nameReferenceNode.modulePrefix();
        String agentModulePrefix = getAgentModuleNamePrefix(context);
        if (!identifier.text().equals(AGENT_CLASS_NAME)
                || !modulePrefix.text().equals(agentModulePrefix)
                || moduleVariableDeclarationNode.initializer().isEmpty()) {
            return;
        }
        addToModifierContext(context, moduleVariableDeclarationNode);
    }

    private void addToModifierContext(SyntaxNodeAnalysisContext context,
                                      ModuleVariableDeclarationNode moduleVariableDeclarationNode) {
        this.modifierContextMap.computeIfAbsent(context.documentId(), document -> new ModifierContext())
                .add(moduleVariableDeclarationNode);
    }

    private String getAgentModuleNamePrefix(SyntaxNodeAnalysisContext context) {
        Node rootNode = context.syntaxTree().rootNode();
        if (rootNode.kind() == SyntaxKind.MODULE_PART) {
            ModulePartNode modulePartNode = (ModulePartNode) rootNode;
            Optional<ImportDeclarationNode> agentModuleImport = modulePartNode.imports().stream()
                    .filter(importDeclarationNode -> {
                        SeparatedNodeList<IdentifierToken> moduleName = importDeclarationNode.moduleName();
                        Optional<ImportOrgNameNode> orgNameOpt = importDeclarationNode.orgName();
                        return moduleName.size() > 1
                                && moduleName.get(0).text().contains(AI_MODULE_NAME)
                                && orgNameOpt.isPresent()
                                && orgNameOpt.get().orgName().text().equals(BALLERINAX_ORG)
                                && moduleName.get(1).text().contains(AGENT_MODULE_NAME);
                    })
                    .findFirst();

            if (agentModuleImport.isEmpty() || agentModuleImport.get().prefix().isEmpty()) {
                return AGENT_MODULE_NAME;
            }
            return agentModuleImport.get().prefix().get().prefix().text().trim();
        }
        return AGENT_MODULE_NAME;
    }
}
