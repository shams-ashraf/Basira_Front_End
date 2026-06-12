import os
from transformers import AutoProcessor, AutoModelForCausalLM

save_path = r"E:\voice_test\scene\florence_model"
model_id = "microsoft/Florence-2-base"

print(f"Downloading {model_id} to {save_path}...")

processor = AutoProcessor.from_pretrained(model_id, trust_remote_code=True)
model = AutoModelForCausalLM.from_pretrained(model_id, trust_remote_code=True)

processor.save_pretrained(save_path)
model.save_pretrained(save_path)

print("Download and save complete!")
