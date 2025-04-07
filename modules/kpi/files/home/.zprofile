# fixes unicode issues over ssh
export LC_ALL=en_US.UTF-8

if [ -z "$WAYLAND_DISPLAY" ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" -eq 1 ] ; then
    export SDL_VIDEODRIVER=wayland,x11
    export _JAVA_AWT_WM_NONREPARENTING=1
    export QT_QPA_PLATFORM=wayland
    #export XDG_CURRENT_DESKTOP=sway
    #export XDG_SESSION_DESKTOP=sway
    #exec dbus-run-session sway --unsupported-gpu
    #exec Hyprland
    if uwsm check may-start; then
        exec uwsm start default
    fi
fi
