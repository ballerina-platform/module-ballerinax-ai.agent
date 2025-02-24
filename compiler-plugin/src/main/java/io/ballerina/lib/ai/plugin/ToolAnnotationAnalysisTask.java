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

import io.ballerina.compiler.api.symbols.AnnotationSymbol;
import io.ballerina.compiler.api.symbols.FunctionSymbol;
import io.ballerina.compiler.api.symbols.FunctionTypeSymbol;
import io.ballerina.compiler.api.symbols.ParameterSymbol;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.api.symbols.SymbolKind;
import io.ballerina.compiler.api.symbols.TypeSymbol;
import io.ballerina.compiler.syntax.tree.AnnotationNode;
import io.ballerina.compiler.syntax.tree.ExpressionNode;
import io.ballerina.compiler.syntax.tree.FunctionDefinitionNode;
import io.ballerina.compiler.syntax.tree.MappingFieldNode;
import io.ballerina.compiler.syntax.tree.NodeFactory;
import io.ballerina.compiler.syntax.tree.NodeParser;
import io.ballerina.compiler.syntax.tree.NonTerminalNode;
import io.ballerina.compiler.syntax.tree.SeparatedNodeList;
import io.ballerina.compiler.syntax.tree.SpecificFieldNode;
import io.ballerina.compiler.syntax.tree.SyntaxKind;
import io.ballerina.lib.ai.plugin.diagnostics.CompilationDiagnostic;
import io.ballerina.projects.DocumentId;
import io.ballerina.projects.plugins.AnalysisTask;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;
import io.ballerina.tools.diagnostics.Diagnostic;
import io.ballerina.tools.diagnostics.Location;

import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.stream.Collectors;

import static io.ballerina.lib.ai.plugin.diagnostics.CompilationDiagnostic.INVALID_RETURN_TYPE_IN_TOOL;
import static io.ballerina.lib.ai.plugin.diagnostics.CompilationDiagnostic.PARAMETER_IS_NOT_A_SUBTYPE_OF_ANYDATA;
import static io.ballerina.lib.ai.plugin.diagnostics.CompilationDiagnostic.UNABLE_TO_GENERATE_SCHEMA_FOR_FUNCTION;
import static io.ballerina.lib.ai.plugin.diagnostics.CompilationDiagnostic.XML_PARAMETER_NOT_SUPPORTED_BY_TOOL;

/**
 * Analyzes a Ballerina AI tools and report diagnostics.
 */
class ToolAnnotationAnalysisTask implements AnalysisTask<SyntaxNodeAnalysisContext> {
    public static final String NAME_FIELD_NAME = "name";
    public static final String DESCRIPTION_FIELD_NAME = "description";
    public static final String PARAMETERS_FIELD_NAME = "parameters";
    public static final String EMPTY_STRING = "";
    public static final String NIL_EXPRESSION = "()";

    private final Map<DocumentId, ModifierContext> modifierContextMap;
    private SyntaxNodeAnalysisContext context;

    ToolAnnotationAnalysisTask(Map<DocumentId, ModifierContext> modifierContextMap) {
        this.modifierContextMap = modifierContextMap;
    }

    @Override
    public void perform(SyntaxNodeAnalysisContext context) {
        this.context = context;
        Optional<Symbol> symbol = context.semanticModel().symbol(context.node());
        if (symbol.isEmpty() || symbol.get().kind() != SymbolKind.ANNOTATION
                || !Utils.isToolAnnotation((AnnotationSymbol) symbol.get())) {
            return;
        }

        AnnotationNode toolAnnotationNode = (AnnotationNode) context.node();
        Optional<FunctionDefinitionNode> functionDefinitionNode = getFunctionDefinitionNode(toolAnnotationNode);
        if (functionDefinitionNode.isEmpty()) {
            return;
        }

        Optional<FunctionSymbol> functionSymbol = getFunctionSymbol(functionDefinitionNode.get());
        if (functionSymbol.isEmpty() || functionSymbol.get().getName().isEmpty()) {
            return;
        }

        Location functionLocation = functionSymbol.get().getLocation()
                .orElse(functionDefinitionNode.get().location());
        if (!hasValidParameterTypes(functionSymbol.get(), functionLocation)
                || !hasValidateReturnType(functionSymbol.get(), functionLocation)) {
            return;
        }
        if (hasSpreadAnnotationFieldValue(toolAnnotationNode)) {
            return;
        }
        ToolAnnotationConfig config = createAnnotationConfig(toolAnnotationNode, functionDefinitionNode.get());
        addToModifierContext(context, toolAnnotationNode, config);
    }

    private boolean hasSpreadAnnotationFieldValue(AnnotationNode toolAnnotationNode) {
        return toolAnnotationNode.annotValue().isPresent()
                && toolAnnotationNode.annotValue().get().fields().size() == 1
                && toolAnnotationNode.annotValue().get().fields().get(0).kind() == SyntaxKind.SPREAD_FIELD;
    }

    private boolean hasValidateReturnType(FunctionSymbol functionSymbol, Location functionLocation) {
        Optional<TypeSymbol> returnType = functionSymbol.typeDescriptor().returnTypeDescriptor();
        if (returnType.isEmpty() || Utils.isAnydataOrErrorType(returnType.get(), this.context)) {
            return true;
        }
        Diagnostic diagnostic = CompilationDiagnostic.getDiagnostic(INVALID_RETURN_TYPE_IN_TOOL, functionLocation,
                functionSymbol.getName().orElse("unknownFunction"));
        reportDiagnostic(diagnostic);
        return false;
    }

