import ballerinax/openai.text;
configurable string openAIToken = ?;
    
class LLM{
    text:Client gpt3Client;
    function init() returns error? {
        self.gpt3Client = check new({auth: {token:openAIToken}});
    }

    function getClient() returns text:Client{
        return self.gpt3Client;
    }
}