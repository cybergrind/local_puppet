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


function hiDPI {
    xrandr --dpi 192
    # Merge & load configuration from .Xresources
    xrdb -merge ~/.Xresources
    xrdb -merge ~/.Xdefaults
    # Let QT and GTK autodetect retina screen and autoadjust
    export QT_AUTO_SCREEN_SCALE_FACTOR=1
    export GDK_SCALE=2
    export GDK_DPI_SCALE=0.5
}

case "$(hostname)" in
    tpad)
        # xrandr --newmode "1920x1080"  173.00  1920 2048 2248 2576  1080 1083 1088 1120 -hsync +vsync
        # xrandr --addmode eDP1 1920x1080
        # xrandr --output eDP1 --mode 1920x1080
        tpad_trackpoint
        xinput set-prop 'Synaptics TM3149-002' 'Synaptics Scrolling Distance' -31 -31
        hiDPI
        ;;
    zz)
        hiDPI
        ;;
esac

systemctl --user import-environment DISPLAY

eval $(/usr/bin/gnome-keyring-daemon --start --components=gpg,pkcs11,secrets,ssh)
# You probably need to do this too:
export GNOME_KEYRING_CONTROL GNOME_KEYRING_PID GPG_AGENT_INFO SSH_AUTH_SOCK
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus

dbus-update-activation-environment --systemd DISPLAY
exec awesome
