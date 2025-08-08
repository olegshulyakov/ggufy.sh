#!/bin/bash
#
# Shortcut for quantizing HF models using named parameters and short options
#
# Usage with long options:
#   ./ggufy.sh --model meta-llama/Llama-2-7b --quant-method Q4_K_M
#   ./ggufy.sh --model meta-llama/Llama-2-7b --quant-method Q4_K_M --use-imatrix
#   ./ggufy.sh --model meta-llama/Llama-2-7b --quant-method Q4_K_M --use-imatrix --output-filename Llama-2-7b-Q4_K_M.gguf
#   ./ggufy.sh --model meta-llama/Llama-2-7b --quant-method Q4_K_M --use-imatrix --output-filename Llama-2-7b-Q4_K_M.gguf --split-model --split-max-tensors 256 --split-max-size 4G
#
#   ./ggufy.sh -m meta-llama/Llama-2-7b -q Q4_K_M
#   ./ggufy.sh -m meta-llama/Llama-2-7b -q Q4_K_M -imatrix
#   ./ggufy.sh -m meta-llama/Llama-2-7b -q Q4_K_M -imatrix -o Llama-2-7b-Q4_K_M.gguf
#   ./ggufy.sh -m meta-llama/Llama-2-7b -q Q4_K_M -imatrix -o Llama-2-7b-Q4_K_M.gguf -split --split-max-tensors 256 --split-max-size 4G
#

# --- Configuration ---

# Path to convert_hf_to_gguf.py
CONVERT_SCRIPT_PATH="./llama.cpp/convert_hf_to_gguf.py"

# Path to calibration data file for imatrix
CALIBRATION_FILE_PATH="./calibration_data_v5_rc.txt"

# --- Input Arguments ---
# Required: Hugging Face model ID (e.g., meta-llama/Llama-3.2-1B)
MODEL_ID=""

# Required: Quantization method (e.g., Q4_K_M, Q5_K_M, F16)
QUANT_METHOD=""

# Optional: "true" to use imatrix, anything else or empty for false
USE_IMATRIX="false"
# Optional: Final GGUF filename (default: <model_name>-<quant_method>.gguf)
OUTPUT_FILENAME=""

# Optional: "true" to split the model, anything else or empty for false
SPLIT_MODEL="false"

# Optional: Max tensors per shard if splitting (default: 256)
SPLIT_MAX_TENSORS="256"

# Optional: Max size per shard if splitting (e.g., 2G) - overrides SPLIT_MAX_TENSORS if set
SPLIT_MAX_SIZE=""

# Optional: Quant embeddings tensor
TOKEN_EMBEDDING_TYPE=""

# Optional: Leave output tensor
LEAVE_OUTPUT_TENSOR="false"

# Optional: Output Quantization Method
OUTPUT_TENSOR_TYPE=""

# --- Parse Named Arguments ---
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model)
            MODEL_ID="$2"
            shift 2
            ;;
        -q|--quant-method)
            QUANT_METHOD="$2"
            shift 2
            ;;
        -imatrix|--use-imatrix)
            USE_IMATRIX="true"
            shift 1
            ;;
        -o|--output-filename)
            OUTPUT_FILENAME="$2"
            shift 2
            ;;
        -split|--split-model)
            SPLIT_MODEL="true"
            shift 1
            ;;
        --split-max-tensors)
            SPLIT_MAX_TENSORS="$2"
            shift 2
            ;;
        --split-max-size)
            SPLIT_MAX_SIZE="$2"
            shift 2
            ;;
        --token-embedding-type)
            TOKEN_EMBEDDING_TYPE="$2"
            shift 2
            ;;
        --leave-output-tensor)
            LEAVE_OUTPUT_TENSOR="true"
            shift 1
            ;;
        --output-tensor-type)
            OUTPUT_TENSOR_TYPE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage:"
            echo "  Long options:"
            echo "    $0 --model <MODEL_ID> --quant-method <QUANT_METHOD> [--use-imatrix] [--output-filename <FILENAME>] [--split-model] [--split-max-tensors <NUM>] [--split-max-size <SIZE>] [--token-embedding-type <QUANT_METHOD>] [--leave-output-tensor] [--output-tensor-type <QUANT_METHOD>]"
            echo ""
            echo "  Short options:"
            echo "    $0 -m <MODEL_ID> -q <QUANT_METHOD> [-imatrix] [-o <FILENAME>] [-split]"
            echo ""
            echo "Examples:"
            echo "  $0 --model meta-llama/Llama-2-7b --quant-method Q4_K_M"
            echo "  $0 -m meta-llama/Llama-2-7b -q Q4_K_M -imatrix"
            echo "  $0 --model meta-llama/Llama-2-7b --quant-method Q4_K_M --use-imatrix --output-filename Llama-2-7b-Q4_K_M.gguf"
            echo "  $0 -m meta-llama/Llama-2-7b -q Q4_K_M -imatrix -o Llama-2-7b-Q4_K_M.gguf -split --split-max-tensors 256 --split-max-size 4G"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help or -h for usage information."
            exit 1
            ;;
    esac
