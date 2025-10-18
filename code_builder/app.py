from fastapi import FastAPI, Request
import httpx, json

app = FastAPI(title="Code Builder Service")
OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
MODEL = "starcoder:15b"

@app.get("/api/ping")
async def ping():
    return {"status": "ok", "message": "code builder alive"}

@app.post("/api/build")
async def build(request: Request):
    data = await request.json()
    prompt = data.get("prompt", "")
    payload = {"model": MODEL, "prompt": prompt}
    async with httpx.AsyncClient() as c:
        r = await c.post(OLLAMA_URL, json=payload, timeout=60)
        return json.loads(r.text)
