#!/usr/bin/env bash
# Download a video with yt-dlp using cookies from Brave.
# Brave can live in a non-default user-data dir, so it is a parameter.
#
# Usage: ytdlp_brave.sh <brave-user-dir> <url> [extra yt-dlp args...]
# Example: ytdlp_brave.sh ~/.config/BraveSoftware/Brave-Browser 'https://...'
set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename "$0") <brave-user-dir> <url> [extra yt-dlp args...]" >&2
    exit 1
fi

brave_dir=$1
url=$2
shift 2

if [[ ! -d $brave_dir ]]; then
    echo "Brave user-data dir not found: $brave_dir" >&2
    exit 1
fi

# yt-dlp reads cookies straight from the browser profile.
# Format: BROWSER[+KEYRING][:USER_DATA_DIR][::CONTAINER]
exec yt-dlp --cookies-from-browser "brave+gnomekeyring:${brave_dir}" "$@" "$url"
