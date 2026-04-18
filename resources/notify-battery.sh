#!/bin/bash

BATTERY="/sys/class/power_supply/BAT0"
NOTIFY="/usr/bin/notify-send"
REMEMBER="/tmp/battery_reminder_shown"

PERCENT=$(cat "$BATTERY/capacity")
STATE=$(cat "$BATTERY/status")

if [ "$STATE" = "Charging" ]; then
    if [ "$PERCENT" -ge 70 ]; then
        if [ ! -f "$REMEMBER" ]; then
            "$NOTIFY" "Battery $PERCENT%" "Please stop charging then close this!"
            touch "$REMEMBER"
        fi
    fi
fi

if [ "$STATE" = "Discharging" ]; then
    if [ "$PERCENT" -le 30 ]; then
        rm -f "$REMEMBER"
        "$NOTIFY" "Battery $PERCENT%" "Please start charging then close this!"
    fi
fi

exit 0