# Represents the memory interface for the agents.
public type Memory isolated object {
    # Retrieves all stored chat messages.
    # + return - An array of `ChatMessage` or an `error`
    public isolated function get() returns ChatMessage[]|error;

    # Adds a chat message to the memory.
    # + message - The `ChatMessage` to store
    # + return - nil on success, or an `error` if the operation fails 
    public isolated function update(ChatMessage message) returns error?;

    # Deletes all stored messages.
    # + return - nil on success, or an `error` if the operation fails
    public isolated function delete() returns error?;
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
    # + return - A copy of the messages, or an `error`
    public isolated function get() returns ChatMessage[]|error {
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
    # + return - An `error?` if the update fails
    public isolated function update(ChatMessage message) returns error? {
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
    # + return - An `error?` if the operation fails
    public isolated function delete() returns error? {
        lock {
            self.memory.removeAll();
            self.systemPrompt = ();
        }
    }
}
