#!/bin/bash
# Vast.ai provisioning script.
# Adds three helpers to .bashrc:
#   download_by_number <id> [target_dir]   - download one Civitai model by ID
#   download_models [file]                 - download a list of IDs grouped under LORAS/ and CHECKPOINTS/
#   download_base_models                   - download the base diffusion model, text encoder and VAE
# Requires the CIVITAI_TOKEN environment variable (set in the Vast.ai template).
# Safe to run more than once (it won't append the functions twice).

MARKER="# >>> civitai helpers (provisioning) >>>"

# Base model URLs used by download_base_models (edit before provisioning).
BASE_DIFFUSION_MODEL_URL="https://huggingface.co/Comfy-Org/Krea-2/resolve/main/diffusion_models/krea2_turbo_fp8_scaled.safetensors"
BASE_TEXT_ENCODER_URL="https://huggingface.co/Comfy-Org/Krea-2/resolve/main/text_encoders/qwen3vl_4b_fp8_scaled.safetensors"
BASE_VAE_URL="https://huggingface.co/Comfy-Org/Krea-2/resolve/main/vae/qwen_image_vae.safetensors"

add_functions() {
    local bashrc="$1"
    [ -d "$(dirname "$bashrc")" ] || return 0
    touch "$bashrc"
    if grep -qF "$MARKER" "$bashrc"; then
        echo "civitai helpers already present in $bashrc"
        return 0
    fi
    {
        echo ""
        echo "$MARKER"
        printf 'BASE_DIFFUSION_MODEL_URL=%q\n' "$BASE_DIFFUSION_MODEL_URL"
        printf 'BASE_TEXT_ENCODER_URL=%q\n' "$BASE_TEXT_ENCODER_URL"
        printf 'BASE_VAE_URL=%q\n' "$BASE_VAE_URL"
    } >> "$bashrc"
    cat >> "$bashrc" <<'BASHRC_EOF'
download_by_number() {
  local number="$1" dir="${2:-.}"
  if [ -z "$number" ]; then
    echo "Usage: download_by_number <model_id> [target_dir]" >&2
    return 1
  fi
  if [ -z "$CIVITAI_TOKEN" ]; then
    echo "CIVITAI_TOKEN is not set in this shell" >&2
    return 1
  fi
  mkdir -p "$dir" || return 1
  wget "https://civitai.com/api/download/models/${number}?token=${CIVITAI_TOKEN}" \
       --content-disposition -P "$dir"
}

# Reads a list from a file (first argument) or from stdin. Format:
#   LORAS/
#   46546
#   16844
#   CHECKPOINTS/
#   4968
# Paths are relative to the current directory.
download_models() {
  local dir="" line id ok=0 fail=0 failed=""
  local input=/dev/stdin
  [ -n "$1" ] && input="$1"
  while IFS= read -r line; do
    line="${line//[\"\'[:space:]]/}"          # strip quotes and whitespace
    [ -z "$line" ] && continue
    if [[ "$line" =~ ^[0-9]+$ ]]; then
      if [ -z "$dir" ]; then
        echo "Skipping $line: no valid LORAS/ or CHECKPOINTS/ header above it" >&2
        continue
      fi
      echo "==> [$dir] model $line"
      if download_by_number "$line" "$dir" < /dev/null; then
        ok=$((ok+1))
      else
        fail=$((fail+1)); failed="$failed $line"
      fi
    else
      case "$(echo "${line%/}" | tr '[:lower:]' '[:upper:]')" in
        LORAS|LORA)               dir="ComfyUI/models/loras" ;;
        CHECKPOINTS|CHECKPOINT)   dir="ComfyUI/models/checkpoints" ;;
        *) echo "Unknown section '$line' - skipping its models" >&2; dir="" ;;
      esac
    fi
  done < "$input"
  echo "Done: $ok downloaded, $fail failed${failed:+ (IDs:$failed)}"
}

# Downloads the base models from the BASE_*_URL constants.
# Paths are relative to the current directory.
download_base_models() {
  local entry name url dir ok=0 fail=0 failed=""
  for entry in \
    "diffusion_model|$BASE_DIFFUSION_MODEL_URL|ComfyUI/models/diffusion_models" \
    "text_encoder|$BASE_TEXT_ENCODER_URL|ComfyUI/models/text_encoder" \
    "vae|$BASE_VAE_URL|ComfyUI/models/vae"; do
    IFS='|' read -r name url dir <<< "$entry"
    if [ -z "$url" ]; then
      echo "Skipping $name: no URL set" >&2
      continue
    fi
    echo "==> [$dir] $name"
    if mkdir -p "$dir" && wget "$url" --content-disposition -P "$dir"; then
      ok=$((ok+1))
    else
      fail=$((fail+1)); failed="$failed $name"
    fi
  done
  echo "Done: $ok downloaded, $fail failed${failed:+ (failed:$failed)}"
}
# <<< civitai helpers (provisioning) <<<
BASHRC_EOF
    echo "civitai helpers added to $bashrc"
}

# Current user (usually root on Vast.ai images)
add_functions "${HOME:-/root}/.bashrc"

# Also the non-root default user, if the image has one
[ -d /home/user ] && add_functions /home/user/.bashrc

# Apply it in this script's shell (only affects this process; new terminals load it automatically)
# shellcheck disable=SC1090
source "${HOME:-/root}/.bashrc" 2>/dev/null || true