from pydantic import BaseModel


class ChatMessage(BaseModel):
    role: str  # "user", "assistant", or "system"
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    web_search: bool = False


class WSMessage(BaseModel):
    type: str  # "token", "done", "search_results", "error"
    content: str
    done: bool = False
