import os
import io
import time
import torch
from PIL import Image
from datetime import datetime
from ultralytics import YOLO
from transformers import (
    VisionEncoderDecoderModel,
    ViTImageProcessor,
    GPT2TokenizerFast,
    BlipProcessor,
    BlipForConditionalGeneration,
)
import gc
import traceback
from peft import PeftModel

# Set HF cache to E: drive to avoid C: drive space issues
os.environ["HF_HOME"] = "E:/hf_cache"

_SCENE_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "scene")
)

# ViT+GPT2  — local fine-tuned model (scene/final_model)
VIT_MODEL_PATH = os.path.join(_SCENE_DIR, "final_model")

# BLIP+LoRA — Salesforce base + LoRA adapter (scene/blip_model)
BLIP_BASE_MODEL = "Salesforce/blip-image-captioning-base"
BLIP_ADAPTER_PATH = os.path.join(_SCENE_DIR, "blip_model")

# Florence-2 — local model (scene/florence_model)
FLORENCE_MODEL_PATH = os.path.join(_SCENE_DIR, "florence_model")

# Florence-2 — local model (scene/florence_model)
FLORENCE_MODEL_PATH = os.path.join(_SCENE_DIR, "florence_model")


class VisionService:
    _instance = None
    _is_processing = False

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(VisionService, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return

        print("Loading YOLO Model in BaseraBack...")
        self.device = "cuda" if torch.cuda.is_available() else "cpu"

        # YOLO — lazy loaded
        self.yolo_model = None

        # Initialize all model placeholders first to avoid AttributeError
        self.vit_model = None
        self.vit_processor = None
        self.vit_tokenizer = None
        
        self.blip_model = None
        self.blip_processor = None
        
        self.florence_model = None
        self.florence_processor = None

        # ViT+GPT2 — lazy
        # self._load_vit_model()

        # BLIP+LoRA — lazy
        # self._load_blip_model()

        # Florence-2 — lazy
        # self._load_florence_model()

        self._initialized = True
        print(f"[VisionService] ViT path:  {VIT_MODEL_PATH} (exists={os.path.exists(VIT_MODEL_PATH)})")
        print(f"[VisionService] BLIP path: {BLIP_ADAPTER_PATH} (exists={os.path.exists(BLIP_ADAPTER_PATH)})")

    # ------------------------------------------------------------------
    # Lazy loaders
    # ------------------------------------------------------------------

    def _unload_other_models(self, keep_model: str):
        """Unload inactive models to save memory."""
        unloaded = False
        import gc
        
        if keep_model != 'yolo' and getattr(self, 'yolo_model', None) is not None:
            print("[VisionService] Unloading YOLO from memory...")
            del self.yolo_model
            self.yolo_model = None
            unloaded = True
        if keep_model != 'vit' and getattr(self, 'vit_model', None) is not None:
            print("[VisionService] Unloading ViT+GPT2 from memory...")
            del self.vit_model
            del self.vit_processor
            del self.vit_tokenizer
            self.vit_model = self.vit_processor = self.vit_tokenizer = None
            unloaded = True
            
        if keep_model != 'blip' and getattr(self, 'blip_model', None) is not None:
            print("[VisionService] Unloading BLIP+LoRA from memory...")
            del self.blip_model
            del self.blip_processor
            self.blip_model = self.blip_processor = None
            unloaded = True
            
        if keep_model != 'florence' and getattr(self, 'florence_model', None) is not None:
            print("[VisionService] Unloading Florence-2 from memory...")
            del self.florence_model
            del self.florence_processor
            self.florence_model = self.florence_processor = None
            unloaded = True
            
        if unloaded:
            gc.collect()
            if torch.cuda.is_available():
                torch.cuda.empty_cache()

    def _load_yolo_model(self):
        """YOLOv8n — local lightweight model"""
        self._unload_other_models('yolo')
        if self.yolo_model is not None:
            return
        print("[VisionService] Lazy-loading YOLOv8...")
        try:
            self.yolo_model = YOLO("yolov8n.pt")
            print(f"[VisionService] ✅ YOLOv8 loaded")
        except Exception as e:
            print(f"[VisionService] ❌ YOLOv8 load error: {e}")
            traceback.print_exc()
            self.yolo_model = None

    def _load_vit_model(self):
        """ViT+GPT2 — scene/final_model"""
        self._unload_other_models('vit')
        if self.vit_model is not None:
            return
        print(f"[VisionService] Lazy-loading ViT+GPT2 from: {VIT_MODEL_PATH}")
        try:
            self.vit_processor = ViTImageProcessor.from_pretrained(VIT_MODEL_PATH)
            self.vit_tokenizer = GPT2TokenizerFast.from_pretrained(VIT_MODEL_PATH)
            self.vit_model = VisionEncoderDecoderModel.from_pretrained(
                VIT_MODEL_PATH, 
                torch_dtype=torch.float16 if self.device == "cuda" else torch.float32
            )
            self.vit_model.to(self.device).eval()
            print(f"[VisionService] ✅ ViT+GPT2 loaded on {self.device}")
        except Exception as e:
            print(f"[VisionService] ❌ ViT+GPT2 load error: {e}")
            traceback.print_exc()
            self.vit_model = self.vit_processor = self.vit_tokenizer = None

    def _load_blip_model(self):
        """BLIP+LoRA — Salesforce/blip-image-captioning-base + scene/blip_model adapter"""
        self._unload_other_models('blip')
        if self.blip_model is not None:
            return
        print(f"[VisionService] Lazy-loading BLIP+LoRA adapter from: {BLIP_ADAPTER_PATH}")
        try:
            self.blip_processor = BlipProcessor.from_pretrained(BLIP_BASE_MODEL)
            base = BlipForConditionalGeneration.from_pretrained(
                BLIP_BASE_MODEL,
                torch_dtype=torch.float16 if self.device == "cuda" else torch.float32
            )
            self.blip_model = PeftModel.from_pretrained(base, BLIP_ADAPTER_PATH)
            self.blip_model.to(self.device).eval()
            print(f"[VisionService] ✅ BLIP+LoRA loaded on {self.device}")
        except Exception as e:
            print(f"[VisionService] ❌ BLIP+LoRA load error: {e}")
            traceback.print_exc()
            self.blip_model = self.blip_processor = None

    def _load_florence_model(self):
        """Florence-2 — cached to local dir"""
        self._unload_other_models('florence')
        if self.florence_model is not None:
            return
        print("[VisionService] Lazy-loading Florence-2...")
        try:
            from transformers import AutoProcessor, AutoModelForCausalLM
            self.florence_processor = AutoProcessor.from_pretrained(
                FLORENCE_MODEL_PATH, trust_remote_code=True
            )
            self.florence_model = AutoModelForCausalLM.from_pretrained(
                FLORENCE_MODEL_PATH,
                trust_remote_code=True,
                torch_dtype=torch.float16 if self.device == "cuda" else torch.float32,
            ).to(self.device)
            self.florence_model.eval()
            print(f"[VisionService] ✅ Florence-2 loaded on {self.device}")
        except Exception as e:
            print(f"[VisionService] ❌ Florence-2 load error: {e}")
            traceback.print_exc()
            self.florence_model = self.florence_processor = None

    # ------------------------------------------------------------------
    # Properties
    # ------------------------------------------------------------------

    @property
    def is_processing(self) -> bool:
        return self._is_processing

    # ------------------------------------------------------------------
    # YOLO detection
    # ------------------------------------------------------------------

    def detect_objects(self, image_path: str) -> list:
        """Run YOLOv8 on a file path."""
        self._is_processing = True
        try:
            self._load_yolo_model()
            if self.yolo_model is None:
                return []
            results = self.yolo_model(image_path, verbose=False)
            detections = []
            for r in results:
                for box in r.boxes:
                    cls = int(box.cls[0])
                    detections.append({
                        "label": self.yolo_model.names[cls],
                        "confidence": round(float(box.conf[0]), 2),
                        "box": tuple(map(int, box.xyxy[0].tolist())),
                    })
            return detections
        finally:
            self._is_processing = False

    # ------------------------------------------------------------------
    # Caption — file path (used by /vision/caption endpoint)
    # ------------------------------------------------------------------

    def generate_caption(self, image_path: str, model_type: str = "vit") -> str:
        """
        Generate a scene caption.

        model_type:
          'vit'      → ViT+GPT2  (scene/final_model)
          'blip'     → BLIP+LoRA (Salesforce base + scene/blip_model adapter)
          'florence' → Florence-2 (microsoft/Florence-2-base)
        """
        self._is_processing = True
        try:
            raw_image = Image.open(image_path).convert("RGB")
            return self._run_caption(raw_image, model_type)
        except Exception as e:
            print(f"[VisionService] Caption error ({model_type}): {e}")
            return f"Error: {str(e)}"
        finally:
            self._is_processing = False

    # ------------------------------------------------------------------
    # Caption — raw bytes (returns full response dict)
    # ------------------------------------------------------------------

    def generate_caption_from_bytes(self, image_bytes: bytes, model_type: str = "vit") -> dict:
        start = time.perf_counter()
        if self._is_processing:
            return _busy_response(start, caption=True)
        self._is_processing = True
        try:
            raw_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
            caption = self._run_caption(raw_image, model_type)
            return {
                "success": True,
                "caption": caption,
                "summary": caption,
                "timestamp": datetime.now().isoformat(),
                "processing_time_ms": _ms(start),
                "error": None,
            }
        except Exception as e:
            return {
                "success": False, "caption": "", "summary": "",
                "timestamp": datetime.now().isoformat(),
                "processing_time_ms": _ms(start),
                "error": str(e),
            }
        finally:
            self._is_processing = False

    # ------------------------------------------------------------------
    # Internal inference dispatcher
    # ------------------------------------------------------------------

    def _run_caption(self, image: Image.Image, model_type: str) -> str:
        if model_type == "blip":
            self._load_blip_model()
            if self.blip_model and self.blip_processor:
                inputs = self.blip_processor(images=image, return_tensors="pt")
                inputs = {k: v.to(self.device) for k, v in inputs.items()}
                with torch.no_grad():
                    out = self.blip_model.generate(
                        **inputs, max_new_tokens=30, num_beams=3
                    )
                return self.blip_processor.decode(out[0], skip_special_tokens=True).strip()
            return "BLIP model is unavailable."

        if model_type == "florence":
            self._load_florence_model()
            if self.florence_model and self.florence_processor:
                prompt = "<MORE_DETAILED_CAPTION>"
                inputs = self.florence_processor(
                    text=prompt, images=image, return_tensors="pt"
                ).to(self.device)
                if self.device == "cuda":
                    inputs["pixel_values"] = inputs["pixel_values"].half()
                with torch.no_grad():
                    generated_ids = self.florence_model.generate(
                        input_ids=inputs["input_ids"],
                        pixel_values=inputs["pixel_values"],
                        max_new_tokens=50,
                        num_beams=2,
                        do_sample=False,
                    )
                return self.florence_processor.batch_decode(
                    generated_ids, skip_special_tokens=True
                )[0].strip()
            return "Florence-2 model is unavailable."

        # Default → 'vit'
        self._load_vit_model()
        if self.vit_model and self.vit_processor and self.vit_tokenizer:
            pixel_values = self.vit_processor(
                image, return_tensors="pt"
            ).pixel_values.to(self.device)
            with torch.no_grad():
                output_ids = self.vit_model.generate(pixel_values, max_length=50)
            return self.vit_tokenizer.decode(
                output_ids[0], skip_special_tokens=True
            ).strip()

        return "Vision system is currently unavailable."


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

def _ms(start: float) -> float:
    return round((time.perf_counter() - start) * 1000, 2)


def _busy_response(start: float, caption: bool = False) -> dict:
    base = {
        "success": False,
        "timestamp": datetime.now().isoformat(),
        "processing_time_ms": _ms(start),
        "error": "Backend is currently busy processing another request.",
    }
    if caption:
        base.update({"caption": "", "summary": ""})
    else:
        base["detections"] = []
    return base


vision_service = VisionService()
