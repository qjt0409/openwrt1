#!/bin/bash
# SPDX-License-Identifier: MIT
# OpenWRT-CI-X86 编译配置生成脚本
#
# 流程：合并目标配置片段 → 追加默认设置（语言/主题/手动插件） → 交给 make defconfig
# 依赖环境变量：WRT_CONFIG / WRT_THEME / WRT_PACKAGE / GITHUB_WORKSPACE
set -e

# ---------- 1. 合并目标配置片段 ----------
cat "$GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt" >> ./.config

# ---------- 2. 基础 LuCI 与中文语言 ----------
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config

# ---------- 3. 默认主题 ----------
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

# ---------- 4. 手动追加的额外插件（可选） ----------
if [ -n "$WRT_PACKAGE" ]; then
	echo ">> 追加手动插件配置:"
	echo -e "$WRT_PACKAGE" | tee -a ./.config
fi

echo ">> .config 已生成"
