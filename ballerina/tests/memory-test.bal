import ballerina/test;
import ballerina/io;

@test:Config {}
function testMemoryInitialization() returns error? {
    MessageWindowChatMemory chatMemory = new (size = 5);
    ChatMessage[] history = check chatMemory.get(DEFAULT_SESSION_ID);
    int memoryLength = history.length();
    test:assertEquals(memoryLength, 0);
}

@test:Config {}
function testMemoryUpdateSystemMesage() returns error? {
    MessageWindowChatMemory chatMemory = new (5);
    ChatUserMessage userMessage = {role: "user", content: "Hi im bob"};
    _ = check chatMemory.update(DEFAULT_SESSION_ID, userMessage);
    ChatAssistantMessage assistantMessage = {role: "assistant", content: "Hello Bob! How can I assist you today?"};
    _ = check chatMemory.update(DEFAULT_SESSION_ID, assistantMessage);
    ChatSystemMessage systemMessage = {role: "system", content: "You are an AI assistant to help users get answers. Respond to the human as helpfully and accurately as possible"};
    _ = check chatMemory.update(DEFAULT_SESSION_ID, systemMessage);
    ChatMessage[] history = check chatMemory.get(DEFAULT_SESSION_ID);
    test:assertEquals(history[0], systemMessage);
    test:assertEquals(history.length(), 3);
}

@test:Config {}
function testUpdateExceedMemorySize() returns error? {
    MessageWindowChatMemory chatMemory = new (3);
    ChatUserMessage userMessage = {role: "user", content: "Hi im bob"};
    _ = check chatMemory.update(DEFAULT_SESSION_ID, userMessage);
    ChatAssistantMessage assistantMessage = {role: "assistant", content: "Hello Bob! How can I assist you today?"};
    _ = check chatMemory.update(DEFAULT_SESSION_ID, assistantMessage);
    ChatSystemMessage systemMessage = {role: "system", content: "You are an AI assistant to help users get answers. Respond to the human as helpfully and accurately as possible"};
    _ = check chatMemory.update(DEFAULT_SESSION_ID, systemMessage);
    ChatUserMessage userMessage2 = {role: "user", content: "Add the numbers [2,3,4,5]"};
    _ = check chatMemory.update(DEFAULT_SESSION_ID, userMessage2);
    ChatMessage[] history = check chatMemory.get(DEFAULT_SESSION_ID);
    io:println("History: ", history);
    test:assertEquals(history[0], systemMessage);
    test:assertEquals(history[1], assistantMessage);
    test:assertEquals(history.length(), 3);
}

@test:Config {}
function testClearMemory() returns error? {
    MessageWindowChatMemory chatMemory = new (4);
    ChatUserMessage userMessage = {role: "user", content: "Hi im bob"};
    _ = check chatMemory.update(DEFAULT_SESSION_ID, userMessage);
    ChatAssistantMessage assistantMessage = {role: "assistant", content: "Hello Bob! How can I assist you today?"};
    _ = check chatMemory.update(DEFAULT_SESSION_ID, assistantMessage);
    ChatSystemMessage systemMessage = {role: "system", content: "You are an AI assistant to help users get answers. Respond to the human as helpfully and accurately as possible"};
    _ = check chatMemory.update(DEFAULT_SESSION_ID, systemMessage);
    _ = check chatMemory.delete(DEFAULT_SESSION_ID);
    test:assertEquals(chatMemory.get(DEFAULT_SESSION_ID), []);
}

@test:Config {}
function testClearEmptyMemory() returns error? {
    MessageWindowChatMemory chatMemory = new (4);
    _ = check chatMemory.delete(DEFAULT_SESSION_ID);
    test:assertEquals(chatMemory.get(DEFAULT_SESSION_ID), []);
}
