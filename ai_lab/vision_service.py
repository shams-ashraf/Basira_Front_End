import gc
import os

from PIL import Image

MODEL_ROOT = os.path.abspath(r"E:\voice_test\ai_lab\models")
os.makedirs(MODEL_ROOT, exist_ok=True)
os.environ["HF_HOME"] = MODEL_ROOT
os.environ["HUGGINGFACE_HUB_CACHE"] = MODEL_ROOT
os.environ["TRANSFORMERS_CACHE"] = MODEL_ROOT

SCENE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "scene"))
VIT_MODEL_PATH = os.path.join(SCENE_DIR, "final_model")
BLIP_BASE_MODEL = "Salesforce/blip-image-captioning-base"
BLIP_ADAPTER_PATH = os.path.join(SCENE_DIR, "blip_model")
FLORENCE_MODEL_PATH = os.path.join(SCENE_DIR, "florence_model")


class VisionService:
    _instance = None
    _is_processing = False

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        import torch

        self._torch = torch
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.yolo_model = None
        self.vit_model = None
        self.vit_processor = None
        self.vit_tokenizer = None
        self.blip_model = None
        self.blip_processor = None
        self.florence_model = None
        self.florence_processor = None
        self._initialized = True

    def _unload_other_models(self, keep_model: str):
        torch = self._torch
        unloaded = False
        if keep_model != "yolo" and getattr(self, "yolo_model", None) is not None:
            del self.yolo_model
            self.yolo_model = None
            unloaded = True
        if keep_model != "vit" and getattr(self, "vit_model", None) is not None:
            del self.vit_model
            del self.vit_processor
            del self.vit_tokenizer
            self.vit_model = self.vit_processor = self.vit_tokenizer = None
            unloaded = True
        if keep_model != "blip" and getattr(self, "blip_model", None) is not None:
            del self.blip_model
            del self.blip_processor
            self.blip_model = self.blip_processor = None
            unloaded = True
        if keep_model != "florence" and getattr(self, "florence_model", None) is not None:
            del self.florence_model
            del self.florence_processor
            self.florence_model = self.florence_processor = None
            unloaded = True
        if unloaded:
            gc.collect()
            if torch.cuda.is_available():
                torch.cuda.empty_cache()

    def _load_yolo_model(self):
        from ultralytics import YOLO

        self._unload_other_models("yolo")
        if self.yolo_model is None:
            self.yolo_model = YOLO("yolov8n.pt")

    def _load_vit_model(self):
        from transformers import GPT2TokenizerFast, ViTImageProcessor, VisionEncoderDecoderModel

        self._unload_other_models("vit")
        if self.vit_model is not None:
            return
        self.vit_processor = ViTImageProcessor.from_pretrained(VIT_MODEL_PATH)
        self.vit_tokenizer = GPT2TokenizerFast.from_pretrained(VIT_MODEL_PATH)
        self.vit_model = VisionEncoderDecoderModel.from_pretrained(VIT_MODEL_PATH)
        self.vit_model.to(self.device).eval()

    def _load_blip_model(self):
        from peft import PeftModel
        from transformers import BlipForConditionalGeneration, BlipProcessor

        self._unload_other_models("blip")
        if self.blip_model is not None:
            return
        self.blip_processor = BlipProcessor.from_pretrained(BLIP_BASE_MODEL)
        base = BlipForConditionalGeneration.from_pretrained(BLIP_BASE_MODEL)
        self.blip_model = PeftModel.from_pretrained(base, BLIP_ADAPTER_PATH)
        self.blip_model.to(self.device).eval()

    def _load_florence_model(self):
        from transformers import AutoProcessor, AutoModelForCausalLM

        self._unload_other_models("florence")
        if self.florence_model is not None:
            return

        self.florence_processor = AutoProcessor.from_pretrained(FLORENCE_MODEL_PATH, trust_remote_code=True)
        self.florence_model = AutoModelForCausalLM.from_pretrained(FLORENCE_MODEL_PATH, trust_remote_code=True)
        self.florence_model.to(self.device).eval()

    def detect_objects(self, image_path: str) -> list:
        self._is_processing = True
        try:
            self._load_yolo_model()
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

    def generate_caption(self, image_path: str, model_type: str = "vit") -> str:
        self._is_processing = True
        try:
            raw_image = Image.open(image_path).convert("RGB")
            if model_type == "blip":
                self._load_blip_model()
                inputs = self.blip_processor(images=raw_image, return_tensors="pt")
                inputs = {k: v.to(self.device) for k, v in inputs.items()}
                with self._torch.no_grad():
                    out = self.blip_model.generate(**inputs, max_new_tokens=30, num_beams=3)
                return self.blip_processor.decode(out[0], skip_special_tokens=True).strip()
            if model_type == "florence":
                self._load_florence_model()
                inputs = self.florence_processor(text="<MORE_DETAILED_CAPTION>", images=raw_image, return_tensors="pt").to(self.device)
                if self.device == "cuda":
                    inputs["pixel_values"] = inputs["pixel_values"].half()
                with self._torch.no_grad():
                    generated_ids = self.florence_model.generate(
                        input_ids=inputs["input_ids"],
                        pixel_values=inputs["pixel_values"],
                        max_new_tokens=50,
                        num_beams=2,
                        do_sample=False,
                    )
                return self.florence_processor.batch_decode(generated_ids, skip_special_tokens=True)[0].strip()
            self._load_vit_model()
            pixel_values = self.vit_processor(raw_image, return_tensors="pt").pixel_values.to(self.device)
            with self._torch.no_grad():
                output_ids = self.vit_model.generate(pixel_values, max_length=50)
            return self.vit_tokenizer.decode(output_ids[0], skip_special_tokens=True).strip()
        finally:
            self._is_processing = False


vision_service = VisionService()
