#!/usr/bin/env bash

export HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances -j | jq -r '.[0].instance')

# set for all tmux session via setenv

tmux setenv -g HYPRLAND_INSTANCE_SIGNATURE $HYPRLAND_INSTANCE_SIGNATURE
tmux setenv HYPRLAND_INSTANCE_SIGNATURE $HYPRLAND_INSTANCE_SIGNATURE
