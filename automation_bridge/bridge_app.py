from fastapi import FastAPI, Request
import requests, os
app = FastAPI()
OLLAMA_URL = "http://127.0.0.1:11434/api/generate"

@app.get("/health")
def health(): return {"status": "ok", "bridge": True}

@app.post("/generate")
def generate(req: Request):
    data = requests.json.loads(req.body())
    prompt = data.get("prompt", "")
    r = requests.post(OLLAMA_URL, json={"model":"mistral","prompt":prompt})
    return r.json()
