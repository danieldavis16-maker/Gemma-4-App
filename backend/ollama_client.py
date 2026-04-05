import json
from collections.abc import AsyncGenerator

import httpx

from config import MODEL_NAME, OLLAMA_BASE_URL


async def stream_chat(
    messages: list[dict], model: str = MODEL_NAME
) -> AsyncGenerator[str, None]:
    """Stream chat responses from Ollama token by token."""
    payload = {
        "model": model,
        "messages": messages,
        "stream": True,
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        async with client.stream(
            "POST",
            f"{OLLAMA_BASE_URL}/api/chat",
            json=payload,
        ) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if not line:
                    continue
                data = json.loads(line)
                token = data.get("message", {}).get("content", "")
                if token:
                    yield token
                if data.get("done", False):
                    break
