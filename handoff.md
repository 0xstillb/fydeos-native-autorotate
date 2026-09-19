# FydeOS Native Autorotate Handoff

## Target

Validated on FydeOS 23.0-SP1, amd64-fydeos_iris.

The lid accelerometer is exposed as:
`/sys/bus/iio/devices/iio:device2`

Expected device metadata:

```text
name=cros-ec-accel
location=lid
```

## Root cause

The stock iioservice failed to allocate the IIO buffer with:

```text
Unable to allocate buffer: Permission denied
Failed to create buffer
SampleTimeout
```

The timestamp channel also corrupted the sample frame.
Therefore only X, Y, and Z are enabled.

## Native-only rule

`duet-autorotate` must be stopped.
Do not run it together with native Ash/iioservice.

```sh
/sbin/initctl stop duet-autorotate || true
```

## Required libraries

The tested preload chain is:

```text
/usr/local/codex-user/work/iio-channel-shim3b.so
/usr/local/codex-user/work/iio-libwrite-shim2.so
/usr/local/codex-user/work/libiio.so.0
```

Do not substitute unrelated libiio builds.

## Manual installation

Run the following as root.

```sh
D=/sys/bus/iio/devices/iio:device2
S=/sys/bus/iio/devices/iio_sysfs_trigger

/sbin/initctl stop duet-autorotate || true
/sbin/initctl stop iio-sysfs-trigger || true
/sbin/initctl stop iioservice || true

if [ ! -e /sys/bus/iio/devices/trigger0/name ]; then
  echo 0 > "$S/add_trigger"
fi

echo 0 > "$D/buffer/enable"
echo 0 > "$D/scan_elements/in_timestamp_en"
echo 1 > "$D/scan_elements/in_accel_x_en"
echo 1 > "$D/scan_elements/in_accel_y_en"
echo 1 > "$D/scan_elements/in_accel_z_en"
echo sysfstrig0 > "$D/trigger/current_trigger"
```

Apply runtime permissions:

```sh
GID=$(getent group iioservice | cut -d: -f3)
chown root:"$GID" /dev/iio:device2
chmod 640 /dev/iio:device2
find "$D" -type f -exec chown :"$GID" {} \;
find "$D" -type f -exec chmod g+r {} \;
chmod g+rw "$D/buffer/enable"
chmod g+rw "$D/buffer/length"
chmod g+rw "$D/trigger/current_trigger"
chmod g+rw "$D"/scan_elements/in_*_en
```

## Native startup command

```sh
P=/usr/local/codex-user/work
export LD_PRELOAD="$P/iio-channel-shim3b.so:$P/iio-libwrite-shim2.so:$P/libiio.so.0"
runcon u:r:cros_iioservice:s0 /usr/bin/env \
  /sbin/minijail0 \
  --config /usr/share/minijail/iioservice.conf \
  -- /usr/sbin/iioservice >/tmp/iioservice-native-boot.log 2>&1 &

sleep 4
/sbin/initctl start iio-sysfs-trigger || true
```

## Verify

```sh
/sbin/initctl status duet-autorotate
/sbin/initctl status iio-sysfs-trigger
cat "$D/buffer/enable"
cat "$D/scan_elements/in_timestamp_en"
cat "$D/trigger/current_trigger"
```

Expected: duet stopped, buffer 1, timestamp 0, trigger sysfstrig0.

## Troubleshooting

If buffer is 0, check permissions and the native log.

```sh
grep -E "Permission denied|allocate buffer|SampleTimeout|Failed to create" \
  /tmp/iioservice-native-boot.log /var/log/messages
```

If the screen rotates repeatedly while stationary, confirm timestamp is 0 and duet-autorotate is stopped.

## Rollback

```sh
/sbin/initctl stop iio-sysfs-trigger || true
[ -r /run/iio-native-iioservice.pid ] && kill "$(cat /run/iio-native-iioservice.pid)" || true
rm -f /run/iio-native-iioservice.pid
/sbin/initctl start duet-autorotate || true
```
