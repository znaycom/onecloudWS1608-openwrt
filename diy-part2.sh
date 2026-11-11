#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# ========== 1. 默认网络参数 ==========
# 默认 LAN IP（旁路由自身地址）
sed -i 's/192.168.1.1/192.168.1.110/g' package/base-files/files/bin/config_generate
# 默认主机名
sed -i 's/LEDE/OneCloud/g' package/base-files/files/bin/config_generate

# 首次启动写入上游网关 / DNS，并关闭本机的 IPv6 RA（IPv6 交给光猫）
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-onecloud <<'EOF'
#!/bin/sh
# 上游网关与 DNS（旁路由自身出口）
uci set network.lan.ipaddr='192.168.1.110'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway='192.168.1.1'
uci set network.lan.dns='223.5.5.5'
uci commit network

# IPv4 DHCP 开启；IPv6 RA/DHCPv6 关闭，避免与光猫冲突
uci set dhcp.lan.ignore='0'
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ndp='disabled'
uci commit dhcp

exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-onecloud

# ========== 2. 默认主题 ==========
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# ========== 3. 终端改为 bash（已装 bash，可保留） ==========
sed -i 's/\/bin\/ash/\/bin\/bash/' package/base-files/files/etc/passwd

# ========== 4. 裁剪重负载组件 ==========
# 4.1 Docker 全家桶
sed -i '/docker/d' .config
sed -i '/CONFIG_DOCKER_/d' .config
sed -i '/CONFIG_CGROUPFS_/d' .config
sed -i '/CONFIG_PACKAGE_runc/d' .config
sed -i '/CONFIG_PACKAGE_tini/d' .config
sed -i '/CONFIG_PACKAGE_cgroupfs-mount/d' .config
sed -i '/CONFIG_PACKAGE_libseccomp/d' .config

# 4.2 下载器（qBittorrent / Qt5）
sed -i '/qbittorrent/d' .config
sed -i '/CONFIG_PACKAGE_rblibtorrent/d' .config
sed -i '/CONFIG_PACKAGE_qt5-/d' .config

# 4.3 网盘与文件共享
sed -i '/openlist/d' .config
sed -i '/ksmbd/d' .config
sed -i '/CONFIG_PACKAGE_autosamba/d' .config
sed -i '/cifs-mount/d' .config
sed -i '/CONFIG_PACKAGE_kmod-fs-cifs/d' .config
sed -i '/CONFIG_PACKAGE_kmod-fs-smbfs-common/d' .config
sed -i '/CONFIG_PACKAGE_wsdd2/d' .config

# 4.4 DNS / 去广告（保留 dnsmasq 的 nftset 变体）
sed -i '/adguardhome/d' .config
sed -i '/mosdns/d' .config
sed -i '/chinadns-ng/d' .config
sed -i '/adblock-fast/d' .config

# 4.5 多余代理与 sing-box / passwall 生态
sed -i '/passwall/d' .config
sed -i '/ssr-plus/d' .config
sed -i '/CONFIG_PACKAGE_sing-box/d' .config
sed -i '/CONFIG_SING_BOX_BUILD_/d' .config
sed -i '/CONFIG_PACKAGE_haproxy/d' .config
sed -i '/CONFIG_PACKAGE_geoview/d' .config
sed -i '/CONFIG_PACKAGE_ipt2socks/d' .config
sed -i '/CONFIG_PACKAGE_v2dat/d' .config
sed -i '/CONFIG_PACKAGE_v2ray-geo/d' .config

# 4.6 其他用不到的服务
sed -i '/CONFIG_PACKAGE_6in4/d' .config
sed -i '/frpc/d' .config
sed -i '/zerotier/d' .config
sed -i '/tailscale/d' .config
sed -i '/p910nd/d' .config
sed -i '/CONFIG_PACKAGE_btrfs-progs/d' .config
sed -i '/CONFIG_PACKAGE_kmod-fs-btrfs/d' .config
sed -i '/CONFIG_PACKAGE_smartmontools/d' .config
sed -i '/hd-idle/d' .config
sed -i '/advancedsetting/d' .config
sed -i '/CONFIG_PACKAGE_luci-theme-material/d' .config

# ========== 5. 追加 OpenClash 及依赖 ==========
cat >> .config <<'EOF'
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_bash=y
CONFIG_PACKAGE_ruby=y
CONFIG_PACKAGE_ruby-yaml=y
CONFIG_PACKAGE_kmod-tun=y
CONFIG_PACKAGE_unzip=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_ca-bundle=y
CONFIG_PACKAGE_coreutils-nohup=y
CONFIG_PACKAGE_ipv6helper=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-i18n-ttyd-zh-cn=y
EOF

# ========== 6. 收敛配置（自动补齐依赖） ==========
make defconfig

# ========== 7. 校验关键项 ==========
echo "===== OpenClash / 关键包检查 ====="
grep -E 'openclash|kmod-tun|ruby|ipv6helper|dnsmasq' .config || true
