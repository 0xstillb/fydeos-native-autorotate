#!/bin/sh
set -eu

fail() {
    echo "native-autorotate rollback: $*" >&2
    exit 1
}

[ "$(id -u)" = 0 ] || fail "run rollback as root"

W=/usr/local/codex-user/work
BACKUP_ROOT="$W/native-autorotate-backups"
LATEST="$BACKUP_ROOT/latest-install"

[ -r "$LATEST" ] || fail "no install backup pointer found at $LATEST"
BACKUP=$(cat "$LATEST")
[ -d "$BACKUP" ] || fail "backup directory is missing: $BACKUP"
[ -r "$BACKUP/targets.list" ] || fail "backup target list is missing"

root_opts=$(awk '$2 == "/" { print $4; exit }' /proc/mounts)
case ",$root_opts," in
    *,ro,*)
        mount -o remount,rw / || fail "could not remount / read-write"
        ;;
esac

/sbin/initctl stop iio-sysfs-trigger >/dev/null 2>&1 || true
/sbin/initctl stop iioservice >/dev/null 2>&1 || true
/sbin/initctl stop duet-autorotate >/dev/null 2>&1 || true

while IFS= read -r p; do
    [ -n "$p" ] || continue
    saved="$BACKUP$p"
    if [ -e "$saved" ]; then
        mkdir -p "$(dirname "$p")"
        rm -f "$p"
        cp -p "$saved" "$p"
    else
        rm -f "$p"
    fi
done <"$BACKUP/targets.list"

rm -f     /run/iio-native-iioservice.log     /run/iio-native-iioservice.pid     /run/iio-native-started     /run/native-iio-prestart.log

/sbin/initctl reload-configuration || true
/sbin/initctl start iioservice >/dev/null 2>&1 || true
/sbin/initctl start duet-autorotate >/dev/null 2>&1 || true

sync
echo "native-device-rollback-complete"
echo "Restored backup: $BACKUP"
