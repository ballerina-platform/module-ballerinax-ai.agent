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
import io.ballerina.compiler.api.symbols.FunctionTypeSymbol;
import io.ballerina.compiler.api.symbols.ParameterKind;
import io.ballerina.compiler.api.symbols.ParameterSymbol;
import io.ballerina.openapi.service.mapper.type.TypeMapper;
import io.ballerina.openapi.service.mapper.type.TypeMapperImpl;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;
import io.swagger.v3.core.util.Json;
import io.swagger.v3.core.util.OpenAPISchema2JsonSchema;
import io.swagger.v3.oas.models.media.Schema;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import static io.ballerina.lib.ai.plugin.ToolAnnotationAnalysisTask.EMPTY_STRING;
import static io.ballerina.lib.ai.plugin.ToolAnnotationAnalysisTask.NIL_EXPRESSION;

/**
 * Utility class for generating and manipulating function tool parameter schemas.
 */
public class SchemaUtils {
    private static final String STRING = "string";
    private static final String BYTE = "byte";
    private static final String NUMBER = "number";

    private SchemaUtils() {
    }

    public static String getParameterSchema(FunctionSymbol functionSymbol, SyntaxNodeAnalysisContext context)
            throws Exception {
        FunctionTypeSymbol functionTypeSymbol = functionSymbol.typeDescriptor();
        List<ParameterSymbol> parameterSymbolList = functionTypeSymbol.params().get();
        if (functionTypeSymbol.params().isEmpty() || parameterSymbolList.isEmpty()) {
            return NIL_EXPRESSION;
        }

        Map<String, String> individualParamSchema = new HashMap<>();
        List<String> requiredParams = new ArrayList<>();
        TypeMapper typeMapper = new TypeMapperImpl(context);
        for (ParameterSymbol parameterSymbol : parameterSymbolList) {
            try {
                String parameterName = parameterSymbol.getName().orElseThrow();
                if (parameterSymbol.paramKind() != ParameterKind.DEFAULTABLE) {
                    requiredParams.add(parameterName);
                }
                @SuppressWarnings("rawtypes")
                Schema schema = typeMapper.getSchema(parameterSymbol.typeDescriptor());
                String parameterDescription = Utils.getParameterDescription(functionSymbol, parameterName);
                schema.setDescription(parameterDescription);
                String jsonSchema = SchemaUtils.getJsonSchema(schema);
                individualParamSchema.put(parameterName, jsonSchema);
            } catch (RuntimeException e) {
                throw new Exception(e);
            }
        }
        String properties = individualParamSchema.entrySet().stream()
                .map(entry -> String.format("\"%s\": %s", entry.getKey(), entry.getValue()))
                .collect(Collectors.joining(", ", "{", "}"));

        String required = requiredParams.stream()
                .map(paramName -> String.format("\"%s\"", paramName))
                .collect(Collectors.joining(", ", "[", "]"));
        return String.format("{\"type\": \"object\", \"required\": %s, \"properties\": %s }",
                required, properties);
    }

    @SuppressWarnings("rawtypes")
    private static String getJsonSchema(Schema schema) {
        modifySchema(schema);
        OpenAPISchema2JsonSchema openAPISchema2JsonSchema = new OpenAPISchema2JsonSchema();
        openAPISchema2JsonSchema.process(schema);
        String newLineRegex = "\\R";
        String jsonCompressionRegex = "\\s*([{}\\[\\]:,])\\s*";
        return Json.pretty(schema.getJsonSchema())
                .replaceAll(newLineRegex, EMPTY_STRING)
                .replaceAll(jsonCompressionRegex, "$1");
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static void modifySchema(Schema schema) {
        if (schema == null) {
            return;
        }
        modifySchema(schema.getItems());
        modifySchema(schema.getNot());

        Map<String, Schema> properties = schema.getProperties();
        if (properties != null) {
            properties.values().forEach(SchemaUtils::modifySchema);
        }

        List<Schema> allOf = schema.getAllOf();
        if (allOf != null) {
            allOf.forEach(SchemaUtils::modifySchema);
        }

        List<Schema> anyOf = schema.getAnyOf();
        if (anyOf != null) {
            anyOf.forEach(SchemaUtils::modifySchema);
        }

        List<Schema> oneOf = schema.getOneOf();
        if (oneOf != null) {
            oneOf.forEach(SchemaUtils::modifySchema);
        }

        // Override default ballerina byte to json schema mapping
        if (BYTE.equals(schema.getFormat()) && STRING.equals(schema.getType())) {
            schema.setFormat(null);
            schema.setType(NUMBER);
        }
        removeUnwantedFields(schema);
    }

    @SuppressWarnings({"rawtypes", "unchecked"})
    private static void removeUnwantedFields(Schema schema) {
        schema.setSpecVersion(null);
        schema.setSpecVersion(null);
        schema.setContains(null);
        schema.set$id(null);
        schema.set$schema(null);
        schema.set$anchor(null);
        schema.setExclusiveMaximumValue(null);
        schema.setExclusiveMinimumValue(null);
        schema.setDiscriminator(null);
        schema.setTitle(null);
        schema.setMaximum(null);
        schema.setExclusiveMaximum(null);
        schema.setMinimum(null);
        schema.setExclusiveMinimum(null);
        schema.setMaxLength(null);
        schema.setMinLength(null);
        schema.setMaxItems(null);
        schema.setMinItems(null);
        schema.setMaxProperties(null);
        schema.setMinProperties(null);
        schema.setAdditionalProperties(null);
        schema.setAdditionalProperties(null);
        schema.set$ref(null);
        schema.set$ref(null);
        schema.setReadOnly(null);
        schema.setWriteOnly(null);
        schema.setExample(null);
        schema.setExample(null);
        schema.setExternalDocs(null);
        schema.setDeprecated(null);
        schema.setPrefixItems(null);
        schema.setContentEncoding(null);
        schema.setContentMediaType(null);
        schema.setContentSchema(null);
        schema.setPropertyNames(null);
        schema.setUnevaluatedProperties(null);
        schema.setMaxContains(null);
        schema.setMinContains(null);
        schema.setAdditionalItems(null);
        schema.setUnevaluatedItems(null);
        schema.setIf(null);
        schema.setElse(null);
        schema.setThen(null);
        schema.setDependentSchemas(null);
        schema.setDependentRequired(null);
        schema.set$comment(null);
        schema.setExamples(null);
        schema.setExtensions(null);
        schema.setConst(null);
    }
}
