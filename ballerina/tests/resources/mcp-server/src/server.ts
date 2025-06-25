// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { 
    Notification, 
    CallToolRequestSchema, 
    ListToolsRequestSchema, 
    LoggingMessageNotification, 
    ToolListChangedNotification, 
    JSONRPCNotification, 
    JSONRPCError, 
    InitializeRequestSchema 
} from "@modelcontextprotocol/sdk/types.js";
import { randomUUID } from "crypto";
import { Request, Response } from "express";

const SESSION_ID_HEADER_NAME = "mcp-session-id";
const JSON_RPC = "2.0";

export class MCPServer {
    server: Server;
    transports: {[sessionId: string]: StreamableHTTPServerTransport} = {};
    
    private toolInterval: NodeJS.Timeout | undefined;
    private singleGreetToolName = "single-greet";
    private multiGreetToolName = "multi-greet";

    constructor(server: Server) {
        this.server = server;
        this.setupTools();
    }

    async handleGetRequest(req: Request, res: Response) {
        console.log("get request received");
        
        const sessionId = req.headers['mcp-session-id'] as string | undefined;
        if (!sessionId || !this.transports[sessionId]) {
            res.status(400).json(this.createErrorResponse("Bad Request: invalid session ID or method."));
            return;
        }

        console.log(`Establishing SSE stream for session ${sessionId}`);
        const transport = this.transports[sessionId];
        await transport.handleRequest(req, res);
        await this.streamMessages(transport);
    }

    async handlePostRequest(req: Request, res: Response) {
        const sessionId = req.headers[SESSION_ID_HEADER_NAME] as string | undefined;

        console.log("post request received");
        console.log("body: ", req.body);

        try {
            // Reuse existing transport
            if (sessionId && this.transports[sessionId]) {
                const transport = this.transports[sessionId];
                await transport.handleRequest(req, res, req.body);
                return;
            }

            // Create new transport
            if (!sessionId && this.isInitializeRequest(req.body)) {
                const transport = new StreamableHTTPServerTransport({
                    sessionIdGenerator: () => randomUUID(),
                });

                await this.server.connect(transport);
                await transport.handleRequest(req, res, req.body);

                const newSessionId = transport.sessionId;
                if (newSessionId) {
                    this.transports[newSessionId] = transport;
                }
                return;
            }

            res.status(400).json(this.createErrorResponse("Bad Request: invalid session ID or method."));
        } catch (error) {
            console.error('Error handling MCP request:', error);
            res.status(500).json(this.createErrorResponse("Internal server error."));
        }
    }

    async cleanup() {
        this.toolInterval?.close();
        await this.server.close();
    }

    private setupTools() {
        const setToolSchema = () => this.server.setRequestHandler(ListToolsRequestSchema, async () => {
            this.singleGreetToolName = `single-greeting`;

            const singleGreetTool = {
                name: this.singleGreetToolName,
                description: "Greet a person with a name",
                inputSchema: {
                    type: "object",
                    properties: {
                        greetName: {
                            type: "string",
                            description: "name to greet"
                        },
                    },
                    required: ["greetName"]
                }
            };

            const multiGreetTool = {
                name: this.multiGreetToolName,
                description: "Greet the user multiple times with delay in between.",
                inputSchema: {
                    type: "object",
                    properties: {
                        greetName: {
                            type: "string",
                            description: "name to greet"
                        },
                    },
                    required: ["name"]
                }
            };

            return {
                tools: [singleGreetTool, multiGreetTool]
            };
        });

        setToolSchema();

        // Set tools dynamically, changing every 5 seconds
        this.toolInterval = setInterval(async () => {
            setToolSchema();
            
            Object.values(this.transports).forEach((transport) => {
                const notification: ToolListChangedNotification = {
                    method: "notifications/tools/list_changed",
                };
                this.sendNotification(transport, notification);
            });
        }, 5000);

        // Handle tool calls
        this.server.setRequestHandler(CallToolRequestSchema, async (request, extra) => {
            console.log("tool request received: ", request);
            console.log("extra: ", extra);

            const args = request.params.arguments;
            const toolName = request.params.name;
            const sendNotification = extra.sendNotification;

            if (!args) {
                throw new Error("arguments undefined");
            }

            if (!toolName) {
                throw new Error("tool name undefined");
            }

            if (toolName === this.singleGreetToolName) {
                const { greetName } = args;

                if (!greetName) {
                    throw new Error("Name to greet undefined.");
                }

                return {
                    content: [{
                        type: "text",
                        text: `Hey ${greetName}! Welcome to Ballerina!`
                    }]
                };
            }

            if (toolName === this.multiGreetToolName) {
                const { greetName } = args;
                const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

                let notification: LoggingMessageNotification = {
                    method: "notifications/message",
                    params: { level: "info", data: `First greet to ${greetName}` }
                };

                await sendNotification(notification);
                await sleep(1000);

                notification.params.data = `Second greet to ${greetName}`;
                await sendNotification(notification);
                await sleep(1000);

                return {
                    content: [{
                        type: "text",
                        text: `Hope you enjoy your day!`
                    }]
                };
            }

            throw new Error("Tool not found");
        });
    }

    private async streamMessages(transport: StreamableHTTPServerTransport) {
        try {
            const message: LoggingMessageNotification = {
                method: "notifications/message",
                params: { level: "info", data: "SSE Connection established" }
            };

            this.sendNotification(transport, message);

            let messageCount = 0;

            const interval = setInterval(async () => {
                messageCount++;
                const data = `Message ${messageCount} at ${new Date().toISOString()}`;

                const streamMessage: LoggingMessageNotification = {
                    method: "notifications/message",
                    params: { level: "info", data: data }
                };

                try {
                    this.sendNotification(transport, streamMessage);
                    console.log(`Sent: ${data}`);

                    if (messageCount === 2) {
                        clearInterval(interval);

                        const completeMessage: LoggingMessageNotification = {
                            method: "notifications/message",
                            params: { level: "info", data: "Streaming complete!" }
                        };

                        this.sendNotification(transport, completeMessage);
                        console.log("Stream completed");
                    }
                } catch (error) {
                    console.error("Error sending message:", error);
                    clearInterval(interval);
                }
            }, 1000);
        } catch (error) {
            console.error("Error sending message:", error);
        }
    }

    private async sendNotification(transport: StreamableHTTPServerTransport, notification: Notification) {
        const rpcNotification: JSONRPCNotification = {
            ...notification,
            jsonrpc: JSON_RPC,
        };
        await transport.send(rpcNotification);
    }

    private createErrorResponse(message: string): JSONRPCError {
        return {
            jsonrpc: '2.0',
            error: {
                code: -32000,
                message: message,
            },
            id: randomUUID(),
        };
    }

    private isInitializeRequest(body: any): boolean {
        const isInitial = (data: any) => {
            const result = InitializeRequestSchema.safeParse(data);
            return result.success;
        };
        
        if (Array.isArray(body)) {
            return body.some(request => isInitial(request));
        }
        
        return isInitial(body);
    }
}
