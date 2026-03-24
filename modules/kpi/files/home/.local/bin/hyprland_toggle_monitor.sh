#!/bin/bash

MONITOR="HDMI-A-1"

is_active=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$MONITOR\") | .name")

hyprctl keyword monitor "$MONITOR,disable"
sleep 0.2
hyprctl keyword monitor "$MONITOR,preferred,0x0,1"

# shift laptop display to the right of the external monitor
ext_width=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$MONITOR\") | .width")
laptop=$(hyprctl monitors -j | jq -r ".[] | select(.name != \"$MONITOR\") | .name")
if [ -n "$ext_width" ] && [ -n "$laptop" ]; then
    hyprctl keyword monitor "$laptop,preferred,${ext_width}x0,1"
fi

hyprctl dispatch focusmonitor "$MONITOR"
