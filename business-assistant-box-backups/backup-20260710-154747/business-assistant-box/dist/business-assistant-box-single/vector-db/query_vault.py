#!/usr/bin/env python3
"""Query the RAG database for relevant context."""

import os
import sys
import psycopg2
from pathlib import Path
from dotenv import load_dotenv

env_path = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(env_path)

BASE_PATH = os.getenv("BASE_PATH")
ACTIVE_CLIENT = os.getenv("ACTIVE_CLIENT", "my-business")
EMBEDDING_PROVIDER = os.getenv("EMBEDDING_PROVIDER", "ollama")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "nomic-embed-text")
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")

DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "user": "admin",
    "password": "strongpassword",
    "dbname": "businessassistant",
}


def get_embedding(text):
    """Get embedding vector from configured provider."""
    if EMBEDDING_PROVIDER == "ollama":
        import requests
        resp = requests.post(
            f"{OLLAMA_BASE_URL}/api/embeddings",
            json={"model": EMBEDDING_MODEL, "prompt": text},
        )
        resp.raise_for_status()
        return resp.json()["embedding"]
    else:
        raise NotImplementedError(f"Embedding provider \"{EMBEDDING_PROVIDER}\" not yet supported.")


def query(question, top_k=5):
    """Retrieve top-k relevant chunks for a question."""
    embedding = get_embedding(question)

    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    cur.execute(
        """
        SELECT title, source_path, chunk_text,
               1 - (embedding <=> %s::vector) AS similarity
        FROM rag_chunks
        WHERE client_name = %s
        ORDER BY embedding <=> %s::vector
        LIMIT %s
        """,
        (embedding, ACTIVE_CLIENT, embedding, top_k),
    )

    results = cur.fetchall()
    cur.close()
    conn.close()
    return results


def main():
    if len(sys.argv) < 2:
        print("Usage: python query_vault.py \"your question here\"")
        sys.exit(1)

    question = " ".join(sys.argv[1:])
    print(f"Query: {question}")
    print(f"Client: {ACTIVE_CLIENT}")
    print("-" * 50)

    results = query(question)

    if not results:
        print("No results found.")
        return

    for i, (title, source, chunk, similarity) in enumerate(results, 1):
        print(f"\n[{i}] {title} ({source})")
        print(f"    Similarity: {similarity:.4f}")
        print(f"    {chunk[:200]}...")


if __name__ == "__main__":
    main()
