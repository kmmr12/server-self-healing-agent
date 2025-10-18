#!/usr/bin/env python3
from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from pathlib import Path
import pandas as pd
import subprocess

router = APIRouter()
BASE = Path("/opt/dfs_advisor")
OUT  = BASE / "output"
LOG  = BASE / "logs/phase10_predict.log"

@router.get("/dfs", response_class=HTMLResponse)
async def dfs_dashboard(request: Request):
    def render_table(path: Path):
        if not path.exists():
            return "<em>No data yet</em>"
        try:
            df = pd.read_csv(path).head(30)
            return df.to_html(classes="table table-striped", index=False)
        except Exception as e:
            return f"<pre>Error reading {path.name}: {e}</pre>"

    tables = {}
    for f in OUT.glob("*_rankings*.csv"):
        tables[f.name] = render_table(f)

    try:
        logs = "\n".join(LOG.read_text().splitlines()[-20:])
    except Exception:
        logs = "(no logs found)"

    html = request.app.jinja_env.get_template("dfs_tab.html").render(
        request=request,
        tables=tables,
        logs=logs
    )
    return HTMLResponse(html)

@router.get("/dfs/run")
async def run_predictive_engine():
    subprocess.run(
        ["/opt/dfs_advisor/venv/bin/python3", "/opt/dfs_advisor/dfs_predictive_engine.py"]
    )
    return RedirectResponse(url="/dfs")
