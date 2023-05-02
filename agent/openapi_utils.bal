import ballerina/io;

// import ballerina/regex;

function removeExtensions(json schema) {
    if schema is map<json> {
        foreach string key in schema.keys() {
            if key.startsWith("x-") {
                _ = schema.remove(key);
                continue;
            }
            _ = removeExtensions(schema[key]);
        }
    } else if schema is json[] {
        foreach json element in schema {
            _ = removeExtensions(element);
        }
    }
}

public function parseOpenAPISpec(string jsonPath) returns OpenAPISpec|error {
    json fileJson = check io:fileReadJson(jsonPath);
    removeExtensions(check fileJson.ensureType());
    map<json> & readonly jsonSchema = check fileJson.cloneWithType();
    OpenAPISpec openAPISchema = check jsonSchema.ensureType();
    return openAPISchema;
}

public class OpenAPISpecVisitor {
    string? serverURL;
    HttpTool[] tools;
    string currentPath;
    HttpMethod? currentMethod;
    map<ComponentType> referenceMap;

    function init() {
        self.serverURL = ();
        self.currentPath = "";
        self.currentMethod = ();

        self.tools = [];
        self.referenceMap = {};
    }

    function visit(OpenAPISpec openAPISpec) returns error? {
        if !openAPISpec.openapi.matches(re `3\.0\..`) {
            return error("OpenAPI version is not supported. Supports specifications with version 3.0.x only.");
        }
        check self.visitServers(openAPISpec.servers ?: []);
        check self.visitComponents(openAPISpec.components ?: {});
        check self.visitPaths(openAPISpec.paths ?: {});
    }

    private function visitServers(Server[] servers) returns error? {
        if servers.length() < 1 {
            return;
        }
        if servers.length() > 1 {
            return error("Multiple server urls are defined in the OpenAPI specification.");
        }
        self.serverURL = check servers[0].url.ensureType();
    }

    private function visitComponents(Components components) returns error? {
        foreach string componentType in components.keys() {
            map<ComponentType|Reference>? componentMap = check components[componentType].ensureType();
            if componentMap is () {
                continue;
            }
            foreach string componentId in componentMap.keys() {
                ComponentType|Reference component = check componentMap[componentId].ensureType();
                string ref = "#/components/" + componentType + "/" + componentId;
                self.referenceMap[ref] = component;
            }
        }
    }

    private function visitPaths(Paths paths) returns error? {
        foreach string pathURL in paths.keys() {
            PathItem pathItem;
            if paths.get(pathURL) is Reference {
                pathItem = check self.resolveReference(<Reference>paths.get(pathURL)).ensureType();
            } else {
                pathItem = check paths.get(pathURL).ensureType();
            }
            self.currentPath = pathURL;
            check self.visitPathItem(pathItem);
        }
    }

    private function visitPathItem(PathItem pathItem) returns error? {
        if pathItem.get is Operation {
            self.currentMethod = GET;
            check self.visitOperation(<Operation>pathItem.get);
        }
        if pathItem.post is Operation {
            self.currentMethod = POST;
            check self.visitOperation(<Operation>pathItem.post);
        }
        if pathItem.put is Operation {
            self.currentMethod = PUT;
            check self.visitOperation(<Operation>pathItem.put);
        }
        if pathItem.delete is Operation {
            self.currentMethod = DELETE;
            check self.visitOperation(<Operation>pathItem.delete);
        }
        if pathItem.options is Operation {
            self.currentMethod = OPTIONS;
            check self.visitOperation(<Operation>pathItem.options);
        }
        if pathItem.head is Operation {
            self.currentMethod = HEAD;
            check self.visitOperation(<Operation>pathItem.head);
        }
        if pathItem.patch is Operation {
            self.currentMethod = PATCH;
            check self.visitOperation(<Operation>pathItem.patch);
        }
        if pathItem.trace is Operation {
            return error("Http trace method is not supported");
        }
    }

    private function resolveReference(Reference reference) returns ComponentType|error {
        if !self.referenceMap.hasKey(reference.\$ref) {
            return error("No component found to resolve the reference: " + reference.\$ref);
        }
        ComponentType|Reference component = self.referenceMap.get(reference.\$ref);
        while component is Reference {
            component = check self.resolveReference(component);
        }
        return component;
    }

    private function visitOperation(Operation operation) returns error? {
        if operation.servers !is () {
            return error("Path-wise service URLs are not supported");
        }
        if operation.summary is () && operation.description is () {
            return error(string `Summary or Description is mandotory. It is missing for ${self.currentPath} and method ${self.currentMethod.toString()}`);
        }
        if operation.operationId is () {
            return error(string `OperationId is mandotory. It is missing for ${self.currentPath} and method ${self.currentMethod.toString()}`);
        }

        string name = <string>operation.operationId;
        string description = operation.summary ?: <string>operation.description;

        // resolve queryParameters
        InputSchema queryParams = {};
        // if operation.parameters !is () {
        // forea
        //     foreach Parameter|Reference parameter in operation.parameters {
        //         if parameter.in != "query" {
        //             continue;
        //         }
        //         InputSchema jsonSchema;
        //         if parameter is Reference {
        //             Parameter resolvedParameter = check self.resolveReference(<Reference>parameter).ensureType();
        //             jsonSchema = check self.visitParameter(resolvedParameter);
        //         } else {
        //             jsonSchema = check self.visitParameter(parameter);
        //         }
        //         queryParams[parameter.name] = jsonSchema;
        //     }
        // }

        // resolve requestBody
        InputSchema jsonRequestBody = {};
        if operation.requestBody !is () {
            RequestBody requestBody;
            if operation.requestBody is Reference {
                requestBody = check self.resolveReference(<Reference>operation.requestBody).ensureType();
            } else {
                requestBody = check operation.requestBody.ensureType();
            }
            jsonRequestBody = check self.visitRequestBody(requestBody);
        }

        self.tools.push({
            name: name,
            description: description,
            path: self.currentPath,
            method: <HttpMethod>self.currentMethod,
            queryParams: queryParams,
            requestBody: jsonRequestBody
        });
    }

