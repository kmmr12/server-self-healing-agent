from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
import httpx, asyncio, time

app = FastAPI(title="AI Agent Dashboard")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

templates = Jinja2Templates(directory="templates")

AGENTS = [
    {"id": "ollama", "port": 11434, "path": "/api/tags"},
    {"id": "automation_bridge", "port": 5194, "path": "/api/ping"},
    {"id": "n8n", "port": 5678, "path": "/api/ping"},
    {"id": "orchestrator_api", "port": 5950, "path": "/api/ping"},
    {"id": "code_builder", "port": 5742, "path": "/api/ping"},
    {"id": "dfs_intelligence", "port": 5990, "path": "/api/ping"},
]

async def ping_agents():
    async with httpx.AsyncClient(timeout=3.0) as client:
        tasks = [check_agent(client, a) for a in AGENTS]
        return await asyncio.gather(*tasks)

async def check_agent(client, a):
    url = f"http://127.0.0.1:{a['port']}{a['path']}"
    try:
        t0 = time.time()
        r = await client.get(url)
        latency = round((time.time() - t0) * 1000, 1)
        if 200 <= r.status_code < 300:
            return {"id": a["id"], "status": "up", "latency_ms": latency}
        else:
            return {"id": a["id"], "status": "error", "latency_ms": latency}
    except Exception:
        return {"id": a["id"], "status": "down", "latency_ms": None}

@app.get("/api/ping")
async def ping():
    return {"status": "ok", "message": "dashboard gui alive"}

@app.get("/api/agents")
async def agents():
    return {"agents": await ping_agents()}

@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5902)

from dfs_tab import router as dfs_router
app.include_router(dfs_router)

import sys
sys.path.append('/opt/gui_dashboard')
from dfs_tab import router as dfs_router
app.include_router(dfs_router)
