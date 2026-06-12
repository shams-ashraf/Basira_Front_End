import gc
import os
import time
from pathlib import Path

import torch
from PIL import Image

MODEL_ROOT = Path(r"E:\voice_test\ai_lab\models")
MODEL_ROOT.mkdir(parents=True, exist_ok=True)
os.environ["HF_HOME"] = str(MODEL_ROOT)
os.environ["HUGGINGFACE_HUB_CACHE"] = str(MODEL_ROOT)
os.environ["TRANSFORMERS_CACHE"] = str(MODEL_ROOT)

SCENE_DIR = Path(r"E:\voice_test\scene")
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

_blip_model = None
_blip_processor = None
_vit_model = None
_vit_processor = None
_vit_tokenizer = None
_florence_model = None
_florence_processor = None


def _unload_all():
    global _blip_model, _blip_processor, _vit_model, _vit_processor, _vit_tokenizer, _florence_model, _florence_processor
    _blip_model = None
    _blip_processor = None
    _vit_model = None
    _vit_processor = None
    _vit_tokenizer = None
    _florence_model = None
    _florence_processor = None
    gc.collect()
    if torch.cuda.is_available():
        torch.cuda.empty_cache()


def _temp_image(path: str) -> Image.Image:
    return Image.open(path).convert("RGB")


def run_blip(image_path: str):
    global _blip_model, _blip_processor
    _unload_all()
    from peft import PeftModel
    from transformers import BlipForConditionalGeneration, BlipProcessor

    if _blip_processor is None:
        _blip_processor = BlipProcessor.from_pretrained("Salesforce/blip-image-captioning-base")
    if _blip_model is None:
        base = BlipForConditionalGeneration.from_pretrained("Salesforce/blip-image-captioning-base")
        _blip_model = PeftModel.from_pretrained(base, str(SCENE_DIR / "blip_model"))
        _blip_model = _blip_model.to(DEVICE).eval()

    image = _temp_image(image_path)
    inputs = _blip_processor(images=image, return_tensors="pt")
    inputs = {k: v.to(DEVICE) for k, v in inputs.items()}
    started = time.perf_counter()
    with torch.no_grad():
        output = _blip_model.generate(**inputs, max_new_tokens=30, num_beams=3)
    caption = _blip_processor.decode(output[0], skip_special_tokens=True).strip()
    elapsed = round((time.perf_counter() - started) * 1000, 2)
    _unload_all()
    return caption, elapsed


def run_vit(image_path: str):
    global _vit_model, _vit_processor, _vit_tokenizer
    _unload_all()
    from transformers import GPT2TokenizerFast, ViTImageProcessor, VisionEncoderDecoderModel

    if _vit_processor is None:
        _vit_processor = ViTImageProcessor.from_pretrained(str(SCENE_DIR / "final_model"))
    if _vit_tokenizer is None:
        _vit_tokenizer = GPT2TokenizerFast.from_pretrained(str(SCENE_DIR / "final_model"))
    if _vit_model is None:
        _vit_model = VisionEncoderDecoderModel.from_pretrained(str(SCENE_DIR / "final_model"))
        _vit_model = _vit_model.to(DEVICE).eval()

    image = _temp_image(image_path)
    inputs = _vit_processor(image, return_tensors="pt").pixel_values.to(DEVICE)
    started = time.perf_counter()
    with torch.no_grad():
        output_ids = _vit_model.generate(inputs, max_length=50)
    caption = _vit_tokenizer.decode(output_ids[0], skip_special_tokens=True).strip()
    elapsed = round((time.perf_counter() - started) * 1000, 2)
    _unload_all()
    return caption, elapsed


def run_florence(image_path: str):
    global _florence_model, _florence_processor
    _unload_all()
    from transformers import AutoModelForCausalLM, AutoProcessor

    if _florence_processor is None:
        _florence_processor = AutoProcessor.from_pretrained(str(SCENE_DIR / "florence_model"), trust_remote_code=True)
    if _florence_model is None:
        _florence_model = AutoModelForCausalLM.from_pretrained(str(SCENE_DIR / "florence_model"), trust_remote_code=True)
        _florence_model = _florence_model.to(DEVICE).eval()

    image = _temp_image(image_path)
    inputs = _florence_processor(text="<MORE_DETAILED_CAPTION>", images=image, return_tensors="pt").to(DEVICE)
    if DEVICE == "cuda":
        inputs["pixel_values"] = inputs["pixel_values"].half()
    started = time.perf_counter()
    with torch.no_grad():
        generated_ids = _florence_model.generate(
            input_ids=inputs["input_ids"],
            pixel_values=inputs["pixel_values"],
            max_new_tokens=50,
            num_beams=2,
            do_sample=False,
        )
    caption = _florence_processor.batch_decode(generated_ids, skip_special_tokens=True)[0].strip()
    elapsed = round((time.perf_counter() - started) * 1000, 2)
    _unload_all()
    return caption, elapsed
