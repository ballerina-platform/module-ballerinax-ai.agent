import ballerina/http;
import ballerinax/openai.text;

configurable string openAIToken = ?;
configurable string wifiServiceURL = ?;
configurable string wifiServiceKey = ?;

final http:Client wifiClient = check new (wifiServiceURL);

// agent is defined and used within the main function
public function sampleHttp() returns error? {
    text:CreateCompletionRequest config = {
        model: "text-davinci-003",
        max_tokens: 256,
        stop: "Observation",
        temperature: 0.3
    };

    GPT3Model model = new (check new ({auth: {token: openAIToken}}), config);

    HttpLoader loader = new (wifiClient, headers = {"API-Key": wifiServiceKey});
    Agent agent = new (model, loader);

    HttpAction listAction = {
        name: "List wifi",
        path: "/guest-wifi-accounts/{ownerEmail}",
        method: GET,
        description: "useful to list the guest wifi accounts."
    };

    HttpAction createAction = {
        name: "Create wifi",
        path: "/guest-wifi-accounts",
        method: POST,
        description: "useful to create a guest wifi account.",
        requestBody: {
            "email": "string",
            "username": "string",
            "password": "string"
        }
    };

    check loader.registerActions(listAction, createAction);

    string query = "create a new guest wifi with user newWifi and password abc123 and show available accounts. email is abc@wso2.com";

    check agent.run(query, maxIter = 2);
}
