# fixes unicode issues over ssh
export LC_ALL=en_US.UTF-8

if [ -z "$WAYLAND_DISPLAY" ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" -eq 1 ] ; then
    exec sway --unsupported-gpu
fi
