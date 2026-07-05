#!/bin/bash
set -e

OUT_NAME="shrunk_image"
TMP="/tmp/work"

mkdir -p "$TMP"

echo "Finding input image..."
IN="$(ls -1 /input | head -n 1)"

if [ -z "$IN" ]; then
  echo "ERROR: No input file found"
  exit 1
fi

echo "Input: $IN"

# Prepare input image
case "$IN" in
  *.img)     cp "/input/$IN" "$TMP/in.img" ;;
  *.img.gz)  gunzip -c "/input/$IN" > "$TMP/in.img" ;;
  *.img.bz2) bunzip2 -c "/input/$IN" > "$TMP/in.img" ;;
  *.img.xz)  xz -dc "/input/$IN" > "$TMP/in.img" ;;
  *) echo "ERROR: Unsupported input format"; exit 1 ;;
esac

echo "Shrinking image..."
./pishrink.sh -vs "$TMP/in.img" "$TMP/${OUT_NAME}.img"

echo "Injecting expand-root service..."

LOOP="$(losetup --show -f "$TMP/${OUT_NAME}.img")"
kpartx -a "$LOOP"
sleep 2

LOOP_NAME="$(basename "$LOOP")"
ROOT_DEV="$(blkid | grep "/dev/mapper/${LOOP_NAME}p" | grep 'TYPE="ext4"' | cut -d: -f1 | head -n1)"

if [ -z "$ROOT_DEV" ]; then
  echo "ERROR: No ext4 root partition found"
  kpartx -d "$LOOP"
  losetup -d "$LOOP"
  exit 1
fi

mount "$ROOT_DEV" /mnt

cp /opt/expand-root.sh /mnt/usr/local/sbin/
chmod +x /mnt/usr/local/sbin/expand-root.sh

cp /opt/expand-root.service /mnt/etc/systemd/system/
chroot /mnt systemctl enable expand-root.service

umount /mnt
kpartx -d "$LOOP"
losetup -d "$LOOP"

echo "Compressing with multicore (pigz)..."

# Use all CPU cores
echo "Compressing image with pigz (multicore gzip)..."
export GZIP=-9
pigz -p "$(nproc)" "$TMP/${OUT_NAME}.img"

echo "Moving final artifact to output..."
mv "$TMP/${OUT_NAME}.img.gz" /output/

echo "DONE ✔"
