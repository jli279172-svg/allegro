#!/usr/bin/env python3
"""
Check PyTorch version from checkpoint file or Python environment.

This script tries to determine the PyTorch version that was used to train
a model by:
1. Checking if torch is available in the current environment
2. Trying to load checkpoint metadata (if available)
3. Falling back to checking installed PyTorch version

Usage:
    python check_pytorch_version.py [checkpoint_file]
"""

import sys
import os
import re
from pathlib import Path

def get_torch_version_from_env():
    """Get PyTorch version from current Python environment."""
    try:
        import torch
        return torch.__version__
    except ImportError:
        return None

def get_torch_version_from_checkpoint(checkpoint_path):
    """Try to extract PyTorch version from checkpoint file metadata."""
    checkpoint_path = Path(checkpoint_path)
    if not checkpoint_path.exists():
        return None
    
    # Lightning checkpoints are ZIP files (they're pickle archives)
    # We can try to check the metadata in the checkpoint
    try:
        import torch
        import pickle
        
        # Try to load checkpoint and check hyperparameters/metadata
        ckpt = torch.load(checkpoint_path, map_location='cpu')
        
        # Check if there's version information in metadata
        if isinstance(ckpt, dict):
            # Check hyper_parameters for torch version info
            if 'hyper_parameters' in ckpt:
                hparams = ckpt['hyper_parameters']
                if 'torch_version' in hparams:
                    return hparams['torch_version']
            
            # Check metadata
            if 'metadata' in ckpt:
                metadata = ckpt['metadata']
                if isinstance(metadata, dict) and 'torch_version' in metadata:
                    return metadata['torch_version']
            
            # Check callbacks (ModelCheckpoint might store version info)
            if 'callbacks' in ckpt:
                for callback in ckpt.get('callbacks', {}).values():
                    if isinstance(callback, dict) and 'torch_version' in callback:
                        return callback['torch_version']
        
        # If we can load the checkpoint, we're in the same environment
        # Return current torch version as proxy
        return torch.__version__
        
    except Exception as e:
        # If loading fails, we can't determine version from checkpoint
        return None

def parse_pytorch_version(version_str):
    """Parse PyTorch version string to extract major.minor version."""
    if not version_str:
        return None
    
    # Match version pattern (e.g., "2.0.0", "2.8.0", "2.0.0+cu118")
    match = re.match(r'^(\d+)\.(\d+)\.', version_str)
    if match:
        major = int(match.group(1))
        minor = int(match.group(2))
        return f"{major}.{minor}"
    return None

def main():
    checkpoint_path = None
    if len(sys.argv) > 1:
        checkpoint_path = sys.argv[1]
    
    # Try to get version from checkpoint
    version = None
    if checkpoint_path:
        version = get_torch_version_from_checkpoint(checkpoint_path)
        source = "checkpoint"
    
    # Fall back to environment
    if not version:
        version = get_torch_version_from_env()
        source = "environment"
    
    if not version:
        print("ERROR: Could not determine PyTorch version.", file=sys.stderr)
        print("Please ensure PyTorch is installed or provide a valid checkpoint file.", file=sys.stderr)
        sys.exit(1)
    
    # Parse version
    parsed_version = parse_pytorch_version(version)
    if not parsed_version:
        print("ERROR: Could not parse PyTorch version.", file=sys.stderr)
        sys.exit(1)
    
    # Output version information
    print(f"PYTORCH_VERSION={version}")
    print(f"PYTORCH_MAJOR_MINOR={parsed_version}")
    print(f"SOURCE={source}")
    
    # Also output for easy parsing
    sys.stdout.write(parsed_version)
    return parsed_version

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

