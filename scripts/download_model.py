#!/usr/bin/env python3

import os
import sys
import subprocess
import urllib.request
from pathlib import Path

def download_file(url, target_path):
    print(f"Downloading model to {target_path}...")
    try:
        # Use curl to download the file showing progress
        subprocess.run(["curl", "-L", "-o", target_path, url], check=True)
        print("\nDownload complete!")
    except subprocess.CalledProcessError as e:
        print(f"\nFailed to download: {e}")
        sys.exit(1)

def main():
    # URL to the Gemma-4-E2B LiteRT-LM model on Hugging Face
    model_url = "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm"
    
    # We will try to download it into the Xcode simulator document directory
    # or print instructions to copy it into the app via Files.
    print("This script downloads the Gemma-4-E2B LiteRT model (approx 2.5GB).")
    
    apps_dir = Path(__file__).resolve().parent.parent / "Apps" / "Brain"
    
    target_dir = apps_dir / "Model"
    target_dir.mkdir(parents=True, exist_ok=True)
    
    model_path = target_dir / "gemma-4-E2B-it.litertlm"
    
    if model_path.exists():
        print(f"Model already exists at {model_path}.")
        return
        
    download_file(model_url, str(model_path))
    
    print("\nNext Steps:")
    print("1. When running on an iOS Simulator: Drag and drop the downloaded model file into the Simulator window, then save it to the Brain app folder via Files app.")
    print("2. When running on a physical iPhone: Transfer the file using AirDrop or Finder to the Brain app's Documents folder.")

if __name__ == "__main__":
    main()
