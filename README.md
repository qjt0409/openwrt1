# OpenWRT-CI-X86

基于 **Lean 大的 lede 源码**（[coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)，master 分支，当前 x86 内核 6.18）的 GitHub Actions 云编译项目，面向 **x86_64 软路由（J1900 / J1800 等通用设备）**。

> 说明：lede 没有「24.10.3」这个版本号（24.10.3 是 OpenWrt 官方版本号）。lede master 基于 OpenWrt 25.12 主线、x86 内核 6.18，功能与稳定性均优于旧版 lede 分支，因此本项目采用 lede master。

## 固件特性

| 类别 | 内容 |
|---|---|
| 科学上网 | PassWall、PassWall2 |
| 消息推送 | 全能推送（PushBot）、微信推送（ServerChan，已更名 luci-app-wechatpush） |
| 网络工具 | DDNS-Go、Lucky、uhttpd 配置、负载均衡（mwan3）、TTYD 终端、自定义命令、IP 限速（eqosplus） |
| 文件存储 | 易有云（LinkEase）、Alist、OpenList、网络共享（Samba4）、磁盘管理 |
| 容器 | Docker（含 docker-compose） |
| 行为管理 | OAF（OpenAppFilter）应用过滤 |
| 应用商店 | iStore 商店（1Panel 等可在商店内一键安装） |
| 流量统计 | luci-app-statistics（collectd） |
| 网络加速 | TurboACC（Flow Offload），**BBR 由内核直接启用并设为默认拥塞算法** |
| 主题 | Argon + Argon 主题设置 |
| 登录 | 管理地址 `10.0.1.1`，用户名 `root`，**密码首次登录时自行设置** |

## 插件来源

- **lede / luci feed 自带**（无需额外仓库）：TurboACC、uhttpd、mwan3、ttyd、diskman、samba4、statistics、commands、docker、openlist、eqos（x86 不可用，已替换 eqosplus）
- **用户提供仓库**：passwall、passwall2、passwall-packages、wechatpush、ddns-go、argon、argon-config、istore、alist、OpenAppFilter（上游新版 v7，lede 自带的旧版 OAF 已由工作流自动移除，避免同名冲突）、eqosplus、helloworld（默认 feed，已因同名冲突移除）
- **自行检索补充**：luci-app-lucky（gdy666）、luci-app-pushbot（zzsj0928）、luci-app-linkease（linkease/nas-packages-luci）、linkease 二进制（linkease/nas-packages）

## 使用方法

1. **Fork / 上传本项目**到你的 GitHub 仓库（保持目录结构）。
2. 进入仓库 **Actions** 页面，首次使用会提示启用 Workflows，点击启用。
3. 手动编译：Actions → **OpenWrt-Build** → **Run workflow**。
   - `config`：选择 `X86`
   - `extra_packages`（可选）：额外追加 `CONFIG_PACKAGE_xxx=y` 行
   - `test`：勾选后**只生成 .config 不编译固件**，用于快速验证配置
4. 编译完成后，固件发布在仓库 **Releases** 页面，含：
   - `openwrt-x86-64-generic-squashfs-combined.img.gz`（BIOS 引导，J1900/J1800 刷这个）
   - `openwrt-x86-64-generic-squashfs-combined-efi.img.gz`（UEFI 引导）
   - `...-ext4-*.img.gz`（ext4 文件系统版本）
   - `...-vmdk-image*.gz`（VMware/虚拟机用）
   - `sha256sums`（校验文件）与完整 `.config`

## 常用操作

- **每日自动编译**：每天北京时间 05:00 自动执行。
- **清理**：Actions → **OpenWrt-Cleanup** → Run workflow，清理历史 Releases 与构建缓存（每周一自动执行）。
- **加快二次编译**：构建缓存（ccache + 工具链）自动保存/恢复，同源码提交的二次编译会显著加快；缓存超限时自动轮换清理。
- **1Panel 安装**：刷机后进入「iStore 应用商店」→ 搜索 1Panel → 一键安装（固件已内置 Docker）。

## 自定义

- **增删插件**：编辑 `Config/X86.txt`，按需增删 `CONFIG_PACKAGE_xxx=y` 行；修改后先跑一次 `test` 模式验证。
- **插件源码**：`Scripts/packages.sh` 管理所有外部插件克隆与提取。
- **默认参数**：`Scripts/patches.sh`（BBR、主题、IP、主机名）、`Scripts/settings.sh`（配置合并）。
- **更换源码**：修改 `build.yml` 中 `repo` / `branch` / `source` 三个参数。

## 注意事项

- OAF（OpenAppFilter）为内核模块，若未来 lede 升级内核后编译报错，可在 `Config/X86.txt` 中临时移除 OAF 三行，等待上游适配。
- 首次编译约 2~4 小时（需编译 Go 类组件如 xray-core、sing-box 等），属正常现象。
- 管理地址改为 `10.0.1.1`，刷机后电脑需与路由器在同一网段（10.0.1.x）才能访问后台。

## 目录结构

```
OpenWRT-CI-X86/
├── .github/workflows/
│   ├── build.yml        # 编译入口（手动/定时/清理后触发）
│   ├── core.yml         # 可复用编译核心（克隆→插件→补丁→编译→发布）
│   └── cleanup.yml      # 定期清理 Releases 与缓存
├── Config/
│   └── X86.txt          # x86_64 目标配置片段（全部插件开关）
├── Scripts/
│   ├── packages.sh      # 插件源码安装
│   ├── patches.sh       # 源码级补丁（BBR/主题/IP/主机名）
│   └── settings.sh      # 编译配置生成
└── README.md
```
