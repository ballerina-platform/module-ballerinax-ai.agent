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

package io.ballerina.lib.ai.compiler;

import io.ballerina.lib.ai.plugin.diagnostics.CompilationDiagnostic;
import io.ballerina.projects.DiagnosticResult;
import io.ballerina.projects.ProjectEnvironmentBuilder;
import io.ballerina.projects.directory.BuildProject;
import io.ballerina.projects.environment.Environment;
import io.ballerina.projects.environment.EnvironmentBuilder;
import io.ballerina.tools.diagnostics.Diagnostic;
import io.ballerina.tools.diagnostics.DiagnosticSeverity;
import io.ballerina.tools.diagnostics.Location;
import org.testng.Assert;
import org.testng.annotations.Test;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.text.MessageFormat;
import java.util.Iterator;

import static io.ballerina.lib.ai.plugin.diagnostics.CompilationDiagnostic.INVALID_RETURN_TYPE_IN_TOOL;
import static io.ballerina.lib.ai.plugin.diagnostics.CompilationDiagnostic.PARAMETER_IS_NOT_A_SUBTYPE_OF_ANYDATA;
import static io.ballerina.lib.ai.plugin.diagnostics.CompilationDiagnostic.UNABLE_TO_GENERATE_SCHEMA_FOR_FUNCTION;
import static io.ballerina.lib.ai.plugin.diagnostics.CompilationDiagnostic.XML_PARAMETER_NOT_SUPPORTED_BY_TOOL;

/**
 * Contains compiler plugin tests for validating the Ballerina AI tool.
 */
public class AiToolValidationTest {
    private static final String BALLERINA_HOME = "BALLERINA_HOME";
    private static final String BALLERINA_DISTRIBUTION_VERSION = "ballerina.distribution.version";
    private static final Path RESOURCE_DIRECTORY = Paths.get("src", "test", "resources",
            "ballerina_sources", "validation_tests").toAbsolutePath();
    private static final Path DISTRIBUTION_PATH = Paths.get(System.getenv(BALLERINA_HOME),
            "distributions", System.getProperty(BALLERINA_DISTRIBUTION_VERSION)).toAbsolutePath();

    @Test
    public void testToolInputTypeValidation() {
        String packagePath = "01_tool_with_any_input_type";
        DiagnosticResult diagnosticResult = getDiagnosticResult(packagePath);
        Assert.assertEquals(diagnosticResult.errorCount(), 2);

        Iterator<Diagnostic> diagnosticIterator = diagnosticResult.errors().iterator();
        Diagnostic diagnostic = diagnosticIterator.next();
        String message = getErrorMessage(PARAMETER_IS_NOT_A_SUBTYPE_OF_ANYDATA, "toolWithAny", "data");
        assertErrorMessage(diagnostic, message, 24, 49);

        diagnostic = diagnosticIterator.next();
        message = getErrorMessage(PARAMETER_IS_NOT_A_SUBTYPE_OF_ANYDATA, "toolWithAny", "anyMap");
        assertErrorMessage(diagnostic, message, 24, 64);
    }

    @Test
    public void testToolReturnTypeValidation() {
        String packagePath = "02_tool_with_any_return_type";
        DiagnosticResult diagnosticResult = getDiagnosticResult(packagePath);
        Assert.assertEquals(diagnosticResult.errorCount(), 4);

        Iterator<Diagnostic> diagnosticIterator = diagnosticResult.errors().iterator();
        Diagnostic diagnostic = diagnosticIterator.next();
        String message = getErrorMessage(INVALID_RETURN_TYPE_IN_TOOL, "toolReturningAny");
        assertErrorMessage(diagnostic, message, 24, 19);

        diagnostic = diagnosticIterator.next();
        message = getErrorMessage(INVALID_RETURN_TYPE_IN_TOOL, "toolReturningInstance");
        assertErrorMessage(diagnostic, message, 29, 19);

        diagnostic = diagnosticIterator.next();
        message = getErrorMessage(INVALID_RETURN_TYPE_IN_TOOL, "toolReturningMapOfAny");
        assertErrorMessage(diagnostic, message, 34, 19);

        diagnostic = diagnosticIterator.next();
        message = getErrorMessage(INVALID_RETURN_TYPE_IN_TOOL, "toolReturningUnionOfAny");
        assertErrorMessage(diagnostic, message, 39, 19);
    }

