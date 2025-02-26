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

package io.ballerina.lib.ai.plugin.diagnostics;

import io.ballerina.tools.diagnostics.Diagnostic;
import io.ballerina.tools.diagnostics.DiagnosticFactory;
import io.ballerina.tools.diagnostics.DiagnosticInfo;
import io.ballerina.tools.diagnostics.DiagnosticSeverity;
import io.ballerina.tools.diagnostics.Location;

import static io.ballerina.tools.diagnostics.DiagnosticSeverity.ERROR;

/**
 * Compilation errors in the Ballerina AI package.
 */
public enum CompilationDiagnostic {
    UNABLE_TO_GENERATE_SCHEMA_FOR_FUNCTION(DiagnosticMessage.ERROR_101, DiagnosticCode.AI_101, ERROR),
    PARAMETER_IS_NOT_A_SUBTYPE_OF_ANYDATA(DiagnosticMessage.ERROR_102, DiagnosticCode.AI_102, ERROR),
    XML_PARAMETER_NOT_SUPPORTED_BY_TOOL(DiagnosticMessage.ERROR_103, DiagnosticCode.AI_103, ERROR),
    INVALID_RETURN_TYPE_IN_TOOL(DiagnosticMessage.ERROR_104, DiagnosticCode.AI_104, ERROR);

    private final String diagnostic;
    private final String diagnosticCode;
    private final DiagnosticSeverity diagnosticSeverity;

    CompilationDiagnostic(DiagnosticMessage message, DiagnosticCode diagnosticCode,
                          DiagnosticSeverity diagnosticSeverity) {
        this.diagnostic = message.getMessage();
        this.diagnosticCode = diagnosticCode.name();
        this.diagnosticSeverity = diagnosticSeverity;
    }

    public static Diagnostic getDiagnostic(CompilationDiagnostic compilationDiagnostic, Location location,
                                           Object... args) {
        DiagnosticInfo diagnosticInfo = new DiagnosticInfo(
                compilationDiagnostic.getDiagnosticCode(),
                compilationDiagnostic.getDiagnostic(),
                compilationDiagnostic.getDiagnosticSeverity());
        return DiagnosticFactory.createDiagnostic(diagnosticInfo, location, args);
    }

    public String getDiagnostic() {
        return diagnostic;
    }

    public String getDiagnosticCode() {
        return diagnosticCode;
    }

    public DiagnosticSeverity getDiagnosticSeverity() {
        return this.diagnosticSeverity;
    }
}
