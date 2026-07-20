#!/usr/bin/env python3
"""Index system and client files into PostgreSQL + pgvector."""

import os
import psycopg2
from pathlib import Path
from dotenv import load_dotenv

env_path = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(env_path, override=True)

BASE_PATH = os.getenv("BASE_PATH")
ACTIVE_CLIENT = os.getenv("ACTIVE_CLIENT", "demo-company")
EMBEDDING_PROVIDER = os.getenv("EMBEDDING_PROVIDER", "ollama")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "snowflake-arctic-embed:335m")
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")

EXCLUDE_DIRS = {"admin", "logs", "backups", "docker", "postgres", "node_modules", ".git", "venv"}
EXCLUDE_EXTENSIONS = {".key", ".pem"}
EXCLUDE_FILES = {".env"}

INDEX_PATHS = [
    os.path.join(BASE_PATH, "system"),
    os.path.join(BASE_PATH, "clients", ACTIVE_CLIENT),
]

DB_CONFIG = {
    "host": os.getenv("PG_HOST", "localhost"),
    "port": int(os.getenv("PG_PORT", "5432")),
    "user": os.getenv("PG_USER", "admin"),
    "password": os.getenv("PG_PASSWORD", "strongpassword"),
    "dbname": os.getenv("PG_DATABASE", "businessassistant"),
}


def get_files(paths):
    files = []
    for base in paths:
        if not os.path.exists(base):
            continue
        for root, dirs, filenames in os.walk(base):
            dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
            for f in filenames:
                if f in EXCLUDE_FILES:
                    continue
                ext = os.path.splitext(f)[1].lower()
                if ext in EXCLUDE_EXTENSIONS:
                    continue
                if ext in (".md", ".txt"):
                    files.append(os.path.join(root, f))
    return files


def chunk_text(text, chunk_size=512, overlap=64):
    chunks = []
    start = 0
    while start < len(text):
        chunks.append(text[start:start + chunk_size])
        start += chunk_size - overlap
    return [c for c in chunks if c.strip()]


def get_embedding(text):
    if EMBEDDING_PROVIDER == "ollama":
        import requests
        resp = requests.post(
            f"{OLLAMA_BASE_URL}/api/embeddings",
            json={"model": EMBEDDING_MODEL, "prompt": text},
        )
        resp.raise_for_status()
        return resp.json()["embedding"]
    raise NotImplementedError(f"Embedding provider '{EMBEDDING_PROVIDER}' not supported.")


def index():
    files = get_files(INDEX_PATHS)
    print(f"Found {len(files)} files to index.")

    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()
    cur.execute("DELETE FROM rag_chunks WHERE client_name = %s", (ACTIVE_CLIENT,))
    cur.execute("DELETE FROM rag_documents WHERE client_name = %s", (ACTIVE_CLIENT,))

    for filepath in files:
        with open(filepath, "r", errors="ignore") as f:
            content = f.read().strip()
        if not content:
            continue

        title = os.path.basename(filepath)
        rel_path = os.path.relpath(filepath, BASE_PATH)
        cur.execute(
            "INSERT INTO rag_documents (client_name, source_path, title) VALUES (%s, %s, %s) RETURNING id",
            (ACTIVE_CLIENT, rel_path, title),
        )
        doc_id = cur.fetchone()[0]

        chunks = chunk_text(content)
        for chunk in chunks:
            try:
                embedding = get_embedding(chunk)
            except Exception as e:
                print(f"  Embedding failed for chunk in {title}: {e}")
                continue
            cur.execute(
                "INSERT INTO rag_chunks (document_id, client_name, source_path, title, chunk_text, embedding) VALUES (%s, %s, %s, %s, %s, %s)",
                (doc_id, ACTIVE_CLIENT, rel_path, title, chunk, embedding),
            )
        print(f"  Indexed: {rel_path} ({len(chunks)} chunks)")

    conn.commit()

    # Rebuild vector index with correct lists parameter based on actual row count
    cur.execute("SELECT COUNT(*) FROM rag_chunks WHERE client_name = %s", (ACTIVE_CLIENT,))
    row_count = cur.fetchone()[0]
    lists = max(1, int(row_count ** 0.5))
    cur.execute("DROP INDEX IF EXISTS idx_chunks_embedding")
    cur.execute(f"CREATE INDEX idx_chunks_embedding ON rag_chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists={lists})")
    conn.commit()
    print(f"  Vector index rebuilt (lists={lists}, {row_count} chunks)")

    cur.close()
    conn.close()
    print("Indexing complete.")


if __name__ == "__main__":
    index()
