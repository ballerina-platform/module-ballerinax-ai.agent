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
import io.ballerina.compiler.syntax.tree.FunctionDefinitionNode;
import io.ballerina.compiler.syntax.tree.MappingConstructorExpressionNode;
import io.ballerina.compiler.syntax.tree.MappingFieldNode;
import io.ballerina.compiler.syntax.tree.MetadataNode;
import io.ballerina.compiler.syntax.tree.ModuleMemberDeclarationNode;
import io.ballerina.compiler.syntax.tree.ModulePartNode;
import io.ballerina.compiler.syntax.tree.ModuleVariableDeclarationNode;
import io.ballerina.compiler.syntax.tree.Node;
import io.ballerina.compiler.syntax.tree.NodeFactory;
import io.ballerina.compiler.syntax.tree.NodeList;
import io.ballerina.compiler.syntax.tree.NodeParser;
import io.ballerina.compiler.syntax.tree.QualifiedNameReferenceNode;
import io.ballerina.compiler.syntax.tree.SeparatedNodeList;
import io.ballerina.compiler.syntax.tree.SpecificFieldNode;
import io.ballerina.compiler.syntax.tree.SyntaxTree;
import io.ballerina.compiler.syntax.tree.Token;
import io.ballerina.projects.DocumentId;
import io.ballerina.projects.Module;
import io.ballerina.projects.ModuleId;
import io.ballerina.projects.plugins.ModifierTask;
import io.ballerina.projects.plugins.SourceModifierContext;
import io.ballerina.tools.text.TextDocument;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import static io.ballerina.compiler.syntax.tree.SyntaxKind.CLOSE_BRACE_TOKEN;
import static io.ballerina.compiler.syntax.tree.SyntaxKind.COLON_TOKEN;
import static io.ballerina.compiler.syntax.tree.SyntaxKind.COMMA_TOKEN;
import static io.ballerina.compiler.syntax.tree.SyntaxKind.EQUAL_TOKEN;
import static io.ballerina.compiler.syntax.tree.SyntaxKind.FUNCTION_DEFINITION;
import static io.ballerina.compiler.syntax.tree.SyntaxKind.MODULE_VAR_DECL;
import static io.ballerina.compiler.syntax.tree.SyntaxKind.OPEN_BRACE_TOKEN;
import static io.ballerina.compiler.syntax.tree.SyntaxKind.QUALIFIED_NAME_REFERENCE;
import static io.ballerina.compiler.syntax.tree.SyntaxKind.SEMICOLON_TOKEN;
import static io.ballerina.compiler.syntax.tree.SyntaxKind.SPECIFIC_FIELD;
import static io.ballerina.lib.ai.plugin.ToolAnnotationConfig.DESCRIPTION_FIELD_NAME;
import static io.ballerina.lib.ai.plugin.ToolAnnotationConfig.NAME_FIELD_NAME;
import static io.ballerina.lib.ai.plugin.ToolAnnotationConfig.PARAMETERS_FIELD_NAME;

/**
 * Modifies the AI tool annotations with the generated tool configuration.
 */
class AiSourceModifier implements ModifierTask<SourceModifierContext> {
    private static final String EMPTY_STRING = "";
    private final Map<DocumentId, ModifierContext> modifierContextMap;
    private final Set<ModuleId> modulesWithPredefinedInitMethods;
    private final Set<ModuleId> modulesWithDesugaredAgentsWithInitMethod = new HashSet<>();

    AiSourceModifier(Map<DocumentId, ModifierContext> modifierContextMap,
                     Set<ModuleId> modulesWithPredefinedInitMethods) {
        this.modifierContextMap = modifierContextMap;
        this.modulesWithPredefinedInitMethods = modulesWithPredefinedInitMethods;
    }

    @Override
    public void modify(SourceModifierContext context) {
        for (Map.Entry<DocumentId, ModifierContext> entry : modifierContextMap.entrySet()) {
            modifyDocumentWithTools(context, entry.getKey(), entry.getValue());
        }
    }

    private void modifyDocumentWithTools(SourceModifierContext context, DocumentId documentId,
                                         ModifierContext modifierContext) {
        Module module = context.currentPackage().module(documentId.moduleId());
        ModulePartNode rootNode = module.document(documentId).syntaxTree().rootNode();
        ModulePartNode updatedRoot = modifyModulePartRoot(rootNode, modifierContext, documentId);
        updateDocument(context, module, documentId, updatedRoot);
    }

