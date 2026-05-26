#!/bin/bash
#
# DIY Part 2: Post-feed customizations (after feeds install)
# Minimal build for NanoPi R2S
#
echo "====== DIY Part 2: Post-Feed Customization ======"

# ---------------------------------------------------------
# 1. Set default LAN IP (change to your preference)
#    Default: 192.168.1.1 (OpenWrt stock)
#    Uncomment below to change:
# ---------------------------------------------------------
# sed -i 's/192.168.1.1/192.168.2.1/g' \
#     package/base-files/files/bin/config_generate

# ---------------------------------------------------------
# 2. Set default hostname
# ---------------------------------------------------------
sed -i "s/hostname='ImmortalWrt'/hostname='R2S'/" \
    package/base-files/files/bin/config_generate

# ---------------------------------------------------------
# 3. Update golang (needed by some OpenClash deps)
#    Pull latest golang from official openwrt/packages
# ---------------------------------------------------------
rm -rf temp_golang
git clone -b master --single-branch --depth 1 \
    https://github.com/openwrt/packages.git temp_golang
rm -rf feeds/packages/lang/golang
cp -rf temp_golang/lang/golang feeds/packages/lang/
rm -rf temp_golang

# ---------------------------------------------------------
# 4. Re-install feeds to pick up golang change
# ---------------------------------------------------------
./scripts/feeds update -a
./scripts/feeds install -a

# ---------------------------------------------------------
# 5. Auto-expand overlay to fill entire SD card on first boot
#    Works with SquashFS + ext4 overlay (preserves factory reset)
# ---------------------------------------------------------
mkdir -p files/etc/uci-defaults
cat << 'EXPAND_EOF' > files/etc/uci-defaults/30-auto-expand-rootfs
#!/bin/sh
# Auto-expand overlay to fill SD card (SquashFS + ext4 overlay)
# Runs once on first boot via uci-defaults, then self-deletes

LOG_TAG="expand-rootfs"

# 1. Find the overlay device
OVERLAY_DEV=$(block info 2>/dev/null | grep 'MOUNT="/overlay"' | cut -d: -f1)
if [ -z "$OVERLAY_DEV" ]; then
    # fallback: standard OpenWrt squashfs layout
    OVERLAY_DEV="/dev/loop0"
fi

# 2. Find the underlying partition (p2 on SD card)
ROOT_PART=$(awk '$2 == "/rom" {print $1; exit}' /proc/mounts)
if [ -z "$ROOT_PART" ]; then
    # fallback for mmcblk devices
    ROOT_PART="/dev/mmcblk0p2"
fi

DISK=$(echo "$ROOT_PART" | sed 's/p[0-9]*$//')
PART_NUM=$(echo "$ROOT_PART" | grep -oE '[0-9]+$')

logger -t "$LOG_TAG" "Overlay=$OVERLAY_DEV, Partition=$ROOT_PART, Disk=$DISK, PartNum=$PART_NUM"

# 3. Expand the partition to fill all remaining space
parted -s "$DISK" resizepart "$PART_NUM" 100% 2>&1 | logger -t "$LOG_TAG"

# 4. Re-read partition table
partx -u "$DISK" 2>/dev/null || partprobe "$DISK" 2>/dev/null

# 5. Update loop device to see new partition size
losetup -c "$OVERLAY_DEV" 2>&1 | logger -t "$LOG_TAG"

# 6. Resize the ext4 overlay filesystem
resize2fs "$OVERLAY_DEV" 2>&1 | logger -t "$LOG_TAG"

logger -t "$LOG_TAG" "Overlay expanded successfully"
exit 0
EXPAND_EOF
chmod +x files/etc/uci-defaults/30-auto-expand-rootfs

echo "====== DIY Part 2 Complete ======"
