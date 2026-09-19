# FydeOS Native Autorotate

Native IIO autorotation compatibility for FydeOS/ChromeOS-style systems. The
working path keeps orientation detection and display rotation inside native
`iioservice` + Ash; the small adapter only generates periodic IIO trigger
events.

## Validated device

Validated on:

- FydeOS 23.0-SP1
- `amd64-fydeos_iris`
- lid accelerometer: `/sys/bus/iio/devices/iio:device2`
- `name=cros-ec-accel`
- `location=lid`

The current scripts are device/build-specific. Do not install them blindly on a
different board or a different IIO device layout.

## Expected healthy state

```text
iioservice:        start/running
iio-sysfs-trigger: start/running
duet-autorotate:   stop/waiting

/dev/iio:device2:  root:iioservice 660
buffer/enable:     1
in_timestamp_en:   0
current_trigger:   sysfstrig0
```

The timestamp channel must remain disabled. On this build, enabling it corrupts
the sample frame.

## Fresh install

The installer backs up every file it replaces, remounts `/` read-write when
needed, installs the known-good preload chain and Upstart jobs, disables the old
`duet-autorotate` fallback, starts the native path, and performs a health check.

### Option A: host already has Git

```sh
cd /tmp
git clone https://github.com/0xstillb/fydeos-native-autorotate.git
cd fydeos-native-autorotate
sudo sh scripts/install-native-device.sh
sudo reboot
```

### Option B: FydeOS host has no Git

```sh
cd /tmp
curl -L \
  https://github.com/0xstillb/fydeos-native-autorotate/archive/refs/heads/main.tar.gz \
  -o fydeos-native-autorotate.tar.gz
tar -xzf fydeos-native-autorotate.tar.gz
cd fydeos-native-autorotate-main
sudo sh scripts/install-native-device.sh
sudo reboot
```

If the installer cannot remount `/` read-write, rootfs verification must be
disabled first.

After reboot:

```sh
sudo /usr/local/sbin/native-autorotate-status
```

A healthy installation ends with:

```text
native-autorotate-status: healthy
```

Then test physical rotation with the keyboard detached and Auto Rotate enabled.

## What gets installed

```text
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
```

Install backups are stored under:

```text
/usr/local/codex-user/work/native-autorotate-backups/
```

## Rollback

From the downloaded/cloned repository:

```sh
sudo sh scripts/rollback-native-device.sh
sudo reboot
```

The rollback script restores the files saved immediately before the latest
installer run.

## Architecture

```text
mojo_service_manager
        |
        v
iioservice Upstart job
  pre-start waits for IIO prerequisites
        |
        v
native-iio-boot-fixed
  - /dev/iio:device2 -> root:iioservice 660
  - timestamp = 0
  - X/Y/Z enabled
  - trigger = sysfstrig0
  - buffer prepared
        |
        v
one preloaded native iioservice
        |
        v
native-iio-verify
        |
        v
iio-sysfs-trigger-adapter -> trigger_now
        |
        v
Ash native orientation / display rotation
```

For the debugging history and technical notes, see `handoff.md`.
