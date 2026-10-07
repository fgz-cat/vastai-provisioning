#!/bin/bash
# Vast.ai provisioning script: adds the download_by_number helper to .bashrc.
# Safe to run more than once (it won't append the function twice).

MARKER="# >>> download_by_number (provisioning) >>>"

add_function() {
    local bashrc="$1"
    [ -d "$(dirname "$bashrc")" ] || return 0
    touch "$bashrc"
    if grep -qF "$MARKER" "$bashrc"; then
        echo "download_by_number already present in $bashrc"
        return 0
    fi
    cat >> "$bashrc" <<'EOF'

# >>> download_by_number (provisioning) >>>
download_by_number() {
  NUMBER=$1
  echo "wget 'https://civitai.com/api/download/models/[NUMBER]?token=$CIVITAI_TOKEN' --content-disposition" | sed "s/\[NUMBER\]/$NUMBER/" | bash
}
# <<< download_by_number (provisioning) <<<
EOF
    echo "download_by_number added to $bashrc"
}

# Current user (usually root on Vast.ai images)
add_function "${HOME:-/root}/.bashrc"

# Also the non-root default user, if the image has one
[ -d /home/user ] && add_function /home/user/.bashrc

# Apply it in this script's shell (only affects this process; see notes)
# shellcheck disable=SC1090
source "${HOME:-/root}/.bashrc" 2>/dev/null || true