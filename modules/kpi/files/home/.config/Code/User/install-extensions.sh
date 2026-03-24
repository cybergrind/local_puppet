#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_FILE="$SCRIPT_DIR/extensions.txt"

if [[ ! -f "$EXT_FILE" ]]; then
    echo "Error: $EXT_FILE not found"
    exit 1
fi

installed=$(code --list-extensions 2>/dev/null)

while IFS= read -r line; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue

    if echo "$installed" | grep -qi "^${line}$"; then
        echo "  [skip] $line (already installed)"
    else
        echo "  [install] $line"
        code --install-extension "$line" --force
    fi
done < "$EXT_FILE"

echo "Done."
