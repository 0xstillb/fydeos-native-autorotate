# FydeOS Native Autorotate Handoff

## Target

Validated on FydeOS 23.0-SP1, `amd64-fydeos_iris`.

The lid accelerometer is:

```text
/sys/bus/iio/devices/iio:device2
name=cros-ec-accel
location=lid
```

## Confirmed working architecture

```text
mojo_service_manager
        |
        v
iioservice Upstart job
  pre-start waits for IIO + local preload prerequisites
        |
        v
native-iio-boot-fixed
        |
        v
one native/preloaded /usr/sbin/iioservice
        |
        v
started iioservice event
        |
        v
iio-sysfs-trigger
  pre-start: native-iio-verify
        |
        v
iio-sysfs-trigger-adapter -> trigger_now every ~100 ms
        |
        v
native iioservice -> Ash orientation detection
```

`iio-sysfs-trigger-adapter` must not decide orientation, rotate the display, or
restart `iioservice`.

## Root causes found

### 1. Character-device permissions

libiio v0.25 opens the IIO character device with `O_RDWR`. Therefore this is
required:

```text
root:iioservice 660 /dev/iio:device2
```

`640` is not sufficient; the `iioservice` group needs write access.

Required sysfs controls are group-owned by `iioservice` and group-writable,
including:

```text
buffer/enable
buffer/length
trigger/current_trigger
scan_elements/in_accel_x_en
scan_elements/in_accel_y_en
scan_elements/in_accel_z_en
scan_elements/in_timestamp_en
sampling_frequency
```

### 2. Timestamp channel

The timestamp channel corrupts the sample frame on this device/build. The
working state is:

```text
in_timestamp_en=0
```

Only X/Y/Z are enabled.

### 3. Boot race

`mojo_service_manager` can emit its started event before `/dev/iio:device2`,
the sysfs trigger interface, and/or local preload files are all ready.

The known-good `iioservice.conf` therefore waits up to 60 seconds for the
prerequisites before running `native-iio-boot-fixed`. A validated reboot needed
about five seconds of waiting before the prerequisites were ready.

### 4. Old fallback conflicts with the native path

`duet-autorotate` must remain stopped. The repository installs:

```text
/etc/init/duet-autorotate.override
```

with:

```text
manual
```

## Required preload chain

```text
/usr/local/codex-user/work/iio-channel-shim3b.so
/usr/local/codex-user/work/iio-libwrite-shim2.so
/usr/local/codex-user/work/libiio.so.0
```

The preload mappings are checked against the actual `iioservice` PID, not only
its minijail parent.

## Known-good runtime state

```text
iioservice start/running
iio-sysfs-trigger start/running
duet-autorotate stop/waiting

root:iioservice 660 /dev/iio:device2
buffer=1
timestamp=0
trigger=sysfstrig0
```

The trigger adapter log should continue reporting increasing `trigger_now`
write counts.

## Non-fatal messages

The light sensor (`device1`, `cros-ec-light`) can report missing FIFO/trigger
support. That is separate from autorotation device2 and must not make the native
autorotation verifier fail.

These device2 warnings are also not treated as fatal by themselves:

```text
label attribute missing
timestamp channel could not be enabled
sampling_frequency_available missing
in_accel_mount_matrix missing
```

The timestamp warning is expected because the working shim intentionally keeps
timestamp disabled.

## Install and verify

Use the repository installer:

```sh
sudo sh scripts/install-native-device.sh
```

Then reboot once and run:

```sh
sudo /usr/local/sbin/native-autorotate-status
```

## Diagnostics

```sh
/sbin/initctl status iioservice
/sbin/initctl status iio-sysfs-trigger
/sbin/initctl status duet-autorotate

pgrep -a -x iioservice
pgrep -a -f iio-sysfs-trigger-adapter

stat -c '%U %G %a %A %n' \
  /dev/iio:device2 \
  /sys/bus/iio/devices/iio:device2/buffer/enable \
  /sys/bus/iio/devices/iio:device2/buffer/length \
  /sys/bus/iio/devices/iio:device2/trigger/current_trigger \
  /sys/bus/iio/devices/iio:device2/scan_elements/in_timestamp_en

D=/sys/bus/iio/devices/iio:device2
echo "buffer=$(cat "$D/buffer/enable")"
echo "timestamp=$(cat "$D/scan_elements/in_timestamp_en")"
echo "trigger=$(cat "$D/trigger/current_trigger")"

cat /run/native-iio-prestart.log
tail -n 30 /var/log/iio-sysfs-trigger-adapter.log
```

## Rollback

```sh
sudo sh scripts/rollback-native-device.sh
sudo reboot
```

The rollback script restores the files saved immediately before the latest
installer run.
