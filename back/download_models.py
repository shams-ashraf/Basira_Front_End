import os
from huggingface_hub import snapshot_download

os.environ["HF_HOME"] = "E:/hf_cache"

print("Downloading microsoft/Florence-2-base...")
snapshot_download(repo_id="microsoft/Florence-2-base")
print("Download complete.")