    private boolean hasValidParameterTypes(FunctionSymbol functionSymbol, Location alternativeLocation) {
        FunctionTypeSymbol functionTypeSymbol = functionSymbol.typeDescriptor();
        List<ParameterSymbol> parameterSymbolList = functionTypeSymbol.params().get();
        if (functionTypeSymbol.params().isEmpty() || parameterSymbolList.isEmpty()) {
            return true;
        }

        boolean isAnydata = true;
        boolean isXml = false;
        String functionName = functionSymbol.getName().orElse("unknownFunction");
        for (ParameterSymbol parameterSymbol : parameterSymbolList) {
            TypeSymbol paramTypeSymbol = parameterSymbol.typeDescriptor();
            if (!Utils.isAnydataType(paramTypeSymbol, this.context)) {
                isAnydata = false;
                Diagnostic diagnostic = CompilationDiagnostic.getDiagnostic(PARAMETER_IS_NOT_A_SUBTYPE_OF_ANYDATA,
                        parameterSymbol.getLocation().orElse(alternativeLocation),
                        functionName, parameterSymbol.getName().orElse("<unknown>"));
                reportDiagnostic(diagnostic);
            }
            XmlTypeInspector xmlTypeInspector = new XmlTypeInspector(context);
            if (xmlTypeInspector.includesXmlType(paramTypeSymbol)) {
                Diagnostic diagnostic = CompilationDiagnostic.getDiagnostic(XML_PARAMETER_NOT_SUPPORTED_BY_TOOL,
                        parameterSymbol.getLocation().orElse(alternativeLocation),
                        functionName, parameterSymbol.getName().orElse("<unknown>"));
                reportDiagnostic(diagnostic);
                isXml = true;
            }
        }
        // Tool functions can take anydata type parameter except xml
        return isAnydata && !isXml;
    }

    private void reportDiagnostic(Diagnostic diagnostic) {
        this.context.reportDiagnostic(diagnostic);
    }

    private Optional<FunctionSymbol> getFunctionSymbol(FunctionDefinitionNode functionDefinitionNode) {
        Optional<Symbol> functionSymbol = context.semanticModel().symbol(functionDefinitionNode);
        return functionSymbol.filter(symbol -> symbol.kind() == SymbolKind.FUNCTION).map(FunctionSymbol.class::cast);
    }

    private Optional<FunctionDefinitionNode> getFunctionDefinitionNode(AnnotationNode annotationNode) {
        NonTerminalNode possibleFunctionNode = annotationNode.parent().parent();
        if (possibleFunctionNode.kind() != SyntaxKind.FUNCTION_DEFINITION) {
            return Optional.empty();
        }
        return Optional.of((FunctionDefinitionNode) possibleFunctionNode);
    }

    private ToolAnnotationConfig createAnnotationConfig(AnnotationNode annotationNode,
                                                        FunctionDefinitionNode functionDefinitionNode) {
        @SuppressWarnings("OptionalGetWithoutIsPresent") // is present already check in perform method
        FunctionSymbol functionSymbol = getFunctionSymbol(functionDefinitionNode).get();
        String functionName = functionSymbol.getName().orElse("unknownFunction");
        SeparatedNodeList<MappingFieldNode> fields = annotationNode.annotValue().isEmpty() ?
                NodeFactory.createSeparatedNodeList() : annotationNode.annotValue().get().fields();
        Map<String, ExpressionNode> fieldValues = extractFieldValues(fields);
        String name = fieldValues.containsKey(NAME_FIELD_NAME) ? fieldValues.get(NAME_FIELD_NAME).toSourceCode()
                : Utils.addDoubleQuotes(functionName);
        String description = fieldValues.containsKey(DESCRIPTION_FIELD_NAME)
                ? fieldValues.get(DESCRIPTION_FIELD_NAME).toSourceCode()
                : Utils.addDoubleQuotes(Objects.requireNonNullElse(Utils.getDescription(functionSymbol), functionName));
        String parameters = fieldValues.containsKey(PARAMETERS_FIELD_NAME)
                ? fieldValues.get(PARAMETERS_FIELD_NAME).toSourceCode()
                : getParameterSchema(functionSymbol, functionDefinitionNode.location());
        return new ToolAnnotationConfig(name, description, parameters);
    }

    private Map<String, ExpressionNode> extractFieldValues(SeparatedNodeList<MappingFieldNode> fields) {
        return fields.stream()
                .filter(field -> field.kind() == SyntaxKind.SPECIFIC_FIELD)
                .map(field -> (SpecificFieldNode) field)
                .filter(field -> field.valueExpr().isPresent())
                .collect(Collectors.toMap(
                        field -> field.fieldName().toSourceCode().trim(),
                        field -> field.valueExpr().orElse(NodeParser.parseExpression(NIL_EXPRESSION))
                ));
    }

    private String getParameterSchema(FunctionSymbol functionSymbol, Location alternativeFunctionLocation) {
        try {
            return SchemaUtils.getParameterSchema(functionSymbol, this.context);
        } catch (Exception e) {
            Diagnostic diagnostic = CompilationDiagnostic.getDiagnostic(UNABLE_TO_GENERATE_SCHEMA_FOR_FUNCTION,
                    functionSymbol.getLocation().orElse(alternativeFunctionLocation),
                    functionSymbol.getName().orElse("unknownFunction"));
            reportDiagnostic(diagnostic);
            return NIL_EXPRESSION;
        }
    }

    private void addToModifierContext(SyntaxNodeAnalysisContext context, AnnotationNode annotationNode,
                                      ToolAnnotationConfig functionDefinitionNode) {
        this.modifierContextMap.computeIfAbsent(context.documentId(), document -> new ModifierContext())
                .add(annotationNode, functionDefinitionNode);
    }
}