    private ModulePartNode modifyModulePartRoot(ModulePartNode modulePartNode,
                                                ModifierContext modifierContext, DocumentId documentId) {
        List<ModuleMemberDeclarationNode> modifiedMembers = getModifiedModuleMembers(modulePartNode.members(),
                modifierContext, documentId);
        return modulePartNode.modify().withMembers(NodeFactory.createNodeList(modifiedMembers)).apply();
    }

    private List<ModuleMemberDeclarationNode> getModifiedModuleMembers(NodeList<ModuleMemberDeclarationNode> members,
            ModifierContext modifierContext,
            DocumentId documentId) {
        Map<AnnotationNode, AnnotationNode> modifiedAnnotations = getModifiedAnnotations(modifierContext);
        Set<ModuleVariableDeclarationNode> agentDeclarations = modifierContext.getModuleLevelAgentDeclarations();
        List<ModuleMemberDeclarationNode> modifiedMembers = new ArrayList<>();

        for (ModuleMemberDeclarationNode member : members) {
            modifiedMembers.add(getModifiedModuleMember(member, modifiedAnnotations, agentDeclarations));
        }
        ModuleId moduleId = documentId.moduleId();
        if (!modulesWithPredefinedInitMethods.contains(moduleId)
                && !modulesWithDesugaredAgentsWithInitMethod.contains(moduleId)) {
            ModuleMemberDeclarationNode initFunctionDeclaration = desugarAgentsWithinInitFunction(moduleId);
            modulesWithDesugaredAgentsWithInitMethod.add(moduleId);
            modifiedMembers.add(initFunctionDeclaration);
        }
        return modifiedMembers;
    }

    private ModuleMemberDeclarationNode desugarAgentsWithinInitFunction(ModuleId moduleId) {
        Set<DocumentId> documentIds = this.modifierContextMap
                .keySet().stream()
                .filter(doc -> doc.moduleId().equals(moduleId)).collect(Collectors.toSet());
        Stream<ModifierContext> modifierContextStream = this.modifierContextMap.entrySet().stream()
                .filter(entry -> documentIds.contains(entry.getKey())).map(Map.Entry::getValue);
        List<ModuleVariableDeclarationNode> agentDeclarations = modifierContextStream
                .map(ModifierContext::getModuleLevelAgentDeclarations).flatMap(Collection::stream).toList();
        String agentInitializationSourceCode = agentDeclarations.stream().map(Node::toSourceCode)
                .map(code -> code.replaceFirst(".*Agent", EMPTY_STRING))
                .collect(Collectors.joining(EMPTY_STRING));
        return NodeParser.parseModuleMemberDeclaration("function init() returns error? {"
                + agentInitializationSourceCode + "}");
    }

    /**
     * Retrieves a map of modified annotations based on the provided modifier context.
     * <p>
     * This method iterates through the annotation configuration map from the
     * given {@link ModifierContext}, applies modifications to each annotation using
     * the {@link #getModifiedAnnotation} method, and returns a new map with the
     * original annotations as keys and the modified annotations as values.
     *
     * @param modifierContext the context containing annotation configurations to be modified
     * @return a map where the keys are the original {@link AnnotationNode} objects
     * and the values are the modified {@link AnnotationNode} objects
     */
    private Map<AnnotationNode, AnnotationNode> getModifiedAnnotations(ModifierContext modifierContext) {
        Map<AnnotationNode, AnnotationNode> updatedAnnotationMap = new HashMap<>();
        for (Map.Entry<AnnotationNode, ToolAnnotationConfig> entry : modifierContext
                .getAnnotationConfigMap().entrySet()) {
            updatedAnnotationMap.put(entry.getKey(), getModifiedAnnotation(entry.getKey(), entry.getValue()));
        }
        return updatedAnnotationMap;
    }

    private AnnotationNode getModifiedAnnotation(AnnotationNode targetNode, ToolAnnotationConfig config) {
        // Handle the following cases separately to preserve line numbers.
        // Otherwise, other compiler errors may have altered line numbers, leading to confusion.
        if (targetNode.annotValue().isEmpty()) {
            // Handle the case where the annotation is empty (e.g., @agent:Tool).
            return handleAnnotationWithoutMappingConstructor(targetNode, config);
        }
        // Handle the case where the annotation has existing values (e.g., @agent:Tool{...}).
        return handleAnnotationWithMappingConstructor(targetNode, config);
    }

