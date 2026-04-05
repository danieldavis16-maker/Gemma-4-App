import json
import logging

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from documents import router as documents_router
from models import ChatRequest, WSMessage
from ollama_client import stream_chat
from rag import format_rag_context, retrieve
from search import format_search_context, web_search

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Gemma 4 Chat API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(documents_router)


@app.get("/api/health")
async def health_check():
    return {"status": "ok"}


@app.websocket("/ws/chat")
async def websocket_chat(websocket: WebSocket):
    await websocket.accept()
    logger.info("WebSocket connection established")

    try:
        while True:
            raw = await websocket.receive_text()
            data = json.loads(raw)
            request = ChatRequest(**data)

            messages = [m.model_dump() for m in request.messages]

            # If web search is enabled, search and prepend context
            if request.web_search and request.messages:
                query = request.messages[-1].content
                try:
                    results = await web_search(query)
                    context = format_search_context(results)

                    # Send search results to the client
                    await websocket.send_text(
                        WSMessage(
                            type="search_results", content=context
                        ).model_dump_json()
                    )

                    # Prepend search context as a system message
                    messages.insert(0, {"role": "system", "content": context})
                except Exception as e:
                    logger.error(f"Web search failed: {e}")
                    await websocket.send_text(
                        WSMessage(
                            type="error",
                            content=f"Web search failed: {e}",
                        ).model_dump_json()
                    )

            # If RAG is enabled, retrieve relevant document chunks
            if request.rag and request.messages:
                query = request.messages[-1].content
                try:
                    chunks = await retrieve(query)
                    context = format_rag_context(chunks)

                    await websocket.send_text(
                        WSMessage(
                            type="rag_context", content=context
                        ).model_dump_json()
                    )

                    messages.insert(0, {"role": "system", "content": context})
                except Exception as e:
                    logger.error(f"RAG retrieval failed: {e}")
                    await websocket.send_text(
                        WSMessage(
                            type="error",
                            content=f"RAG retrieval failed: {e}",
                        ).model_dump_json()
                    )

            # Stream response from Ollama
            try:
                async for token in stream_chat(messages):
                    await websocket.send_text(
                        WSMessage(
                            type="token", content=token
                        ).model_dump_json()
                    )

                # Signal completion
                await websocket.send_text(
                    WSMessage(
                        type="done", content="", done=True
                    ).model_dump_json()
                )
            except Exception as e:
                logger.error(f"Ollama streaming failed: {e}")
                await websocket.send_text(
                    WSMessage(
                        type="error",
                        content=f"Failed to get response from Gemma: {e}",
                    ).model_dump_json()
                )

    except WebSocketDisconnect:
        logger.info("WebSocket connection closed")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
