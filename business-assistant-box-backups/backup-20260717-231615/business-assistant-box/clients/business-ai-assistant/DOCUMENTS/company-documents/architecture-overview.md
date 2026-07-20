# Business Assistant Box — Architecture Overview

## System Components

### Open WebUI (Port 3000)
The user-facing chat interface. Handles authentication, conversation history, and function/filter pipelines. The RAG filter intercepts every message to inject relevant business context.

### Ollama (Port 11434)
Local LLM inference engine. Runs models like qwen3:14b entirely on the host machine. No data leaves the system. Provides both chat completions and embedding generation.

### PostgreSQL + pgvector (Port 5432)
Stores document embeddings as vectors. Enables semantic similarity search — finding the most relevant document chunks for any user question. Uses ivfflat indexing for fast approximate nearest-neighbor search.

### n8n (Port 5678)
Visual workflow automation. Handles scheduled tasks (daily briefings), triggered actions (email processing), and multi-step business processes. All workflows use local Ollama for AI operations.

## Data Privacy

All processing happens locally. The system makes zero external API calls unless the user explicitly configures a cloud provider (e.g., Gemini). Documents, embeddings, conversations, and workflow data never leave the host machine.

## Deployment Model

Single-machine deployment using Docker containers for WebUI, PostgreSQL, and n8n. Ollama runs natively on the host for direct GPU access. All services communicate over localhost.
