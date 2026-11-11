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

# 保持 helloworld 注释，不引入 ssr-plus
# sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# 添加 OpenClash 源
grep -q '^src-git openclash' feeds.conf.default || \
sed -i '$a src-git openclash https://github.com/vernesong/OpenClash.git;master' feeds.conf.default

# 移除可能存在的 passwall 源（保险）
sed -i '/passwall/d' feeds.conf.default
grep -n 'openclash' feeds.conf.default