    private AnnotationNode handleAnnotationWithoutMappingConstructor(AnnotationNode targetNode,
                                                                     ToolAnnotationConfig config) {
        String mappingConstructorExpression = generateConfigMappingConstructor(config);
        MappingConstructorExpressionNode mappingConstructorNode = (MappingConstructorExpressionNode) NodeParser
                .parseExpression(mappingConstructorExpression);

        Node annotationReference = targetNode.annotReference();
        if (annotationReference.kind() == QUALIFIED_NAME_REFERENCE) {
            QualifiedNameReferenceNode qualifiedNameReferenceNode = (QualifiedNameReferenceNode) annotationReference;
            String identifier = qualifiedNameReferenceNode.identifier().text().replaceAll("\\R", EMPTY_STRING);
            String modulePrefix = qualifiedNameReferenceNode.modulePrefix().text();
            annotationReference = NodeFactory.createQualifiedNameReferenceNode(
                    NodeFactory.createIdentifierToken(modulePrefix),
                    NodeFactory.createToken(COLON_TOKEN),
                    NodeFactory.createIdentifierToken(identifier)
            );
            Token closeBraceTokenWithNewLine = NodeFactory.createToken(
                    CLOSE_BRACE_TOKEN,
                    NodeFactory.createEmptyMinutiaeList(),
                    NodeFactory.createMinutiaeList(
                            NodeFactory.createEndOfLineMinutiae(System.lineSeparator())));
            mappingConstructorNode = mappingConstructorNode.modify().withCloseBrace(closeBraceTokenWithNewLine).apply();
        }
        return NodeFactory.createAnnotationNode(targetNode.atToken(), annotationReference, mappingConstructorNode);
    }

    private String generateConfigMappingConstructor(ToolAnnotationConfig config) {
        return generateConfigMappingConstructor(config, OPEN_BRACE_TOKEN.stringValue(),
                CLOSE_BRACE_TOKEN.stringValue());
    }

    private String generateConfigMappingConstructor(ToolAnnotationConfig config, String openBraceSource,
                                                    String closeBraceSource) {
        String name = config.name().replaceAll("\\R", " ");
        return openBraceSource + String.format("name:%s,description:%s,parameters:%s",
                name,
                config.description() != null ? config.description().replaceAll("\\R", " ") : name,
                config.parameterSchema()) + closeBraceSource;
    }

    private AnnotationNode handleAnnotationWithMappingConstructor(AnnotationNode targetNode,
                                                                  ToolAnnotationConfig config) {
        MappingConstructorExpressionNode mappingConstructorNode = getMappingConstructorExpressionNode(targetNode);
        Set<String> existingFieldNames = extractFieldNames(mappingConstructorNode.fields());
        List<MappingFieldNode> missingFields = getMissingFields(existingFieldNames, config);

        String missingFieldSourceCode = generateMissingFieldSourceCode(missingFields);
        if (missingFieldSourceCode == null) {
            return targetNode;
        }
        String annotationSourceCode = targetNode.toSourceCode();
        String modifiedAnnotationSourceCode = getModifiedAnnotationSourceCode(annotationSourceCode,
                missingFieldSourceCode);
        return NodeParser.parseAnnotation(modifiedAnnotationSourceCode);
    }

    private Set<String> extractFieldNames(SeparatedNodeList<MappingFieldNode> fields) {
        return fields.stream()
                .filter(field -> field.kind() == SPECIFIC_FIELD)
                .map(field -> (SpecificFieldNode) field)
                .map(specificFieldNode -> specificFieldNode.fieldName().toSourceCode().trim())
                .collect(Collectors.toSet());
    }

    private String generateMissingFieldSourceCode(List<MappingFieldNode> missingFields) {
        return missingFields.isEmpty() ? null :
                missingFields.stream()
                        .map(Node::toSourceCode)
                        .collect(Collectors.joining(COMMA_TOKEN.stringValue()));
    }

