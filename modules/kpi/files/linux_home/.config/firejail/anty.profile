# example to run program
# firejail --debug --profile=/home/kpi/.config/firejail/anty.profile --appimage ./vision

noblacklist ${HOME}/.config/dolphin_anty
noblacklist ${HOME}/.cache/dolphin_anty-updater/
noblacklist ${HOME}/.cache/dolphin_anty/
noblacklist ${PATH}/fusermount

noblacklist /sys/module
#blacklist /usr/bin/nvidia-modprobe

noblacklist ${HOME}/.config/pulse
private ${HOME}/devel/octo/a_other/dpriv

#blacklist ${HOME}/*
#private-home



read-only ${HOME}/.Xauthority

#seccomp !mbind


apparmor
tracelog
#private-dev
private-tmp
private-cache

#restrict-namespaces

noblacklist /
noblacklist /run/user/1000/
noblacklist /run/user/1000/*
