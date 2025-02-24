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
import io.ballerina.compiler.syntax.tree.Node;
import io.ballerina.compiler.syntax.tree.NodeFactory;
import io.ballerina.compiler.syntax.tree.NodeList;
import io.ballerina.compiler.syntax.tree.NodeParser;
import io.ballerina.compiler.syntax.tree.QualifiedNameReferenceNode;
import io.ballerina.compiler.syntax.tree.SeparatedNodeList;
import io.ballerina.compiler.syntax.tree.SpecificFieldNode;
import io.ballerina.compiler.syntax.tree.SyntaxKind;
import io.ballerina.compiler.syntax.tree.SyntaxTree;
import io.ballerina.compiler.syntax.tree.Token;
import io.ballerina.projects.DocumentId;
import io.ballerina.projects.Module;
import io.ballerina.projects.plugins.ModifierTask;
import io.ballerina.projects.plugins.SourceModifierContext;
import io.ballerina.tools.text.TextDocument;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static io.ballerina.lib.ai.plugin.ToolAnnotationAnalysisTask.DESCRIPTION_FIELD_NAME;
import static io.ballerina.lib.ai.plugin.ToolAnnotationAnalysisTask.NAME_FIELD_NAME;
import static io.ballerina.lib.ai.plugin.ToolAnnotationAnalysisTask.PARAMETERS_FIELD_NAME;

/**
 * Modifies the AI tool annotations with the generated tool configuration.
 */
class AiSourceModifier implements ModifierTask<SourceModifierContext> {
    private final Map<DocumentId, ModifierContext> modifierContextMap;

    AiSourceModifier(Map<DocumentId, ModifierContext> modifierContextMap) {
        this.modifierContextMap = modifierContextMap;
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
        ModulePartNode updatedRoot = modifyModulePartRoot(rootNode, modifierContext);
        updateDocument(context, module, documentId, updatedRoot);
    }

    private ModulePartNode modifyModulePartRoot(ModulePartNode modulePartNode, ModifierContext modifierContext) {
        List<ModuleMemberDeclarationNode> modifiedMembers = getModifiedModuleMembers(modulePartNode.members(),
                modifierContext);
        return modulePartNode.modify().withMembers(NodeFactory.createNodeList(modifiedMembers)).apply();
    }

