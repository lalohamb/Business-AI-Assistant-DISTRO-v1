# Ollama-to-Gemini Workflow Configuration

## Current State

All 16 n8n workflows now use **local Ollama** (`qwen3:14b`) instead of Google's Gemini API. This means:

- No external API key required
- All AI processing stays on your machine
- No per-token costs
- Works offline
- Slower than Gemini (local inference vs cloud)

---

## How It Works

Each workflow has an HTTP Request node that calls Ollama's local API:

```
POST http://host.docker.internal:11434/api/generate
```

Request body format:
```json
{
  "model": "($env.OLLAMA_MODEL || 'qwen3:14b')",
  "prompt": "Your prompt text here...",
  "stream": false
}
```

The model is read from the `OLLAMA_MODEL` environment variable passed to the n8n container. If not set, falls back to `qwen3:14b`.

Response format:
```json
{
  "response": "The model's output text..."
}
```

---

## How to Switch Back to Gemini

### 1. Set your Google API key

Edit `.env` in the project root:

```bash
GOOGLE_API_KEY=your-actual-google-api-key-here
```

Get a key at: https://aistudio.google.com/apikey

### 2. Change the HTTP Request nodes

In each workflow JSON, replace the Ollama node pattern:

**From (Ollama):**
```json
{
  "method": "POST",
  "url": "http://host.docker.internal:11434/api/generate",
  "jsonBody": "={{ JSON.stringify({ model: 'qwen3:14b', prompt: '...', stream: false }) }}"
}
```

**To (Gemini):**
```json
{
  "method": "POST",
  "url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={{$env.GOOGLE_API_KEY}}",
  "jsonBody": "={{ JSON.stringify({ contents: [{ parts: [{ text: '...' }] }] }) }}"
}
```

### 3. Change the response parsing

Ollama returns `$json.response` — Gemini returns `$json.candidates[0].content.parts[0].text`.

**From (Ollama):**
```
{{ $json.response }}
```

**To (Gemini):**
```
{{ $json.candidates[0].content.parts[0].text }}
```

---

## Workflow Files Location

```
n8n/workflows/
├── standard/
│   ├── approval-router.json
│   ├── ask-assistant.json
│   ├── calendar-review.json
│   ├── daily-briefing.json
│   ├── email-triage.json
│   └── rag-query.json
└── selectable/
    ├── appointment-booking.json
    ├── customer-intake.json
    ├── document-drafting.json
    ├── expense-tracker.json
    ├── invoice-generator.json
    ├── lead-followup.json
    ├── report-generator.json
    ├── review-requester.json
    ├── social-post-scheduler.json
    └── voicemail-transcription.json
```

---

## Gemini Multimodal Features (Not Available in Ollama)

Two workflows originally used Gemini's multimodal capabilities:

| Workflow | Feature | Ollama Workaround |
|----------|---------|-------------------|
| expense-tracker | Image OCR (receipt photos) | Send `receipt_text` field with pre-extracted text instead of `receipt_base64` |
| voicemail-transcription | Audio transcription | Send `transcription_text` field with pre-transcribed text (use Whisper or RingCentral transcription) |

To restore these features, switch those two workflows back to Gemini and set `GOOGLE_API_KEY`.

---

## Changing the Model

All workflows use the `OLLAMA_MODEL` environment variable. To switch models for all workflows at once:

### 1. Edit `.env`

```bash
OLLAMA_MODEL=llama3:8b
```

### 2. Recreate the n8n container

```bash
docker stop n8n && docker rm n8n
docker run -d --name n8n \
  --restart unless-stopped \
  --add-host=host.docker.internal:host-gateway \
  -p 5678:5678 \
  -e OLLAMA_MODEL=llama3:8b \
  -e N8N_BASE_URL=http://localhost:5678 \
  -v "/home/ubuntu/.business-assistant-box/business-assistant-box/n8n:/home/node/.n8n" \
  docker.n8n.io/n8nio/n8n:latest
```

The workflows reference the model as:
```
model: ($env.OLLAMA_MODEL || 'qwen3:14b')
```

If `OLLAMA_MODEL` is not set, it falls back to `qwen3:14b`.

### Available models (run `ollama list` to see yours):
- `qwen3:14b` — current default, good quality, slower
- `qwen3:8b` — faster, slightly less capable
- `llama3:8b` — Meta's model, fast
- `mistral:7b` — good for structured JSON output

> **Note:** Changing `OLLAMA_MODEL` only affects n8n workflows. The Open WebUI chat model is selected independently in the UI dropdown.

---

## Quick Revert Script

To bulk-revert all workflows back to Gemini, run:

```bash
cd /home/ubuntu/.business-assistant-box/business-assistant-box

# Replace Ollama URLs with Gemini
find n8n/workflows -name "*.json" -exec sed -i \
  's|http://host.docker.internal:11434/api/generate|https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={{$env.GOOGLE_API_KEY}}|g' {} \;
```

> **Note:** This only changes the URL. You'd still need to manually update:
> - Request body format (wrap prompt in `{ contents: [{ parts: [{ text: ... }] }] }`)
> - Response parsing (`$json.response` → `$json.candidates[0].content.parts[0].text`)

For a clean revert, restore from backup:
```bash
cp -r business-assistant-box-backups/backup-*/business-assistant-box/n8n/workflows/ n8n/workflows/
```

---

## n8n Environment Variables

Environment variables are passed to n8n via `-e` flags when creating the container. After changing `.env`, you must recreate (not just restart) the container:

```bash
docker stop n8n && docker rm n8n
docker run -d --name n8n \
  --restart unless-stopped \
  --add-host=host.docker.internal:host-gateway \
  -p 5678:5678 \
  -e OLLAMA_MODEL=qwen3:14b \
  -e N8N_BASE_URL=http://localhost:5678 \
  -e GOOGLE_API_KEY=your-key-here \
  -v "/home/ubuntu/.business-assistant-box/business-assistant-box/n8n:/home/node/.n8n" \
  docker.n8n.io/n8nio/n8n:latest
```

Key variables:
| Variable | Purpose | Default |
|----------|---------|--------|
| `OLLAMA_MODEL` | Model used by all workflows | `qwen3:14b` |
| `N8N_BASE_URL` | n8n's own URL for internal webhooks | `http://localhost:5678` |
| `GOOGLE_API_KEY` | Only needed if switching back to Gemini | (empty) |
