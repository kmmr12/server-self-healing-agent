from fastapi import FastAPI
import requests, os

app = FastAPI()

@app.get("/api/ping")
async def ping():
    return {"status": "ok", "message": "automation bridge alive"}

@app.get("/api/ollama/test")
async def ollama_test():
    try:
        r = requests.get("http://127.0.0.1:5193/api/tags", timeout=3)
        return {"status": "success", "ollama_response": r.json()}
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.get("/api/n8n/test")
async def n8n_test():
    try:
        r = requests.get("http://127.0.0.1:5678", timeout=3)
        return {"status": "success", "n8n_code": r.status_code}
    except Exception as e:
        return {"status": "error", "detail": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5194)
