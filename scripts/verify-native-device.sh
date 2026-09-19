#!/bin/sh
set -u
D=/sys/bus/iio/devices/iio:device2
/sbin/initctl status duet-autorotate 2>&1 || true
/sbin/initctl status iio-sysfs-trigger 2>&1 || true
ps -ef | grep -E "[i]ioservice|[d]uet-autorotate"
printf "buffer="; cat "$D/buffer/enable"
printf "timestamp="; cat "$D/scan_elements/in_timestamp_en"
printf "trigger="; cat "$D/trigger/current_trigger"
P=$(pgrep -x iioservice | tail -1)
[ -n "$P" ] && grep -E "iio-channel-shim3b|iio-libwrite-shim2|libiio.so.0" "/proc/$P/maps" || true
