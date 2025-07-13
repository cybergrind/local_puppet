#!/bin/bash
rofi_dmenu() {
    # format: 1005624 docker-compose -f infra/docker-compose.yaml up
    kill `pidof rofi`
    local COM=$(ps -a -u $USER --no-headers -o pid,args | sort | uniq -i | rofi -dmenu -p "   " -i)
    local PID=$(awk '{print $1}' <<< "$COM")
    echo "$PID" | xargs -r kill
}

if [[ -z "$1" ]]; then
   echo "Kill process"
else
    rofi_dmenu
fi