done

# --- Validation ---
if [ -z "$MODEL_ID" ] || [ -z "$QUANT_METHOD" ]; then
    echo "Error: Both --model (-m) and --quant-method (-q) are required."
    echo
    echo "Use --help or -h for usage information."
    exit 1
fi

# --- Derived Variables ---
# Extract model name from ID
MODEL_NAME=$(basename "$MODEL_ID")

# Directory to store intermediate and final files
OUTPUT_DIR="./outputs/${MODEL_NAME}"
mkdir -p "$OUTPUT_DIR"

if [ "$USE_IMATRIX" = "true" ]; then
    if [ ! -f "$CALIBRATION_FILE_PATH" ]; then
        echo "Error: Calibration file '$CALIBRATION_FILE_PATH' not found. Please provide it."
        exit 1
    fi
fi

if [ -z "$OUTPUT_FILENAME" ]; then
    OUTPUT_FILENAME="${MODEL_NAME}-${QUANT_METHOD}.gguf"
fi

FP16_MODEL_PATH="$OUTPUT_DIR/${MODEL_NAME}-fp16.gguf"
IMATRIX_FILE_PATH="$OUTPUT_DIR/${MODEL_NAME}-imatrix.gguf"
QUANTIZED_MODEL_PATH="$OUTPUT_DIR/$OUTPUT_FILENAME"

echo "=== Starting GGUF Conversion Pipeline ==="
echo "Model ID: $MODEL_ID"
echo "Model Name: $MODEL_NAME"
echo "Quantization Method: $QUANT_METHOD"
echo "Use Imatrix: $USE_IMATRIX"
if [ "$USE_IMATRIX" = "true" ]; then
    echo "Calibration File: $CALIBRATION_FILE_PATH"
fi
echo "Output Directory: $OUTPUT_DIR"
echo "Final Output File: $QUANTIZED_MODEL_PATH"
echo "Split Model: $SPLIT_MODEL"
if [ "$SPLIT_MODEL" = "true" ]; then
    if [ -n "$SPLIT_MAX_SIZE" ]; then
        echo "Split Max Size: $SPLIT_MAX_SIZE"
    else
        if [ -z "$SPLIT_MAX_TENSORS" ]; then
            SPLIT_MAX_TENSORS=256
        fi
        echo "Split Max Tensors: $SPLIT_MAX_TENSORS"
    fi
fi
echo "----------------------------------------"

if [ -f "$FP16_MODEL_PATH" ]; then
    echo "FP16 model '$FP16_MODEL_PATH' already exists. Skipping conversion."
else
    # --- Step 1: Check Hugging Face Login ---
    echo "Checking Hugging Face login status..."
    if ! hf auth whoami > /dev/null 2>&1; then
        echo "Error: Not logged into Hugging Face. Please run 'hf auth login' first."
        exit 1
    fi
    echo "Logged in successfully."

    # --- Step 2: Download Hugging Face Model ---
    echo "Downloading model '$MODEL_ID'..."
    MODEL_DOWNLOAD_DIR="./downloads/$MODEL_NAME"
    mkdir -p "$MODEL_DOWNLOAD_DIR"

    # Download necessary files
    hf download "$MODEL_ID" \
        --revision main \
        --include "*.md" \
        --include "*.json" \
        --include "*.model" \
        --include "*.safetensors" \
        --include "*.bin" \
        --local-dir "$MODEL_DOWNLOAD_DIR"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to download model '$MODEL_ID'."
        rm -rf "$MODEL_DOWNLOAD_DIR"
        exit 1
    fi

    echo "Model downloaded to '$MODEL_DOWNLOAD_DIR'."

    # Check for LoRA adapter (simplified check)
    if [ -f "$MODEL_DOWNLOAD_DIR/adapter_config.json" ] && [ ! -f "$MODEL_DOWNLOAD_DIR/config.json" ]; then
        echo "Error: adapter_config.json found but no config.json. This might be a LoRA adapter. Please use GGUF-my-lora."
        exit 1
    fi

    # --- Step 3: Convert HF Model to FP16 GGUF ---
    echo "Converting Hugging Face model to FP16 GGUF..."
    python3 "$CONVERT_SCRIPT_PATH" "$MODEL_DOWNLOAD_DIR" \
        --outtype f16 \
        --outfile "$FP16_MODEL_PATH"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to convert model to FP16 GGUF."
        rm -f "$FP16_MODEL_PATH"
        exit 1
    fi
    echo "FP16 GGUF model created at '$FP16_MODEL_PATH'."