    private static String getModifiedAnnotationSourceCode(String annotationSourceCode,
                                                          String missingFieldSourceCode) {
        int closeBraceTokenIndex = annotationSourceCode.lastIndexOf(CLOSE_BRACE_TOKEN.stringValue());
        String sourceBeforeCloseBrace = annotationSourceCode.substring(0, closeBraceTokenIndex);
        String sourceAfterCloseBrace = annotationSourceCode.substring(closeBraceTokenIndex);

        String endsWithBracesRegex = ".*\\{\\s*$";
        if (sourceBeforeCloseBrace.matches(endsWithBracesRegex)) {
            return sourceBeforeCloseBrace + missingFieldSourceCode + sourceAfterCloseBrace;
        }
        return sourceBeforeCloseBrace + COMMA_TOKEN.stringValue() + missingFieldSourceCode + sourceAfterCloseBrace;
    }

    private MappingConstructorExpressionNode getMappingConstructorExpressionNode(AnnotationNode targetNode) {
        @SuppressWarnings("OptionalGetWithoutIsPresent")
        MappingConstructorExpressionNode mappingConstructorExpressionNode = targetNode.annotValue().get();
        return mappingConstructorExpressionNode;
    }

    private List<MappingFieldNode> getMissingFields(Set<String> existingFieldNames, ToolAnnotationConfig config) {
        List<String> requiredFields = List.of(NAME_FIELD_NAME, DESCRIPTION_FIELD_NAME, PARAMETERS_FIELD_NAME);
        List<MappingFieldNode> missingFields = new ArrayList<>();
        for (String fieldName : requiredFields) {
            if (!existingFieldNames.contains(fieldName)) {
                missingFields.add(NodeFactory.createSpecificFieldNode(
                        null,
                        NodeFactory.createIdentifierToken(fieldName),
                        NodeFactory.createToken(COLON_TOKEN),
                        NodeParser.parseExpression(config.get(fieldName))
                ));
            }
        }
        return missingFields;
    }

    private ModuleMemberDeclarationNode getModifiedModuleMember(ModuleMemberDeclarationNode member,
                                                                Map<AnnotationNode, AnnotationNode> modifiedAnnotations,
                                                                Set<ModuleVariableDeclarationNode> agentDeclarations) {
        if (member.kind() == FUNCTION_DEFINITION) {
            return modifyFunction((FunctionDefinitionNode) member, modifiedAnnotations);
        }
        if (member.kind() == MODULE_VAR_DECL) {
            return modifyVariableDeclaration((ModuleVariableDeclarationNode) member, agentDeclarations);
        }
        return member;
    }

    private ModuleMemberDeclarationNode modifyVariableDeclaration(
            ModuleVariableDeclarationNode member, Set<ModuleVariableDeclarationNode> agentDeclarations) {
        if (!agentDeclarations.contains(member)) {
            return member;
        }
        String sourceCode = member.toSourceCode();
        int numberOfNewLines = sourceCode.length() - sourceCode.replaceAll("\\R", EMPTY_STRING).length();
        String modifiedSource = sourceCode.split(EQUAL_TOKEN.stringValue())[0].trim() + SEMICOLON_TOKEN.stringValue()
                + System.lineSeparator().repeat(numberOfNewLines);
        return NodeParser.parseModuleMemberDeclaration(modifiedSource);
    }

    private FunctionDefinitionNode modifyFunction(FunctionDefinitionNode functionNode,
                                                  Map<AnnotationNode, AnnotationNode> modifiedAnnotations) {
        if (functionNode.metadata().isEmpty()) {
            return functionNode;
        }
        MetadataNode modifiedMetadata = modifyMetadata(functionNode.metadata().get(), modifiedAnnotations);
        return functionNode.modify().withMetadata(modifiedMetadata).apply();
    }

    private MetadataNode modifyMetadata(MetadataNode metadata,
                                        Map<AnnotationNode, AnnotationNode> modifiedAnnotations) {
        List<AnnotationNode> updatedAnnotations = new ArrayList<>();
        for (AnnotationNode annotation : metadata.annotations()) {
            updatedAnnotations.add(modifiedAnnotations.getOrDefault(annotation, annotation));
        }
        return metadata.modify().withAnnotations(NodeFactory.createNodeList(updatedAnnotations)).apply();
    }

    private void updateDocument(SourceModifierContext context, Module module, DocumentId documentId,
                                ModulePartNode updatedRoot) {
        SyntaxTree syntaxTree = module.document(documentId).syntaxTree().modifyWith(updatedRoot);
        TextDocument textDocument = syntaxTree.textDocument();
        if (module.documentIds().contains(documentId)) {
            context.modifySourceFile(textDocument, documentId);
        } else {
            context.modifyTestSourceFile(textDocument, documentId);
        }
    }
}
