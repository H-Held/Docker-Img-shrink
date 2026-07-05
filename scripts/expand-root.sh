#!/bin/bash
set -euo pipefail

### ---------- helpers ----------

paint_ttys() {
  for tty in /dev/tty{1..6}; do
    [ -w "$tty" ] || continue
    {
      printf '\033[0m\033[2J\033[H'
      printf '\033[41m\033[97m'

      cols=$(stty size < "$tty" 2>/dev/null | awk '{print $2}')
      lines=$(stty size < "$tty" 2>/dev/null | awk '{print $1}')
      cols=${cols:-80}
      lines=${lines:-24}

      for ((i=1; i<=lines; i++)); do
        printf '%*s\n' "$cols" ''
      done

      printf '\033[H'
      echo "=========================================="
      echo "  SYSTEM MAINTENANCE IN PROGRESS"
      echo "  Expanding root filesystem..."
      echo "  DO NOT POWER OFF"
      echo "=========================================="

      printf '\033[0m'
    } > "$tty"
  done
}

### ---------- lock system ----------

# Stop SSH completely
systemctl stop ssh 2>/dev/null || systemctl stop sshd 2>/dev/null || true
# Would disable SSH on next boot, but no need since we reboot at the end
#systemctl disable ssh 2>/dev/null || systemctl disable sshd 2>/dev/null || true

# Stop all local logins
for i in {1..6}; do
  systemctl stop getty@tty$i 2>/dev/null || true
done

# Kill existing sessions
pkill -t pts || true

### ---------- keep red screen alive ----------
(
  while true; do
    paint_ttys
    sleep 0.5
  done
) &
PAINT_PID=$!

### ---------- resize root filesystem ----------

ROOT_DEV="$(findmnt -n -o SOURCE /)"
DISK="/dev/$(lsblk -no pkname "$ROOT_DEV")"
PART_NUM="$(echo "$ROOT_DEV" | grep -o '[0-9]*$')"

parted "$DISK" ---pretend-input-tty <<EOF
resizepart $PART_NUM 100%
Yes
EOF

partprobe "$DISK"
sleep 2
resize2fs "$ROOT_DEV"

### ---------- cleanup ----------
echo "Expansion complete, rebooting in 10 seconds..."
kill "$PAINT_PID" || true

systemctl disable expand-root.service
rm -f /etc/systemd/system/expand-root.service

### Script Removes Itself
rm -f /usr/local/sbin/expand-root.sh

# Time for the kernel to settle
sync
sleep 10

systemctl reboot
