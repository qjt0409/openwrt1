#!/bin/bash
# SPDX-License-Identifier: MIT
# OpenWRT-CI-X86 源码级补丁
#
# 1. x86 内核启用 BBR（lede 默认未开启，内核自带最新 BBR）
# 2. TurboACC 默认 TCP 拥塞算法改为 bbr
# 3. 默认主题切换为 Argon
# 4. 默认 LAN 地址 / 主机名
# 5. LuCI 状态页追加编译日期标识
#
# 依赖环境变量：WRT_THEME / WRT_NAME / WRT_IP / WRT_MARK / WRT_DATE
set -e

# ---------- 1. x86 内核启用 BBR ----------
KVER=$(grep -m1 -oP '^KERNEL_PATCHVER:=\K.*' ./target/linux/x86/Makefile 2>/dev/null || true)
KCFG="./target/linux/x86/config-$KVER"
if [ -n "$KVER" ] && [ -f "$KCFG" ]; then
	sed -i '/^CONFIG_TCP_CONG_BBR/d; /^CONFIG_DEFAULT_TCP_CONG/d' "$KCFG"
	printf 'CONFIG_TCP_CONG_BBR=y\nCONFIG_DEFAULT_TCP_CONG="bbr"\n' >> "$KCFG"
	echo ">> 内核 $KVER: 已启用 TCP BBR 并设为默认拥塞算法"
else
	echo "!! 未找到 x86 内核配置（$KCFG），跳过 BBR 补丁"
fi

# ---------- 2. TurboACC 默认拥塞算法 ----------
TUCFG=$(find ./feeds/luci/applications/luci-app-turboacc/root/etc/uci-defaults/ -type f 2>/dev/null | head -1)
if [ -n "$TUCFG" ]; then
	sed -i "s/option tcpcca 'cubic'/option tcpcca 'bbr'/" "$TUCFG"
	echo ">> TurboACC 默认 TCP 拥塞算法已设为 bbr"
else
	echo "!! 未找到 TurboACC uci-defaults，跳过"
fi

# ---------- 3. 默认主题 ----------
for MF in $(find ./feeds/luci/collections/ -maxdepth 1 -name "Makefile"); do
	sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" "$MF"
done
echo ">> 默认主题已切换为 $WRT_THEME"

# ---------- 4. 默认 LAN 地址 / 主机名 ----------
CFG_GEN="./package/base-files/files/bin/config_generate"
if [ -f "$CFG_GEN" ]; then
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_GEN"
	sed -i "s/hostname='[^']*'/hostname='$WRT_NAME'/" "$CFG_GEN"
	echo ">> 默认 LAN 地址=$WRT_IP 主机名=$WRT_NAME"
else
	echo "!! 未找到 config_generate，跳过"
fi

# 同步修改 LuCI 恢复页中的默认地址提示
FLASH_JS=$(find ./feeds/luci/modules/luci-mod-system -name "flash.js" | head -1)
if [ -n "$FLASH_JS" ]; then
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$FLASH_JS"
	echo ">> LuCI 恢复页默认地址已同步为 $WRT_IP"
fi

# ---------- 5. LuCI 状态页编译日期标识 ----------
SYSJS=$(find ./feeds/luci/modules/luci-mod-status -name "10_system.js" | head -1)
if [ -n "$SYSJS" ]; then
	sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/" "$SYSJS" || true
	echo ">> 已写入编译日期标识 $WRT_MARK-$WRT_DATE"
fi

# ---------- 6. 升级 dnsmasq 到 2.92（PassWall 要求 >=2.92） ----------
DNSMASQ_MAKE="./package/network/services/dnsmasq/Makefile"
if [ -f "$DNSMASQ_MAKE" ]; then
	sed -i 's/PKG_UPSTREAM_VERSION:=2.91/PKG_UPSTREAM_VERSION:=2.92/' "$DNSMASQ_MAKE"
	sed -i 's|PKG_HASH:=.*|PKG_HASH:=4bf50c2c1018f9fbc26037df51b90ecea0cb73d46162846763b92df0d6c3a458|' "$DNSMASQ_MAKE"
	echo ">> dnsmasq 已升级到 2.92"
else
	echo "!! 未找到 dnsmasq Makefile，跳过"
fi

# ---------- 7. Dockerman 菜单提升为顶级 "Docker" ----------
# lede feed 默认把 dockerman 挂在"服务"分类下（admin/services/dockerman，标题 Dockerman JS）。
# 用户要求 Docker 为独立顶级菜单（图2 布局），全局替换菜单路径并改标题。
if [ -d "./feeds/luci/applications/luci-app-dockerman" ]; then
	grep -rl "admin/services/dockerman" ./feeds/luci/applications/luci-app-dockerman 2>/dev/null | while read -r F; do
		sed -i 's|admin/services/dockerman|admin/docker|g' "$F"
	done
	sed -i 's/"Dockerman JS"/"Docker"/' \
		./feeds/luci/applications/luci-app-dockerman/root/usr/share/luci/menu.d/luci-app-dockerman.json
	echo ">> Dockerman 菜单已提升为顶级 Docker"
else
	echo "!! 未找到 luci-app-dockerman，跳过菜单补丁"
fi

echo ">> 全部补丁应用完成"
