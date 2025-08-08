# ggufy.sh

## Overview
`ggufy.sh` is a shell script utility designed to simplify operations related to the GGUF (GPT-Generated Unified Format) file format, commonly used for machine learning model inference with frameworks like GGML.  While specific implementation details for this repository aren't publicly documented in search results, the tool appears to be part of the growing ecosystem of GGUF management utilities similar to other conversion tools in the space.

## Features
- Command-line interface for GGUF file operations
- Shell-based implementation for cross-platform compatibility
- Likely supports model conversion or packaging workflows (based on naming conventions in the GGUF ecosystem)

## Installation
```bash
# Clone the repository
git clone https://github.com/olegshulyakov/ggufy.sh.git
cd ggufy.sh

# Make the script executable
chmod +x ggufy.sh

# Make Python virtual environment
python3 -m venv .venv

# Activate environment
source .venv/bin/activate

pip install --no-cache-dir -r llama.cpp/requirements/requirements-convert_hf_to_gguf.txt

# Run with help to see available commands
./ggufy.sh --help
```

## Usage
Basic operation likely follows patterns common in GGUF tooling:

**Usage with long options:**
```bash
./ggufy.sh --model meta-llama/Llama-2-7b --quant-method Q4_K_M
./ggufy.sh --model meta-llama/Llama-2-7b --quant-method Q4_K_M --use-imatrix
./ggufy.sh --model meta-llama/Llama-2-7b --quant-method Q4_K_M --use-imatrix --output-filename Llama-2-7b-Q4_K_M.gguf
./ggufy.sh --model meta-llama/Llama-2-7b --quant-method Q4_K_M --use-imatrix --output-filename Llama-2-7b-Q4_K_M.gguf --split-model --split-max-tensors 256 --split-max-size 4G
```

**Usage with short options:**
```
./ggufy.sh -m meta-llama/Llama-2-7b -q Q4_K_M
./ggufy.sh -m meta-llama/Llama-2-7b -q Q4_K_M -imatrix
./ggufy.sh -m meta-llama/Llama-2-7b -q Q4_K_M -imatrix -o Llama-2-7b-Q4_K_M.gguf
./ggufy.sh -m meta-llama/Llama-2-7b -q Q4_K_M -imatrix -o Llama-2-7b-Q4_K_M.gguf -split --split-max-tensors 256 --split-max-size 4G

```

## Requirements
- Linux/ MacOS
- Llama.cpp
- Python 3.11
