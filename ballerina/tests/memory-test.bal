import ballerina/test;

@test:Config {}
function testMemoryInitialization() returns error? {
    MessageWindowChatMemory chatMemory = new (size = 5);
    ChatMessage[] history = check chatMemory.get();
    int memoryLength = history.length();
    test:assertEquals(memoryLength, 0);
}

@test:Config {}
function testMemoryUpdateSystemMesage() returns error? {
    MessageWindowChatMemory chatMemory = new (5);
    ChatUserMessage userMessage = {role: "user", content: "Hi im bob"};
    _ = check chatMemory.update(userMessage);
    ChatAssistantMessage assistantMessage = {role: "assistant", content: "Hello Bob! How can I assist you today?"};
    _ = check chatMemory.update(assistantMessage);
    ChatSystemMessage systemMessage = {role: "system", content: "You are an AI assistant to help users get answers. Respond to the human as helpfully and accurately as possible"};
    _ = check chatMemory.update(systemMessage);
    ChatMessage[] history = check chatMemory.get();
    test:assertEquals(history[0], systemMessage);
    test:assertEquals(history.length(), 3);
}

@test:Config {}
function testUpdateExceedMemorySize() returns error? {
    MessageWindowChatMemory chatMemory = new (3);
    ChatUserMessage userMessage = {role: "user", content: "Hi im bob"};
    _ = check chatMemory.update(userMessage);
    ChatAssistantMessage assistantMessage = {role: "assistant", content: "Hello Bob! How can I assist you today?"};
    _ = check chatMemory.update(assistantMessage);
    ChatSystemMessage systemMessage = {role: "system", content: "You are an AI assistant to help users get answers. Respond to the human as helpfully and accurately as possible"};
    _ = check chatMemory.update(systemMessage);
    ChatUserMessage userMessage2 = {role: "user", content: "Add teh numbers [2,3,4,5]"};
    _ = check chatMemory.update(userMessage2);
    ChatMessage[] history = check chatMemory.get();
    test:assertEquals(history[0], systemMessage);
    test:assertEquals(history[1], assistantMessage);
    test:assertEquals(history.length(), 3);
}

@test:Config {}
function testClearMemory() returns error? {
    MessageWindowChatMemory chatMemory = new (4);
    ChatUserMessage userMessage = {role: "user", content: "Hi im bob"};
    _ = check chatMemory.update(userMessage);
    ChatAssistantMessage assistantMessage = {role: "assistant", content: "Hello Bob! How can I assist you today?"};
    _ = check chatMemory.update(assistantMessage);
    ChatSystemMessage systemMessage = {role: "system", content: "You are an AI assistant to help users get answers. Respond to the human as helpfully and accurately as possible"};
    _ = check chatMemory.update(systemMessage);
    _ = check chatMemory.delete();
    test:assertEquals(chatMemory.get(), []);
}

@test:Config {}
function testClearEmptyMemory() returns error? {
    MessageWindowChatMemory chatMemory = new (4);
    _ = check chatMemory.delete();
    test:assertEquals(chatMemory.get(), []);
}
