#!/usr/bin/env python3
"""Query the RAG database for relevant context."""

import os
import sys
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

DB_CONFIG = {
    "host": os.getenv("PG_HOST", "localhost"),
    "port": int(os.getenv("PG_PORT", "5432")),
    "user": os.getenv("PG_USER", "admin"),
    "password": os.getenv("PG_PASSWORD", "strongpassword"),
    "dbname": os.getenv("PG_DATABASE", "businessassistant"),
}


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


def query(question, top_k=5):
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
        print('Usage: python query_vault.py "your question here"')
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
