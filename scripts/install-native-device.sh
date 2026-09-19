#!/bin/sh
set -eu
[ "$(id -u)" = 0 ] || exit 1
B=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
W=/usr/local/codex-user/work
A=/usr/local/sbin/iio-sysfs-trigger-adapter
H=/usr/local/sbin/native-iio-boot-fixed
C=/etc/init/iio-sysfs-trigger.conf
install -d -m 0755 "$W"
for x in iio-channel-shim3b.so iio-libwrite-shim2.so libiio.so.0
do
  install -m 0755 "$B/artifacts/$x" "$W/$x"
done
install -m 0755 "$B/scripts/native-iio-boot-fixed" "$H"
if [ -e "$A" ]; then
  cp -p "$A" "$W/iio-sysfs-trigger-adapter.backup-native-device"
fi
install -m 0755 "$B/artifacts/iio-sysfs-trigger-adapter" "$A"
[ -e "$C" ] || install -m 0644 "$B/artifacts/iio-sysfs-trigger.conf" "$C"
/sbin/initctl reload-configuration || true
/sbin/initctl stop duet-autorotate || true
/sbin/initctl stop iio-sysfs-trigger || true
/sbin/initctl stop iioservice || true
rm -f /run/iio-native-iioservice.pid
/sbin/initctl start iioservice
sleep 12
/sbin/initctl start iio-sysfs-trigger || true
echo native-device-install-complete
