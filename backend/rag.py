import logging

import fitz  # pymupdf
import httpx
import chromadb

from config import CHROMA_PERSIST_DIR, EMBEDDING_MODEL, OLLAMA_BASE_URL, RAG_TOP_K

logger = logging.getLogger(__name__)

# Initialize ChromaDB with persistent storage
_client = chromadb.PersistentClient(path=CHROMA_PERSIST_DIR)
_collection = _client.get_or_create_collection(
    name="documents",
    metadata={"hnsw:space": "cosine"},
)


def extract_text(file_bytes: bytes, content_type: str) -> str:
    """Extract text from a file based on its content type."""
    if content_type == "application/pdf":
        doc = fitz.open(stream=file_bytes, filetype="pdf")
        text = ""
        for page in doc:
            text += page.get_text()
        doc.close()
        return text
    else:
        # TXT, MD, and other plain text formats
        return file_bytes.decode("utf-8")


def chunk_text(text: str, chunk_size: int = 1500, overlap: int = 200) -> list[str]:
    """Split text into overlapping chunks using a sliding window."""
    if len(text) <= chunk_size:
        return [text] if text.strip() else []

    chunks = []
    start = 0
    while start < len(text):
        end = start + chunk_size
        chunk = text[start:end].strip()
        if chunk:
            chunks.append(chunk)
        start += chunk_size - overlap

    return chunks


async def embed(texts: list[str]) -> list[list[float]]:
    """Generate embeddings for a list of texts using Ollama."""
    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            f"{OLLAMA_BASE_URL}/api/embed",
            json={"model": EMBEDDING_MODEL, "input": texts},
        )
        response.raise_for_status()
        data = response.json()
        return data["embeddings"]


async def ingest_document(filename: str, file_bytes: bytes, content_type: str) -> int:
    """Extract, chunk, embed, and store a document. Returns chunk count."""
    # Remove existing chunks for this filename (re-upload replaces)
    delete_document(filename)

    text = extract_text(file_bytes, content_type)
    if not text.strip():
        raise ValueError("No text could be extracted from the document.")

    chunks = chunk_text(text)
    if not chunks:
        raise ValueError("Document produced no chunks after processing.")

    embeddings = await embed(chunks)

    ids = [f"{filename}_chunk_{i}" for i in range(len(chunks))]
    metadatas = [{"filename": filename, "chunk_index": i} for i in range(len(chunks))]

    _collection.add(
        ids=ids,
        embeddings=embeddings,
        documents=chunks,
        metadatas=metadatas,
    )

    logger.info(f"Ingested '{filename}': {len(chunks)} chunks")
    return len(chunks)


async def retrieve(query: str, n_results: int = RAG_TOP_K) -> list[dict]:
    """Retrieve the most relevant document chunks for a query."""
    if _collection.count() == 0:
        return []

    query_embedding = await embed([query])

    results = _collection.query(
        query_embeddings=query_embedding,
        n_results=min(n_results, _collection.count()),
    )

    chunks = []
    for i in range(len(results["documents"][0])):
        chunks.append({
            "content": results["documents"][0][i],
            "filename": results["metadatas"][0][i]["filename"],
            "distance": results["distances"][0][i] if results.get("distances") else None,
        })

    return chunks


def format_rag_context(chunks: list[dict]) -> str:
    """Format retrieved chunks into a context string for the LLM."""
    if not chunks:
        return "No relevant documents found."

    lines = ["Here are relevant excerpts from your documents:\n"]
    for i, chunk in enumerate(chunks, 1):
        lines.append(f"[Source: {chunk['filename']}]")
        lines.append(f"{chunk['content']}\n")

    lines.append(
        "Use the above document excerpts to inform your response. "
        "Cite the source document when relevant."
    )
    return "\n".join(lines)


def list_documents() -> list[dict]:
    """List all ingested documents with their chunk counts."""
    if _collection.count() == 0:
        return []

    all_metadata = _collection.get()["metadatas"]
    doc_counts: dict[str, int] = {}
    for meta in all_metadata:
        name = meta["filename"]
        doc_counts[name] = doc_counts.get(name, 0) + 1

    return [{"filename": name, "chunk_count": count} for name, count in doc_counts.items()]


def delete_document(filename: str) -> None:
    """Remove all chunks for a given document."""
    _collection.delete(where={"filename": filename})
    logger.info(f"Deleted document: {filename}")
