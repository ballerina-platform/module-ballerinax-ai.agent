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
import io.ballerina.compiler.api.symbols.Documentable;
import io.ballerina.compiler.api.symbols.FunctionSymbol;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.api.symbols.TypeDescKind;
import io.ballerina.compiler.api.symbols.TypeReferenceTypeSymbol;
import io.ballerina.compiler.api.symbols.TypeSymbol;
import io.ballerina.compiler.api.symbols.UnionTypeSymbol;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;

/**
 * Util class for the compiler plugin.
 */
public class Utils {
    public static final String BALLERINAX_ORG = "ballerinax";
    private static final String BALLERINA_ORG = "ballerina";
    private static final String TOOL_ANNOTATION_NAME = "Tool";
    private static final String AI_AGENT_PACKAGE_NAME = "ai.agent";
    private static final String HTTP_PACKAGE_NAME = "http";
    private static final String HTTP_RESPONSE_OBJECT_NAME = "Response";

    private Utils() {
    }

    public static boolean isToolAnnotation(AnnotationSymbol annotationSymbol) {
        return annotationSymbol.getModule().isPresent()
                && isAgentModuleSymbol(annotationSymbol.getModule().get())
                && annotationSymbol.getName().isPresent()
                && TOOL_ANNOTATION_NAME.equals(annotationSymbol.getName().get());
    }

    public static boolean isAgentModuleSymbol(Symbol symbol) {
        return symbol.getModule().isPresent()
                && AI_AGENT_PACKAGE_NAME.equals(symbol.getModule().get().id().moduleName())
                && BALLERINAX_ORG.equals(symbol.getModule().get().id().orgName());
    }

    public static boolean isHttpModuleSymbol(Symbol symbol) {
        return symbol.getModule().isPresent()
                && HTTP_PACKAGE_NAME.equals(symbol.getModule().get().id().moduleName())
                && BALLERINA_ORG.equals(symbol.getModule().get().id().orgName());
    }

    public static boolean isAnydataType(TypeSymbol typeSymbol, SyntaxNodeAnalysisContext context) {
        return typeSymbol.subtypeOf(context.semanticModel().types().ANYDATA);
    }

    public static boolean isErrorType(TypeSymbol typeSymbol, SyntaxNodeAnalysisContext context) {
        return typeSymbol.subtypeOf(context.semanticModel().types().ERROR);
    }

    public static boolean isAnydataOrErrorTypeOrHttpResponse(TypeSymbol typeSymbol, SyntaxNodeAnalysisContext context) {
        if (typeSymbol.typeKind() == TypeDescKind.TYPE_REFERENCE) {
            TypeReferenceTypeSymbol typeReferenceTypeSymbol = (TypeReferenceTypeSymbol) typeSymbol;
            if (HTTP_RESPONSE_OBJECT_NAME.equals(typeReferenceTypeSymbol.definition().getName().orElse("<unknown>"))
                    && Utils.isHttpModuleSymbol(typeReferenceTypeSymbol)) {
                return true;
            }
            return isAnydataOrErrorTypeOrHttpResponse(typeReferenceTypeSymbol.typeDescriptor(), context);
        }
        if (typeSymbol.typeKind() == TypeDescKind.UNION) {
            UnionTypeSymbol unionTypeSymbol = (UnionTypeSymbol) typeSymbol;
            return unionTypeSymbol.memberTypeDescriptors()
                    .stream().map(member -> isAnydataOrErrorTypeOrHttpResponse(member, context))
                    .reduce((a, b) -> a && b)
                    .orElse(false);
        }
        return isAnydataType(typeSymbol, context) || isErrorType(typeSymbol, context);
    }

    public static boolean isXmlType(TypeSymbol typeSymbol, SyntaxNodeAnalysisContext context) {
        return typeSymbol.subtypeOf(context.semanticModel().types().XML);
    }

    public static String getParameterDescription(FunctionSymbol functionSymbol, String parameterName) {
        if (functionSymbol.documentation().isEmpty()
                || functionSymbol.documentation().get().description().isEmpty()) {
            return null;
        }
        return functionSymbol.documentation().get().parameterMap().getOrDefault(parameterName, null);
    }

    public static String getDescription(Documentable documentable) {
        if (documentable.documentation().isEmpty()
                || documentable.documentation().get().description().isEmpty()) {
            return null;
        }
        return documentable.documentation().get().description().get();
    }

    public static String addDoubleQuotes(String functionName) {
        return "\"" + functionName + "\"";
    }
}
