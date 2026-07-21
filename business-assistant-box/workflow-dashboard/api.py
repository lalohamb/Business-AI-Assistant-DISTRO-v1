"""
Workflow Dashboard API — proxy between dashboard UI and n8n webhooks.
Reads N8N_BASE_URL from /app/.env (mounted at runtime).
Reads workflow manifest from /app/manifest.json (mounted at runtime).
"""

import json
import os
from pathlib import Path

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse

load_dotenv("/app/.env")

N8N_BASE_URL = os.getenv("N8N_BASE_URL", "http://host.docker.internal:5678")
MANIFEST_PATH = Path("/app/manifest.json")
DASHBOARD_HTML = Path("/app/dashboard.html")

app = FastAPI(title="Workflow Dashboard", docs_url=None, redoc_url=None)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Webhook paths per workflow id — derived from actual workflow JSON paths
WEBHOOK_PATHS = {
    "daily-briefing":      ("POST", "/webhook/business/daily-briefing"),
    "email-triage":        ("POST", "/webhook/business/email-triage"),
    "calendar-review":     ("POST", "/webhook/business/calendar-review"),
    "customer-intake":     ("POST", "/webhook/business/customer-intake"),
    "invoice-generator":   ("POST", "/webhook/business/generate-invoice"),
    "lead-followup":       ("POST", "/webhook/business/lead-followup"),
    "document-drafting":   ("POST", "/webhook/business/document-drafting"),
    "appointment-booking": ("POST", "/webhook/business/appointment-booking"),
    "review-requester":    ("POST", "/webhook/business/review-requester"),
    "expense-tracker":     ("POST", "/webhook/business/expense-tracker"),
    "report-generator":    ("POST", "/webhook/business/report-generator"),
    "social-post-scheduler": ("POST", "/webhook/business/social-post-scheduler"),
    "voicemail-transcription": ("POST", "/webhook/business/voicemail-transcription"),
}


@app.get("/")
async def serve_dashboard():
    return FileResponse(DASHBOARD_HTML)


@app.get("/api/workflows")
async def get_workflows():
    if not MANIFEST_PATH.exists():
        raise HTTPException(status_code=500, detail="manifest.json not found")
    data = json.loads(MANIFEST_PATH.read_text())
    return JSONResponse(data)


@app.post("/api/run/{workflow_id}")
async def run_workflow(workflow_id: str, request: Request):
    if workflow_id not in WEBHOOK_PATHS:
        raise HTTPException(status_code=404, detail=f"No webhook configured for '{workflow_id}'")

    method, path = WEBHOOK_PATHS[workflow_id]
    url = f"{N8N_BASE_URL}{path}"

    try:
        body = await request.json()
    except Exception:
        body = {}

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(url, json=body)
        return JSONResponse(
            {"ok": True, "workflow_id": workflow_id, "status": resp.status_code,
             "detail": resp.text[:500] if resp.text else "triggered"},
            status_code=200,
        )
    except httpx.ConnectError:
        raise HTTPException(status_code=502, detail="Cannot reach n8n. Is it running?")
    except httpx.TimeoutException:
        # n8n accepted but took too long — still a success for fire-and-forget workflows
        return JSONResponse({"ok": True, "workflow_id": workflow_id, "detail": "triggered (timeout — workflow is running)"})
