#!/bin/bash
set -euo pipefail

# Settings (set in docker-compose.yml or via `docker compose run -e ...`)
#   OUT_NAME  Name of the output file without extension.
#             Empty = "<input name>_shrunk".
#   COMPRESS  gz   -> <name>.img.gz (small, for Raspberry Pi Imager / balenaEtcher)
#             none -> <name>.img    (raw, can be written directly with Win32 Disk Imager)
COMPRESS="${COMPRESS:-gz}"

# Work directory lives on the host (inside Output/), so the space is visible
# and freed again after the run instead of staying in the Docker VM.
TMP="/output/.work"
LOOP=""

cleanup() {
  mountpoint -q /mnt && umount /mnt || true
  if [ -n "$LOOP" ]; then
    kpartx -d "$LOOP" || true
    losetup -d "$LOOP" || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

echo "Finding input image..."
IN="$(ls -1 /input | head -n 1)"
if [ -z "$IN" ]; then
  echo "ERROR: No input file found in Input/"
  exit 1
fi
echo "Input: $IN"

BASE="${IN%%.img*}"
OUT_NAME="${OUT_NAME:-${BASE}_shrunk}"
OUT_IMG="$TMP/${OUT_NAME}.img"

case "$COMPRESS" in
  gz|none) ;;
  *) echo "ERROR: COMPRESS must be 'gz' or 'none'"; exit 1 ;;
esac

mkdir -p "$TMP"

# Progress bars: pv shows bytes, speed, percent and ETA.
PV="pv -f -p -t -e -r -b -w 80"
step() { echo; echo "=== [$1/4] $2 ==="; }

# Copy or unpack the input into the work directory. The original stays untouched.
step 1 "Copying / unpacking $IN"
case "$IN" in
  *.img)     $PV "/input/$IN"              > "$OUT_IMG" ;;
  *.img.gz)  $PV "/input/$IN" | gunzip -c  > "$OUT_IMG" ;;
  *.img.bz2) $PV "/input/$IN" | bunzip2 -c > "$OUT_IMG" ;;
  *.img.xz)  $PV "/input/$IN" | xz -dc     > "$OUT_IMG" ;;
  *) echo "ERROR: Unsupported input format (.img, .img.gz, .img.bz2, .img.xz)"; exit 1 ;;
esac

# -s: no PiShrink auto-expand, our own expand-root service is used instead.
step 2 "Shrinking image (PiShrink, no percent available)"
./pishrink.sh -vs "$OUT_IMG"

step 3 "Injecting expand-root service"
LOOP="$(losetup --show -f "$OUT_IMG")"
kpartx -a "$LOOP"
sleep 2

LOOP_NAME="$(basename "$LOOP")"
ROOT_DEV="$(blkid | grep "/dev/mapper/${LOOP_NAME}p" | grep 'TYPE="ext4"' | cut -d: -f1 | head -n1 || true)"
if [ -z "$ROOT_DEV" ]; then
  echo "ERROR: No ext4 root partition found"
  exit 1
fi

mount "$ROOT_DEV" /mnt
install -m 755 /opt/expand-root.sh      /mnt/usr/local/sbin/expand-root.sh
install -m 644 /opt/expand-root.service /mnt/etc/systemd/system/expand-root.service
chroot /mnt systemctl enable expand-root.service
umount /mnt
kpartx -d "$LOOP"
losetup -d "$LOOP"
LOOP=""

if [ "$COMPRESS" = "gz" ]; then
  step 4 "Compressing with pigz (all cores, -9)"
  $PV "$OUT_IMG" | pigz -9 -p "$(nproc)" > "${OUT_IMG}.gz"
  rm -f "$OUT_IMG"
  OUT_IMG="${OUT_IMG}.gz"
else
  step 4 "Compression skipped (COMPRESS=none)"
fi

mv "$OUT_IMG" /output/
echo "DONE: Output/$(basename "$OUT_IMG")"
