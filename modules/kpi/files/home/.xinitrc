export LC_ALL='en_US.UTF-8'
export LANG='en_US.UTF-8'
#setxkbmap 'us,ru(winkeys)' -option grp:shifts_toggle,grp_led:scroll,ctrl:nocaps
setxkbmap 'us,ru(winkeys)' -option grp:toggle,grp_led:scroll,ctrl:nocaps
#setxkbmap 'us,ru(winkeys)' -option grp:toggle,grp_led:scroll,ctrl:nocaps,grp:alt_shift_toggle
#xkbcomp -w 0 .xkb.map $DISPLAY
#xmodmap -e 'keycode 105 = Super_R'
#xmodmap -e 'remove control = Super_R'
#xmodmap -e 'add mod4 = Super_R'

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

function setup_wacom {
    #Wacom Intuos5 touch S Pen stylus
    #Wacom Intuos5 touch S Pad pad
    #Wacom Intuos5 touch S Pen eraser
    #Wacom Intuos5 touch S Pen cursor
    xsetwacom set "Wacom Intuos5 touch S Pen stylus" MapToOutput HEAD-0
    xsetwacom set "Wacom Intuos5 touch S Pen eraser" MapToOutput HEAD-0
    xsetwacom set "Wacom Intuos5 touch S Pen cursor" MapToOutput HEAD-0
    xsetwacom set "Wacom Intuos5 touch S Pad pad" Button 1 "key ctrl" # in whell

    xsetwacom set "Wacom Intuos5 touch S Pad pad" Button 2 "key x"
    xsetwacom set "Wacom Intuos5 touch S Pad pad" Button 3 "key v"
    xsetwacom set "Wacom Intuos5 touch S Pad pad" Button 8 "key ctrl z"
    xsetwacom set "Wacom Intuos5 touch S Pad pad" Button 9 "key ["
    xsetwacom set "Wacom Intuos5 touch S Pad pad" Button 10 "key alt ctrl 1"
    xsetwacom set "Wacom Intuos5 touch S Pad pad" Button 11 "key ]"
}


case "$(hostname)" in
    tpad)
        xrandr --newmode "1920x1080"  173.00  1920 2048 2248 2576  1080 1083 1088 1120 -hsync +vsync
        xrandr --addmode eDP1 1920x1080
        xrandr --output eDP1 --mode 1920x1080
        tpad_trackpoint
        xinput set-prop 'Synaptics TM3149-002' 'Synaptics Scrolling Distance' -31 -31
        export SAKURA_ARGS=''
        ;;
    zz)
        export SAKURA_ARGS='-c 232 -r 64'
        xrandr --output DP-0 --mode 2560x1440 --rate 144
        ;;
esac
exec awesome
