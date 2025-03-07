# Represents the interface of a memory manager.
public type MemoryManager isolated object {

    # Retrieves memory based on the given memory ID.
    #
    # + memoryId - The ID associated with the memory
    # + return - A `Memory` instance on success, otherwise an `agent:Error`
    public isolated function getMemory(string memoryId) returns Memory|MemoryError;
};

# Represents the memory interface for the agents.
public type Memory isolated object {
    # Retrieves all stored chat messages.
    # + return - An array of messages or an `agent:Error`
    public isolated function get() returns ChatMessage[]|MemoryError;

    # Adds a chat message to the memory.
    # + message - The message to store
    # + return - nil on success, or an `agent:Error` if the operation fails 
    public isolated function update(ChatMessage message) returns MemoryError?;

    # Deletes all stored messages.
    # + return - nil on success, or an `agent:Error` if the operation fails
    public isolated function delete() returns MemoryError?;
};

# Provides an in-memory chat message window with a limit on stored messages.
public isolated class MessageWindowChatMemory {
    *Memory;
    private final int size;
    private ChatSystemMessage? systemPrompt = ();
    private final ChatMessage[] memory = [];

    # Initializes a new memory window with a default or given size.
    # + size - The maximum capacity for stored messages
    public isolated function init(int size = 10) {
        self.size = size;
    }

    # Retrieves a copy of all stored messages, with an optional system prompt.
    # + return - A copy of the messages, or an `agent:Error`
    public isolated function get() returns ChatMessage[]|MemoryError {
        lock {
            ChatMessage[] memory = self.memory.clone();
            ChatSystemMessage? systemPrompt = self.systemPrompt;
            if systemPrompt is ChatSystemMessage {
                memory.unshift(systemPrompt);
            }
            return memory.clone();
        }
    }

    # Adds a message to the window.
    # + message - The `ChatMessage` to store or use as system prompt
    # + return - nil on success, or an `agent:Error` if the operation fails 
    public isolated function update(ChatMessage message) returns MemoryError? {
        lock {
            if message is ChatSystemMessage {
                self.systemPrompt = message.clone();
                return;
            }
            if self.memory.length() >= self.size - 1 {
                _ = self.memory.shift();
            }
            self.memory.push(message.clone());
        }
    }

    # Removes all messages from the memory.
    # + return - nil on success, or an `agent:Error` if the operation fails 
    public isolated function delete() returns MemoryError? {
        lock {
            self.memory.removeAll();
            self.systemPrompt = ();
        }
    }
}

# A default implementation of `agent:MemoryManager`.
public isolated class DefaultMessageWindowChatMemoryManager {
    *MemoryManager;
    private final map<MessageWindowChatMemory> sessions = {};
    private final int size;

    # Initializes a new `agent:DefaultMessageWindowChatMemoryManager`.
    #
    # + size - The maximum number of messages that can be stored in `agent:MessageWindowChatMemory`
    public isolated function init(int size = 10) {
        self.size = size;
    }

    # Retrieves memory based on the given memory ID.
    #
    # + memoryId - The ID associated with the memory
    # + return - A `Memory` instance on success, otherwise an `agent:Error`
    public isolated function getMemory(string memoryId) returns Memory|MemoryError {
        lock {
            if !self.sessions.hasKey(memoryId) {
                self.sessions[memoryId] = new MessageWindowChatMemory(self.size);
            }
            return self.sessions.get(memoryId);
        }
    }
}

isolated function getMemory(Memory|MemoryManager memory, string memoryId = "default") returns Memory|MemoryError {
    if memory is Memory {
        return memory;
    } 
    if memory is MemoryManager {
        return memory.getMemory(memoryId);
    }
    // This error is returned because type narrowing does not apply in this case
    return error MemoryError("Invalid memory type");
}
