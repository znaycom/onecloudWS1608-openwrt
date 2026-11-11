#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# Uncomment a feed source
# sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
# 1. 添加 OpenClash 源（必须放在最前面）
sed -i '1i src-git openclash https://github.com/vernesong/OpenClash.git;master' feeds.conf.default
# 2. 移除 Passwall 两个源（只用 OpenClash，避免体积和冲突）
sed -i '/passwall/d' feeds.conf.default
#sed -i '2s/^#//' feeds.conf.default
#sed -i '3s/^/#/' feeds.conf.default
