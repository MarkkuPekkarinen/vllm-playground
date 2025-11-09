#!/bin/bash
# =============================================================================
# LLMCompressor Model Quantization Script
# =============================================================================
# Standalone script to compress/quantize models using LLMCompressor
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Configuration
MODEL="${1:-TinyLlama/TinyLlama-1.1B-Chat-v1.0}"
OUTPUT_DIR="${2:-./compressed_models}"
QUANTIZATION_FORMAT="${3:-W8A8_INT8}"
ALGORITHM="${4:-GPTQ}"
CALIBRATION_SAMPLES="${5:-512}"

echo "═══════════════════════════════════════════════════════════════"
echo "LLMCompressor Model Quantization"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Configuration:"
echo "  Model: $MODEL"
echo "  Output: $OUTPUT_DIR"
echo "  Format: $QUANTIZATION_FORMAT"
echo "  Algorithm: $ALGORITHM"
echo "  Calibration Samples: $CALIBRATION_SAMPLES"
echo ""

# Check for HF token
if [ -n "$HF_TOKEN" ]; then
    log_info "HF_TOKEN detected - will be used for model access"
elif [ -n "$HUGGING_FACE_HUB_TOKEN" ]; then
    log_info "HUGGING_FACE_HUB_TOKEN detected - will be used for model access"
else
    log_warning "No HF token found. If downloading a gated model, it may fail."
    log_info "Set HF_TOKEN environment variable for gated model access:"
    log_info "  export HF_TOKEN=\"hf_your_token_here\""
fi
echo ""

# Activate venv if available
VENV_PATH="${VENV_PATH:-$HOME/.venv}"
if [ -d "$VENV_PATH" ]; then
    log_info "Activating virtual environment: $VENV_PATH"
    source "$VENV_PATH/bin/activate"
fi

# Check if llmcompressor is installed
if ! python3 -c "import llmcompressor" 2>/dev/null; then
    log_error "llmcompressor not installed"
    echo "Install with: pip install llmcompressor"
    exit 1
fi

# Create output directory
model_name=$(echo "$MODEL" | sed 's/\//_/g')
full_output_dir="${OUTPUT_DIR}/${model_name}_${QUANTIZATION_FORMAT}"
mkdir -p "$full_output_dir"

log_info "Output directory: $full_output_dir"

# Map quantization format to scheme
scheme="W8A8"
case "$QUANTIZATION_FORMAT" in
    "W8A8_INT8") scheme="W8A8" ;;
    "W8A8_FP8") scheme="W8A8_FP8" ;;
    "W4A16") scheme="W4A16" ;;
    "W8A16") scheme="W8A16" ;;
    "W4A4") scheme="W4A4" ;;
    *) scheme="W8A8" ;;
esac

log_info "Using quantization scheme: $scheme"

# Create Python compression script
cat > /tmp/compress_model_detailed.py << 'PYTHON_SCRIPT'
import sys
import os
from pathlib import Path
from llmcompressor import oneshot
from llmcompressor.modifiers.quantization import GPTQModifier

def main():
    model = sys.argv[1]
    output_dir = sys.argv[2]
    scheme = sys.argv[3]
    calibration_samples = int(sys.argv[4])
    
    print("=" * 70)
    print("LLMCompressor - Model Quantization")
    print("=" * 70)
    print(f"\n📦 Model: {model}")
    print(f"📊 Quantization Scheme: {scheme}")
    print(f"🔢 Calibration Samples: {calibration_samples}")
    print(f"📁 Output Directory: {output_dir}")
    
    # Check for HF token
    if os.environ.get('HF_TOKEN') or os.environ.get('HUGGING_FACE_HUB_TOKEN'):
        print("🔑 HF Token: ✓ Found (will use for authentication)")
    else:
        print("⚠️  HF Token: Not found (may fail for gated models)")
    
    print("\n" + "=" * 70)
    
    # Build recipe
    print("\n🔧 Building compression recipe...")
    recipe = [
        GPTQModifier(
            scheme=scheme,
            targets="Linear",
            ignore=["lm_head"]
        )
    ]
    print("✓ Recipe created")
    
    # Run compression
    print("\n🚀 Starting compression (this will take several minutes)...")
    print("   - Loading model")
    print("   - Calibrating with dataset")
    print("   - Applying quantization")
    print("   - Saving compressed model")
    print()
    
    try:
        oneshot(
            model=model,
            dataset="open_platypus",
            recipe=recipe,
            output_dir=output_dir,
            max_seq_length=2048,
            num_calibration_samples=calibration_samples,
        )
        
        print("\n" + "=" * 70)
        print("✓ Compression Complete!")
        print("=" * 70)
        print(f"\n📁 Compressed model saved to: {output_dir}")
        
        # Show file size
        output_path = Path(output_dir)
        if output_path.exists():
            config_file = output_path / "config.json"
            if config_file.exists():
                print(f"✓ Config file found: {config_file}")
            
            # Try to calculate size
            try:
                import subprocess
                result = subprocess.run(
                    ["du", "-sh", str(output_path)],
                    capture_output=True,
                    text=True
                )
                if result.returncode == 0:
                    size = result.stdout.split()[0]
                    print(f"📊 Total size: {size}")
            except:
                pass
        
        print("\n💡 To use this model with vLLM:")
        print(f"   python -m vllm.entrypoints.openai.api_server \\")
        print(f"     --model {output_dir} \\")
        print(f"     --quantization gptq \\")
        print(f"     --dtype auto")
        print()
        
    except Exception as e:
        print(f"\n✗ Error during compression: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
PYTHON_SCRIPT

# Run compression
log_info "Starting compression..."
if python3 /tmp/compress_model_detailed.py "$MODEL" "$full_output_dir" "$scheme" "$CALIBRATION_SAMPLES"; then
    log_success "Compression completed successfully!"
    echo ""
    echo "Compressed model location:"
    echo "  $full_output_dir"
else
    log_error "Compression failed"
    exit 1
fi

