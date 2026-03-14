#!/bin/bash
#
# DIY Part 1: Add OpenClash feed (before feeds update)
# Minimal build for NanoPi R2S
#

echo "====== DIY Part 1: Adding OpenClash Feed ======"

# Backup original feeds
cp feeds.conf.default feeds.conf.default.bak

# Clean commented lines and fix mirrors
sed -i '/^#/d' feeds.conf.default
sed -i -e 's|git.openwrt.org/feed|github.com/openwrt|g' \
       -e 's|git.openwrt.org/project|github.com/openwrt|g' \
       feeds.conf.default

# Add OpenClash feed (only if not already present)
if ! grep -q "src-git OpenClash" feeds.conf.default; then
    sed -i '1i src-git OpenClash https://github.com/vernesong/OpenClash;master' \
        feeds.conf.default
    echo "Added OpenClash feed"
else
    echo "OpenClash feed already exists, skipping"
fi

echo ""
echo "Final feeds.conf.default:"
cat feeds.conf.default
echo ""

# Clone Argon theme (lightweight, the only custom theme we keep)
CUSTOM_PKG_PATH="./package/custom_packages/"
rm -rf ${CUSTOM_PKG_PATH}
mkdir -p ${CUSTOM_PKG_PATH}

git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git \
    ${CUSTOM_PKG_PATH}luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git \
    ${CUSTOM_PKG_PATH}luci-app-argon-config

echo "====== DIY Part 1 Complete ======"
