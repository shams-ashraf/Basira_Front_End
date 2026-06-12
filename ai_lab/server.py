from datetime import datetime
import os
import sys
import traceback
from pathlib import Path

AI_LAB_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = AI_LAB_DIR.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

MODEL_ROOT = Path(r"E:\voice_test\ai_lab\models")
MODEL_ROOT.mkdir(parents=True, exist_ok=True)
os.environ["HF_HOME"] = str(MODEL_ROOT)
os.environ["HUGGINGFACE_HUB_CACHE"] = str(MODEL_ROOT)
os.environ["TRANSFORMERS_CACHE"] = str(MODEL_ROOT)

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from object_detection.detector import router as object_detection_router
from scene_summary.blip_model import router as blip_router
from scene_summary.florence_model import router as florence_router
from scene_summary.runtime import run_blip, run_florence, run_vit
from scene_summary.vit_model import router as vit_router

app = FastAPI(title="AI Lab", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(object_detection_router, prefix="/object-detection")
app.include_router(blip_router, prefix="/scene-summary/blip")
app.include_router(vit_router, prefix="/scene-summary/vit")
app.include_router(florence_router, prefix="/scene-summary/florence")

_root = os.path.dirname(__file__)
app.mount("/storage", StaticFiles(directory=os.path.join(_root, "storage")), name="storage")


@app.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.now().isoformat()}


@app.post("/scene-summary/run")
async def scene_summary_run(file: UploadFile = File(...), child_id: str = Form("unknown")):
    temp_path = None
    try:
        temp_dir = MODEL_ROOT / "scene_requests"
        temp_dir.mkdir(parents=True, exist_ok=True)
        temp_path = temp_dir / f"{child_id}_{datetime.now().timestamp()}.jpg"
        contents = await file.read()
        temp_path.write_bytes(contents)
        blip_caption, blip_time_ms = run_blip(str(temp_path))
        vit_caption, vit_time_ms = run_vit(str(temp_path))
        florence_caption, florence_time_ms = run_florence(str(temp_path))
        return {
            "blip": {"caption": blip_caption, "time_ms": blip_time_ms},
            "vit": {"caption": vit_caption, "time_ms": vit_time_ms},
            "florence": {"caption": florence_caption, "time_ms": florence_time_ms},
            "step_logs": [
                {"title": "BLIP", "result": [blip_caption or "No caption"]},
                {"title": "ViT-GPT2", "result": [vit_caption or "No caption"]},
                {"title": "Florence", "result": [florence_caption or "No caption"]},
            ],
        }
    except Exception as exc:
        return {
            "success": False,
            "error": str(exc),
            "traceback": traceback.format_exc(),
            "step_logs": [{"title": "Error", "result": [str(exc)]}],
        }
    finally:
        if temp_path is not None:
            try:
                temp_path.unlink()
            except Exception:
                pass