    function visitRequestBody(RequestBody requestBody) returns JsonInputSchema|error {
        map<MediaType> content = requestBody.content;

        // check for json content
        if !content.hasKey(OPENAPI_JSON_CONTENT_KEY) {
            return error("Only json content is supported.");
        }
        Schema schema = content.get(OPENAPI_JSON_CONTENT_KEY).schema;
        return self.visitSchema(schema).ensureType();
    }

    function visitSchema(Schema schema) returns SubSchema|error {

        if schema is ObjectSchema {
            return self.visitObjectSchema(schema);
        }
        if schema is ArraySchema {
            return self.visitArraySchema(schema);
        }
        if schema is PrimitiveTypeSchema {
            return self.visitPrimitiveTypeSchema(schema);
        }
        if schema is AnyOfSchema {
            return self.visitAnyOfSchema(schema);
        }
        if schema is OneOfSchema {
            return self.visitOneOfSchema(schema);
        }
        if schema is AllOfSchema {
            return self.visitAllOfSchema(schema);
        }
        if schema is NotSchema {
            return self.visitNotSchema(schema);
        }

        Schema resolvedSchema = check self.resolveReference(<Reference>schema).ensureType();
        return check self.visitSchema(resolvedSchema);

        // return error("Unsupported schema type found: " + (typeof schema).toString());
    }

    function visitObjectSchema(ObjectSchema schema) returns ObjectInputSchema|error {
        ObjectInputSchema objectSchema = {
            'type: OBJECT,
            properties: {}
        };

        if schema?.properties == () {
            return objectSchema;
        }

        map<Schema> properties = <map<Schema>>schema?.properties;
        if properties.length() == 0 {
            return objectSchema;
        }

        foreach string propertyName in properties.keys() {
            SubSchema trimmedProperty = check self.visitSchema(properties.get(propertyName));
            objectSchema.properties[propertyName] = trimmedProperty;
        }
        return objectSchema;
    }

    function visitArraySchema(ArraySchema schema) returns ArrayInputSchema|error {

        SubSchema trimmedItems = check self.visitSchema(schema.items);

        return {
            'type: ARRAY,
            items: trimmedItems
        };
    }

    function visitPrimitiveTypeSchema(PrimitiveTypeSchema schema) returns PrimitiveInputSchema {
        if schema is StringSchema {
            return {
                'type: STRING,
                format: schema.format
            };
        }
        if schema is NumberSchema {
            return {
                'type: FLOAT
            };
        }
        return {
            'type: schema.'type
        };
    }

    function visitAnyOfSchema(AnyOfSchema schema) returns AnyOfInputSchema|error {
        SubSchema[] anyOf = [];
        foreach Schema element in schema.anyOf {
            SubSchema trimmedElement = check self.visitSchema(element);
            anyOf.push(trimmedElement);
        }
        return {
            anyOf: anyOf
        };
    }

    function visitAllOfSchema(AllOfSchema schema) returns AllOfInputSchema|error {
        SubSchema[] allOf = [];
        foreach Schema element in schema.allOf {
            SubSchema trimmedElement = check self.visitSchema(element);
            allOf.push(trimmedElement);
        }
        return {
            allOf: allOf
        };
    }

    function visitOneOfSchema(OneOfSchema schema) returns OneOfInputSchema|error {
        SubSchema[] oneOf = [];
        foreach Schema element in schema.oneOf {
            SubSchema trimmedElement = check self.visitSchema(element);
            oneOf.push(trimmedElement);
        }
        return {
            oneOf: oneOf
        };
    }

    function visitNotSchema(NotSchema schema) returns NotInputSchema|error {
        return {
            not: check self.visitSchema(schema.not)
        };
    }
}

// public function main() returns error? {

//     final string filePath = "tests/data/openapi2.json";

//     // map<Schema> properties = {
//     //     "password": {"type": "object"}
//     // };
//     // StringSchema schema = {'type: STRING};
//     // Schema trimmedProperty = check schema.ensureType();
//     // properties["password"] = trimmedProperty; 
//     // io:println(properties);

//     // Schema schema = {
//     //     "allOf": [
//     //         {"type": "object", "properties": {"email": {"type": "string"}, "username": {"type": "string"}}},
//     //         {"type": "object", "properties": {"password": {"type": "string"}}}
//     //     ]
//     // };

//     OpenAPISpec openAPISchema = check parseOpenAPISpec(filePath);

//     OpenAPISpecVisitor visitor = new;
//     check visitor.visit(openAPISchema);
//     io:println(visitor.tools);
//     // io:println(openAPISchema);

//     //     // map<json> & readonly jsonSchema = {"type": "string", "default": "", "example": "This is a test."};
//     //     // Schema schema1 = check jsonSchema.ensureType();
//     //     // io:println(schema1);
//     //     // io:println(schema1 is ObjectSchema);
//     //     // io:println(schema1 is StringSchema);
//     //     // io:println(schema1 is IntegerSchema);

//     //     // IntegerSchema ss = check jsonSchema.ensureType();
//     //     // io:println(ss);

//     //     // io:println(regex:matches( "string", "^string$"));

// }

