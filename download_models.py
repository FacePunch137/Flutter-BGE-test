import os
import shutil
from huggingface_hub import hf_hub_download

TARGET_DIR = r"C:\Coding Projects\PROTOTYPE XKIL\georgian_legal_search\assets\models"
os.makedirs(TARGET_DIR, exist_ok=True)

print("Downloading bge-m3.onnx (quantized, faster)...")
model_path = hf_hub_download(repo_id="Xenova/bge-m3", filename="onnx/model_quantized.onnx")
shutil.copy(model_path, os.path.join(TARGET_DIR, "bge-m3.onnx"))

print("Downloading bge-reranker-v2-m3.onnx (using base quantized for speed)...")
reranker_path = hf_hub_download(repo_id="Xenova/bge-reranker-base", filename="onnx/model_quantized.onnx")
shutil.copy(reranker_path, os.path.join(TARGET_DIR, "bge-reranker-v2-m3.onnx"))

print("Models downloaded successfully to assets/models!")
