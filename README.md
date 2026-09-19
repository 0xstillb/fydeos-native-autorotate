# FydeOS Native Autorotate

Native IIO autorotation compatibility for FydeOS and ChromeOS devices.

## Scope

- Uses native FydeOS iioservice and Ash orientation handling.
- The adapter only generates periodic IIO trigger events.
- `duet-autorotate` must remain stopped.
- The timestamp channel must remain disabled.

## Validated device

FydeOS 23.0-SP1 on amd64-fydeos_iris.

The lid accelerometer is:

`/sys/bus/iio/devices/iio:device2`

Expected native state:

```text
duet-autorotate: stop/waiting
buffer/enable: 1
in_timestamp_en: 0
current_trigger: sysfstrig0
```

## Required preload libraries

```text
/usr/local/codex-user/work/iio-channel-shim3b.so
/usr/local/codex-user/work/iio-libwrite-shim2.so
/usr/local/codex-user/work/libiio.so.0
```

These files are device-specific and must come from a compatible build.

## Quick verification

```sh
/sbin/initctl status duet-autorotate
/sbin/initctl status iio-sysfs-trigger
D=/sys/bus/iio/devices/iio:device2
cat "$D/buffer/enable"
cat "$D/scan_elements/in_timestamp_en"
cat "$D/trigger/current_trigger"
```

For the complete installation, startup bootstrap, troubleshooting, and rollback procedure, read `handoff.md`.
