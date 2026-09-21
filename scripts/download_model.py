#!/usr/bin/env python3

import sys

MODEL_ID = "LiquidAI/LFM2.5-2.6B-MLX-4bit"

def main():
    print(f"Prefetching {MODEL_ID} for MLX Swift...")
    print("This downloads the multi-file 4-bit checkpoint into the Hugging Face cache.")

    try:
        from huggingface_hub import snapshot_download
    except ImportError:
        print("Install the Hugging Face Hub client first: python3 -m pip install -U huggingface_hub")
        sys.exit(1)

    try:
        model_path = snapshot_download(repo_id=MODEL_ID, repo_type="model")
    except Exception as error:
        print(f"\nFailed to download {MODEL_ID}: {error}")
        sys.exit(1)

    print(f"\nModel cache is ready at {model_path}")
    print("Brain downloads its own iOS cache through MLX Swift when needed.")

if __name__ == "__main__":
    main()