    @Test
    public void testToolXmlInputValidation() {
        String packagePath = "03_tool_with_xml_input_type";
        DiagnosticResult diagnosticResult = getDiagnosticResult(packagePath);
        Assert.assertEquals(diagnosticResult.errorCount(), 7);

        Iterator<Diagnostic> diagnosticIterator = diagnosticResult.errors().iterator();
        Diagnostic diagnostic = diagnosticIterator.next();
        String message = getErrorMessage(XML_PARAMETER_NOT_SUPPORTED_BY_TOOL, "toolWithXml", "one");
        assertErrorMessage(diagnostic, message, 26, 35);

        diagnostic = diagnosticIterator.next();
        message = getErrorMessage(XML_PARAMETER_NOT_SUPPORTED_BY_TOOL, "toolWithXml", "two");
        assertErrorMessage(diagnostic, message, 26, 44);

        diagnostic = diagnosticIterator.next();
        message = getErrorMessage(XML_PARAMETER_NOT_SUPPORTED_BY_TOOL, "toolWithXml", "three");
        assertErrorMessage(diagnostic, message, 26, 58);

        diagnostic = diagnosticIterator.next();
        message = getErrorMessage(XML_PARAMETER_NOT_SUPPORTED_BY_TOOL, "toolWithXml", "four");
        assertErrorMessage(diagnostic, message, 26, 77);

        diagnostic = diagnosticIterator.next();
        message = getErrorMessage(XML_PARAMETER_NOT_SUPPORTED_BY_TOOL, "toolWithXml", "five");
        assertErrorMessage(diagnostic, message, 27, 16);

        diagnostic = diagnosticIterator.next();
        message = getErrorMessage(XML_PARAMETER_NOT_SUPPORTED_BY_TOOL, "toolWithXml", "six");
        assertErrorMessage(diagnostic, message, 27, 36);

        diagnostic = diagnosticIterator.next();
        message = getErrorMessage(XML_PARAMETER_NOT_SUPPORTED_BY_TOOL, "toolWithXml", "seven");
        assertErrorMessage(diagnostic, message, 27, 55);
    }

    @Test
    public void testToolWithCyclicInputValidation() {
        String packagePath = "04_tool_with_cyclic_input_type";
        DiagnosticResult diagnosticResult = getDiagnosticResult(packagePath);
        Assert.assertEquals(diagnosticResult.errorCount(), 1);

        Iterator<Diagnostic> diagnosticIterator = diagnosticResult.errors().iterator();
        Diagnostic diagnostic = diagnosticIterator.next();
        String message = getErrorMessage(UNABLE_TO_GENERATE_SCHEMA_FOR_FUNCTION, "toolCyclicInput");
        assertErrorMessage(diagnostic, message, 26, 19);
    }

    private DiagnosticResult getDiagnosticResult(String path) {
        Path projectDirPath = RESOURCE_DIRECTORY.resolve(path);
        BuildProject project = BuildProject.load(getEnvironmentBuilder(), projectDirPath);
        return project.currentPackage().runCodeGenAndModifyPlugins();
    }

    private static ProjectEnvironmentBuilder getEnvironmentBuilder() {
        Environment environment = EnvironmentBuilder.getBuilder().setBallerinaHome(DISTRIBUTION_PATH).build();
        return ProjectEnvironmentBuilder.getBuilder(environment);
    }

    private String getErrorMessage(CompilationDiagnostic compilationDiagnostic, Object... args) {
        return MessageFormat.format(compilationDiagnostic.getDiagnostic(), args);
    }

    private void assertErrorMessage(Diagnostic diagnostic, String message, int line, int column) {
        Assert.assertEquals(diagnostic.diagnosticInfo().severity(), DiagnosticSeverity.ERROR);
        Assert.assertEquals(diagnostic.message(), message);
        assertErrorLocation(diagnostic.location(), line, column);
    }

    private void assertErrorLocation(Location location, int line, int column) {
        // Compiler counts lines and columns from zero
        Assert.assertEquals((location.lineRange().startLine().line() + 1), line);
        Assert.assertEquals((location.lineRange().startLine().offset() + 1), column);
    }
}
