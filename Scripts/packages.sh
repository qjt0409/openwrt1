#!/bin/bash
# SPDX-License-Identifier: MIT
# OpenWRT-CI-X86 插件源码安装脚本
#
# 插件来源优先级：
#   1. 用户提供的仓库清单
#   2. lede / luci feed 自带（无需克隆，直接写 CONFIG 即可）
#   3. 用户清单缺失时自行检索补充
#
# 依赖说明：
#   - PassWall / PassWall2 依赖 openwrt-passwall-packages（已一并安装）
#   - iStore 商店依赖 luci-lib-taskd / taskd / luci-lib-xterm（istore 仓库自带）
#   - 易有云依赖 linkease 二进制 + luci-lib-linkeasefile（nas-packages 系列仓库）
set -e

PACKAGE_DIR="./package"
mkdir -p "$PACKAGE_DIR"

# 克隆完整仓库到 ./package/<name>，自动清理旧目录
clone_pkg() {
	local name="$1" repo="$2" branch="$3"
	echo "=================================================="
	echo ">> 安装插件源码: $name"
	echo ">> 仓库: https://github.com/$repo.git (分支: $branch)"
	rm -rf "$PACKAGE_DIR/$name"
	git clone -q --depth=1 --single-branch --branch "$branch" \
		"https://github.com/$repo.git" "$PACKAGE_DIR/$name" || {
		echo "!! 克隆失败: $name"
		exit 1
	}
}

# 从大仓库中提取指定子目录到 ./package/<name>
extract_dir() {
	local src="$1" dest="$2"
	if [ ! -d "$src" ]; then
		echo "!! 提取失败，源目录不存在: $src"
		exit 1
	fi
	rm -rf "$PACKAGE_DIR/$dest"
	cp -rf "$src" "$PACKAGE_DIR/$dest"
	echo ">> 提取: $src -> $PACKAGE_DIR/$dest"
}

# ---------- 科学上网：PassWall / PassWall2 ----------
clone_pkg openwrt-passwall-packages Openwrt-Passwall/openwrt-passwall-packages main
clone_pkg openwrt-passwall Openwrt-Passwall/openwrt-passwall main
clone_pkg openwrt-passwall2 Openwrt-Passwall/openwrt-passwall2 main

# ---------- Argon 主题与主题设置 ----------
clone_pkg luci-theme-argon jerrykuku/luci-theme-argon master
clone_pkg luci-app-argon-config jerrykuku/luci-app-argon-config master

# ---------- 消息推送 ----------
# 全能推送
clone_pkg luci-app-pushbot zzsj0928/luci-app-pushbot master
# 微信推送（原 ServerChan，仓库已更名）
clone_pkg luci-app-wechatpush tty228/luci-app-wechatpush master

# ---------- 网络工具 ----------
clone_pkg luci-app-ddns-go sirpdboy/luci-app-ddns-go main
clone_pkg luci-app-lucky gdy666/luci-app-lucky main
# IP 限速（x86 专用）
clone_pkg luci-app-eqosplus sirpdboy/luci-app-eqosplus main

# ---------- 文件列表：Alist（已按用户要求移除，不编译） ----------

# ---------- iStore 应用商店（大仓库按需提取） ----------
clone_pkg istore-src linkease/istore main
for d in luci-app-store luci-lib-taskd luci-lib-xterm taskd; do
	extract_dir "$PACKAGE_DIR/istore-src/luci/$d" "$d"
done
# iStore 前端语言由 i18n.translate("istore_vue_lang") 决定，
# 未翻译时默认 en。注入 po 翻译让前端使用中文。
mkdir -p "$PACKAGE_DIR/luci-app-store/po/zh-cn"
cat > "$PACKAGE_DIR/luci-app-store/po/zh-cn/app.po" <<'PO'
msgid ""
msgstr ""
"Content-Type: text/plain; charset=UTF-8\n"
"Language: zh-cn\n"

msgid "istore_vue_lang"
msgstr "zh-cn"
PO
rm -rf "$PACKAGE_DIR/istore-src"

# ---------- 易有云 LinkEase（大仓库按需提取） ----------
clone_pkg nas-packages linkease/nas-packages master
for d in linkease linkease-common-bin; do
	extract_dir "$PACKAGE_DIR/nas-packages/network/services/$d" "$d"
done
rm -rf "$PACKAGE_DIR/nas-packages"

clone_pkg nas-packages-luci linkease/nas-packages-luci main
for d in luci-app-linkease luci-lib-linkeasefile; do
	extract_dir "$PACKAGE_DIR/nas-packages-luci/luci/$d" "$d"
done
rm -rf "$PACKAGE_DIR/nas-packages-luci"

# ---------- OAF 行为管理（appfilter 用户态 + oaf 内核模块 + luci 界面） ----------
clone_pkg OpenAppFilter destan19/OpenAppFilter master

# 安全校验：lede 自带 OAF 残留会导致 kconfig 重复符号（递归依赖错误）
CONFLICT=$(find ./feeds ./package/feeds -maxdepth 4 -type d \( -name "open-app-filter" -o -name "luci-app-appfilter" \) 2>/dev/null)
if [ -n "$CONFLICT" ]; then
	echo "!! 检测到 lede 自带 OAF 残留，请确认 core.yml 已移除 feeds/packages/net/open-app-filter 与 feeds/luci/applications/luci-app-appfilter"
	echo "!! 残留目录: $CONFLICT"
	exit 1
fi

echo "=================================================="
echo ">> 全部插件源码安装完成"
