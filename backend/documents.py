import logging

from fastapi import APIRouter, HTTPException, UploadFile

import rag

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/documents", tags=["documents"])

ALLOWED_TYPES = {
    "application/pdf",
    "text/plain",
    "text/markdown",
    "application/octet-stream",  # fallback for .md files
}
ALLOWED_EXTENSIONS = {".pdf", ".txt", ".md"}


@router.post("/upload")
async def upload_document(file: UploadFile):
    """Upload and ingest a document for RAG."""
    if not file.filename:
        raise HTTPException(status_code=400, detail="No filename provided.")

    ext = "." + file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else ""
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type '{ext}'. Allowed: {', '.join(ALLOWED_EXTENSIONS)}",
        )

    content_type = "application/pdf" if ext == ".pdf" else "text/plain"

    try:
        file_bytes = await file.read()
        chunk_count = await rag.ingest_document(file.filename, file_bytes, content_type)
        return {"filename": file.filename, "chunks_count": chunk_count, "status": "ok"}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Document upload failed: {e}")
        raise HTTPException(status_code=500, detail=f"Ingestion failed: {e}")


@router.get("/")
async def list_documents():
    """List all ingested documents."""
    return rag.list_documents()


@router.delete("/{filename}")
async def delete_document(filename: str):
    """Delete a document and all its chunks."""
    rag.delete_document(filename)
    return {"filename": filename, "status": "deleted"}
