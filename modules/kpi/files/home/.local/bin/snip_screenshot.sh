#!/usr/bin/env bash
if [[ ! -d "${HOME}/Pictures/Screenshots" ]]; then
    mkdir -p "${HOME}/Pictures/Screenshots"
fi

screenshot_filename="${HOME}/Pictures/Screenshots/screenshot_$(date +%Y%m%d-%H%M%S).png"
grim -g "$(slurp)" "$screenshot_filename"

if [[ -f "$screenshot_filename" ]]; then
    wl-copy < "$screenshot_filename"
    ksnip "$screenshot_filename"
fi
