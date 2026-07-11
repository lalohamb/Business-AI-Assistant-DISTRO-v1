-- Business Assistant Box - RAG Schema
-- Requires: CREATE EXTENSION vector;
-- Embedding dimensions: 768

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
  embedding vector(768),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chunks_client ON rag_chunks(client_name);
CREATE INDEX IF NOT EXISTS idx_chunks_embedding ON rag_chunks USING ivfflat (embedding vector_cosine_ops);
