
// openapi errors 
public type OpenApiParsingError distinct error;

public type ParsingStackOverflowError distinct OpenApiParsingError;

public type UnsupportedOpenApiVersion distinct OpenApiParsingError;

public type InvalidReferenceError distinct OpenApiParsingError;

public type IncompleteSpecificationError distinct OpenApiParsingError;

public type UnsupportedMediaTypeError distinct OpenApiParsingError;

// http toolkit errors
public type HttpResponseParsingError distinct error;
