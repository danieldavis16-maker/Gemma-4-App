# Gemma 4 Chat - iOS App with FastAPI Backend

An iOS chat application powered by Google's Gemma 4 model running locally via Ollama, with DuckDuckGo web search integration.

## Architecture

```
iOS App (SwiftUI) <--WebSocket--> FastAPI Backend <--HTTP--> Ollama (Gemma 4)
                                       |
                                  DuckDuckGo Search
```

## Prerequisites

- Python 3.11+
- [Ollama](https://ollama.ai) installed and running
- Xcode 15+ (for iOS app)
- macOS (for iOS development)

## Backend Setup

1. Pull the Gemma model:
   ```bash
   ollama pull gemma3:4b
   ```

2. Start Ollama:
   ```bash
   ollama serve
   ```

3. Install Python dependencies:
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

4. Run the backend:
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```

## iOS Setup

1. Open `ios/Gemma4Chat/` in Xcode
2. Update the backend URL in `Services/WebSocketService.swift` to your machine's local IP
3. Build and run on simulator or device

## Features

- Real-time streaming chat with Gemma 4
- WebSocket-based communication for low-latency responses
- Toggle web search to augment AI responses with live web results
- DuckDuckGo integration (no API key required)
- Clean SwiftUI chat interface
