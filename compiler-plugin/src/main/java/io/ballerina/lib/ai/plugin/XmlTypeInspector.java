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

import io.ballerina.compiler.api.symbols.ArrayTypeSymbol;
import io.ballerina.compiler.api.symbols.MapTypeSymbol;
import io.ballerina.compiler.api.symbols.RecordTypeSymbol;
import io.ballerina.compiler.api.symbols.TableTypeSymbol;
import io.ballerina.compiler.api.symbols.TypeReferenceTypeSymbol;
import io.ballerina.compiler.api.symbols.TypeSymbol;
import io.ballerina.compiler.api.symbols.UnionTypeSymbol;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;

import java.util.HashSet;
import java.util.Set;

public class XmlTypeInspector {
    private final SyntaxNodeAnalysisContext context;
    private final Set<TypeSymbol> visitedSymbol = new HashSet<>();

    public XmlTypeInspector(SyntaxNodeAnalysisContext context) {
        this.context = context;
    }

    public boolean includesXmlType(TypeSymbol typeSymbol) {
        if (visitedSymbol.contains(typeSymbol)) {
            // If there is a cyclic reference in the type, return false to avoid infinite recursion.
            // The correctness is ensured as record fields are validated separately.
            return false;
        }
        visitedSymbol.add(typeSymbol);
        return switch (typeSymbol.typeKind()) {
            case TYPE_REFERENCE -> includesXmlType(((TypeReferenceTypeSymbol) typeSymbol).typeDescriptor());
            case UNION -> ((UnionTypeSymbol) typeSymbol).memberTypeDescriptors()
                    .stream().anyMatch(this::includesXmlType);
            case RECORD -> ((RecordTypeSymbol) typeSymbol).fieldDescriptors().values()
                    .stream().anyMatch(field -> includesXmlType(field.typeDescriptor()));
            case MAP -> includesXmlType(((MapTypeSymbol) typeSymbol).typeParam());
            case ARRAY -> includesXmlType(((ArrayTypeSymbol) typeSymbol).memberTypeDescriptor());
            case TABLE -> includesXmlType(((TableTypeSymbol) typeSymbol).rowTypeParameter());
            default -> Utils.isXmlType(typeSymbol, context);
        };
    }
}
