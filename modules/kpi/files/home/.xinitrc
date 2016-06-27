export LC_ALL='en_US.UTF-8'
export LANG='en_US.UTF-8'
#setxkbmap 'us,ru(winkeys)' -option grp:shifts_toggle,grp_led:scroll,ctrl:nocaps
#setxkbmap 'us,ru(winkeys)' -option grp:toggle,grp_led:scroll,ctrl:nocaps
xkbcomp -w 0 .xkb.map $DISPLAY
xmodmap -e 'keycode 105 = Super_R'
xmodmap -e 'remove control = Super_R'
xmodmap -e 'add mod4 = Super_R'

if [ -e /home/kpi/.xmodmaprc ]
   then
       xmodmap ~/.xmodmaprc
fi

function tpad_trackpoint {
    tpset() { xinput set-prop "TPPS/2 IBM TrackPoint" "$@"; }

    tpset "Evdev Wheel Emulation" 1
    tpset "Evdev Wheel Emulation Button" 2
    tpset "Evdev Wheel Emulation Timeout" 200
    tpset "Evdev Wheel Emulation Axes" 6 7 4 5
    tpset "Device Accel Constant Deceleration" 0.95
}

if [ $(hostname) = "tpad" ]; then
    xrandr --newmode "1920x1080"  173.00  1920 2048 2248 2576  1080 1083 1088 1120 -hsync +vsync
    xrandr --addmode eDP1 1920x1080
    xrandr --output eDP1 --mode 1920x1080
    tpad_trackpoint
fi
exec awesome
