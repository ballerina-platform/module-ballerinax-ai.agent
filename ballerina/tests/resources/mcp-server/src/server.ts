import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { Notification, CallToolRequestSchema, ListToolsRequestSchema, LoggingMessageNotification, ToolListChangedNotification, JSONRPCNotification, JSONRPCError, InitializeRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { randomUUID } from "crypto";
import { Request, Response } from "express"

const SESSION_ID_HEADER_NAME = "mcp-session-id"
const JSON_RPC = "2.0"

export class MCPServer {
    server: Server

    // to support multiple simultaneous connections
    transports: {[sessionId: string]: StreamableHTTPServerTransport} = {}

    private toolInterval: NodeJS.Timeout | undefined
    private singleGreetToolName = "single-greet"
    private multiGreetToolName = "multi-great"


    constructor(server: Server) {
        this.server = server
        this.setupTools()
    }

    async handleGetRequest(req: Request, res: Response) {
        console.log("get request received")
        // if server does not offer an SSE stream at this endpoint.
        // res.status(405).set('Allow', 'POST').send('Method Not Allowed')

        const sessionId = req.headers['mcp-session-id'] as string | undefined
        if (!sessionId || !this.transports[sessionId]) {
            res.status(400).json(this.createErrorResponse("Bad Request: invalid session ID or method."))
            return
        }

        console.log(`Establishing SSE stream for session ${sessionId}`)
        const transport = this.transports[sessionId]
        await transport.handleRequest(req, res)
        await this.streamMessages(transport)

        return
    }

    async handlePostRequest(req: Request, res: Response) {
        const sessionId = req.headers[SESSION_ID_HEADER_NAME] as string | undefined

        console.log("post request received")
        console.log("body: ", req.body)

        let transport: StreamableHTTPServerTransport

        try {
            // reuse existing transport
            if (sessionId && this.transports[sessionId]) {
                transport = this.transports[sessionId]
                await transport.handleRequest(req, res, req.body)
                return
            }

            // create new transport
            if (!sessionId && this.isInitializeRequest(req.body)) {
                const transport = new StreamableHTTPServerTransport({
                    sessionIdGenerator: () => randomUUID(),
                    // for stateless mode:
                    // sessionIdGenerator: () => undefined
                })

                await this.server.connect(transport)
                await transport.handleRequest(req, res, req.body)

                // session ID will only be available (if in not Stateless-Mode)
                // after handling the first request
                const sessionId = transport.sessionId
                if (sessionId) {
                    this.transports[sessionId] = transport
                }

                return
            }

            res.status(400).json(this.createErrorResponse("Bad Request: invalid session ID or method."))
            return

        } catch (error) {

            console.error('Error handling MCP request:', error)
            res.status(500).json(this.createErrorResponse("Internal server error."))
            return
        }
    }

    async cleanup() {
        this.toolInterval?.close()
        await this.server.close()
    }

    private setupTools() {

        // Define available tools
        const setToolSchema = () => this.server.setRequestHandler(ListToolsRequestSchema, async () => {
            this.singleGreetToolName = `single-greeting`

            // tool that returns a single greeting
            const singleGreetTool = {
                name: this.singleGreetToolName,
                description: "Greet the user once.",
                inputSchema: {
                    type: "object",
                    properties: {
                        name: {
                            type: "string" ,
                            description: "name to greet"
                        },
                    },
                    required: ["name"]
                }
            }

            // tool that sends multiple greetings with notifications
            const multiGreetTool = {
                name: this.multiGreetToolName,
                description: "Greet the user multiple times with delay in between.",
                inputSchema: {
                    type: "object",
                    properties: {
                        name: {
                            type: "string" ,
                            description: "name to greet"
                        },
                    },
                    required: ["name"]
                }
            }

            return {
                tools: [singleGreetTool, multiGreetTool]
            }
        })

        setToolSchema()

        // set tools dynamically, changing 5 second
        this.toolInterval = setInterval(async () => {
            setToolSchema()
            // to notify client that the tool changed
            Object.values(this.transports).forEach((transport) => {

                const notification: ToolListChangedNotification = {
                    method: "notifications/tools/list_changed",
                }
                this.sendNotification(transport, notification)
            })
        }, 5000)

        // handle tool calls
        this.server.setRequestHandler(CallToolRequestSchema, async (request, extra) => {
            console.log("tool request received: ", request)
            console.log("extra: ", extra)

            const args = request.params.arguments
            const toolName = request.params.name
            const sendNotification = extra.sendNotification

            if (!args) {
                throw new Error("arguments undefined")
            }

            if (!toolName) {
                throw new Error("tool name undefined")
            }

            if (toolName === this.singleGreetToolName) {

                const { name } = args

                if (!name) {
                    throw new Error("Name to greet undefined.")
                }

                return {
                    content: [ {
                        type: "text",
                        text: `Hey ${name}! Welcome to itsuki's world!`
                    }]
                }
            }

            if (toolName === this.multiGreetToolName) {
                const { name } = args
                const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms))

                let notification: LoggingMessageNotification = {
                    method: "notifications/message",
                    params: { level: "info", data: `First greet to ${name}` }
                }

                await sendNotification(notification)

                await sleep(1000)

                notification.params.data = `Second greet to ${name}`
                await sendNotification(notification);

                await sleep(1000)

                return {
                    content: [ {
                        type: "text",
                        text: `Hope you enjoy your day!`
                    }]
                }
            }

            throw new Error("Tool not found")
        })
    }


    // send message streaming message every second
    // cannot use server.sendLoggingMessage because we have can have multiple transports
    private async streamMessages(transport: StreamableHTTPServerTransport) {
        try {
            // based on LoggingMessageNotificationSchema to trigger setNotificationHandler on client
            const message: LoggingMessageNotification = {
                method: "notifications/message",
                params: { level: "info", data: "SSE Connection established" }
            }

            this.sendNotification(transport, message)

            let messageCount = 0

            const interval = setInterval(async () => {

                messageCount++

                const data = `Message ${messageCount} at ${new Date().toISOString()}`

                const message: LoggingMessageNotification = {
                    method: "notifications/message",
                    params: { level: "info", data: data }
                }


                try {

                    this.sendNotification(transport, message)

                    console.log(`Sent: ${data}`)

                    if (messageCount === 2) {
                        clearInterval(interval)

                        const message: LoggingMessageNotification = {
                            method: "notifications/message",
                            params: { level: "info", data: "Streaming complete!" }
                        }

                        this.sendNotification(transport, message)

                        console.log("Stream completed")
                    }

                } catch (error) {
                    console.error("Error sending message:", error)
                    clearInterval(interval)
                }

            }, 1000)

        } catch (error) {
            console.error("Error sending message:", error)
        }
    }


    private async sendNotification(transport: StreamableHTTPServerTransport, notification: Notification) {
        const rpcNotificaiton: JSONRPCNotification = {
            ...notification,
            jsonrpc: JSON_RPC,
        }
        await transport.send(rpcNotificaiton)
    }


    private createErrorResponse(message: string): JSONRPCError {
        return {
            jsonrpc: '2.0',
            error: {
              code: -32000,
              message: message,
            },
            id: randomUUID(),
        }
    }

    private isInitializeRequest(body: any): boolean {
        const isInitial = (data: any) => {
            const result = InitializeRequestSchema.safeParse(data)
            return result.success
        }
        if (Array.isArray(body)) {
          return body.some(request => isInitial(request))
        }
        return isInitial(body)
    }

}
