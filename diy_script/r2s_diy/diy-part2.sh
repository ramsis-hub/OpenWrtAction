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
# 4. Re-install feeds to pick up changes
# ---------------------------------------------------------
./scripts/feeds update -a
./scripts/feeds install -a

# ---------------------------------------------------------
# 5. Auto-expand rootfs to fill entire SD card on first boot
# ---------------------------------------------------------
mkdir -p files/etc/uci-defaults
cat << 'EXPAND_EOF' > files/etc/uci-defaults/30-auto-expand-rootfs
#!/bin/sh
#
# Auto-expand root partition and filesystem to fill SD card
# Runs once on first boot, then self-deletes
#

ROOT_DEV=$(lsblk -npo PKNAME "$(findmnt -nfo SOURCE /)" 2>/dev/null)
ROOT_PART=$(findmnt -nfo SOURCE / 2>/dev/null)
PART_NUM=$(echo "$ROOT_PART" | grep -oE '[0-9]+$')

if [ -z "$ROOT_DEV" ] || [ -z "$PART_NUM" ]; then
    logger -t expand-rootfs "Could not detect root device, skipping expansion"
    exit 0
fi

logger -t expand-rootfs "Expanding ${ROOT_PART} on ${ROOT_DEV} partition ${PART_NUM}"

# Expand partition to use all remaining space
echo "- +" | sfdisk --no-reread -N "$PART_NUM" "$ROOT_DEV" 2>/dev/null || \
    parted -s "$ROOT_DEV" resizepart "$PART_NUM" 100% 2>/dev/null

# Force kernel to re-read partition table
partx -u "$ROOT_DEV" 2>/dev/null || partprobe "$ROOT_DEV" 2>/dev/null

# Resize the ext4 filesystem
resize2fs "$ROOT_PART" 2>/dev/null

logger -t expand-rootfs "Root filesystem expanded successfully"

exit 0
EXPAND_EOF
chmod +x files/etc/uci-defaults/30-auto-expand-rootfs

echo "====== DIY Part 2 Complete ======"
