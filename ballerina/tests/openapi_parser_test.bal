import ballerina/file;
import ballerina/io;
import ballerina/test;
import ballerina/yaml;

@test:Config {}
function testOpenApiSchemaTypes() {
    Schema schema = { // simple schema for integer values
        'type: "integer"
    };
    test:assertTrue(schema is IntegerSchema);

    schema = { // primitive schema for specific type of strings
        'type: "string",
        'format: "date-time",
        pattern: "/^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$/"
    };
    test:assertTrue(schema is StringSchema);

    schema = { // primitive schema with additional parameters
        'type: "string",
        'format: "date-time",
        pattern: "/^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$/",
        "additionalParameter": "dummy-value"
    };
    test:assertTrue(schema is StringSchema);

    schema = { // reference schema
        \$ref: "#/components/schemas/Pet"
    };
    test:assertTrue(schema is Reference);

    schema = { // array schema
        items: {
            'type: "string"
        },
        "additionalParameter": "dummy-value"
    };
    test:assertTrue(schema is ArraySchema);

    schema = { // object schema
        'type: "object",
        properties: {}

    };
    test:assertTrue(schema is ObjectSchema);

    schema = { // object schema without type
        properties: {
            name: {
                'type: "string"
            },
            tag: {
                'type: "string"
            }
        }
    };
    test:assertTrue(schema is ObjectSchema);

    schema = { // object schema without properties
        'type: "object"
    };
    test:assertTrue(schema is ObjectSchema);

    schema = { // unspecified types to string schema
        'enum: ["a", "b", "c"]
    };
    test:assertTrue(schema is StringSchema);

    Schema anyOfSchema = {
        anyOf: [
            schema
        ]
    };
    test:assertTrue(anyOfSchema is AnyOfSchema);

    Schema oneOfSchema = {
        allOf: [
            schema,
            anyOfSchema
        ]
    };
    test:assertTrue(oneOfSchema is AllOfSchema);
}

@test:Config {}
function testOpenApiParser() returns error? {
    string dirPath = "tests/resources/openapi";
    file:MetaData[] openApiDir = check file:readDir(dirPath);
    foreach file:MetaData specInfo in openApiDir {
        map<json> openApiSpec;
        string filePath = specInfo.absPath;
        if filePath.endsWith(".yaml") || filePath.endsWith(".yml") {
            openApiSpec = check yaml:readFile(filePath).ensureType();
        }
        else if filePath.endsWith(".json") {
            openApiSpec = check io:fileReadJson(filePath).ensureType();
        }
        else {
            return error(string `Unsupported file type in the '${dirPath}' directory`);
        }
        OpenApiSpec|UnsupportedOpenApiVersion|OpenApiParsingError parseSpec = parseOpenApiSpec(openApiSpec);

        if filePath.endsWith("openapi (29).json") && parseSpec is UnsupportedOpenApiVersion {
            continue;
        }
        if parseSpec is OpenApiParsingError {
            test:assertFail(string `Failed to parse the OpenAPI at '${filePath}' due to: ${parseSpec.toString()}`);
        }
    }
}
