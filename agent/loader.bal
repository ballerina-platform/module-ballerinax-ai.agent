import ballerina/http;

public enum HttpMethod {
    GET, POST, DELETE
}

public type Headers record {|
    string|string[]...;
|};

public type Parameters record {|
    string|string[]...;
|};

public type HttpAction record {|
    string name;
    string description;
    string path;
    HttpMethod method;
    Parameters queryParams = {};
    json payloadSchema = {};
|};

type HttpInput record {
    *InputSchema;
    string path;
    Parameters queryParams?;
    Headers headers?;
    json payload = {};
};

public type ActionLoader distinct object {
    ActionStore actionStore;
    function getStore() returns ActionStore;
};

public class HttpLoader {
    *ActionLoader;
    private Headers headers;
    private http:Client httpClient;

    public function init(http:Client httpClient, Headers headers = {}) {
        self.actionStore = new;
        self.headers = headers;
        self.httpClient = httpClient;
    }

    function getStore() returns ActionStore {
        return self.actionStore;
    }

    public function registerActions(HttpAction... httpActions) returns error? {
        foreach HttpAction httpAction in httpActions {
            HttpInput httpIn = {
                path: httpAction.path,
                queryParams: httpAction.queryParams
            };
            function httpCaller = self.get;
            match httpAction.method {
                GET => {
                    // do nothing (default)
                }
                POST => {
                    httpIn.payload = httpAction.payloadSchema;
                    httpCaller = self.post;

                }
                DELETE => {
                    httpIn.payload = httpAction.payloadSchema;
                    httpCaller = self.delete;

                }
                _ => {
                    return error("invalid http type");
                }
            }

            Action action = {
                name: httpAction.name,
                description: httpAction.description + " Path parameters should be replaced with appropriate values",
                inputs: httpIn,
                caller: httpCaller
            };
            self.actionStore.registerActions(action);
        }

    }

    function get(*HttpInput httpInput) returns string|error {
        // TODO need a way to use query params. Waiting for an solution in discord channel.
        http:Response|http:ClientError getResult = self.httpClient->get(httpInput.path, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

    function post(*HttpInput httpInput) returns string|error {
        // TODO need a way to use query params. Waiting for an solution in discord channel.
        http:Response|http:ClientError getResult = self.httpClient->post(httpInput.path, message = httpInput.payload, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

    function delete(*HttpInput httpInput) returns string|error {
        // TODO need a way to use query params. Waiting for an solution in discord channel.
        http:Response|http:ClientError getResult = self.httpClient->post(httpInput.path, message = httpInput.payload, headers = self.headers);
        if getResult is http:Response {
            return getResult.getTextPayload();
        } else {
            return getResult.message();
        }
    }

}