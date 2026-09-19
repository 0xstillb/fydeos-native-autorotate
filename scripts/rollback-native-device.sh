#!/bin/sh
set -eu
[ "$(id -u)" = 0 ] || exit 1
/sbin/initctl stop iio-sysfs-trigger 2>/dev/null || true
if [ -r /run/iio-native-iioservice.pid ]; then
  kill "$(cat /run/iio-native-iioservice.pid)" 2>/dev/null || true
fi
rm -f /run/iio-native-iioservice.pid
A=/usr/local/sbin/iio-sysfs-trigger-adapter
B=/usr/local/codex-user/work/iio-sysfs-trigger-adapter.backup-native-device
[ -f "$B" ] && cp -p "$B" "$A"
rm -f /usr/local/sbin/native-iio-boot-fixed
/sbin/initctl reload-configuration || true
/sbin/initctl start iioservice || true
echo native-device-rollback-complete
