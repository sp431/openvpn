# OpenVPN

OpenWrt OpenVPN 客户端的源码、离线安装包和配置指南，适配 Cudy TR3000 与 Tenda BE12 Pro。

本仓库的目的是让 OpenVPN 能在这些设备上**可复现**地装好 —— 包括处理
`kmod-ovpn-backports`（DCO）内核模块缺失这个必踩的坑，以及新版官方包不含 init 脚本的问题。

## 支持设备

| 型号 | 架构 | 系统 | 包管理器 | 状态 |
|------|------|------|----------|------|
| Cudy TR3000 256MB v1 | aarch64_cortex-a53 | OpenWrt 25.12.4 | apk | OpenVPN 2.7.6 + LuCI 26.262，实测可用 |
| Tenda BE12 Pro | aarch64_cortex-a53 | OpenWrt SNAPSHOT r34613（内核 6.18.31） | apk | 官方 openvpn-openssl 2.7.7 + LuCI 26.262，实测可用 |

## 目录结构

```
openvpn/
├── README.md                          # 本文件
├── .gitignore
├── .gitattributes                     # 强制 LF
├── rudy-TR3000/                       # Cudy TR3000 (aarch64)
│   ├── README.md
│   ├── scripts/install-openvpn.sh
│   ├── src/                           # init / LuCI（跨内核通用，BE12_Pro 复用）
│   └── packages/                      # 8 个 apk
└── BE12_Pro/                          # Tenda BE12 Pro (aarch64, SNAPSHOT)
    ├── README.md                      # 含官方 2.7.7 无 init 的处理
    └── scripts/install-openvpn.sh     # 复用 rudy-TR3000 的 src/packages
```

## 文件用途

### rudy-TR3000/src/ — 源码

| 路径 | 用途 |
|------|------|
| `etc/init.d/openvpn` | 服务启动/停止脚本 |
| `usr/sbin/openvpn` | OpenVPN 主程序二进制 |
| `usr/lib/lua/luci/controller/openvpn.lua` | LuCI 菜单控制器 |
| `usr/lib/lua/luci/model/cbi/openvpn*.lua` | LuCI 配置页面模型 |
| `usr/lib/lua/luci/view/openvpn/` | LuCI 视图模板 |

### rudy-TR3000/packages/ — .apk 安装包

| 文件 | 版本 | 说明 |
|------|------|------|
| `openvpn-openssl-2.7.6-r1.apk` | 2.7.6 | 主程序 |
| `luci-app-openvpn-26.262.64656~abf63e6.apk` | 26.262 | LuCI 界面 |
| `luci-i18n-openvpn-zh-cn-26.262.64656~abf63e6.apk` | 26.262 | 中文语言包 |
| `libopenssl3-3.5.7-r1.apk` | 3.5.7 | 加密库依赖 |
| `liblzo2-2.10-r5.apk` | 2.10 | LZO 压缩 |
| `liblz4-1-1.10.0-r1.apk` | 1.10.0 | LZ4 压缩 |
| `libnl-genl200-3.12.0-r1.apk` | 3.12.0 | netlink 依赖 |
| `libcap-ng-0.8.4-r2.apk` | 0.8.4 | 权限能力库 |

## 安装方法

```sh
# 一键脚本（自动处理 DCO 内核模块缺失）
cd /tmp/rudy-TR3000
sh scripts/install-openvpn.sh
```

详细步骤与手动安装方式见 [rudy-TR3000/README.md](rudy-TR3000/README.md)。

## 已知问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| `apk add openvpn-openssl` 报 `unsatisfiable constraints: kmod-ovpn-backports` | OpenWrt 25.12 的 openvpn-openssl 依赖 DCO 内核模块，而定制固件（内核 6.12.87）未编译该模块 | 先执行 `apk add --virtual kmod-ovpn-backports` 创建空虚拟包占位，再安装 |
| `DCO version: N/A` | 同上，DCO 未启用 | 属预期行为，OpenVPN 自动回退用户态数据通道，功能不受影响 |
| LuCI 里找不到 OpenVPN 菜单 | 路径不在 services 下 | 访问 `admin/vpn/openvpn`，不是 `admin/services/openvpn` |

## 注意事项

- OpenVPN 2.7.6 构建于 OpenSSL 3.5.7，支持 LZO / LZ4 压缩
- 配置模板请勿提交真实服务器地址与证书
- `kmod-ovpn-backports` 的不可用是固件层面的限制，不是配置问题
