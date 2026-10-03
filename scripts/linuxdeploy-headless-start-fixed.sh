#!/system/bin/sh
set -u
IMAGE=/data/media/0/linux.img
ROOT=/data/local/mnt
PIDFILE=/data/local/tmp/linuxdeploy-headless.pid

[ "$(id -u)" = "0" ] || { echo '[headless] root required'; exit 1; }
[ -f "$IMAGE" ] || { echo "[headless] image missing: $IMAGE"; exit 1; }
mkdir -p "$ROOT" /data/local/tmp

if ! grep -q " $ROOT " /proc/mounts 2>/dev/null; then
  LOOP=$(losetup -j "$IMAGE" 2>/dev/null | sed -n 's#^\(/dev/block/loop[0-9]*\):.*#\1#p' | head -n1)
  if [ -z "$LOOP" ]; then
    LOOP=$(losetup -f 2>/dev/null) || exit 1
    losetup "$LOOP" "$IMAGE" || exit 1
  fi
  mount -t ext4 -o rw "$LOOP" "$ROOT" || { echo '[headless] rootfs mount failed'; exit 1; }
fi

mkdir -p "$ROOT/dev" "$ROOT/dev/pts" "$ROOT/proc" "$ROOT/sys"
mountpoint -q "$ROOT/dev" || mount --rbind /dev "$ROOT/dev"
mountpoint -q "$ROOT/dev/pts" || mount -t devpts devpts "$ROOT/dev/pts" -o gid=5,mode=620 2>/dev/null || true
mountpoint -q "$ROOT/proc" || mount -t proc proc "$ROOT/proc"
mountpoint -q "$ROOT/sys" || mount -t sysfs sysfs "$ROOT/sys"

touch "$ROOT/.headless-write-test" && rm -f "$ROOT/.headless-write-test" || { echo '[headless] rootfs not writable'; exit 1; }

if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE" 2>/dev/null || true)
  if [ -n "$PID" ] && [ -r "/proc/$PID/cmdline" ] && tr '\0' ' ' <"/proc/$PID/cmdline" | grep -q 'sshd'; then
    echo "[headless] already running pid=$PID"
    exit 0
  fi
fi

chroot "$ROOT" /usr/sbin/sshd -p 22 -f /etc/ssh/sshd_config || { echo '[headless] sshd start failed'; exit 1; }
PID=$(ps -Ao pid,args 2>/dev/null | awk '/[s]shd -p 22/{print $1; exit}')
[ -n "$PID" ] && echo "$PID" > "$PIDFILE"
echo "[headless] READY pid=${PID:-unknown}"
grep " $ROOT " /proc/mounts || true
