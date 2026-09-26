# CMCC RAX3000M — OpenVPN 离线安装说明

本目录为 **中国移动 CMCC RAX3000M** 提供 **纯离线** 的 OpenVPN 安装支持。设备刷 FanchmWrt 后无 WAN、无 apk 源，全部依赖随本目录携带。

## 设备信息（实测 2026-09-26）

| 项目 | 值 |
|---|---|
| 型号 | 中国移动 CMCC RAX3000M（`cmcc,rax3000m`） |
| SoC | MediaTek MT7981B（Filogic 820），双核 A53，aarch64 |
| 系统 | FanchmWrt = **OpenWrt 25.12.4** r32933-4ccb782af7 |
| 内核 | **6.12.87** |
| 架构标识 | mediatek/filogic / `aarch64_cortex-a53` |
| 包管理器 | **apk-tools 3.0.5**（非 opkg） |
| 存储 | 128MB SPI-NAND；rootfs_data(UBI) 88.5MiB |
| 内存 | 512MB DDR4 |
| 网络 | br-lan **192.168.1.1**，root / password |
| 源状态 | `/etc/apk/repositories` **为空**，无 WAN/互联网 |

## 目录内容

```
CMCC_RAX3000M/
├── README.md                    # 本文件
├── packages/                    # 39 个离线 apk（61MB）+ SHA256SUMS.txt
└── scripts/
    └── install-openvpn.sh       # 一键离线安装
```

> 说明：`packages/` 内是三软件（openvpn + passwall + passwall2）共用的完整离线依赖池。本仓脚本只安装其中与 OpenVPN 相关的包；apk 会自动跳过已装包。

## 安装

把本 `CMCC_RAX3000M` 目录上传到设备（dropbear 无 SFTP 子系统，用 `cat >`、U 盘或 HTTP）：

```sh
cd /tmp/CMCC_RAX3000M
sh scripts/install-openvpn.sh
```

安装后页面（注意是 **vpn** 段，不是 services）：

```
http://192.168.1.1/cgi-bin/luci/admin/vpn/openvpn
```

## 安装结果（实测）

| 组件 | 版本 / 状态 |
|---|---|
| openvpn-openssl | **2.7.6**，`/usr/sbin/openvpn` |
| init 脚本 | **2.7.6 自带 `/etc/init.d/openvpn`**（无需补，区别于 2.7.7） |
| LuCI 前端 | luci-app-openvpn 26.262 + zh-cn 语言包 |
| DCO | `kmod-ovpn-backports` 空虚拟包占位，回退用户态数据通道 |
| 开机自启 | `S90openvpn` 已建立 |
| LuCI 页面 | HTTP **200** |

## 关键经验 / 调试方法

1. **纯离线**：设备无网且 repositories 为空，不能 `apk update`。把所有 apk 放一个目录，用
   `apk add --allow-untrusted ./*.apk` 本地安装。
2. **一次性装齐（最重要）**：apk 若半途失败会在 `/etc/apk/world` 残留未满足约束，导致后续所有 apk 命令报错。务必先干跑确认无缺依赖再实装：
   ```sh
   apk add --allow-untrusted --simulate /tmp/apkpool/*.apk   # 看有无 missing
   ```
3. **DCO 占位法**：openvpn-openssl 依赖 `kmod-ovpn-backports`（内核加速模块，离线源没有）。造一个空虚拟包即可满足依赖：
   ```sh
   apk add --virtual kmod-ovpn-backports
   ```
   OpenVPN 随后自动用用户态数据通道，功能不受影响。
4. **内核模块已内置**：`/dev/net/tun`、kmod-tun、kmod-nft-tproxy、kmod-nf-socket 等随固件提供，无需再装。
5. **校验传输完整性**：见 `packages/SHA256SUMS.txt`：
   ```sh
   cd packages && sha256sum -c SHA256SUMS.txt
   ```
6. **无 SFTP**：dropbear 默认不带 SFTP 子系统，SFTP 会报 `EOF during negotiation`，改用 `cat > file` 管道。

## 依赖来源

- OpenVPN 核心 / LuCI：本仓库 `rudy-TR3000/packages`（TR3000 与本机同为 filogic / aarch64_cortex-a53 / 25.12.4 / 内核 6.12.87，apk 可直接复用）。
- 通用依赖（curl、coreutils、lyaml、libev、libsodium、libatomic1 等）：OpenWrt 25.12.4 官方 base/packages/luci/target feed 离线下载补齐。
