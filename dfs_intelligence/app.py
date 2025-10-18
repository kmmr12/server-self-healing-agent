from fastapi import FastAPI

app = FastAPI(title="DFS Intelligence / Bet Advisor")

@app.get("/api/ping")
def ping():
    return {"status": "ok", "message": "DFS Intelligence alive"}

@app.get("/api/test")
def test():
    return {"game":"DAL@PHI","ou":48.5,"spread":"+2.5","note":"placeholder data"}
