#!/bin/sh
set -u

D=/sys/bus/iio/devices/iio:device2
ok=1

pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*" >&2; ok=0; }

status_iio=$(/sbin/initctl status iioservice 2>&1 || true)
status_trigger=$(/sbin/initctl status iio-sysfs-trigger 2>&1 || true)
status_duet=$(/sbin/initctl status duet-autorotate 2>&1 || true)

printf '%s\n' "$status_iio"
printf '%s\n' "$status_trigger"
printf '%s\n' "$status_duet"

printf '%s\n' "$status_iio" | grep -q 'start/running' &&
    pass "iioservice running" || fail "iioservice is not running"
printf '%s\n' "$status_trigger" | grep -q 'start/running' &&
    pass "iio-sysfs-trigger running" || fail "iio-sysfs-trigger is not running"
printf '%s\n' "$status_duet" | grep -q 'stop/waiting' &&
    pass "duet-autorotate stopped" || fail "duet-autorotate is not stopped"

count=$(pgrep -x iioservice 2>/dev/null | awk 'NF {n++} END {print n + 0}')
[ "$count" -eq 1 ] && pass "one iioservice process" || fail "expected one iioservice process, found $count"

pid=$(pgrep -x iioservice 2>/dev/null | head -1)
if [ -n "$pid" ] && [ -r "/proc/$pid/maps" ]; then
    for lib in iio-channel-shim3b.so iio-libwrite-shim2.so libiio.so.0; do
        grep -q "$lib" "/proc/$pid/maps" &&
            pass "$lib mapped" || fail "$lib is not mapped in iioservice"
    done
else
    fail "could not inspect iioservice mappings"
fi

perm=$(stat -c '%U:%G %a' /dev/iio:device2 2>/dev/null || true)
[ "$perm" = 'root:iioservice 660' ] &&
    pass "/dev/iio:device2 permissions are root:iioservice 660" ||
    fail "/dev/iio:device2 permissions are '$perm'"

buffer=$(cat "$D/buffer/enable" 2>/dev/null || true)
timestamp=$(cat "$D/scan_elements/in_timestamp_en" 2>/dev/null || true)
trigger=$(cat "$D/trigger/current_trigger" 2>/dev/null || true)

printf 'buffer=%s\n' "$buffer"
printf 'timestamp=%s\n' "$timestamp"
printf 'trigger=%s\n' "$trigger"

[ "$buffer" = 1 ] && pass "buffer enabled" || fail "buffer is not enabled"
[ "$timestamp" = 0 ] && pass "timestamp disabled" || fail "timestamp is not disabled"
[ "$trigger" = sysfstrig0 ] && pass "sysfstrig0 selected" || fail "sysfstrig0 is not selected"

pgrep -f '/usr/local/sbin/iio-sysfs-trigger-adapter' >/dev/null 2>&1 &&
    pass "trigger adapter running" || fail "trigger adapter is not running"

if [ "$ok" -eq 1 ]; then
    echo "native-autorotate-status: healthy"
    exit 0
fi

echo "native-autorotate-status: unhealthy" >&2
exit 1
