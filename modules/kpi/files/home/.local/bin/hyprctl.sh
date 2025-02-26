#!/usr/bin/env bash

export HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances -j | jq -r '.[0].instance')
hyprctl "$@"

