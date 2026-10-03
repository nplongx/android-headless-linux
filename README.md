# Android Headless Linux

A small, conservative Magisk-based boot layer for running a Linux Deploy-style Linux rootfs headlessly on rooted Android devices.

The project is **not tied to OpenClaw**. It provides a reusable Android boot mechanism for a Linux rootfs that exposes SSH, plus an optional conservative LMKD tuning module.

## What it does

- Starts a Linux rootfs once after Android reports `sys.boot_completed=1`.
- Mounts the ext4 image read-write and prepares `/dev`, `/dev/pts`, `/proc`, and `/sys`.
- Starts the rootfs `sshd` on port 22.
- Detects stale PID files by checking the process command line before treating sshd as alive.
- Does **not** run a watchdog, kill processes, restart arbitrary services, or alter OpenClaw.
- Includes an optional `Android Safe RAM` module with conservative LMKD properties and no runtime process killing.

## Verified reference setup

The current reference device is a Redmi Note 8 (`ginkgo`) with Magisk root and a 12 GiB ext4 Linux rootfs. The rootfs was verified writable and clean with `e2fsck` before use.

The headless boot path was verified across a real Android reboot:

1. Android reached `sys.boot_completed=1`.
2. The Magisk boot service ran.
3. The Linux rootfs mounted read-write.
4. `sshd` started inside the rootfs.
5. ADB port forwarding to TCP/22 was recreated.
6. SSH connectivity succeeded.

This is a device-specific verification, not a claim that every Android/Magisk/Linux Deploy combination will work unchanged.

## Repository layout

```text
modules/
  android-linux-headless-v1.0.0.zip
  android-safe-ram-v1.0.0.zip
scripts/
  linuxdeploy-headless-start-fixed.sh
```

## Installation

### 1. Linux headless boot module

Install `modules/android-linux-headless-v1.0.0.zip` from Magisk, then ensure the companion start script is available at:

```text
/data/local/tmp/linuxdeploy-headless-start-fixed.sh
```

The boot module waits for Android boot completion and invokes that script once. If the rootfs is already mounted, it exits without restarting anything.

### 2. Optional RAM tuning

`modules/android-safe-ram-v1.0.0.zip` is independent. It supplies conservative LMKD properties:

```text
ro.lmk.use_psi=true
ro.lmk.swap_util_max=100
ro.lmk.thrashing_limit=100
ro.lmk.thrashing_limit_decay=10
```

It intentionally has no runtime process killer or watchdog. Do not treat these values as a universal performance optimization; benchmark them on the target device.

## Manual start

As root on Android:

```sh
/data/local/tmp/linuxdeploy-headless-start-fixed.sh
```

Expected successful output includes:

```text
[headless] READY pid=<sshd-pid>
```

## SSH from a host

Forward Android TCP/22 to a host port:

```sh
adb forward tcp:2222 tcp:22
ssh -p 2222 long@127.0.0.1
```

## Safety / design constraints

This project intentionally keeps the boot path simple:

- one-shot boot trigger
- no watchdog loop
- no package/process killing
- no automatic reboot
- no mutation of OpenClaw configuration
- stale PID validation before early exit
- explicit writable-rootfs check

If the rootfs or SSH configuration is broken, the service logs the failure and exits rather than attempting aggressive recovery.

## Checksums

Release artifacts are accompanied by SHA-256 values in the GitHub release notes. Verify downloaded ZIPs before installing them.

## Status

**v1.0.0 — stable for the verified reference setup; broader device compatibility is not guaranteed.**

The release is based on an actual reboot test rather than a dry-run alone.
