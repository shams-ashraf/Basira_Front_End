import os
from datetime import datetime

from fastapi import APIRouter, File, Form, UploadFile

from .runtime import run_vit

router = APIRouter()


@router.post("/run")
async def run(file: UploadFile = File(...), child_id: str = Form("unknown")):
    contents = await file.read()
    temp_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "storage"))
    os.makedirs(temp_dir, exist_ok=True)
    temp_path = os.path.join(temp_dir, f"vit_{child_id}_{datetime.now().timestamp()}.jpg")
    with open(temp_path, "wb") as handle:
        handle.write(contents)
    caption, elapsed = run_vit(temp_path)
    try:
        os.remove(temp_path)
    except Exception:
        pass
    return {
        "success": True,
        "timestamp": datetime.now().isoformat(),
        "vit_caption": caption,
        "vit_time_ms": elapsed,
    }
