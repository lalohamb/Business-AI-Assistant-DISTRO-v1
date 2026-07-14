-- Business Assistant Box - RAG Schema
-- Requires: CREATE EXTENSION vector;
-- Embedding dimensions: set by EMBEDDING_DIMENSIONS in .env (default 768)
-- If you change embedding model, update .env and re-run index_vault.py
-- which will recreate the table with the correct dimensions.

CREATE TABLE IF NOT EXISTS rag_documents (
  id SERIAL PRIMARY KEY,
  client_name VARCHAR(255) NOT NULL,
  source_path TEXT NOT NULL,
  title VARCHAR(500),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rag_chunks (
  id SERIAL PRIMARY KEY,
  document_id INTEGER REFERENCES rag_documents(id) ON DELETE CASCADE,
  client_name VARCHAR(255) NOT NULL,
  source_path TEXT NOT NULL,
  title VARCHAR(500),
  chunk_text TEXT NOT NULL,
  embedding vector(768),  -- dimension must match EMBEDDING_DIMENSIONS in .env
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chunks_client ON rag_chunks(client_name);
-- Note: ivfflat requires lists << row_count to work. For small datasets (<1000 rows),
-- use lists=16. For larger datasets, use sqrt(row_count). HNSW has no such limitation
-- but uses more memory. Index is created after data is inserted by index_vault.py.
-- CREATE INDEX IF NOT EXISTS idx_chunks_embedding ON rag_chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 16);