    private List<ModuleMemberDeclarationNode> getModifiedModuleMembers(NodeList<ModuleMemberDeclarationNode> members,
                                                                       ModifierContext modifierContext) {
        Map<AnnotationNode, AnnotationNode> modifiedAnnotations = getModifiedAnnotations(modifierContext);
        List<ModuleMemberDeclarationNode> modifiedMembers = new ArrayList<>();
        for (ModuleMemberDeclarationNode member : members) {
            modifiedMembers.add(getModifiedModuleMember(member, modifiedAnnotations));
        }
        return modifiedMembers;
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
            // Handle the case where the annotation is empty (e.g., @ai:Tool).
            return handleAnnotationWithoutMappingConstructor(targetNode, config);
        }
        // Handle the case where the annotation has existing values (e.g., @ai:Tool{...}).
        return handleAnnotationWithMappingConstructor(targetNode, config);
    }

    private AnnotationNode handleAnnotationWithoutMappingConstructor(AnnotationNode targetNode,
                                                                     ToolAnnotationConfig config) {
        String mappingConstructorExpression = generateConfigMappingConstructor(config);
        MappingConstructorExpressionNode mappingConstructorNode = (MappingConstructorExpressionNode) NodeParser
                .parseExpression(mappingConstructorExpression);

        Node annotationReference = targetNode.annotReference();
        if (annotationReference.kind() == SyntaxKind.QUALIFIED_NAME_REFERENCE) {
            QualifiedNameReferenceNode qualifiedNameReferenceNode = (QualifiedNameReferenceNode) annotationReference;
            String identifier = qualifiedNameReferenceNode.identifier().text().replaceAll("\\R", "");
            String modulePrefix = qualifiedNameReferenceNode.modulePrefix().text();
            annotationReference = NodeFactory.createQualifiedNameReferenceNode(
                    NodeFactory.createIdentifierToken(modulePrefix),
                    NodeFactory.createToken(SyntaxKind.COLON_TOKEN),
                    NodeFactory.createIdentifierToken(identifier)
            );
            Token closeBraceTokenWithNewLine = NodeFactory.createToken(
                    SyntaxKind.CLOSE_BRACE_TOKEN,
                    NodeFactory.createEmptyMinutiaeList(),
                    NodeFactory.createMinutiaeList(
                            NodeFactory.createEndOfLineMinutiae(System.lineSeparator())));
            mappingConstructorNode = mappingConstructorNode.modify().withCloseBrace(closeBraceTokenWithNewLine).apply();
        }
        return NodeFactory.createAnnotationNode(targetNode.atToken(), annotationReference, mappingConstructorNode);
    }

    private String generateConfigMappingConstructor(ToolAnnotationConfig config) {
        return String.format("{name:%s,description:%s,parameters:%s}",
                config.name(),
                config.description() != null ? config.description() : config.name(),
                config.parameterSchema());
    }

    private AnnotationNode handleAnnotationWithMappingConstructor(AnnotationNode targetNode,
                                                                  ToolAnnotationConfig config) {
        MappingConstructorExpressionNode mappingConstructorNode = getMappingConstructorExpressionNode(targetNode);
        SeparatedNodeList<MappingFieldNode> fields = mappingConstructorNode.fields();
        // Check if the existing fields are empty (.ie, @ai:Tool{}).
        if (fields.isEmpty()) {
            return handleAnnotationWithEmptyMappingConstructor(targetNode, config);
        }
        return handleAnnotationHavingFields(targetNode, config);
    }

    private MappingConstructorExpressionNode getMappingConstructorExpressionNode(AnnotationNode targetNode) {
        @SuppressWarnings("OptionalGetWithoutIsPresent")
        MappingConstructorExpressionNode mappingConstructorExpressionNode = targetNode.annotValue().get();
        return mappingConstructorExpressionNode;
    }

    private AnnotationNode handleAnnotationWithEmptyMappingConstructor(AnnotationNode targetNode,
                                                                       ToolAnnotationConfig config) {
        String mappingConstructorExpression = generateConfigMappingConstructor(config);
        MappingConstructorExpressionNode expressionNode = (MappingConstructorExpressionNode) NodeParser
                .parseExpression(mappingConstructorExpression);
        MappingConstructorExpressionNode targetMappingConstructorNode = getMappingConstructorExpressionNode(targetNode);
        MappingConstructorExpressionNode modifiedMapping = targetMappingConstructorNode.modify()
                .withFields(expressionNode.fields()).apply();
        return targetNode.modify().withAnnotValue(modifiedMapping).apply();
    }

    private AnnotationNode handleAnnotationHavingFields(AnnotationNode targetNode, ToolAnnotationConfig config) {
        MappingConstructorExpressionNode mappingConstructorNode = getMappingConstructorExpressionNode(targetNode);

        LinkedHashMap<String, MappingFieldNode> existingFields = new LinkedHashMap<>();
        String lastFieldName = "";
        for (MappingFieldNode field : mappingConstructorNode.fields()) {
            if (field.kind() == SyntaxKind.SPECIFIC_FIELD) {
                SpecificFieldNode specificFieldNode = (SpecificFieldNode) field;
                String fieldName = specificFieldNode.fieldName().toSourceCode().trim();
                lastFieldName = fieldName;
                existingFields.put(fieldName, specificFieldNode);
            }
        }
        String mappingConstructorExpression = buildMappingConstructorExpression(config, existingFields, lastFieldName);
        MappingConstructorExpressionNode modifiedMappingConstructorNode = (MappingConstructorExpressionNode) NodeParser
                .parseExpression(mappingConstructorExpression);
        return targetNode.modify().withAnnotValue(modifiedMappingConstructorNode).apply();
    }

    private String buildMappingConstructorExpression(ToolAnnotationConfig config,
                                                     LinkedHashMap<String, MappingFieldNode> existingFields,
                                                     String lastFieldName) {
        boolean lastFieldEndsWithLineBreak = Utils.endsWithNewline(existingFields.get(lastFieldName).toSourceCode());
        LinkedHashMap<String, MappingFieldNode> modifiedFields = new LinkedHashMap<>(existingFields);
        addMissingConfigFields(modifiedFields, config);

        StringBuilder mappingConstructorBuilder = new StringBuilder(SyntaxKind.OPEN_BRACE_TOKEN.stringValue());
        for (Map.Entry<String, MappingFieldNode> entry : modifiedFields.entrySet()) {
            if (mappingConstructorBuilder.length() > 1) {
                mappingConstructorBuilder.append(SyntaxKind.COMMA_TOKEN.stringValue());
            }
            String sourceCode = entry.getKey().equals(lastFieldName) && lastFieldEndsWithLineBreak
                    ? Utils.removeLastNewline(entry.getValue().toSourceCode()) : entry.getValue().toSourceCode();
            mappingConstructorBuilder.append(sourceCode);
        }

        if (lastFieldEndsWithLineBreak) {
            mappingConstructorBuilder.append(System.lineSeparator());
        }
        return mappingConstructorBuilder.append(SyntaxKind.CLOSE_BRACE_TOKEN.stringValue()).toString();
    }

    private void addMissingConfigFields(Map<String, MappingFieldNode> fields, ToolAnnotationConfig config) {
        addFieldIfAbsent(fields, NAME_FIELD_NAME, config.name());
        addFieldIfAbsent(fields, DESCRIPTION_FIELD_NAME, config.description());
        addFieldIfAbsent(fields, PARAMETERS_FIELD_NAME, config.parameterSchema());
    }

    private void addFieldIfAbsent(Map<String, MappingFieldNode> fields, String fieldName, String value) {
        if (!fields.containsKey(fieldName)) {
            fields.put(fieldName, NodeFactory.createSpecificFieldNode(
                    null,
                    NodeFactory.createIdentifierToken(fieldName),
                    NodeFactory.createToken(SyntaxKind.COLON_TOKEN),
                    NodeParser.parseExpression(value)
            ));
        }
    }

    private ModuleMemberDeclarationNode getModifiedModuleMember(
            ModuleMemberDeclarationNode member, Map<AnnotationNode, AnnotationNode> modifiedAnnotations) {
        if (member.kind() != SyntaxKind.FUNCTION_DEFINITION) {
            return member;
        }
        return modifyFunction((FunctionDefinitionNode) member, modifiedAnnotations);
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
