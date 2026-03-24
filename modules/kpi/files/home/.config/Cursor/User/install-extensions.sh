#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_FILE="$SCRIPT_DIR/extensions.txt"

if [[ ! -f "$EXT_FILE" ]]; then
    echo "Error: $EXT_FILE not found"
    exit 1
fi

CLI="cursor"
if ! command -v "$CLI" &>/dev/null; then
    CLI="code"
fi

installed=$("$CLI" --list-extensions 2>/dev/null)
failed=()

while IFS= read -r line; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue

    if echo "$installed" | grep -qi "^${line}$"; then
        echo "  [skip] $line (already installed)"
    else
        echo "  [install] $line"
        if ! "$CLI" --install-extension "$line" --force; then
            failed+=("$line")
        fi
    fi
done < "$EXT_FILE"

if [[ ${#failed[@]} -gt 0 ]]; then
    echo ""
    echo "Failed to install:"
    for ext in "${failed[@]}"; do
        echo "  - $ext"
    done
    echo ""
    echo "These may need manual VSIX install from https://marketplace.visualstudio.com"
    exit 1
fi

echo "Done."
