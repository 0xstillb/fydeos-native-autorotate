#!/bin/sh
set -eu

fail() {
    echo "native-autorotate installer: $*" >&2
    exit 1
}

[ "$(id -u)" = 0 ] || fail "run this installer as root"

B=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
W=/usr/local/codex-user/work
S=/usr/local/sbin
BACKUP_ROOT="$W/native-autorotate-backups"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$BACKUP_ROOT/install-$STAMP"

required_files="
$B/artifacts/iio-channel-shim3b.so
$B/artifacts/iio-libwrite-shim2.so
$B/artifacts/libiio.so.0
$B/artifacts/iio-sysfs-trigger-adapter
$B/artifacts/iio-sysfs-trigger.conf
$B/artifacts/iioservice.conf
$B/artifacts/duet-autorotate.override
$B/scripts/native-iio-boot-fixed
$B/scripts/native-iio-verify
$B/scripts/verify-native-device.sh
"

for f in $required_files; do
    [ -f "$f" ] || fail "missing repository file: $f"
done

root_opts=$(awk '$2 == "/" { print $4; exit }' /proc/mounts)
case ",$root_opts," in
    *,ro,*)
        echo "Remounting root filesystem read-write..."
        mount -o remount,rw / || fail "could not remount / read-write; disable rootfs verification first"
        ;;
esac

testfile=/etc/init/.native-autorotate-write-test.$$
if ! : >"$testfile" 2>/dev/null; then
    fail "/etc/init is not writable"
fi
rm -f "$testfile"

install -d -m 0755 "$W" "$S" "$BACKUP_ROOT" "$BACKUP"

targets="
/usr/local/codex-user/work/iio-channel-shim3b.so
/usr/local/codex-user/work/iio-libwrite-shim2.so
/usr/local/codex-user/work/libiio.so.0
/usr/local/sbin/native-iio-boot-fixed
/usr/local/sbin/native-iio-verify
/usr/local/sbin/iio-sysfs-trigger-adapter
/usr/local/sbin/native-autorotate-status
/etc/init/iioservice.conf
/etc/init/iio-sysfs-trigger.conf
/etc/init/duet-autorotate.override
"

printf '%s\n' "$targets" | sed '/^$/d' >"$BACKUP/targets.list"

for p in $targets; do
    if [ -e "$p" ]; then
        dst="$BACKUP$p"
        mkdir -p "$(dirname "$dst")"
        cp -p "$p" "$dst"
    fi
done

printf '%s\n' "$BACKUP" >"$BACKUP_ROOT/latest-install"
echo "Backup: $BACKUP"

/sbin/initctl stop iio-sysfs-trigger >/dev/null 2>&1 || true
/sbin/initctl stop iioservice >/dev/null 2>&1 || true
/sbin/initctl stop duet-autorotate >/dev/null 2>&1 || true

for x in iio-channel-shim3b.so iio-libwrite-shim2.so libiio.so.0; do
    install -m 0755 "$B/artifacts/$x" "$W/$x"
done

install -m 0755 "$B/scripts/native-iio-boot-fixed" "$S/native-iio-boot-fixed"
install -m 0755 "$B/scripts/native-iio-verify" "$S/native-iio-verify"
install -m 0755 "$B/scripts/verify-native-device.sh" "$S/native-autorotate-status"
install -m 0755 "$B/artifacts/iio-sysfs-trigger-adapter" "$S/iio-sysfs-trigger-adapter"

install -m 0644 "$B/artifacts/iioservice.conf" /etc/init/iioservice.conf
install -m 0644 "$B/artifacts/iio-sysfs-trigger.conf" /etc/init/iio-sysfs-trigger.conf
install -m 0644 "$B/artifacts/duet-autorotate.override" /etc/init/duet-autorotate.override

if command -v restorecon >/dev/null 2>&1; then
    restorecon         "$W/iio-channel-shim3b.so"         "$W/iio-libwrite-shim2.so"         "$W/libiio.so.0"         "$S/native-iio-boot-fixed"         "$S/native-iio-verify"         "$S/native-autorotate-status"         "$S/iio-sysfs-trigger-adapter"         /etc/init/iioservice.conf         /etc/init/iio-sysfs-trigger.conf         /etc/init/duet-autorotate.override         >/dev/null 2>&1 || true
fi

rm -f     /run/iio-native-iioservice.log     /run/iio-native-iioservice.pid     /run/iio-native-started     /run/native-iio-prestart.log

/sbin/initctl reload-configuration || true

echo "Starting native iioservice..."
/sbin/initctl start iioservice >/dev/null 2>&1 || true

n=0
while [ "$n" -lt 75 ]; do
    if /sbin/initctl status iioservice 2>&1 | grep -q 'start/running'; then
        break
    fi
    sleep 1
    n=$((n + 1))
done

/sbin/initctl status iioservice 2>&1 | grep -q 'start/running' ||
    fail "iioservice did not start; inspect /run/native-iio-prestart.log"

/sbin/initctl start iio-sysfs-trigger >/dev/null 2>&1 || true

n=0
while [ "$n" -lt 35 ]; do
    if /sbin/initctl status iio-sysfs-trigger 2>&1 | grep -q 'start/running'; then
        break
    fi
    sleep 1
    n=$((n + 1))
done

"$S/native-autorotate-status"

sync

echo
echo "native-device-install-complete"
echo "Reboot once, then run: sudo /usr/local/sbin/native-autorotate-status"
echo "Rollback: sudo sh $B/scripts/rollback-native-device.sh"
