#!/bin/bash
# Vast.ai provisioning script.
# Adds two helpers to .bashrc:
#   download_by_number <id> [target_dir]   - download one Civitai model by ID
#   download_models [file]                 - download a list of IDs grouped under LORAS/ and CHECKPOINTS/
# Requires the CIVITAI_TOKEN environment variable (set in the Vast.ai template).
# Safe to run more than once (it won't append the functions twice).

MARKER="# >>> civitai helpers (provisioning) >>>"

add_functions() {
    local bashrc="$1"
    [ -d "$(dirname "$bashrc")" ] || return 0
    touch "$bashrc"
    if grep -qF "$MARKER" "$bashrc"; then
        echo "civitai helpers already present in $bashrc"
        return 0
    fi
    cat >> "$bashrc" <<'BASHRC_EOF'

# >>> civitai helpers (provisioning) >>>
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