# Ballerina AI Module Examples: Personal AI Assistant

## Overview

This example demonstrates how to implement a personal AI assistant using Ballerina AI module along with Google Calendar and Gmail integrations. The assistant, named **Nova**, helps users manage their schedules and emails efficiently.

### Features

- **Email Management**: Access unread emails and send messages using the Ballerina Gmail connector.
- **Calendar Management**: Fetch upcoming events and schedule new ones via the Ballerina Google Calendar connector.
- **AI-Powered Assistance**: Leverages OpenAI's GPT-4o model for intelligent and contextual responses.

## Prerequisites

### 1. Obtain API Credentials

#### OpenAI API Key

- Sign up at [OpenAI](https://platform.openai.com/signup/).
- Get an API key from the [API section](https://platform.openai.com/docs/api-reference/authentication).

#### Google API Credentials

- Sign up on [Google](https://accounts.google.com/signup/).
- Follow [this guide](https://developers.google.com/identity/protocols/oauth2) to obtain a **Client ID, Client Secret, and Refresh Token**.
- Ensure you grant the necessary permissions for both Gmail and Calendar APIs.

### 2. Configure `Config.toml`

Create a `Config.toml` file in your project directory and add the following configurations:

```toml
[config]
googleRefreshToken = "<YOUR_GOOGLE_REFRESH_TOKEN>"
clientId = "<YOUR_GOOGLE_CLIENT_ID>"
clientSecret = "<YOUR_GOOGLE_CLIENT_SECRET>"
refreshUrl = "https://oauth2.googleapis.com/token"

openAiApiKey = "<YOUR_OPENAI_API_KEY>"

userName = "<YOUR_NAME>"
userEmail = "<YOUR_EMAIL>"
```

## Running the Personal AI Assistant

Start the service using the Ballerina runtime:

```sh
bal run
```

Once the service is running, you can interact with Nova through the AI agent API on port `9090`.

## Chat with Assistant

**Endpoint:** `POST /chat`

**Request Body:**

```json
{
  "message": "What are my upcoming meetings?",
  "sessionId": "12345"
}
```

**Response Example:**

```json
{
  "message": "You have a meeting with the team at 10:00 AM tomorrow."
}
```

## Code Structure

- **AI Agent Setup**: Defines Nova as an AI assistant with email and calendar management capabilities.
- **Google API Integrations**: Uses Ballerina connectors to interact with Gmail and Google Calendar.
- **AI System Prompt**: Provides specific instructions to ensure relevant and professional responses.
- **HTTP Service**: Listens for chat requests and processes them using the AI agent.

With this setup, you can extend Nova's capabilities by adding more tools and AI-driven functionalities!
