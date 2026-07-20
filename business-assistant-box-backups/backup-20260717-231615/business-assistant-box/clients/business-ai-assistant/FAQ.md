# FAQ.md

## Purpose

Quick answers about the Business Assistant Box platform.

---

## Setup & Installation

Q: How do I install Business Assistant Box?
A: Run `bash admin/install.sh` on a fresh Ubuntu 22.04+ system with at least 16GB RAM. The script installs Docker, Ollama, PostgreSQL, n8n, and Open WebUI automatically.

---

Q: What models are supported?
A: Any model available through Ollama. Default is qwen3:14b. Smaller options: qwen3:8b, llama3.1:8b. Larger: qwen3:30b, llama3.1:70b (requires 64GB+ RAM).

---

Q: How long does initial setup take?
A: About 15-30 minutes depending on internet speed (model download is ~8GB for qwen3:14b).

---

## Daily Usage

Q: How do I ask the assistant a question?
A: Open http://localhost:3000 in your browser and type your question. The assistant will search your indexed documents and respond with cited answers.

---

Q: How do I add new documents?
A: Place files in `clients/{ACTIVE_CLIENT}/DOCUMENTS/` in the appropriate subfolder, then run `python3 vector-db/index_vault.py` to index them.

---

Q: What if the assistant says "I don't have that information"?
A: The document containing that information hasn't been indexed. Add the relevant document and re-index.

---

Q: How do I get my daily briefing?
A: The daily-briefing workflow runs automatically via n8n. You can also trigger it manually from the n8n dashboard at http://localhost:5678.

---

## Administration

Q: How do I switch to a different client/business?
A: Edit `.env` and change `ACTIVE_CLIENT=your-client-folder`, then re-run `index_vault.py`.

---

Q: How do I change the AI model?
A: Edit `.env` and change `OLLAMA_MODEL=model-name`. Recreate the n8n container to pick up the change.

---

Q: How do I back up my data?
A: Back up the entire `business-assistant-box/` directory. The vector DB can be recreated from source documents by re-indexing.

---

Q: How do I update the system?
A: Pull the latest code, then re-run `bash admin/install.sh`. It's idempotent and won't destroy existing data.

---

## Troubleshooting

Q: The assistant is hallucinating / making things up.
A: Verify the RAG filter is enabled in Open WebUI → Functions. Check that `business_rag_filter.py` has the anti-hallucination prefix.

---

Q: Responses are very slow.
A: Try a smaller model (`OLLAMA_MODEL=qwen3:8b`). Check RAM usage with `free -h`. Ensure no other heavy processes are running.

---

Q: n8n workflows show "connection refused".
A: Verify Ollama is running (`curl http://localhost:11434/api/tags`). Check that the n8n container has the correct OLLAMA_BASE_URL environment variable.

---

## Maintenance

Review quarterly. Update as new features are added.