fi

# --- Step 4: (Optional) Generate Imatrix ---
if [ "$USE_IMATRIX" = "true" ]; then
    if [ -f "$IMATRIX_FILE_PATH" ]; then
        echo "Imatrix file '$IMATRIX_FILE_PATH' already exists. Skipping generation."
    else
        echo "Generating importance matrix (imatrix)..."
        IMATRIX_CMD=(
            llama-imatrix
            -m "$FP16_MODEL_PATH"
            -f "$CALIBRATION_FILE_PATH"
            -ngl 99
            --output-frequency 10
            -o "$IMATRIX_FILE_PATH"
        )
        echo "Running command: ${IMATRIX_CMD[*]}"
        "${IMATRIX_CMD[@]}"

        if [ $? -ne 0 ]; then
            echo "Error: Failed to generate imatrix."
            rm -f "$IMATRIX_FILE_PATH"
            exit 1
        fi
        echo "Imatrix generated at '$IMATRIX_FILE_PATH'."
    fi
fi

# --- Step 5: Quantize the GGUF Model ---
echo "Quantizing GGUF model..."
QUANTIZE_CMD=(
    llama-quantize
)

if [ "$USE_IMATRIX" = "true" ] && [ -f "$IMATRIX_FILE_PATH" ]; then
    QUANTIZE_CMD+=(
        --imatrix "$IMATRIX_FILE_PATH"
    )
fi

if [ -n "$TOKEN_EMBEDDING_TYPE" ]; then
    QUANTIZE_CMD+=(
        --token-embedding-type "$TOKEN_EMBEDDING_TYPE"
    )
fi

if [ "$LEAVE_OUTPUT_TENSOR" = "true" ]; then
    QUANTIZE_CMD+=(
        --leave-output-tensor
    )
else
    if [ -n "$OUTPUT_TENSOR_TYPE" ]; then
        QUANTIZE_CMD+=(
            --output-tensor-type "$OUTPUT_TENSOR_TYPE"
        )
    fi
fi

QUANTIZE_CMD+=(
    "$FP16_MODEL_PATH"
    "$QUANTIZED_MODEL_PATH"
    "$QUANT_METHOD"
)

echo "Running command: ${QUANTIZE_CMD[*]}"
"${QUANTIZE_CMD[@]}"

if [ $? -ne 0 ]; then
    echo "Error: Failed to quantize model."
    rm -f "$QUANTIZED_MODEL_PATH"
    exit 1
fi
echo "Model quantized successfully to '$QUANTIZED_MODEL_PATH'."

# --- Step 6: (Optional) Split the Quantized Model ---
if [ "$SPLIT_MODEL" = "true" ]; then
    echo "Splitting quantized model..."
    SPLIT_CMD=(
        llama-gguf-split
        --split
    )

    if [ -n "$SPLIT_MAX_SIZE" ]; then
        SPLIT_CMD+=(--split-max-size "$SPLIT_MAX_SIZE")
    else
        SPLIT_CMD+=(--split-max-tensors "$SPLIT_MAX_TENSORS")
    fi

    # Output prefix (without .gguf extension)
    OUTPUT_PREFIX="${QUANTIZED_MODEL_PATH%.gguf}"
    SPLIT_CMD+=("$QUANTIZED_MODEL_PATH" "$OUTPUT_PREFIX")

    echo "Running command: ${SPLIT_CMD[*]}"
    "${SPLIT_CMD[@]}"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to split model."
        exit 1
    fi

    # Remove the original unsplit file
    if [ -f "$QUANTIZED_MODEL_PATH" ]; then
        rm "$QUANTIZED_MODEL_PATH"
        echo "Removed original unsplit file '$QUANTIZED_MODEL_PATH'."
    fi

    echo "Model split successfully. Shards are in '$OUTPUT_DIR' with prefix '$OUTPUT_PREFIX'."
else
    echo "Model splitting skipped."
fi

echo "=== GGUF Conversion Pipeline Completed Successfully ==="
if [ "$SPLIT_MODEL" = "true" ]; then
    echo "Check directory '$OUTPUT_DIR' for split GGUF files."
else
    echo "Final GGUF file is located at: $QUANTIZED_MODEL_PATH"
fi